---
name: implement-and-evaluate
description: Orquestra `implement-feature` + `evaluator` + `fix-runner` num loop de verificação e retry. Roda o implementador uma vez e depois alterna o evaluator (veredito canônico) com o fix-runner (passada corretiva) até o contrato ser honrado, o retry budget se esgotar ou o circuit-breaker disparar. Persiste um journal por execução documentando cada ciclo e apontando para os eval-reports. No sucesso, commita os artefatos de avaliação, integra a branch padrão, faz push e abre o PR.
---

# Implement and Evaluate

Orquestrador ponta a ponta para levar uma feature de `spec.md + plan.md + contract.md` até um veredito `clean` do `evaluator`, **sem intervenção do operador** entre os ciclos. O orquestrador é dono do loop de retry e do journal; o trabalho em si é delegado a três skills, cada uma invocada num subagente novo, para que o contexto do próprio orquestrador continue pequeno ao longo de muitos ciclos:

1. **`implement-feature`** — invocada uma vez, no ciclo 0. Percorre as fases do `plan.md`, faz um commit por fase, produz os Prerequisites do contrato como artefatos e emite um report de prontidão preliminar.
2. **`evaluator`** — invocada no final de todo ciclo (incluindo o ciclo 0). Levanta um ambiente efêmero, exercita ponta a ponta cada item in-scope, persiste um `eval-report-<ts>.md` com timestamp e devolve o veredito canônico.
3. **`fix-runner`** — invocada no início dos ciclos 1+. Lê os itens com falha + a evidência deles no eval-report do ciclo anterior, edita código/fixtures/seeds/configs, valida localmente e produz um único commit `fix(F<ID>): cycle <N> — address items …`.

O orquestrador nunca edita código. Nunca invoca nenhuma das três skills inline — toda invocação passa por um subagente `general-purpose`, para que a execução de cada skill viva na sua própria janela de contexto.

As três skills são do plugin `ia-package` e são invocadas pelo nome com namespace: `ia-package:implement-feature`, `ia-package:evaluator`, `ia-package:fix-runner`.

Somente leitura sobre o projeto, exceto pelo arquivo de journal, pelo lockfile, pela entrada da target feature no `prd_progress.json` e pelos commits dos Steps 7 e 8 descritos abaixo. Nunca modifica código, contratos, specs ou plans. Push e abertura de PR acontecem APENAS no Step 7 (fluxo de criação do PR), e só quando o loop chegou a `success` e a branch atual não é a branch padrão do projeto. Os commits do orquestrador são: os commits de artefatos de avaliação (Steps 7.2 e 7.6), o merge commit quando o único arquivo em conflito era o `prd_progress.json` (Step 7.4) e o commit dos artefatos restantes no Step 8.4, que só acontece quando o fluxo do PR já fez o commit do Step 7.2 e parou antes do Step 7.6.

## INPUT

Free-form. Mesma resolução do `implement-feature` e do `evaluator`. Formatos aceitos:

- Feature ID (`F03`, `F12`).
- Pasta da feature (`docs/F03-video-upload/`, `./F03/`).
- Arquivo dentro da pasta da feature (`docs/F03-video-upload/contract.md`).
- Nome da feature em kebab-case ou fuzzy (`video upload`, `Video Upload`).

Overrides opcionais em linguagem natural, em qualquer lugar do input. Seis são interpretados pelo orquestrador; o resto é repassado ao `implement-feature` no ciclo 0.

| Override | Efeito |
|---|---|
| `max <N> retries` | Define o retry budget do orquestrador (default 3). |
| `no retries` | Define o budget como 0 (um ciclo só — implementação inicial + um evaluator). |
| `unlimited retries` | Desabilita o budget. O circuit-breaker e a guarda de 3 `gates-failed` consecutivos continuam valendo. |
| `pause between cycles` | Espera uma resposta no chat contendo `ok` / `continue` / `segue` / `yes` entre cada ciclo. |
| `keep eval env` | Depois de finalizar com status diferente de `success`, re-invoca o evaluator uma vez com `keep env`, para que o usuário possa inspecionar o ambiente com falha (Step 8). |
| `progress-path=<path>` | Path para o `prd_progress.json` do projeto. Repassado a toda invocação de sub-skill, para que as três (`implement-feature`, `evaluator`, `fix-runner`) gravem no mesmo arquivo. Se omitido, cada sub-skill descobre o arquivo de forma independente. Veja **PROGRESS TRACKING**. |

Qualquer outra coisa reconhecida no input original é repassada literalmente ao prompt de invocação do `implement-feature` no ciclo 0 (ex.: `pause between phases`, `skip lint`, `stub OpenAI`, `only phases 1 and 2`). O orquestrador NÃO repassa overrides ao evaluator (exceto `keep env`, conforme acima) nem ao fix-runner — os dois rodam com seus defaults, para que o veredito e a passada corretiva fiquem reproduzíveis.

Se a resolução falhar:

- Pasta da feature ausente ou sem `spec.md` + `plan.md` + `contract.md` → aborte: "feature folder missing required file `<file>`. Regenerate via `spec-writer`."
- Várias pastas plausíveis → aborte e liste os candidatos.

## OUTPUT

Dois artefatos por execução:

1. **Journal persistido** em `<feature-folder>/orchestration-<ts>.md`. Irmão do `contract.md` e dos arquivos `eval-report-*.md`. Formato fixado por `references/journal-template.md`. Não fica no gitignore. Registra o loop inteiro: a invocação de cada ciclo, o status retornado, o path do eval-report, os IDs de itens failed/passed/blocked/manual, os deltas em relação ao ciclo anterior e o veredito final.
2. **Chat report (compacto)** no final:
   - Status final (`success` | `manual-pending` | `stuck` | `exhausted` | `aborted` | `pr-blocked`).
   - Uma linha por ciclo (ciclo, quem rodou, status, contagens fail/pass/blocked, path do eval-report).
   - Path do journal.
   - Path do eval-report mais recente.
   - Soft-fails / overrides ignorados.

Nenhum código é escrito pelo orquestrador. As três skills delegadas produzem seus próprios commits conforme seus próprios contratos. No `success`, o orquestrador commita os artefatos de avaliação da execução, integra a branch padrão, faz push de todos esses commits e abre o PR (Step 7). Se o fluxo do PR parar depois do primeiro commit de artefatos, o Step 8.4 commita o que sobrou (sem push), exceto com um merge em andamento.

---

## EXECUTION STEPS

### Step 1 — Resolve input

Faça o parsing do input como free-form. Identifique a referência da feature e aplique a extração de overrides descrita em **INPUT**:

- Reconheça os seis overrides de nível de orquestrador; registre o efeito de cada um.
- Remova-os da string de input.
- O que sobrar vira o **`tail`**, acrescentado literalmente à invocação do `implement-feature` no ciclo 0.

Resolva a referência da feature para uma pasta contendo `spec.md` + `plan.md` + `contract.md`. Calcule `<feature-id>` como o segmento inicial `F<N>` do nome da pasta (em minúsculas, apenas alfanuméricos — a mesma definição de marcador que o evaluator usa).

Determine `<run-id>` = timestamp ISO 8601 normalizado para ser seguro em nome de arquivo (ex.: `2026-05-01T17-32-04Z`). A mesma string é usada no nome do arquivo de journal, na linha `**Run:**` do journal e em qualquer referência que o orquestrador emita sobre a execução.

**Checagem de estado pré-execução (best-effort).** Localize o `prd_progress.json` conforme **PROGRESS TRACKING**. Quando o arquivo existir e a entrada da target feature estiver acessível, inspecione o `status` atual e emita no chat um aviso de uma linha para os quatro estados abaixo antes de prosseguir. NÃO aborte; NÃO pergunte — o orquestrador continua autônomo. O aviso expõe o estado para ciência humana; a execução segue normalmente e as sub-skills sobrescrevem o status conforme seus próprios contratos. Quando o arquivo não estiver acessível (ausente, sem parse, feature ID ausente), pule em silêncio — a checagem pré-execução não pode bloquear a execução.

