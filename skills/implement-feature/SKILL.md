---
name: implement-feature
description: Implementa uma feature de forma autônoma com base em seu spec e plan, fazendo um commit por fase e reportando os resultados em relação aos acceptance criteria da feature.
---

# Implement Feature

Implementa de forma autônoma uma feature a partir de seus arquivos `spec.md` + `plan.md` existentes. A skill faz o parsing da technical specification e do implementation plan da feature, escreve o código fase por fase, valida cada fase, faz o commit e reporta os resultados em relação aos acceptance criteria declarados no PRD.

## INPUT

Free-form. A skill descobre o que foi passado. Qualquer combinação funciona:

- Um identificador de feature: `F09`, `Video Upload` ou similar.
- Uma pasta de feature: `docs/F09-in-video-transcription-search/`, `./F09/`, etc.
- Um arquivo dentro da pasta da feature: `docs/F09-in-video-transcription-search/spec.md`.
- Um path para o PRD: `@docs/PRD.md`, `docs/PRD.md`, `@PRD.md`.
- Instruções extras em linguagem natural adicionadas em qualquer lugar (veja **Overrides**).

A skill só precisa localizar dois arquivos e uma fonte de referência:

1. **`spec.md` e `plan.md`** para a target feature. Se o input apontar para uma pasta, procure dentro. Se apontar para um arquivo, procure em sua pasta pai (parent folder). Se apontar para um ID ou nome, pesquise em `docs/` por uma pasta que corresponda a `<ID>-*` ou cujo nome seja o kebab-case do nome fornecido.
2. **O PRD**. Se passado explicitamente, use-o. Caso contrário, faça um auto-discover: `docs/PRD.md` → `PRD.md` → qualquer `*.md` no top-level cujo conteúdo se pareça com um product spec. Se nenhum for encontrado, aborte. Se vários forem plausíveis, aborte e liste-os.

## OUTPUT

- **Commits**: um por fase do `plan.md`, na branch atual (sem criação de branch, sem branch switching).
- **Chat report** no final: o checklist de acceptance-criteria da feature marcado com ✓ / ✗ / — em relação aos resultados reais dos testes, mais seções para Deviations, Soft-fails, Pre-existing failures, Overrides applied, Overrides ignored e Phase status.

Nenhum arquivo é gravado além das alterações de código e objetos de commit. O chat report é efêmero.

---

## EXECUTION STEPS

### Step 1: Resolve Input

Faça o parsing de todo o input como free-form. Extraia:

- **Feature reference**: o primeiro token que se resolve para uma pasta contendo `spec.md` + `plan.md`. Matches: padrões de ID como `F\d+`, paths de pastas, paths de arquivos (parent folder = target), nomes de features (kebab-case + fuzzy match com nomes de pastas sob `docs/`).
- **PRD reference**: um path explícito de `*.md` prefixado com `@` ou escrito literalmente; se parecer um PRD (conteúdo de product spec no topo), aceite. Caso contrário, faça o auto-discover.
- **Extra instructions**: qualquer texto restante que não seja um path/ID/nome — trate como overrides em linguagem natural (Step 3).

Se a resolução falhar:

- Nenhum `spec.md` ou `plan.md` na pasta resolvida → aborte: "spec.md/plan.md missing in `<folder>`."
- Nenhum PRD encontrado → aborte: "No PRD found. Pass the path explicitly."
- Múltiplos PRDs plausíveis → aborte e liste os candidatos.
- Feature reference ambígua (múltiplas pastas dão match) → aborte e liste os candidatos.

### Step 2: Load Context

Leia na íntegra:

- `spec.md` da target feature — Component Overview, Data Model, API Contracts, Business Rules, UX Flows, Error Handling, Testing Strategy, Assumptions/Decisions.
- `plan.md` — fases e steps em ordem.
- **O conteúdo de acceptance-criteria do PRD para esta feature** — localize-o semanticamente, não por número de seção. Títulos típicos: "Acceptance Criteria", "Critérios de Aceitação", "AC". Inclua também o bloco "Non-Functional Acceptance", quando presente. Formato típico: uma checkbox list `- [ ]` com escopo na feature (por ID ou nome). Localize também qualquer checklist de cross-feature/integration que referencie esta feature. NÃO assuma um número de seção fixo — encontre o conteúdo por seu formato (shape).

