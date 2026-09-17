# Report Template

Estrutura fixa do `eval-report-<ISO-timestamp>.md`. A skill grava o arquivo preenchendo este template; NÃO altere a ordem nem os títulos das seções — o parsing de `only failed-last-run` e os diffs humanos entre execuções dependem da estabilidade do formato.

Os títulos, labels e o vocabulário de status (`PASS`, `FAIL`, `BLOCKED`, `MANUAL`, `SKIPPED`, `✓ verified`, `✗ failed`, `⊘ undetermined`, os valores de `**Status:**` e os motivos `run aborted at …`) ficam em inglês, literalmente. O texto livre que preenche os placeholders (causas raiz, interpretações, motivos, parágrafo de abort) é escrito em pt-BR. O texto dos bullets e dos ACs é copiado do contrato como está.

O **resumo no chat** é uma projeção compacta deste mesmo template: header (linha de status, agregados de itens / ACs, insight defensivo quando disparado), depois apenas os ACs FAIL / `⊘`, depois apenas os itens FAIL / BLOCKED em blocos curtos próprios, depois o path do relatório em arquivo. Todo o resto do template (Discovery, Pre-run cleanup, Pre-flight completo, Coverage Manifest completo, itens PASS, Evidence, Overrides, Soft-fails) fica apenas no arquivo.

Placeholders são escritos como `<assim>`. Listas sem entradas colapsam para uma única linha em itálico `*(none)*` em vez de uma seção vazia.

---

## Template

```markdown
# Eval Report — F<ID> <Nome da Feature>

*Gerado pelo evaluator. Cada execução produz um novo arquivo com timestamp. Não edite à mão.*

**Run:** `<ISO-timestamp>`
**Branch:** `<git branch>`
**Status:** `clean | fail | fail (gate <name>) | pending | aborted at step <N> | aborted at item <ID>: <reason>`
**Items:** `<P>` PASS · `<F>` FAIL · `<B>` BLOCKED · `<M>` MANUAL · `<S>` SKIPPED (out of `<total>`)
**ACs:** `<V>` ✓ verified · `<X>` ✗ failed · `<U>` ⊘ undetermined (out of `<total>`)

> Note: <N>% of items fail with `<pattern>`; implementation may not be in place.

*(A linha de nota acima aparece apenas quando o limite do insight defensivo é atingido. Omita caso contrário.)*

---

## Discovery

Rastro, camada por camada, de qual fonte respondeu cada decisão de ambiente. Auditável.

| Decision | Layer | Source |
|---|---|---|
| Bring-up command | <1-7> | `<arquivo ou pista>` |
| Migration command | <1-7> | `<arquivo ou pista>` |
| Seed mechanism | <1-7> | `<arquivo ou pista>` |
| Reset between items | <1-7> | `<arquivo ou pista>` |
| HTTP driver | <1-7> | `<arquivo ou pista>` |
| UI driver | <1-7> | `<arquivo ou pista>` |
| Service driver (when used) | <1-7> | `<arquivo ou pista>` |
| ... | ... | ... |

Layer key: 1 = contract Prerequisites, 2 = project docs (CLAUDE.md / harness / README), 3 = spec.md Seção 4 (Technical Decisions & Assumptions), 4 = sibling contracts, 5 = stack inspection, 6 = stack defaults, 7 = abort.

---

## Pre-run cleanup

- Removed orphan DB: `<name>` (created `<earlier-timestamp>`)
- Removed orphan tmpdir: `<path>` (created `<earlier-timestamp>`)
- Killed orphan processes: PIDs `<list>`

*(none)*

---

## Quality gates

Resultado por gate, na ordem do documento, a partir da seção `## Quality gates` do contrato. A execução para no primeiro exit não-zero; as entradas abaixo da que falhou são renderizadas como `— not run`.

- ✓ `<gate name>` — exit `0` — `<command>`
- ✗ `<gate name>` — exit `<N>` — `<command>` — `<resumo de uma linha do stderr>`
- — `<gate name>` — not run (run aborted earlier)

*(none — contract has no `## Quality gates` section)*

---

## Pre-flight (Prerequisites)

### Runtime services
- ✓ `<service>` — reachable at `<url>`, health `<endpoint>` returned `<status>`
- ✗ `<service>` — `<motivo>`

### Persistent state
- ✓ `<handle>` — seeded via `<mecanismo>`; verified attributes: `<lista>`
- ✗ `<handle>` — `<motivo>`

### Static inputs
- ✓ `<path>` — `<intrinsic-tool>`: `<resultado>`
- ✗ `<path>` — `<motivo>`

