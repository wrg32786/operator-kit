#!/usr/bin/env bash
# install.sh — operator-kit one-click installer
#
# Usage:
#   bash install.sh
#   curl -fsSL https://raw.githubusercontent.com/wrg32786/operator-kit/main/install.sh | bash
#
# What it does:
#   1. Backs up ~/.claude/settings.json -> ~/.claude/settings.json.bak
#   2. Copies agents/*.md to ~/.claude/agents/operator-kit/
#   3. Copies context-loader/auto-context-load.sh to ~/.claude/hooks/ (chmod +x)
#   4. Wires the UserPromptSubmit hook into settings.json (idempotent — no duplicate adds)
#   5. Places project-keywords.json at ~/.claude/hooks/operator-kit-keywords.json
#   6. Offers to place the rules template into your current project
#   7. Prints success + restart reminder
#
# Idempotent: safe to run multiple times. Never clobbers existing hooks.
# Requires: bash, python3 (for JSON merge fallback). jq is used when available.

set -euo pipefail

# ── resolve source directory ──────────────────────────────────────────────────
# When run as `bash install.sh` from a local clone, BASH_SOURCE[0] points to
# the script file and REPO_DIR contains agents/, context-loader/, rules/.
# When run via `curl … | bash`, the script is piped through stdin — BASH_SOURCE[0]
# is empty or "bash", so REPO_DIR resolves to the caller's CWD (no source files).
# In that case we self-fetch the repo into a temp directory.
# Only trust BASH_SOURCE as a clone path when it points to a REAL readable file.
# When piped via curl|bash it is "bash"/empty, so this leaves _SCRIPT_DIR empty
# and forces self-fetch — without this guard, running the one-liner from any dir
# that happens to contain an agents/ folder copies the wrong files (live-QA catch).
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  _SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  _SCRIPT_DIR=""
fi
REPO_URL="https://github.com/wrg32786/operator-kit.git"
_TMPDIR=""

# Cleanup temp dir on exit (no-op if we never created one).
# Explicitly return 0 so the trap never overrides a successful script exit code.
_cleanup() { [ -n "$_TMPDIR" ] && rm -rf "$_TMPDIR"; return 0; }
trap _cleanup EXIT

if [ -n "$_SCRIPT_DIR" ] && [ -d "$_SCRIPT_DIR/agents" ] && [ -d "$_SCRIPT_DIR/context-loader" ] && [ -f "$_SCRIPT_DIR/install.sh" ]; then
  # Running from a genuine local clone (dir is actually operator-kit) — use in place
  SRC="$_SCRIPT_DIR"
else
  # Piped via curl|bash (or run from a directory without the repo files).
  # Self-fetch the repo so we have the source files to copy.
  echo "[operator-kit] curl|bash mode detected — fetching source files..."
  _TMPDIR="$(mktemp -d)"
  SRC="$_TMPDIR/operator-kit"

  if command -v git >/dev/null 2>&1; then
    git clone --depth 1 "$REPO_URL" "$SRC"
  else
    # Fallback: git not available — curl each file individually.
    echo "[operator-kit] git not found, downloading files via curl..."
    RAW="https://raw.githubusercontent.com/wrg32786/operator-kit/main"
    mkdir -p \
      "$SRC/agents" \
      "$SRC/context-loader" \
      "$SRC/rules"
    # agents
    for agent in echo hypatia iris lyra newton; do
      curl -fsSL "$RAW/agents/$agent.md" -o "$SRC/agents/$agent.md"
    done
    # context-loader
    curl -fsSL "$RAW/context-loader/auto-context-load.sh" \
      -o "$SRC/context-loader/auto-context-load.sh"
    curl -fsSL "$RAW/context-loader/project-keywords.json" \
      -o "$SRC/context-loader/project-keywords.json"
    # rules template
    curl -fsSL "$RAW/rules/post-compact-critical.md.template" \
      -o "$SRC/rules/post-compact-critical.md.template"
  fi
fi

CLAUDE_DIR="$HOME/.claude"
AGENTS_DEST="$CLAUDE_DIR/agents/operator-kit"
HOOKS_DEST="$CLAUDE_DIR/hooks"
SETTINGS="$CLAUDE_DIR/settings.json"
# Use explicit 'bash' — Claude Code's hook runner uses bash regardless of $SHELL
HOOK_CMD="bash $HOOKS_DEST/auto-context-load.sh"

# ── colours ──────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()    { echo -e "${GREEN}[operator-kit]${NC} $*"; }
warn()    { echo -e "${YELLOW}[operator-kit]${NC} $*"; }
err()     { echo -e "${RED}[operator-kit]${NC} $*" >&2; }

# ── step 1: backup settings.json ─────────────────────────────────────────────
info "Step 1/5 — Backing up settings.json"
mkdir -p "$CLAUDE_DIR"
if [ -f "$SETTINGS" ]; then
  cp "$SETTINGS" "${SETTINGS}.bak"
  info "  Backup written to ${SETTINGS}.bak"
else
  info "  settings.json does not exist yet — will create it"
fi