Se o PRD não tiver conteúdo de acceptance-criteria para esta feature, prossiga com um AC checklist vazio e anote isso em soft-fails.

NÃO explore a codebase de forma eager (antecipada). Abra os arquivos de forma lazy (sob demanda) conforme cada fase exigir.

### Step 3: Apply Overrides

Interprete instruções extras como overrides em linguagem natural sobre os defaults:

| Default | Example overrides |
|---|---|
| Hard-fail retry limit = 3 | "no retry limit", "max 5 tries" |
| Totalmente autônomo (Fully autonomous) | "pause between phases" — a skill espera no chat por uma resposta contendo `ok`, `continue`, `segue`, `yes`, ou similar |
| 1 commit por fase | "single commit at the end", "no commits, just implement" |
| Rodar linter + typecheck + testes | "skip tests", "skip lint", "skip typecheck" |
| Implementar todas as fases | "only phases 1 and 2", "skip phase 3" — as posições das fases são ordinais; labels como `A/B/C` mapeiam para `1/2/3` |
| Abortar testes em caso de dependência externa ausente (external dep missing) | "stub missing services", "assume empty response for missing APIs" — substitui por stubs **APENAS no código de teste (test code)**, nunca em production modules |

Para cada override reconhecido, registre o antes/depois para a seção "Overrides applied" do chat report final.

**Immutable core (não pode sofrer override):** o AC checklist final e sua traceability com o PRD. Instruções que desabilitariam o report são logadas em "Overrides ignored" com o motivo.

Instruções ambíguas ou contraditórias → o default vence; logado em "Overrides ignored" com "ambiguous, kept default".

### Step 4: Pre-flight Dependency Check

Localize o grafo de dependências ENTRE FEATURES no PRD semanticamente (título típico: "Dependency Graph", normalmente dentro de "Appendix A: Implementation Planning"; formato típico: uma tabela pareando cada feature com seus prerequisites por ID). NÃO confunda com a seção de negócio "Dependencies" (fornecedores, times, exigências legais) — essa não descreve prerequisites de implementação e não deve ser usada aqui. Para cada dependência listada da target feature, verifique se ela parece implementada na codebase (procure pelos arquivos característicos descritos no Component Overview do `spec.md` da própria dependência, ou marcadores óbvios no source-level).

- Qualquer dependência ausente → **aborte antes de qualquer implementação**. Reporte: "F<target> depends on F<N>, which is not implemented yet."
- Todas as dependências presentes → prossiga para o Step 5.

Se o PRD não tiver conteúdo de dependência, faça o skip deste passo.

### Step 5: Execute Phases

Para cada fase do `plan.md`, em ordem:

**5.1 — Skip if already done**

Inspecione os últimos ~20 commits na branch atual. Se a mensagem de algum commit indicar que esta exata fase já rodou (mesmo feature ID + nome da fase ou ordinal), faça o skip da fase com o status `— already committed` e siga em frente. A detecção é best-effort: faça o match no feature ID mais o nome normalizado da fase ou o phase index.

**5.2 — Implement**

Leia as seções do `spec.md` relevantes para a fase. Edite/crie os arquivos para cumprir os steps da fase.

**O que conta como "done" para uma fase** — tudo a seguir, e não apenas "eu escrevi o código":

- Cada arquivo listado para esta fase no Component Overview do `spec.md` existe e contém o conteúdo descrito.
- Cada contrato (API, schema, function signature) descrito para esta fase dá match com o que foi escrito.
- O passo de Validation em 5.3 passa (hard fails resolvidos).
- Se a fase produzir comportamento em runtime que não é coberto por unit tests (UI pages, server routes, migrations, CLI commands), de fato o exercite antes de declarar como done: rode o dev server / build / migration / command contra um ambiente local e confirme que ele se comporta como o esperado. Se o ambiente não puder ser levantado nesta execução (run), faça o log do runtime-check sob `Soft-fails` — NÃO declare silenciosamente que a fase está done.

Escrever código sem rodar não é "done". Declarar conclusão sem atender ao checklist acima é uma violação do contrato da skill.

Faça adaptações quando a realidade divergir do spec (coluna chamada `pinned` no DB vs `isPinned` no spec, nome de arquivo de component diferente, path ligeiramente diferente, types estruturalmente compatíveis). Specs nunca são 100% fiéis à realidade — adaptação é esperada. Registre cada adaptação em uma lista de `Deviations` para o chat report final. NÃO aborte em pequenas divergências.

