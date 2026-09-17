#!/usr/bin/env bash
# services-tail.sh — roda no painel superior direito da janela de uma equipe.
# Espera os logs de serviço aparecerem (quem os cria é o bring-up do evaluator)
# e então faz `tail -F` neles, para o usuário ver a saída dos serviços ao vivo
# ao lado da TUI do claude.
#
# Entradas (posicionais):
#   $1  worktree_abspath  ex.: /proj/.claude/worktrees/F05-folder-organization
#
# Descoberta de logs, na ordem (a primeira convenção que casar vence):
#   1. <worktree>/.pids/*.log     — convenção do scaffold clean-arch
#   2. <worktree>/logs/*.log      — convenção comum em outros projetos
#
# O pacote original fixava `.pids/{backend,web}.log`, que só existe em projetos
# gerados pelo scaffold clean-arch; em qualquer outro projeto o painel ficava
# preso para sempre. Aqui a descoberta é por convenção e o painel diz claramente
# o que está procurando quando não encontra nada.
#
# `tail -F` (F maiúsculo) tolera arquivo que ainda não existe, segue rotação e
# imprime cabeçalhos `==> arquivo <==` entre as fontes.

set -uo pipefail

worktree="${1:?uso: services-tail.sh <worktree_abspath>}"
worktree="${worktree%/}"

# Ecoa os paths dos logs encontrados, um por linha. Vazio quando não há nenhum.
discover_logs() {
    local found
    found=$(ls -1 "$worktree"/.pids/*.log 2>/dev/null) && [ -n "$found" ] && { printf '%s\n' "$found"; return; }
    found=$(ls -1 "$worktree"/logs/*.log  2>/dev/null) && [ -n "$found" ] && { printf '%s\n' "$found"; return; }
    return 1
}

echo "═══════════════════════════════════════════"
echo " $(basename "$worktree")"
echo " procurando logs em: .pids/*.log, logs/*.log"
echo "═══════════════════════════════════════════"
echo

# Espera em silêncio até algum log aparecer. Sem essa espera, o `tail -F`
# despejaria erros de "cannot open" em loop.
waited=0
while ! logs=$(discover_logs); do
    sleep 5
    waited=$(( waited + 5 ))
    # A cada 2 minutos, lembra o usuário de que o painel está vivo, só sem logs.
    if [ $(( waited % 120 )) -eq 0 ]; then
        echo "  … $((waited / 60))min sem logs de serviço (normal antes do bring-up do evaluator)"
    fi
done

echo "Logs encontrados:"
printf '  %s\n' $logs
echo

# shellcheck disable=SC2086 — a divisão em palavras é intencional: um arg por log.
exec tail -F $logs 2>&1
