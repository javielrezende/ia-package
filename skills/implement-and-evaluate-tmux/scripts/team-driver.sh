#!/usr/bin/env bash
# team-driver.sh — roda numa janela tmux, dirigindo uma única equipe (uma feature).
#
# Responsabilidades:
#   1. Inicializar o status file da equipe (status=running, phase=spawning).
#   2. Entrar na worktree da equipe.
#   3. Rodar `claude "/implement-and-evaluate F<ID> <tail>"` em foreground nesta janela.
#   4. Quando o claude sair (por qualquer motivo), fazer parse do bloco Final Verdict
#      do journal da equipe e gravar o status file terminal.
#   5. Dormir para sempre, mantendo a janela tmux viva para inspeção.
#
# Entradas (posicionais):
#   $1  feature_id       ex.: F03
#   $2  feature_slug     ex.: video-upload
#   $3  wave_dir         ex.: /proj/.claude/worktrees/.wave-2026-05-02T18-02-13Z
#   $4  tail             overrides repassados ao /implement-and-evaluate (pode ser vazio)
#   $5  permission_mode  modo de permissão do claude (default: auto)
#
# Variável de ambiente:
#   IAE_COMMAND  slash command que a equipe roda (default: /ia-package:implement-and-evaluate).
#                As skills e commands deste plugin resolvem com o prefixo `ia-package:`;
#                a forma sem namespace NÃO resolve. Só mexa nisso se o plugin for
#                instalado sob outro nome.
#
# Status file: $wave_dir/status/$feature_id.status
# Um campo por linha, key=value. Escrita atômica (grava em .tmp + rename).

set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-time.sh
. "$script_dir/lib-time.sh"

feature_id="${1:?falta feature_id}"
feature_slug="${2:?falta feature_slug}"
wave_dir="${3:?falta wave_dir}"
tail_override="${4:-}"
permission_mode="${5:-auto}"
iae_command="${IAE_COMMAND:-/ia-package:implement-and-evaluate}"

status_dir="$wave_dir/status"
status_file="$status_dir/$feature_id.status"
worktree_rel=".claude/worktrees/${feature_id}-${feature_slug}"
# wave_dir é .claude/worktrees/.wave-<run-id>/ — três níveis abaixo da raiz do projeto.
project_root="$(cd "$wave_dir/../../.." && pwd)"
worktree_abspath="$project_root/$worktree_rel"

mkdir -p "$status_dir"

write_status() {
    local tmp="${status_file}.tmp.$$"
    printf '%s\n' "$@" > "$tmp"
    mv -f "$tmp" "$status_file"
}

# --- Status inicial ---
started_at="$(now_iso)"
write_status \
    "feature_id=$feature_id" \
    "feature_slug=$feature_slug" \
    "worktree=$worktree_abspath" \
    "started_at=$started_at" \
    "last_updated=$started_at" \
    "phase=spawning" \
    "status=running"

# --- Entra na worktree ---
if [ ! -d "$worktree_abspath" ]; then
    write_status \
        "feature_id=$feature_id" \
        "feature_slug=$feature_slug" \
        "worktree=$worktree_abspath" \
        "started_at=$started_at" \
        "last_updated=$(now_iso)" \
        "finished_at=$(now_iso)" \
        "phase=done" \
        "status=aborted" \
        "abort_reason=worktree-missing"
    echo "[team-driver] FATAL: worktree não encontrada em $worktree_abspath" >&2
    exec sleep 99999
fi

cd "$worktree_abspath" || exit 1

write_status \
    "feature_id=$feature_id" \
    "feature_slug=$feature_slug" \
    "worktree=$worktree_abspath" \
    "started_at=$started_at" \
    "last_updated=$(now_iso)" \
    "phase=running" \
    "status=running"

# Monta o input do /implement-and-evaluate.
ie_input="$feature_id"
if [ -n "$tail_override" ]; then
    ie_input="$ie_input $tail_override"
fi

