#!/usr/bin/env bash
# Prepare a disposable demo branch for a Field Engineer customer demo.
#
# Usage:
#   ./scripts/demos/setup.sh <demo-id> [--force] [--from <base-branch>]
#
# Example:
#   ./scripts/demos/setup.sh explore-trace
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") <demo-id> [--force] [--from <base-branch>]

Creates (or recreates) local branch demo/<demo-id> from the base branch,
records state in .demo-state, and prints next steps for the agent/FE.

Known demo ids (folders under scripts/demos/):
$(list_known_demos | sed 's/^/  - /' || true)

Options:
  --force          Allow dirty working tree / recreate existing demo branch
  --from <branch>  Base branch (default: main)
  -h, --help       Show this help
EOF
}

DEMO_ID=""
FORCE=0
FROM_BRANCH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --force) FORCE=1; shift ;;
    --from)
      FROM_BRANCH="${2:-}"
      [[ -n "${FROM_BRANCH}" ]] || demo_die "--from requires a branch name"
      shift 2
      ;;
    -*)
      demo_die "Unknown flag: $1"
      ;;
    *)
      if [[ -z "${DEMO_ID}" ]]; then
        DEMO_ID="$1"
        shift
      else
        demo_die "Unexpected argument: $1"
      fi
      ;;
  esac
done

[[ -n "${DEMO_ID}" ]] || { usage; exit 1; }

require_repo_root
validate_demo_id "${DEMO_ID}"
ensure_clean_worktree "${FORCE}"

BASE="${FROM_BRANCH:-$(base_branch)}"
BRANCH="$(demo_branch_name "${DEMO_ID}")"

if [[ -f "${STATE_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${STATE_FILE}"
  if [[ "${FORCE}" != "1" ]]; then
    demo_die "Demo already active (${DEMO_ID:-unknown} on ${DEMO_BRANCH:-unknown}). Run reset.sh first, or pass --force."
  fi
  demo_warn "Overwriting existing demo state (was ${DEMO_ID:-?} / ${DEMO_BRANCH:-?})"
fi

demo_log "Fetching origin/${BASE} (best effort)…"
git fetch origin "${BASE}" 2>/dev/null || demo_warn "Could not fetch origin/${BASE}; using local refs"

if git show-ref --verify --quiet "refs/remotes/origin/${BASE}"; then
  START_REF="origin/${BASE}"
elif git show-ref --verify --quiet "refs/heads/${BASE}"; then
  START_REF="${BASE}"
else
  demo_die "Base branch '${BASE}' not found locally or on origin"
fi

if git show-ref --verify --quiet "refs/heads/${BRANCH}"; then
  if [[ "${FORCE}" == "1" ]]; then
    demo_log "Deleting existing local branch ${BRANCH}"
    if [[ "$(current_branch)" == "${BRANCH}" ]]; then
      git checkout "${BASE}" 2>/dev/null || git checkout -B "${BASE}" "${START_REF}"
    fi
    git branch -D "${BRANCH}"
  else
    demo_die "Branch ${BRANCH} already exists. Pass --force to recreate, or run reset.sh."
  fi
fi

demo_log "Creating ${BRANCH} from ${START_REF}"
git checkout -B "${BRANCH}" "${START_REF}"

write_state "${DEMO_ID}" "${BRANCH}" "${BASE}"

PROFILE_DIR="${DEMOS_ROOT}/${DEMO_ID}"
if [[ -d "${PROFILE_DIR}" ]]; then
  if [[ -x "${PROFILE_DIR}/setup.sh" ]]; then
    demo_log "Running demo-specific setup: ${PROFILE_DIR}/setup.sh"
    "${PROFILE_DIR}/setup.sh"
  elif [[ -f "${PROFILE_DIR}/setup.sh" ]]; then
    demo_warn "Found ${PROFILE_DIR}/setup.sh but it is not executable; skipping"
  fi
  if [[ -f "${PROFILE_DIR}/NOTES.md" ]]; then
    demo_log "Demo notes: ${PROFILE_DIR}/NOTES.md"
  fi
else
  demo_warn "No profile folder at scripts/demos/${DEMO_ID}/ yet (scaffold only)."
  demo_warn "Add NOTES.md + optional setup.sh/reset.sh there when you lock the demo."
fi

cat <<EOF

✓ Demo ready
  demo-id:     ${DEMO_ID}
  branch:      ${BRANCH}
  based on:    ${START_REF}
  state file:  ${STATE_FILE}

Next:
  1. Use the matching Cursor skill (or /kev-demo-kit) for the talk track
  2. Read the profile setup's === DEMO READINESS === block:
     - READY → proceed to live beats
     - NOT READY → start missing backend/frontend as durable Cursor background
       shells (block_until_ms:0, exec …; never nohup in a one-shot Shell), then
       re-run: ./scripts/demos/<demo-id>/setup.sh
  3. After the customer session: ./scripts/demos/reset.sh

EOF
