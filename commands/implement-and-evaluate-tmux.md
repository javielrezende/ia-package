---
description: |
    Toca uma wave inteira do PRD em paralelo, com um worktree git e uma janela tmux por feature. Usage: /implement-and-evaluate-tmux <seleção> [overrides] — ex.: "wave 3", "F03,F05,F07", "wave 3 except F04 max-parallel=2"
---

Invoque a skill `ia-package:implement-and-evaluate-tmux` pela Skill tool, passando `$ARGUMENTS` como string de input.

A skill é dona do parsing do input, da validação, do despacho, do polling e do relatório — consulte o SKILL.md dela para o comportamento. Não reimplemente nada aqui nem interprete os argumentos antes de repassá-los: a gramática de overrides (Families 1 a 4) é resolvida dentro da skill.

User input: $ARGUMENTS