**Aborte o run inteiro apenas em:**

- Dependency feature ausente (geralmente pega no Step 4; se descoberta em mid-phase, aborte aqui).
- Hard fail que ultrapasse o retry limit no Step 5.3 abaixo.

Dependências externas ausentes necessárias apenas por *testes* (ex: `OPENAI_API_KEY` indisponível) NÃO abortam o run — elas causam um soft-fail no teste afetado. O código de implementação que chama o serviço ainda é escrito.

**5.3 — Validate**

Descubra os comandos de validação em runtime: inspecione os `scripts` do `package.json`, ou para stacks não-Node inspecione o equivalente (`Makefile`, `pyproject.toml`, `Cargo.toml`, `vitest.config.*`, `jest.config.*`). Rode os que estiverem disponíveis.

- **Hard fail** = saída (exit) não-zero do linter, typecheck ou unit tests, onde a falha é atribuível ao código que este run alterou. Faça o retry até o limite configurado (default 3). Cada retry lê o erro, ajusta o código e roda novamente (re-runs). Após o limite, aborte o run inteiro e vá para o Step 6.
- **Soft fail** = a validação não pode ser executada neste ambiente (e2e exigindo browser/server não presente; integration test exigindo uma credencial externa não definida; suite marcada explicitamente como non-runnable; command not found). Faça o skip, faça o log sob `Soft-fails` e prossiga.
- **Pre-existing failure** = a validação falha, mas a falha não é atribuível ao código que este run alterou (tocou em arquivos não relacionados, já existia na branch antes deste run). Faça o log sob `Pre-existing failures`, NÃO desconte do retry budget e prossiga.

Warnings sem saída não-zero (non-zero exit) nunca são falhas.

**5.4 — Commit**

Se a validação passou (todos os hard fails resolvidos; restam apenas soft fails e pre-existing failures), faça o stage apenas dos arquivos que esta fase tocou e faça o commit com uma mensagem resumindo a fase. Faça o match com o estilo de commit do projeto inspecionando as últimas ~10 commit messages. Fallback: `feat(F<ID>): <phase name>`.

Faça o stage apenas de arquivos específicos (nada de `git add -A` / `git add .`). Faça o commit na branch atual. Não pule (skip) os hooks.

Se um override desabilitou commits, faça o skip deste sub-step e mantenha as mudanças na working-tree.

**5.5 — Proceed**

Passe para a próxima fase. Um abort em nível de run (hard fail passando do retry limit, dependência ausente em mid-phase) interrompe a execução e vai para o Step 6 com quaisquer fases já "commitadas".

### Step 6: Final Verification

Após o commit da última fase (ou quando o run foi abortado), rode um verification pass independente sobre toda a feature antes de escrever o report. Esse step existe porque checagens per-phase podem deixar passar regressions, e porque IAs comumente declaram "done" quando não está.

Execute todos os passos a seguir — nenhum step é opcional:

**6.1 — Full-suite validation**

Rode toda a validation suite no repositório inteiro (não apenas nos arquivos tocados): linter, typecheck e toda a test suite conforme definido pelo projeto. NÃO filtre para arquivos que este run alterou.

- Se aparecerem falhas que não foram flagadas por fase (per-phase) → elas contam como **regressions**. Tente corrigir até o retry limit (mesma política de hard-fail). Se ainda estiver falhando, NÃO declare success — o status se torna `completed with regressions` e as falhas são listadas sob `Regressions` no report.
- Pre-existing failures já logadas no Step 5.3 continuam categorizadas como pre-existing; elas não se tornam regressions.

**6.2 — Component Overview walk-through**

Leia o Component Overview do `spec.md` (ou seção de file-list equivalente) e, para cada arquivo listado, verifique: se o arquivo existe, se seu papel descrito é visível no conteúdo e se seus contratos (exports, routes, schemas) dão match com o spec dentro das regras de adaptação do Step 5.2.

Qualquer arquivo ausente, export ausente ou contrato ausente → adicione a `Missing from spec` no report. NÃO declare success se esta lista não estiver vazia (non-empty).

**6.3 — AC re-check**

