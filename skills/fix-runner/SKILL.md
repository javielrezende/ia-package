---
name: fix-runner
description: Passada corretiva direcionada sobre uma única feature. Use quando (1) um relatório de avaliação guiada por contrato (`eval-report-<ts>.md`) tem itens reprovados que precisam ficar verdes — lê a evidência expected/observed de cada item e edita implementação, fixtures, seeds, testes ou configs para resolvê-los; (2) um merge produziu conflitos na working tree — resolve os conflitos ou, se receber uma referência de PR, busca a branch base do PR, executa o merge e resolve os conflitos que aparecerem; ou (3) um relatório de design (`design-report-<ts>.md`, da skill `design-review`) lista correções de UI acionáveis — aplica as mudanças de apresentação sem tocar em comportamento. Valida pelos quality gates e testes do projeto e produz um commit por execução (`fix(F<ID>): cycle <N> — …` nas execuções guiadas por avaliação, `merge: …` nas de resolução de conflito, `style(F<ID>): design pass <N> — …` nas de design).
---

# Fix Runner

Passada corretiva direcionada para uma única feature. Opera em um de dois modos, selecionado automaticamente pelo formato do input:

- **Mode A — Fix evaluation failures.** Guiado por um `eval-report-<ts>.md` que lista itens reprovados, ou que registra um abort do evaluator na subida do ambiente (`aborted at step <N>`).
- **Mode B — Resolve merge conflicts (PR-aware).** Guiado por um merge já em andamento na working tree, ou por uma referência de PR (nesse caso a skill busca a base do PR, executa o merge e resolve os conflitos que aparecerem).
- **Mode C — Apply design fixes.** Guiado por um `design-report-<ts>.md` da skill `design-review`, que lista correções de UI acionáveis (`## Design fixes`). Aplica as mudanças visuais; o próximo `design-review` é o verificador canônico.

A skill não refaz o trabalho de implementação por fase que produziu a feature e não verifica o resultado dos itens por conta própria — o próximo ciclo de avaliação é o verificador canônico. Somente leitura sobre `contract.md`, `spec.md`, `plan.md`, o histórico de `eval-report-*.md` e quaisquer pastas de features irmãs. Só altera código de produção, testes, fixtures, seeds, configs e o objeto de commit (além do campo `cycles` descrito em **PROGRESS TRACKING**).

## INPUT

Free-form. O modo é selecionado pelo formato do input:

- `eval-report=` + `failed-items=` → **Mode A**.
- `pr=` ou `conflicted-files=` → **Mode B**.
- `design-report=` → **Mode C**.
- Campos de mais de um modo misturados → aborte nomeando os campos conflitantes.

### Campos do Mode A

- **feature** — ID da feature (`F03`), pasta, arquivo dentro da pasta ou nome fuzzy. Resolvido para uma pasta contendo `contract.md` + `spec.md` + `plan.md`.
- **eval-report** — path para o `eval-report-<ts>.md` com falha. Precisa existir e ficar dentro da pasta da feature resolvida.
- **failed-items** — lista de IDs de itens separados por vírgula ou espaço (`API-UPLOAD-03`, `UI-UPLOAD-01` etc.). Obrigatória e não vazia, **exceto** quando o `**Status:**` do relatório é `aborted at step <N>` (o evaluator não conseguiu levantar o ambiente e nenhum item foi exercitado). Nesse caso a lista pode vir vazia (`failed-items=`) e a skill trabalha a partir da seção `## Abort reason` do relatório. Com qualquer outro status, lista vazia → aborte nomeando o campo.
- **cycle** — inteiro ≥ 1 que identifica qual ciclo de retry é este. Usado na mensagem de commit. Default 1 se ausente.
- **progress-path** (opcional) — path para o `prd_progress.json` do projeto. Se omitido, a skill procura o arquivo conforme **PROGRESS TRACKING**.

Exemplos:

```
feature=F03 eval-report=docs/F03-video-upload/eval-report-2026-05-01T14-22-33Z.md failed-items=API-UPLOAD-03,UI-UPLOAD-01 cycle=2
```

```
Corrija a F03. Eval report em docs/F03-video-upload/eval-report-2026-05-01T14-22-33Z.md. Os itens API-UPLOAD-03 e UI-UPLOAD-01 falharam. Cycle 2.
```

```
feature=F03 eval-report=docs/F03-video-upload/eval-report-2026-05-01T15-02-10Z.md failed-items= cycle=3
```

### Campos do Mode B

