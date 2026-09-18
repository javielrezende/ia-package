---
name: implement-feature
description: Implementa uma feature de forma autônoma com base em seu spec, plan e contrato de comportamento, fazendo um commit por fase, produzindo cada Prerequisite do contrato como artefato versionado e reportando a prontidão preliminar em relação ao Coverage Manifest do contrato.
---

# Implement Feature

Implementa de forma autônoma uma feature a partir do trio `spec.md` + `plan.md` + `contract.md` já existente. A skill lê a technical specification da feature (estrutura), o behavior contract (comportamento de fronteira + prerequisites) e o implementation plan (ordem das fases). Ela escreve o código fase por fase, produz todo artefato de author-time que os Prerequisites do contrato declaram (fixtures, seeds, migrations, config defaults), valida cada fase, faz o commit e reporta a prontidão preliminar para um **contract evaluator** que vem depois no pipeline.

A skill **não** verifica os itens do contrato por conta própria (isso é trabalho do evaluator). Ela produz os artefatos para que o contrato seja exercitável e dá um sinal de prontidão no report.

## INPUT

Free-form. A skill descobre o que foi passado. Qualquer combinação funciona:

- Um identificador de feature: `F09`, `Video Upload` ou similar.
- Uma pasta de feature: `docs/F09-in-video-transcription-search/`, `./F09/`, etc.
- Um arquivo dentro da pasta da feature: `docs/F09-in-video-transcription-search/spec.md`.
- Um path para o PRD: `@docs/PRD.md`, `docs/PRD.md`, `@PRD.md`.
- Um `progress-path=<path>` opcional apontando para o `prd_progress.json` do projeto. Se omitido, a skill procura o arquivo conforme **PROGRESS TRACKING**.
- Instruções extras em linguagem natural adicionadas em qualquer lugar (veja **Overrides**).

A skill só precisa localizar três arquivos da feature e uma fonte de referência:

1. **`spec.md`, `plan.md` e `contract.md`** para a target feature — os três ficam lado a lado na mesma pasta, gerados juntos pelo `spec-writer`. Se o input apontar para uma pasta, procure dentro. Se apontar para um arquivo, procure em sua pasta pai (parent folder). Se apontar para um ID ou nome, pesquise em `docs/` por uma pasta que corresponda a `<ID>-*` ou cujo nome seja o kebab-case do nome fornecido.
2. **O PRD**. Se passado explicitamente, use-o. Caso contrário, faça um auto-discover: `docs/PRD.md` → `PRD.md` → qualquer `*.md` no top-level cujo conteúdo se pareça com um product spec. Se nenhum for encontrado, aborte. Se vários forem plausíveis, aborte e liste-os. (O PRD é necessário para contexto e para o pre-flight do grafo de dependências; ele **não** é a fonte da verificação de acceptance criteria — esse papel pertence ao Coverage Manifest do `contract.md`.)

## OUTPUT

- **Commits**: um por fase do `plan.md`, na branch atual (sem criação de branch, sem branch switching). Commits adicionais podem ser produzidos pelo walk-through dos Prerequisites do contrato quando ele remedia artefatos ausentes (Step 6.3).
- **Chat report** no final:
  - **AC pass-through sobre o Coverage Manifest do contrato** — cada AC in-scope marcado com `~` (prontidão preliminar — full suite + prereqs verdes) ou `✗` (blocked — falhas a montante), com os IDs dos itens que o cobrem. A seção carrega um header explícito de que a verificação de AC é canônica do contract evaluator, não desta skill.
  - **Contract Prerequisites readiness** — cada entrada de `Persistent state`, `Static inputs` e `Configuration` marcada com ✓ produced ou ✗ missing.
  - **Phase status, Missing from spec, Missing prerequisites, Regressions, Deviations, Soft-fails, Pre-existing failures, Overrides applied, Overrides ignored, Abort reason (se houver)**.

Nenhum arquivo é gravado além das alterações de código, dos objetos de commit e das escritas no `prd_progress.json` descritas em **PROGRESS TRACKING**. O chat report é efêmero.

---

## EXECUTION STEPS

### Step 1: Resolve Input

Faça o parsing de todo o input como free-form. Extraia:

- **Feature reference**: o primeiro token que se resolve para uma pasta contendo `spec.md` + `plan.md` + `contract.md`. Matches: padrões de ID como `F\d+`, paths de pastas, paths de arquivos (parent folder = target), nomes de features (kebab-case + fuzzy match com nomes de pastas sob `docs/`).
- **PRD reference**: um path explícito de `*.md` prefixado com `@` ou escrito literalmente; se parecer um PRD (conteúdo de product spec no topo), aceite. Caso contrário, faça o auto-discover.
- **Progress reference**: `progress-path=<path>`, quando presente.
- **Extra instructions**: qualquer texto restante que não seja um path/ID/nome — trate como overrides em linguagem natural (Step 3).

Se a resolução falhar:

- Qualquer um de `spec.md`, `plan.md` ou `contract.md` ausente na pasta resolvida → aborte: "`<missing-file>` não encontrado em `<folder>`. Regenere o trio da feature com a skill `spec-writer` — os três arquivos compartilham um único ciclo de vida e o implementador precisa dos três."
- Nenhum PRD encontrado → aborte: "Nenhum PRD encontrado. Passe o path explicitamente."
- Múltiplos PRDs plausíveis → aborte e liste os candidatos.
- Feature reference ambígua (múltiplas pastas dão match) → aborte e liste os candidatos.

### Step 2: Load Context

Leia na íntegra:

- `spec.md` da target feature — Component Overview, Data Model, API Contracts, Business Rules, UX Flows, Error Handling, Testing Strategy, Assumptions/Decisions. **O `spec.md` é a fonte canônica da estrutura interna** (file paths, decomposição, schema, escolha de bibliotecas, nomenclatura).
- `plan.md` — fases e steps em ordem.
- `contract.md` — leia o arquivo inteiro. Extraia três coisas:
  - **Coverage Manifest** — a tabela que mapeia o texto do AC copiado do PRD (com o prefixo de ID, ex.: `(RF01.1) ...`, `(UC01) ...`) → IDs dos itens que o cobrem (`API-UPLOAD-01`, `UI-UPLOAD-01`, etc.). Ele é a **fonte única dos ACs in-scope**. O que não está no manifest está fora do escopo desta execução por decisão do `spec-writer` — critérios da própria feature descartados como cross-feature, critérios de `Non-Functional Acceptance` e critérios de `Cross-Feature Integration` cuja feature `Owner` é outra — e não é carregado, não é reportado, não é testado.
  - **Prerequisites** — três subseções interessam a esta skill: `Persistent state`, `Static inputs`, `Configuration`. Cada entrada descreve uma condição prospectiva (ex.: "alice existe com e-mail…", "o arquivo de fixture no path X é um MP4 H.264 válido…", "`MAX_VIDEO_BYTES` está definido na config de teste"). O implementador PRECISA produzir artefatos de author-time que tornem cada entrada verdadeira. As outras duas subseções (`Runtime services`, `External dependencies`) descrevem condições de runtime/host e são responsabilidade do **contract evaluator**, não desta skill — carregue-as apenas como contexto, não aja sobre elas.
  - **Corpo dos itens** (given/when/then por superfície) — são a **fonte canônica do comportamento de fronteira**. Os itens ditam contratos observáveis: status codes HTTP, formato do response body (nomes de campos, tipos, presença), side-effects persistidos (linhas no DB, colunas, valores), side-effects no filesystem, códigos de erro, seletores/labels de UI. Os itens NÃO ditam a estrutura interna (file paths, nomes de classes, escolha de bibliotecas). Quando `spec.md` e itens discordam sobre o mesmo comportamento observável, **os itens vencem**; o spec vence na estrutura. Registre cada desempate desse tipo em `Deviations` para o report.
- `## Quality gates` do `contract.md`, quando presente — a lista de gates (nome, comando literal, o que significa passar) usada na validação dos Steps 5.3 e 6.1.

Se o `contract.md` tiver um Coverage Manifest vazio ou ausente, aborte a execução antes de qualquer implementação (veja o Step 4).

NÃO explore a codebase de forma eager (antecipada). Abra os arquivos de forma lazy (sob demanda) conforme cada fase exigir.

### Step 3: Apply Overrides

Interprete instruções extras como overrides em linguagem natural sobre os defaults:

| Default | Example overrides |
|---|---|
| Hard-fail retry limit = 3 | "no retry limit", "max 5 tries" |
| Totalmente autônomo (Fully autonomous) | "pause between phases" — a skill espera no chat por uma resposta contendo `ok`, `continue`, `segue`, `yes`, ou similar |
| 1 commit por fase | "single commit at the end", "no commits, just implement" |
| Rodar quality gates + testes | "skip tests", "skip lint", "skip typecheck" |
| Implementar todas as fases | "only phases 1 and 2", "skip phase 3" — as posições das fases são ordinais; labels como `A/B/C` mapeiam para `1/2/3` |
| Abortar testes em caso de dependência externa ausente (external dep missing) | "stub missing services", "assume empty response for missing APIs" — substitui por stubs **APENAS no código de teste (test code)**, nunca em production modules |

Para cada override reconhecido, registre o antes/depois para a seção "Overrides applied" do chat report final.

**Immutable core (não pode sofrer override):** a integração com o contrato como um todo — carregar o `contract.md`, executar o walk-through dos Contract Prerequisites no 6.3, executar o AC pass-through no 6.4 e renderizar o AC report com o header "preliminary readiness — canonical AC verification = contract evaluator" (que preserva a traceability com o PRD pelo texto copiado no manifest). Instruções que desabilitariam qualquer um desses pontos são logadas em "Overrides ignored" com o motivo.

Instruções ambíguas ou contraditórias → o default vence; logado em "Overrides ignored" com "ambíguo, mantido o default".

### Step 4: Pre-flight Dependency Check

**4.1 — Contract sanity:**

- `contract.md` tem uma seção `## Coverage Manifest` reconhecível (match do heading pelo formato) → prossiga.
- Coverage Manifest vazio ou ausente → aborte: "O contrato de F<target> não tem nenhum AC in-scope a verificar. Regenere com o `spec-writer` para fechar o coverage gate."
- `contract.md` não tem seção `## Prerequisites`, ou a seção está malformada (nenhuma subseção reconhecível) → aborte com a mesma mensagem de regeneração. Prerequisites é o único mecanismo que diz ao implementador quais artefatos produzir; sem ele a execução não consegue honrar seu contrato.

**4.2 — Feature dependencies:**

Localize o grafo de dependências ENTRE FEATURES no PRD semanticamente (título típico: "Dependency Graph", normalmente dentro de "Appendix A: Implementation Planning"; formato típico: uma tabela pareando cada feature com seus prerequisites por ID). NÃO confunda com a seção de negócio "Dependencies" (fornecedores, times, exigências legais) — essa não descreve prerequisites de implementação e não deve ser usada aqui. Para cada dependência listada da target feature, verifique se ela parece implementada na codebase (procure pelos arquivos característicos descritos no Component Overview do `spec.md` da própria dependência, ou marcadores óbvios no source-level).