echo "═══════════════════════════════════════════════════════"
echo " $feature_id — $feature_slug"
echo " worktree:        $worktree_abspath"
echo " permission-mode: $permission_mode"
echo " comando:         $iae_command $ie_input"
echo "═══════════════════════════════════════════════════════"
echo

# Roda o claude em foreground neste painel, para que o usuário acompanhe a TUI.
# `--permission-mode auto` (default) auto-aprova tool calls com verificação de
# segurança em background, em vez de pular as checagens por completo — é o que
# mantém a equipe autônoma sem abrir mão da revisão.
claude --permission-mode "$permission_mode" "$iae_command $ie_input"
claude_exit=$?

# --- Parse do bloco Final Verdict do journal da equipe ---
finished_at="$(now_iso)"
journal=""
status_value="aborted"
abort_reason=""
pr_url=""
cycles=""

feature_docs="docs/${feature_id}-${feature_slug}"
if [ -d "$feature_docs" ]; then
    journal="$(ls -1t "$feature_docs"/orchestration-*.md 2>/dev/null | head -n1)"
fi

if [ -n "$journal" ] && [ -f "$journal" ]; then
    fv_status="$(awk '
        /^## Final Verdict/ { in_fv=1; next }
        in_fv && /^\*\*Status:\*\*/ {
            sub(/^\*\*Status:\*\*[[:space:]]*/, "")
            gsub(/`/, "")
            print
            exit
        }
    ' "$journal")"

    case "$fv_status" in
        success|manual-pending|stuck|exhausted|aborted|pr-blocked)
            status_value="$fv_status"
            ;;
        *)
            status_value="aborted"
            abort_reason="journal-missing-final-verdict"
            ;;
    esac

    cycles="$(awk '
        /^\*\*Total cycles:\*\*/ {
            sub(/^\*\*Total cycles:\*\*[[:space:]]*/, "")
            gsub(/`/, "")
            print $1
            exit
        }
    ' "$journal")"

    # URL do PR/MR, se o journal citar alguma. Aceita as duas formas de forge:
    # GitHub `.../pull/<N>` e GitLab `.../-/merge_requests/<N>`, em qualquer host
    # (GitLab auto-hospedado não usa gitlab.com). O nome do campo continua
    # `pr_url` — o dashboard.sh e o wave-status-template.md o leem por esse nome.
    # `|| true` porque o pipefail propagaria o exit 1 do grep quando não houver match.
    pr_url="$( { grep -oE 'https://[^[:space:]]+/(pull|-/merge_requests)/[0-9]+' "$journal" || true; } | tail -n1)"
else
    abort_reason="journal-not-found"
fi

# Sem status recuperado do journal, o exit code do claude vira o diagnóstico.
if [ "$status_value" = "aborted" ] && [ "$claude_exit" -ne 0 ] && [ -z "$abort_reason" ]; then
    abort_reason="claude-exit-${claude_exit}"
fi

# --- Escrita final ---
{
    printf '%s\n' \
        "feature_id=$feature_id" \
        "feature_slug=$feature_slug" \
        "worktree=$worktree_abspath" \
        "started_at=$started_at" \
        "last_updated=$finished_at" \
        "finished_at=$finished_at" \
        "phase=done" \
        "status=$status_value" \
        "claude_exit=$claude_exit"
    [ -n "$cycles" ]       && printf 'cycles=%s\n' "$cycles"
    [ -n "$journal" ]      && printf 'journal=%s\n' "$journal"
    [ -n "$pr_url" ]       && printf 'pr_url=%s\n' "$pr_url"
    [ -n "$abort_reason" ] && printf 'abort_reason=%s\n' "$abort_reason"
} > "${status_file}.tmp.$$"
mv -f "${status_file}.tmp.$$" "$status_file"

echo
echo "[team-driver] $feature_id — status terminal: $status_value"
echo "[team-driver] janela mantida viva para inspeção. Use tmux kill-window ao terminar."

# Mantém a janela tmux viva para o usuário inspecionar a saída final do claude.
exec sleep 99999