| `status` atual | Aviso a emitir |
|---|---|
| `done` | `"feature already 'done' (last eval clean); re-running will re-verify and may regress to 'fail' / 'pr-blocked'"` |
| `pr-blocked` | `"feature is 'pr-blocked' (prior merge-conflict unresolvable); re-running may overwrite this state"` |
| `removed` | `"feature is 'removed' from the current PRD; re-running will resurrect it without applying the prd-writer-for-complete-project Caso B reset (cycles, started_at, etc. carry over). Consider regenerating the PRD via prd-writer-for-complete-project first"` |
| `implementing` | `"feature is 'implementing' (a prior implement-feature run never reached terminal state); re-running is safe — Write 1 will refresh the entry"` |

Os quatro estados acima são os únicos que merecem aviso. `pending` / `implemented` / `fail` são pontos de entrada normais do orquestrador e não produzem aviso.

Aborts:

- Trio ausente → aborte, sugira o `spec-writer`.
- Padrão de override reconhecido mas com valor inválido (ex.: `max five retries` em vez de `max 5`) → aborte citando o trecho problemático e o formato esperado.

### Step 2 — Acquire run lock

O lockfile do orquestrador fica em `<feature-folder>/.orchestrate.lock`. É um arquivo de uma linha:

```
<PID> <run-id>
```

**Aquisição do lock:**

1. Se o lockfile não existir → grave-o com o PID atual e o `<run-id>`. Prossiga.
2. Se o lockfile existir, leia o PID. Verifique se está vivo com `kill -0 <pid>`:
   - PID vivo → aborte: "concurrent /implement-and-evaluate run for `<feature-id>`: PID `<N>` alive. Wait for it to finish or stop it, then re-run."
   - PID morto → a execução anterior caiu; sobrescreva o lockfile e prossiga. Registre em `Soft-fails`: "stale lockfile from PID `<dead-pid>`; overwrote".

**Liberação do lock:** apague o arquivo no final da execução (Step 8) ou em qualquer caminho de abort. A liberação é idempotente — tenha sucesso em silêncio se o arquivo já não existir. O lockfile nunca entra em commit.

### Step 3 — Initialize journal

Grave `<feature-folder>/orchestration-<run-id>.md` a partir do template em `references/journal-template.md`. Preencha o header (run-id, branch, feature ID, started-at, retry budget, overrides aplicados/ignorados). Deixe a tabela de ciclos e o bloco de veredito final vazios — eles são preenchidos conforme os ciclos terminam.

O orquestrador atualiza o journal **depois de cada ciclo**, para que um journal parcial seja informativo se a execução for interrompida (Ctrl-C, crash etc.).

### Step 4 — Cycle 0: invoke `implement-feature`

Crie um subagente novo pela Agent tool com `subagent_type: general-purpose`. O prompt PRECISA instruir o subagente a invocar a skill pela Skill tool e devolver um resumo estruturado sobre o qual o orquestrador possa agir sem reler o chat report completo do implementador.

Template do prompt:

```
Invoque a skill `ia-package:implement-feature` pela Skill tool com este input:

<feature-folder> <tail> <progress-path=<path>, apenas quando o orquestrador o recebeu>

Quando a skill terminar, devolva APENAS um bloco JSON cercado por ``` seguindo este schema:

{
  "status": "success | completed-with-regressions | incomplete | aborted-at-phase-<N> | aborted-pre-phase",
  "phases_committed": <int>,
  "phases_total": <int>,
  "abort_reason": "<texto ou null>",
  "report_summary": "<o chat report do implementador, literal>"
}

Mapeie o status assim:
- "success", "completed with regressions" ou "incomplete" → use a string de status literal (minúsculas, hífens no lugar de espaços).
- "aborted at phase N" → "aborted-at-phase-<N>".
- Aborts pré-fase (Steps 1–4 do implementador: dependência ausente, PRD ausente, seção do contrato ausente etc.) → "aborted-pre-phase".

Não interprete nem resuma o report — copie-o literalmente em report_summary.
```

Receba o JSON. Acrescente os campos ao journal em "Cycle 0", com o status do implementador, as fases commitadas e o motivo do abort, se houver.

**Decida:**

- `aborted-pre-phase` → o orquestrador finaliza com status `aborted` (Steps 6 e 8). Pula o loop de verificação inteiro. O implementador bateu num problema estrutural (dependências ausentes, contrato vazio, PRD não encontrado etc.); retry não resolve.
- Qualquer outro status → prossiga para o Step 5. Mesmo `incomplete` e `completed-with-regressions` vão para o verificador — o veredito canônico vem do evaluator, não do sinal de prontidão preliminar do implementador.

Se os overrides do usuário incluírem `pause between cycles`, espere uma resposta no chat contendo `ok` / `continue` / `segue` / `yes` antes de continuar.

### Step 5 — Verification loop

Inicialize:

- `cycle = 0` (ciclo 0 = o ciclo que acabou de terminar, em que o implementador rodou).
- `last_failed_set = ∅`, `last_passed_set = ∅`.

Loop:

#### 5.1 — Invoke `evaluator`

Crie um subagente `general-purpose`. Não injete `keep env` aqui — o override `keep eval env` é tratado apenas no Step 8, depois que o status final é conhecido.

Template do prompt:

```
Invoque a skill `ia-package:evaluator` pela Skill tool com este input:

<feature-folder> <progress-path=<path>, apenas quando o orquestrador o recebeu>

Quando a skill terminar, devolva APENAS um bloco JSON cercado por ``` seguindo este schema:

{
  "status": "clean | fail | fail-gate-<name> | pending | aborted-at-step-<N> | aborted-at-item-<ID>",
  "report_path": "<path absoluto ou relativo ao workspace do eval-report-*.md>",
  "items": {
    "passed": ["<ID>", ...],
    "failed": ["<ID>", ...],
    "blocked": ["<ID>", ...],
    "manual": ["<ID>", ...],
    "skipped": ["<ID>", ...]
  },
  "acs": {
    "verified": <int>,
    "failed": <int>,
    "undetermined": <int>,
    "total": <int>
  },
  "abort_reason": "<texto ou null>"
}

Mapeamento de status:
- "clean", "fail", "pending" → literal.
- "fail (gate <name>)" → "fail-gate-<name>" (nome do gate em kebab-case).
- "aborted at step <N>" → "aborted-at-step-<N>".
- "aborted at item <ID>: <reason>" → "aborted-at-item-<ID>". Coloque o motivo em abort_reason.

Leia as listas de itens da seção "## Items" do eval-report, agrupadas pelo Verdict.
```

Receba o JSON. Calcule:

- `failed_set = set(items.failed)`
- `blocked_set = set(items.blocked)`
- `manual_set = set(items.manual)`
- `passed_set = set(items.passed)`
- `passed_delta = passed_set − last_passed_set` (itens que viraram PASS neste ciclo)

Acrescente ao journal: número do ciclo, kind = `evaluator`, status, path do relatório, contagens de itens e os deltas em relação a `last_failed_set` / `last_passed_set`.

#### 5.2 — Decide: stop or continue

Aplique esta árvore de decisão, na ordem:

1. **`status == "clean"`** → terminal. Status final do orquestrador: `success`. Vá para o Step 6.

2. **`status == "pending"` E `failed_set == ∅` E `blocked_set == ∅`** (ou seja, apenas itens `manual` impedem a execução de ser clean) → terminal. Status final: `manual-pending`. Itens manuais são subjetivos e nenhum ciclo de fix os resolve — o usuário precisa revisá-los à mão. Vá para o Step 6.