- Qualquer dependência ausente → **aborte antes de qualquer implementação**. Reporte: "F<target> depende de F<N>, que ainda não está implementada."
- Todas as dependências presentes → prossiga para o Step 5.

Se o PRD não tiver o grafo de dependências entre features, faça o skip do 4.2 e prossiga.

### Step 5: Execute Phases

Para cada fase do `plan.md`, em ordem:

**5.1 — Skip if already done**

Inspecione os últimos ~20 commits na branch atual. Se a mensagem de algum commit indicar que esta exata fase já rodou (mesmo feature ID + nome da fase ou ordinal), faça o skip da fase com o status `— already committed` e siga em frente. A detecção é best-effort: faça o match no feature ID mais o nome normalizado da fase ou o phase index.

**5.2 — Implement**

Antes de editar o código desta fase, leia três fontes em conjunto:

1. **Seções do `spec.md` relevantes para a fase** — as entradas do Component Overview que a fase produz, mais os trechos correspondentes de API Contracts / Data Model / Error Handling. O spec é a fonte canônica da **estrutura interna**: file paths, decomposição, colunas do schema, escolha de bibliotecas, nomenclatura interna.
2. **Todos os itens do contrato** (cada item sob cada seção de superfície do `contract.md`). Os itens são a fonte canônica do **comportamento de fronteira**: status codes, formato do response body, side-effects persistidos, side-effects no filesystem, códigos de erro, labels de UI. Ler todos os itens a cada fase é intencional — os itens relevantes para uma fase não são pré-filtrados. Os códigos de superfície (`SVC`, `API`, `UI`, `WRK`, `EVT`, `CLI`, `E2E`) sinalizam quais itens são exercitados de forma observável por qual tipo de fase, mas o implementador lê todos os itens para contexto, independentemente disso.
3. **A descrição do step da fase no `plan.md`** — ancora o que a fase está entregando.

Então edite/crie os arquivos para cumprir os steps da fase, **respeitando a regra de desempate**:

- **Itens vencem no comportamento observável.** Quando o `spec.md` descreve um formato de resposta, status code, código de erro ou qualquer outra propriedade observável externamente e um item do contrato afirma algo diferente sobre a mesma propriedade, siga o item. Divergência no spec é bug do `spec-writer`, mas o implementador não deve propagá-la; o contract evaluator vai checar o item, não o spec. Registre cada desempate desse tipo em `Deviations` no formato "spec said X, item `<ID>` asserted Y, followed Y".
- **O spec vence na estrutura interna.** Os itens nunca ditam file paths, nomes de classes, colunas internas do data model que não são afirmadas externamente, ou escolha de bibliotecas. Na dúvida se uma divergência é "observável" ou "interna", pergunte: o contract evaluator perceberia isso de fora do sistema? Se sim, os itens vencem; se não, o spec vence.

**Produza os Prerequisites do contrato junto com o código.** Quando uma fase naturalmente produz um artefato que satisfaz uma entrada de Prerequisites (uma migration que cria a tabela `videos`, uma fixture que os itens referenciam, um seed que cria `alice`, um config default para `VIDEO_STORAGE_DIR`), produza-o como parte do commit dessa fase. Não adie para o Step 6.3, exceto como remediação de último recurso.

**O que conta como "done" para uma fase** — tudo a seguir, e não apenas "eu escrevi o código":

- Cada arquivo listado para esta fase no Component Overview do `spec.md` existe e contém o conteúdo descrito.
- Cada contrato (API, schema, function signature) descrito para esta fase dá match com o que foi escrito, **respeitada a regra de desempate acima (itens vencem)**.
- O passo de Validation em 5.3 passa (hard fails resolvidos).
- Se a fase produzir comportamento em runtime que não é coberto por unit tests (UI pages, server routes, migrations, CLI commands), de fato o exercite antes de declarar como done: rode o dev server / build / migration / command contra um ambiente local e confirme que ele se comporta como o esperado. Se o ambiente não puder ser levantado nesta execução (run), faça o log do runtime-check sob `Soft-fails` — NÃO declare silenciosamente que a fase está done.
- **Para superfícies cujos itens do contrato só podem ser observados no navegador, o exercício de runtime precisa ser no navegador.** Quando a fase produz uma superfície coberta por itens com código de superfície `UI-*` ou `E2E-*`, o exercício de runtime acima só é cumprido conduzindo um navegador real contra a superfície ao vivo — smoke apenas via HTTP (ex.: `curl`) não satisfaz, porque os itens tipicamente afirmam observáveis que só existem na página renderizada (estado do DOM, foco, computed styles, estado de elementos de mídia, posição de scroll, efeitos de navegação na página). Use a ferramenta de automação de navegador que o projeto já usa. Se a ferramenta, o dev server ou a página não puderem ser levantados nesta execução, a checagem é registrada como `✗ blocked` no Step 6.5 — nunca como soft-fail.

Escrever código sem rodar não é "done". Declarar conclusão sem atender ao checklist acima é uma violação do contrato da skill.

Faça adaptações quando a realidade divergir do spec (coluna chamada `pinned` no DB vs `isPinned` no spec, nome de arquivo de component diferente, path ligeiramente diferente, types estruturalmente compatíveis). Specs nunca são 100% fiéis à realidade — adaptação é esperada. Registre cada adaptação em uma lista de `Deviations` para o chat report final. NÃO aborte em pequenas divergências.

**Aborte o run inteiro apenas em:**

