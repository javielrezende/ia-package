"""PostToolUse (Write|Edit): avisa sobre marcadores de lacuna deixados no doc."""
import json, os, re, sys

MARKER = re.compile(r"\[NEEDS INPUT[^\]]*\]|\bTBD\b|<preencher>", re.IGNORECASE)


def main() -> int:
    try:
        data = json.load(sys.stdin)
    except Exception:
        return 0

    path = (data.get("tool_input") or {}).get("file_path") or ""
    if not path.endswith(".md"):
        return 0

    root = data.get("cwd") or os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()
    abs_path = path if os.path.isabs(path) else os.path.join(root, path)
    try:
        rel = os.path.relpath(abs_path, root)
    except ValueError:
        return 0
    if not rel.startswith("docs" + os.sep):
        return 0

    try:
        with open(abs_path, encoding="utf-8", errors="replace") as fh:
            lines = fh.read().splitlines()
    except OSError:
        return 0

    hits = [(n, ln.strip()) for n, ln in enumerate(lines, 1) if MARKER.search(ln)]
    if not hits:
        return 0

    shown = "\n".join(f"  {rel}:{n}  {text[:110]}" for n, text in hits[:8])
    extra = f"\n  ... e mais {len(hits) - 8}" if len(hits) > 8 else ""
    # No PostToolUse, stdout em texto puro só vai para o log de debug; o Claude
    # só enxerga o aviso quando ele vem em hookSpecificOutput.additionalContext.
    message = (
        f"{len(hits)} lacuna(s) em aberto em {rel}:\n{shown}{extra}\n"
        "Não trate o documento como concluído sem resolver esses pontos com o "
        "usuário ou listá-los explicitamente como pendências no relatório final."
    )
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PostToolUse",
            "additionalContext": message,
        }
    }, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