3. **`status == "aborted-at-item-<ID>"`** com motivo `pause-on-first-failure` (só é possível se um override vazou — o orquestrador nunca deveria tê-lo definido) → terminal `aborted`. Vá para o Step 6.

4. **Circuit breaker (S2):** se `cycle ≥ 1` E **esta decisão está sendo tomada sobre uma avaliação real deste ciclo** E `failed_set == last_failed_set` E `len(passed_delta) == 0` E `len(failed_set) > 0` → terminal `stuck`. Vá para o Step 6. O implementador + o fixer não estão convergindo; mais ciclos desperdiçam budget.

   A primeira condição é o que impede o breaker de disparar por falta de dados. Ele só julga o que um evaluator de fato observou: numa reaplicação sintética do 5.2 depois de um `gates-failed` (veja o 5.3), nenhuma avaliação rodou, e a igualdade dos conjuntos é consequência da ausência de dados novos, não evidência de não-convergência. Nesse caminho, pule este ramo.

5. **Checagem do retry budget:** se `cycle == retry_budget` → terminal `exhausted`. Vá para o Step 6.

6. **Caso contrário** (status `fail`, `fail-gate-<name>`, `pending` com itens BLOCKED, `aborted-at-step-<N>`, `aborted-at-item-<ID>` com morte de serviço) → continue para o Step 5.3 para despachar um ciclo de fix.

Caso especial para `aborted-at-step-<N>`: o evaluator não conseguiu levantar o ambiente (migration quebrada, app que não sobe etc.). O fix-runner é invocado com o path do eval-report e uma lista `failed-items` vazia; ele diagnostica pela seção `## Abort reason` do relatório e pelo estado do projeto. Se `failed_set` estiver vazio E `aborted_at_step` for o único sinal, defina `failed-items=` (vazio) para o fix-runner; a skill reconhece esse caso quando o `**Status:**` do relatório é `aborted at step <N>` e opera a partir do motivo do abort.

Atualize `last_failed_set = failed_set`, `last_passed_set = passed_set`.

#### 5.3 — Invoke `fix-runner`

`cycle += 1`.

Crie um subagente `general-purpose`. Prompt:

```
Invoque a skill `ia-package:fix-runner` pela Skill tool com este input:

feature=<feature-folder>
eval-report=<report_path>
failed-items=<IDs de failed_set ∪ blocked_set, separados por vírgula>
cycle=<cycle>
<progress-path=<path>, apenas quando o orquestrador o recebeu>

Quando a skill terminar, devolva APENAS um bloco JSON cercado por ``` seguindo este schema:

{
  "status": "fixed | gates-failed | aborted",
  "commit_sha": "<SHA ou null>",
  "files_touched": ["<path>", ...],
  "items_targeted": ["<ID>", ...],
  "soft_fails": ["<linha>", ...],
  "abort_reason": "<texto ou null>",
  "report_summary": "<chat report literal>"
}
```

Notas sobre a lista `failed-items`:

- Concatene `failed_set` e `blocked_set`. Itens BLOCKED são exatamente o que o fix-runner resolve (seeds, fixtures, configs ausentes).
- Itens MANUAL NUNCA são passados ao fix-runner — são subjetivos, e a execução já termina neles pelo ramo 2 da árvore de decisão.
- Se os dois conjuntos estiverem vazios (o caso `aborted-at-step-<N>` do 5.2), passe `failed-items=` (lista vazia); o fix-runner recorre ao motivo do abort e ao relatório.

Receba o JSON. Acrescente ao journal: número do ciclo, kind = `fix-runner`, status, SHA do commit (se houver), arquivos tocados, itens alvo, soft-fails.

**Sub-decisões:**

- `fixed` (commit produzido) → volte ao 5.1 com o mesmo `cycle` (a próxima execução do evaluator faz parte do ciclo `cycle`).
- `gates-failed` (sem commit; working tree suja) → o ciclo é um retry "desperdiçado". Conta contra o budget. Pule a próxima execução do evaluator — não há nada novo a verificar — e vá direto ao Step 5.2 da próxima iteração com o mesmo `last_failed_set`.
  - **O circuit-breaker (ramo 4) NÃO se aplica neste caminho**, pela primeira condição do próprio ramo: nenhuma avaliação rodou neste ciclo. Vá direto ao ramo 5 (checagem de budget). Com budget restante, despache outro ciclo de fix-runner (5.3) com o **mesmo** `eval-report` e a **mesma** lista de `failed-items` da última avaliação real. Sem budget, termine `exhausted`.
  - Nota de implementação: modele como uma reaplicação imediata da lógica do Step 5.2 com o ramo 4 desabilitado só para esta iteração. NÃO atualize `last_failed_set` nem `last_passed_set` — eles continuam apontando para a última avaliação real, e o próximo evaluator que de fato rodar vai compará-los contra dados frescos, com o breaker valendo normalmente de novo.
  - Justificativa: a passada corretiva não é determinística. O fix-runner esgotou seu budget interno de 3 tentativas, mas uma nova leitura da mesma evidência pode atacar a causa por outro ângulo. Gastar o budget que o usuário pediu antes de desistir é a escolha deliberada aqui; o custo é limitado pelo próprio budget.
  - **Guarda de `gates-failed` consecutivos (limite fixo: 3).** Mantenha um contador `consecutive_gates_failed`, incrementado a cada `gates-failed` e **zerado sempre que um evaluator de fato rodar**. Ao atingir 3, termine `stuck` com o motivo `"3 consecutive gates-failed cycles; no evaluation ran since cycle <N>"`, mesmo que ainda haja budget. Esta guarda é o que impede uma execução com `unlimited retries` de girar para sempre: sem budget e sem breaker (que aqui não se aplica), ela é o único piso. Não pode sofrer override.
- `aborted` (ex.: apenas itens MANUAL, ou a correção exigiria mudanças no contrato) → terminal `aborted`. Acrescente ao journal o motivo do abort do fix-runner e vá para o Step 6.

Se os overrides do usuário incluírem `pause between cycles`, espere `ok` / `continue` / `segue` / `yes` antes de voltar ao 5.1.

### Step 6 — Compute final status

Calcule o status final a partir de como o loop terminou:

- `success` — `clean` alcançado.
- `manual-pending` — restaram apenas itens MANUAL.
- `stuck` — o circuit-breaker disparou, ou a guarda de `gates-failed` consecutivos (Step 5.3) atingiu 3.
- `exhausted` — budget consumido sem sucesso.
- `aborted` — abort pré-fase, abort do fix-runner ou abort do evaluator por override.

O status `pr-blocked` não é calculado aqui — ele só surge dentro do Step 7.

Se o status final for `success`, prossiga para o **Step 7 — PR creation flow**. Para qualquer outro status, pule o Step 7 e vá direto ao Step 8.

### Step 7 — PR creation flow (only on `success`)

Disparado exclusivamente quando o Step 6 calculou `success`. Objetivo: abrir um pull request da branch atual da feature para a branch padrão do projeto, com os artefatos de avaliação versionados e a feature integrada ao estado mais recente da branch padrão.

**7.1 — Safety check.** Determine a branch padrão do projeto via `gh repo view --json defaultBranchRef -q .defaultBranchRef.name` (ex.: `main`). Se a branch atual (`git branch --show-current`) for igual à branch padrão, cancele a criação do PR e finalize com status `success` mais um aviso no chat report: `"Cannot open PR from default branch <main> to itself. Re-invoke from a feature branch if you want a PR."`. O trabalho em si está feito; só o passo do PR é pulado. Nenhum commit de artefatos é feito neste caso.

**7.2 — Commit evaluation artifacts.** Antes do merge, versione os artefatos que esta execução produziu. Isso deixa o `prd_progress.json` sem mudanças pendentes (senão o `git merge` do 7.3 pode ser recusado) e garante que os paths citados no corpo do PR existam no PR.

Faça o stage **por path explícito**, apenas destes arquivos:

- Cada `eval-report-<ts>.md` cujo path foi devolvido pelos subagentes do evaluator **desta execução**. Relatórios de outras execuções que estiverem na pasta não entram.
- A pasta `eval-screenshots-<ts>/` irmã de cada um desses relatórios, quando existir.
- O journal desta execução, `<feature-folder>/orchestration-<run-id>.md`, com o Cycle Log e o Cycle Detail atualizados.
- O `prd_progress.json` localizado conforme **PROGRESS TRACKING**, quando `git status --porcelain -- <path>` mostrar mudança. Se o arquivo estiver fora do repositório ou for ignorado pelo git, não faça stage e registre em `Soft-fails`: "prd_progress.json not versioned in this repository; left out of the artifacts commit".

Nunca faça stage do `.orchestrate.lock`, de journals de outras execuções nem de qualquer outro arquivo. Nunca use `git add -A` / `git add .`.

Faça o commit com:

```
chore(F<ID>): record evaluation artifacts — run <run-id>
```

Faça o match com o estilo recente de commit-message do projeto inspecionando as últimas ~10 mensagens (capitalização, convenções de escopo). Não pule hooks (`--no-verify`). Se não houver nada para commitar, siga em frente. Se o commit falhar (ex.: um hook recusou), cancele a criação do PR e finalize com status `success` mais um aviso no chat report nomeando a falha.

**7.3 — Sync with the default branch.** Faça fetch e merge da branch padrão mais recente na branch atual da feature. Opera sobre a branch que estiver em checkout — funciona corretamente dentro de um `git worktree`.

```
git fetch origin <default-branch>
git merge origin/<default-branch>
```

Três resultados:

- **Already up to date** (nada a integrar) → prossiga para o Step 7.6.
- **Merge limpo** (auto-merge, possivelmente com merge commit) → prossiga para o Step 7.5 (reavaliação).
- **Conflitos** (`git status` mostra paths não integrados) → prossiga para o Step 7.4.

Se acontecer qualquer outra falha do git (ex.: a ferramenta de merge sai com código não-zero sem relação com conflitos, a rede cai no meio do fetch), cancele a criação do PR e finalize com status `success` mais um aviso no chat report nomeando a falha do git. O usuário pode resolver manualmente e re-invocar, ou abrir o PR à mão.

**7.4 — Resolve conflicts.**

Capture os arquivos em conflito: `git diff --name-only --diff-filter=U`.

**Primeiro, o `prd_progress.json`.** Se o `prd_progress.json` localizado conforme **PROGRESS TRACKING** estiver entre os arquivos em conflito, o orquestrador resolve esse arquivo sozinho, de forma mecânica — o fix-runner não faz stage do `prd_progress.json`:

1. Leia o lado da branch da feature (`git show :2:<path>`) e o lado da branch padrão (`git show :3:<path>`) e faça o parse dos dois como JSON.
2. Monte o resultado a partir da versão da branch padrão (campos de primeiro nível e entradas de todas as outras features), substituindo `features[<target>]` pela entrada da branch da feature. Entradas de feature que existem apenas no lado da branch da feature são mantidas.
3. Grave o resultado com escrita atômica (`.tmp` + rename) e faça `git add <path>`.

Se qualquer um dos dois lados não fizer parse, a resolução mecânica não é possível: finalize com status terminal `pr-blocked` e `failure_reason="unresolvable merge conflict in <path>: prd_progress.json side does not parse"`.

**Depois, os demais arquivos.** Recalcule `git diff --name-only --diff-filter=U`.

- **Nenhum arquivo restante** → conclua o merge com um commit, no mesmo formato de mensagem que o fix-runner usa no Mode B:
  ```
  merge: resolve conflicts from <base> into <head> (cycle <current cycle + 1>)

  Resolved files:
  - <path do prd_progress.json>
  ```
  Não pule hooks. Prossiga para o Step 7.5. Se o commit falhar, finalize com status terminal `pr-blocked` e `failure_reason="merge commit failed after resolving prd_progress.json: <motivo>"`.
- **Restam arquivos** → crie um subagente `general-purpose` com este prompt:

```
Invoque a skill `ia-package:fix-runner` pela Skill tool com este input:

feature=<feature-folder>
conflicted-files=<paths restantes do git diff, separados por vírgula>
cycle=<current cycle + 1>
<progress-path=<path>, apenas quando o orquestrador o recebeu>

Quando a skill terminar, devolva APENAS um bloco JSON cercado por ``` seguindo este schema:

{
  "status": "fixed | gates-failed | aborted",
  "commit_sha": "<SHA ou null>",
  "files_touched": ["<path>", ...],
  "abort_reason": "<texto ou null>"
}
```

Resultados:
- `fixed` → merge commit produzido pelo fix-runner (ele inclui o `prd_progress.json` já resolvido e staged pelo orquestrador). Prossiga para o Step 7.5 (reavaliação sobre o estado integrado).
- `gates-failed` ou `aborted` → o fix-runner não conseguiu uma resolução limpa. Finalize com status terminal `pr-blocked` e `failure_reason="unresolvable merge conflict in <files>: <abort_reason do fix-runner>"`. A working tree fica como o fix-runner a deixou (marcadores podem continuar presentes em `aborted`; limpa mas sem commit em `gates-failed`). O usuário resolve manualmente, commita (incluindo os artefatos que o Step 8.4 lista no chat report) e faz push + abre o PR à mão OU re-invoca o orquestrador.

**7.5 — Re-run evaluator.** Como o merge mudou código na branch da feature, valide o estado pós-merge. Crie um subagente `general-purpose` e rode o evaluator (mesmo template de prompt do Step 5.1, com `cycle += 1`).

- `clean` → o merge não quebrou nada; prossiga para o Step 7.6.
- Qualquer coisa diferente de `clean` → volte ao loop de verificação normal no Step 5.2 (árvore de decisão: parar ou continuar). O merge conta como mudança de código, então os ciclos normais de fix-runner / reavaliação se aplicam. Quando o loop terminar, recalcule o status final do Step 6. Se ainda terminar em `success`, NÃO refaça o Step 7.3 (apenas um merge por execução do orquestrador — evita condições de corrida quando a branch padrão avança durante o ciclo); vá direto ao Step 7.6. Se o status não for mais `success`, pule os Steps 7.6–7.9 e vá para o Step 8.

**7.6 — Finalize journal and commit remaining artifacts.** Antes do push:

1. Atualize a linha `**Status:**` do header do journal para `success` e preencha o bloco **Final Verdict** (status `success`, completed-at, total de ciclos e commits, todos os eval-reports, itens restantes, termination reason) e os **Soft-fails** de nível de execução. Na linha **Pull request** do Final Verdict, grave: `push e abertura do PR acontecem depois do commit que inclui este journal; resultado e URL no chat report`. A URL do PR não é gravada no journal.
2. Faça o stage, com as mesmas regras do Step 7.2, de tudo que mudou desde o 7.2: os eval-reports (e suas pastas `eval-screenshots-<ts>/`) produzidos pelas avaliações posteriores ao 7.2, o journal desta execução e o `prd_progress.json` quando tiver mudado.
3. Faça o commit com a mesma mensagem do Step 7.2 (`chore(F<ID>): record evaluation artifacts — run <run-id>`). Se o commit falhar, cancele a criação do PR e finalize com status `success` mais um aviso no chat report nomeando a falha.

**7.7 — Push the branch.**

```
git push -u origin <branch>
```

Se o push falhar (autenticação negada, remoto recusou, rede), finalize com status `success` mais um aviso no chat report nomeando a falha. Imprima o comando manual explícito que o usuário pode rodar para fazer push: `git push -u origin <branch>`.

**7.8 — Check for an existing PR.**

```
gh pr list --head <branch> --json url,number --limit 1
```

