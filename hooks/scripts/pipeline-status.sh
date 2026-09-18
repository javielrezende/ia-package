#!/usr/bin/env bash
# SessionStart — injeta no contexto onde o projeto está no pipeline de documentação.
#
# Sem isso, o Claude só descobre que já existe um docs/PRD.md depois de procurar.
# Com isso, ele já começa a sessão sabendo qual é o próximo passo do pipeline.
set -uo pipefail

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
cd "$ROOT" 2>/dev/null || exit 0

# Um plugin não deve inventar convenções: só reporta o que encontra.
found=""
add() { found="${found}\n- $1"; }

[ -f "docs/PRD.md" ]  && add "PRD:   docs/PRD.md"
[ -f "docs/HLD.md" ]  && add "HLD:   docs/HLD.md"

# O FDD e o PRD de feature são um por feature: moram na pasta da feature quando ela
# existe (reportados no laço abaixo) e caem na raiz de docs/ quando não existe.
# O docs/FDD.md sem sufixo é o layout antigo, de quando a skill gravava sempre no
# mesmo arquivo — continua sendo reportado para quem já tem um.
[ -f "docs/FDD.md" ]  && add "FDD:   docs/FDD.md"

loose_docs=$(find docs -maxdepth 1 -type f \( -name 'FDD-*.md' -o -name 'PRD-*.md' \) 2>/dev/null | sort | head -20)
if [ -n "$loose_docs" ]; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    add "Doc:   $f (sem pasta de feature)"
  done <<< "$loose_docs"
fi

# Diretriz de código: um arquivo por linguagem (docs/go-development-guidelines.md).
guidelines=$(find docs -maxdepth 1 -type f -name '*development-guideline*.md' 2>/dev/null | sort | head -10)
if [ -n "$guidelines" ]; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    add "Diretriz: $f"
  done <<< "$guidelines"
fi

feature_dirs=$(find docs -maxdepth 1 -type d -name 'F[0-9][0-9]*' 2>/dev/null | sort | head -20)
if [ -n "$feature_dirs" ]; then
  while IFS= read -r d; do
    [ -z "$d" ] && continue
    marks=""
    [ -f "$d/PRD.md" ]      && marks="${marks}prd "
    [ -f "$d/FDD.md" ]      && marks="${marks}fdd "
    [ -f "$d/spec.md" ]     && marks="${marks}spec "
    [ -f "$d/plan.md" ]     && marks="${marks}plan "
    [ -f "$d/contract.md" ] && marks="${marks}contract "
    # eval-reports e journals dizem em que ponto do loop
    # implementar -> avaliar -> corrigir a feature parou.
    evals=$(find "$d" -maxdepth 1 -name 'eval-report-*.md' 2>/dev/null | wc -l | tr -d ' ')
    [ "${evals:-0}" -gt 0 ] && marks="${marks}eval:${evals} "
    journals=$(find "$d" -maxdepth 1 -name 'orchestration-*.md' 2>/dev/null | wc -l | tr -d ' ')
    [ "${journals:-0}" -gt 0 ] && marks="${marks}journal:${journals} "
    [ -z "$marks" ] && marks="(vazia) "
    add "Feature: $d — ${marks% }"
  done <<< "$feature_dirs"
fi

# O prd_progress.json é o registro determinístico do estado de cada feature ao
# longo do pipeline. O tally é o sinal mais útil na abertura da sessão: diz o que
# está pendente, o que falhou e o que já está entregue, sem ninguém precisar abrir
# o arquivo. Sem python3 no PATH, reporta só a presença do arquivo.
progress=""
for p in docs/prd_progress.json prd_progress.json; do
  [ -f "$p" ] && { progress="$p"; break; }
done
if [ -n "$progress" ]; then
  tally=""
  if command -v python3 >/dev/null 2>&1; then
    tally=$(python3 - "$progress" <<'PY' 2>/dev/null
import collections, json, sys

try:
    with open(sys.argv[1], encoding="utf-8") as fh:
        data = json.load(fh)
except Exception:
    raise SystemExit(0)

features = data.get("features")
if not isinstance(features, dict):
    raise SystemExit(0)

counts = collections.Counter(
    (v or {}).get("status", "?") for v in features.values() if isinstance(v, dict)
)
# Ordem do ciclo de vida, para a linha se ler como o progresso do pipeline.
order = ["pending", "implementing", "implemented", "fail", "pr-blocked", "done", "removed"]
parts = [f"{s} {counts[s]}" for s in order if counts.get(s)]
parts += [f"{s} {n}" for s, n in sorted(counts.items()) if s not in order]
if parts:
    print(", ".join(parts))
PY
)
  fi
  if [ -n "$tally" ]; then
    add "Progresso: $progress — $tally"
  else
    add "Progresso: $progress"
  fi
fi

adr_count=$(find docs/adrs -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
[ "${adr_count:-0}" -gt 0 ] && add "ADRs:  $adr_count em docs/adrs/"

c4_count=$(find docs/c4 -name '*.puml' 2>/dev/null | wc -l | tr -d ' ')
[ "${c4_count:-0}" -gt 0 ] && add "C4:    $c4_count diagramas em docs/c4/"

mmd_count=$(find docs/mermaid -name '*.mmd' -o -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
[ "${mmd_count:-0}" -gt 0 ] && add "Mermaid: $mmd_count arquivos em docs/mermaid/"

# Nada do pipeline existe ainda: fica quieto em vez de poluir toda sessão.
[ -z "$found" ] && exit 0

printf 'Artefatos do pipeline ia-package já presentes neste projeto:%b\n\nOrdem do pipeline: PRD (+ prd_progress.json) -> HLD -> FDD -> spec/plan/contract -> implementação -> avaliação (eval-report) -> correção -> ADRs -> diagramas. Leia o artefato anterior antes de gerar o próximo, em vez de reperguntar ao usuário o que já está documentado. O prd_progress.json é a fonte determinística do estado de cada feature; o eval-report mais recente de uma pasta de feature é o veredito canônico dela.\n' "$found"
exit 0
