# Context Loader — Install Guide

The context loader is a UserPromptSubmit hook for Claude Code. When you mention a keyword in your prompt, it automatically injects the relevant project files into context before the agent responds. No more re-explaining what you're working on every session.

## What it does

1. You mention "auth flow" or "payments" or whatever keyword you configure
2. The hook fires before Claude responds
3. Claude sees a context block with your relevant files already loaded
4. Claude answers with full project knowledge, not blank-slate guessing

This is structural enforcement, not a memory note. It fires every time, not just when you remember to mention it.

## Prerequisites

- Claude Code installed and working
- `python3` available on your PATH (used for JSON parsing)
- Git Bash or WSL if you're on Windows (the hook is a bash script)

## One-line install behavior

The main installer places the hook and starter keywords file here:

```text
~/.claude/hooks/auto-context-load.sh
~/.claude/hooks/operator-kit-keywords.json
```

After installing, edit:

```bash
~/.claude/hooks/operator-kit-keywords.json
```

Add keywords and project files relative to the Claude Code workspace you launch from. Example:

```json
"auth": {
  "keywords": ["auth", "login", "session"],
  "priority_file": "docs/auth.md",
  "files": [
    "docs/auth.md",
    "src/lib/session.ts"
  ]
}
```

If your hook runner does not use your project directory as its working directory, set `PROJECT_ROOT` explicitly:

```bash
export PROJECT_ROOT="/absolute/path/to/your-project"
```

You can also point the hook at a different keywords file:

```bash
export OPERATOR_KIT_KEYWORDS="/absolute/path/to/operator-kit-keywords.json"
```

## Manual project-local install

If you prefer to keep the hook inside a single project, place these two files in your repo:

```text
your-project/
  context-loader/
    auto-context-load.sh
    project-keywords.json
```

Then make the script executable:

```bash
chmod +x context-loader/auto-context-load.sh
```

Open or create `.claude/settings.json` in your project root and add the hook:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash /absolute/path/to/your-project/context-loader/auto-context-load.sh"
          }
        ]
      }
    ]
  }
}
```

Use an absolute path in the command. Claude Code's working directory can vary.

## Keywords file resolution order

The hook looks for keywords in this order:

1. `OPERATOR_KIT_KEYWORDS`, if set
2. `~/.claude/hooks/operator-kit-keywords.json`, the one-line install default
3. `operator-kit-keywords.json` next to the hook script
4. `<PROJECT_ROOT>/context-loader/project-keywords.json`, the project-local fallback

Paths inside the keywords file are resolved relative to `PROJECT_ROOT`, or the current Claude Code workspace if `PROJECT_ROOT` is not set.

## Test it

Open a new Claude Code session in your project. Type a prompt containing one of your keywords. You should see an `[AUTO-CONTEXT]` block appear before Claude's response.

The hook also logs every fire to `memory/.auto-context-log` in your project root — useful for verifying it's working and seeing what got surfaced.

## Limits

- Total context injected per prompt: ~80KB / 3000 lines across all matched keywords
- Per priority file: first 40 lines excerpted
- If the keywords file is missing or python3 is unavailable, the hook exits silently

## Troubleshooting

**Hook never fires:** Confirm `~/.claude/hooks/operator-kit-keywords.json` exists, contains a keyword from your prompt, and the script is executable.

**Files show as not found:** Set `PROJECT_ROOT` to your project path, or launch Claude Code from the project root.

**"python3 not found":** Install Python 3 or update the script to use `python` if that's your binary name.

**Wrong files surfacing:** Check your keyword strings — matching is case-insensitive substring, so "auth" will also match "authentication" and "reauth".

**Windows path issues:** The script normalizes `/c/Users/...` Git Bash paths to `C:/Users/...` automatically. If you still get path errors, set `PROJECT_ROOT` explicitly as a Windows-style path in your shell profile.
