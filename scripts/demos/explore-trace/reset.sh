#!/usr/bin/env bash
# explore-trace: demo-specific teardown.
#   - Stops traffic + Grafana backend/frontend by default (so the *next* Cursor
#     chat's start skill relaunches them → native terminals in that chat).
#   - Leaves the Prometheus container RUNNING by default (fast reuse).
#   - Pass --keep-servers to leave FE/BE up (same-chat iteration).
#   - Pass --stop-deps for a cold teardown (also stop Prometheus/devenv).
# Branch + .demo-state cleanup is handled by top-level scripts/demos/reset.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../_lib.sh
source "${SCRIPT_DIR}/../_lib.sh"

STOP_DEPS=0
KEEP_SERVERS=0
for arg in "$@"; do
  case "${arg}" in
    --stop-deps) STOP_DEPS=1 ;;
    --keep-servers) KEEP_SERVERS=1 ;;
  esac
done

echo "→ (explore-trace) demo-specific reset"

# Stop the background traffic generator started by setup.
demo_stop_traffic

# Remove UC2 plant (untracked limitSeries* + GraphContainer restore) so files
# do not leak onto main when the operator skips --save-kit / --clean-untracked.
if [[ -x "${SCRIPT_DIR}/unplant-uc2.sh" ]]; then
  "${SCRIPT_DIR}/unplant-uc2.sh" || demo_warn "unplant-uc2 exited non-zero"
fi

demo_remove_prometheus_datasource
# Reload while Grafana is still up so the provisioned datasource is dropped now
# (otherwise it lingers until the next backend restart).
demo_reload_datasource_provisioning

# Default: stop FE/BE so the next chat owns fresh terminals. Prometheus stays.
if [[ "${KEEP_SERVERS}" == "1" ]]; then
  demo_log "Leaving Grafana backend/frontend running (--keep-servers)"
else
  demo_stop_grafana_servers
fi

if [[ "${STOP_DEPS}" == "1" ]]; then
  if command -v docker >/dev/null 2>&1; then
    demo_log "Stopping devenv containers (make devenv-down)…"
    make -C "${REPO_ROOT}" devenv-down || demo_warn "devenv-down exited non-zero"
  else
    demo_warn "Docker not found; nothing to stop"
  fi
else
  if demo_prometheus_ok; then
    demo_log "Leaving Prometheus running on :9090 (reuse next iteration; --stop-deps to stop)"
  fi
fi

echo "  Reminder: run ./scripts/demos/reset.sh from the repo root to leave"
echo "  demo/explore-trace and clear .demo-state."