- **feature** — mesma resolução do Mode A.
- **pr** (opcional, mutuamente exclusivo com `conflicted-files`) — `<URL|número|nome-da-branch>`. Quando presente, a skill busca os metadados do PR/MR pelo CLI do forge do projeto (veja `${CLAUDE_PLUGIN_ROOT}/references/forge.md` § 3.6), exige que a branch atual seja igual à branch de origem do PR/MR, executa `git merge` da branch de destino na branch atual e resolve os conflitos que aparecerem. O título e o corpo do PR/MR são mantidos como contexto para a resolução.
- **conflicted-files** (opcional, mutuamente exclusivo com `pr`; obrigatório quando `pr` está ausente) — lista de paths separados por vírgula ou espaço que contêm marcadores `<<<<<<<` / `=======` / `>>>>>>>`. Tipicamente obtida via `git diff --name-only --diff-filter=U`.
- **cycle**, **progress-path** — iguais ao Mode A.

Exemplos:

```
feature=F03 pr=42 cycle=2
```

```
feature=F03 conflicted-files=apps/web/lib/session.ts,apps/backend/src/main.ts cycle=2
```

### Campos do Mode C

- **feature** — mesma resolução do Mode A.
- **design-report** — path para o `design-report-<ts>.md`. Precisa existir e ficar dentro da pasta da feature resolvida.
- **fix-items** (opcional) — lista de IDs `DSG-<NN>` separados por vírgula ou espaço. Quando ausente, a skill aplica **todos** os fixes de severidade `blocker` e `major` do relatório e ignora os `minor`. Quando presente, aplica exatamente os IDs nomeados, em qualquer severidade.
- **cycle**, **progress-path** — iguais ao Mode A.

Exemplos:

```
feature=F03 design-report=docs/F03-video-upload/design-report-2026-05-01T16-40-02Z.md cycle=1
```

```
feature=F03 design-report=docs/F03-video-upload/design-report-2026-05-01T16-40-02Z.md fix-items=DSG-01,DSG-04 cycle=2
```

Se qualquer campo obrigatório do modo selecionado estiver ausente ou não puder ser resolvido → aborte nomeando o campo.

## OUTPUT

- 0 ou 1 commit na branch atual (commit apenas em caso de sucesso; em `gates-failed` a working tree fica suja para inspeção).
- **Chat report**:

```
Fix Runner — F<ID> cycle <N>

Status: fixed | gates-failed | aborted

Items targeted: <ID-1>, <ID-2>, ...        (Mode A)
Evaluator abort: step <N> — <motivo>        (Mode A com failed-items vazio)
PR: <ref> (<head> ← <base>)                 (Mode B com pr=)
Conflicted files: <lista>                   (Mode B)
Design fixes applied: <DSG-01>, <DSG-04>    (Mode C)
Design fixes skipped: <DSG-07> (<motivo>)   (Mode C)
Files touched: <lista>
Commit: <SHA> | (none)

Validation:
  Gates: ✓ | ✗ (attempt <N>/<budget>)
  Tests: ✓ | ✗ (attempt <N>/<budget>)

Soft-fails:
- <problema>

Abort reason (if any): <motivo>
```

Nenhum arquivo é gravado além de código/testes/fixtures/seeds/configs e do campo `cycles` no `prd_progress.json`. O chat report é efêmero; o commit (quando produzido) é o artefato durável.

---

## EXECUTION STEPS

### Step 1 — Resolve input

Faça o parsing do input como free-form. Detecte o modo pelos campos presentes (veja **INPUT**). Valide os campos do modo detectado e aborte com um motivo claro se algo estiver ausente, não resolvível ou contraditório entre os modos.

No Mode A, leia a linha `**Status:**` do eval-report já neste step: ela decide se `failed-items` vazio é aceito (apenas `aborted at step <N>`).

### Step 2 — Load context (Mode A)

Leia na íntegra:

- **`contract.md`** — foque no corpo dos itens em `failed-items`. Os itens são canônicos para o comportamento de fronteira que a correção precisa satisfazer (status codes, formato da resposta, side-effects persistidos, códigos de erro, labels de UI). Leia também os blocos `Common given:` das seções de superfície dos itens em escopo e a seção `## Prerequisites` (itens BLOCKED tipicamente referenciam uma de suas entradas). Leia a seção `## Quality gates`, quando presente.
- **`spec.md`** — apenas as seções que mapeiam para os itens alvo: as entradas da Seção 5 (`Component Overview`) que os itens referenciam, mais os trechos correspondentes da Seção 6 (`API Contracts`), da Seção 7 (`Data Model`) e da Seção 8 (`Error Handling`). Leia também a Seção 4 (`Technical Decisions & Assumptions`), que declara as convenções do projeto (mecanismo de seeding, path de fixtures, config de teste, fonte do schema, comando de migration). O spec é canônico para a **estrutura interna** (file paths, decomposição, nomenclatura).
- **O eval-report** no path informado — para cada ID de item com falha, extraia:
  - o `**Verdict:**` do item (FAIL / BLOCKED — qualquer outro é registrado como soft-fail e pulado);
  - o `expected` / `observed` de cada bullet `✗` e a narrativa `→ root cause:` quando presente;
  - o bloco `Evidence` (o `<details>` recolhido) — leia-o para obter bodies HTTP, resultados de consultas ao DB e trechos do DOM que fixam o comportamento real.

  Quando o `**Status:**` do relatório for `fail (gate <name>)`, leia também a seção `## Quality gates` do relatório (resultado por gate) e a seção `## Abort reason` (comando do gate que falhou, exit code e trecho do stderr).

  Quando o `**Status:**` do relatório for `aborted at step <N>` e `failed-items` vier vazio, não há itens para extrair: leia a seção `## Abort reason` (qual step, o que falhou, o que completou até ali) e as seções `## Discovery` e `## Pre-flight (Prerequisites)` do relatório, que mostram quais comandos o evaluator usou para instalar, migrar, semear e subir os serviços.

Não leia o `plan.md` — as fases não são relevantes para o fluxo de correção. Não leia pastas de features irmãs.

### Step 3 — Diagnose (Mode A)

Para cada item com falha, classifique pela superfície (o heading dentro de `## Items` do eval-report). A classificação aponta a correção para a camada mais provável:

| Surface | Local mais provável da correção |
|---|---|
| Service | use-case / lógica de domínio — backend |
| HTTP API | route handler, DTO, validação, mapper, repository — backend |
| CLI | entrada do comando — onde quer que o projeto hospede a CLI |
| Worker | handler de fila, job runner — backend |
| Event | listener, dispatcher — backend |
| UI | component, page, form, client — frontend |
| E2E | composição envolvendo UI + backend |

**Itens BLOCKED por falha de gate** (`BLOCKED — run aborted at gates: <name>`, com relatório em `fail (gate <name>)`): a causa não é um Prerequisite nem o item em si — nenhum item foi exercitado. Diagnostique pelo gate que falhou: o comando, o exit code e o stderr registrados em `## Quality gates` e `## Abort reason` do relatório. O alvo da correção é o que o gate acusa (erro de tipo, violação de lint, regra de arquitetura, teste quebrado etc.). Os itens voltam a ser exercitados no próximo ciclo de avaliação, depois que o gate ficar verde.

**Demais itens BLOCKED**: a falha costuma ser um Prerequisite ausente ou malformado. Inspecione qual subseção ele consumiu (Persistent state / Static inputs / Configuration / Runtime services / External dependencies) e ataque esse artefato, seguindo a convenção do projeto registrada na Seção 4 do `spec.md` ou já presente na codebase:

- Seed ausente / atributos de seed errados → edite o mecanismo de seeding do projeto (ex.: `prisma/seed.*`, factories, setup hooks).
- Fixture ausente ou inválida → escreva/repare no path que o contrato nomeia (ex.: `apps/backend/tests/fixtures/...`).
- Default de config errado → corrija o arquivo de config de exemplo e/ou de teste do projeto (ex.: `.env.example`, `.env.test`).
- Divergência de schema → edite a fonte do schema do projeto (ex.: `prisma/schema.prisma`); aplicar a migration pode ser interativo, veja o Step 4.

**Abort do evaluator na subida do ambiente** (`failed-items` vazio, relatório em `aborted at step <N>`): diagnostique pelo `## Abort reason`. Casos típicos: instalação de dependências quebrada, migration que falha, seed que explode, serviço que não sobe ou não passa no health-check. Ataque a causa na implementação, na migration, no seed ou na config — não no ambiente do evaluator.

Um FAIL com `expected 201 / observed 500` tipicamente aponta para uma exceção em runtime — leia o body de erro no bloco Evidence e rastreie até a implementação. Um FAIL com `expected 201 / observed 404` aponta para uma rota ausente ou um path errado.

### Step 4 — Edit (Mode A)

Aplique o menor conjunto de edições que plausivelmente satisfaça os itens (ou elimine a causa do abort / do gate), tratando os itens do `contract.md` como canônicos para o comportamento observável e o `spec.md` para a estrutura interna. Quando o spec contradiz um item sobre uma propriedade observável externamente, siga o item.

**As convenções do projeto são autoritativas.** Antes de editar, respeite as regras que o próprio projeto documenta (em `CLAUDE.md`, `harness/`, `README*` ou qualquer documentação que o projeto use por convenção) sobre quais regras de camadas, design systems ou padrões de código valem para quais tipos de artefato. O fix-runner é agnóstico de projeto — segue o que o projeto declara; não enumera essas regras.

