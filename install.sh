#!/usr/bin/env bash
# Legacy user-scope installer for AIgent Operator Kit.
# Recommended for new installs: use the Claude Code plugin marketplace.

set -euo pipefail

REPO_URL="https://github.com/wrg32786/operator-kit.git"
RAW_URL="https://raw.githubusercontent.com/wrg32786/operator-kit/main"
TMP_DIR=""
STAMP="$(date -u +%Y%m%d-%H%M%S)-$$"

cleanup() {
  [ -n "$TMP_DIR" ] && rm -rf "$TMP_DIR"
  return 0
}
trap cleanup EXIT

if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  SCRIPT_DIR=""
fi

if [ -n "$SCRIPT_DIR" ] \
  && [ -d "$SCRIPT_DIR/agents" ] \
  && [ -f "$SCRIPT_DIR/context-loader/auto-context-load.sh" ] \
  && [ -f "$SCRIPT_DIR/context-loader/context_loader.py" ] \
  && [ -f "$SCRIPT_DIR/install.sh" ]; then
  SRC="$SCRIPT_DIR"
else
  TMP_DIR="$(mktemp -d)"
  SRC="$TMP_DIR/operator-kit"
  printf '[operator-kit] Fetching source files...\n'

  if command -v git >/dev/null 2>&1; then
    git clone --depth 1 "$REPO_URL" "$SRC"
  else
    command -v curl >/dev/null 2>&1 || {
      printf '[operator-kit] ERROR: git or curl is required to fetch the kit.\n' >&2
      exit 1
    }
    mkdir -p "$SRC/agents" "$SRC/context-loader" "$SRC/rules"
    for agent in echo hypatia iris lyra newton; do
      curl -fsSL "$RAW_URL/agents/$agent.md" -o "$SRC/agents/$agent.md"
    done
    curl -fsSL "$RAW_URL/context-loader/auto-context-load.sh" \
      -o "$SRC/context-loader/auto-context-load.sh"
    curl -fsSL "$RAW_URL/context-loader/context_loader.py" \
      -o "$SRC/context-loader/context_loader.py"
    curl -fsSL "$RAW_URL/context-loader/project-keywords.json" \
      -o "$SRC/context-loader/project-keywords.json"
    curl -fsSL "$RAW_URL/rules/post-compact-critical.md.template" \
      -o "$SRC/rules/post-compact-critical.md.template"
  fi
fi

CLAUDE_DIR="$HOME/.claude"
AGENTS_DEST="$CLAUDE_DIR/agents/operator-kit"
HOOK_DEST="$CLAUDE_DIR/hooks/operator-kit"
SETTINGS="$CLAUDE_DIR/settings.json"
KEYWORDS_DEST="$CLAUDE_DIR/operator-kit-keywords.json"
LEGACY_KEYWORDS="$CLAUDE_DIR/hooks/operator-kit-keywords.json"
HOOK_PATH="$HOOK_DEST/auto-context-load.sh"
LEGACY_HOOK_PATH="$CLAUDE_DIR/hooks/auto-context-load.sh"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
RESET='\033[0m'

info() { printf '%b[operator-kit]%b %s\n' "$GREEN" "$RESET" "$*"; }
warn() { printf '%b[operator-kit]%b %s\n' "$YELLOW" "$RESET" "$*"; }
fail() { printf '%b[operator-kit] ERROR:%b %s\n' "$RED" "$RESET" "$*" >&2; }

PYTHON_BIN=""
for candidate in "${OPERATOR_KIT_PYTHON:-}" python3 python; do
  [ -n "$candidate" ] || continue
  command -v "$candidate" >/dev/null 2>&1 || continue
  if "$candidate" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 8) else 1)' >/dev/null 2>&1; then
    PYTHON_BIN="$candidate"
    break
  fi
done

# Validate settings before touching the installation. Invalid JSON must remain untouched.
if [ -n "$PYTHON_BIN" ] && [ -f "$SETTINGS" ]; then
  if ! "$PYTHON_BIN" - "$SETTINGS" <<'PYEOF'
