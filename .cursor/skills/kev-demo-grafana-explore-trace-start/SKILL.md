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

Full talk track lives in `scripts/demos/explore-trace/NOTES.md`.

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
| Anything Docker (`setup.sh`, `docker …`, `make devenv`) | Docker socket blocked → "Docker not found" → **false TestData fallback** | Run unsandboxed |
| Frontend `yarn start` | FSEvents blocked → `EMFILE: too many open files` → watcher dies in ~10s | Run unsandboxed |
| `go mod download` / backend build | `GOMODCACHE`/`GOCACHE` redirected to a temp sandbox cache → re-downloads | Run unsandboxed (or pin `$HOME` caches) |

Also: **exported env vars persist across `Shell` calls** in a session — a stray `CHOKIDAR_USEPOLLING`/`WATCHPACK_POLLING` will poison later `yarn start` restarts. `unset` them.

## Steps

### 1. Setup (new branch)

```sh
./scripts/demos/setup.sh explore-trace
```

Optional: `--force` (recreate), `--from <base-branch>` (default `main`).

Confirm output shows branch `demo/explore-trace` and `.demo-state` written.

Then run profile preflight (prints checklist):

```sh
# invoked automatically by top-level setup when present; safe to re-run:
./scripts/demos/explore-trace/setup.sh
```

Read `scripts/demos/explore-trace/NOTES.md` and follow its beats/prompts.

#### Data source: Prometheus (preferred) / TestData (fallback)

The profile `setup.sh` auto-selects the data source. **Prometheus is strongly preferred** — the 2 a.m. on-call story only feels real when a genuine PromQL query returns empty. Renaming TestData to look like Prometheus is dishonest; don't.

- **Docker available** → starts a local Prometheus (`localhost:9090`) via `make devenv sources=prometheus` and provisions it as the default datasource (`conf/provisioning/datasources/demo-explore-trace.yaml`, gitignored).
  - **CRITICAL — run `setup.sh` OUTSIDE the Cursor sandbox** (`required_permissions: ["all"]`). The sandbox blocks the Docker socket, so `docker info` fails and setup **wrongly falls back to TestData even though Docker Desktop is running**. This was the single biggest source of confusion — always shell out unsandboxed for anything Docker.
  - **Basic auth:** the devenv Prometheus block (`web.yml`) requires `admin`/`admin`. `demo_prometheus_ok` and the provisioned datasource both send those creds; a hand-rolled datasource without `basicAuth: true` gets **401** and "fails" silently.
  - **First-run timing:** `make devenv sources=prometheus` builds several images (~1 min cold). The 30s health poll can expire mid-build → TestData fallback. Just **re-run `./scripts/demos/explore-trace/setup.sh`** once the container is up; it takes the fast reuse path and provisions the datasource (backend reload API, no restart needed).
  - Prometheus is a container independent of the git branch, so it's **reused across iterations** and left running by `reset.sh` (fast next spinup).
  - Verify end-to-end: `curl -s -u admin:admin http://localhost:3000/api/datasources/uid/demo-explore-trace-prom/health` → `"status":"OK"`.
- **Docker genuinely absent** → falls back to **TestData → No Data Points**. Setup never fails on this; the Run → `/api/ds/query` → Go path is identical either way. Say so out loud rather than pretending it's Prometheus.

### 2. Ensure servers (fast spinup)

Do **not** jump to Explore / Ask / Design Mode until `/login` returns **200**. Frontend compile alone is not enough.

#### Fast spinup sequence

1. **PATH** — verify `go version` and `node -v`. On this machine, local toolchains live under `~/.local`:
   ```sh
   export PATH="$HOME/.local/go/bin:$HOME/.local/node/bin:$PATH"
   ```
2. **Reuse if healthy** — if `curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/login` is `200` and yarn HMR is up, **skip restart**. Do not kill a mid-start backend (wastes `go mod download` progress).
3. **Warm modules** (cold machine only):
   ```sh
   # From agent Shell: use durable caches (sandbox may redirect under /var/folders/.../cursor-sandbox-cache/)
   export GOMODCACHE="${GOMODCACHE:-$HOME/go/pkg/mod}"
   export GOCACHE="${GOCACHE:-$HOME/Library/Caches/go-build}"
   go mod download   # wait for completion; retry once on proxy.golang.org timeout
   ```
   Prefer `required_permissions: ["all"]` (unsandboxed) for `go mod download` / backend build so caches stick.
