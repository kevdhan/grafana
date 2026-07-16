#!/usr/bin/env bash
# afterFileEdit hook: auto-format edited Grafana frontend files with Prettier.
# Only touches public/app source files. Fails open so a formatting hiccup never
# blocks the agent.
set -uo pipefail

INPUT_JSON="$(cat)"

# Pull the edited file path from the hook payload (tolerate key-name variations).
FILE="$(python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    print(""); sys.exit(0)
for k in ("file_path", "filePath", "path"):
    v = d.get(k)
    if isinstance(v, str) and v:
        print(v); sys.exit(0)
e = d.get("edit") or {}
print(e.get("file_path", "") if isinstance(e, dict) else "")
' <<< "$INPUT_JSON" 2>/dev/null || true)"

# Only format frontend source files (matches both relative and absolute paths).
case "$FILE" in
  *public/app/*.ts|*public/app/*.tsx|*public/app/*.scss) ;;
  *) printf '%s\n' '{}'; exit 0 ;;
esac

if [ -x node_modules/.bin/prettier ] && [ -f "$FILE" ]; then
  node_modules/.bin/prettier --write "$FILE" >/dev/null 2>&1 || true
fi

printf '%s\n' '{}'
exit 0
