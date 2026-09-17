#!/usr/bin/env bash
# dashboard.sh - renderiza a tabela de status da wave ao vivo.
# Roda sob `watch -n 5` na janela 0 da sessão tmux da wave.
#
# Lê:
#   - $1/wave.meta                                        (metadados da wave)
#   - $1/status/*.status                                  (status por equipe)
#   - <worktree>/docs/F<ID>-<slug>/orchestration-*.md      (journal por equipe,
#                                                          para fase/ciclo/itens ao vivo)
#
# Saída: uma tabela em stdout. O `watch` redesenha a cada 5s.
#
# Uso: dashboard.sh <wave_dir>

set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-time.sh
. "$script_dir/lib-time.sh"

wave_dir="${1:?uso: dashboard.sh <wave_dir>}"
meta_file="$wave_dir/wave.meta"
status_dir="$wave_dir/status"

[ -f "$meta_file" ] || { echo "sem wave.meta em $meta_file"; exit 0; }

get_meta() { awk -F= -v k="$1" '$1==k { sub(/^[^=]+=/, ""); print; exit }' "$meta_file"; }
get_field() { awk -F= -v k="$1" '$1==k { sub(/^[^=]+=/,""); print; exit }' "$2"; }

run_id=$(get_meta run_id)
wave_tag=$(get_meta wave_tag)
started_at=$(get_meta started_at)
max_parallel=$(get_meta max_parallel)
team_timeout=$(get_meta team_timeout)
permission_mode=$(get_meta permission_mode)
foundation=$(get_meta foundation_features)
selected=$(get_meta selected_features)

# --- Cabeçalho ---
# iso_to_epoch devolve 0 em entrada vazia ou não parseável. Sem a guarda, a
# subtração usaria a epoch como início e o painel mostraria algo como 489000h00m.
wave_s0=$(iso_to_epoch "$started_at")
if [ "$wave_s0" -gt 0 ]; then
    elapsed_str=$(fmt_elapsed $(( $(date -u +%s) - wave_s0 )))
else
    elapsed_str="-"
fi

printf 'Wave %s - run %s\n' "$wave_tag" "$run_id"
printf 'Início: %s · decorrido: %s · max-parallel=%s · team-timeout=%s · permission-mode=%s\n' \
    "$started_at" "$elapsed_str" "$max_parallel" "$team_timeout" "${permission_mode:-auto}"
[ -n "$foundation" ] && printf 'Foundation (serializadas): %s\n' "$foundation"
echo

# --- Tabela ---
printf '%-5s  %-20s  %-12s  %-5s  %-10s  %-9s  %s\n' \
    "ID" "Slug" "Fase" "Ciclo" "P/F/B/M" "Decorrido" "Status"
printf '%s\n' "$(printf '%.0s─' {1..100})"

