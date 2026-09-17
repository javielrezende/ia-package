#!/usr/bin/env bash
# ports-tail.sh — mostra periodicamente as portas TCP em LISTEN abertas por
# processos cujo diretório de trabalho está dentro da worktree da equipe.
#
# Agnóstico de projeto: não lê nenhum arquivo de env nem assume convenção de
# path; usa apenas `lsof`. É o painel que responde "em que porta essa equipe
# subiu o serviço dela?" sem a skill precisar saber nada do projeto.
#
# Entradas (posicionais):
#   $1  worktree_abspath  ex.: /proj/.claude/worktrees/F05-folder-organization
#
# Roda num painel tmux baixo (~14 linhas) no canto inferior direito da janela
# da equipe, abaixo do services-tail.

set -uo pipefail

worktree="${1:?uso: ports-tail.sh <worktree>}"
worktree="${worktree%/}"   # tira a barra final, para o match de prefixo ser exato
INTERVAL=5

if ! command -v lsof >/dev/null 2>&1; then
    echo "lsof não instalado — não é possível descobrir as portas."
    echo "Instale com: sudo apt install lsof"
    exec sleep 99999
fi

# PIDs cujo CWD está dentro da worktree. lsof puro, portável Linux/macOS.
discover_pids() {
    lsof -nP -d cwd -F pn 2>/dev/null | awk -v wt="$worktree/" '
        /^p/ { pid = substr($0, 2) }
        /^n/ {
            cwd = substr($0, 2) "/"
            if (index(cwd, wt) == 1) print pid
        }
    ' | sort -u
}

print_header() {
    printf '═══ %s ═══\n' "$(basename "$worktree")"
    date '+%H:%M:%S'
    if [ -e "$worktree/.git" ]; then
        local branch
        branch=$(cd "$worktree" 2>/dev/null && git branch --show-current 2>/dev/null) || branch=""
        [ -n "$branch" ] && printf 'branch: %s\n' "$branch"
    fi
    echo
}

list_listening_ports() {
    local pids="$1"
    if [ -z "$pids" ]; then
        echo "(nenhum processo com cwd dentro da worktree)"
        return
    fi

    local pid_csv rows
    pid_csv=$(echo "$pids" | paste -sd, -)
    rows=$(lsof -nP -iTCP -sTCP:LISTEN -a -p "$pid_csv" 2>/dev/null | tail -n +2)

    if [ -z "$rows" ]; then
        echo "(nenhuma porta TCP em LISTEN ainda)"
        return
    fi

    printf '%-5s %-7s %s\n' "PORTA" "PID" "COMANDO"
    printf '%s\n' "─────────────────────────────────────────────"
    # Passo 1: extrai pid + porta do lsof. Passo 2: enriquece com a linha de
    # comando via `ps`. A coluna NAME do lsof vem como `*:3000` ou `127.0.0.1:5432`.
    echo "$rows" | awk '{
        pid = $2
        n = split($9, parts, ":")
        port = parts[n]
        gsub(/\(.*\)/, "", port)
        print port "\t" pid
    }' | sort -u | sort -n -k1 | while IFS=$'\t' read -r port pid; do
        cmd=$(ps -p "$pid" -o command= 2>/dev/null)
        cmd="${cmd#"${cmd%%[! ]*}"}"   # tira espaços à esquerda
        # Deixa a linha legível: todo token que é path absoluto vira só o basename.
        # Ex.: "/opt/.../bin/node /home/.../tsx/dist/loader.mjs src/main.ts"
        #    → "node loader.mjs src/main.ts"
        cmd=$(echo "$cmd" | awk '{
            for (i = 1; i <= NF; i++) {
                if (substr($i, 1, 1) == "/") {
                    n = split($i, parts, "/")
                    $i = parts[n]
                }
            }
            print
        }')
        # Se ainda estiver longo, corta pelo FIM (o começo agora é o que importa).
        max=60
        if [ ${#cmd} -gt $max ]; then
            cmd="${cmd:0:$((max - 3))}..."
        fi
        printf '%-5s %-7s %s\n' "$port" "$pid" "$cmd"
    done
}

while true; do
    clear
    print_header
    list_listening_ports "$(discover_pids)"
    sleep "$INTERVAL"
done
