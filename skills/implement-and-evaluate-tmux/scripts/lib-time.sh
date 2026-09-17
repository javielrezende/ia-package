#!/usr/bin/env bash
# lib-time.sh — helpers de tempo compartilhados pelos scripts da skill.
#
# Motivo de existir: o pacote original usava `date -u -j -f` (sintaxe BSD/macOS),
# que falha em Linux/WSL2 e caía num fallback silencioso que zerava todo tempo
# decorrido — o `team-timeout` nunca disparava e o dashboard mostrava sempre
# `0h00m`. Aqui a conversão tenta primeiro a sintaxe GNU (`-d`) e só depois a BSD,
# então funciona nos dois sistemas.
#
# Uso: `. "$(dirname "$0")/lib-time.sh"`

# now_iso — timestamp UTC RFC 3339, o mesmo formato que o prd_progress.json usa.
now_iso() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

# iso_to_epoch <iso8601> — converte para segundos desde a epoch.
# Imprime 0 quando a entrada é vazia ou não parseável, para que o chamador
# consiga distinguir "sem dado" de um tempo real.
iso_to_epoch() {
    local iso="${1:-}"
    [ -z "$iso" ] && { echo 0; return; }
    date -u -d "$iso" +%s 2>/dev/null && return          # GNU coreutils (Linux/WSL2)
    date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$iso" +%s 2>/dev/null && return  # BSD/macOS
    echo 0
}

# fmt_elapsed <segundos> — formata como `<H>h<MM>m`.
fmt_elapsed() {
    local s="${1:-0}"
    [ "$s" -lt 0 ] 2>/dev/null && s=0
    printf '%dh%02dm' $(( s / 3600 )) $(( (s % 3600) / 60 ))
}
