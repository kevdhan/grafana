---
name: kev-demo-grafana-explore-trace-start
description: >-
  Field Engineer demo — START a new explore-trace demo (creates the branch, spins
  up servers, runs the two Explore use cases). UC1 — Ask-mode trace of Grafana
  Explore Run → API → Go (optionally captured in a Cursor Canvas), then Agents
  Window + Design Mode to build an active-diagnosis empty state (ExploreNoDataDiagnostics.tsx + PanelDataErrorView.tsx) that queries the datasource.
  UC2 — Ask traces the Explore graph series-limiting pipeline and Agent fixes a
  dropped-series bug in limitSeries.ts + GraphContainer.tsx (only 1 line drawn
  when the disclaimer says 20), turning a failing unit test green. Use when the user says
  start explore-trace demo, grafana explore demo, /kev-demo-grafana-explore-trace-start,
  or wants to begin the Ask + Design Mode + Agent Grafana demo. To tear the demo
  down afterward, use the companion skill /kev-demo-grafana-explore-trace-reset.
  Trigger via /kev-demo-grafana-explore-trace-start.
---

# kev-demo-grafana-explore-trace-start

Starts (and runs) the **explore-trace** customer demo across **two Explore use cases**.
To tear it down afterward, use the companion skill **`/kev-demo-grafana-explore-trace-reset`**.

- **UC1 — No data → diagnose & fix the query.** Ask maps the request path (capture it in a Cursor Canvas); Design Mode builds an *active-diagnosis* empty state (`ExploreNoDataDiagnostics.tsx` + `PanelDataErrorView.tsx`) that queries the datasource to explain why (metric "did you mean" + culprit label filter); one-click fix reveals a seeded 401 spike.
- **UC2 — Data looks wrong → find & fix a bug.** Ask traces the graph series-limiting pipeline to `limitSeries.ts` (via `GraphContainer.tsx`); Agent fixes a dropped-series bug (only 1 line drawn when the disclaimer says 20) and turns a failing unit test green (planted, reversible demo artifact).

Full talk track: `scripts/demos/explore-trace/NOTES.md`. Live cheat sheet: `NOTES-BRIEF.md`.

## Branch lifecycle

| Step | Command | Git effect |
|------|---------|------------|
| Setup | `./scripts/demos/setup.sh explore-trace` | Creates local branch `demo/explore-trace` from `main` (or `--from`), writes `.demo-state` |
| Reset | `./scripts/demos/reset.sh` | Checks out base (`main`), **deletes** local `demo/explore-trace`, clears `.demo-state` |

Always run setup at the start and reset at the end of a customer session.

## When to use

- User triggers `/kev-demo-grafana-explore-trace-start`
- User asks to start / run the Grafana Explore Ask + Design Mode demo
- User wants the first FE Value Map demo (Buckets 1–4 + 8)

(Teardown is a separate skill: `/kev-demo-grafana-explore-trace-reset`.)

## Safety (always)

1. Prefer `./scripts/demos/setup.sh` / `./scripts/demos/reset.sh` — no free-hand destructive git.
2. Never force-push `main` / `master`. Never delete remote branches unless asked.
3. Do **not** pass `--clean-untracked` unless the user explicitly wants it.
4. Live edits are scoped: UC1 Design Mode builds the Explore-scoped empty state in `ExploreNoDataDiagnostics.tsx` + `PanelDataErrorView.tsx` (guarded by `eventsScope === 'explore'`) and threads `request` through `Explore.tsx` → `GraphContainer.tsx` → `ExploreGraph.tsx`; UC2 Agent fixes only the hardcoded series cap in `public/app/features/explore/Graph/limitSeries.ts` (`1` → `MAX_NUMBER_OF_TIME_SERIES`, consumed by `GraphContainer.tsx`).
5. Do **not** change `runQueries`, the Explore query pipeline, `pkg/api/ds_query.go` / `pkg/api/api.go`, dashboard "No data" behavior, auth, or alerting in the live demo.
6. Keep empty-state copy professional (no jokes / customer-name hardcoding).
7. If `.demo-state` exists for another demo, confirm before switching.

## Cursor sandbox (read first)

