#!/usr/bin/env bash
# explore-trace: generate a realistic mix of HTTP status codes on Grafana's own
# request metric (grafana_http_request_duration_seconds_count), which the devenv
# Prometheus scrapes as job="grafana". This powers the "4xx error spike after a
# deploy" on-call story in Use Case 1 WITHOUT any extra exporter or container.
#
# Why 4xx and not 5xx: Grafana won't reliably emit 500s on demand, so we tell an
# honest story around auth failures (401) / removed endpoints (404) spiking after
# a deploy — a real paging scenario that also reinforces the "a deploy changed
# something" theme used elsewhere in this demo.
#
# Two modes:
#   One-shot (default): a burst of traffic, useful right before a beat.
#     ./scripts/demos/explore-trace/seed-traffic.sh [cycles]        # default 40
#   Continuous: a steady trickle so rate() over ANY window (5m/15m/60m) stays
#   non-zero for the whole demo. This is what setup.sh runs in the background.
#     ./scripts/demos/explore-trace/seed-traffic.sh --watch [interval_secs]  # default 15
#
# Then, in Explore (Prometheus):
#   sum by (status_code) (rate(grafana_http_request_duration_seconds_count[5m]))
set -euo pipefail

GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
ADMIN_AUTH="${ADMIN_AUTH:-admin:admin}"

WATCH=0
INTERVAL=15
CYCLES=40
for arg in "$@"; do
  case "${arg}" in
    --watch) WATCH=1 ;;
    [0-9]*) if [[ "${WATCH}" == "1" ]]; then INTERVAL="${arg}"; else CYCLES="${arg}"; fi ;;
  esac
done

# Soft curl: never abort the watch loop when Grafana is briefly down / restarting.
# (This script uses `set -e`; a plain curl exit 7 on connection-refused would kill
# --watch and leave .demo-traffic.pid pointing at a dead process.)
soft_curl() {
  curl -s -o /dev/null --connect-timeout 2 --max-time 5 "$@" || true
}

# One round of mixed traffic: healthy 200s + 401s + a 404.
emit_mixed() {
  local tag="${1:-x}"
  soft_curl -u "${ADMIN_AUTH}" "${GRAFANA_URL}/api/health"
  soft_curl -u "${ADMIN_AUTH}" "${GRAFANA_URL}/api/search?limit=1"
  # 401 — UNAUTHENTICATED request (no credentials submitted).
  # IMPORTANT: do NOT send a wrong password here. Repeated bad-password attempts
  # trip Grafana's brute-force protection and lock the admin account for ~5 min,
  # which blocks admin:admin everywhere and breaks the whole demo. An
  # unauthenticated request returns 401 without counting as a failed login.
  soft_curl "${GRAFANA_URL}/api/admin/settings"
  # 404 — endpoint/resource removed or renamed by a deploy (valid admin creds)
  soft_curl -u "${ADMIN_AUTH}" "${GRAFANA_URL}/api/dashboards/uid/removed-by-deploy-${tag}"
}

if [[ "${WATCH}" == "1" ]]; then
  echo "→ Continuous traffic to ${GRAFANA_URL} every ${INTERVAL}s (Ctrl-C / kill to stop)"
  n=0
  while true; do
    n=$((n + 1))
    emit_mixed "watch-${n}"
    sleep "${INTERVAL}"
  done
else
  echo "→ Seeding ~${CYCLES} cycles of mixed traffic to ${GRAFANA_URL}"
  echo "  (healthy 200s + a burst of 401 auth failures and 404s)"
  for i in $(seq 1 "${CYCLES}"); do
    emit_mixed "${i}"
  done
  echo "→ Done. In Explore (Prometheus), run:"
  echo "    sum by (status_code) (rate(grafana_http_request_duration_seconds_count[5m]))"
  echo "  You should see 200 alongside a 401/404 spike."
  echo "  Tip: for a demo, prefer '--watch' so the spike stays fresh for 15m/60m windows."
fi
