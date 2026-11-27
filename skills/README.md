# Agent Skills

These folders follow the [Agent Skills](https://agentskills.io) open standard. Each one is a specialist brief the five Operator Kit agents already use, packaged so Claude Code, Cursor, Codex, and other compatible clients can load it.

| Skill | Job |
|---|---|
| [operator-kit](operator-kit/SKILL.md) | Roster and routing: pick the smallest specialist that fits |
| [echo](echo/SKILL.md) | Read-only codebase mapping |
| [newton](newton/SKILL.md) | Cited research briefing |
| [hypatia](hypatia/SKILL.md) | Adversarial review of a plan |
| [iris](iris/SKILL.md) | Visual specification, not code |
| [lyra](lyra/SKILL.md) | Bounded implementation |

The Claude Code subagents in `agents/` stay the source for plugin installs. Keep a skill and its matching agent file in sync when you change the brief.

Install instructions for each agent are in the [README](../README.md#install-as-agent-skills).
