# ia-package

Plugin do Claude Code com um pipeline de documentação técnica assistida por IA:
entrevistas guiadas que produzem **PRD → HLD → FDD → spec/plan/contract →
implementação → avaliação → correção → ADRs → diagramas C4/Mermaid**.

Os documentos são gerados em português (pt-BR).

## Instalação

```bash
# 1. registre o repositório como marketplace
/plugin marketplace add javielrezende/ia-package

# 2. instale
/plugin install ia-package@ia-package
```

Depois de instalar, copie o `templates/CLAUDE.example.md` para a raiz do seu projeto como
`CLAUDE.md` e preencha a stack, os caminhos e a seção **Forge** — é isso que faz as
skills gerarem documentos aderentes ao projeto em vez de genéricos.

## O que vem dentro

### Skills (invocadas por `/nome` ou automaticamente pelo contexto)

**Entrevistas** (`skills/for-interviews/`) — uma pergunta por vez, saída em Markdown
com export opcional em JSON:

| Skill | Produz | Onde grava |
|---|---|---|
| `generate-prd-for-feature` | PRD de **uma** feature | `docs/F<ID>-<slug>/PRD.md` |
| `generate-high-level-design` | HLD: arquitetura, componentes, fluxos, modelo de dados | `docs/HLD.md` |
| `generate-feature-design-doc` | FDD: contratos públicos, matriz de erros, observabilidade | `docs/F<ID>-<slug>/FDD.md` |
| `generate-deep-research-part-1` | Briefing de pesquisa (até 6 perguntas) | saída no chat |
| `generate-deep-research-part-2` | Formata o resultado da pesquisa em 16 seções | saída no chat |

**Execução:**

| Skill | Produz |
|---|---|
| `prd-writer-for-complete-project` | PRD do produto inteiro, só de negócio: 12 seções + `Appendix A` de planejamento, mais o `prd_progress.json` que o resto do pipeline usa como registro de estado |
| `spec-writer` | `spec.md` + `plan.md` + `contract.md` por feature (tem batch mode por wave) |
| `implement-feature` | Implementa a feature fase a fase, um commit por fase, guiada pelo contrato |
| `evaluator` | Exercita cada item do `contract.md` ponta a ponta num ambiente efêmero e grava o veredito em `eval-report-<ts>.md` |
| `design-review` | Avalia a qualidade visual da UI de uma feature: captura screenshots em 3 viewports e nos estados de borda, roda um piso mecânico de acessibilidade e grava notas por dimensão mais uma lista de correções em `design-report-<ts>.md` |
| `fix-runner` | Passada corretiva sobre os itens reprovados de um eval-report, sobre os achados de um design-report, ou resolução de conflitos de merge |
| `generate-development-guideline` | Diretriz de desenvolvimento por linguagem/stack, em `docs/<linguagem>-development-guidelines.md` |

**Orquestração** — encadeiam as skills acima em loop, sem intervenção entre os ciclos:

| Skill | Faz |
|---|---|
| `implement-and-evaluate` | Uma feature: cria a branch de trabalho se a execução começar na branch padrão, implementa → avalia → corrige → reavalia até o contrato ser honrado, o retry budget acabar ou o circuit-breaker disparar. Com `with design review`, roda também um loop de design antes do PR. No sucesso, commita os artefatos de avaliação, integra a branch padrão, faz push e abre o PR |
| `implement-and-evaluate-tmux` | Uma wave inteira em paralelo: um worktree git e uma janela tmux por feature, cada uma rodando `implement-and-evaluate` por conta própria. A sessão Main só despacha, espera e consolida |

O `contract.md` é a peça que sustenta o loop: itens Given/When/Then por superfície
(API, UI, E2E…), uma seção `Prerequisites` e um `Coverage Manifest` que liga cada
critério de aceite do PRD aos itens que o cobrem. Quem implementa usa como checklist;
o `evaluator` usa como asserção.

O `prd_progress.json` é o outro artefato compartilhado do loop: o
`prd-writer-for-complete-project` o cria a partir do `Appendix A`, e as cinco skills de
execução leem e escrevem nele ao longo dos ciclos. O schema — chaves, valores de
`status`, semântica dos campos e invariantes — vive em `references/progress-schema.md`,
na raiz do plugin. É a fonte canônica; cada skill documenta apenas as próprias escritas
e aponta para lá.

O `design-review` é o eixo ortogonal: o `evaluator` responde *a feature faz o que
prometeu?*, o `design-review` responde *a feature está apresentável?*. Nenhum bullet
Given/When/Then captura "isso parece um template scaffoldado" — por isso a avaliação
visual é uma skill separada, com rubrica ponderada, evidência capturada e piso mecânico
de acessibilidade. Ela é **opt-in** no orquestrador (`with design review`): a maioria das
features não tem UI, e qualidade de design é decisão de produto, não invariante de
correção.

