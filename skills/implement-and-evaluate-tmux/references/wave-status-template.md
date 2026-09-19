# Wave Status Template

Formato fixado de **dois artefatos** produzidos pelo `implement-and-evaluate-tmux` no finalize:

1. `<wave-dir>/wave-status.md` — artefato persistido, irmão de `wave.meta` e de `status/`. Sobrevive à sessão tmux ser derrubada.
2. O **relatório no chat** que a sessão Main emite ao final do Step 7. Mesma estrutura, um pouco mais enxuta.

Os dois seguem a mesma forma: resumo compacto em cima, depois uma seção de detalhe por equipe que falhou. Equipes bem-sucedidas colapsam para uma linha cada (a URL do PR é o único dado que o leitor precisa).

Os títulos, labels e o vocabulário de status (`all-success`, `partial-success`, `all-failed`, `aborted`, `success`, `manual-pending`, `stuck`, `exhausted`, `aborted`, `pr-blocked`, `timeout`) ficam em inglês, literalmente. O texto livre que preenche os placeholders (motivos, soft-fails) é escrito em pt-BR.

Listas sem entradas colapsam para uma única linha em itálico `*(none)*`.

---

## Template do `wave-status.md`

```markdown
# Wave Status — `<wave-tag>` (run `<run-id>`)

**Status:** `all-success | partial-success | all-failed | aborted`
**Started:** `<ISO-8601>`
**Finished:** `<ISO-8601>` (`<HhMM>` decorrido)
**Tmux session:** `iaet-<wave-tag>-<run-id>` — attach: `tmux attach -t iaet-<wave-tag>-<run-id>`
**Selected features:** `F0X, F0Y, F0Z` (`<N>` no total)
**Foundation (serializadas):** `F01, F02` *(omita a linha quando não houve nenhuma)*
**max-parallel:** `<N>` · **team-timeout:** `<Nm>` · **permission-mode:** `<modo>`

---

## Teams

| ID | Slug | Status | Cycles | Elapsed | PR | Journal |
|---|---|---|---|---|---|---|
| F03 | video-upload | ✓ success | 2 | 16m | #142 https://github.com/.../pull/142 | docs/F03-video-upload/orchestration-<ts>.md |
| F05 | transcription | ✗ stuck | 4 | 18m | — | docs/F05-transcription/orchestration-<ts>.md |
| F07 | admin-panel | ✓ success | 1 | 12m | #143 https://github.com/.../pull/143 | docs/F07-admin-panel/orchestration-<ts>.md |

**PRs opened:** `<M>` de `<N>`

---

## Worktrees preservadas

*(Seção omitida inteira quando toda equipe teve sucesso e não houve `keep worktrees`.)*

- `.claude/worktrees/F05-transcription/` — limpeza: `git worktree remove --force .claude/worktrees/F05-transcription`

---

## Failure detail

*(Um bloco por equipe com status diferente de `success`. Equipes `success` já estão cobertas pela tabela; não ganham expansão.)*

### F05 transcription — stuck

- **Reason:** circuit breaker disparou no ciclo 4 (mesmo conjunto FAIL, zero delta de PASS)
- **Items still failing:** `API-TRANSCRIBE-CONCURRENT-01`, `EVENT-TRANSCRIPTION-PARTIAL-02`
- **Latest eval-report:** `docs/F05-transcription/eval-report-<ts>.md`
- **Worktree:** `.claude/worktrees/F05-transcription/`
- **Re-run:** `cd .claude/worktrees/F05-transcription && claude "/ia-package:implement-and-evaluate F05"` (retoma do estado atual da branch)

---

## Soft-fails (nível de wave)

- *(none)*

---

## Overrides applied

- `max-parallel=3` (default)
- `team-timeout=90m` (default)
- `permission-mode=auto` (default)
- *(repassados a cada equipe:)* *(none)*

## Overrides ignored

- *(none)*
```

---

## Template do relatório no chat

Emitido ao final do Step 7. A sessão Main imprime isto no chat. Um pouco mais compacto que o arquivo persistido (pula as seções vazias).