- Dependency feature ausente (geralmente pega no Step 4; se descoberta em mid-phase, aborte aqui).
- Hard fail que ultrapasse o retry limit no Step 5.3 abaixo.

Dependências externas ausentes necessárias apenas por *testes* (ex: `OPENAI_API_KEY` indisponível) NÃO abortam o run — elas causam um soft-fail no teste afetado. O código de implementação que chama o serviço ainda é escrito.

**5.3 — Validate**

Descubra os comandos de validação em runtime:

- **Gates** — se o `contract.md` tiver a seção `## Quality gates`, execute o comando literal de cada entrada. Se o contrato não tiver essa seção, descubra os comandos de linter e typecheck inspecionando os `scripts` do `package.json`, ou para stacks não-Node o equivalente (`Makefile`, `pyproject.toml`, `Cargo.toml`).
- **Testes** — descubra o comando da test suite pelos manifests/configs do projeto (`package.json`, `vitest.config.*`, `jest.config.*`, `pyproject.toml`, `Makefile`, etc.).

Os overrides de validação (`skip lint`, `skip typecheck`, `skip tests`) valem para o gate ou comando correspondente. Quando o gate declarado no contrato não permite separar a parte pedida (ex.: um script wrapper que roda lint e typecheck juntos), o gate roda inteiro e o override é registrado em "Overrides ignored" com o motivo.

- **Hard fail** = saída (exit) não-zero de um gate ou dos testes, onde a falha é atribuível ao código que este run alterou. Faça o retry até o limite configurado (default 3). Cada retry lê o erro, ajusta o código e roda novamente (re-runs). Após o limite, aborte o run inteiro e vá para o Step 6.
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

Rode toda a validation suite no repositório inteiro (não apenas nos arquivos tocados): os mesmos gates e testes descobertos no Step 5.3 (gates de `## Quality gates` quando o contrato os declara; caso contrário, linter e typecheck do projeto) e toda a test suite conforme definido pelo projeto. NÃO filtre para arquivos que este run alterou.

- Se aparecerem falhas que não foram flagadas por fase (per-phase) → elas contam como **regressions**. Tente corrigir até o retry limit (mesma política de hard-fail). Se ainda estiver falhando, NÃO declare success — o status se torna `completed with regressions` e as falhas são listadas sob `Regressions` no report.
- Pre-existing failures já logadas no Step 5.3 continuam categorizadas como pre-existing; elas não se tornam regressions.

**6.2 — Component Overview walk-through**

Leia o Component Overview do `spec.md` (ou seção de file-list equivalente) e, para cada arquivo listado, verifique: se o arquivo existe, se seu papel descrito é visível no conteúdo e se seus contratos (exports, routes, schemas) dão match com o spec dentro das regras de adaptação do Step 5.2.

Qualquer arquivo ausente, export ausente ou contrato ausente → adicione a `Missing from spec` no report. NÃO declare success se esta lista não estiver vazia (non-empty).

**6.3 — Contract Prerequisites walk-through**

Para cada entrada das três subseções in-scope de Prerequisites do `contract.md` — `Persistent state`, `Static inputs` e `Configuration` — verifique se um artefato de author-time no repositório torna a entrada verdadeira. Aplique rigor de Nível 2: presença + checagem intrínseca leve, usando ferramentas que o contrato já assume disponíveis no host (essas ferramentas também aparecem em `Runtime services` / `External dependencies` do mesmo contrato).

**Convenções do projeto:** a convenção de seeding, de path de fixtures e de configuração de teste vem primeiro das Assumptions/Decisions do `spec.md` (Spec §4). Quando a Spec §4 não registra a convenção, procure na codebase o mecanismo que o projeto já usa (código de setup de testes, pastas de seed/migration, arquivos de factory, pastas de fixtures, arquivos de config de teste). A entrada só é marcada `✗ missing` por falta de convenção quando nenhuma das duas fontes a revela.

Por subseção:

- **`Persistent state`** — entradas declarativas descrevendo entidades/contas/linhas/sessões que precisam existir dentro do store do sistema (ex.: "alice existe com e-mail `alice@example.com`, senha `Pass1234`, ativa, com um cookie de sessão válido"). Verifique fazendo o parsing do artefato de seeding do projeto (seed/factory/migration, conforme a convenção acima) e confirmando que uma entrada cria o handle declarado com os atributos declarados. **Nunca** verifique subindo o sistema e consultando o DB — isso invade a responsabilidade de runtime do evaluator.
- **`Static inputs`** — paths de arquivos que os itens referenciam (ex.: `apps/backend/tests/fixtures/videos/sample-30s.mp4`). Verifique que o arquivo existe no path declarado E que sua propriedade intrínseca vale:
  - A existência do arquivo em disco é obrigatória.
  - Para fixtures de mídia com um perfil declarado de codec/duração/tamanho, rode a ferramenta de host que o contrato nomeia (ex.: `ffprobe`/`ffmpeg`) e confirme a propriedade. Para casos "precisa ser legível", a ferramenta tem sucesso; para inversões "precisa ser ilegível", a ferramenta falha como esperado.
  - Para fixtures de texto/binárias com formato de tamanho ou conteúdo, confirme pelos metadados do arquivo (tamanho, byte sniff, extensão).
  - Para fixtures cuja propriedade intrínseca depende de um valor de config (ex.: tamanho de `oversize.bin` > `MAX_VIDEO_BYTES`), resolva o valor de config a partir do artefato de config de teste e compare.