**Testes** — só edite testes existentes quando eles afirmam um formato desatualizado (ex.: um unit test preso a um schema de resposta antigo que o contrato depois esclareceu). Não adicione testes novos nesta skill — as asserções canônicas vivem nos itens do `contract.md` e são exercitadas pelo próximo ciclo de avaliação.

**Migrations** — se for necessária uma mudança de schema, edite a fonte da verdade do schema do projeto (o arquivo ou DSL que o projeto usa — descubra pela Seção 4 do `spec.md` ou pela documentação do projeto). Não rode nenhum comando de migration interativo que bloquearia esperando input do usuário; registre um soft-fail nomeando o comando de migration que o usuário (ou quem chamou a skill) precisa rodar depois que esta skill terminar.

### Step 5 — Validate

Rode os quality gates e os testes. **Descubra os dois comandos a partir do projeto — não os fixe no código.**

- **Gates** — leia a seção `## Quality gates` do contrato e execute o comando literal de cada entrada. Se o contrato não tiver seção `## Quality gates`, use o que a documentação do projeto (`CLAUDE.md`, `harness/`, `README*`) nomeia como runner de gates; se nada estiver declarado em lugar nenhum, registre o soft-fail "no gates declared in contract or project docs; skipping gate validation" e prossiga para os testes.
- **Testes** — descubra o comando pelos manifests/scripts do projeto (`package.json`, `Makefile`, `Taskfile`, `pyproject.toml` etc.).

**Retry budget interno: 3 tentativas com gates ou testes vermelhos.** Cada tentativa: leia a falha, ajuste a edição, rode de novo. O budget é compartilhado entre gates e testes.

Se o budget se esgotar com gates ou testes ainda vermelhos:
- Status = `gates-failed`.
- Sem commit. A working tree fica suja para inspeção.
- Reporte o que foi tentado.

Se gates e testes ficarem verdes dentro do budget, prossiga para o commit.

**Falhas pré-existentes** (vermelhas na entrada, não atribuíveis às edições desta execução) não contam para o budget. Registre em `Soft-fails`. Prossiga para o commit se todo o resto estiver verde.

**Exceção — gate que causou o `fail (gate <name>)`:** quando a execução foi disparada por um relatório nesse status, o gate `<name>` nunca é tratado como falha pré-existente, mesmo estando vermelho na entrada. Ele é o alvo da correção: precisa ficar verde dentro do budget para haver commit; caso contrário, o status é `gates-failed`.

### Step 6 — Commit

Faça o stage **apenas dos arquivos que esta execução tocou**. Nunca faça stage do `prd_progress.json`, de `eval-report-*.md` nem de `eval-screenshots-*/` — o commit desses artefatos não é responsabilidade desta skill. Faça o commit com:

```
fix(F<ID>): cycle <N> — address items <ID-1>, <ID-2>, ...
```

Quando `failed-items` veio vazio (abort do evaluator na subida do ambiente):

```
fix(F<ID>): cycle <N> — address evaluator abort at step <N>
```

Faça o match com o estilo recente de commit-message do projeto inspecionando as últimas ~10 mensagens (capitalização, convenções de escopo). Ajuste o template se o projeto divergir.

Restrições: stage por nome de arquivo apenas (nunca `git add -A` / `git add .`); não pule hooks (`--no-verify`); não faça amend de commits anteriores; não faça push; não crie nem troque de branch. Um commit por invocação. Se um hook de commit falhar, corrija o problema de fundo e faça o stage de novo; não contorne.

### Step 7 — Report

Imprima o chat report mostrado em OUTPUT, preenchido com os valores reais desta execução. Status:

- `fixed` — gates verdes, testes verdes, commit produzido.
- `gates-failed` — budget interno esgotado com gates ou testes vermelhos; sem commit; working tree suja.
- `aborted` — pre-flight falhou ou um handler de EDGE CASES disparou um abort; working tree limpa; sem commit.

---

### Step 8 — Mode B (resolve merge conflicts)

Quando o Step 1 detectar o Mode B, siga este fluxo em vez dos Steps 2–7.

**Inicie o merge, se necessário.** Quando `pr=<ref>` foi informado:

1. Resolva o forge do projeto (`github` | `gitlab`) conforme `${CLAUDE_PLUGIN_ROOT}/references/forge.md` (seções 1 e 2) e busque os metadados do PR/MR com a operação **"ver metadados de um PR/MR"** (§ 3.6), usando o mapeamento de campos de lá — o corpo é `body` no GitHub e `description` no GitLab. Aborte se o CLI do forge estiver ausente ou não autenticado, se o PR/MR não existir ou se o estado dele não for aberto (`OPEN` no GitHub, `opened` no GitLab — aceite os dois literais).
2. Verifique se a branch atual é igual à **branch de origem** do PR/MR (`headRefName` no GitHub, `source_branch` no GitLab). Se não for, aborte com `"PR head is <X>; current branch is <Y> — refusing to switch branches"`.
3. Verifique se a working tree está limpa. A checagem considera **apenas arquivos versionados** (arquivos não versionados, como `eval-report-*.md` e `eval-screenshots-*/`, não contam) e **ignora o `prd_progress.json`** (que esta própria skill acabou de alterar ao incrementar `cycles`). Se houver qualquer outra mudança em arquivo versionado, aborte listando os paths no motivo.
4. `git fetch origin <branch-de-destino>` e `git merge origin/<branch-de-destino>` (`baseRefName` no GitHub, `target_branch` no GitLab).
5. Se o merge terminou limpo (sem marcadores na working tree), pule direto para **Commit** com a variante limpa.

Quando `conflicted-files=<lista>` foi informado, verifique que `.git/MERGE_HEAD` existe e que todo path do input está atualmente em `git diff --name-only --diff-filter=U`. Se o estado do merge não bater, aborte descrevendo a inconsistência.

**Carregue o contexto.** Leia os itens do `contract.md` (focados nas superfícies às quais os arquivos em conflito pertencem) e as seções relevantes do `spec.md`: a Seção 3 (`Impacto na Architecture`) e a Seção 5 (`Component Overview`). Descubra o conjunto canônico de conflitos via `git diff --name-only --diff-filter=U` — ele é autoritativo; se `conflicted-files=` foi informado e diverge, registre soft-fail e prossiga com o conjunto descoberto. Leia cada arquivo em conflito com os marcadores no lugar; leia os dois lados de cada bloco `<<<<<<< / ======= / >>>>>>>`. Quando `pr=` foi usado, o título e o body do PR fazem parte desse contexto — eles descrevem a intenção do lado que está entrando.

**Resolva.** Para cada arquivo em conflito, edite para remover os marcadores e produzir uma versão mesclada coerente. Regras de resolução, em ordem:

1. **A intenção do spec/contrato vence.** Quando os dois lados discordam sobre algo que o spec ou o contrato fixa (uma assinatura de função, o path de uma rota, uma coluna de schema), siga o que o spec/contrato diz.
2. **Merges aditivos se combinam.** Quando os dois lados adicionam a uma lista (imports, definições de rota, campos de schema) sem entradas sobrepostas, faça a união — as duas adições, sem duplicatas.
3. **Mudanças conflitantes na mesma linha:** prefira o lado da branch da feature (o lado em que quem chamou esta skill está trabalhando). Documente a escolha no body do commit.
4. **Genuinamente irreconciliável** (intenções incompatíveis, contrato não fixa): aborte com o motivo `"unresolvable conflict in <file>: <descrição de uma linha>"`. Não produza uma meia-resolução.

**As convenções do projeto são autoritativas** — mesma regra do Step 4 do Mode A. O resultado mesclado precisa estar conforme por construção (regras de arquitetura para artefatos de backend, regras de design system para artefatos de frontend etc.), não corrigido depois que os gates falharem.

Depois de resolver todos os arquivos, faça `git add` de cada um. Nunca faça stage do `prd_progress.json`, de `eval-report-*.md` nem de `eval-screenshots-*/`.

**Valide** do mesmo jeito que no Step 5 (gates + testes com budget de 3 tentativas). Se a validação não ficar verde dentro do budget, reporte `gates-failed`; não faça commit; o merge fica em andamento para inspeção humana.

**Commit.** Duas variantes:

- **Conflitos resolvidos:**
  ```
  merge: resolve conflicts from <base> into <head> (cycle <N>)

  Resolved files:
  - <path>
  - <path>
  ```
- **Merge limpo do PR** (nenhum conflito surgiu):
  ```
  merge: bring <base> into <head> (cycle <N>) — clean
  ```

Na variante limpa, o `git merge` já produziu um merge commit padrão antes deste step — ajuste a mensagem dele para o formato acima (ex.: `git commit --amend`).

**Reporte** no mesmo formato do Step 7, com `Items targeted` substituído por `Conflicted files: <lista>` (e a linha opcional `PR:` quando `pr=` foi usado). `fixed` significa que o merge foi concluído e commitado.

---

### Step 9 — Mode C (apply design fixes)

Quando o Step 1 detectar o Mode C, siga este fluxo em vez dos Steps 2–7.