Se um PR existente for retornado: pule a criação; registre a URL dele no chat report ("Existing PR updated: `<url>`"). O push anterior (Step 7.7) já atualizou o diff do PR e dispara qualquer CI ligada a ele.

Se não houver PR existente: prossiga para o 7.9.

**7.9 — Create the PR.**

Fontes para os placeholders que o orquestrador ainda não tem em memória:

- **`<Feature Name>`** — derive do nome da pasta da feature. Remova o prefixo `F<ID>-`, troque hífens por espaços e coloque cada palavra com inicial maiúscula. Exemplo: `F03-video-upload` → `Video Upload`. NÃO abra o PRD só para isso.
- **`<texto literal do AC>` para o checklist de ACs** — leia do **`eval-report-<ts>.md` mais recente** desta execução (o path está no journal). A tabela `## Coverage Manifest` dele tem cada AC in-scope literal na primeira coluna, com uma marca de três estados; como o Step 6 chegou a `success`, toda linha está `✓ verified`. Copie cada célula da primeira coluna como uma linha do checklist. Isso evita re-analisar o PRD ou o contrato.
- **`<resumo de 2–3 frases>`** — localize o PRD pelo `prd_path` do `prd_progress.json` quando disponível; caso contrário, pela mesma auto-descoberta do `implement-feature` (`docs/PRD.md` → `PRD.md`). Leia a seção da target feature na Seção 6 (`Functional Requirements`) do PRD. Tire as 1–2 primeiras frases do bloco `Capabilities` e, se necessário, uma frase do `Experience`. Corte sem dó — é um resumo de PR, não um spec. Se o PRD não for localizável por qualquer motivo, use uma linha de fallback: `"Implementa F<ID> conforme seu contrato; veja os Acceptance Criteria abaixo."` NÃO bloqueie a criação do PR por causa da leitura do PRD.
- **`<Closes #N>` (auto-link opcional)** — consulte o GitHub em busca de uma issue de acompanhamento aberta, criada antes pelo `spec-writer`:
  ```
  gh issue list --search "[F<ID>] in:title" --state open --json number,url --limit 5
  ```
  - Nenhuma correspondência → omita a seção `## Closes` inteira do body. É o caso esperado quando o usuário não optou pela criação de issue no spec-writer.
  - Exatamente uma correspondência → defina `<N>` como o `number` dessa issue e inclua a seção `## Closes`.
  - Várias correspondências → use o `number` do **primeiro** resultado, registre um soft-fail no chat report nomeando todas as URLs de issue encontradas (para que o usuário consolide manualmente) e inclua a seção `## Closes` com a primeira.
  - Falha do `gh` → omita a seção `## Closes`, registre um soft-fail no chat report e continue. A criação do PR nunca é bloqueada pela busca de issue.

Monte o título:
```
feat(F<ID>): <Feature Name>
```

Monte o body com este template (`<feature-folder>` é a pasta da feature resolvida no Step 1):

````markdown
## Summary

Implementa **F<ID>: <Feature Name>**.

<resumo de 2–3 frases derivado de Capabilities e Experience desta feature no PRD>

## Acceptance Criteria

Todos os ACs in-scope foram verificados ponta a ponta pelo contract evaluator:

- ✓ <texto literal do AC>
- ✓ <texto literal do AC>
...

## Implementation Cycle

- Phases committed: <N> (pelo `implement-feature`)
- Fix cycles: <M> (pelo `fix-runner`)
- Final eval: clean — todos os itens do contrato em PASS

## Artifacts

- Spec: `<feature-folder>/spec.md`
- Plan: `<feature-folder>/plan.md`
- Contract: `<feature-folder>/contract.md`
- Latest eval-report: `<feature-folder>/eval-report-<ts>.md`
- Orchestration journal: `<feature-folder>/orchestration-<run-id>.md`

## Closes

Closes #<N>

---

🤖 Gerado automaticamente. Cada acceptance criterion acima foi exercitado ponta a ponta contra o contrato.
````

A seção `## Closes` do template acima é **condicional**: emita o header da seção E a linha `Closes #<N>` apenas quando a busca `gh issue list` encontrou ao menos uma issue aberta. Quando a busca não encontrou nada (ou o `gh` falhou), remova o bloco `## Closes` inteiro do body — NÃO emita uma seção vazia.

Invoque:

```
gh pr create --title "<title>" --body "$(cat <<'EOF'
<conteúdo do body acima>
EOF
)"
```

Capture a URL do PR retornada. Se o `gh pr create` falhar, finalize com status `success` mais um aviso no chat report nomeando a falha e o comando manual para tentar de novo.

### Step 8 — Finalize

1. **`keep env` no último evaluator (se o usuário pediu E o status final não for `success`)** — re-invoque o evaluator mais uma vez com `keep env` acrescentado ao input, para que o usuário tenha um ambiente vivo para inspecionar. Registre essa re-invocação no journal como uma entrada especial "post-finalize"; o status dela é apenas informativo (não muda o status final do orquestrador).

2. **Grave o bloco final do journal** (e atualize a linha `**Status:**` do header) com: status final, total de ciclos, total de commits entre os ciclos (soma dos commits de fase + commits de fix), paths de todos os eval-reports produzidos (um por invocação do evaluator), itens failed/blocked restantes, soft-fails do journal e a linha **Pull request**: `PR not opened: <motivo>` (quando bloqueado ou pulado por branch padrão, falha de commit, falha de push, falha do `gh` ou status diferente de `success`). Quando o Step 7.6 já gravou o Final Verdict, não o regrave.

3. **Grave o `prd_progress.json`** conforme **PROGRESS TRACKING**, de acordo com o status final.

4. **Commit dos artefatos restantes (apenas quando esta execução fez o commit do Step 7.2 e o fluxo do PR parou antes de chegar ao Step 7.6).** Evita que a execução termine com parte dos artefatos commitada e parte não — o que acontece quando o fluxo do PR para depois do 7.2 (falha do git no 7.3, `pr-blocked` no 7.4, status que deixa de ser `success` depois do 7.5). Nas demais execuções, este passo não faz nada: se o Step 7.2 não commitou (o Step 7 não rodou, a branch é a padrão ou um hook recusou o commit do 7.2), nada é commitado; se um hook recusou o commit do 7.6, não tente de novo — registre no chat report que o journal ficou sem commit.

   - **Sem merge em andamento** (`.git/MERGE_HEAD` não existe) → faça o stage, com as mesmas regras do Step 7.2, de tudo que mudou desde o 7.2: o journal desta execução (com o bloco final), os eval-reports e as pastas `eval-screenshots-<ts>/` produzidos depois do 7.2 (incluindo a re-invocação de `keep env` do item 1) e o `prd_progress.json` quando tiver mudado. Faça o commit com a mesma mensagem do Step 7.2 (`chore(F<ID>): record evaluation artifacts — run <run-id>`). Não faça push. Se o commit falhar, não contorne; registre a falha no chat report.
   - **Com merge em andamento** (`.git/MERGE_HEAD` existe — tipicamente `pr-blocked` no 7.4) → NÃO faça commit: ele concluiria um merge ainda não resolvido. Deixe o merge como está (marcadores e a resolução parcial do fix-runner continuam para o usuário). Liste no chat report, na seção `Artifacts to include in the merge commit`, os paths exatos dos artefatos restantes (os mesmos do caso acima), para que o usuário os inclua com `git add` no commit do merge que ele fizer.

5. **Libere o lockfile** em `<feature-folder>/.orchestrate.lock`. Idempotente.

6. **Emita o chat report:**

