# `prd_progress.json` — schema do arquivo de progresso

Fonte canônica do arquivo de progresso que atravessa o pipeline inteiro. O
`prd-writer-for-complete-project` cria e faz o merge do arquivo na FASE 5; a
`implement-feature`, o `evaluator`, o `fix-runner`, a `implement-and-evaluate` e
a `implement-and-evaluate-tmux` leem e escrevem nele durante suas execuções.
Cada uma dessas skills documenta **apenas as próprias escritas** na sua seção
`PROGRESS TRACKING` e aponta para cá para o schema.

Referência a partir de uma skill: `${CLAUDE_PLUGIN_ROOT}/references/progress-schema.md`.

As chaves, os valores de `status` e os nomes de campo são **literais de schema**:
ficam em inglês, exatamente como escritos aqui. Só o `name` de cada feature é
texto livre, copiado do PRD como está. Traduzir qualquer um dos outros valores
quebra em silêncio o `team-driver.sh` e o `dashboard.sh`, que fazem match por
`case` e `grep -E` sobre eles.

---

O arquivo de progresso (`prd_progress.json`) é um registro determinístico, legível por máquina, da situação de implementação de cada feature. O `prd-writer-for-complete-project` cria o arquivo e faz o merge (FASE 5); as skills seguintes do pipeline (`implement-feature`, `evaluator`, `fix-runner`, `implement-and-evaluate`, `implement-and-evaluate-tmux`) leem e gravam nele durante suas próprias execuções.

**Estrutura de primeiro nível:**

```json
{
  "schema_version": 1,
  "prd_path": "<caminho do PRD>",
  "generated_at": "<timestamp RFC 3339 UTC, definido só na primeira criação>",
  "features": {
    "F01": { ... },
    "F02": { ... }
  }
}
```

**Estrutura por feature:**

```json
{
  "name": "Acesso e Identificação",
  "priority": 1,
  "wave": 1,
  "dependencies": [],
  "status": "pending",
  "cycles": 0,
  "failure_reason": null,
  "report_path": null,
  "started_at": null,
  "updated_at": "2026-05-02T14:30:00Z",
  "completed_at": null
}
```

**Semântica dos campos:**

- `name` / `priority` / `dependencies` — copiados da tabela A.2 `Dependency Graph` do Anexo A; `wave` — copiado de A.4 `Execution Waves`. Atualizados a cada regeneração do PRD.
- `status` — um de:
  - `pending` (terminal) — não iniciada
  - `implementing` (transitório) — `implement-feature` está em execução. Definido no início do Passo 5 da `implement-feature`; substituído por `implemented` quando ela termina com sucesso (ou por `fail` em caso de aborto). Raramente aparece num JSON parado — só persiste enquanto a `implement-feature` roda.
  - `implemented` (checkpoint terminal) — `implement-feature` concluiu seu trabalho; a feature está no loop implementar → avaliar → corrigir, aguardando o veredito terminal do `evaluator`. Persiste entre invocações de skills.
  - `done` (terminal) — o `evaluator` aprovou; o contrato foi cumprido
  - `fail` (terminal) — o `evaluator` reprovou de forma terminal OU a `implement-feature` abortou sem recuperação OU o orquestrador esgotou o orçamento de tentativas / acionou o circuit breaker
  - `pr-blocked` (terminal) — a feature foi implementada e validada com sucesso (avaliação limpa), mas o orquestrador não conseguiu abrir o pull request porque o merge da branch padrão do projeto na branch da feature gerou conflitos que o `fix-runner` não resolveu automaticamente. É diferente de `fail` porque a implementação em si está correta — só a integração com a main está bloqueada. A resolução é humana: fazer rebase/merge manual, push, e então reinvocar ou abrir o PR à mão.
  - `removed` (terminal) — a feature existia numa revisão anterior do PRD, mas não está mais no PRD atual
- `cycles` — quantidade acumulada de execuções do `fix-runner` sobre a feature, incrementada pelo próprio `fix-runner`. É informativo: a `implement-and-evaluate` aplica o orçamento de tentativas com um contador próprio de cada execução, não com este campo.
- `failure_reason` — obrigatório quando `status: "fail"` ou `status: "pr-blocked"`. Texto curto (menos de 200 caracteres) com a causa da falha (ex.: `"3 contract item(s) failed; first: API-UPLOAD-03 — endpoint returned 500"`, `"cycle budget exhausted (5 cycles); last eval: ..."`, `"unresolvable merge conflict in apps/web/lib/session.ts, apps/backend/src/main.ts"`). Pode permanecer em `status: "removed"` como registro forense da falha anterior. `null` para os demais status (`pending`, `implementing`, `implemented`, `done`).
- `report_path` — ponteiro opcional para o `eval-report-<ts>.md` mais recente da feature. Pode ser definido em `done` (última avaliação aprovada), `fail` (última avaliação reprovada) ou `implemented` (última avaliação `pending` — sem item reprovado, mas com itens bloqueados, manuais ou filtrados; o `evaluator` não muda o status) e persiste em `removed` como registro forense. `null` quando nenhuma avaliação rodou.
- `started_at` — timestamp RFC 3339 UTC do momento em que o status saiu de `pending` pela primeira vez. `null` até lá. Volta a `null` apenas quando uma feature `removed` é ressuscitada numa nova revisão do PRD (começa um novo ciclo de vida).
- `updated_at` — timestamp RFC 3339 UTC da última escrita nesta entrada. Sempre preenchido.
- `completed_at` — timestamp RFC 3339 UTC definido quando o status passa a `done`. `null` nos demais casos.

**Invariantes:**

- Todo feature ID presente na Seção 6 do PRD DEVE existir como chave em `features`. O inverso não é exigido (entradas `removed` persistem além do PRD atual).
- `cycles >= 0`.
- Todo ID em `dependencies` deve existir como chave em `features` (atual ou `removed`).
- Todos os timestamps são UTC, RFC 3339 (`2026-05-02T14:30:00Z`).