**Carregue o contexto.** Leia o `design-report-<ts>.md` informado e extraia:

- A linha `**Calibration:**` — `design-system` significa que as correções precisam usar os tokens e componentes existentes do projeto; `greenfield` dá mais liberdade.
- A seção `## Design fixes`, lida por título literal: cada bloco `### DSG-<NN>` até a próxima seção `##`. De cada bloco, leia `Severity`, `Dimension`, `Evidence`, `Observed` e `Change`.
- A seção `## Mechanical floor` — todo `✗` em M1–M6 é um blocker de acessibilidade e tem prioridade sobre qualquer fix estético.

Selecione os fixes a aplicar: os IDs de `fix-items=` quando informado; caso contrário, todos os `blocker` e `major`. Se a seleção ficar vazia (relatório sem fixes, ou `fix-items=` nomeando IDs inexistentes), aborte com `"no applicable design fixes in <report>"`.

Leia também os artefatos de design do projeto antes de editar: tokens, tema, biblioteca de componentes e as telas irmãs já existentes. **Uma correção que resolve o achado introduzindo um valor hardcoded fora do sistema não é uma correção** — troca um achado por outro que o próximo `design-review` vai registrar como desvio.

**Aplique.** Um fix por vez, na ordem do relatório (blockers primeiro). Para cada um:

1. Localize o elemento pela `Evidence` (seletor ou região) e pelo componente correspondente na codebase.
2. Aplique a mudança descrita em `Change`, expressa nos tokens e nas convenções do projeto.
3. Se o `Change` não for aplicável como escrito (o componente é de terceiros e não aceita a prop, o token não existe, a mudança brigaria com uma tela irmã), **pule o fix** e registre em `Design fixes skipped` com o motivo. Não improvise uma variante distante do que foi pedido.

**Anti-escopo.** O Mode C altera apresentação: estilos, classes, tokens, markup de layout, copy de estados vazios/erro, atributos de acessibilidade. **Não altera lógica de negócio, chamadas de API, schema nem os itens do `contract.md`** — se um fix parece exigir isso, ele está mal especificado: pule e registre. Um design pass jamais pode regredir um item que o `evaluator` já deu como verde.

**Valide** do mesmo jeito que no Step 5 (gates + testes com budget de 3 tentativas). Uma regressão nos testes aqui quase sempre significa que uma asserção dependia de um seletor ou de um texto que o fix mudou: atualize a asserção quando o teste estiver acoplado à apresentação, e reverta o fix quando ele tiver de fato quebrado comportamento.

**Commit.**

```
style(F<ID>): design pass <N> — apply <DSG-01>, <DSG-04>
```

Mesmas restrições do Step 6: stage por nome de arquivo, sem `--no-verify`, sem amend, sem push, um commit por invocação. Nunca faça stage de `design-report-*.md` nem de `design-screenshots-*/`.

**Reporte** no formato do Step 7, com `Items targeted` substituído por `Design fixes applied` e `Design fixes skipped`. `fixed` significa que ao menos um fix foi aplicado e commitado com gates e testes verdes.

**A verificação é do `design-review`.** Esta skill não repontua a tela nem declara o achado resolvido — a próxima execução do `design-review` é o verificador canônico, exatamente como o `evaluator` é no Mode A.

---

## PROGRESS TRACKING

Esta skill incrementa o contador `cycles` num arquivo compartilhado `prd_progress.json` a cada execução, restrito à entrada da target feature. O arquivo é o registro determinístico do estado das features ao longo do pipeline `implement-feature` → `evaluator` → `fix-runner`. O schema é canônico na skill `prd-writer-for-complete-project` (seção "SCHEMA DO ARQUIVO DE PROGRESSO"); esta seção documenta apenas as escritas desta skill.

**Localizando o arquivo** (na ordem; o primeiro encontrado vence):

1. Se o input contiver `progress-path=<path>`, use-o.
2. Procure a partir da pasta da feature resolvida no Step 1 para cima (máximo 4 níveis) pelo `prd_progress.json` mais próximo. O `prd-writer-for-complete-project` grava o arquivo ao lado do PRD por padrão, e as pastas de feature ficam ao lado do PRD (ex.: `docs/F03-video-upload/` → `docs/prd_progress.json`).
3. Procure a partir do CWD para cima (máximo 4 níveis) pelo `prd_progress.json` mais próximo.

Se não for encontrado, registre em `Soft-fails` a linha "progress file not found, cycles not tracked" e prossiga. O trabalho de correção nunca é bloqueado pelo tracking.