Para cada acceptance criterion (AC) carregado no Step 2, localize os testes mapeados para ele via Testing Strategy do `spec.md` (ou equivalente). Rode esses testes do zero agora (não confie apenas que eles passaram em uma fase anterior). Marque o AC com ✓ apenas se o teste passar neste re-check final. Se o teste não passar mais → marque com ✗, adicione a `Regressions` e não declare success.

ACs sem testes mapeados permanecem como `—` (no test).

**6.4 — Environment smoke check (quando aplicável)**

Se a feature produzir superfícies de runtime que a validação per-phase não pôde exercitar (UI page, HTTP endpoint, migration, CLI command), faça um exercício final de cada uma delas contra um local environment (dev server, DB efêmero, etc.). Um rápido load-and-interact é suficiente — o objetivo é pegar coisas que os unit tests não pegam.

Se o ambiente não puder ser levantado neste run, faça o log de cada smoke check "pulado" (skipped) em `Soft-fails` — NÃO atualize o status para `success` a menos que cada smoke check tenha passado ou sido genuinamente registrado como soft-fail.

**6.5 — Status decision**

O status final do run é determinado por este step, e não se as fases fizeram os commits:

- `success` — full suite verde (green), todos os itens do Component Overview presentes, os testes de cada AC passaram no 6.3, cada smoke check passou ou deu soft-fail.
- `completed with regressions` — fases "commitadas", mas 6.1 ou 6.3 revelaram falhas que a skill não conseguiu resolver.
- `incomplete` — `Missing from spec` (6.2) não está vazio (non-empty).
- `aborted at phase <N>` — o run parou durante o Step 5 antes de chegar aqui.

Nunca reporte `success` quando qualquer uma das verificações acima tiver uma falha não resolvida, mesmo se cada fase individualmente tenha feito um commit limpo (clean).

### Step 7: Final Report

Exiba o report no chat. O status vem do Step 6.5, nunca de "eu acho que terminei":

```
Feature F<ID> — <name>

Status: success | completed with regressions | incomplete | aborted at phase <N>
Phases: <N> committed / <M> total
Branch: <current-branch>

Acceptance Criteria (re-checked in Step 6.3):
✓ <AC text> (covered by <test name>)
✗ <AC text> (test failed after <K> retries: <error summary>)
— <AC text> (no test covers this AC)

Cross-feature integration (se houver):
✓ <criterion> (covered by <test name>)
...

Missing from spec (from Step 6.2):
- <arquivo/export/contrato que o spec exigia e está ausente>
...

Regressions (from Step 6.1 or 6.3):
- <nome do teste> começou a falhar durante este run: <error>
...

Deviations:
- <o que foi adaptado e por que>
...

Soft-fails:
- <o que sofreu skip e por que, incluindo runtime smoke checks não exercitados>
...

Pre-existing failures:
- <nome do teste>: falhou ao entrar neste run; mantido as-is
...

Overrides applied:
- Retry limit: 3 → unlimited
...

Overrides ignored:
- "<text>" (motivo)
...

Abort reason (se o status for aborted): <error>
```

Se abortado, o report ainda lista o que quer que as fases "commitadas" alcançaram e marca claramente qual fase falhou e por quê. Se for `completed with regressions` ou `incomplete`, o report deixa claro quais checagens falharam para que o usuário saiba o que consertar.

---

## RULES

**Sempre:**
- Exija `spec.md` + `plan.md` na pasta da target feature; aborte sem eles.
- Localize o conteúdo de AC e o grafo de dependências entre features no PRD semanticamente, nunca por um número de seção fixo. O PRD pode ter 9 seções (formato antigo) ou 12 seções + `Appendix A` (formato atual).
- Faça 1 commit por fase (default), fazendo stage apenas dos arquivos que aquela fase tocou.
- Faça match com o estilo recente de commit-message do projeto.
- Adapte-se a pequenas divergências entre spec/código; registre cada adaptação sob `Deviations`.
- Rode o passo de validation após cada fase; diferencie hard-fail (retry ≤ limit) de soft-fail (skip + log) de pre-existing failure (log, sem retry).
- Antes de afirmar que uma fase está "done": confirme que cada arquivo listado para essa fase existe com o conteúdo descrito E a validação passou. Escrever código sem rodar nunca é "done".
- Para fases que produzem runtime surfaces (UI, HTTP route, migration, CLI), de fato as exercite contra um local environment antes de declarar como done, ou dê um soft-fail no runtime check.
- Execute o Step 6 (Final Verification) por completo antes do reporting — re-run do full-suite, walk-through do Component Overview, re-check do AC, smoke check do ambiente.
- Derive o status final exclusivamente do Step 6.5. Reporte `success` apenas quando toda checagem do Step 6 estiver verde (green).

