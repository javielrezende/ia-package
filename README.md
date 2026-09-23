# ia-package

Plugin do Claude Code com um pipeline agêntico que leva uma feature do PRD ao PR/MR.
Você conduz o planejamento; a execução roda sozinha — implementa, avalia contra um
contrato de comportamento, corrige o que reprovou e repete até o contrato ser honrado.

Os documentos são gerados em português (pt-BR).

```
┌─ PLANEJAMENTO — você conduz, uma skill por vez ─────────────────────┐
│                                                                     │
│   /ia-package:prd-writer-for-complete-project                       │
│        entrevista de 12 blocos ──▶ docs/PRD.md + prd_progress.json  │
│                     │                                               │
│   /ia-package:spec-writer F03                                       │
│        entrevista técnica ──▶ spec.md + plan.md + contract.md       │
│                     │                                               │
│   git commit / PR ──┴──▶ planejamento versionado na branch padrão   │
└──────────────────────────────┬──────────────────────────────────────┘
                               ▼
┌─ EXECUÇÃO — o loop roda sem intervenção entre os ciclos ────────────┐
│                                                                     │
│   /ia-package:implement-and-evaluate F03                            │
│                                                                     │
│     implement-feature ──▶ evaluator ──▶ clean? ──sim──▶ PR/MR       │
│                               ▲           │                         │
│                               │          não                        │
│                               └─ fix-runner ◀─┘                     │
│                                                                     │
│   O par evaluator ⇄ fix-runner repete até o contrato ser honrado,   │
│   o retry budget acabar ou o circuit-breaker disparar. O veredito   │
│   é sempre do evaluator, nunca de quem implementou.                 │
└─────────────────────────────────────────────────────────────────────┘
```

> As skills de documentação e arquitetura que **não** participam deste loop — as
> entrevistas de PRD de feature, HLD, FDD e deep research, o fluxo de ADRs e os
> geradores de diagramas C4/Mermaid — foram extraídas para um pacote separado. Elas
> se invocam uma de cada vez e nada aqui lê o que elas produzem.

## Pré-requisitos

| Ferramenta | Para quê | Quando é obrigatória |
|---|---|---|
| `git` | branches, worktrees e commits do pipeline | sempre |
| `bash` + `python3` | os dois hooks | para os hooks — sem `python3` eles saem em silêncio, sem quebrar a sessão |
| `gh` (GitHub) ou `glab` (GitLab) | abrir issue e PR/MR | opcional: sem o CLI, o pipeline faz o trabalho inteiro e imprime o comando manual. Veja **Forge** |
| `tmux` | uma janela por feature na wave paralela | só para o `implement-and-evaluate-tmux` |
| Ferramenta de automação de navegador | itens `UI-*` e `E2E-*` do contrato e o `design-review` | só quando a feature tem tela |

## Instalação

```bash
# 1. registre o repositório como marketplace
/plugin marketplace add javielrezende/ia-package

# 2. instale
/plugin install ia-package@ia-package
```

Depois de instalar, o seu projeto precisa de dois arquivos: um `CLAUDE.md` (o que o
plugin não tem como adivinhar sobre o projeto) e um `.claude/settings.json` (o que o
pipeline pode rodar sem parar para perguntar). Os dois têm template no plugin.

## O `CLAUDE.md` do seu projeto

Copie o `templates/CLAUDE.example.md` para a raiz do **seu projeto** (não deste
repositório) como `CLAUDE.md` e preencha. É esse arquivo que faz as skills gerarem
documentos aderentes ao projeto em vez de genéricos. Três blocos carregam mais peso
que o resto:

**`## Ambiente de avaliação` — preencha primeiro.** O `evaluator` sobe um ambiente
efêmero do zero para exercitar cada item do contrato e procura como fazer isso nesta
ordem: (1) a seção `Prerequisites` do contrato, (2) este arquivo, (3) o `spec.md` da
feature, (4) outros contratos, (5) os manifests do projeto, (6) defaults da stack.
**Quando nada responde, ele aborta** e aponta para cá. Cada linha preenchida aqui é
uma camada de adivinhação a menos: instalar dependências, criar banco efêmero, rodar
migrations, semear dados, subir e derrubar os serviços, health-check de cada um,
resetar o estado entre itens, onde ficam as fixtures.

