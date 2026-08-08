#!/usr/bin/env bash
# Thin Claude Code hook wrapper for the Python standard-library loader.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PYTHON_BIN=""
for candidate in "${OPERATOR_KIT_PYTHON:-}" python3 python; do
  [ -n "$candidate" ] || continue
  command -v "$candidate" >/dev/null 2>&1 || continue
  if "$candidate" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 8) else 1)' >/dev/null 2>&1; then
    PYTHON_BIN="$candidate"
    break
  fi
done

[ -n "$PYTHON_BIN" ] || exit 0
exec "$PYTHON_BIN" "$SCRIPT_DIR/context_loader.py"