# ── step 2: copy agents ──────────────────────────────────────────────────────
info "Step 2/5 — Installing agents to $AGENTS_DEST"
mkdir -p "$AGENTS_DEST"
for f in "$SRC"/agents/*.md; do
  cp "$f" "$AGENTS_DEST/"
  info "  Installed $(basename "$f")"
done

# ── step 3: install hook script ──────────────────────────────────────────────
info "Step 3/5 — Installing context-loader hook"
mkdir -p "$HOOKS_DEST"
cp "$SRC/context-loader/auto-context-load.sh" "$HOOKS_DEST/auto-context-load.sh"
chmod +x "$HOOKS_DEST/auto-context-load.sh"
info "  Installed auto-context-load.sh (executable)"

# ── step 3b: place keywords template ─────────────────────────────────────────
KEYWORDS_DEST="$HOOKS_DEST/operator-kit-keywords.json"
if [ ! -f "$KEYWORDS_DEST" ]; then
  cp "$SRC/context-loader/project-keywords.json" "$KEYWORDS_DEST"
  info "  Placed starter project-keywords.json at $KEYWORDS_DEST"
else
  info "  Skipped keywords.json (already exists at $KEYWORDS_DEST)"
fi

# ── step 4: wire UserPromptSubmit hook into settings.json ────────────────────
info "Step 4/5 — Wiring UserPromptSubmit hook"

# The hook entry we want to add
HOOK_ENTRY='{"matcher":"*","hooks":[{"type":"command","command":"'"$HOOK_CMD"'"}]}'

wire_with_jq() {
  # Idempotency guard: is our command already present?
  if jq -e --arg cmd "$HOOK_CMD" \
    '.hooks.UserPromptSubmit // [] | map(.hooks // [] | map(.command) | any(. == $cmd)) | any' \
    "$SETTINGS" > /dev/null 2>&1; then
    warn "  Hook already wired (idempotent — skipped duplicate add)"
    return 0
  fi

  # Merge: append entry to hooks.UserPromptSubmit array (create path if missing)
  local tmp
  tmp=$(mktemp)
  jq --argjson entry "$HOOK_ENTRY" '
    .hooks.UserPromptSubmit = ((.hooks.UserPromptSubmit // []) + [$entry])
  ' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
  info "  Hook wired via jq"
}

wire_with_python() {
  python3 - "$SETTINGS" "$HOOK_ENTRY" "$HOOK_CMD" <<'PYEOF'
import sys, json, os, shutil

settings_path = sys.argv[1]
hook_entry_str = sys.argv[2]
hook_cmd = sys.argv[3]

# Load or initialize
if os.path.isfile(settings_path):
    with open(settings_path, encoding='utf-8') as f:
        try:
            settings = json.load(f)
        except json.JSONDecodeError:
            print("[operator-kit] WARNING: settings.json is not valid JSON — creating fresh",
                  file=sys.stderr)
            settings = {}
else:
    settings = {}

# Ensure hooks structure exists
if 'hooks' not in settings:
    settings['hooks'] = {}
if 'UserPromptSubmit' not in settings['hooks']:
    settings['hooks']['UserPromptSubmit'] = []

# Idempotency check: is the command already present?
for entry in settings['hooks']['UserPromptSubmit']:
    for hook in entry.get('hooks', []):
        if hook.get('command') == hook_cmd:
            print("[operator-kit] Hook already wired (idempotent — skipped duplicate add)")
            sys.exit(0)

# Add the new hook entry
hook_entry = json.loads(hook_entry_str)
settings['hooks']['UserPromptSubmit'].append(hook_entry)

# Write atomically via temp file
tmp = settings_path + '.tmp'
with open(tmp, 'w', encoding='utf-8') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')
shutil.move(tmp, settings_path)
print("[operator-kit] Hook wired via python3")
PYEOF
}

# Initialise settings.json if missing
if [ ! -f "$SETTINGS" ]; then
  echo '{}' > "$SETTINGS"
fi

if command -v jq >/dev/null 2>&1; then
  wire_with_jq
elif command -v python3 >/dev/null 2>&1; then
  wire_with_python
else
  err "  Neither jq nor python3 found. Add the hook manually:"
  echo ""
  echo "  Open $SETTINGS and add under hooks.UserPromptSubmit:"
  echo "  $HOOK_ENTRY"
  echo ""
  warn "  All other steps completed. Only the settings.json wire is missing."
fi

# ── step 5: offer rules template ─────────────────────────────────────────────
info "Step 5/5 — Rules template"
RULES_TEMPLATE="$SRC/rules/post-compact-critical.md.template"

# Bug 2 fix: never read from stdin when stdin IS the script (curl|bash mode).
# Read from /dev/tty (the real terminal) only when it is genuinely accessible.
# We probe with a subshell so any open/tty failure can't abort the main script
# (set -e applies inside subshells but the exit code is just used as a boolean).
# Fall back to "n" — the else branch prints the manual cp command.
yn="n"
_tty_available() { exec </dev/tty && tty -s; }
if ( _tty_available ) 2>/dev/null; then
  echo ""
  warn "Optional: copy the post-compact rules template into your current project?"
  warn "  Source: $RULES_TEMPLATE"
  warn "  Target: ./rules/post-compact-critical.md  (in current directory)"
  read -r -p "  Copy it? [y/N] " yn </dev/tty
fi

case "$yn" in
  [Yy]*)
    mkdir -p ./rules
    cp "$RULES_TEMPLATE" ./rules/post-compact-critical.md
    info "  Copied. Add '@rules/post-compact-critical.md' to your CLAUDE.md to wire it."
    ;;
  *)
    info "  Skipped. Copy manually later:"
    info "  cp $RULES_TEMPLATE ./rules/post-compact-critical.md"
    ;;
esac

# ── done ─────────────────────────────────────────────────────────────────────
echo ""
info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
info "operator-kit installed successfully."
info ""
info "Agents available:  echo, hypatia, iris, lyra, newton"
info "Context loader:    $HOOKS_DEST/auto-context-load.sh"
info "Keywords file:     $KEYWORDS_DEST"
info ""
info "Next steps:"
info "  1. Edit $KEYWORDS_DEST to map your project's trigger words to files"
info "  2. Restart Claude Code — hooks take effect on next launch"
info "  3. Type a keyword in a prompt to verify the context loader fires"
info "     (check the [AUTO-CONTEXT] block before Claude's response)"
info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