Nesse bloco, **declare a variável de porta de cada serviço, não o número**. O ambiente
efêmero aloca uma porta livre por execução — veja
[**Isolamento entre execuções paralelas**](#isolamento-entre-execuções-paralelas).

**`## Stack deste projeto`.** É o que faz o `spec-writer` produzir um plano coerente
com a linguagem, o framework, o ORM e os comandos de teste e lint que o projeto usa.

**`## Forge`.** A linha `- Forge: github|gitlab`. Obrigatória em GitLab
auto-hospedado num host que não se chama `gitlab.*`. Veja **Forge**.

## Permissões: pré-aprove o que o pipeline usa

O pipeline roda sozinho por dezenas de minutos. Toda vez que ele para para pedir
aprovação de um comando, a execução fica esperando uma pessoa — e numa wave paralela,
a janela daquela equipe fica parada até o `team-timeout` matá-la, 90 minutos depois.

**O padrão recomendado não é desligar as permissões, é pré-aprovar o que o pipeline
usa.** Copie o `templates/settings.example.json` deste repositório para
`.claude/settings.json` na raiz do seu projeto e ajuste as listas à sua stack.

| Chave | Para quê |
|---|---|
| `permissions.allow` | O que o pipeline roda o tempo todo — testes, lint, build, git, `gh`/`glab`, subir e derrubar serviços. Pré-aprovado, nunca pergunta |
| `permissions.deny` | O que nunca deve rodar, com ou sem agente. **Regras `deny` valem em todos os modos de permissão, inclusive `bypassPermissions`** |

O arquivo é versionado e vale para todo mundo no projeto. Com ele no lugar, o modo de
permissão padrão já basta: o pipeline roda sem interrupção e o que sai do previsto
continua passando por uma checagem.

Existe uma skill que gera essa lista a partir do seu próprio histórico, em vez de você
adivinhar: `/fewer-permission-prompts`.

**Quando isso não basta** — um ambiente isolado (container/VM) onde você quer zero
prompts, ou uma wave que precisa ser à prova de travamento — veja
[**Overrides do `implement-and-evaluate-tmux`**](#implement-and-evaluate-tmux) e a nota
sobre modos de permissão logo abaixo dela.

## Como invocar as skills

Instalado como plugin, o nome completo é `/ia-package:<skill>`:

```
/ia-package:implement-and-evaluate F03
```

A forma curta (`/implement-and-evaluate F03`) funciona quando nenhum outro plugin
instalado tem uma skill com o mesmo nome. As skills também são acionadas pelo próprio
contexto da conversa, sem barra — pedir "implementa e avalia a F03" chega no mesmo
lugar. Este README usa a forma completa, que nunca é ambígua.

## O fluxo completo

### 1 — PRD do produto inteiro

```
/ia-package:prd-writer-for-complete-project MeuProduto docs/ docs/PRD.md "descrição do produto ou @arquivo-de-contexto.md"
```

Os parâmetros são o nome do projeto, a pasta de saída, o path do PRD e a descrição
(ou arquivos de contexto). A skill conduz uma entrevista de 12 blocos, uma pergunta
por vez, e grava dois arquivos: o `docs/PRD.md` — 12 seções de **negócio**, sem
nenhuma decisão técnica, mais o `Appendix A: Implementation Planning` com o grafo de
dependências, as waves e as Foundation Features — e o `docs/prd_progress.json`, o
registro de estado que o resto do pipeline lê e escreve.

Um PRD por projeto. Regenerar preserva o estado de execução das features que
continuam existindo e marca como `removed` as que saíram.

### 2 — Spec, plano e contrato de cada feature

```
/ia-package:spec-writer F03                # uma feature, com entrevista
/ia-package:spec-writer wave 3             # a wave inteira, em paralelo, com auto-accept
/ia-package:spec-writer F03 create-issue   # cria também a issue de acompanhamento no forge
```

Gera o trio `spec.md` + `plan.md` + `contract.md` em `docs/F03-video-upload/`. O batch
mode liga sozinho quando o input tem vários IDs ou uma referência de wave — todas as
features do batch precisam ser da mesma wave. Sem a flag `create-issue`, a skill
pergunta `y/n` antes de criar a issue.

### 3 — Versione o planejamento na branch padrão (obrigatório só na wave)

Nenhuma skill do plugin commita na branch padrão (na Tray ela é protegida): o
planejamento chega lá por commit ou PR/MR seu. Depois do merge, `git pull` na branch
padrão local.

- **Wave: obrigatório.** As worktrees nascem de um commit e não enxergam o que está só
  no disco. Sem isso, a wave para antes de despachar.
- **Uma feature: dispensável.** O próprio orquestrador commita o trio junto com os
  artefatos, e o PR sai com o contrato que validou a implementação. Se o PRD ou o
  `prd_progress.json` não estiverem na branch padrão, a execução avisa numa linha e segue.

Veja [**O planejamento precisa estar na branch padrão**](#o-planejamento-precisa-estar-na-branch-padrão).

### 4 — Execute

```
/ia-package:implement-and-evaluate F03                      # uma feature
/ia-package:implement-and-evaluate-tmux wave 3              # a wave inteira, em paralelo
```

Uma feature: o orquestrador garante a branch de trabalho, roda o implementador uma
vez e alterna evaluator e fix-runner até o veredito ficar limpo. No sucesso, commita
os artefatos de avaliação, integra a branch padrão, faz push e abre o PR/MR.

Uma wave: um worktree git e uma janela tmux por feature, cada uma rodando o
`implement-and-evaluate` por conta própria. A sessão Main só despacha, espera e
consolida. Formas de seleção:

| Forma | Efeito |
|---|---|
| `wave 3` | toda feature da wave 3 com status `pending`, `fail` ou `implemented` |
| `F03,F05,F07` | IDs explícitos |
| `wave 3 except F04` | a wave menos as exclusões |
| `wave 3 only F04,F05` | a wave restrita às inclusões |

A wave aborta na largada — antes de criar a primeira worktree — quando o planejamento
não está na branch padrão, quando o CLI do forge falta, ou quando alguma feature
depende de outra que ainda não está `done` (dependência dentro da mesma wave está
fora de escopo: implemente a dependência antes, com o `implement-and-evaluate`).

Durante a execução, a janela 0 do tmux é um dashboard ao vivo. No fim, a Main emite um
relatório consolidado e grava o `wave-status.md`.

Cada equipe levanta o próprio ambiente de avaliação, isolado das outras — banco,
containers e portas próprios por execução. Veja
[**Isolamento entre execuções paralelas**](#isolamento-entre-execuções-paralelas).

### 5 — Leia o resultado

Cada execução termina com um status final no chat e um journal em arquivo. Veja
[**Estados finais**](#estados-finais).

### Rodar uma etapa isolada

As skills de execução são independentes e podem ser invocadas sozinhas — útil para
re-verificar ou corrigir sem repassar pelo loop inteiro:

```
/ia-package:evaluator F03                         # só o veredito
/ia-package:evaluator F03 only failed-last-run    # só o que reprovou na última vez
/ia-package:design-review F03                     # só a qualidade visual
/ia-package:fix-runner eval-report=docs/F03-video-upload/eval-report-<ts>.md failed-items=API-UPLOAD-03
/ia-package:implement-feature F03                 # só a implementação
```

## O que vem dentro

### Skills de execução

| Skill | Produz |
|---|---|
| `prd-writer-for-complete-project` | PRD do produto inteiro, só de negócio: 12 seções + `Appendix A` de planejamento, mais o `prd_progress.json` que o resto do pipeline usa como registro de estado |
| `spec-writer` | `spec.md` + `plan.md` + `contract.md` por feature (tem batch mode por wave) |
| `implement-feature` | Implementa a feature fase a fase, um commit por fase, guiada pelo contrato |
| `evaluator` | Exercita cada item do `contract.md` ponta a ponta num ambiente efêmero e grava o veredito em `eval-report-<ts>.md` |
| `design-review` | Avalia a qualidade visual da UI de uma feature: captura screenshots em 3 viewports e nos estados de borda, roda um piso mecânico de acessibilidade e grava notas por dimensão mais uma lista de correções em `design-report-<ts>.md` |
| `fix-runner` | Passada corretiva sobre os itens reprovados de um eval-report, sobre os achados de um design-report, ou resolução de conflitos de merge |
| `generate-development-guideline` | Diretriz de desenvolvimento por linguagem/stack, em `docs/<linguagem>-development-guidelines.md`. Não participa do loop: nenhuma outra skill a lê sozinha — cite o path no `CLAUDE.md` do projeto para que o `implement-feature` a siga |

### Skills de orquestração

Encadeiam as skills acima em loop, sem intervenção entre os ciclos:

| Skill | Faz |
|---|---|
| `implement-and-evaluate` | Uma feature: cria a branch de trabalho se a execução começar na branch padrão, implementa → avalia → corrige → reavalia até o contrato ser honrado, o retry budget acabar ou o circuit-breaker disparar. Com `with design review`, roda também um loop de design antes do PR. No sucesso, commita os artefatos de avaliação, integra a branch padrão, faz push e abre o PR |
| `implement-and-evaluate-tmux` | Uma wave inteira em paralelo: um worktree git e uma janela tmux por feature, cada uma rodando `implement-and-evaluate` por conta própria. A sessão Main só despacha, espera e consolida |

Cada skill é invocada num subagente novo, para que o contexto do orquestrador continue
pequeno ao longo de muitos ciclos.

### Hooks

Rodam sozinhos, sem invocação. Ficam em silêncio quando não têm nada a dizer.

| Evento | Script | Para quê |
|---|---|---|
| `SessionStart` | `pipeline-status.sh` | Diz ao Claude, já na abertura da sessão, quais artefatos do pipeline já existem (incluindo contratos, eval-reports e journals por feature) e como está o tally de status do `prd_progress.json` |
| `PostToolUse` (Write\|Edit) | `flag-open-gaps.sh` | Aponta ao Claude `[NEEDS INPUT]`, `TBD` e `<preencher>` deixados em documentos de `docs/`. Ignora os artefatos gerados pelo loop (`eval-report-*`, `orchestration-*`, `wave-status.md`), onde um `TBD` citado como evidência é conteúdo legítimo |

## Overrides

Linguagem natural, em qualquer posição do input. O que o orquestrador não reconhece é
repassado literalmente ao `implement-feature` (ex.: `skip lint`, `stub OpenAI`,
`only phases 1 and 2`, `pause between phases`).

### `implement-and-evaluate`

| Override | Efeito |
|---|---|
| `max <N> retries` | Retry budget do orquestrador. Default `3` |
| `no retries` | Um ciclo só: implementação inicial + um evaluator |
| `unlimited retries` | Sem budget. O circuit-breaker e a guarda de 3 `gates-failed` consecutivos continuam valendo |
| `pause between cycles` | Espera `ok` / `continue` / `segue` / `yes` no chat entre cada ciclo |
| `keep eval env` | Terminando com status diferente de `success`, re-invoca o evaluator uma vez com `keep env` para você inspecionar o ambiente com falha |
| `with design review` | Liga o loop de design entre o veredito limpo e o PR: `design-review` e, se reprovar, `fix-runner` Mode C |
| `max <N> design passes` | Budget do loop de design. Default `2`. Só tem efeito com `with design review` |
| `no branch` | Fica na branch atual, seja qual for — inclusive a padrão. Rodando assim na branch padrão, o PR não é aberto |
| `progress-path=<path>` | Path do `prd_progress.json`, repassado às três sub-skills para que gravem no mesmo arquivo |

```
/ia-package:implement-and-evaluate F03 max 5 retries with design review
```

### `implement-and-evaluate-tmux`

Valem para a wave e não são repassados às equipes:

| Override | Efeito | Default |
|---|---|---|
| `max-parallel=<N>` | Teto de equipes concorrentes | `3` |
| `team-timeout=<N>m` | Timeout de relógio de parede por equipe; passado isso a Main mata a janela e marca `timeout` | `90m` |
| `permission-mode=<modo>` | Modo de permissão do `claude` de cada equipe: `auto`, `acceptEdits`, `manual`, `plan`, `dontAsk`, `bypassPermissions` | `auto` |
| `keep worktrees` | Não apaga as worktrees no sucesso | off |
| `clean worktrees` | Apaga as worktrees mesmo em falha | off |
| `no foundation serialization` | Desliga a serialização das Foundation Features. Escape hatch para projetos que já têm o scaffolding | off |
| `progress-path=<path>` | Um único `prd_progress.json` para toda equipe e para o reconcile da Main | auto-descoberta |

Qualquer override do `implement-and-evaluate` é repassado a todas as equipes, com
duas exceções: `pause between cycles` e `pause between phases` abortam a wave —
várias janelas não conseguem todas esperar input humano.

> **Sobre travar esperando aprovação.** O `auto` (default) aprova com um classificador
> em background, mas volta a perguntar depois de 3 bloqueios seguidos ou 20 no total, e
> pode nem estar disponível (depende do plano, ou de `permissions.disableAutoMode` nas
> settings). Aí a equipe fica parada até o `team-timeout` — o sintoma no dashboard é uma
> equipe em `running` com o ciclo sem avançar.
>
> A primeira defesa é o `.claude/settings.json` com `permissions.allow`, descrito em
> [**Permissões**](#permissões-pré-aprove-o-que-o-pipeline-usa): o que está pré-aprovado
> nunca chega ao classificador. Se ainda assim precisar de garantia:
>
> - `permission-mode=bypassPermissions` — pula os prompts. Só em ambiente isolado
>   (container/VM); as regras `deny` continuam valendo.
> - `permission-mode=dontAsk` — o modo desenhado para CI: **a sessão nunca espera
>   input**. Ele *nega* o que pediria aprovação, então a equipe falha rápido em vez de
>   pendurar. Só é útil com uma allowlist boa.
>
> Um detalhe que pega: `AskUserQuestion` — o agente fazendo uma pergunta a você — não é
> auto-aprovado **em nenhum modo, nem no `bypassPermissions`**. Só o `dontAsk` o
> resolve, negando.

### `evaluator` e `design-review`

| Skill | Overrides |
|---|---|
| `evaluator` | `only API`, `only API-UPLOAD-03`, `only API and E2E`, `skip UI`, `only failed-last-run`, `keep env`, `pause on first failure` |
| `design-review` | `url=<url>`, `routes=/a,/b`, `threshold=<N>` (default `7.0`), `calibration=greenfield` / `calibration=design-system`, `only mobile`, `only desktop`, `skip tablet`, `skip states`, `keep env`, `no fixes` |

O orquestrador **não** repassa overrides ao evaluator (exceto `keep env`) nem ao
fix-runner: os dois rodam com seus defaults, para que o veredito e a passada corretiva
fiquem reproduzíveis.

## Onde os documentos são gravados

Nenhuma etapa termina no chat: cada uma grava o arquivo e informa o path. É o que faz a
etapa seguinte encontrar o que a anterior escreveu — o hook de sessão e as skills de
execução só enxergam arquivo, não o que passou na conversa.

| Documento | Path | Regra |
|---|---|---|
| PRD do produto | `docs/PRD.md` | um por projeto |
| Estado das features | `docs/prd_progress.json` | um por projeto |
| Spec, plano e contrato | `docs/F<ID>-<slug>/{spec,plan,contract}.md` | um trio por feature |
| Relatório de avaliação | `docs/F<ID>-<slug>/eval-report-<ts>.md` | um por execução do `evaluator` |
| Screenshots da avaliação | `docs/F<ID>-<slug>/eval-screenshots-<ts>/` | por execução com UI/E2E |
| Relatório de design | `docs/F<ID>-<slug>/design-report-<ts>.md` | um por execução do `design-review` |
| Screenshots do design review | `docs/F<ID>-<slug>/design-screenshots-<ts>/` | por execução do `design-review` |
| Journal de orquestração | `docs/F<ID>-<slug>/orchestration-<ts>.md` | um por execução do orquestrador |
| Status da wave | `.claude/worktrees/.wave-<run-id>/wave-status.md` | um por execução da wave |
| Diretriz de código | `docs/<linguagem>-development-guidelines.md` | um por linguagem |

A pasta da feature (`docs/F03-video-upload/`) sai do nome da feature na Seção 6 do PRD e é
o endereço de tudo que diz respeito a ela. Os `eval-report-*.md` e os `orchestration-*.md`
são histórico com timestamp: cada execução grava um arquivo novo, nenhum é sobrescrito.
Não edite nenhum dos dois à mão — para um veredito novo, rode o `evaluator` de novo.

## Estados finais

Toda execução do `implement-and-evaluate` termina em um destes seis status, no chat e
na linha `**Status:**` do journal:

| Status | O que aconteceu | O que fazer |
|---|---|---|
| `success` | Contrato honrado. Artefatos commitados, push feito, PR/MR aberto | Revisar e mergear o PR/MR |
| `manual-pending` | Sobraram apenas itens `MANUAL` — subjetivos, que nenhum ciclo de fix resolve | Revisar esses itens à mão no eval-report |
| `stuck` | Circuit-breaker: o mesmo conjunto de falhas em dois ciclos seguidos, sem nenhum item novo passando. Ou 3 ciclos seguidos em que os quality gates reprovaram antes de qualquer avaliação | Ler o último eval-report. Normalmente é contrato ambíguo ou ambiente de avaliação mal declarado no `CLAUDE.md` — mais ciclos não resolvem |
| `exhausted` | O retry budget acabou sem veredito limpo | Re-rodar (a branch de trabalho é reusada) ou aumentar o budget com `max <N> retries` |
| `aborted` | Abort antes das fases (trio ausente, dependência não implementada), do fix-runner ou do evaluator | Corrigir o que o abort apontou e re-rodar |
| `pr-blocked` | A avaliação passou, mas o merge da branch padrão gerou conflito que o fix-runner não resolveu. A implementação está certa; só a integração travou | Resolver o merge à mão, commitar (incluindo os artefatos que o chat report lista), push e abrir o PR/MR |

Na wave, cada equipe reporta um destes mais o `timeout`, gravado pela Main quando o
`team-timeout` estoura. A worktree de uma equipe que falhou é preservada para inspeção.

O `prd_progress.json` tem o seu próprio vocabulário de status por feature (`pending`,
`implementing`, `implemented`, `done`, `fail`, `pr-blocked`, `removed`), definido em
`references/progress-schema.md`.

## Como o loop decide

### O contrato é o eixo

O `contract.md` é a peça que sustenta o loop: itens Given/When/Then por superfície
(API, UI, E2E…), uma seção `Prerequisites` e um `Coverage Manifest` que liga cada
critério de aceite do PRD aos itens que o cobrem. Quem implementa usa como checklist;
o `evaluator` usa como asserção.

Não edite `contract.md`, `spec.md` ou `plan.md` para fazer uma avaliação passar. Se a
correção exigir mudança no contrato, o trio precisa ser regerado pelo `spec-writer` —
é revisão de escopo, não conserto.

### O `prd_progress.json` é o registro de estado

O `prd-writer-for-complete-project` o cria a partir do `Appendix A`, e `implement-feature`,
`evaluator`, `fix-runner`, `implement-and-evaluate` e `implement-and-evaluate-tmux` leem e
escrevem nele ao longo dos ciclos. O schema — chaves, valores de
`status`, semântica dos campos e invariantes — vive em `references/progress-schema.md`,
na raiz do plugin. É a fonte canônica; cada skill documenta apenas as próprias escritas
e aponta para lá.

### O `design-review` é opt-in

O `evaluator` responde *a feature faz o que prometeu?*; o `design-review` responde *a
feature está apresentável?*. Nenhum bullet Given/When/Then captura "isso parece um
template scaffoldado" — por isso a avaliação visual é uma skill separada, com rubrica
ponderada, evidência capturada e piso mecânico de acessibilidade.

Ela só entra no orquestrador com `with design review`: a maioria das features não tem
UI, e qualidade de design é decisão de produto, não invariante de correção. Mesmo com o
override, o loop de design é pulado quando o contrato não declara superfície `## UI`
nem `## E2E`.

### Isolamento entre execuções paralelas

Duas features rodando ao mesmo tempo — as equipes de uma wave, ou dois terminais seus —
não podem compartilhar ambiente de avaliação. Não é só o risco de `EADDRINUSE`: se a
equipe B bate no serviço que a equipe A subiu, o veredito de B é colhido da feature
errada, e um contrato passa ou reprova por um motivo que não existe.

Cada execução do `evaluator` e do `design-review` isola tudo o que levanta:

| Recurso | Como é isolado |
|---|---|
| Código | uma worktree git por feature, na wave |
| Banco efêmero | nome próprio por execução: `eval_<feature-id>_<run-id>` (`dsg_…` no design-review) |
| Containers, volumes e rede | nome de projeto compose próprio: `docker compose -p eval_<feature-id>_<run-id>` |
| Tmpdir e PIDs | `evaluator-<feature-id>-<run-id>/` com `processes.lock` |
| **Portas** | uma porta livre é alocada por serviço, a cada execução, e injetada por variável de ambiente |

Portas são o único recurso que não dá para nomear, então são **alocadas** em vez de
fixadas. Para isso funcionar, cada serviço do projeto precisa aceitar a porta por
variável ou flag — é o que a tabela do bloco `## Ambiente de avaliação` do `CLAUDE.md`
declara. Serviço com porta cravada não trava a execução: vira um soft-fail no relatório
avisando que execuções paralelas daquele serviço vão colidir.

A limpeza segue o mesmo marcador: cada execução derruba apenas o que ela mesma nomeou,
e uma execução viva (PID no `processes.lock`) nunca tem os recursos removidos por outra.

### A branch de trabalho

O `implement-and-evaluate` commita muito: um commit por fase do `implement-feature`,
um por ciclo do `fix-runner` e os artefatos de avaliação no fim. Invocado a partir da
branch padrão, tudo isso cairia direto nela — e o passo do PR só descobriria que não
há de onde abrir depois de todos os ciclos.

Por isso o orquestrador **garante a branch antes do primeiro commit**: se a branch em
checkout for a padrão, ele entra em `feat/<nome da pasta da feature>` — criando se não
existir, reusando se existir, porque re-rodar depois de um `exhausted` é caso normal de
uso. O nome sai da pasta **verbatim**: `docs/F03-video-upload/` → `feat/F03-video-upload`,
exatamente o nome que o `implement-and-evaluate-tmux` dá à branch da worktree, para que
as duas portas de entrada nunca produzam branches diferentes para a mesma feature.

Fora da branch padrão o passo é no-op — inclusive dentro de cada worktree da wave, que
já nasce na branch da feature. Se a branch já estiver em checkout numa worktree, a
execução aborta citando o path, em vez de disputar a branch com a wave que está
rodando. Para ficar deliberadamente onde está, use `no branch`.

### O planejamento precisa estar na branch padrão

O planejamento — `docs/PRD.md`, `docs/prd_progress.json` e o trio `spec.md` /
`plan.md` / `contract.md` de cada feature — precisa estar **commitado na branch
padrão** antes da execução. As skills gravam esses arquivos em disco e param aí:
nenhuma skill do plugin commita na branch padrão (na Tray ela é protegida).

O motivo é a wave. O `implement-and-evaluate-tmux` cria uma worktree por feature a
partir de um commit da branch padrão, e uma worktree só tem o que está commitado:
arquivo que existe apenas no disco do checkout principal não aparece nela, e cada
equipe abortaria com "trio ausente" ou "PRD não encontrado". Por isso a wave confere
antes de criar a primeira worktree: o PRD, o `prd_progress.json` e o trio de cada
feature selecionada precisam existir na branch padrão **local** e ser iguais ao que
está em disco. Se algo faltar, ela lista tudo e para:

```
Planejamento fora da branch padrão (main) — as worktrees nasceriam sem ele:
  - docs/F03-video-upload/contract.md — não versionado
  - docs/PRD.md — diverge do que está commitado
Commite ou abra um PR/MR com esses arquivos, atualize a main local (git pull) e re-rode.
```

A conferência é contra a ref local porque é dela que as worktrees nascem — depois do
merge do PR/MR do planejamento, é o `git pull` que o traz para ela. A igualdade com o
disco garante que a seleção da wave, feita sobre o `prd_progress.json` do disco, e as
equipes, que leem o da branch, enxergam o mesmo estado.

Uma feature só (`/ia-package:implement-and-evaluate F03`) não aborta. O trio entra no
commit de artefatos da própria feature, e a PR/MR sai com o contrato que a validou; se
o PRD ou o `prd_progress.json` não estiverem na branch padrão, a execução avisa numa
linha e segue.

## Forge: GitHub ou GitLab

O pipeline abre issues (no `spec-writer`) e pull/merge requests (no
`implement-and-evaluate`), e funciona nos dois. A plataforma (o *forge*) é resolvida
**uma vez por execução**, nesta ordem:

1. **A linha `- Forge: github|gitlab` no `CLAUDE.md` do seu projeto.** Vence tudo.
2. **Auto-detecção pelo `git remote get-url origin`** — `github.com` → GitHub;
   `gitlab.com` ou host cujo primeiro rótulo é `gitlab` (ex.: `gitlab.tray.net.br`)
   → GitLab.
3. **Sem remote ou host não reconhecido** → assume GitHub e registra um soft-fail
   dizendo como declarar o contrário.

GitLab auto-hospedado num host que não se chama `gitlab.*` **não é detectável** —
é para isso que existe a linha no `CLAUDE.md`. Como cada projeto carrega o seu,
trocar de projeto não exige mexer no plugin:

```markdown
## Forge
- Forge: github
<!-- - Forge: gitlab -->
```

**Pré-requisito de CLI.** As operações de forge usam `gh` (GitHub) ou `glab`
(GitLab), instalado e autenticado:

| Forge | CLI | Instalação | Autenticação |
|---|---|---|---|
| GitHub | `gh` | <https://github.com/cli/cli#installation> | `gh auth login` |
| GitLab | `glab` | <https://gitlab.com/gitlab-org/cli#installation> | `glab auth login` |

**Sem o CLI, nada se perde.** Implementação, avaliação, correção e commits não
dependem de forge nenhum. Quando o CLI falta ou não está autenticado, o pipeline
faz o trabalho inteiro, salva os arquivos, commita, e imprime no relatório o
comando manual do que ficou faltando (abrir a issue, abrir o PR/MR). A única
exceção é o `implement-and-evaluate-tmux`, que checa o CLI antes de despachar e
aborta a wave — falhar na largada custa menos que descobrir depois de 30 minutos
de ciclos que nenhuma equipe consegue abrir MR.

O mapeamento completo — as seis operações usadas, o comando de cada forge, os
nomes de campo que divergem (`body` ⇄ `description`, `OPEN` ⇄ `opened`) e os
literais de schema que **não** mudam — vive em `references/forge.md`, na raiz do
plugin. É a fonte canônica; as skills apontam para lá em vez de embutir comandos.

> **Os comandos `glab` ainda não foram validados contra um binário local.** Foram
> escritos a partir da documentação oficial. Flags do `glab` variam entre versões;
> confirme com `glab <comando> --help` na primeira execução real. Um flag errado
> degrada para o soft-fail normal — "abra o MR à mão" —, nunca para trabalho perdido.

## Contribuindo

Quem for **editar o plugin** — e não apenas usá-lo — precisa conhecer a regra de
idioma (qual string carrega peso e não pode ser traduzida), o setup de
desenvolvimento local e a armadilha de descoberta de componentes. Tudo isso está em
[`CONTRIBUTING.md`](CONTRIBUTING.md).

## Licença

MIT
