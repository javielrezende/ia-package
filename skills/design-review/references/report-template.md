# Report Template

Estrutura fixa do `design-report-<ISO-timestamp>.md`. A skill grava o arquivo preenchendo este template; **NÃO altere a ordem nem os títulos das seções** — o `fix-runner` (Mode C) faz parsing da seção `## Design fixes` por leitura seccional, e o diff humano entre execuções depende da estabilidade do formato.

Os títulos, labels e o vocabulário de status (`pass`, `pass-with-findings`, `fail`, `blocker`, `major`, `minor`, `✓`, `✗`, `not reachable`, `high`/`medium`/`low`) ficam em inglês, literalmente. O texto livre que preenche os placeholders (raciocínio, observações, mudanças propostas) é pt-BR.

O **resumo no chat** é uma projeção compacta: header, tabela de notas, blockers e os fixes `blocker` / `major`, depois o path do relatório. Todo o resto fica apenas no arquivo.

Placeholders são escritos como `<assim>`. Listas sem entradas colapsam para `*(none)*`.

---

## Template

```markdown
# Design Report — F<ID> <Nome da Feature>

*Gerado pelo design-review. Cada execução produz um novo arquivo com timestamp. Não edite à mão.*

**Run:** `<ISO-timestamp>`
**Branch:** `<git branch>`
**Status:** `pass | pass-with-findings | fail | aborted at step <N>`
**Weighted Score:** `<N.N>` / 10 (threshold `<N.N>`)
**Calibration:** `greenfield | design-system` — `<pista que determinou a calibração>`
**Confidence:** `high | medium | low` — `<motivo, quando não for high>`
**Routes:** `<rota-1>`, `<rota-2>` · **Viewports:** `mobile`, `tablet`, `desktop`
**Screenshots:** `design-screenshots-<ISO-timestamp>/` (`<N>` arquivos)

---

## Scores

| Dimension | Weight | Score | Cap applied | Delta |
|---|---|---|---|---|
| Design Quality | 2x | `<N>` | — | `<+N \| -N \| =>` |
| Originality | 2x | `<N>` | `<slop: max 7 \| —>` | `<...>` |
| Craft | 1x | `<N>` | `<mechanical: max 6 \| —>` | `<...>` |
| Functionality | 1x | `<N>` | — | `<...>` |
| **Weighted** | | **`<N.N>`** | | `<...>` |

*(A coluna Delta é omitida inteira quando não há execução anterior desta feature.)*

---

## Reasoning

### Design Quality — `<N>`

`<Raciocínio em pt-BR, citando screenshots pelo nome do arquivo. Toda nota abaixo de 9 nomeia ao menos 2 deficiências concretas, cada uma com screenshot + elemento.>`

- Deficiência: `<descrição>` — `<screenshot>` — `<seletor ou região>`
- Deficiência: `<descrição>` — `<screenshot>` — `<seletor ou região>`

### Originality — `<N>`

`<Raciocínio. Sob a calibração design-system, avalie fluência no sistema, não novidade. Todo `sim` do checklist de slop aparece aqui.>`

- Deficiência: `<descrição>` — `<screenshot>` — `<seletor ou região>`

### Craft — `<N>`

`<Raciocínio. Se um teto mecânico foi aplicado, diga qual checagem o disparou.>`

### Functionality — `<N>`

`<Raciocínio. Os estados de borda pesam aqui tanto quanto o caminho feliz.>`

---

## Mechanical floor

Checagens determinísticas. `✗` em M1–M6 é blocker de acessibilidade e reprova a execução sozinho.

| # | Check | Result | Evidence |
|---|---|---|---|
| M1 | Text contrast | ✓ / ✗ | `<elemento>` — medido `<N.N>:1`, exigido `<N.N>:1` |
| M2 | Visible focus | ✓ / ✗ | `<elemento>` — `<observação>` |
| M3 | Touch target | ✓ / ✗ | `<elemento>` — `<N>×<N> px` |
| M4 | Accessible label | ✓ / ✗ | `<elemento>` |
| M5 | Text alternative | ✓ / ✗ | `<elemento>` |
| M6 | Horizontal overflow | ✓ / ✗ | `scrollWidth <N>` vs `innerWidth 390` |
| M7 | Type scale | ✓ / ✗ | `<N>` tamanhos distintos: `<lista>` |
| M8 | Spacing system | ✓ / ✗ | `<N>%` dos elementos fora do passo de `<N>px` |
| M9 | Heading hierarchy | ✓ / ✗ | `<observação>` |
| M10 | Reduced motion | ✓ / ✗ | `<observação>` |

**Caps applied:** `<Craft limitado a N por <motivo> | none>`

---

## AI slop checklist

| # | Signal | Present | Evidence |
|---|---|---|---|
| S1 | Purple gradient over white cards | sim / não | `<screenshot ou —>` |
| S2 | Generic hero with stock copy | sim / não | `<...>` |
| S3 | Cookie-cutter card grid | sim / não | `<...>` |
| S4 | Default glassmorphism | sim / não | `<...>` |
| S5 | Over-symmetrical layout | sim / não | `<...>` |
| S6 | Gradient-heavy CTAs | sim / não | `<...>` |
| S7 | Placeholder microcopy | sim / não | `<...>` |
| S8 | Emojis as product icons | sim / não | `<...>` |
| S9 | Mixed icon libraries | sim / não | `<...>` |
| S10 | Uniform default shadow | sim / não | `<...>` |

**Count:** `<N>` sinais presentes → `<teto aplicado a Originality | nenhum teto>`

---

## States captured

| Route | Viewport | default | empty | loading | error | focus | hover |
|---|---|---|---|---|---|---|---|
| `<rota>` | mobile | ✓ | ✓ | not reachable | ✓ | ✗ | ✓ |
| `<rota>` | desktop | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

Legenda: `✓` capturado e íntegro · `✗` capturado e com problema (vira achado) · `not reachable` não atingível sem editar código (baixa a confiança, não a nota).

---

## Design fixes

Uma entrada por deficiência citada em Reasoning ou no piso mecânico. Consumida pelo `fix-runner` Mode C. Ordenada por severidade: todos os `blocker`, depois `major`, depois `minor`.

### DSG-<NN> — <título curto>

**Severity:** blocker | major | minor
**Dimension:** Design Quality | Originality | Craft | Functionality
**Evidence:** `<arquivo-do-screenshot>` — `<seletor ou região>`
**Observed:** `<o que está na tela hoje, com valor medido quando houver>`
**Change:** `<a mudança concreta a fazer, no vocabulário e nos tokens do projeto>`

*(Repita o bloco por fix. `*(none)*` quando a execução não produziu nenhum.)*

---

## Discovery

| Decision | Source |
|---|---|
| Bring-up command | `<arquivo ou pista>` |
| Seed mechanism | `<arquivo ou pista>` |
| Routes | `<contract.md ## UI \| router \| routes= override>` |
| Design system | `<arquivo ou pista, ou "none detected">` |
| Browser driver | `<arquivo ou pista>` |

