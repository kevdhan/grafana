---
name: kev-demo-grafana-explore-trace-health
description: >-
  Field Engineer demo — HEALTH check for the explore-trace demo. Runs a quick
  read-only probe of every dependency the demo needs (toolchain, demo branch +
  state, Docker daemon, Prometheus container, Grafana backend, the provisioned
  Prometheus datasource, frontend HMR watcher, the background traffic generator,
  whether the 401 error data is present, and the UC2 Cursor kit primitives) and reports each as green / yellow /
  red with a short problem description and fix. Use when the user says demo
  health, demo status, is everything running, check the explore-trace demo,
  diagnose the demo, or /kev-demo-grafana-explore-trace-health. Companion to
  /kev-demo-grafana-explore-trace-start and /kev-demo-grafana-explore-trace-reset.
  Trigger via /kev-demo-grafana-explore-trace-health.
---

# kev-demo-grafana-explore-trace-health

A fast, **read-only** health check for the **explore-trace** demo. Probes every
dependency and renders a green / yellow / red status table with fixes. Companion
to **`/kev-demo-grafana-explore-trace-start`** and **`/kev-demo-grafana-explore-trace-reset`**.

## When to use

- User triggers `/kev-demo-grafana-explore-trace-health`
- Before a live demo, to confirm everything is green
- When something misbehaves mid-demo and you need a quick diagnosis
- After `start` (to confirm spinup) or to see what a `reset` left running

## How to run

Run the probe block below **UNSANDBOXED** (`required_permissions: ["all"]`). This
is required — the Cursor sandbox blocks the Docker socket and hides processes, so
a sandboxed run gives false reds for **Docker daemon** and **Frontend HMR**. The
block only reads state (curl, git, pgrep, cat); it never mutates anything.

```bash
export PATH="$HOME/.local/go/bin:$HOME/.local/node/bin:$PATH"
GURL="http://localhost:3000"; PURL="http://localhost:9090"; DS="demo-explore-trace-prom"
row(){ printf '%s|%s|%s\n' "$1" "$2" "$3"; }

# 1. Toolchain (Go/Node)
if command -v go >/dev/null 2>&1 && command -v node >/dev/null 2>&1; then
  row GREEN "Toolchain" "$(go version | awk '{print $3}'), node $(node -v)"
else
  row RED "Toolchain" "go/node not on PATH — export \$HOME/.local/{go,node}/bin"
fi

# 2. Demo branch + state
b=$(git branch --show-current 2>/dev/null)
if [ -f .demo-state ] && grep -q '^DEMO_ID=explore-trace' .demo-state 2>/dev/null; then
  row GREEN "Demo state" "active on ${b}"
elif [ "$b" = "demo/explore-trace" ]; then
  row YELLOW "Demo state" "on demo branch but .demo-state missing — re-run start"
else
  row YELLOW "Demo state" "no active demo (on ${b}) — run /kev-demo-grafana-explore-trace-start"
fi

# 3. Docker daemon (sandbox hides the socket — must run unsandboxed)
if docker version --format '{{.Server.Version}}' >/dev/null 2>&1; then
  row GREEN "Docker daemon" "server $(docker version --format '{{.Server.Version}}' 2>/dev/null)"
else
  row RED "Docker daemon" "not reachable — start Docker Desktop (if this ran sandboxed it's a false red)"
fi

# 4. Prometheus container :9090 (devenv block requires basic auth admin/admin)
code=$(curl -s -o /dev/null -w '%{http_code}' -u admin:admin --max-time 5 "$PURL/-/healthy" 2>/dev/null)
if [ "$code" = "200" ]; then
  row GREEN "Prometheus :9090" "healthy"
elif [ "$code" = "401" ]; then
  row YELLOW "Prometheus :9090" "401 — needs basic auth admin/admin (send creds)"
else
  row RED "Prometheus :9090" "HTTP ${code:-000} — not running; re-run start or 'make devenv sources=prometheus'"
fi

# 5. Grafana backend :3000
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$GURL/login" 2>/dev/null)
if [ "$code" = "200" ]; then
  row GREEN "Grafana backend :3000" "/login 200"
else
  row RED "Grafana backend :3000" "HTTP ${code:-000} — backend down; start ./bin/grafana server … and gate on /login 200"
fi

# 6. Prometheus datasource (provisioned + reachable via Grafana proxy)
st=$(curl -s -u admin:admin --max-time 5 "$GURL/api/datasources/uid/$DS/health" 2>/dev/null \
      | python3 -c "import sys,json;print(json.load(sys.stdin).get('status','ERR'))" 2>/dev/null)
if [ "$st" = "OK" ]; then
  row GREEN "Prometheus datasource" "health OK"
elif [ -z "$st" ] || [ "$st" = "ERR" ]; then
  row RED "Prometheus datasource" "missing/unhealthy — re-run start (provisioning + reload)"
else
  row YELLOW "Prometheus datasource" "status ${st}"
fi

# 7. Frontend HMR (webpack dev watcher — needed for Design Mode live edits)
if pgrep -f "webpack.dev" >/dev/null 2>&1; then
  row GREEN "Frontend HMR" "yarn start watcher running"
else
  row YELLOW "Frontend HMR" "no watcher — Design Mode won't hot-reload; run 'yarn start' UNSANDBOXED"
fi

# 8. Background traffic generator (durable shell; keeps the 401 spike fresh)
pid=$(cat .demo-traffic.pid 2>/dev/null)
if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
  row GREEN "Traffic generator" "running (pid ${pid})"
elif pgrep -f 'seed-traffic\.sh --watch' >/dev/null 2>&1; then
  row YELLOW "Traffic generator" "running but .demo-traffic.pid stale — re-run profile setup to record pid"
else
  row YELLOW "Traffic generator" "stopped — start durable shell: exec bash scripts/demos/explore-trace/seed-traffic.sh --watch 12"
fi

# 9. Error data present (UC1 payoff): 401 rate > 0 over 5m
v=$(curl -s -u admin:admin --max-time 5 \
      --data-urlencode 'query=sum(rate(grafana_http_request_duration_seconds_count{status_code="401"}[5m]))' \
      "$PURL/api/v1/query" 2>/dev/null \
      | python3 -c "import sys,json;d=json.load(sys.stdin)['data']['result'];print(d[0]['value'][1] if d else '0')" 2>/dev/null)
if awk "BEGIN{exit !(${v:-0}>0)}" 2>/dev/null; then
  row GREEN "Error data (401 spike)" "rate ${v}/s over 5m"
else
  row YELLOW "Error data (401 spike)" "401 rate 0 over 5m — traffic just started/stopped; wait ~30s or start generator"
fi

# 10. UC2 Cursor primitives (git-tracked kit — needed for the Customize tour + delegated fix)
missing=""
for f in .cursor/rules/grafana-frontend-conventions.mdc \
         .cursor/skills/run-frontend-test/SKILL.md \
         .cursor/hooks/format-frontend.sh .cursor/hooks.json \
         .cursor/agents/plan-executor.md; do
  [ -f "$f" ] || missing="${missing} ${f##*/}"
done
if [ -z "$missing" ]; then
  row GREEN "UC2 kit primitives" "rule + skill + hooks + plan-executor present"
else
  row YELLOW "UC2 kit primitives" "missing:${missing} — restore from base (reset --save-kit preserves these)"
fi
```