### Commands

| Command | Faz |
|---|---|
| `/adr-generate [MODULE_ID ...] [--output-dir=] [--context-dir=] [--language=]` | Fase 3 do fluxo de ADRs: um agente `adr-generator` por potential ADR, em paralelo, depois a numeração sequencial e o relatório |
| `/generate-c4-from-fdd <fdd.md> [pasta] [--no-images]` | C4 em PlantUML a partir do FDD |
| `/generate-mermaid-diagram-from-fdd <fdd.md> [pasta]` | Diagramas Mermaid a partir do FDD |

### Agents

| Agent | Faz |
|---|---|
| `adr-analyzer` | Mapeia o codebase e identifica ADRs candidatos |
| `adr-generator` | Gera um ADR formal em MADR (um arquivo por vez) |
| `adr-linker` | Cria links bidirecionais entre ADRs |
| `c4-diagram-generator` | Motor por trás de `/generate-c4-from-fdd` |
| `mermaid-diagram-generator` | Motor por trás de `/generate-mermaid-diagram-from-fdd` |

### Hooks

Rodam sozinhos, sem invocação. Ficam em silêncio quando não têm nada a dizer.

| Evento | Script | Para quê |
|---|---|---|
| `SessionStart` | `pipeline-status.sh` | Diz ao Claude, já na abertura da sessão, quais artefatos do pipeline já existem (incluindo contratos, eval-reports e journals por feature) e como está o tally de status do `prd_progress.json` |
| `PostToolUse` (Write\|Edit) | `flag-open-gaps.sh` | Aponta ao Claude `[NEEDS INPUT]`, `TBD` e `<preencher>` deixados em documentos de `docs/`. Ignora os artefatos gerados pelo loop (`eval-report-*`, `orchestration-*`, `wave-status.md`), onde um `TBD` citado como evidência é conteúdo legítimo |
| `SubagentStop` | hook do tipo `prompt` | Confere, pela mensagem final, se os agentes geradores relataram os artefatos que prometeram |

Os dois primeiros são hooks de comando (bash + python3, sem dependências externas);
o terceiro é um hook `prompt`, avaliado por um modelo. Exigem apenas `bash` e `python3`
no PATH — se `python3` faltar, os scripts saem em silêncio em vez de quebrar a sessão.

## Onde os documentos são gravados

As entrevistas não terminam no chat: cada uma grava o arquivo e informa o path. É o que
faz a etapa seguinte encontrar o que a anterior escreveu — o hook de sessão só enxerga
arquivo, e o `spec-writer` lê o que está em disco, não o que passou na conversa.

| Documento | Path | Regra |
|---|---|---|
| PRD do produto | `docs/PRD.md` | um por projeto |
| HLD | `docs/HLD.md` | um por projeto |
| PRD de feature | `docs/F<ID>-<slug>/PRD.md` | um por feature |
| FDD | `docs/F<ID>-<slug>/FDD.md` | um por feature |
| Diretriz de código | `docs/<linguagem>-development-guidelines.md` | um por linguagem |

O PRD de feature e o FDD são resolvidos pela pasta da feature (`docs/F03-video-upload/`,
a mesma que guarda `spec.md`, `plan.md` e `contract.md`). Quando nenhuma pasta casa — a
entrevista foi feita antes do PRD do produto —, o arquivo cai em `docs/PRD-<slug>.md` ou
`docs/FDD-<slug>.md` e a skill diz que fez isso. Quando mais de uma casa, ela pergunta em
vez de escolher.

**Nada é sobrescrito calado.** Se o arquivo de destino já existe, a skill mostra o que há
lá e oferece três saídas: sobrescrever, gravar com a data no nome, ou não gravar. O
`generate-prd-for-feature` nunca escreve em `docs/PRD.md`: esse path é do PRD do produto
inteiro, e o resto do pipeline o usa como fonte de escopo.

## O fluxo de ADRs

São três fases, e cada uma tem porta de entrada própria:

1. **Mapeamento e identificação** — o agente `adr-analyzer` varre o codebase, grava
   `docs/adrs/mapping.md` e depois os potential ADRs em
   `docs/adrs/potential-adrs/{must-document,consider}/<MODULE>/`.
2. **Geração** — `/adr-generate` pega esses arquivos e produz os ADRs formais em MADR
   em `docs/adrs/generated/<MODULE>/` (ou `needs-input/` quando faltam decisões de
   negócio, custo ou compliance para um humano responder).
