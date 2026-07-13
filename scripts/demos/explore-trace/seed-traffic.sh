#!/usr/bin/env bash
# explore-trace: generate a realistic mix of HTTP status codes on Grafana's own
# request metric (grafana_http_request_duration_seconds_count), which the devenv
# Prometheus scrapes as job="grafana". This powers the "4xx error spike after a
# deploy" on-call story in Beat 1 WITHOUT any extra exporter or container.
#
# Why 4xx and not 5xx: Grafana won't reliably emit 500s on demand, so we tell an
# honest story around auth failures (401) / removed endpoints (404) spiking after
# a deploy — a real paging scenario that also reinforces the "a deploy changed
# something" theme used elsewhere in this demo.
#
# Usage:
#   ./scripts/demos/explore-trace/seed-traffic.sh [cycles]
# Then, in Explore (Prometheus):
#   sum by (status_code) (rate(grafana_http_request_duration_seconds_count[5m]))
set -euo pipefail

GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
ADMIN_AUTH="${ADMIN_AUTH:-admin:admin}"
CYCLES="${1:-40}"

echo "→ Seeding ~${CYCLES} cycles of mixed traffic to ${GRAFANA_URL}"
echo "  (healthy 200s + a burst of 401 auth failures and 404s)"

for i in $(seq 1 "${CYCLES}"); do
  # Healthy 200s (baseline traffic)
  curl -s -o /dev/null -u "${ADMIN_AUTH}" "${GRAFANA_URL}/api/health"
  curl -s -o /dev/null -u "${ADMIN_AUTH}" "${GRAFANA_URL}/api/search?limit=1"

  # 401 — auth failures (e.g. a service token rotated/broken by a deploy)
  curl -s -o /dev/null -u "admin:wrongpass" "${GRAFANA_URL}/api/admin/settings"

  # 404 — endpoint/resource removed or renamed by a deploy
  curl -s -o /dev/null -u "${ADMIN_AUTH}" "${GRAFANA_URL}/api/dashboards/uid/removed-by-deploy-${i}"
done

echo "→ Done. In Explore (Prometheus), run:"
echo "    sum by (status_code) (rate(grafana_http_request_duration_seconds_count[5m]))"
echo "  You should see 200 alongside a 401/404 spike."