Agent `Shell` calls run **sandboxed by default**, which silently breaks three things in this demo. Run these unsandboxed (`required_permissions: ["all"]`):

| Task | Sandboxed symptom | Fix |
|------|-------------------|-----|
| Anything Docker (`setup.sh`, `docker …`, `make devenv`) | Docker socket blocked → `docker info` fails → **false TestData fallback** | Run unsandboxed |
| Frontend `yarn start` | FSEvents blocked → `EMFILE: too many open files` → watcher dies in ~10s | Run unsandboxed |
| `go mod download` / backend build | `GOMODCACHE`/`GOCACHE` redirected to a temp sandbox cache → re-downloads | Run unsandboxed (or pin `$HOME` caches) |
| Long-lived servers via `nohup … &` in a one-shot Shell | Process group dies when the Shell tool exits → `/login` flips to `000`, traffic pid goes stale | Use Cursor **background** shells (`block_until_ms: 0`) with `exec` |

Also: **exported env vars persist across `Shell` calls** in a session — a stray `CHOKIDAR_USEPOLLING`/`WATCHPACK_POLLING` will poison later `yarn start` restarts. `unset` them.

## Agent startup contract (do not improvise)

Setup is automated. **Do not** hand-plant UC2, dig through agent transcripts, or invent server-start sequences. Follow this loop until the readiness gate says `READY`:

### 1. Run setup (unsandboxed)

```sh
./scripts/demos/setup.sh explore-trace
# recreate: add --force
```

Profile `scripts/demos/explore-trace/setup.sh` runs automatically and now:

1. **Plants UC2** via `plant-uc2.sh` (copies fixtures → `limitSeries.ts` + failing test, wires `GraphContainer.tsx`, re-breaks the cap to `1` if a prior Agent fix left it green)
2. Ensures Prometheus (or TestData fallback) + datasource provisioning
3. Starts/verifies the **traffic** generator when `/login` is already 200 (and survives Grafana blips — soft curl)
4. Prints a final **`=== DEMO READINESS ===`** block

### 2. Parse the readiness gate

Read the setup stdout block:

```
=== DEMO READINESS ===
login:     OK|FAIL
prometheus:OK|DOWN|TestData
frontend:  OK|FAIL
traffic:   OK|FAIL
uc2-plant: OK|FAIL
status:    READY|NOT READY
=== END READINESS ===
```

- **`status: READY`** (and `uc2-plant: OK`, `login: OK`) → skip to Beat 1. Do not restart healthy servers.
- **`status: NOT READY`** → go to step 3. Do **not** explore the repo looking for missing files — setup already told you what failed.

### 3. Start only what the gate says is missing (durable shells)

If `login: FAIL` and/or `frontend: FAIL`, start them as **separate Cursor background shells**:

- `required_permissions: ["all"]`
- `block_until_ms: 0`
- Prefer `exec …` so the process is the shell’s main PID

```sh
# Backend (prefer bin/grafana when present)
export PATH="$HOME/.local/go/bin:$HOME/.local/node/bin:$PATH"
unset CHOKIDAR_USEPOLLING CHOKIDAR_INTERVAL WATCHPACK_POLLING
exec ./bin/grafana server -profile -profile-addr=127.0.0.1 -profile-port=6000 -packaging=dev cfg:app_mode=development
# else: exec go run ./pkg/cmd/grafana -- server -packaging=dev cfg:app_mode=development
```

```sh
# Frontend
export PATH="$HOME/.local/go/bin:$HOME/.local/node/bin:$PATH"
unset CHOKIDAR_USEPOLLING CHOKIDAR_INTERVAL WATCHPACK_POLLING
exec yarn start
```

**Never** start backend/frontend with `nohup … &` inside a one-shot Shell — that was the main failure mode that made `/login` flip to `000` mid-demo.

Await `/login → 200` (and webpack “Compiled” for HMR), then **re-run**:

```sh
./scripts/demos/explore-trace/setup.sh
```

That **records server pids** (`.demo-backend.pid` / `.demo-frontend.pid` for reset), re-attaches traffic, re-verifies the UC2 plant, and reprints the gate. Loop until `READY`.

