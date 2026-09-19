#!/usr/bin/env bash
# team-driver.sh — roda numa janela tmux, dirigindo uma única equipe (uma feature).
#
# Responsabilidades:
#   1. Inicializar o status file da equipe (status=running, phase=spawning).
#   2. Entrar na worktree da equipe.
#   3. Gravar o marcador de início e subir o vigia em background.
#   4. Rodar `claude "/implement-and-evaluate F<ID> <tail>"` em foreground nesta janela.
#      O claude abre a TUI interativa, e ela NÃO sai quando a skill termina.
#   5. Vigia: a cada 15s, confere se a execução terminou (journal desta execução com
#      Final Verdict terminal e .orchestrate.lock liberado) e grava o status terminal
#      com o claude ainda aberto.
#   6. Se o claude sair (/exit manual, crash): encerrar o vigia; se o status já for
#      terminal, só acrescentar claude_exit; senão, fazer o parse do journal como hoje.
#   7. Dormir para sempre, mantendo a janela tmux viva para inspeção.
#
# Entradas (posicionais):
#   $1  feature_id       ex.: F03
#   $2  feature_slug     ex.: video-upload
#   $3  wave_dir         ex.: /proj/.claude/worktrees/.wave-2026-05-02T18-02-13Z
#   $4  tail             overrides repassados ao /implement-and-evaluate (pode ser vazio)
#   $5  permission_mode  modo de permissão do claude (default: auto)
#
# Variáveis de ambiente:
#   IAE_COMMAND         slash command que a equipe roda (default: /ia-package:implement-and-evaluate).
#                       As skills e commands deste plugin resolvem com o prefixo `ia-package:`;
#                       a forma sem namespace NÃO resolve. Só mexa nisso se o plugin for
#                       instalado sob outro nome.
#   IAE_WATCH_INTERVAL  segundos entre as conferências do vigia (default: 15). Existe para
#                       os testes do script; numa wave real, deixe o default.
#
# Status file: $wave_dir/status/$feature_id.status
# Um campo por linha, key=value. Escrita atômica (grava num temporário + rename).
# O campo pr_url não é gravado aqui: o journal é fechado antes de a PR/MR existir, então
# não tem a URL. A Main acrescenta o pr_url no Step 7.0 do SKILL.md, buscando a PR/MR
# pela branch da equipe no forge.
# Marcador de início: $wave_dir/status/$feature_id.started

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
watch_interval="${IAE_WATCH_INTERVAL:-15}"

status_dir="$wave_dir/status"
status_file="$status_dir/$feature_id.status"
start_marker="$status_dir/$feature_id.started"
worktree_rel=".claude/worktrees/${feature_id}-${feature_slug}"
# wave_dir é .claude/worktrees/.wave-<run-id>/ — três níveis abaixo da raiz do projeto.
project_root="$(cd "$wave_dir/../../.." && pwd)"
worktree_abspath="$project_root/$worktree_rel"
feature_docs="$worktree_abspath/docs/${feature_id}-${feature_slug}"
orchestrate_lock="$feature_docs/.orchestrate.lock"

mkdir -p "$status_dir"

write_status() {
    local tmp="${status_file}.tmp.$$"
    printf '%s\n' "$@" > "$tmp"
    mv -f "$tmp" "$status_file"
}

status_field() {
    awk -F= -v k="$1" '$1==k { sub(/^[^=]+=/,""); print; exit }' "$status_file" 2>/dev/null
}

# Journal mais recente DESTA execução. O orquestrador o cria depois que o driver
# grava o marcador de início; um journal mais antigo na pasta veio commitado da
# branch padrão (execução anterior da mesma feature) e não diz nada sobre esta.
latest_journal() {
    local f newest=""
    for f in "$feature_docs"/orchestration-*.md; do
        [ -f "$f" ] || continue
        [ "$f" -nt "$start_marker" ] || continue
        if [ -z "$newest" ] || [ "$f" -nt "$newest" ]; then
            newest="$f"
        fi
    done
    printf '%s' "$newest"
}

