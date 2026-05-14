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

## Install steps

**1. Copy the files into your project**

Place these two files somewhere in your project (the context-loader directory is a good choice, or wherever you keep dev tooling):

```
your-project/
  context-loader/
    auto-context-load.sh
    project-keywords.json
```

**2. Make the script executable**

```bash
chmod +x auto-context-load.sh
```

**3. Set PROJECT_ROOT**

The script auto-detects its root from its own location (two levels up from the script). If your layout differs, set the env var explicitly in your shell profile:

```bash
export PROJECT_ROOT="/absolute/path/to/your-project"
```

Or pass it inline in the hook command (step 4).

**4. Wire it into Claude Code settings**

Open (or create) `.claude/settings.json` in your project root and add the hook:

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

Use an absolute path in the command — Claude Code's working directory may vary.

**5. Populate project-keywords.json**

Edit `project-keywords.json` to map your project's trigger words to relevant files. See `examples/sample-project-keywords.json` for a filled-out example.

Each entry follows this shape:

```json
"entry_key": {
  "keywords": ["trigger word", "alternate phrase"],
  "priority_file": "relative/path/to/main-doc.md",
  "files": [
    "relative/path/to/main-doc.md",
    "relative/path/to/related-doc.md"
  ]
}
```

Paths are relative to `PROJECT_ROOT`.

**6. Test it**

Open a new Claude Code session in your project. Type a prompt containing one of your keywords. You should see an `[AUTO-CONTEXT]` block appear before Claude's response.

The hook also logs every fire to `memory/.auto-context-log` in your project root — useful for verifying it's working and seeing what got surfaced.

## Limits

- Total context injected per prompt: ~80KB / 3000 lines across all matched keywords
- Per priority file: first 40 lines excerpted
- If the keywords file is missing or python3 is unavailable, the hook exits silently

## Troubleshooting

**Hook never fires:** Check that the path in settings.json is absolute and the script is executable.

**"python3 not found":** Install Python 3 or update the script to use `python` if that's your binary name.

**Wrong files surfacing:** Check your keyword strings — matching is case-insensitive substring, so "auth" will also match "authentication" and "reauth".

**Windows path issues:** The script normalizes `/c/Users/...` Git Bash paths to `C:/Users/...` automatically. If you still get path errors, set `PROJECT_ROOT` explicitly as a Windows-style path in your shell profile.