```
implement-and-evaluate — F<ID> <Feature Name>

Status: success | manual-pending | stuck | exhausted | aborted | pr-blocked
Cycles: <N> (1 implement + <N-1> fix)
Branch: <git branch>
Run: <run-id>

Cycle log:
  0  implement-feature  <impl status>     phases <X>/<Y>
  0  evaluator          <eval status>     P=<P> F=<F> B=<B> M=<M>   eval-report-<ts1>.md
  1  fix-runner         <fix status>      commit <sha or none>
  1  evaluator          <eval status>     P=<P> F=<F> B=<B> M=<M>   eval-report-<ts2>.md
  ...

Artifacts commits:
  <sha> chore(F<ID>): record evaluation artifacts — run <run-id>
  OR  (none) — <motivo>

Artifacts to include in the merge commit:     (apenas com merge em andamento no Step 8.4)
  git add <path> <path> ...

Pull request:
  ✓ Opened: <url>
  OR  ✓ Updated existing: <url>
  OR  ❌ Not opened — <motivo>: <uma linha + comando manual para tentar de novo>

Latest eval-report: <path>
Journal: <path>

Soft-fails:
- <linha>

Overrides applied:
- <linha>

Overrides ignored:
- <linha>

Abort reason (if any): <um parágrafo>
```

Se `keep eval env` foi respeitado, acrescente um bloco final listando os detalhes de conexão do ambiente vivo (URL do DB, URLs dos serviços, tmpdir) mais o comando explícito de limpeza para o usuário rodar depois.

---

## PROGRESS TRACKING

Este orquestrador delega a maior parte das escritas no `prd_progress.json` às três sub-skills. O schema é canônico na skill `prd-writer-for-complete-project` (seção "SCHEMA DO ARQUIVO DE PROGRESSO"); esta seção documenta apenas as escritas do orquestrador.

- `implement-feature` grava `status="implementing"` (transitório, início do Step 5 dela), `status="implemented"` (no final do Step 7 dela, quando não abortou) ou `status="fail"` num abort de fase / pré-fase.
- `evaluator` grava `status="done"` no clean, `status="fail"` em fail / fail-gate / abort, mais `report_path`. No `pending`, não muda o status.
- `fix-runner` incrementa `cycles` uma vez por execução. Não toca no status.

As escritas diretas do orquestrador se limitam a:

1. **Terminar em falha de forma consistente** — nos status finais `exhausted`, `stuck` e `aborted`, garantir `status="fail"` (o último evaluator pode ter deixado `implemented`, quando deu `pending`, ou `done`, quando uma avaliação clean anterior ao merge foi seguida de um `pending`) e gravar um `failure_reason` com o contexto de nível de orquestrador que as sub-skills não conhecem.
2. **Gravar `status="pr-blocked"`** — um status que só o orquestrador produz, quando o merge com a branch padrão do Step 7 gera conflitos que não puderam ser resolvidos.
3. **Resolver o conflito de merge do próprio arquivo** no Step 7.4, adotando as entradas da branch padrão para as outras features e a entrada da branch da feature para a target feature.

**Localizando o arquivo** (na ordem; o primeiro encontrado vence):

1. Se o input contiver `progress-path=<path>`, use-o E repasse-o literalmente em todo prompt de sub-skill que o orquestrador despachar (para que `implement-feature`, `evaluator` e `fix-runner` gravem no mesmo arquivo de forma determinística).
2. Procure a partir da pasta da feature resolvida no Step 1 para cima (máximo 4 níveis) pelo `prd_progress.json` mais próximo. O `prd-writer-for-complete-project` grava o arquivo ao lado do PRD por padrão, e as pastas de feature ficam ao lado do PRD (ex.: `docs/F03-video-upload/` → `docs/prd_progress.json`).
3. Procure a partir do CWD para cima (máximo 4 níveis) pelo `prd_progress.json` mais próximo.

Nos casos 2 e 3, NÃO repasse o path às sub-skills — deixe que elas o descubram de forma independente (elas usam a mesma ordem de busca e chegam ao mesmo arquivo em condições normais).

Se não for encontrado, registre em `Soft-fails` a linha "progress file not found, orchestrator-level write skipped" e prossiga. O journal continua registrando tudo; o JSON apenas fica sem a anotação do orquestrador.

**Regra de escopo:** nas escritas de status, nunca modifique a entrada de outra feature além da target feature e nunca modifique os campos de primeiro nível (`schema_version`, `prd_path`, `generated_at`). O orquestrador pode gravar `status`, `failure_reason`, `completed_at` e `updated_at` — e apenas nos casos abaixo. A única exceção à regra de escopo é a resolução de conflito do Step 7.4, que adota a versão da branch padrão para os campos de primeiro nível e para as outras features: isso é integração do merge, não uma escrita de status.

**Modos de falha — continuação silenciosa:**

- Arquivo não encontrado, falha no parse ou feature ID ausente → registre em `Soft-fails`, pule a escrita.
- Escrita atômica falha → registre em `Soft-fails`, pule.

Toda escrita de status é: ler → modificar apenas a entrada da target feature → escrita atômica (`.tmp` + rename) do JSON inteiro. Timestamps são RFC 3339 UTC.

**Escritas — no Step 8 (finalize), conforme o status terminal do orquestrador:**

- **`success`** → nenhuma escrita. O último evaluator já gravou `status="done"`; não há nada a acrescentar.
- **`manual-pending`** → nenhuma escrita. Itens manuais são subjetivos; o status do último evaluator permanece; o usuário revisa pelo journal e pelo relatório.
- **`exhausted`** (retry budget consumido sem sucesso) →
  - `status` ← `"fail"` (quando ainda não for `fail`)
  - `completed_at` ← `null` (quando o status anterior era `done`; mantém o invariante `completed_at` ≠ null ⇔ status == `done`)
  - `failure_reason` ← `"cycle budget exhausted (<N> cycles); last: <failure_reason anterior ou "no prior failure_reason">"` (≤200 caracteres; trunque o motivo anterior se necessário)
  - `updated_at` ← now
- **`stuck`** (circuit-breaker S2, ou a guarda de `gates-failed` consecutivos do Step 5.3) →
  - `status` ← `"fail"` (quando ainda não for `fail`)
  - `completed_at` ← `null` (quando o status anterior era `done`)
  - `failure_reason` ← `"circuit breaker: same FAIL set across cycles <N-1> and <N>, no PASS delta"` — ou, quando o término veio da guarda, `"3 consecutive gates-failed cycles; no evaluation ran since cycle <N>"`
  - `updated_at` ← now
- **`aborted`** (qualquer término via abort pré-fase do Step 4, abort do fix-runner ou abort do evaluator por override) →
  - `status` ← `"fail"` (quando ainda não for `fail`; em aborts pré-fase o `implement-feature` já gravou `fail`)
  - `completed_at` ← `null` (quando o status anterior era `done`)
  - `failure_reason` ← `"orchestrator aborted: <motivo>"` (motivo tirado da entrada de abort do journal; ≤200 caracteres; sobrescreve o `failure_reason` da sub-skill para acrescentar o enquadramento do orquestrador)
  - `updated_at` ← now
- **`pr-blocked`** (o merge com a branch padrão do Step 7 gerou conflitos que não puderam ser resolvidos) →
  - `status` ← `"pr-blocked"` (sobrescreve o `done` deixado pelo último evaluator, porque a etapa de integração revelou que o trabalho ainda não está pronto para entrega)
  - `completed_at` ← `null` (o veredito `clean` do evaluator anterior tinha definido esse campo; limpá-lo mantém o invariante do schema `completed_at` ≠ null ⇔ status == `done`. O trabalho não foi concluído-e-entregue — só concluído localmente — então o campo precisa voltar a null)
  - `failure_reason` ← `"unresolvable merge conflict in <files>: <abort_reason do fix-runner>"` (≤200 caracteres; ou o motivo específico do Step 7.4 quando a falha foi na resolução do `prd_progress.json`)
  - `updated_at` ← now

A anotação do orquestrador serve à clareza forense do JSON. O journal em `<feature-folder>/orchestration-<run-id>.md` continua sendo o registro narrativo canônico; o papel do JSON é o status terminal determinístico + uma linha de rastro.