- **`Configuration`** — chaves de config e defaults que o contrato nomeia (ex.: `VIDEO_STORAGE_DIR`, `MAX_VIDEO_BYTES`, nome do cookie `videomax_session`). Verifique que a chave está presente no artefato de config de teste do projeto (`.env.example`, `.env.test`, bloco de config específico do framework — conforme a convenção acima) com um valor compatível com o significado declarado no contrato.

Para cada entrada, classifique como:

- `✓ produced` — o artefato existe, a checagem intrínseca passou.
- `✗ missing` — o artefato está ausente, OU a checagem intrínseca falhou, OU a ferramenta de host necessária não está disponível.

Quando uma entrada `✗ missing` for corrigível nesta execução (o artefato pode ser escrito ao alcance da skill com as ferramentas disponíveis), tente a remediação como um commit separado intitulado `chore(F<ID>): produce contract prerequisite — <handle>` e verifique de novo. Se a remediação tiver sucesso, a entrada vira `✓ produced`. Se a remediação falhar (sem `ffmpeg`, sem permissão, etc.), mantenha `✗ missing` e adicione uma linha com o motivo em `Missing prerequisites` no report.

As outras duas subseções de Prerequisites — `Runtime services` e `External dependencies` — são intencionalmente puladas aqui. Elas descrevem condições de runtime/host que o **contract evaluator** é responsável por satisfazer quando exercita os itens. O implementador não as verifica nem as produz.

**6.4 — AC pass-through sobre o Coverage Manifest do contrato**

Este step **não** é um test runner por AC. A verificação canônica de AC pertence a um contract evaluator a jusante que exercita os itens GWT do contrato ponta a ponta. O trabalho desta skill aqui é projetar um **sinal de prontidão preliminar** para que o usuário saiba se o run está em condições de o evaluator assumir.

Para cada linha de AC no Coverage Manifest do `contract.md`:

- Leia o texto do AC copiado do PRD (coluna 1, com o prefixo de ID) e os IDs dos itens que o cobrem (coluna 2).
- Calcule uma marca de prontidão a partir dos resultados a montante do Step 6 — nunca rodando um teste específico do AC:
  - `~ ready` — Step 6.1 (full suite) está verde E Step 6.3 (walk-through dos Contract Prerequisites) está verde E nenhuma entrada de `Missing from spec` (Step 6.2) se sobrepõe a um arquivo que os itens de cobertura referenciariam E nenhum item de cobertura `UI-*` / `E2E-*` está `✗ blocked` no Step 6.5.
  - `✗ blocked` — qualquer um dos pontos acima está vermelho.
- Renderize a linha do AC como: `<mark> <texto do AC copiado do PRD> [<item IDs>]`.

ACs ausentes do Coverage Manifest ficam ausentes do report — estão fora do escopo por design (sem linha `—`, sem linha "out of scope", sem menção).

**6.5 — Environment smoke check (quando aplicável)**

Se a feature produzir superfícies de runtime que a validação per-phase não pôde exercitar (UI page, HTTP endpoint, migration, CLI command), faça um exercício final de cada uma delas contra um local environment (dev server, DB efêmero, etc.). Um rápido load-and-interact é suficiente — o objetivo é pegar coisas que os unit tests não pegam.

O tipo de exercício exigido depende do código de superfície dos itens que a cobrem:

- **Superfícies HTTP / SVC / WRK / EVT / CLI** — exercite pelo transporte correspondente (cliente HTTP para `API`, invocação direta para `SVC`/`WRK`/`EVT`, shell para `CLI`). Se o ambiente não puder ser levantado neste run, faça o log em `Soft-fails`.
- **Superfícies `UI-*` e `E2E-*`** — os itens afirmam observáveis que só existem numa página renderizada (estado do DOM, foco, computed styles, estado de elementos de mídia, posição de scroll, navegação na página). O exercício PRECISA, portanto, conduzir um navegador real contra a página ao vivo, usando a ferramenta de automação de navegador que o projeto já usa; smoke apenas via HTTP ou `curl` NÃO cumpre a checagem. Se a ferramenta de navegador, o dev server ou a página não puderem ser levantados, a checagem é `✗ blocked` (NÃO soft-fail) e os itens `UI-*` / `E2E-*` afetados propagam `✗ blocked` para os ACs que cobrem no 6.4.

O exercício no navegador precisa verificar o estado renderizado, não apenas se dá para clicar ou se o texto está no DOM. Mídias (`<img>`, `<video>`, thumbnails) precisam carregar de fato — um ícone de imagem quebrada não é aceitável. Overlays, menus, dropdowns, popovers e dialogs precisam abrir por inteiro dentro do viewport, sem corte por `overflow` de ancestrais e sem ficar escondidos atrás da UI ao redor. Qualquer render claramente quebrado visível num screenshot precisa ser corrigido dentro do retry budget. Problemas visuais contam como hard-fails para fins de retry; apenas a impossibilidade de subir o navegador ou o dev server é `✗ blocked`.

Interação com o status: um smoke check em `Soft-fail` ainda permite `success`. Um smoke check `✗ blocked` não — ele rebaixa o status para `incomplete` conforme o 6.6.

**6.6 — Status decision**

O status final do run é determinado por este step, e não se as fases fizeram os commits:

- `success` — full suite verde (6.1), todos os itens do Component Overview presentes (6.2), toda entrada de Prerequisites `✓ produced` (6.3), todo AC do Coverage Manifest marcado `~ ready` (6.4), cada smoke check passou ou deu soft-fail honesto (6.5). Um smoke check `UI-*` / `E2E-*` pulado porque a ferramenta de navegador, o dev server ou a página não subiram é `✗ blocked` (conforme 6.5), não soft-fail — sua presença impede `success`.
- `completed with regressions` — fases "commitadas", mas o 6.1 revelou falhas que a skill não conseguiu resolver.
- `incomplete` — `Missing from spec` (6.2) não está vazio, OU `Missing prerequisites` (6.3) não está vazio após a remediação, OU algum AC do 6.4 está marcado `✗ blocked`.
- `aborted at phase <N>` — o run parou durante o Step 5 antes de chegar aqui.

Nunca reporte `success` quando qualquer uma das verificações acima tiver uma falha não resolvida, mesmo se cada fase individualmente tenha feito um commit limpo (clean).

### Step 7: Final Report

Exiba o report no chat. O status vem do Step 6.6, nunca de "eu acho que terminei":

```
Feature F<ID> — <name>

Status: success | completed with regressions | incomplete | aborted at phase <N>
Phases: <N> committed / <M> total
Branch: <current-branch>

Acceptance Criteria (preliminary readiness — canonical AC verification = contract evaluator):
~ <texto do AC copiado do PRD> [<item IDs>]
✗ <texto do AC copiado do PRD> [<item IDs>] — blocked: <motivo em uma linha apontando para a falha a montante>
...

Contract Prerequisites (from Step 6.3):
Persistent state:
  ✓ <handle> — <localizador em uma linha: qual seed/factory/migration o carrega>
  ✗ <handle> — <motivo: artefato ausente | parse do seed falhou | …>
Static inputs:
  ✓ <path> — <checagem intrínseca que passou, ex.: "ffprobe: H.264 + AAC, duration 18s">
  ✗ <path> — <motivo: arquivo ausente | ffprobe falhou | ferramenta fora do PATH | …>
Configuration:
  ✓ <key> — <onde: .env.example | config/test.ts | …>
  ✗ <key> — <motivo>

Missing from spec (from Step 6.2):
- <arquivo/export/contrato que o spec exigia e está ausente>
...

Missing prerequisites (from Step 6.3, after remediation attempts):
- <handle ou path>: <motivo pelo qual o artefato não pôde ser produzido>
...

Regressions (from Step 6.1):
- <nome do teste ou gate> começou a falhar durante este run: <error>
...

Deviations:
- <o que foi adaptado e por que; inclua os desempates items-win: "spec said X, item <ID> asserted Y, followed Y">
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

Se abortado, o report ainda lista o que quer que as fases "commitadas" alcançaram e marca claramente qual fase falhou e por quê. Se for `completed with regressions` ou `incomplete`, o report deixa claro quais checagens falharam para que o usuário saiba o que consertar. O header de Acceptance Criteria **precisa** carregar literalmente a ressalva "preliminary readiness — canonical AC verification = contract evaluator" — nunca apresente essas marcas como veredito.

---

## PROGRESS TRACKING

Esta skill grava suas próprias transições de status num arquivo compartilhado `prd_progress.json`, restritas à entrada da target feature. O arquivo é o registro determinístico do estado das features ao longo do pipeline `implement-feature` → `evaluator` → `fix-runner`. O schema é canônico na skill `prd-writer-for-complete-project` (seção "SCHEMA DO ARQUIVO DE PROGRESSO"); esta seção documenta apenas as escritas desta skill.

**Localizando o arquivo** (na ordem; o primeiro encontrado vence):

1. Se o input contiver `progress-path=<path>`, use-o.
2. `prd_progress.json` na mesma pasta do PRD resolvido no Step 1 (o `prd-writer-for-complete-project` grava o arquivo ao lado do PRD por padrão).
3. Procure a partir do CWD para cima (máximo 4 níveis) pelo `prd_progress.json` mais próximo.

Se não for encontrado, faça o log de uma linha em `Soft-fails` "arquivo de progresso não encontrado, status não rastreado" e prossiga. O trabalho de implementação nunca é bloqueado pelo tracking.

**Regra de escopo:** nunca toque na entrada de qualquer feature que não seja a target feature. Nunca modifique os campos de primeiro nível (`schema_version`, `prd_path`, `generated_at`).

**Modos de falha — continuação silenciosa:**

- Arquivo não encontrado, falha no parse, ou feature ID ausente como chave em `features` → log em `Soft-fails`, pule a escrita.
- Escrita atômica falha (erro no rename, permissão, etc.) → log em `Soft-fails`, pule.

Toda escrita é: ler → modificar apenas a entrada da target feature → escrita atômica (`.tmp` + rename) do JSON inteiro. Timestamps são RFC 3339 UTC (`2026-05-02T14:30:00Z`).

**Write 1 — No início do Step 5 (Execute Phases), depois que os pre-flight checks passam:**

- `status` ← `"implementing"` (transitório — marca "implement-feature está rodando AGORA")
- `started_at` ← now (apenas se estiver `null`; nunca sobrescreva)
- `updated_at` ← now
- `failure_reason` ← `null` (limpa nota de falha antiga de um ciclo anterior)
- `report_path` ← `null` (limpa o ponteiro para qualquer eval-report anterior — a implementação invalida o veredito anterior)
- `completed_at` ← `null`
- `cycles`, `priority`, `wave`, `dependencies`, `name` — intocados.

**Write 2 — Num abort pré-fase (qualquer abort durante os Steps 1–4, antes do Write 1):**

- `status` ← `"fail"`
- `failure_reason` ← motivo curto ≤200 caracteres, ex.: `"aborted pre-phase: spec.md missing in docs/F03-video-upload/"`
- `updated_at` ← now
- Todos os outros campos intocados.

**Write 3 — No final do Step 7, condicionado ao status do Step 6.6:**

- `"aborted at phase <N>"` → grave `status="fail"`, `failure_reason="aborted at phase <N>: <motivo em uma linha ≤200 caracteres>"`, `updated_at=now`. Outros campos intocados.
- `success`, `completed with regressions` ou `incomplete` → grave `status="implemented"` (a fase de implementação terminou; a feature agora está no loop implementar → avaliar → corrigir aguardando o veredito terminal do evaluator), `updated_at=now`. Outros campos intocados. O `evaluator` a jusante vai substituir `implemented` por `done` (clean) ou `fail` (falha terminal).

Essas três escritas cobrem todos os caminhos de término. Se a skill cair (processo morre, kill signal) entre o Write 1 e o Write 3, o status fica em `"implementing"` — sinal visível de que algo estava rodando e não terminou; o usuário/orquestrador pode rodar de novo; o Write 1 da próxima execução vai renovar `failure_reason`/`report_path`/`completed_at` e voltar o `status` para `"implementing"`.

---

## RULES

**Sempre:**
- Exija `spec.md` + `plan.md` + `contract.md` na pasta da target feature; aborte sem qualquer um dos três.
- Trate o Coverage Manifest do `contract.md` como a fonte única da lista de ACs in-scope. ACs ausentes do manifest estão fora do escopo e nunca aparecem no report.
- Trate os itens do `contract.md` como canônicos para o comportamento de fronteira; trate o `spec.md` como canônico para a estrutura interna. Aplique o desempate items-win e registre cada desempate em `Deviations`.
- Produza artefatos de author-time que satisfaçam cada entrada de `Persistent state`, `Static inputs` e `Configuration` dos Prerequisites do contrato. Faça isso dentro da fase natural sempre que possível; remedie como commit separado durante o Step 6.3 apenas quando a fase natural deixou passar.
- Localize o grafo de dependências entre features no PRD semanticamente, nunca por um número de seção fixo. O PRD pode ter 9 seções (formato antigo) ou 12 seções + `Appendix A` (formato atual). Nunca use a seção de negócio "Dependencies" como grafo de features.
- Use os gates de `## Quality gates` do contrato na validação quando a seção existir; descubra os comandos pelos manifests do projeto apenas quando ela não existir. Descubra a test suite sempre pelos manifests do projeto.
- Faça 1 commit por fase (default), fazendo stage apenas dos arquivos que aquela fase tocou. Os commits de remediação de prerequisites do Step 6.3 são exceção: são intitulados `chore(F<ID>): produce contract prerequisite — <handle>` e fazem stage apenas dos arquivos de artefato adicionados.
- Faça match com o estilo recente de commit-message do projeto.
- Adapte-se a pequenas divergências entre spec/código; registre cada adaptação sob `Deviations`.
- Rode o passo de validation após cada fase; diferencie hard-fail (retry ≤ limit) de soft-fail (skip + log) de pre-existing failure (log, sem retry).
- Antes de afirmar que uma fase está "done": confirme que cada arquivo listado para essa fase existe com o conteúdo descrito E a validação passou. Escrever código sem rodar nunca é "done".
- Para fases que produzem runtime surfaces (UI, HTTP route, migration, CLI), de fato as exercite contra um local environment antes de declarar como done, ou dê um soft-fail no runtime check. Para superfícies cujos itens do contrato têm código `UI-*` ou `E2E-*`, o exercício precisa ser conduzido por navegador contra a página ao vivo (os itens afirmam observáveis de navegador que um smoke via HTTP não enxerga); pular é `✗ blocked`, nunca soft-fail. O exercício no navegador também precisa verificar o estado renderizado — thumbnails quebradas, overlays cortados, menus escondidos e bugs de render semelhantes são hard-fails a corrigir neste run.
- Execute o Step 6 (Final Verification) por completo antes do reporting — re-run do full-suite, walk-through do Component Overview, walk-through dos Contract Prerequisites, AC pass-through, smoke check do ambiente (nessa ordem).
- Derive o status final exclusivamente do Step 6.6. Reporte `success` apenas quando toda checagem do Step 6 estiver verde (green).
- Renderize o header do report de Acceptance Criteria com a ressalva literal "preliminary readiness — canonical AC verification = contract evaluator". Nunca apresente `~` como veredito.
- Execute as três escritas no `prd_progress.json` definidas em **PROGRESS TRACKING** quando o arquivo for localizável: Write 1 no início do Step 5; Write 2 em qualquer abort pré-fase; Write 3 condicionado ao status do Step 6.6. Modifique apenas a entrada da target feature; nunca toque nas outras.