3. **Ligação** — o agente `adr-linker` escreve os relacionamentos entre os ADRs. O
   `/adr-generate` oferece rodá-lo no fim, e só roda com o sim explícito: ele reescreve
   cabeçalhos de ADRs que já existiam.

O `adr-generator` processa **um** arquivo por invocação, então `/adr-generate` despacha
um agente por potential ADR em paralelo (até 8 por lote). Isso é o que torna a
**numeração trabalho do command, não do agente**: agentes paralelos não conseguem
combinar números entre si, então cada um grava o placeholder `ADR-XXX` e o command
atribui a sequência no fim, numa passada serial, continuando de onde os ADRs existentes
pararam.

Cada potential ADR só vai para `potential-adrs/done/` depois de o ADR formal estar em
disco. Por isso rodar `/adr-generate` de novo retoma o que falhou sem duplicar o que já
passou — e `/adr-generate <MODULE_ID>` limita a rodada a um módulo, que é como dar conta
de um codebase grande sem estourar o contexto.

## Antes de executar

O planejamento — `docs/PRD.md`, `docs/prd_progress.json` e o trio `spec.md` /
`plan.md` / `contract.md` de cada feature — precisa estar **commitado na branch
padrão** antes de rodar a execução. As skills gravam esses arquivos em disco e param
aí: nenhuma skill do plugin commita na branch padrão (na Tray ela é protegida). O
planejamento chega lá por commit ou PR/MR seu.

O motivo é a wave. O `implement-and-evaluate-tmux` cria uma worktree por feature a
partir de um commit da branch padrão, e uma worktree só tem o que está commitado:
arquivo que existe apenas no disco do checkout principal não aparece nela, e cada
equipe abortaria com "trio ausente" ou "PRD não encontrado". Por isso a wave confere
antes de criar a primeira worktree (Step 1.6b): o PRD, o `prd_progress.json` e o trio
de cada feature selecionada precisam existir na branch padrão **local** e ser iguais
ao que está em disco. Se algo faltar, ela lista tudo e para:

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

Uma feature só (`/implement-and-evaluate F03`) não aborta. O trio entra no commit de
artefatos da própria feature, e a PR/MR sai com o contrato que a validou; se o PRD
ou o `prd_progress.json` não estiverem na branch padrão, a execução avisa numa linha
e segue.

## A branch de trabalho

O `implement-and-evaluate` commita muito: um commit por fase do `implement-feature`,
um por ciclo do `fix-runner` e os artefatos de avaliação no fim. Invocado a partir da
branch padrão, tudo isso cairia direto nela — e o passo do PR só descobriria que não
há de onde abrir depois de todos os ciclos.

Por isso o orquestrador **garante a branch antes do primeiro commit** (Step 2.5): se
a branch em checkout for a padrão, ele entra em `feat/<nome da pasta da feature>` —
criando se não existir, reusando se existir, porque re-rodar depois de um `exhausted`
é caso normal de uso. O nome sai da pasta **verbatim**: `docs/F03-video-upload/` →
`feat/F03-video-upload`, exatamente o nome que o `implement-and-evaluate-tmux` dá à
branch da worktree, para que as duas portas de entrada nunca produzam branches
diferentes para a mesma feature.

Fora da branch padrão o step é no-op — inclusive dentro de cada worktree da wave, que
já nasce na branch da feature. Se a branch já estiver em checkout numa worktree, a
execução aborta citando o path, em vez de disputar a branch com a wave que está
rodando.

Para ficar deliberadamente onde está, use o override `no branch`:

```
/implement-and-evaluate F03 no branch
```

Rodando assim a partir da branch padrão, o PR não é aberto — e o aviso no relatório
final diz exatamente isso, em vez de só constatar que a branch é a padrão.

## Forge: GitHub ou GitLab

O pipeline abre issues e pull/merge requests, e funciona nos dois. A plataforma
(o *forge*) é resolvida **uma vez por execução**, nesta ordem:

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
exceção é o `implement-and-evaluate-tmux`, que checa o CLI no Step 2.4 e aborta a
wave antes de despachar — falhar na largada custa menos que descobrir depois de
30 minutos de ciclos que nenhuma equipe consegue abrir MR.

O mapeamento completo — as seis operações usadas, o comando de cada forge, os
nomes de campo que divergem (`body` ⇄ `description`, `OPEN` ⇄ `opened`) e os
literais de schema que **não** mudam — vive em `references/forge.md`, na raiz do
plugin. É a fonte canônica; as skills apontam para lá em vez de embutir comandos.