import json
import sys

path = sys.argv[1]
try:
    with open(path, encoding="utf-8") as handle:
        data = json.load(handle)
except json.JSONDecodeError as exc:
    print(f"settings.json is invalid JSON at line {exc.lineno}, column {exc.colno}: {exc.msg}", file=sys.stderr)
    raise SystemExit(1)

if not isinstance(data, dict):
    print("settings.json must contain a JSON object", file=sys.stderr)
    raise SystemExit(1)

hooks = data.get("hooks", {})
if not isinstance(hooks, dict):
    print("settings.json field 'hooks' must be an object", file=sys.stderr)
    raise SystemExit(1)

entries = hooks.get("UserPromptSubmit", [])
if not isinstance(entries, list):
    print("settings.json field 'hooks.UserPromptSubmit' must be an array", file=sys.stderr)
    raise SystemExit(1)
PYEOF
  then
    fail "Refusing to modify invalid $SETTINGS. Fix it first; no files were installed."
    exit 1
  fi
fi

info "Installing five agents"
mkdir -p "$(dirname "$AGENTS_DEST")"
if [ -d "$AGENTS_DEST" ] && ! diff -qr "$SRC/agents" "$AGENTS_DEST" >/dev/null 2>&1; then
  AGENTS_BACKUP="${AGENTS_DEST}.backup-$STAMP"
  cp -R "$AGENTS_DEST" "$AGENTS_BACKUP"
  warn "Backed up customized agents to $AGENTS_BACKUP"