---

## Overrides applied

- `<texto do override>` → `<efeito>`

*(none)*

## Soft-fails

- `<rótulo curto>` — `<motivo>`

*(none)*

## Abort reason

*(Presente apenas quando o status é `aborted at step <N>`.)*

`<um parágrafo: qual step, o que falhou, o que foi capturado até aqui, o que não rodou>`
```

---

## Notes for the writer

- **Nome dos screenshots:** `<rota-slug>--<viewport>--<estado>.png`, ex.: `videos-upload--mobile--empty.png`. Toda citação no relatório usa esse nome exato — é o que liga a nota à evidência.
- **IDs dos fixes:** `DSG-01`, `DSG-02`, … sequenciais dentro da execução, na ordem de severidade. Não são estáveis entre execuções (o `fix-runner` recebe o path do relatório junto com os IDs, então a ambiguidade não aparece).
- **Ordem das seções é contrato.** O `fix-runner` localiza `## Design fixes` por título literal e lê os blocos `### DSG-` até a próxima seção `##`. Renomear ou reordenar quebra o Mode C silenciosamente.
- **Diffabilidade:** mantenha títulos, colunas e formato de bullet estáveis byte a byte entre execuções, para que o `diff` entre dois relatórios mostre só o que mudou de verdade.
- **Delta:** calculado contra o `design-report-*.md` mais recente da mesma pasta. Quando não existir, omita a coluna inteira em vez de preencher com zeros.
- **Projeção no chat:** as linhas do header, a tabela Scores, os blockers do piso mecânico, os fixes `blocker` e `major` (uma linha cada: ID, severidade, título), e `Report: <path relativo>`. Nada mais.
