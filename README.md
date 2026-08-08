<div align="center">

<img src="assets/hero.gif" alt="Five operator-kit agents delegating inside a terminal: Lyra hands a spec to Iris, Newton runs a research sweep, Hypatia flags a risk" width="760">

# AIgent Operator Kit

**Five focused Claude Code specialists. One small install.**

Echo maps, Newton researches, Hypatia challenges, Iris specifies, and Lyra builds. The optional context-loader hook adds a relevant file map and priority excerpt when your prompt mentions a configured project topic.

MIT licensed. The five agents are plain Markdown; the optional hook uses Bash and Python 3.8+.

</div>

## Install

### Recommended: Claude Code plugin

```text
/plugin marketplace add wrg32786/operator-kit
/plugin install operator-kit@operator-kit
```

Plugin agents are namespaced, for example `operator-kit:echo`. Use the plugin or the legacy installer, not both; an older user-scope install can leave duplicate hooks and unscoped agents in place. Restart Claude Code after installation, then invoke one naturally or with an agent mention:

```text
use operator-kit:echo to find every place we call the Stripe API
```

### Legacy user-scope install

```bash
curl -fsSL https://raw.githubusercontent.com/wrg32786/operator-kit/main/install.sh | bash
```

The legacy installer places unscoped agents under `~/.claude/agents/operator-kit/`, preserves existing configuration, backs up customized agent files before replacing them, and wires the optional hook only when Python 3.8+ is available.

Manual agents-only install:

```bash
mkdir -p ~/.claude/agents/operator-kit
cp agents/*.md ~/.claude/agents/operator-kit/
```

## The agents

| Agent | Job | Example task |
|---|---|---|
| **Echo** | Read-only codebase scout | “Echo, trace every caller of `createInvoice` and return paths and lines.” |
| **Newton** | Current, cited research | “Newton, compare Drizzle and Prisma for this schema using primary sources.” |
| **Hypatia** | Adversarial decision review | “Hypatia, find the strongest reason not to run this migration.” |
| **Iris** | Visual specification | “Iris, specify the dashboard empty state: hierarchy, type, spacing, and motion.” |
| **Lyra** | Bounded implementation | “Lyra, implement this accepted spec and run the smallest relevant check.” |

Compose them through the main Claude Code session:

```text
Echo maps the flow → Newton checks external constraints → Hypatia challenges the plan → Iris specifies the visual surface → Lyra implements and verifies
```

The boundaries are enforced in frontmatter, not just prose. Echo, Hypatia, and Iris receive only read tools. Newton receives read and web-research tools. Lyra alone receives write and shell tools.

## Context loader

The plugin includes a silent `UserPromptSubmit` hook. It does nothing until you add a keywords file.

Recommended project setup:

```bash
mkdir -p .claude
cp examples/sample-project-keywords.json .claude/operator-kit-keywords.json
```

Example entry:

```json
{
  "auth": {
    "keywords": ["authentication", "auth flow", "login", "session"],
    "priority_file": "docs/auth.md",
    "files": [
      "docs/auth.md",
      "src/lib/session.ts"
    ]
  }
}
```

When a submitted prompt contains one of those whole words or phrases, the hook adds:

- The first 40 lines of `priority_file`.
- A map of the configured project paths.
- An instruction to read the relevant paths before making claims or changes.

It matches only the submitted `prompt`, not hook metadata or directory names. Paths must remain inside the project root. The hook writes nothing into the project and debug logging is off by default.

Full configuration and troubleshooting: [`context-loader/install.md`](context-loader/install.md).

## Critical rules

`rules/post-compact-critical.md.template` is a starter for invariants that must survive long sessions and context compaction.

Copy it to Claude Code’s native project-rules directory:

```bash
mkdir -p .claude/rules
cp rules/post-compact-critical.md.template .claude/rules/critical.md
```

Use it for production/test boundaries, architectural invariants, known footguns, and required verification—not general documentation.

## Repository

```text
operator-kit/
├── .claude-plugin/  # plugin manifest + marketplace catalog
├── agents/          # echo · hypatia · iris · lyra · newton
├── context-loader/  # hook wrapper, standard-library loader, guide, starter config
├── examples/        # filled-out project keywords example
├── hooks/           # native plugin hook registration
├── rules/           # critical project-rules template
├── tests/           # one dependency-free smoke check
└── install.sh       # legacy user-scope installer
```

## Validate

```bash
python3 tests/smoke.py
claude plugin validate .
```

The smoke check validates agent schemas and tool boundaries, JSON and shell syntax, prompt-only keyword matching, path containment, no-write default behavior, invalid-settings protection, legacy-hook migration, and installer idempotency.

## License

MIT. See [LICENSE](LICENSE). The five agents are self-contained; the optional context loader uses only Python’s standard library.

---

<div align="center">

Built by **[The AIgent](https://theaigent.xyz)**. A weekly digest on running Claude Code at scale: **[theaigent.xyz](https://theaigent.xyz)**

Want the full operator system these agents run inside? **[aigent-OS](https://github.com/wrg32786/aigent-os)** — free and open source (MIT).

</div>
