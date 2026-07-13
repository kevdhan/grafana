#!/usr/bin/env bash
# explore-trace: preflight + plant UC2 + readiness gate.
#
# This script is the single source of truth for "is the demo ready?". The Cursor
# skill must follow the === DEMO READINESS === block instead of improvising.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../_lib.sh
source "${SCRIPT_DIR}/../_lib.sh"

echo "→ explore-trace preflight"
echo ""

demo_ensure_local_path
demo_check_toolchain || true

# --- UC2 plant (always; clean origin/main does not include the bug) ---
if [[ -x "${SCRIPT_DIR}/plant-uc2.sh" ]]; then
  "${SCRIPT_DIR}/plant-uc2.sh"
else
  demo_die "Missing executable ${SCRIPT_DIR}/plant-uc2.sh — cannot plant UC2 bug"
fi
echo ""

# Data source: prefer a real local Prometheus (authentic "No data" story);
# fall back to TestData when Docker is unavailable. Never fail setup on this.
if demo_ensure_prometheus; then
  demo_write_prometheus_datasource
  # If a backend is already up, reload provisioning so the datasource appears
  # without a restart; otherwise it is picked up on next backend start.
  demo_reload_datasource_provisioning
  demo_log "Data source: Prometheus (localhost:9090) provisioned"
else
  demo_remove_prometheus_datasource
  demo_log "Data source: using TestData fallback (No Data Points scenario)"
fi
echo ""

if demo_login_ok; then
  demo_log "Grafana already healthy on :3000 (/login → 200) — reuse; do not restart"
  demo_ensure_traffic || true
else
  demo_log "Grafana not ready on :3000 — warming modules before any backend start"
  demo_warm_go_modules || true
  echo ""
  echo "  Fast spinup (agent: start as durable Cursor background shells, NOT nohup in a one-shot Shell):"
  echo "  1. Frontend: unset CHOKIDAR_USEPOLLING CHOKIDAR_INTERVAL WATCHPACK_POLLING; yarn start"
  echo "  2. Backend (prefer non-race):"
  demo_backend_cmd_hint | sed 's/^/     /'
  echo "  3. Wait until: curl -s -o /dev/null -w '%{http_code}' http://localhost:3000/login → 200"
  echo "     (Frontend 'Compiled successfully' alone is NOT enough.)"
  echo "  4. Re-run this script to attach traffic + re-print the readiness gate:"
  echo "       ./scripts/demos/explore-trace/setup.sh"
  echo ""
fi

echo "  Checklist before the live beats:"
echo "  [ ] PATH: go/node visible (often ~/.local/go/bin + ~/.local/node/bin)"
echo "  [ ] Backend healthy:  /login → 200 (reuse if already up)"
echo "  [ ] Frontend:         yarn start → HMR for Design Mode"
echo "  [ ] Login:            admin / admin"
echo "  [ ] Explore ready:    open /explore, Prometheus empty query (or TestData No Data Points)"
echo "  [ ] Agents Window:    Cmd+Shift+P → Open Agents Window → Browser"
echo "  [ ] Design Mode:      Cmd+Shift+D (after page fully loads)"
echo ""
echo "  Talk track + prompts: scripts/demos/explore-trace/NOTES.md"
echo "  Skill trigger:        /kev-demo-grafana-explore-trace-start (reset: /kev-demo-grafana-explore-trace-reset)"

# Always print the gate last so the agent can parse it.
demo_print_readiness || true
