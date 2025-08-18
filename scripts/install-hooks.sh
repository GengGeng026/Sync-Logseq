#!/bin/bash
set -e
HOOK_SRC="$(dirname "$0")/../.githooks/pre-commit"
HOOK_DEST="$(dirname "$0")/../.git/hooks/pre-commit"
if [ -f "$HOOK_SRC" ]; then
  cp "$HOOK_SRC" "$HOOK_DEST"
  chmod +x "$HOOK_DEST"
  echo "installed pre-commit hook"
else
  echo "no .githooks/pre-commit found; ensure you place hook template there"
fi
