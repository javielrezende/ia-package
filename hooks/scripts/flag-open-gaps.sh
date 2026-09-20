#!/usr/bin/env bash
# PostToolUse (Write|Edit) — avisa quando um documento do pipeline foi gravado
# ainda com marcadores de lacuna em aberto.
#
# As skills de documentação deixam [NEEDS INPUT] de propósito.
# O risco é o documento ser dado como pronto com os marcadores ainda lá.
set -uo pipefail
command -v python3 >/dev/null 2>&1 || exit 0
exec python3 "$(dirname "${BASH_SOURCE[0]}")/flag_open_gaps.py"