> External UC2 dependencies — the Jira MCP (`fe-anysphere-demo`, ticket `KHS-6`) and
> the GitHub Bugbot repo (`internalsphere/kev-grafana`, PR #2) — live outside this
> repo and outside this probe. Confirm MCP/GitHub auth separately before demoing UC2.

## Output — render a traffic-light table

Parse the `STATUS|Component|Detail` lines and present a table, mapping
`GREEN → 🟢`, `YELLOW → 🟡`, `RED → 🔴`. Keep the Detail column short; it already
carries the problem + fix for non-green rows.

| Status | Component | Detail / fix |
|--------|-----------|--------------|
| 🟢 | Grafana backend :3000 | /login 200 |
| 🟡 | Traffic generator | stopped — run seed-traffic.sh --watch |
| … | … | … |

Then give a one-line **overall verdict**: 🟢 all green (ready to demo) · 🟡 degraded
(demo works, note the caveats) · 🔴 blocked (fix reds before demoing). Lead with any
red/yellow rows and the single most important next action.

Optional: for a richer graphical view, render a Cursor Canvas (traffic-light
cards) instead of a table — but the table is the fast default.

## What each check means (dependency map)

| Component | Green means | Common non-green cause & fix |
|-----------|-------------|------------------------------|
| Toolchain | `go` + `node` on PATH | export `~/.local/{go,node}/bin` |
| Demo state | `.demo-state` + on `demo/explore-trace` | not started → `/kev-demo-grafana-explore-trace-start` |
| Docker daemon | daemon responds | Docker Desktop down, or ran **sandboxed** (false red) |
| Prometheus :9090 | `/-/healthy` 200 w/ admin:admin | container down → re-run start; 401 → missing basic auth |
| Grafana backend | `/login` 200 | backend not running / cold-starting |
| Datasource | proxy health `OK` | not provisioned → re-run start (reload API) |
| Frontend HMR | webpack watcher alive | not started, or `yarn start` sandboxed (EMFILE) → run unsandboxed |
| Traffic generator | `.demo-traffic.pid` alive (durable shell) | stopped → durable `exec bash …/seed-traffic.sh --watch 12` (never nohup); re-run profile setup |
| Error data | 401 rate > 0 over 5m | generator just started/stopped → wait or restart |
| UC2 kit primitives | rule + `run-frontend-test` skill + hooks + `plan-executor` present | missing → restore from base (`reset --save-kit` preserves them); Jira MCP + `internalsphere/kev-grafana` are external — check auth separately |

## Safety

- **Read-only** — this skill only probes; it never edits files, git state, or services.
- Run **unsandboxed** so Docker + process checks are accurate.

## Related

- Start / run: `/kev-demo-grafana-explore-trace-start`
- Reset / teardown: `/kev-demo-grafana-explore-trace-reset`
- Orchestrator: `/kev-demo-kit`
- Notes: `scripts/demos/explore-trace/demo-script.md` · cheat sheet: `demo-script-short.md`
