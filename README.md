# AIgent Operator Kit

These are 5 agents I use across my own projects, plus the context-loading pattern that keeps them from forgetting what you're building. All MIT licensed. Drop them into your Claude Code setup and use them as-is or adapt them.

## What's in it

```
operator-kit/
├── agents/          # Drop into ~/.claude/agents/
│   ├── iris.md      # Visual designer
│   ├── lyra.md      # Builder
│   ├── echo.md      # Scout / reader
│   ├── newton.md    # Research synthesist
│   └── hypatia.md   # Critic / devil's advocate
├── context-loader/  # Auto-inject project context on keyword match
│   ├── auto-context-load.sh
│   ├── project-keywords.json
│   └── install.md
├── rules/
│   └── post-compact-critical.md.template
└── examples/
    └── sample-project-keywords.json
```

## The agents

**Iris** is the visual specialist. Give her a design problem and she returns a specification: palette, proportions, hierarchy, motion, and AI image-gen prompts if needed. She does not write code — she writes specs precise enough that a builder can implement without guessing. Use her for UI design briefs, sprite specs, color systems, and animation choreography.

**Lyra** is the builder. She takes a complete spec and returns a diff or built artifact. Before writing anything, she runs a pre-build checklist: invariant, failure modes, cost asymmetry, boring-path test, handoff test. Every response ends with an honesty ledger so you know exactly what changed, what was left alone, and what she noticed but didn't fix. Use her for code edits with bounded scope.

**Echo** is the scout. Haiku-class, read-only, fast. She traverses files, summarizes codebases, and returns structured findings — paths, line numbers, bullet points, no prose. She never writes or executes. Use her when you need to know what exists before deciding what to do.

**Newton** is the research synthesist. He pulls from multiple sources (web search, project notes, GitHub, docs), triangulates, and returns a structured briefing with inline citations. Every claim traces to a source. He leads with a working hypothesis and closes with a recommendation — you make the call. Use him for tool evaluations, competitive analysis, and any question that needs real evidence before a decision.

**Hypatia** is the critic. She challenges thinking before it hardens into commitment. She finds the strongest counterargument first, names the hidden assumptions, and surfaces the alternatives you didn't consider. Read-only — she critiques, never builds. Use her before any significant decision, architecture choice, or plan you're about to commit to.

## Install the agents

Copy the files from `agents/` into your Claude Code agents directory:

```bash
cp agents/*.md ~/.claude/agents/
```

That's it. Claude Code auto-discovers agents in that directory. You can invoke them directly:

```
use the echo agent to find all API route handlers in src/
```

Or set one as the default for a project by adding it to `.claude/CLAUDE.md`.

## Install the context loader

The context loader is a UserPromptSubmit hook. When you mention a keyword in your prompt, it injects the relevant project files into context before the agent responds. You stop re-explaining what you're working on every session.

See `context-loader/install.md` for the full install walkthrough.

The short version:

1. Copy `auto-context-load.sh` and `project-keywords.json` somewhere in your project
2. `chmod +x auto-context-load.sh`
3. Add the hook to `.claude/settings.json`
4. Populate `project-keywords.json` with your project's keywords and file paths

See `examples/sample-project-keywords.json` for a filled-out example.

## The critical-rules template

`rules/post-compact-critical.md.template` is a starting point for your own post-compaction rules file. When Claude Code compresses a long session, most conversation history is lost. Files you wire into your project settings survive. Use this template to capture rules that must hold no matter how far into a session you are: database invariants, code style rules, known footguns, verification requirements.

## Notes

The honesty ledger pattern used by Lyra and Newton is deliberate. Every response ends with a structured accounting of what changed, what didn't, what was noticed but not fixed, and what's still uncertain. This keeps you informed even when you're moving fast.

The agent separation (Iris designs, Lyra builds, Echo scouts, Newton researches, Hypatia critiques) reflects a principle: each agent does one job and does it well, rather than one generalist agent that does everything at average quality. You can compose them — have Echo find the files, Newton research the approach, Hypatia challenge it, and Lyra implement it.

---

MIT License. See LICENSE file.
