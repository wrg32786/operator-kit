---
name: operator-kit
description: >
  Route work to the smallest AIgent Operator Kit specialist that fits:
  Echo for read-only codebase mapping, Newton for cited research,
  Hypatia for adversarial review of a plan, Iris for a visual specification,
  and Lyra for bounded implementation. Use when the user wants the operator
  team, the specialist roster, or help choosing who should take a task.
license: MIT
metadata:
  author: wrg32786
---

# Operator Kit roster

Use one specialist by default. Compose only when the task crosses roles. After you pick a specialist, follow that skill's `SKILL.md` and stay inside its job.

| Need | Use | Skill |
|---|---|---|
| Locate code or trace callers | Echo | [echo](../echo/SKILL.md) |
| Implement a clear, bounded change | Lyra | [lyra](../lyra/SKILL.md) |
| Repair an unclear bug | Echo, then Lyra | [echo](../echo/SKILL.md), [lyra](../lyra/SKILL.md) |
| Evaluate a current tool or approach | Newton, then Hypatia | [newton](../newton/SKILL.md), [hypatia](../hypatia/SKILL.md) |
| Design and build a visual surface | Iris, then Lyra | [iris](../iris/SKILL.md), [lyra](../lyra/SKILL.md) |
| Review a plan, launch, or architecture choice | Hypatia | [hypatia](../hypatia/SKILL.md) |
| Review the current diff | The host agent's built-in code review | (not an Operator Kit skill) |
| Commit, push, open a PR, or merge | The main session, only when the user explicitly asks | (not an Operator Kit skill) |

## Rules that apply to every specialist

- Do not invent files, APIs, or findings. Mark uncertainty.
- Keep the return shape of the specialist you are using.
- Lyra never commits, pushes, or opens a pull request unless the user explicitly asks.
- Echo, Newton, and Hypatia are read-only. Iris returns a specification, not code.

In Claude Code, the same roster is also available as subagents (`agents/*.md`, or `operator-kit:<name>` when the plugin is installed). In Cursor, Codex, and other Agent Skills clients, load these skill folders and invoke a specialist by name or by the task in the table above.