---

## RULES

**Sempre:**

- Resolva a referência da feature com as mesmas regras do `implement-feature` e do `evaluator`.
- Rode a checagem de estado pré-execução do Step 1 contra o `prd_progress.json` (best-effort): emita o aviso de uma linha documentado quando o `status` atual da target feature for `done`, `pr-blocked`, `removed` ou `implementing`. Nunca aborte nem pergunte por causa do aviso — o orquestrador continua autônomo e deixa as sub-skills sobrescreverem conforme seus próprios contratos.
- Adquira `<feature-folder>/.orchestrate.lock` com checagem de PID vivo antes de despachar qualquer subagente.
- Inicialize e atualize continuamente `<feature-folder>/orchestration-<run-id>.md` conforme `references/journal-template.md`.
- Delegue as três skills a subagentes `general-purpose` novos — um subagente por invocação de skill, uma invocação de skill por subagente. Nunca invoque as skills inline. Invoque-as pelo nome com namespace (`ia-package:implement-feature`, `ia-package:evaluator`, `ia-package:fix-runner`).
- Exija retornos JSON estruturados de cada subagente, para que o orquestrador nunca precise fazer parsing de markdown.
- Rode o `evaluator` depois de todo passo que modifica código (implementação no ciclo 0, fix no ciclo ≥ 1, merge no Step 7). O evaluator é canônico; a prontidão preliminar do implementador não é.
- Agregue `failed_set ∪ blocked_set` como lista de input do fix-runner. Nunca inclua itens MANUAL.
- Aplique o circuit-breaker S2 com rigor sobre avaliações reais: mesmo conjunto FAIL + zero delta de PASS = parar, sem mais retry. Um ciclo em que o fix-runner devolveu `gates-failed` não tem avaliação para julgar — ele consome budget e segue pelo ramo 5, sem passar pelo breaker.
- Mantenha o contador `consecutive_gates_failed` do Step 5.3, zerando-o sempre que um evaluator rodar, e termine `stuck` ao chegar a 3. É o único piso de uma execução com `unlimited retries`.
- Respeite exatamente os overrides de nível de orquestrador (`max N retries`, `no retries`, `unlimited retries`, `pause between cycles`, `keep eval env`, `progress-path=<path>`) e repasse todo o resto ao prompt do implementador no ciclo 0.
- Libere o lockfile em qualquer caminho de término, incluindo aborts.
- Repasse `progress-path=<path>` a todo prompt de subagente de sub-skill quando o receber como input, para que `implement-feature`, `evaluator` e `fix-runner` gravem no mesmo `prd_progress.json`. Grave `status="fail"` + `failure_reason` de nível de orquestrador conforme **PROGRESS TRACKING** no Step 8 nos casos `exhausted` / `stuck` / `aborted`; grave `status="pr-blocked"` + `failure_reason` no caso `pr-blocked`.
- Quando o Step 6 calcular `success`, rode o Step 7 (fluxo de criação do PR): verifique que a branch atual não é a branch padrão, commite os artefatos de avaliação desta execução, faça fetch + merge de `origin/<default>`, resolva o conflito do `prd_progress.json` e despache o `fix-runner` Mode B para os demais conflitos, reavalie depois do merge, finalize o journal e commite os artefatos restantes, faça push da branch e então `gh pr create` com o título canônico (`feat(F<ID>): <Feature Name>`) e o template de body documentado no Step 7. Pule o Step 7 de forma limpa (aviso no chat report, status continua `success`) quando a branch for a branch padrão, um commit de artefatos falhar, o push falhar ou o `gh pr create` falhar — o trabalho está feito; só o passo de anúncio não pôde ser concluído.
- Nos commits de artefatos (Steps 7.2, 7.6 e 8.4), faça stage por path explícito apenas dos eval-reports e das pastas `eval-screenshots-<ts>/` desta execução, do journal desta execução e do `prd_progress.json`.
- Detecte PRs existentes via `gh pr list --head <branch>` antes do `gh pr create`; se houver, apenas faça push e reporte a URL existente.
- Busque a issue aberta `[F<ID>]` correspondente (criada pelo `spec-writer`) via `gh issue list --search "[F<ID>] in:title" --state open --json number,url --limit 5` imediatamente antes de compor o body do PR no Step 7.9. Quando houver correspondência, injete `## Closes\n\nCloses #<N>` no body para que o GitHub feche a issue automaticamente no merge; quando não houver ou o `gh` falhar, omita a seção inteira e continue.

**Nunca:**

- Edite código, contratos, specs, plans, eval-reports ou qualquer `orchestration-*.md` anterior. Somente leitura sobre o projeto, exceto pelo journal da execução atual, pelo lockfile, pelas escritas no `prd_progress.json` descritas em **PROGRESS TRACKING** e pelos commits dos Steps 7 e 8.4.
- Grave `status` no `prd_progress.json` fora dos casos `exhausted` / `stuck` / `aborted` (sempre `fail`) e `pr-blocked`. O status é, de resto, das sub-skills (`implement-feature` / `evaluator` / `fix-runner`).
- Commite fora dos Steps 7 e 8.4, ou faça push ou abra PRs fora do Step 7. Nenhum commit do orquestrador e nenhum push durante o loop de verificação; nenhum push no Step 8; nenhum PR aberto em `manual-pending` / `stuck` / `exhausted` / `aborted` / `pr-blocked`.
- Faça commit no Step 8.4 com um merge em andamento (`.git/MERGE_HEAD` presente) — liste os paths no chat report em vez disso.
- Faça stage do `.orchestrate.lock`, de relatórios ou journals de outras execuções, ou use `git add -A` / `git add .`.
- Pule git hooks (`--no-verify`).
- Faça force-push (`git push --force` ou `--force-with-lease`). O Step 7 usa apenas `git push` simples — a abordagem de merge foi escolhida justamente para evitar reescritas de histórico que exigiriam force-push.
- Abra um PR da branch padrão do projeto para ela mesma. O safety check do Step 7 cancela a criação do PR quando a branch atual é a branch padrão.
- Modifique qualquer entrada de feature no `prd_progress.json` além da entrada da target feature, ou os campos de primeiro nível, fora da resolução de conflito do Step 7.4.
- Pule a checagem do lockfile. Execuções concorrentes na mesma feature são inseguras, e o lockfile é o seguro barato.
- Repasse overrides de nível de orquestrador ao implementador (eles são consumidos pelo orquestrador). Repasse overrides que não são do orquestrador ao evaluator ou ao fix-runner — eles têm suas próprias gramáticas de override e o orquestrador não traduz. A única exceção é `progress-path=<path>`: embora seja de nível de orquestrador, ele É repassado literalmente às três sub-skills, para que todas gravem no mesmo `prd_progress.json` (conforme **PROGRESS TRACKING**).
- Passe itens MANUAL ao fix-runner. Eles são subjetivos e encerram a execução pelo ramo 2 da árvore de decisão.
- Re-invoque o `implement-feature` depois do ciclo 0. O design do implementador é greenfield (um commit por fase); os retries são do `fix-runner`.
- Continue o loop depois que o circuit-breaker disparar. Ficar preso nas mesmas falhas é sinal de que mais ciclos de fix desperdiçam budget; exponha e pare.
- Marque a execução como `success` quando o journal ainda tiver falhas não resolvidas de qualquer tipo.

---

## OVERRIDES

