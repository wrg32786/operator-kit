#!/bin/bash
# auto-context-load.sh — project context injector
# UserPromptSubmit hook. Reads the prompt from stdin, matches against
# project-keywords.json, and injects <system-reminder> blocks with
# actual file contents into context BEFORE the agent responds.
#
# This solves the "ask instead of read" failure mode: passive hints don't
# fire; injected content does. The agent sees the project files, not a hint.
#
# Convention:
#   - Reads prompt from stdin (Claude Code UserPromptSubmit hook convention)
#   - PROJECT_ROOT env var or auto-detected from script location
#   - Output: system-reminder blocks to stdout. Silent if no match.
#   - Total output capped at ~80KB / 3000 lines across all matches
#   - Logs every fire to <project-root>/memory/.auto-context-log
#   - Uses python3 for JSON parsing (no jq dependency)

ROOT="${PROJECT_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
DAEMON_ERR_LOG="$ROOT/memory/.daemon-errors.log"

# Windows Git-Bash: /c/Users/... -> C:/Users/...
normalize_path() {
  local p="$1"
  if [[ "$p" =~ ^/([a-zA-Z])/(.*) ]]; then
    echo "${BASH_REMATCH[1]^^}:/${BASH_REMATCH[2]}"
  else
    echo "$p"
  fi
}

ROOT=$(normalize_path "$ROOT")
KEYWORDS_FILE="$ROOT/context-loader/project-keywords.json"
LOG_FILE="$ROOT/memory/.auto-context-log"

# Guards — python3 is required; keywords file must exist
[ -f "$KEYWORDS_FILE" ] || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

INPUT=$(cat 2>/dev/null)
[ -z "$INPUT" ] && exit 0

# Delegate everything to Python for JSON handling
PROMPT_LOWER=$(echo "$INPUT" | tr '[:upper:]' '[:lower:]')
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
PROMPT_SNIPPET=$(echo "$INPUT" | head -c 120 | tr '\n' ' ')

python3 - "$KEYWORDS_FILE" "$ROOT" "$PROMPT_LOWER" "$LOG_FILE" "$TIMESTAMP" "$PROMPT_SNIPPET" 2>>"$DAEMON_ERR_LOG" <<'PYEOF'
import sys, json, os

keywords_file = sys.argv[1]
root = sys.argv[2]
prompt_lower = sys.argv[3]
log_file = sys.argv[4]
timestamp = sys.argv[5]
prompt_snippet = sys.argv[6]

# Windows Git-Bash path normalization (Python-side)
def normalize(p):
    import re
    m = re.match(r'^/([a-zA-Z])/(.*)', p)
    if m:
        return m.group(1).upper() + ':/' + m.group(2)
    return p

root = normalize(root)

try:
    with open(keywords_file, encoding='utf-8') as f:
        keyword_dict = json.load(f)
except Exception:
    sys.exit(0)

MAX_LINES = 3000
MAX_BYTES = 81920
total_lines = 0
total_bytes = 0
matched_keys = []
matched_display_kws = []

for entry_key, entry in keyword_dict.items():
    if entry_key == '_comment':
        continue
    if not isinstance(entry, dict):
        continue
    for kw in entry.get('keywords', []):
        if kw.lower() in prompt_lower:
            matched_keys.append(entry_key)
            matched_display_kws.append(kw)
            break

if not matched_keys:
    sys.exit(0)

output_blocks = []
files_surfaced = []

for entry_key in matched_keys:
    if total_lines >= MAX_LINES or total_bytes >= MAX_BYTES:
        break
    entry = keyword_dict[entry_key]
    priority_file_rel = entry.get('priority_file', '')
    files_rel = entry.get('files', [])

    # Build file listing
    file_list_lines = []
    for rel in files_rel:
        abs_path = os.path.join(root, rel.replace('/', os.sep))
        if os.path.isfile(abs_path):
            file_list_lines.append(f'- {rel}')
            files_surfaced.append(rel)
        else:
            file_list_lines.append(f'- {rel} (not found)')

    # Read priority file excerpt
    priority_abs = os.path.join(root, priority_file_rel.replace('/', os.sep))
    if os.path.isfile(priority_abs):
        try:
            with open(priority_abs, encoding='utf-8', errors='replace') as f:
                excerpt_lines = [f.readline().rstrip('\n') for _ in range(40)]
            excerpt = '\n'.join(l for l in excerpt_lines if l is not None)
        except Exception:
            excerpt = '(could not read file)'
    else:
        excerpt = f'(file not found: {priority_file_rel})'

    block = (
        f'[AUTO-CONTEXT] keyword={entry_key}\n'
        f'Project files for this topic:\n'
        + '\n'.join(file_list_lines) +
        f'\n\nPriority file excerpt — {priority_file_rel} (first 40 lines):\n'
        f'{excerpt}\n'
    )

    block_lines = block.count('\n')
    block_bytes = len(block.encode('utf-8'))
    total_lines += block_lines
    total_bytes += block_bytes
    output_blocks.append(block)

# Emit to stdout
for block in output_blocks:
    print(block, end='')

# Log the fire
try:
    os.makedirs(os.path.dirname(log_file), exist_ok=True)
    with open(log_file, 'a', encoding='utf-8') as f:
        f.write('---\n')
        f.write(f'ts={timestamp}\n')
        f.write(f'prompt_snippet={prompt_snippet}\n')
        f.write(f'keywords_matched={", ".join(matched_display_kws)}\n')
        f.write(f'files_surfaced={", ".join(files_surfaced)}\n')
        f.write(f'lines_emitted={total_lines} bytes_emitted={total_bytes}\n')
except Exception:
    pass

PYEOF

exit 0
