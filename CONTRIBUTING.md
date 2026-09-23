# Contribuindo com o ia-package

Este arquivo é para quem **edita o plugin**. Quem só usa o pipeline não precisa dele —
o [`README.md`](README.md) cobre instalação, fluxo, overrides e artefatos.

## Estrutura do repositório

```
.claude-plugin/     plugin.json e marketplace.json
skills/<nome>/      SKILL.md + references/ + scripts/ de cada skill
hooks/              hooks.json e os scripts de SessionStart e PostToolUse
references/         fontes canônicas compartilhadas entre skills
templates/          CLAUDE.example.md e settings.example.json, copiados para o projeto do usuário
```

### Fontes canônicas

Três arquivos são canônicos e **as skills apontam para eles em vez de duplicar o
conteúdo**. Mudou o comportamento? Mude aqui, não dentro de uma skill:

| Arquivo | Define |
|---|---|
| `references/progress-schema.md` | O schema do `prd_progress.json`: chaves, valores de `status`, semântica dos campos e invariantes. Cada skill documenta apenas as próprias escritas |
| `references/forge.md` | As seis operações de forge, o comando de cada plataforma, os nomes de campo que divergem e os literais de schema que não mudam |
| `skills/spec-writer/references/contract-template.md` | O formato do `contract.md` — incluindo quais âncoras dele são estruturais |

## Regra de idioma

Os documentos gerados são pt-BR, e as mensagens que o pipeline escreve no chat também.
O que **não** é traduzido é o inglês que carrega peso: o texto que outra skill, um
script ou um parser vai procurar. Essa fronteira é a regra — quem editar o plugin
precisa saber de que lado cada string está antes de mexer nela.

### Carrega peso — não traduza

| Categoria | Exemplos | Quem depende |
|---|---|---|
| Âncoras do PRD | `## 6. Functional Requirements`, `Capabilities`, `Dependency Graph`, `Execution Waves`, `Foundation Features` | `spec-writer`, `implement-feature`, `implement-and-evaluate-tmux` |
| Âncoras do `contract.md` | `## Prerequisites`, `## Quality gates`, `## Coverage Manifest`, `Verification mode:`, `Common given:`, `Used by:` | `implement-feature`, `evaluator`, `fix-runner`, `design-review` |
| Âncoras do eval-report | `## Abort reason`, `**Verdict:**`, `PASS` / `FAIL` / `BLOCKED` / `MANUAL` | `fix-runner` |
| Âncoras do journal | `## Final Verdict`, `**Status:**`, `**Total cycles:**`; `## Cycle Log` | **`team-driver.sh` (as três primeiras) e `dashboard.sh` (`## Cycle Log`), via `awk`** |
| Valores de status | `success`, `manual-pending`, `stuck`, `exhausted`, `aborted`, `pr-blocked`, `running`, `done`, `implementing` | **`team-driver.sh` e `dashboard.sh`, via `case` e `grep -E`** |
| Chaves e valores do `prd_progress.json` | `status`, `failure_reason`, `cycles`, `wave`, `dependencies` | todo o pipeline de execução |
| Chaves do JSON que os subagentes devolvem | `status`, `items.failed`, `acs.verified`, `abort_reason` | `implement-and-evaluate` |
| Mensagens de commit | `feat(F03):`, `fix(F03): cycle 2 — address items …`, `chore(F03): record evaluation artifacts` | `implement-feature` detecta fase já commitada pela mensagem |
| Gramática de override | `max 3 retries`, `keep eval env`, `with design review`, `no branch`, `progress-path=` | é o que o usuário digita |
| Nomes de arquivo e marcadores | `eval-report-<ts>.md`, `eval_<fid>_*`, `dsg_<fid>_*` (DBs **e** nomes de projeto compose), `ports.env` | limpeza de órfãos e isolamento de ambiente do `evaluator` e do `design-review` |

> 🔴 Os dois scripts bash são o caso perigoso. Se `## Final Verdict` ou `success`
> virarem português, o `team-driver.sh` e o `dashboard.sh` falham **em silêncio**: a
> equipe termina bem, o dashboard segue mostrando tudo como se ainda estivesse
> rodando, e só o timeout encerra a wave.

### Não carrega peso — escreva em pt-BR

Tudo que só é impresso para uma pessoa ler — as perguntas interativas
(`"Posso prosseguir? (sim/não)"`), os aborts (`"Nenhum PRD encontrado. Passe o path
explicitamente."`), os avisos e as linhas de `Soft-fails`. Ninguém faz parse dessas
strings; elas existem para serem lidas.

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

> **Atenção à descoberta de componentes.** `skills/` na raiz é varrido por default,
> mas subpasta agrupadora (`skills/<grupo>/<skill>/SKILL.md`) só é descoberta se o
> caminho estiver declarado no campo `skills` do `plugin.json` — sem a linha, a skill
> some em silêncio, sem erro nenhum. Rode `claude plugin details` depois de mexer na
> estrutura e confirme a contagem de componentes.

## Ao editar uma skill

- **Mudou um artefato que outra skill lê?** Atualize a fonte canônica e confira quem
  aponta para ela (`grep -rn "progress-schema\|forge.md" skills/`).
- **Mudou um status terminal ou uma âncora de journal?** Ajuste `team-driver.sh` e
  `dashboard.sh` no mesmo commit — eles fazem match por `awk`, `case` e `grep -E`.
- **Mudou a gramática de override?** Ela aparece em três lugares: a tabela `INPUT` da
  skill, a seção **Overrides** do README e, para o `implement-and-evaluate`, a lista
  de repasse do `implement-and-evaluate-tmux` (Family 3).
- **Adicionou uma skill?** Confirme a descoberta com `claude plugin details` e
  acrescente a linha na tabela de skills do README.
- **Mexeu no bring-up de ambiente** (`evaluator` Step 4, `design-review` Step 3)?
  Todo recurso nomeável carrega `<marcador>_<feature-id>_<run-id>` e toda porta é
  alocada livre por execução — é o que permite a wave rodar em paralelo sem colher
  veredito da feature errada. Cleanup e tear-down precisam usar o mesmo marcador,
  byte a byte.