> **Os comandos `glab` ainda não foram validados contra um binário local.** Foram
> escritos a partir da documentação oficial. Flags do `glab` variam entre versões;
> confirme com `glab <comando> --help` na primeira execução real. Um flag errado
> degrada para o soft-fail normal — "abra o MR à mão" —, nunca para trabalho perdido.

## Regra de idioma

Os documentos gerados são pt-BR, e as mensagens que o pipeline escreve no chat também.
O que **não** é traduzido é o inglês que carrega peso: o texto que outra skill, um
script ou um parser vai procurar. Essa fronteira é a regra — quem editar o plugin
precisa saber de que lado cada string está antes de mexer nela.

**Carrega peso — não traduza:**

| Categoria | Exemplos | Quem depende |
|---|---|---|
| Âncoras do PRD | `## 6. Functional Requirements`, `Capabilities`, `Dependency Graph`, `Execution Waves`, `Foundation Features` | `spec-writer`, `implement-feature`, `implement-and-evaluate-tmux` |
| Âncoras do `contract.md` | `## Prerequisites`, `## Quality gates`, `## Coverage Manifest`, `Verification mode:`, `Common given:`, `Used by:` | `implement-feature`, `evaluator`, `fix-runner`, `design-review` |
| Âncoras do eval-report | `## Abort reason`, `**Verdict:**`, `PASS` / `FAIL` / `BLOCKED` / `MANUAL` | `fix-runner` |
| Âncoras do journal | `## Final Verdict`, `**Status:**`, `**Total cycles:**`, `**Pull request:**` | **`team-driver.sh`, via `awk`** |
| Valores de status | `success`, `manual-pending`, `stuck`, `exhausted`, `aborted`, `pr-blocked`, `running`, `done`, `implementing` | **`team-driver.sh` e `dashboard.sh`, via `case` e `grep -E`** |
| Chaves e valores do `prd_progress.json` | `status`, `failure_reason`, `cycles`, `wave`, `dependencies` | todo o pipeline de execução |
| Chaves do JSON que os subagentes devolvem | `status`, `items.failed`, `acs.verified`, `abort_reason` | `implement-and-evaluate` |
| Mensagens de commit | `feat(F03):`, `fix(F03): cycle 2 — address items …`, `chore(F03): record evaluation artifacts` | `implement-feature` detecta fase já commitada pela mensagem |
| Gramática de override | `max 3 retries`, `keep eval env`, `with design review`, `no branch`, `progress-path=` | é o que o usuário digita |
| Nomes de arquivo e marcadores | `eval-report-<ts>.md`, `eval_<fid>_*`, `dsg_<fid>_*` | limpeza de órfãos do `evaluator` e do `design-review` |

> 🔴 Os dois scripts bash são o caso perigoso. Se `## Final Verdict` ou `success`
> virarem português, o `team-driver.sh` e o `dashboard.sh` falham **em silêncio**: a
> equipe termina bem, o dashboard segue mostrando tudo como se ainda estivesse
> rodando, e só o timeout encerra a wave.

**Não carrega peso — escreva em pt-BR:** tudo que só é impresso para uma pessoa ler —
as perguntas interativas (`"Posso prosseguir? (sim/não)"`), os aborts
(`"Nenhum PRD encontrado. Passe o path explicitamente."`), os avisos e as linhas de
`Soft-fails`. Ninguém faz parse dessas strings; elas existem para serem lidas.

O `contract.md` tem a sua própria versão dessa regra — conteúdo em pt-BR, âncoras
estruturais e vocabulário de capability em inglês —, canônica em
`skills/spec-writer/references/contract-template.md`. O `prd_progress.json` fica inteiro
do lado que carrega peso: chaves, nomes de campo e valores de `status` são literais de
schema, definidos em `references/progress-schema.md`.

## Desenvolvimento local

Para testar sem publicar:

```bash
mkdir -p ~/.claude/skills
ln -s "$(pwd)" ~/.claude/skills/ia-package
```

O plugin carrega como `ia-package@skills-dir` na próxima sessão. Para conferir o
que foi de fato descoberto e quanto custa em tokens:

```bash
claude plugin validate .
claude plugin details ia-package@skills-dir
```

> **Atenção à descoberta de componentes.** `agents/` **não** é varrido
> recursivamente: um agente em `agents/adr/x.md` é silenciosamente ignorado.
> Já `skills/` aceita subpastas, mas só se o caminho for declarado no campo
> `skills` do `plugin.json` — é por isso que `./skills/for-interviews/` está
> listado lá. Rode `claude plugin details` depois de mexer na estrutura e confirme
> a contagem de componentes.

## Licença

MIT