**Nunca:**
- Afirme que o run foi `success` quando o Step 6 encontrar regressions, itens missing-from-spec, prerequisites ausentes ou qualquer AC marcado `✗ blocked` — mesmo que cada fase individualmente tenha "commitado" limpo (clean).
- Dê soft-fail no smoke check de uma superfície `UI-*` ou `E2E-*`. O exercício conduzido por navegador é obrigatório; se não puder rodar, a superfície é `✗ blocked` e o status é rebaixado conforme o 6.6.
- Substitua o smoke por navegador de uma superfície `UI-*` / `E2E-*` por uma checagem apenas HTTP (`curl`, script de fetch, integration test).
- Pule o Step 6 (Final Verification) ou qualquer um de seus sub-steps.
- Rode testes específicos de AC no Step 6.4 (o step é um pass-through sobre o Coverage Manifest, não um test runner).
- Verifique Prerequisites do contrato subindo o sistema e consultando-o (Persistent state, Static inputs e Configuration são checados contra artefatos de author-time). Subir o sistema é trabalho do contract evaluator.
- Verifique, satisfaça ou comente os Prerequisites de `Runtime services` e `External dependencies` — eles são do lado do evaluator.
- Renderize `✓` em qualquer linha de AC no 6.4 — prontidão é `~`, não veredito.
- Trate o `spec.md` como autoritativo quando um item o contradiz explicitamente sobre uma propriedade observável externamente; siga o item e registre o desvio.
- Renderize uma linha "out of scope" para ACs ausentes do Coverage Manifest — o silêncio é por design.
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
- **Validation**: `skip tests`, `skip lint`, `skip typecheck` — valem para o gate ou comando correspondente; um gate que não permite separar a parte pedida roda inteiro e o override vai para `Overrides ignored`.
- **Phase selection**: `only phases 1 and 2`, `skip phase 3` — as posições das fases são ordinais; labels `A/B/C` mapeiam para `1/2/3`.
- **External services**: `stub OpenAI`, `assume empty response for missing APIs` — stubs se aplicam APENAS em test code; production modules mantêm a chamada real.