**Nunca:**
- Afirme que o run foi `success` quando o Step 6 encontrar regressions, itens missing-from-spec ou falhas não resolvidas — mesmo que cada fase individualmente tenha "commitado" limpo (clean).
- Pule o AC report ou a sua traceability (immutable core).
- Pule o Step 6 (Final Verification).
- Crie ou troque (switch) branches.
- Aborte em divergências cosméticas de nome/path/tipo.
- Aborte por external dependency missing em um teste — dê soft-fail no teste, continue implementando.
- Use `git add -A` ou `git add .`.
- Pule os git hooks.
- Desconte do retry budget as pre-existing test failures.
- Re-execute (re-run) fases já "commitadas" na branch (detectadas por commit-message match).
- Insira service stubs em production modules — stubs são permitidos apenas em arquivos de teste.
- Explore a codebase antecipadamente (upfront) com uma varredura ampla — leia os arquivos de forma lazy conforme as fases exigem.
- Declare uma fase completa com base apenas em "eu escrevi os arquivos". O checklist de completion em 5.2 deve ser mantido.

---

## Overrides

Instruções free-form no final da invocação sobrescrevem os defaults. Exemplos:

- **Retry limit**: `no retry limit`, `max 5 tries`.
- **Autonomy**: `pause between phases` — aguarda resposta do usuário (`ok`, `continue`, `segue`, `yes`, etc.) após cada fase.
- **Commit strategy**: `no commits, just implement`; `single commit at the end`.
- **Validation**: `skip tests`, `skip lint`, `skip typecheck`.
- **Phase selection**: `only phases 1 and 2`, `skip phase 3` — as posições das fases são ordinais; labels `A/B/C` mapeiam para `1/2/3`.
- **External services**: `stub OpenAI`, `assume empty response for missing APIs` — stubs se aplicam APENAS em test code; production modules mantêm a chamada real.

Overrides não reconhecidos ou contraditórios: o default vence; registrados em `Overrides ignored`.

**Immutable core**: o AC checklist e sua traceability ao PRD não podem sofrer override.

---

## Edge Cases

**Nenhum PRD encontrado**: aborte antes de começar.

**Nenhum spec.md ou plan.md**: aborte antes de começar.

**Dependency feature não implementada**: aborte no Step 4 com uma mensagem clara.

**Feature reference ambígua**: liste os candidatos, aborte perguntando qual usar.

**Working tree tem mudanças não relacionadas no início**: prossiga de qualquer forma — a skill é projetada para ser invocável de qualquer lugar (tipicamente de uma worktree). Os commits farão o stage apenas dos arquivos específicos que cada fase tocou.

**Nome da fase contém caracteres especiais**: faça fallback para `feat(F<ID>): implement phase <N>`.

**Re-invocation após um run parcial**: O Step 5.1 detecta fases already-committed através do commit-message match e faz o skip delas. Mudanças uncommitted na working-tree de um run interrompido anteriormente ficam as-is (como estão); a skill não as limpa.

**Hard fail que ultrapassa o retry limit em um step que não é parte de nenhum AC**: aborte de qualquer forma — a skill não pode julgar quais falhas são "aceitáveis". O usuário pode aplicar o override com `skip tests` ou similar.

**Ferramenta externa emite warnings, não errors**: warnings não são failures. Apenas non-zero exit codes contam.

**Override contradiz o core contract** (ex: `simplify the spec, drop requirements`): ignore, faça o log sob `Overrides ignored` e prossiga com o spec completo.

**Comandos de validation não discoverable**: se o `package.json` / config files não revelarem comandos de linter/typecheck/test, registre cada comando ausente em `Soft-fails` e prossiga.

**PRD não tem conteúdo de AC para esta feature**: prossiga com um AC checklist vazio e anote sob soft-fails.

**PRD não tem conteúdo de dependência**: pule o Step 4 e prossiga.

**O estilo de commit-message é inconsistente no histórico recente**: faça o fallback para `feat(F<ID>): <phase name>`.