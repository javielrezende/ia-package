# ia-package

Plugin do Claude Code com um pipeline de documentação técnica assistida por IA:
entrevistas guiadas que produzem **PRD → HLD → FDD → spec/plan → implementação →
ADRs → diagramas C4/Mermaid**.

Os documentos são gerados em português (pt-BR).

## Instalação

```bash
# 1. registre o repositório como marketplace
/plugin marketplace add javielrezende/ia-package

# 2. instale
/plugin install ia-package@ia-package
```

Depois de instalar, copie o `templates/CLAUDE.example.md` para a raiz do seu projeto como
`CLAUDE.md` e preencha a stack e os caminhos — é isso que faz as skills gerarem
documentos aderentes ao projeto em vez de genéricos.

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
| `prd-writer-for-complete-project` | PRD do produto inteiro, só de negócio: 12 seções + `Appendix A` de planejamento |
| `spec-writer` | `spec.md` + `plan.md` por feature (tem batch mode por wave) |
| `implement-feature` | Implementa a feature fase a fase, um commit por fase |
| `generate-development-guideline` | Diretriz de desenvolvimento por linguagem/stack |

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
| `SessionStart` | `pipeline-status.sh` | Diz ao Claude, já na abertura da sessão, quais artefatos do pipeline já existem e qual é o próximo passo |
| `PostToolUse` (Write\|Edit) | `flag-open-gaps.sh` | Aponta ao Claude `[NEEDS INPUT]`, `TBD` e `<preencher>` deixados em documentos de `docs/` |
| `SubagentStop` | hook do tipo `prompt` | Confere, pela mensagem final, se os agentes geradores relataram os artefatos que prometeram |

Os dois primeiros são hooks de comando (bash + python3, sem dependências externas);
o terceiro é um hook `prompt`, avaliado por um modelo. Exigem apenas `bash` e `python3`
no PATH — se `python3` faltar, os scripts saem em silêncio em vez de quebrar a sessão.

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