| Override | Efeito | Default |
|---|---|---|
| `max <N> retries` | Define o retry budget. `N` é um inteiro não negativo. | 3 |
| `no retries` | Equivale a `max 0 retries`. | — |
| `unlimited retries` | Desabilita o budget. O circuit-breaker e a guarda de 3 `gates-failed` consecutivos continuam valendo. | — |
| `pause between cycles` | Espera `ok`/`continue`/`segue`/`yes` entre cada ciclo (ciclo 0 → 1, 1 → 2 etc.). | autônomo |
| `keep eval env` | Depois de finalizar, re-invoca o evaluator uma vez com `keep env` para que o usuário possa inspecionar um ambiente vivo com falha. Ignorado em `success`. | off |
| `progress-path=<path>` | Path do `prd_progress.json`; repassado literalmente às três sub-skills. | auto-descoberta |

Qualquer outra coisa reconhecida na string de input é **repassada literalmente** à invocação do `implement-feature` no ciclo 0 como parte do seu `tail`. O orquestrador não interpreta esses overrides; o implementador interpreta. Exemplos que são repassados:

- `pause between phases` (interpretado pelo implementador)
- `skip lint`, `skip tests`, `skip typecheck` (interpretados pelo implementador)
- `stub OpenAI`, `assume empty response for missing APIs` (interpretados pelo implementador)
- `only phases 1 and 2` (interpretado pelo implementador)

Texto não reconhecido fica no `tail`. Se o implementador o ignorar, isso é problema do implementador — o orquestrador não registra nada.

**Immutable core (não pode sofrer override):**

- O loop de verificação roda depois de todo passo que modifica código.
- O lockfile é adquirido e liberado.
- O journal é persistido.
- O circuit-breaker S2 dispara em execuções travadas.
- A guarda de 3 `gates-failed` consecutivos (Step 5.3) termina a execução como `stuck`, inclusive sob `unlimited retries`.
- O fix-runner recebe `failed_set ∪ blocked_set`, nunca MANUAL.

---

## EDGE CASES

- **Sem o trio `spec.md` / `plan.md` / `contract.md`** → aborte no Step 1; instrua o usuário a rodar o `spec-writer`.
- **PRD ausente** → propague diretamente o abort pré-fase do implementador. O orquestrador não procura o PRD para o loop; quem procura é o implementador. (O Step 7.9 só lê o PRD para o resumo do PR, com fallback.)
- **Implementador aborta pré-fase (dependências ausentes, contrato vazio etc.)** → terminal `aborted`. Sem evaluator. Sem ciclo de fix. O journal registra o abort com o motivo do implementador.
- **Evaluator aborta no step 1 (resolução do input)** quando chamado pelo orquestrador → inesperado (o orquestrador já resolveu o input). Trate como `aborted` e registre o diagnóstico do evaluator.
- **Evaluator aborta no step 4 (falha no bring-up)** → o fix-runner é despachado com `failed-items=` (vazio) e o path do relatório; o fix-runner lê o `## Abort reason` do relatório para diagnosticar. Caso comum (migration quebrada introduzida pelo implementador).
- **Fix-runner retorna `gates-failed`** → sem reexecução do eval nesta iteração; o ciclo conta como consumido; o circuit-breaker não se aplica (não houve avaliação para julgar). O loop continua enquanto houver budget, despachando outro ciclo de fix-runner sobre o mesmo eval-report e a mesma lista de itens. É intencional: só uma avaliação real pode afirmar que a execução parou de convergir. O fim vem por uma de duas portas: o budget se esgota (`exhausted`) ou a guarda de 3 `gates-failed` consecutivos dispara (`stuck`) — o que vier primeiro.
- **`unlimited retries` com o fix-runner preso em `gates-failed`** → sem budget para esgotar e sem breaker neste caminho, quem encerra é a guarda de 3 consecutivos do Step 5.3, com status `stuck`. Sem ela a execução giraria indefinidamente.
- **Fix-runner retorna `aborted` porque a correção exigiria mudanças no contrato** → terminal `aborted`. O journal registra o motivo. O usuário precisa regenerar o spec/contrato via `spec-writer`.
- **Vários eval-reports gravados num mesmo ciclo** (ex.: o usuário re-roda o evaluator manualmente no meio do ciclo) → o orquestrador usa apenas o path de relatório devolvido pelo seu próprio subagente de evaluator; relatórios estranhos na pasta são ignorados e nunca entram nos commits de artefatos.
- **Lockfile obsoleto (processo caiu no meio da execução)** → o orquestrador sobrescreve e prossegue; registra em `Soft-fails`. O journal anterior fica intacto (re-execuções produzem um novo journal com timestamp — journals antigos são histórico imutável).
- **`pause between cycles` e o usuário digita algo diferente dos tokens de retomada reconhecidos** → o orquestrador interpreta o texto como overrides adicionais para o *próximo* ciclo de fix e o acrescenta ao prompt do próximo subagente. (Ex.: o usuário digita `skip tests` entre os ciclos 1 e 2; isso vai para o prompt do fix-runner do ciclo 2.)
- **`keep eval env` numa execução `success`** → ignorado (não há ambiente com falha para manter). Registrado em `Overrides ignored` no chat report.
- **Execução interrompida (Ctrl-C, reboot da máquina)** → o lockfile fica para trás; o journal parcial fica como está. A próxima invocação detecta o lockfile obsoleto pela checagem de PID vivo, sobrescreve-o e começa com um novo run-id (não retoma).
- **Branch trocada no meio da execução** (`git checkout` entre ciclos) → todos os commits e o novo run-id ficam presos à branch em que o orquestrador começou; trocar de branch no meio da execução é comportamento indefinido e o orquestrador não detecta. Comportamento documentado: não troque de branch entre ciclos.
- **A feature já está em estado clean quando invocada** (implementador diz que todas as fases estão commitadas, evaluator diz clean) → terminal `success` depois de um ciclo. O journal registra "0 phases newly committed; 0 fix cycles".
- **O `tail` do implementador contém um token de nível de orquestrador** (ex.: `max 5 retries` aparece no input do usuário, mas o orquestrador deixou passar) → o implementador vai vê-lo e não vai interpretá-lo como do orquestrador, já que `max N retries` também está na gramática do implementador (é o retry de hard-fail do implementador, não o do orquestrador). Essa dupla contagem é aceitável — o implementador a aplica dentro do seu loop de hard-fail; o orquestrador já extraiu sua própria cópia no Step 1.
- **Evaluator retorna `aborted-at-item-<ID>` com `service died`** → o fix-runner é despachado com o ID do item com falha (a execução foi abortada no meio, então `failed_set` pode ser parcial; inclua o item abortado mais tudo que estiver explicitamente FAIL ou BLOCKED no relatório parcial).
- **O evaluator não retorna nenhum item** (clean e zero itens, ex.: contrato com superfícies vazias) → o evaluator já deveria ter abortado por contrato malformado; se não abortou, trate como `success` (verdade vacuosa) e registre o soft-fail "evaluator returned zero items; verify contract has any items".
- **`prd_progress.json` fora do repositório ou ignorado pelo git** → os commits de artefatos dos Steps 7.2 e 7.6 seguem sem ele; registre o soft-fail. Sem o arquivo versionado, ele também não entra em conflito no Step 7.4.
- **Conflito no `prd_progress.json` com um dos lados sem parse** → a resolução mecânica do Step 7.4 não é possível; terminal `pr-blocked`.
- **Um hook de commit recusa o commit de artefatos (Step 7.2 ou 7.6)** → não contorne; cancele a criação do PR e finalize com `success` mais o aviso no chat report. Se a falha foi no 7.6, o Step 8.4 não tenta de novo e o Final Verdict já gravado fica sem commit.
- **O fluxo do PR para antes do Step 7.6 sem merge em andamento (falha do git no 7.3, status que deixa de ser `success` depois do 7.5)** → o Step 8.4 commita os artefatos restantes. Todos os commits da execução ficam na branch local sem push, como acontece com os commits de fase e de fix em qualquer status diferente de `success`.
- **`pr-blocked` com merge em andamento** → o Step 8.4 não commita; o merge fica para o usuário, e o chat report lista os paths dos artefatos restantes para entrarem no commit do merge.