Overrides não reconhecidos ou contraditórios: o default vence; registrados em `Overrides ignored`.

**Immutable core**: a integração com o contrato não pode sofrer override — o carregamento do `contract.md`, o AC pass-through sobre o Coverage Manifest, o walk-through dos Contract Prerequisites e o header do AC report valem independentemente de overrides.

---

## Edge Cases

**Nenhum PRD encontrado**: aborte antes de começar.

**Nenhum spec.md, plan.md ou contract.md**: aborte antes de começar com a mensagem de regeneração — os três arquivos compartilham um único ciclo de vida e a skill não roda com um conjunto parcial.

**`contract.md` existe, mas o Coverage Manifest está vazio/ausente**: aborte no Step 4.1 com a mensagem de regeneração.

**`contract.md` existe, mas a seção Prerequisites está vazia/ausente**: aborte no Step 4.1 — o implementador não consegue honrar um contrato sem declaração de prerequisites.

**Dependency feature não implementada**: aborte no Step 4.2 com uma mensagem clara.

**Feature reference ambígua**: liste os candidatos, aborte perguntando qual usar.

**Working tree tem mudanças não relacionadas no início**: prossiga de qualquer forma — a skill é projetada para ser invocável de qualquer lugar (tipicamente de uma worktree). Os commits farão o stage apenas dos arquivos específicos que cada fase tocou.

**Nome da fase contém caracteres especiais**: faça fallback para `feat(F<ID>): implement phase <N>`.

**Re-invocation após um run parcial**: O Step 5.1 detecta fases already-committed através do commit-message match e faz o skip delas. O Step 6.3 ainda roda e pode produzir um commit de remediação se um Prerequisite não foi produzido pelas fases puladas. Mudanças uncommitted na working-tree de um run interrompido anteriormente ficam as-is (como estão); a skill não as limpa.

**Spec e item do contrato discordam sobre uma propriedade observável**: siga o item, registre "a spec dizia X, o item `<ID>` afirma Y, segui Y" em `Deviations`. Não pause para reconciliar, não edite o `spec.md` para bater — a divergência é bug do `spec-writer`, não preocupação do implementador.

**Spec descreve um detalhe de estrutura interna (file path, nome de classe) sem contrapartida em item**: siga o spec; a regra items-win só se aplica quando as duas fontes falam da mesma propriedade.

**Fixture de Static input não pode ser produzida** (ex.: `ffmpeg` fora do PATH, mas o contrato exige um arquivo H.264 válido): marque a fixture `✗ missing` no 6.3 com o motivo, liste-a em `Missing prerequisites` e deixe a decisão de status rebaixar para `incomplete`. Não aborte o run.

**Seed de Persistent state não pode ser escrito** porque a convenção de seeding do projeto não está registrada nas Assumptions do `spec.md` nem é encontrada na codebase: faça o log em `Soft-fails` ("convenção de seeding não documentada e não encontrada na codebase; não dá para escrever o seed de `<handle>`") e marque a entrada `✗ missing`. O status é rebaixado para `incomplete`.

**Chave de Configuration já presente no projeto, mas com valor incompatível com o significado declarado no contrato**: não sobrescreva em silêncio. Registre em `Deviations`, proponha o valor alinhado ao contrato como default e adicione a chave em `Missing prerequisites` para que o usuário revise.

**Hard fail que ultrapassa o retry limit em um step que não é parte de nenhum AC**: aborte de qualquer forma — a skill não pode julgar quais falhas são "aceitáveis". O usuário pode aplicar o override com `skip tests` ou similar.

**Ferramenta externa emite warnings, não errors**: warnings não são failures. Apenas non-zero exit codes contam.

**Override contradiz o core contract** (ex: `simplify the spec, drop requirements`, `skip prereqs`, `ignore the contract`): ignore, faça o log sob `Overrides ignored` e prossiga com o spec + contrato completos. A integração com o contrato não é opcional.

**Contrato sem `## Quality gates` e comandos de validation não discoverable**: se o `package.json` / config files não revelarem comandos de linter/typecheck/test, registre cada comando ausente em `Soft-fails` e prossiga.

**PRD não tem o grafo de dependências entre features**: pule o Step 4.2 e prossiga.

**O estilo de commit-message é inconsistente no histórico recente**: faça o fallback para `feat(F<ID>): <phase name>` (ou `chore(F<ID>): produce contract prerequisite — <handle>` para commits de remediação do 6.3).