**Regra de escopo:** nunca toque na entrada de qualquer feature que não seja a target feature. Nunca modifique os campos de primeiro nível (`schema_version`, `prd_path`, `generated_at`). Nunca modifique `status` — esse campo é gravado por outros steps do workflow; esta skill é neutra em relação ao status.

**Modos de falha — continuação silenciosa:**

- Arquivo não encontrado, falha no parse, ou feature ID ausente como chave em `features` → registre em `Soft-fails`, pule a escrita.
- Escrita atômica falha → registre em `Soft-fails`, pule.

**Escrita — uma vez por execução, depois que o Step 1 tiver sucesso, qualquer que seja o modo ativo:**

Ler → modificar apenas a entrada da target feature → escrita atômica (`.tmp` + rename) do JSON inteiro. Timestamps são RFC 3339 UTC.

- `cycles` ← `cycles` anterior + 1 (leia primeiro, incremente, grave de volta)
- `updated_at` ← now
- Todos os outros campos intocados (incluindo `status`, `failure_reason`, `report_path`, `started_at`, `completed_at`).

O incremento acontece no **início** do trabalho, não no final. Uma execução que resolveu seus inputs se comprometeu a tentar o trabalho; os recursos do ciclo são considerados consumidos mesmo que a validação falhe depois (`gates-failed`) ou que um edge case aborte a execução.

**Nota sobre o input `cycle` vs o campo `cycles` do JSON:** são independentes. O input `cycle` é um rótulo para a mensagem de commit (`fix(F<ID>): cycle <N> — ...`), passado por quem chama e refletindo a contagem do loop de quem chama. O `cycles` do JSON é a contagem acumulada de execuções do fix-runner já feitas sobre esta feature, mantida por esta skill independentemente do `cycle` informado. Tipicamente coincidem no uso orquestrado, mas podem divergir no uso standalone; isso é intencional.

---

## RULES

**Sempre:**

- Resolva a referência da feature por ID, pasta, arquivo dentro da pasta ou nome fuzzy.
- No Mode A, exija um path de `eval-report-<ts>.md` que exista e fique sob a pasta da feature resolvida.
- No Mode A, exija `failed-items` não vazio, exceto quando o `**Status:**` do relatório for `aborted at step <N>`; nesse caso, trabalhe a partir de `## Abort reason`.
- Leia na íntegra os itens do `contract.md` dos IDs com falha antes de editar — os itens são canônicos para o comportamento de fronteira.
- Aplique o desempate items-vs-spec: itens vencem no comportamento observável; o spec vence na estrutura interna.
- Respeite a governança documentada do projeto para os tipos de artefato sendo editados.
- Descubra os comandos de validação em runtime: gates pela seção `## Quality gates` do contrato (ou pela documentação do projeto, se ausente), testes pelos manifests/scripts do projeto.
- Quando o relatório estiver em `fail (gate <name>)`, trate o gate `<name>` como alvo da correção: ele precisa ficar verde para haver commit.
- No Mode C, leia a `**Calibration:**` do design-report e os tokens/componentes do projeto antes de editar; expresse toda correção no vocabulário do design system existente.
- No Mode C, pule e registre qualquer fix que não seja aplicável como escrito, em vez de improvisar uma variante.
- Faça stage apenas de arquivos específicos ao commitar.
- Produza exatamente um commit por invocação bem-sucedida, na branch atual.
- Pare no retry budget interno (default 3) e reporte `gates-failed` em vez de commitar uma árvore vermelha.
- Incremente `cycles` no `prd_progress.json` conforme **PROGRESS TRACKING**, uma vez por execução.

**Nunca:**

- Modifique `contract.md`, `spec.md` ou `plan.md`. Eles são inputs.
- Modifique `status`, `failure_reason`, `report_path`, `started_at` ou `completed_at` no `prd_progress.json`. Só `cycles` e `updated_at` são gravados.
- Modifique qualquer entrada de feature no `prd_progress.json` além da entrada da target feature. Nunca modifique os campos de primeiro nível.
- Modifique pastas de outras features. A skill é restrita à feature.
- Modifique qualquer `eval-report-*.md` ou `design-report-*.md` anterior.
- Faça stage do `prd_progress.json`, de `eval-report-*.md`, de `eval-screenshots-*/`, de `design-report-*.md` ou de `design-screenshots-*/`.
- No Mode C, altere lógica de negócio, chamadas de API, schema ou o `contract.md` para satisfazer um fix estético. Um design pass nunca regride um item que o `evaluator` já deu como verde.
- No Mode C, repontue a tela ou declare um achado resolvido. O verificador canônico é a próxima execução do `design-review`.
- Crie / troque / apague branches. Faça push. Abra PRs.
- Pule git hooks (`--no-verify`) ou contorne assinatura.
- Adicione testes novos. Asserções novas pertencem ao contrato.
- Insira stubs de serviços externos em código de produção. Stubs de teste são aceitáveis quando a infra de testes do projeto já os suporta.
- Rode um ciclo de avaliação completo ou a suite e2e completa como substituto da validação direta por gates + testes.
- Trate como falha pré-existente o gate que causou o `fail (gate <name>)` do relatório.
- Use `git add -A` ou `git add .`.

