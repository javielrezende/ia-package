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

| Skill | Produz |
|---|---|
| `generate-prd-for-feature` | PRD de **uma** feature |
| `generate-high-level-design` | HLD: arquitetura, componentes, fluxos, modelo de dados |
| `generate-feature-design-doc` | FDD: contratos públicos, matriz de erros, observabilidade |
| `generate-deep-research-part-1` | Briefing de pesquisa (até 6 perguntas) |
| `generate-deep-research-part-2` | Formata o resultado da pesquisa em 16 seções |

**Execução:**

| Skill | Produz |
|---|---|
| `prd-writer-for-complete-project` | PRD do produto inteiro, só de negócio: 12 seções + `Appendix A` de planejamento, mais o `prd_progress.json` que o resto do pipeline usa como registro de estado |
| `spec-writer` | `spec.md` + `plan.md` + `contract.md` por feature (tem batch mode por wave) |
| `implement-feature` | Implementa a feature fase a fase, um commit por fase, guiada pelo contrato |
| `evaluator` | Exercita cada item do `contract.md` ponta a ponta num ambiente efêmero e grava o veredito em `eval-report-<ts>.md` |
| `design-review` | Avalia a qualidade visual da UI de uma feature: captura screenshots em 3 viewports e nos estados de borda, roda um piso mecânico de acessibilidade e grava notas por dimensão mais uma lista de correções em `design-report-<ts>.md` |
| `fix-runner` | Passada corretiva sobre os itens reprovados de um eval-report, sobre os achados de um design-report, ou resolução de conflitos de merge |
| `generate-development-guideline` | Diretriz de desenvolvimento por linguagem/stack |

**Orquestração** — encadeiam as skills acima em loop, sem intervenção entre os ciclos:

| Skill | Faz |
|---|---|
| `implement-and-evaluate` | Uma feature: implementa → avalia → corrige → reavalia até o contrato ser honrado, o retry budget acabar ou o circuit-breaker disparar. Com `with design review`, roda também um loop de design antes do PR. No sucesso, commita os artefatos de avaliação, integra a branch padrão, faz push e abre o PR |
| `implement-and-evaluate-tmux` | Uma wave inteira em paralelo: um worktree git e uma janela tmux por feature, cada uma rodando `implement-and-evaluate` por conta própria. A sessão Main só despacha, espera e consolida |

O `contract.md` é a peça que sustenta o loop: itens Given/When/Then por superfície
(API, UI, E2E…), uma seção `Prerequisites` e um `Coverage Manifest` que liga cada
critério de aceite do PRD aos itens que o cobrem. Quem implementa usa como checklist;
o `evaluator` usa como asserção.

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