IFS=',' read -r -a pairs <<< "$selected"
for pair in "${pairs[@]}"; do
    pair_trim="$(echo "$pair" | tr -d ' ')"
    [ -z "$pair_trim" ] && continue
    # selected_features é "F03:video-upload,F05:transcription,..."
    fid="${pair_trim%%:*}"
    pair_slug="${pair_trim#*:}"
    [ "$pair_slug" = "$pair_trim" ] && pair_slug=""
    sf="$status_dir/$fid.status"

    if [ ! -f "$sf" ]; then
        printf '%-5s  %-20s  %-12s  %-5s  %-10s  %-9s  %s\n' \
            "$fid" "${pair_slug:--}" "-" "-" "-" "-" "◦ na fila"
        continue
    fi

    feat_slug=$(get_field feature_slug "$sf"); [ -z "$feat_slug" ] && feat_slug="$pair_slug"
    started=$(get_field  started_at  "$sf")
    finished=$(get_field finished_at "$sf")
    phase=$(get_field    phase       "$sf")
    status=$(get_field   status      "$sf")
    pr_url=$(get_field   pr_url      "$sf")
    journal=$(get_field  journal     "$sf")
    worktree=$(get_field worktree    "$sf")

    # Ciclo/itens ao vivo, tirados da última linha do Cycle Log do journal.
    cycle_str="-"
    items_str="-/-/-/-"
    live_phase="$phase"
    if [ -z "$journal" ] && [ -n "$worktree" ] && [ -d "$worktree/docs/${fid}-${feat_slug}" ]; then
        journal="$(ls -1t "$worktree/docs/${fid}-${feat_slug}"/orchestration-*.md 2>/dev/null | head -n1)"
    fi
    if [ -n "$journal" ] && [ -f "$journal" ]; then
        # Última linha de dados (pula cabeçalho e separador) da tabela Cycle Log.
        last_row="$(awk '
            /^## Cycle Log/ { in_log=1; next }
            in_log && /^## / { exit }
            in_log && /^\| *[0-9]+ *\|/ { last=$0 }
            END { print last }
        ' "$journal")"
        if [ -n "$last_row" ]; then
            cycle_str=$( echo "$last_row" | awk -F'|' '{ gsub(/ /,"",$2); print $2 }')
            live_phase=$(echo "$last_row" | awk -F'|' '{ gsub(/^ +| +$/,"",$3); print $3 }')
            # Extrai P=N F=N B=N M=N da célula Counts / Notes (5ª coluna).
            counts_cell=$(echo "$last_row" | awk -F'|' '{ print $5 }')
            p=$(echo "$counts_cell" | grep -oE 'P=[0-9]+' | head -n1 | cut -d= -f2)
            f=$(echo "$counts_cell" | grep -oE 'F=[0-9]+' | head -n1 | cut -d= -f2)
            b=$(echo "$counts_cell" | grep -oE 'B=[0-9]+' | head -n1 | cut -d= -f2)
            m=$(echo "$counts_cell" | grep -oE 'M=[0-9]+' | head -n1 | cut -d= -f2)
            items_str="${p:--}/${f:--}/${b:--}/${m:--}"
        fi
    fi

    # Tempo decorrido da equipe. Mesma guarda do cabeçalho: qualquer uma das duas
    # pontas não parseável (ou ausente) imprime "-" em vez de um número absurdo.
    team_s0=$(iso_to_epoch "$started")
    team_s1=$(iso_to_epoch "${finished:-$(now_iso)}")
    if [ "$team_s0" -gt 0 ] && [ "$team_s1" -gt 0 ]; then
        elapsed_team=$(fmt_elapsed $(( team_s1 - team_s0 )))
    else
        elapsed_team="-"
    fi

    case "$status" in
        success)        marker="✓ success" ;;
        manual-pending) marker="⚠ manual-pending" ;;
        stuck)          marker="✗ stuck" ;;
        exhausted)      marker="✗ exhausted" ;;
        aborted)        marker="✗ aborted" ;;
        pr-blocked)     marker="✗ pr-blocked" ;;
        timeout)        marker="✗ timeout" ;;
        running)        marker="● running" ;;
        *)              marker="? $status" ;;
    esac
    [ -n "$pr_url" ] && marker="$marker ($pr_url)"

    printf '%-5s  %-20s  %-12s  %-5s  %-10s  %-9s  %s\n' \
        "$fid" "${feat_slug:--}" "${live_phase:--}" "$cycle_str" "$items_str" "$elapsed_team" "$marker"
done

echo
done_count=$(grep -lE '^status=(success|manual-pending|stuck|exhausted|aborted|pr-blocked|timeout)$' "$status_dir"/*.status 2>/dev/null | wc -l | tr -d ' ')
running_count=$(grep -lE '^status=running$' "$status_dir"/*.status 2>/dev/null | wc -l | tr -d ' ')
total=${#pairs[@]}
queued=$(( total - done_count - running_count ))
printf 'Totais: %s concluídas · %s rodando · %s na fila · %s no total\n' \
    "$done_count" "$running_count" "$queued" "$total"