fi
mkdir -p "$AGENTS_DEST"
for file in "$SRC"/agents/*.md; do
  cp "$file" "$AGENTS_DEST/"
done

if [ -z "$PYTHON_BIN" ]; then
  warn "Python 3.8+ was not found. Agents were installed; the optional context loader was skipped."
else
  info "Installing the optional context loader"
  HOOK_CHANGED=0
  for file in auto-context-load.sh context_loader.py; do
    if [ -f "$HOOK_DEST/$file" ] && ! cmp -s "$SRC/context-loader/$file" "$HOOK_DEST/$file"; then
      HOOK_CHANGED=1
    fi
  done
  if [ "$HOOK_CHANGED" -eq 1 ]; then
    HOOK_BACKUP="${HOOK_DEST}.backup-$STAMP"
    cp -R "$HOOK_DEST" "$HOOK_BACKUP"
    warn "Backed up the previous context loader to $HOOK_BACKUP"
  fi
  mkdir -p "$HOOK_DEST"
  cp "$SRC/context-loader/auto-context-load.sh" "$HOOK_PATH"
  cp "$SRC/context-loader/context_loader.py" "$HOOK_DEST/context_loader.py"
  chmod +x "$HOOK_PATH"

  if [ ! -f "$KEYWORDS_DEST" ]; then
    if [ -f "$LEGACY_KEYWORDS" ]; then
      cp "$LEGACY_KEYWORDS" "$KEYWORDS_DEST"
      info "Migrated the existing keywords file to $KEYWORDS_DEST"
    else
      cp "$SRC/context-loader/project-keywords.json" "$KEYWORDS_DEST"
      info "Created the starter keywords file at $KEYWORDS_DEST"
    fi
  else
    info "Kept the existing keywords file at $KEYWORDS_DEST"
  fi

  info "Wiring the UserPromptSubmit hook"
  "$PYTHON_BIN" - "$SETTINGS" "$HOOK_PATH" "$LEGACY_HOOK_PATH" "$STAMP" <<'PYEOF'
import json
import os
import shutil
import sys
import tempfile

settings_path, hook_path, legacy_hook_path, stamp = sys.argv[1:]
if os.path.islink(settings_path):
    settings_path = os.path.realpath(settings_path)

if os.path.isfile(settings_path):
    with open(settings_path, encoding="utf-8") as handle:
        settings = json.load(handle)
else:
    settings = {}

hooks = settings.setdefault("hooks", {})
entries = hooks.setdefault("UserPromptSubmit", [])

legacy_commands = {
    f"bash {hook_path}",
    f"bash {legacy_hook_path}",
    hook_path,
    legacy_hook_path,
}


def is_operator_hook(hook):
    if not isinstance(hook, dict):
        return False
    command = hook.get("command")
    args = hook.get("args")
    if command in legacy_commands:
        return True
    return (
        command == "bash"
        and isinstance(args, list)
        and len(args) == 1
        and args[0] in {hook_path, legacy_hook_path}
    )


cleaned_entries = []
for entry in entries:
    if not isinstance(entry, dict):
        cleaned_entries.append(entry)
        continue
    inner = entry.get("hooks")
    if not isinstance(inner, list):
        cleaned_entries.append(entry)
        continue
    remaining = [hook for hook in inner if not is_operator_hook(hook)]
    if remaining:
        updated = dict(entry)
        updated["hooks"] = remaining
        cleaned_entries.append(updated)

cleaned_entries.append(
    {
        "hooks": [
            {
                "type": "command",
                "command": "bash",
                "args": [hook_path],
            }
        ]
    }
)

updated_settings = dict(settings)
updated_hooks = dict(hooks)
updated_hooks["UserPromptSubmit"] = cleaned_entries
updated_settings["hooks"] = updated_hooks

if updated_settings == settings:
    print("[operator-kit] Hook already wired")
    raise SystemExit(0)

os.makedirs(os.path.dirname(settings_path), exist_ok=True)
if os.path.isfile(settings_path):
    backup = f"{settings_path}.backup-{stamp}"
    shutil.copy2(settings_path, backup)
    print(f"[operator-kit] Backed up settings to {backup}")

fd, temp_path = tempfile.mkstemp(prefix="settings.", suffix=".tmp", dir=os.path.dirname(settings_path))
try:
    with os.fdopen(fd, "w", encoding="utf-8") as handle:
        json.dump(updated_settings, handle, indent=2)
        handle.write("\n")
    if os.path.isfile(settings_path):
        shutil.copymode(settings_path, temp_path)
    os.replace(temp_path, settings_path)
finally:
    if os.path.exists(temp_path):
        os.unlink(temp_path)

print("[operator-kit] Hook wired")
PYEOF
fi

info "Critical-rules template"
RULES_SOURCE="$SRC/rules/post-compact-critical.md.template"
RULES_TARGET="./.claude/rules/critical.md"
INSTALL_RULES="${OPERATOR_KIT_INSTALL_RULES:-}"

if [ "$INSTALL_RULES" = "1" ]; then
  answer="y"
elif [ "$INSTALL_RULES" = "0" ]; then
  answer="n"
elif [ -r /dev/tty ] && [ -w /dev/tty ]; then
  printf '\nCopy the critical-rules template to %s? [y/N] ' "$RULES_TARGET" >/dev/tty
  read -r answer </dev/tty || answer="n"
else
  answer="n"
fi

case "$answer" in
  [Yy]*)
    if [ -e "$RULES_TARGET" ]; then
      warn "Kept the existing $RULES_TARGET"
    else
      mkdir -p "$(dirname "$RULES_TARGET")"
      cp "$RULES_SOURCE" "$RULES_TARGET"
      info "Created $RULES_TARGET"
    fi
    ;;
  *)
    info "Skipped. Copy later with: mkdir -p .claude/rules && curl -fsSL '$RAW_URL/rules/post-compact-critical.md.template' -o '$RULES_TARGET'"
    ;;
esac

printf '\n'
info "Installation complete"
info "Agents: $AGENTS_DEST"
if [ -n "$PYTHON_BIN" ]; then
  info "Context loader: $HOOK_PATH"
  info "Keywords: $KEYWORDS_DEST"
fi
info "Restart Claude Code, then invoke echo, hypatia, iris, lyra, or newton."