---

## OVERRIDES

Overrides free-form reconhecidos:

- `max <N> retries` — ajusta o retry budget interno de gates. Default 3.
- `dry-run` — aplica as edições mas pula o step de commit. Working tree suja para revisão humana.
- `skip gates` — pula a fase de gates; só os testes rodam. Use apenas quando os gates já estão vermelhos na entrada e quem chama quer uma tentativa de correção mesmo assim.

Overrides não reconhecidos ou contraditórios → o default vence; registre em `Overrides ignored` no chat report.

---

## EDGE CASES

- **O path do eval-report aponta para uma feature diferente da `feature` resolvida** — aborte: "eval-report belongs to `<other-feature>`; refusing to mix".
- **Um item de `failed-items` não está presente no eval-report** — registre em `Soft-fails` ("item `<ID>` not in report; skipped") e continue com os demais. Não aborte, a menos que a lista inteira fique vazia.
- **`failed-items` vazio com relatório em `aborted at step <N>`** — caso válido: diagnostique pelo `## Abort reason` (Steps 2–3) e commite com a variante `address evaluator abort at step <N>`. Com qualquer outro status, lista vazia é campo obrigatório ausente → aborte.
- **Relatório em `fail (gate <name>)`** — todos os itens estão `BLOCKED — run aborted at gates: <name>`. Diagnostique pelo gate que falhou (Step 3), não pelos Prerequisites; o gate precisa ficar verde no Step 5 para haver commit.
- **Todos os itens alvo são `MANUAL`** — aborte: "all targeted items are subjective (`MANUAL`); fix-runner can't auto-fix manual items".
- **O path do design-report aponta para outra feature** — aborte: "design-report belongs to `<other-feature>`; refusing to mix".
- **Design-report em `pass` sem nenhum fix** — aborte: "no applicable design fixes in `<report>`". Não é falha; é alvo errado.
- **Fix de design exigiria mudar comportamento** (ex.: `Change` pede paginação onde não há endpoint) — pule, registre em `Design fixes skipped` com o motivo e siga. O caminho certo é uma mudança de contrato via `spec-writer`, não uma edição escondida num design pass.
- **Todos os `failed-items` estão BLOCKED no mesmo Prerequisite** — corrija o Prerequisite uma vez; a correção provavelmente desbloqueia todos numa única edição.
- **A correção exigiria modificar `contract.md` / `spec.md` / `plan.md`** — aborte: "the fix would require contract/spec/plan changes; that is a feature-triple revision, not a corrective pass. Re-author the triple and re-invoke."
- **Mudança de schema necessária** — edite a fonte do schema do projeto (Seção 4 do `spec.md` ou documentação do projeto) e registre um soft-fail orientando o usuário a rodar o comando de migration do projeto (descoberto na Seção 4 do `spec.md`, em `CLAUDE.md` / `harness/` / `README*` ou nos manifests) depois que esta skill terminar. Não tente rodar a migration se o comando for interativo.
- **Working tree suja no início (Mode A)** — prossiga; o commit faz stage apenas dos arquivos que esta execução tocou. Arquivos que já estavam sujos continuam sujos. Registre "pre-existing dirty files: `<lista>`" em `Soft-fails`.
- **Nenhuma mudança de código parece necessária** (ex.: a falha foi flaky) — aborte com status `aborted` e motivo "no edits identified; the failure may be flaky. Re-invoke evaluation without a fix cycle."
- **Comandos de validação não descobríveis** — registre cada comando ausente em `Soft-fails`. Se gates e testes estiverem ambos ausentes, aborte: "no validation commands available; can't verify the fix would not regress".
- **Falhas de teste pré-existentes** — registre em `Soft-fails`; não contam para o retry budget; não bloqueiam o commit.
- **A evidência de um item com falha é um erro de rede/transporte** em vez de uma falha HTTP — o serviço provavelmente não subiu durante a avaliação anterior. Olhe para a implementação como se o serviço estivesse quebrado (provavelmente uma exceção na inicialização ou numa rota).
- **O eval-report é mais antigo que o HEAD** — registre o soft-fail "eval-report is older than HEAD; some failures may already be resolved", mas continue.