### Configuration
- ✓ `<key>` — set to `<value>` (compatible with contract: `<expectativa>`)
- ✗ `<key>` — `<motivo>`

### External dependencies
- ✓ `<tool>` — version `<version>`, on PATH at `<location>`
- ✗ `<tool>` — `<motivo>`

*(Subseções sem entradas declaradas no contrato são omitidas.)*

---

## Coverage Manifest

| AC (verbatim from PRD) | Mark | Items |
|---|---|---|
| `<texto do AC>` | ✓ verified | `<ID-1>`, `<ID-2>` |
| `<texto do AC>` | ✗ failed | `<ID-3>` (FAIL: `<motivo de uma linha>`) |
| `<texto do AC>` | ⊘ undetermined | `<ID-4>` (MANUAL), `<ID-5>` (BLOCKED: `<motivo>`) |

---

## Items

Agrupados por superfície, em ordem de pirâmide. Dentro de cada superfície, na ordem do documento. Superfícies sem itens são omitidas.

### Service

#### `<ID>` — `<título>` `*`

O `*` final aparece no heading quando ao menos um bullet foi interpretado por LLM (fora da gramática reconhecida). O mesmo caractere de marcação é usado por bullet dentro do item — heading e bullet ficam consistentes.

**Verdict:** PASS | FAIL | BLOCKED | MANUAL | SKIPPED

**Bullets:**
- ✓ `<texto do bullet>` | expected `<E>` · observed `<O>`
- ✗ `<texto do bullet>` | expected `<E>` · observed `<O>`
  → root cause: `<narrativa de uma linha ancorada em evidência>`
- `*` `<texto do bullet>` | interpreted as: `<descrição em linguagem simples da checagem inferida>` · observed `<O>` · PASS | FAIL

**Evidence**

<details>
<summary>Show raw evidence</summary>

```
<bodies de request / response recortados ao que importa>
<consultas ao DB com resultados>
<checagens de filesystem>
<log de rede>
<trecho do DOM>
```

</details>

*(Repita o bloco de item para cada item da superfície.)*

### HTTP API

*(Mesmo formato por item.)*

### CLI

### Worker

### Event

### UI

### E2E

### Manual

---

## Overrides applied

- `<texto do override>` → `<efeito>`

*(none)*

## Overrides ignored

- `<texto do override>` — `<motivo>`

*(none)*

## Soft-fails / out-of-band

- `<rótulo curto>` — `<motivo>`

*(none)*

## Abort reason

*(Presente apenas quando o status é `aborted` ou `fail (gate <name>)`.)*

`<um parágrafo: qual step, o que falhou, o que foi feito até aqui, o que não rodou>`

Para aborts `fail (gate <name>)`, inclua o comando do gate que falhou, o exit code e as primeiras 30–50 linhas do stderr (recolhidas em `<details>` quando longas).
```

---

## Notes for the writer

- **Formato do run-id**: ISO 8601 normalizado para forma segura em nome de arquivo, ex.: `2026-04-28T17-32-04Z`. A mesma string aparece no nome do arquivo, na linha `**Run:**`, no nome do DB efêmero (`eval_<feature-id>_<run-id>`) e no tmpdir (`evaluator-<feature-id>-<run-id>`). `<feature-id>` segue a definição de marcador fixada no Step 3 do SKILL.md (prefixo `F<N>` em minúsculas).
- **Ordem dos itens dentro de uma superfície**: a ordem do documento no `contract.md`. Não reordene por veredito.
- **Evidence recolhida**: sempre envolva a evidência bruta em `<details>` para que o relatório seja legível pelo header. Recorte os bodies às partes que importam para os bullets verificados — dumps completos de request / response só adicionam ruído.
- **Limite do insight defensivo**: ≥ 80 % dos itens *executados* (sem contar BLOCKED, MANUAL, SKIPPED) falhando com o mesmo padrão de causa raiz. Calcule apenas sobre os itens efetivamente executados.
- **Diffabilidade entre execuções**: um `diff` entre dois relatórios com timestamp deve destacar apenas o que de fato mudou. Mantenha títulos de seção, ordem das colunas das tabelas e formato dos bullets estáveis byte a byte entre execuções.
- **Projeção do resumo no chat**: as linhas do header literalmente, depois uma seção `## Failures` listando cada AC `✗` e cada AC `⊘` (uma linha: AC literal, marca, IDs dos itens com motivo curto) e cada item FAIL / BLOCKED (uma linha: ID, título, causa raiz de uma linha), depois `Report: <path relativo>`. Nada mais.