```
implement-and-evaluate-tmux — Wave <wave-tag> (<N> equipes)

Wave status: <all-success | partial-success | all-failed>
Started:  <ISO-8601>
Finished: <ISO-8601> (<HhMM> decorrido)
Tmux session: iaet-<wave-tag>-<run-id>  (ainda viva — `tmux attach -t iaet-<wave-tag>-<run-id>`)

Foundation serializadas: F01, F02        (omita a linha quando não houve nenhuma)

Teams:
  ✓ F03 video-upload      success     cycles 2  PR #142  https://github.com/.../pull/142
  ✗ F05 transcription     stuck       cycles 4  sem PR   journal: docs/F05-transcription/orchestration-<ts>.md
  ✓ F07 admin-panel       success     cycles 1  PR #143  https://github.com/.../pull/143

PRs opened: <M> de <N>

Worktrees preservadas (<K>):
  - .claude/worktrees/F05-transcription/   (limpeza: `git worktree remove --force .claude/worktrees/F05-transcription`)

────────────────────────────────────────
Failure detail

F05 transcription — stuck
  Reason: circuit breaker disparou no ciclo 4 (mesmo conjunto FAIL, zero delta de PASS)
  Items still failing: API-TRANSCRIBE-CONCURRENT-01, EVENT-TRANSCRIPTION-PARTIAL-02
  Eval-report: docs/F05-transcription/eval-report-<ts>.md
  Re-run: `cd .claude/worktrees/F05-transcription && claude "/ia-package:implement-and-evaluate F05"`
────────────────────────────────────────

Wave status file: .claude/worktrees/.wave-<run-id>/wave-status.md
prd_progress.json: não tocado no checkout principal — cada PR traz o estado da sua branch no merge (Regime A)
                   OU reconciliado a partir dos journals das equipes (Regime B)

Soft-fails (nível de wave):
  - <linha>     (omita a seção quando não houver)

Overrides applied: max-parallel=3 (default), team-timeout=90m (default), permission-mode=auto (default), <tail repassado ou none>
Overrides ignored: (none)                                                  (omita quando não houver)
```

---

## Vocabulário de status da wave

| Status | Significado |
|---|---|
| `all-success` | toda equipe terminou em `success` |
| `partial-success` | ao menos um `success` E ao menos um não-`success` |
| `all-failed` | zero `success` |
| `aborted` | a Main abortou antes de qualquer equipe terminar (erros dos Steps 1/2). Sem tabela de equipes. |

## Vocabulário de status por equipe

O mesmo do Final Verdict do `/implement-and-evaluate`, mais `timeout` (acrescentado por esta skill quando o relógio de parede passa do `team-timeout`):

`success` · `manual-pending` · `stuck` · `exhausted` · `aborted` · `pr-blocked` · `timeout`

---

## Notas para quem escreve

- **Os marcadores da tabela usam Unicode (UTF-8)**: `✓`, `✗`, `⚠`, `●` — o mesmo vocabulário do dashboard, para que o arquivo persistido e a tela ao vivo pareçam a mesma coisa. O terminal precisa suportar UTF-8.
- **As equipes que falharam têm o bloco de detalhe em ordem lexicográfica por feature ID**, para que duas renderizações seguidas da mesma wave saiam byte a byte iguais (escrita idempotente).
- **Equipes bem-sucedidas nunca ganham bloco de detalhe.** A URL do PR + o path do journal bastam — qualquer coisa além disso é apodrecimento esperando acontecer conforme o PR evolui.
- **A coluna `PR` aceita as duas formas de forge.** Os exemplos acima usam URLs de GitHub (`.../pull/<N>`), mas o valor vem do campo `pr_url` do status file, que a Main grava no Step 7.0 buscando a PR/MR pela branch da equipe no forge (operação 3.4 de `${CLAUDE_PLUGIN_ROOT}/references/forge.md`) — o journal não tem a URL, porque é fechado antes de a PR/MR ser aberta. No GitLab a URL tem a forma `.../-/merge_requests/<N>`. Copie a URL como ela veio e prefixe o número com a convenção do forge: `#<N>` no GitHub, `!<N>` no GitLab. Equipe `success` sem `pr_url` aparece sem PR/MR (`—` na tabela, `sem PR` no chat) e não conta em `PRs opened:`. Em texto corrido, use o termo do forge do projeto (veja `${CLAUDE_PLUGIN_ROOT}/references/forge.md` § 6); `PRs opened:` continua com esse rótulo nos dois casos.
- **A seção "Worktrees preservadas" some inteira quando está vazia.** `*(none)*` é reservado para sub-bullets, não para seções inteiras.
- **As linhas de `Re-run`** das equipes que falharam SEMPRE começam com `cd <worktree>`, para que o usuário caia na branch certa, com o ambiente (portas, banco) que aquela worktree tiver. Re-rodar do repositório principal atingiria outra branch.
- **Os comandos de remoção de worktree sempre trazem `--force`.** Worktrees carregam arquivos não rastreados (logs de serviço, `.pids/`, tmpdirs do evaluator) que nenhum commit recolhe; sem `--force`, o `git` recusa e o comando que o relatório sugeriu falha na mão do usuário.
- **A linha do `prd_progress.json`** no relatório de chat nomeia explicitamente qual regime valeu (A ou B). É a diferença entre "o estado chega pelos merges de PR" e "a Main reescreveu o arquivo agora", e o leitor precisa saber qual dos dois aconteceu.
- **Foundation**: quando houve serialização, o relatório a nomeia. Se alguma Foundation Feature terminou em status diferente de `success`, o soft-fail correspondente é obrigatório — as features do bloco paralelo rodaram sobre um scaffolding possivelmente incompleto e o leitor precisa saber disso ao ler os resultados delas.