**Why reset stops FE/BE:** Cursor terminals belong to the chat that started them. After reset, the next demo is usually a **new chat** — leaving servers up would make start silently reuse invisible processes. Reset stops Grafana backend/frontend by default (Prometheus stays); start relaunches them here so terminals are native to this chat.

### 4. What setup owns (so you don't)

| Concern | Owner | Notes |
|---------|-------|-------|
| UC2 `limitSeries.ts` plant (cap=`1`) + failing test + `GraphContainer` wire | `plant-uc2.sh` via profile setup | Fixtures live under `scripts/demos/explore-trace/fixtures/` |
| UC2 cleanup on teardown | `unplant-uc2.sh` via profile reset | Also covered by `--save-kit` product discard |
| Traffic generator | `demo_ensure_traffic` | Soft-curl so Grafana restarts don't kill `--watch` |
| Prometheus vs TestData | `demo_ensure_prometheus` | Warns on sandboxed Docker socket |
| Readiness summary | `demo_print_readiness` | Agent parses this; don't reinvent checks |

### Data source notes (Prometheus preferred)

- **Always run setup unsandboxed** so Docker works. Sandbox → false TestData fallback.
- Basic auth on devenv Prometheus: `admin`/`admin`.
- Cold devenv build ~1 min; if 30s poll expires → TestData; **re-run profile setup** once `:9090` is healthy.
- Verify: `curl -s -u admin:admin http://localhost:3000/api/datasources/uid/demo-explore-trace-prom/health` → `"status":"OK"`.

### Traffic / 401 safety

- 401s come from **unauthenticated** requests (`curl` with no `-u`), **never** `admin:wrongpass` (locks admin ~5 min).
- Continuous `--watch` keeps `rate()[5m|15m|60m]` fresh; one-shot bursts decay.

### Backend tips

- Prefer `./bin/grafana server …` when present; avoid `make run-go` (`-race`, slow cold compile).
- Plugin version-compat log noise is OK if `/login` is 200.
- Login: `admin` / `admin`.

After `READY`, use `NOTES-BRIEF.md` while driving; fall back to `NOTES.md` for full prompts / narrative.

## Use Case 1 — No data → diagnose & fix the query (Steps 3–6)

### 3. Product context (the 2 a.m. page)

Frame Explore as the ad-hoc **incident investigation** surface (not a saved dashboard), then tell the on-call story from NOTES Beat 1: a paged engineer runs a 5xx-rate query and hits a dead-end **No data** empty state. Full narrative + talk track live in `scripts/demos/explore-trace/NOTES.md`.

Guide the FE/customer to land the empty state:

- **Prometheus (preferred)** — open `/explore`, pick **Prometheus**, run the 5xx query the on-call always reaches for (returns nothing because a deploy renamed the metric; `http_requests_total` doesn't exist here):
  ```promql
  sum(rate(http_requests_total{job="checkout", status=~"5.."}[5m]))
  ```
  Then **fix to a real metric** to fill the graph with the seeded **401 spike** (the errors they were paged for):
  ```promql
  sum by (status_code) (rate(grafana_http_request_duration_seconds_count[5m]))
  ```
  (`prometheus_http_requests_total` is another real metric.) Optional contrast: run `up` first (draws a graph), then the empty 5xx query.
- **TestData (fallback)** — pick **TestData** → scenario **No Data Points**. Note this renders the `NoData` component — a *different* Explore empty state from the graph one improved in Step 5; the active-diagnosis state (`PanelDataErrorView.tsx` + `ExploreNoDataDiagnostics.tsx`) is on the **Prometheus graph** path and needs the datasource's label API, so prefer Prometheus for the full UC1 payoff.

Confirm the centered **No data** empty state is visible before Ask / Design Mode. See the full recipe + why-it's-realistic table in NOTES Beat 1.

**Talk:** the empty state did the diagnosis; the fix reveals the actual incident signal.

### 4. Ask beats + Cursor Canvas (codebase understanding)

Switch to **Ask** mode. Walk the prompts from NOTES (adapt lightly):

1. Where is the Run query button / handler in `ExploreToolbar`?
2. Trace through frontend state / `runQueries` → `runRequest` to the network call (`POST /api/ds/query`).
3. Which Go handler serves that path? Point at `pkg/api/api.go` route → `pkg/api/ds_query.go` `QueryMetricsV2` and summarize.

Map: `ExploreToolbar Run → runQueries → runRequest → POST /api/ds/query → pkg/api/api.go → pkg/api/ds_query.go QueryMetricsV2`.

**Cursor Canvas (shareable source of truth):** after the trace, generate/open a Cursor Canvas (`explore-run-trace.canvas.tsx`) capturing this path as a standalone artifact engineers can open beside chat and share — instead of a trace buried in a thread. Frame Canvas as the team's living source-of-truth; it can also capture the UC2 bug RCA.

Do **not** edit code in this beat — map only.

### 5. Agents Window + Design Mode (build the diagnostic empty state)

**Where the empty state lives (the lesson):** the "No data" state for an empty Prometheus **graph** query is rendered by `public/app/features/panel/components/PanelDataErrorView.tsx` (stack: `PanelDataErrorView > TimeSeriesPanel > … > ExploreGraph`) — **not** `NoData.tsx`, which is a different Explore empty state. Selecting the real DOM node in Design Mode revealed the true component; **trust the selection over the assumption**.

1. Guide: `Cmd+Shift+P` → **Open Agents Window** → Browser → `http://localhost:3000/explore`
2. Ensure the Prometheus-graph empty state is visible
3. Design Mode: `Cmd+Shift+D` after the page fully loads
4. Prefer **user-driven** selection of the No Data / empty-state UI in the browser — the selection resolves to `PanelDataErrorView.tsx`
5. Give the **structured prompt** in NOTES Beat 4 (copy it verbatim). This is an **Agent-scale, multi-file change** kicked off from the selection, not a CSS tweak — the prompt names the Explore scope, the `request` threading the empty state needs, and the exact diagnosis behavior.
6. If touching user-visible strings, use i18n via `t()` when that matches repo pattern

**Already implemented (what the prompt reproduces)** — an *active diagnosis*, scoped to Explore via `context.eventsScope === 'explore'` (Explore's panel context doesn't set `app`):
- New component `public/app/features/panel/components/ExploreNoDataDiagnostics.tsx` calls the datasource resource proxy (`getBackendSrv` → `/api/datasources/uid/<uid>/resources/api/v1/label/__name__/values` and `/api/v1/label/<name>/values`) to detect a **missing metric** (with ranked "did you mean" + "Copy fixed query") and **label matchers that match no series** (with the valid values).
- `PanelDataErrorView.tsx` renders it (query echo + time range + Copy retained; checklist as fallback); dashboards keep the minimal "No data".
- `request` is threaded `Explore.tsx` → `GraphContainer.tsx` → `ExploreGraph.tsx` so the empty state has the query + datasource uid.

Call out Design Mode caveats from NOTES (Agents Window browser; source edit not CSS-only sidebar; needs HMR).

### 6. Verify + reveal the incident

- Confirm the Explore empty state updated via HMR (time range, failed query + Copy, "No metric named … did you mean" suggestion, and the culprit label filter with its valid values)
- Fix the query to `sum by (status_code) (rate(grafana_http_request_duration_seconds_count[5m]))` and watch the graph fill in with the seeded **401 spike**
- Optional Ask: which file changed for the empty state? → `PanelDataErrorView.tsx`

## Use Case 2 — Data looks wrong → find & fix a bug with Cursor

### 6b. Ask trace + Agent fix (planted, reversible bug)

A safe, reversible bug lives on `demo/explore-trace` (discarded by reset). **Say it's an intentional demo artifact.**

1. In Explore (Prometheus), query a metric that **returns many series**: `prometheus_http_requests_total` (returns **56 series** here).
2. The graph draws **only 1 line**, while the disclaimer above it reads *"⚠ Showing only 20 series — Show all 56"*. The mismatch (claims 20, draws 1) is the obvious "something's broken" tell.
3. Use Cursor **Ask** to trace the series-limiting pipeline **and** generate a shareable diagram. Prompt:
   > In Grafana Explore the graph renders only 1 series even though the query returns 56 and the disclaimer says "Showing only 20 series." Trace the series-limiting pipeline from the query result through `GraphContainer` to the exact function that caps the series, and identify the bug. Then generate a Cursor Canvas with a visual architecture diagram of the whole path — user query → `runQueries`/`runRequest` → `POST /api/ds/query` → Go handler → data frames back → `GraphContainer` `slicedData` → `limitSeriesForDisplay` → `PanelRenderer`/graph — and **highlight the node where the bug is** (the series cap).

   Expected: Ask lands on `public/app/features/explore/Graph/limitSeries.ts` — `limitSeriesForDisplay` caps at a hardcoded **`1`** instead of `MAX_NUMBER_OF_TIME_SERIES` (wired via `GraphContainer.tsx`; the `LimitedDataDisclaimer` still uses the real constant, hence "20 shown, 1 drawn"). The Canvas renders the flow with the `limitSeries.ts` node flagged as the fault.
4. **Use the failing unit test as the reproducible artifact** (normal Jest test, runs in the terminal):
   ```sh
   yarn jest public/app/features/explore/Graph/limitSeries.test.ts --watchAll=false
   ```
   (Currently **2 failed, 1 passed** — `Received length: 1` vs `Expected length: 20`.) Optionally run it yourself to show RED first; the stronger move is to let the **Agent** reproduce → fix → re-run green autonomously.
5. Cursor **Agent** prompt — fix + **validate with a unit test AND a visual (headless-browser) test**: *"`limitSeriesForDisplay` caps the series at 1 instead of `MAX_NUMBER_OF_TIME_SERIES`. Fix it, then (1) run `limitSeries.test.ts` until green, and (2) run a visual test with the Playwright harness `scripts/demos/explore-trace/shot.mjs` against `prometheus_http_requests_total` and confirm the graph renders ~20 series instead of 1."*
   - Visual test (Agent runs it, **unsandboxed**): `PLAYWRIGHT_BROWSERS_PATH="$HOME/Library/Caches/ms-playwright" EXPR='prometheus_http_requests_total' OUT='scripts/demos/explore-trace/.shot-uc2-after.png' node scripts/demos/explore-trace/shot.mjs`
   - Result: cap becomes `MAX_NUMBER_OF_TIME_SERIES`, unit test **green**, and the screenshot shows ~20 series (matching the disclaimer) — two forms of proof (test + rendered screenshot).

**Talk:** two Cursor modes across two use cases — Ask/Design to understand & improve UX (UC1), Agent + a failing test to root-cause & fix a real bug (UC2).

## Wrap-up

### 7. Reset (teardown is a separate skill)

When the session ends, tear down with the companion skill **`/kev-demo-grafana-explore-trace-reset`** (it drives `./scripts/demos/reset.sh`, with `--save-kit` to preserve kit work and `--stop-deps` for a full cold teardown). Quick reference:

```sh
./scripts/demos/reset.sh            # base branch, delete demo branch, clear state
./scripts/demos/reset.sh --save-kit # + commit kit to base (local), discard product changes
```

## Safe change constraints

| Allowed | Not allowed in live demo |
|---------|--------------------------|
| UC1: active diagnosis (`ExploreNoDataDiagnostics.tsx` + `PanelDataErrorView.tsx`, `eventsScope === 'explore'`) + `request` threading (`Explore`/`GraphContainer`/`ExploreGraph`) | `runQueries` / query pipeline |
| UC2: hardcoded series-cap fix in `limitSeries.ts` (`1` → `MAX_NUMBER_OF_TIME_SERIES`, consumed by `GraphContainer.tsx`) so `limitSeries.test.ts` passes | `pkg/api/ds_query.go` / `pkg/api/api.go` |
| Tiny i18n `t()` if required | Dashboard "No data" behavior in `PanelDataErrorView.tsx` |
| Professional, reversible UI / bug-fix | Auth, alerting, migrations, broad refactors |

## Related

- Orchestrator: `/kev-demo-kit` (`.cursor/skills/kev-demo-kit/SKILL.md`)
- Servers: `start-dev-server` / `dev-server-hot-reload`
- Notes: `scripts/demos/explore-trace/NOTES.md` · cheat sheet: `NOTES-BRIEF.md`