4. **Start frontend + backend** (separate terminals):
   - Frontend: `yarn start` (required for Design Mode HMR)
   - Backend — prefer **non-race** for demos (faster first compile):
     - **Fastest restart** when `bin/grafana` exists and is recent (`bin/` is gitignored):
       ```sh
       go build -o bin/grafana ./pkg/cmd/grafana   # once after a successful non-race build
       ./bin/grafana server -profile -profile-addr=127.0.0.1 -profile-port=6000 -packaging=dev cfg:app_mode=development
       ```
     - Else:
       ```sh
       go run ./pkg/cmd/grafana -- server -packaging=dev cfg:app_mode=development
       ```
     Or `make run` (Air). Race is opt-in via `.go-race-enabled-locally` / `GO_RACE`.
   - **Avoid** `make run-go` for demos: it **hardcodes `-race`**, which makes cold compiles much slower. (`GO_RACE_FLAG` elsewhere does not apply to `run-go`.)
   - **Frontend watcher must run OUTSIDE the Cursor sandbox** (`required_permissions: ["all"]`). Inside the sandbox macOS FSEvents is blocked, so webpack falls back to per-file `fs.watch` and dies within ~10s with thousands of `EMFILE: too many open files, watch` (and the ts-checker crash). Do **not** work around it with `CHOKIDAR_USEPOLLING=true` — this repo's chokidar throws `ERR_INVALID_ARG_TYPE` (undefined interval) and kills `yarn start`. Also note exported env vars persist across agent Shell calls, so a stray `CHOKIDAR_USEPOLLING` will poison later restarts — `unset` it. A clean unsandboxed `yarn start` compiles in ~4s and reports `No typescript errors found`.
5. **Healthy check** — poll until ready before continuing:
   ```sh
   curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/login   # expect 200
   ```
   Profile `setup.sh` / `_lib.sh` helpers: `demo_login_ok`, `demo_wait_for_login`, `demo_warm_go_modules`.
6. **Error data (for UC1) is auto-generated per demo.** When Grafana is up, `setup.sh` starts a **continuous** background generator (`seed-traffic.sh --watch`, pid in `.demo-traffic.pid`; `reset.sh` stops it) that curls Grafana to produce a status-code mix on its own `grafana_http_request_duration_seconds_count` (scraped as `job="grafana"`): steady 200s plus a **401** spike and 404s. No extra container.
   - **⚠ 401s come from *unauthenticated* requests, NOT wrong passwords.** The generator hits an auth-required endpoint with no creds (`curl http://localhost:3000/api/admin/settings`, no `-u`) — that returns 401 without counting as a failed login. Never generate 401s with `curl -u admin:wrongpass …`: repeated bad-password attempts trip Grafana's brute-force login protection and **lock the admin account (~5 min)**, blocking `admin:admin` everywhere (UI + API) and breaking the whole demo. If admin login ever locks, stop the failing requests and wait ~5 min (the lockout auto-clears).
   - **Continuous, not one-shot:** scraped metrics (memory, `up`) are generated continuously by the running stack, but the 401/404 error signal only exists while we generate it — a one-shot burst decays out of `rate()[5m]` in ~5 min. The watcher keeps it fresh so **any** window (5m/15m/60m) shows the spike. 5xx can't be forced on Grafana, so the story uses a 4xx (401 auth) spike after a deploy.
   - If setup ran before Grafana was up, start it manually **unsandboxed** (`required_permissions: ["all"]`): `./scripts/demos/explore-trace/seed-traffic.sh --watch &` (or a one-shot `./scripts/demos/explore-trace/seed-traffic.sh` right before the beat).

#### Backend cold-start notes

- Cold `go mod download` / `proxy.golang.org` timeouts can stall for minutes before Grafana listens on `:3000`.
- Cursor agent Shell may sandbox `GOMODCACHE` / `GOCACHE` under `/var/folders/.../cursor-sandbox-cache/` — set durable `$HOME` caches (or reuse a warm sandbox cache) and prefer unsandboxed Shell for downloads/builds.
- Prefer `./bin/grafana server …` over `go run` / `make run-go` when a recent `bin/grafana` exists.
- Plugin installer may log version-compat errors (e.g. “not compatible with your Grafana version: 9.2.0”) — **harmless** for this empty-state demo if `/login` is 200.
- Login: `admin` / `admin`.

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
3. Use Cursor **Ask** to trace the Explore graph series-limiting pipeline to the culprit: `public/app/features/explore/Graph/limitSeries.ts`. It exports `limitSeriesForDisplay(data, showAllSeries)` and `MAX_NUMBER_OF_TIME_SERIES = 20`, but when not showing all it caps the series at a hardcoded **`1`** instead of `MAX_NUMBER_OF_TIME_SERIES` (a plausible leftover-debug hardcode). It's wired into `GraphContainer.tsx` (the `slicedData` memo calls `limitSeriesForDisplay(data, showAllSeries)`), while the "Showing only N series" `LimitedDataDisclaimer` still uses the real `MAX_NUMBER_OF_TIME_SERIES` — hence the disclaimer says 20 while the graph shows 1.
4. Show the failing unit test as the reproducible artifact:
   ```sh
   yarn jest public/app/features/explore/Graph/limitSeries.test.ts --watchAll=false
   ```
   (Currently **2 failed, 1 passed** — failure shows `Received length: 1` vs `Expected length: 20`.)
5. Cursor **Agent** fixes the cap (`1` → `MAX_NUMBER_OF_TIME_SERIES`) → test goes **green** → all 20 series render and match the disclaimer.

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
- Notes: `scripts/demos/explore-trace/NOTES.md`
