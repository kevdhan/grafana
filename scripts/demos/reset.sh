#!/usr/bin/env bash
# Tear down an active Field Engineer demo and return to the base branch.
#
# Usage:
#   ./scripts/demos/reset.sh [--force] [--keep-branch] [--clean-untracked]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") [--save-kit] [--force] [--keep-branch] [--clean-untracked]
                        [--keep-servers] [--stop-deps]

Reads .demo-state, checks out the base branch, deletes the local demo branch
(unless --keep-branch), and clears demo state.

Options:
  --save-kit         Before teardown, commit the reusable demo-kit changes
                     (scripts/demos, .cursor/skills, demo-safety rule, .gitignore)
                     onto the base branch (local commit — NOT pushed), then
                     discard the live product changes under public/app and pkg.
                     This is the one-command "keep my kit, reset the demo" path.
  --force            Allow discarding uncommitted changes to tracked files
                     (git reset --hard). Does NOT delete untracked files.
  --clean-untracked  Also run git clean -fd (destructive — removes untracked
                     files/dirs). Requires --force. Use rarely.
  --keep-branch      Do not delete the local demo/<id> branch
  --keep-servers     Forwarded to profile reset: leave Grafana FE/BE running
                     (default profile reset stops them so the next chat owns
                     fresh terminals). Prometheus still left up unless --stop-deps.
  --stop-deps        Forwarded to profile reset: also stop Prometheus/devenv
  -h, --help         Show this help
EOF
}

FORCE=0
KEEP_BRANCH=0
CLEAN_UNTRACKED=0
SAVE_KIT=0
KEEP_SERVERS=0
STOP_DEPS=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --force) FORCE=1; shift ;;
    --keep-branch) KEEP_BRANCH=1; shift ;;
    --clean-untracked) CLEAN_UNTRACKED=1; shift ;;
    --save-kit) SAVE_KIT=1; shift ;;
    --keep-servers) KEEP_SERVERS=1; shift ;;
    --stop-deps) STOP_DEPS=1; shift ;;
    *) demo_die "Unknown flag: $1" ;;
  esac
done

if [[ "${CLEAN_UNTRACKED}" == "1" && "${FORCE}" != "1" ]]; then
  demo_die "--clean-untracked requires --force"
fi

require_repo_root
read_state

demo_log "Active demo: ${DEMO_ID} on ${DEMO_BRANCH} (base ${BASE_BRANCH})"

PROFILE_DIR="${DEMOS_ROOT}/${DEMO_ID}"
if [[ -x "${PROFILE_DIR}/reset.sh" ]]; then
  PROFILE_ARGS=()
  [[ "${KEEP_SERVERS}" == "1" ]] && PROFILE_ARGS+=(--keep-servers)
  [[ "${STOP_DEPS}" == "1" ]] && PROFILE_ARGS+=(--stop-deps)
  demo_log "Running demo-specific reset: ${PROFILE_DIR}/reset.sh${PROFILE_ARGS[*]:+ ${PROFILE_ARGS[*]}}"
  if [[ ${#PROFILE_ARGS[@]} -gt 0 ]]; then
    "${PROFILE_DIR}/reset.sh" "${PROFILE_ARGS[@]}" || demo_warn "Demo-specific reset exited non-zero"
  else
    "${PROFILE_DIR}/reset.sh" || demo_warn "Demo-specific reset exited non-zero"
  fi
fi

# --save-kit: preserve reusable kit changes on the base branch, then discard
# the live product changes so the tree is clean for teardown below.
if [[ "${SAVE_KIT}" == "1" ]]; then
  demo_commit_kit_to_base "${BASE_BRANCH}"
  demo_discard_product_changes
fi

if [[ -n "$(git status --porcelain)" ]]; then
  if [[ "${FORCE}" == "1" ]]; then
    demo_warn "Discarding tracked changes with git reset --hard"
    git reset --hard
    if [[ "${CLEAN_UNTRACKED}" == "1" ]]; then
      demo_warn "Removing untracked files with git clean -fd"
      git clean -fd
    else
      demo_warn "Leaving untracked files in place (pass --clean-untracked to remove)"
    fi
  else
    demo_die "Working tree is dirty. Stash/commit, or pass --force to discard tracked changes."
  fi
fi

if git show-ref --verify --quiet "refs/heads/${BASE_BRANCH}"; then
  demo_log "Checking out ${BASE_BRANCH}"
  git checkout "${BASE_BRANCH}"
elif git show-ref --verify --quiet "refs/remotes/origin/${BASE_BRANCH}"; then
  demo_log "Creating local ${BASE_BRANCH} from origin/${BASE_BRANCH}"
  git checkout -B "${BASE_BRANCH}" "origin/${BASE_BRANCH}"
else
  demo_die "Cannot find base branch ${BASE_BRANCH}"
fi

REMOVED_NOTE="deleted local ${DEMO_BRANCH}"
if [[ "${KEEP_BRANCH}" == "1" ]]; then
  demo_warn "Keeping local branch ${DEMO_BRANCH}"
  REMOVED_NOTE="kept local ${DEMO_BRANCH} (--keep-branch)"
else
  if git show-ref --verify --quiet "refs/heads/${DEMO_BRANCH}"; then
    demo_log "Deleting local branch ${DEMO_BRANCH}"
    git branch -D "${DEMO_BRANCH}"
  else
    demo_warn "Demo branch ${DEMO_BRANCH} already gone"
    REMOVED_NOTE="branch already gone"
  fi
fi

clear_state

cat <<EOF

✓ Demo reset complete
  now on:   $(current_branch)
  branch:   ${REMOVED_NOTE}

Ready for the next customer session.

EOF