# Valor do **Status:** dentro do bloco ## Final Verdict do journal ($1).
final_verdict_status() {
    awk '
        /^## Final Verdict/ { in_fv=1; next }
        in_fv && /^\*\*Status:\*\*/ {
            sub(/^\*\*Status:\*\*[[:space:]]*/, "")
            gsub(/`/, "")
            print
            exit
        }
    ' "$1"
}

is_terminal() {
    case "$1" in
        success|manual-pending|stuck|exhausted|aborted|pr-blocked) return 0 ;;
        *) return 1 ;;
    esac
}

# --- Parse do bloco Final Verdict do journal da equipe e escrita do status terminal ---
# $1 = exit code do claude, quando ele saiu; vazio quando quem chama é o vigia, com
# o claude ainda aberto. Idempotente: só grava sobre um status file ainda `running`,
# então uma segunda chamada — ou uma chamada depois do `timeout` da Main — não muda nada.
finalize_from_journal() {
    local claude_exit="${1:-}"
    local finished_at journal status_value abort_reason cycles fv_status tmp

    finished_at="$(now_iso)"
    journal="$(latest_journal)"
    status_value="aborted"
    abort_reason=""
    cycles=""

    if [ -n "$journal" ]; then
        fv_status="$(final_verdict_status "$journal")"

        if is_terminal "$fv_status"; then
            status_value="$fv_status"
        else
            status_value="aborted"
            abort_reason="journal-missing-final-verdict"
        fi

        cycles="$(awk '
            /^\*\*Total cycles:\*\*/ {
                sub(/^\*\*Total cycles:\*\*[[:space:]]*/, "")
                gsub(/`/, "")
                print $1
                exit
            }
        ' "$journal")"
    else
        abort_reason="journal-not-found"
    fi

    # Sem status recuperado do journal, o exit code do claude vira o diagnóstico.
    if [ "$status_value" = "aborted" ] && [ -n "$claude_exit" ] && [ "$claude_exit" -ne 0 ] && [ -z "$abort_reason" ]; then
        abort_reason="claude-exit-${claude_exit}"
    fi

    tmp="$(mktemp "${status_file}.tmp.XXXXXX")" || return 1
    {
        printf '%s\n' \
            "feature_id=$feature_id" \
            "feature_slug=$feature_slug" \
            "worktree=$worktree_abspath" \
            "started_at=$started_at" \
            "last_updated=$finished_at" \
            "finished_at=$finished_at" \
            "phase=done" \
            "status=$status_value"
        [ -n "$claude_exit" ]  && printf 'claude_exit=%s\n' "$claude_exit"
        [ -n "$cycles" ]       && printf 'cycles=%s\n' "$cycles"
        [ -n "$journal" ]      && printf 'journal=%s\n' "$journal"
        [ -n "$abort_reason" ] && printf 'abort_reason=%s\n' "$abort_reason"
    } > "$tmp"

    # Confere de novo logo antes do rename: a Main pode ter gravado `timeout` enquanto
    # o journal era lido.
    if [ "$(status_field status)" = "running" ]; then
        mv -f "$tmp" "$status_file"
    else
        rm -f "$tmp"
    fi
}

# Acrescenta (ou troca) o claude_exit num status file que já é terminal.
record_claude_exit() {
    local tmp
    tmp="$(mktemp "${status_file}.tmp.XXXXXX")" || return 1
    { grep -v '^claude_exit=' "$status_file"; printf 'claude_exit=%s\n' "$1"; } > "$tmp"
    mv -f "$tmp" "$status_file"
}

# --- Vigia ---
# O claude interativo não sai quando a skill termina, então o fim da execução é
# decidido aqui, pelas três condições juntas:
#   1. existe um journal desta execução (mais novo que o marcador de início);
#   2. o **Status:** do Final Verdict dele é terminal;
#   3. o .orchestrate.lock não existe mais.
# A 3 é a que garante o fim de verdade: no sucesso, o Final Verdict é gravado no
# Step 7.6 do /implement-and-evaluate, ANTES do push e da PR/MR; o lock só é
# liberado no Step 8, DEPOIS deles. O vigia sai sem gravar se o status file deixar
# de ser `running` (a Main gravou `timeout`).
watch_for_completion() {
    local journal
    while :; do
        sleep "$watch_interval"
        [ "$(status_field status)" = "running" ] || return 0
        [ -e "$orchestrate_lock" ] && continue
        journal="$(latest_journal)"
        [ -n "$journal" ] || continue
        is_terminal "$(final_verdict_status "$journal")" || continue
        finalize_from_journal
        return 0
    done
}

# O vigia pode ter saído há horas (depois de gravar o status), e o PID dele pode ter
# sido reusado desde então. Só mata o processo se ele ainda for filho deste driver.
stop_watcher() {
    [ -n "${watcher_pid:-}" ] || return 0
    if [ "$(ps -o ppid= -p "$watcher_pid" 2>/dev/null | tr -d ' ')" = "$$" ]; then
        kill "$watcher_pid" 2>/dev/null
    fi
    wait "$watcher_pid" 2>/dev/null
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

# Marcador de início e vigia. A saída do vigia vai para /dev/null: qualquer byte
# escrito neste painel corromperia a TUI do claude.
: > "$start_marker"
watch_for_completion < /dev/null > /dev/null 2>&1 &
watcher_pid=$!

# Roda o claude em foreground neste painel, para que o usuário acompanhe a TUI.
# `--permission-mode auto` (default) auto-aprova tool calls com verificação de
# segurança em background, em vez de pular as checagens por completo — é o que
# mantém a equipe autônoma sem abrir mão da revisão.
claude --permission-mode "$permission_mode" "$iae_command $ie_input"
claude_exit=$?

# O claude saiu (/exit manual, crash). Encerra o vigia antes de qualquer escrita,
# para que só este processo grave o status file daqui em diante.
stop_watcher

if [ "$(status_field status)" = "running" ]; then
    # Caminho de reserva: o vigia não chegou a ver o fim da execução.
    finalize_from_journal "$claude_exit"
else
    # O vigia (ou a Main) já gravou o status terminal; só registra como o claude saiu.
    record_claude_exit "$claude_exit"
fi

echo
echo "[team-driver] $feature_id — status terminal: $(status_field status)"
echo "[team-driver] janela mantida viva para inspeção. Use tmux kill-window ao terminar."

# Mantém a janela tmux viva para o usuário inspecionar a saída final do claude.
exec sleep 99999
