# Journal Template

Estrutura fixa do `<feature-folder>/orchestration-<ISO-timestamp>.md`. O orquestrador grava o arquivo preenchendo este template e **o atualiza de forma incremental depois de cada ciclo**, para que um journal parcial seja informativo se a execução for interrompida (Ctrl-C, crash etc.).

O placeholder `<ISO-timestamp>` é o run-id, normalizado para ser seguro em nome de arquivo (ex.: `2026-05-01T17-32-04Z`). Ele é estável byte a byte entre o nome do arquivo, a linha `**Run:**` e qualquer referência à execução dentro do documento.

Os títulos, labels e o vocabulário de status (`success`, `manual-pending`, `stuck`, `exhausted`, `aborted`, `pr-blocked`, os status de cada skill delegada, `PASS`/`FAIL`/`BLOCKED`/`MANUAL`/`SKIPPED`) ficam em inglês, literalmente. O texto livre que preenche os placeholders (motivos, razão de término, soft-fails) é escrito em pt-BR.

Listas sem entradas colapsam para uma única linha em itálico `*(none)*`.

---

## Template

```markdown
# Orchestration Journal — F<ID> <Nome da Feature>

*Gerado pelo `implement-and-evaluate`. Cada execução produz um novo arquivo com timestamp. Não edite à mão.*

**Run:** `<ISO-timestamp>`
**Feature folder:** `<pasta da feature>`
**Branch:** `<branch de trabalho da execução>`
**Started at:** `<ISO-8601 wall clock>`
**Retry budget:** `<N>` (default 3 · `unlimited` · `0` para no-retries)
**Status:** `running | success | manual-pending | stuck | exhausted | aborted | pr-blocked`

**Overrides applied (orchestrator-level):**
- `<override>` — `<efeito>`

*(none)*

**Overrides forwarded to implement-feature (cycle 0 only):**
- `<token>`

*(none)*

**Overrides ignored:**
- `<override>` — `<motivo>`

*(none)*

---

## Cycle Log

Cada ciclo tem uma ou duas linhas: uma linha `implement-feature` (apenas no ciclo 0) ou uma linha `fix-runner` (ciclos ≥ 1), seguida de uma linha `evaluator` que fecha o ciclo. As linhas são acrescentadas conforme acontecem; NÃO reordene.

**Ciclo sem linha de evaluator:** quando o fix-runner devolve `gates-failed`, ele não commita nada e o evaluator não roda — não há código novo para verificar. Esse ciclo fica com uma linha só, a do fix-runner. É o formato correto; não invente uma linha de evaluator para "fechar" o ciclo.

| # | Kind | Status | Counts / Notes | Artifact |
|---|---|---|---|---|
| 0 | implement-feature | `<status>` | phases `<X>/<Y>` committed | — |
| 0 | evaluator | `<status>` | `P=<P> F=<F> B=<B> M=<M> S=<S>` (of `<total>`) · ACs `✓<V> ✗<X> ⊘<U>` | `eval-report-<ts1>.md` |
| 1 | fix-runner | `<status>` | items targeted: `<lista>` · commit `<sha or none>` · `<files-touched-count>` files | — |
| 1 | evaluator | `<status>` | `P=<P> F=<F> B=<B> M=<M> S=<S>` · `Δpass=+<N>/-<N>` `Δfail=+<N>/-<N>` | `eval-report-<ts2>.md` |
| 2 | fix-runner | `<status>` | ... | — |
| 2 | evaluator | `<status>` | ... | `eval-report-<ts3>.md` |
| D1 | design-review | `<status>` | score `<N.N>` · DQ`<N>` O`<N>` C`<N>` F`<N>` · confidence `<high\|medium\|low>` | `design-report-<ts4>.md` |
| D1 | fix-runner | `<status>` | design fixes applied: `<lista>` · skipped: `<lista>` · commit `<sha or none>` | — |
| D2 | design-review | `<status>` | score `<N.N>` (`<+N.N \| -N.N>` vs D1) · ... | `design-report-<ts5>.md` |

Os passes do Step 6.5 são numerados `D1`, `D2`, … em vez de continuarem a numeração de ciclo — eles rodam depois do `clean`, sobre uma feature já verde, e misturá-los com os ciclos de correção de contrato tornaria o log ilegível. As linhas `D*` só aparecem quando o override `with design review` esteve ativo.

**Status vocabulary by kind:**

- `implement-feature`: `success` · `completed-with-regressions` · `incomplete` · `aborted-at-phase-<N>` · `aborted-pre-phase`
- `evaluator`: `clean` · `fail` · `fail-gate-<name>` · `pending` · `aborted-at-step-<N>` · `aborted-at-item-<ID>`
- `fix-runner`: `fixed` · `gates-failed` · `aborted`
- `design-review`: `pass` · `pass-with-findings` · `fail` · `aborted-at-step-<N>`

---

## Cycle Detail

Um bloco por ciclo, em ordem cronológica. Cada bloco carrega os dados que a linha do Cycle Log resumiu, mais os deltas em relação ao ciclo anterior e quaisquer soft-fails retornados.

### Cycle 0 — implement-feature → evaluator

**implement-feature**

- Status: `<status>`
- Phases committed: `<X>/<Y>`
- Abort reason (if any): `<texto ou none>`
- Soft-fails / regressions / deviations: `<lista ou none>`

**evaluator**

- Status: `<status>`
- Eval-report: `<path>`
- Items: `P=<P> F=<F> B=<B> M=<M> S=<S>` of `<total>`
- ACs: `✓<V> verified · ✗<X> failed · ⊘<U> undetermined` of `<total>`
- Failed item IDs: `<lista ou none>`
- Blocked item IDs: `<lista ou none>`
- Manual item IDs: `<lista ou none>`
- Abort reason (if any): `<texto ou none>`
- Defensive insight (if triggered): `<linha literal>`

### Cycle 1 — fix-runner → evaluator

**fix-runner**

- Status: `<status>`
- Items targeted: `<IDs passados, separados por vírgula>`
- Commit: `<sha ou none>` — `fix(F<ID>): cycle 1 — address items …`
- Files touched: `<lista>`
- Soft-fails: `<lista ou none>`
- Abort reason (if any): `<texto ou none>`
- Evaluator this cycle: `ran` · `skipped (gates-failed — no commit to verify; circuit-breaker not applied)`

**evaluator**

- Status: `<status>`
- Eval-report: `<path>`
- Items: `P=<P> F=<F> B=<B> M=<M> S=<S>`
- Deltas vs. cycle 0:
  - `flipped to PASS:` `<IDs que não eram PASS no ciclo 0 e agora são PASS>`
  - `flipped from PASS:` `<IDs que eram PASS no ciclo 0 e agora não são (regressões)>`
  - `still failing:` `<IDs FAIL/BLOCKED nos dois ciclos>`
  - `new failures:` `<IDs FAIL/BLOCKED agora que não estavam no ciclo 0>`
- Circuit-breaker status: `not tripped` · `tripped (same failed_set, zero passed delta)`
- Soft-fails: `<lista ou none>`

### Cycle 2 — fix-runner → evaluator

*(Mesmo formato do Cycle 1.)*

---

## Final Verdict

**Status:** `success | manual-pending | stuck | exhausted | aborted | pr-blocked`

**Completed at:** `<ISO-8601 wall clock>`

**Total cycles:** `<N>` (1 implement-feature + `<N-1>` fix-runner)

**Total commits across cycles:** `<N>` (`<X>` das fases do implement-feature + `<F>` commits de fix)

**All eval-reports produced:**

1. `<path-do-eval-report-do-ciclo-0>.md`
2. `<path-do-eval-report-do-ciclo-1>.md`
3. ...

**Items still failing or blocked at end of run:**

- `<ID>` — `<superfície>` — `<motivo de uma linha tirado do eval-report mais recente>`

*(none)*

**Items still MANUAL at end of run:**

- `<ID>` — `<superfície>` — subjective

*(none)*

**Design review** *(apenas quando o Step 6.5 rodou):*

- **Final status:** `<status>` — score `<N.N>`/10 after `<N>` pass(es)
- **Reports:** `design-report-<ts>.md`, …
- **Fixes outstanding:** `<DSG-NN> (<severity>) — <título>` · *(none)*
- **Stop reason:** `pass alcançado | pass-with-findings (não dispara correção) | budget consumido | gates-failed no design pass | regressão de score | sem superfície de UI | abort do design-review`

*(A reprovação do design NUNCA altera o Status acima — o veredito da feature é do evaluator.)*

**Pull request:**

- `push e abertura do PR acontecem depois do commit que inclui este journal; resultado e URL no chat report` *(status `success`, fluxo de PR em andamento — Step 7.6)*
- `PR not opened: <motivo>` *(todos os outros casos)*

**Termination reason (one paragraph):**

`<por que a execução terminou: evaluator clean | apenas itens MANUAL | circuit-breaker disparou | retry budget consumido | conflito de merge não resolvido | motivo do abort>`

---

## Soft-fails (run-level)

- `<rótulo curto>` — `<motivo>`

*(none)*

---

## keep eval env (when honored)

*(Presente apenas quando o usuário passou `keep eval env` E a execução não terminou em `success`. Lista os detalhes de conexão da re-execução pós-finalização do evaluator, mais o comando explícito de limpeza.)*

- DB URL: `<postgres://...>`
- Service URLs: `<lista>`
- Tmpdir: `<path>`
- Cleanup: `<comando de shell de uma linha que o usuário pode rodar depois para remover o DB e o tmpdir>`
```

---

## Notes for the writer

- **Linha `**Branch:**`**: é a branch de *trabalho* da execução — a que o Step 2.5 do orquestrador deixou em checkout, não a branch de onde a execução foi invocada. Quando o Step 2.5 cria `feat/F03-video-upload` a partir da `main`, o journal registra `feat/F03-video-upload`. O header é gravado no Step 3, **depois** do Step 2.5, justamente para que essa linha nunca guarde a branch errada.
- **Formato do run-id**: ISO 8601 normalizado para forma segura em nome de arquivo, ex.: `2026-05-01T17-32-04Z`. A mesma string aparece no nome do arquivo, na linha `**Run:**` e em toda referência a esta execução. O orquestrador nunca reutiliza um run-id.
- **Escritas incrementais**: grave o header no Step 3 (inicialização). Depois de cada ciclo, acrescente a nova linha na tabela **Cycle Log** e um novo bloco em **Cycle Detail**. O **Final Verdict** e os **Soft-fails** de nível de execução são preenchidos no Step 7.6 quando o status é `success` e o fluxo de PR chega até lá (antes do último commit de artefatos e do push); em todos os outros caminhos, no Step 8. A seção **keep eval env** é preenchida no Step 8, quando aplicável.
- **Cálculo dos deltas**: os deltas do bloco **Cycle Detail** são calculados contra a saída do evaluator do ciclo **anterior** (conjuntos de IDs de itens), não contra o ciclo 0, a menos que o anterior seja o ciclo 0. Os grupos "still failing" e "new failures" juntos precisam ser iguais ao `failed_set ∪ blocked_set` do ciclo atual.
- **Linha do circuit-breaker**: aparece em todo bloco de evaluator a partir do ciclo 1. Sempre preencha; a árvore de decisão do orquestrador depende desse sinal. Num ciclo `gates-failed` não há bloco de evaluator e, portanto, não há linha de circuit-breaker — quem registra que o breaker não foi consultado é a linha `Evaluator this cycle` do bloco do fix-runner. Ler o journal e não achar a linha do breaker num ciclo é sinal esperado, não omissão.
- **Estabilidade do vocabulário de status**: mantenha as strings de status em kebab-case estáveis byte a byte entre execuções — a comparação por `diff` entre dois journals (ou entre um journal e o chat report) depende disso.
- **Listas de IDs de itens** nos sub-bullets de delta são ordenadas lexicograficamente dentro de cada grupo, para que diffs entre execuções destaquem apenas mudanças reais de pertencimento.
- **Sem reordenação**: as linhas do **Cycle Log** são acrescentadas em ordem cronológica. Nunca reordene por status, contagem ou qualquer outra chave.
- **Sem evidência bruta**: a evidência (bodies HTTP, resultados de consultas ao DB, trechos do DOM) fica no `eval-report-<ts>.md` de cada ciclo. O journal referencia esses relatórios pelo path; não os duplica.
- **Diffabilidade entre execuções**: quando uma feature exige várias invocações de `implement-and-evaluate` ao longo de dias/sessões, dois journals de execuções diferentes devem gerar um `diff` limpo ao longo dos títulos de seção, da ordem das colunas das tabelas e do formato dos bullets.
- **Execuções abortadas**: se o Status for `aborted`, o bloco **Final Verdict** ainda é renderizado, com **Total cycles** igual ao número de ciclos que de fato rodaram e **Items still failing or blocked at end of run** preenchido a partir da última saída do evaluator (ou vazio se o abort aconteceu antes de qualquer evaluator rodar). O **Termination reason** é a mensagem de abort.
