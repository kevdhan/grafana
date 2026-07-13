#!/usr/bin/env bash
# explore-trace: demo-specific teardown.
#   - Removes the provisioned Prometheus datasource (gitignored, disposable).
#   - Leaves the Prometheus container RUNNING by default so the next demo
#     iteration is fast (reuse-first). Pass --stop-deps for a cold teardown.
# Branch + .demo-state cleanup is handled by top-level scripts/demos/reset.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../_lib.sh
source "${SCRIPT_DIR}/../_lib.sh"

STOP_DEPS=0
for arg in "$@"; do
  case "${arg}" in
    --stop-deps) STOP_DEPS=1 ;;
  esac
done

echo "→ (explore-trace) demo-specific reset"

# Stop the background traffic generator started by setup.
demo_stop_traffic

demo_remove_prometheus_datasource
# If Grafana is up, reload so the provisioned datasource is dropped now
# (otherwise it lingers until the next backend restart).
demo_reload_datasource_provisioning

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
