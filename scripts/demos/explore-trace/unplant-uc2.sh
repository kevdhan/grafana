#!/usr/bin/env bash
# Remove the Use Case 2 planted bug files and restore GraphContainer.tsx.
# Called from explore-trace/reset.sh so untracked plant files do not leak onto main
# even when the operator skips --save-kit / --clean-untracked.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../_lib.sh
source "${SCRIPT_DIR}/../_lib.sh"

require_repo_root

GRAPH_DIR="${REPO_ROOT}/public/app/features/explore/Graph"
TARGET_TS="${GRAPH_DIR}/limitSeries.ts"
TARGET_TEST="${GRAPH_DIR}/limitSeries.test.ts"
GRAPH_CONTAINER="${GRAPH_DIR}/GraphContainer.tsx"

rm -f "${TARGET_TS}" "${TARGET_TEST}"
demo_log "Removed planted UC2 files (limitSeries.ts / limitSeries.test.ts)"

if [[ -f "${GRAPH_CONTAINER}" ]]; then
  # Restore to HEAD (demo branch or base — whichever is checked out). Safe no-op if clean.
  git restore --worktree --staged -- "${GRAPH_CONTAINER}" 2>/dev/null \
    || git checkout -- "${GRAPH_CONTAINER}" 2>/dev/null \
    || true
  demo_log "Restored GraphContainer.tsx from git"
fi
