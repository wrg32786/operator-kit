# Context Loader — Install and Configure

The context loader is an optional Claude Code `UserPromptSubmit` hook. When the submitted prompt contains a configured whole word or phrase, it adds two things before Claude responds:

1. The first 40 lines of one priority file.
2. A map of other relevant project paths Claude should read before making claims or changes.

It does not dump every configured file into the context window.

## Recommended: install the plugin

```text
/plugin marketplace add wrg32786/operator-kit
/plugin install operator-kit@operator-kit
```

The plugin includes the hook. It remains silent until a keywords file exists. Use the plugin or the legacy user-scope installer, not both.

Create a project-local mapping:

```bash
mkdir -p .claude
cp examples/sample-project-keywords.json .claude/operator-kit-keywords.json
```

Then replace the sample paths with paths from the current project:

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

Paths must be relative to the Claude Code project root. Absolute paths and paths that escape the project with `..` are rejected.

## Legacy user-scope installer

The root `install.sh` installs the agents and hook under `~/.claude/`. It stores the default user mapping at:

```text
~/.claude/operator-kit-keywords.json
```

Project-local configuration takes precedence over the user-level fallback.

## Resolution order

The loader searches for its mapping in this order:

1. `OPERATOR_KIT_KEYWORDS`, when explicitly set.
2. `<project>/.claude/operator-kit-keywords.json`.
3. `<project>/context-loader/project-keywords.json` for legacy project-local installs.
4. `~/.claude/operator-kit-keywords.json`.
5. `~/.claude/hooks/operator-kit-keywords.json` for legacy user installs.

The project root is resolved from `PROJECT_ROOT`, then the hook payload's `cwd`, then `CLAUDE_PROJECT_DIR`, then the process working directory.

## Test it

Start a new Claude Code session in the configured project and submit a prompt containing one of the trigger phrases. The hook should add an `<operator-kit-context>` block before the response.

Matching is case-insensitive and boundary-aware. A trigger of `auth` matches `auth` but not `reauthenticate`.

## Limits and privacy

- Maximum output per prompt: 80 KiB or 3,000 lines.
- Maximum priority excerpt: 40 lines per matched topic.
- Missing Python, invalid JSON, or no match causes a silent no-op.
- The loader does not write into the project.
- Debug logging is off by default. Set `OPERATOR_KIT_DEBUG=1` to write non-prompt diagnostic metadata under `~/.claude/logs/operator-kit/`.

## Troubleshooting

**Hook never fires:** Confirm the mapping exists, contains a phrase from the submitted prompt, and points at files relative to the correct project root.

**Files show as not found:** Launch Claude Code from the project, or set `PROJECT_ROOT=/absolute/path/to/project`.

**Python is unavailable:** Install Python 3.8 or newer, set `OPERATOR_KIT_PYTHON` to a compatible Python executable, or use only the five agents.

**Wrong topic fires:** Use a more specific phrase. Avoid broad triggers such as `db`, `ci`, or `cd`.

**Need diagnostics:** Set `OPERATOR_KIT_DEBUG=1`, reproduce once, and inspect `~/.claude/logs/operator-kit/context-loader.log`.
