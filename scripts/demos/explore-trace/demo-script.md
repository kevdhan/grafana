# explore-trace — two Explore use cases (Ask · Design · Agent)

**Demo id:** `explore-trace`  
**Skills:** `/kev-demo-grafana-explore-trace-start` · `/kev-demo-grafana-explore-trace-reset`  
**Branch:** `demo/explore-trace` (setup creates, reset deletes)  
**Timebox:** ~30 min · **Login:** `admin` / `admin` → http://localhost:3000  
**Cheat sheet:** [`demo-script-short.md`](./demo-script-short.md)

## Customer pain (Value Map)

Engineers ask: *Where does Run query go?* · *Can Cursor change UI from the browser?* · *Can it root-cause a real bug?*

| UC | Story | Modes |
|----|-------|-------|
| **1** | No data → diagnose & fix the query | Ask → Canvas → Design Mode |
| **2** | Data looks wrong → find & fix a bug | Ask → Agent + failing test |

| Bucket | In this demo |
|--------|----------------|
| 1 — Codebase understanding | Ask: Run → `runQueries` → `POST /api/ds/query` → Go; Ask: series-limiting pipeline (UC2) |
| 2 — Agent edits | Design: active-diagnosis empty state (UC1); Agent: `limitSeries.ts` cap fix (UC2) |
| 3 — Skills | start / reset skills + demo kit |
| 4 — Terminal | Fast spinup, `/login` → 200, `seed-traffic.sh` |
| 8 — Browser | Agents Window + Design Mode; Cursor Canvas |

## Product story

```
UC1  No data → diagnose & fix (2 a.m. page)
  Ask:     Run → explore state → POST /api/ds/query → pkg/api/ds_query.go
  Canvas:  shareable Run → API → Go trace
  Design:  select No data → PanelDataErrorView.tsx → HMR

UC2  Data looks wrong → fix a bug
  Ask:     GraphContainer → limitSeriesForDisplay → limitSeries.ts
  Agent:   cap 1 → MAX_NUMBER_OF_TIME_SERIES → test green → ~20 series
```

Same running app for both: Ask/Design for UX understanding (UC1), Agent + test for a real bug (UC2).

---

## Preflight

1. `./scripts/demos/setup.sh explore-trace` (or the start skill) — creates `demo/explore-trace`; profile setup **plants UC2**, provisions Prometheus, starts traffic when `:3000` is up, prints `=== DEMO READINESS ===`. **Run unsandboxed** so Docker works.
2. Follow the readiness gate — do not hand-plant or invent server starts. If `NOT READY`, start only missing FE/BE as durable Cursor background shells (`block_until_ms: 0`, `exec …`), then re-run `./scripts/demos/explore-trace/setup.sh`. Never `nohup … &` in a one-shot Shell. Reset stops FE/BE by default (next chat owns terminals); Prometheus stays unless `--stop-deps`.
3. **PATH:** `export PATH="$HOME/.local/go/bin:$HOME/.local/node/bin:$PATH"`
4. Reuse if `login: OK`. Else:
   - Pin Go caches if sandboxed: `GOMODCACHE=$HOME/go/pkg/mod`, `GOCACHE=$HOME/Library/Caches/go-build`
   - Frontend: `yarn start` **unsandboxed**; `unset CHOKIDAR_USEPOLLING CHOKIDAR_INTERVAL WATCHPACK_POLLING`
   - Backend: `./bin/grafana server …` if present; else non-race `go run …`. Avoid `make run-go` (`-race`).
5. Start product beats only when gate says `READY`.
6. Traffic: setup starts `seed-traffic.sh --watch` (`.demo-traffic.pid`). **401s = unauthenticated requests — never wrong passwords** (locks admin ~5 min).
7. Plugin version-compat log noise is OK if `/login` is 200.
8. Shortcuts: Agents Window (`Cmd+Shift+P`) · Design Mode `Cmd+Shift+D`

### Data source (Prometheus preferred)

- Setup starts Prometheus on `:9090` (`make devenv sources=prometheus`) and provisions it as default (`conf/provisioning/datasources/demo-explore-trace.yaml`, gitignored).
- **Unsandboxed setup required** — sandbox blocks Docker → false TestData fallback.
- Prometheus basic auth: `admin` / `admin`. Verify:  
  `curl -s -u admin:admin http://localhost:3000/api/datasources/uid/demo-explore-trace-prom/health` → `"status":"OK"`.
- Cold devenv ~1 min; if 30s poll expires → TestData; re-run profile setup once `:9090` is healthy.
- No Docker: TestData → No Data Points still works for Ask path; say so out loud. Full UC1 diagnosis needs Prometheus label API.
- Reset leaves Prometheus up; cold teardown: `scripts/demos/explore-trace/reset.sh --stop-deps`.

---

## Live demo beats

### Beat 0 — Setup (~2–5 min cold; ~0 if reusing)

- Confirm `demo/explore-trace` + `.demo-state`; follow Preflight; login only after `/login` → 200.
- Do not kill a mid-start backend.

**Talk:** “We keep customer demos on disposable `demo/*` branches so reset is one script.”

---

## Use Case 1 — No data → diagnose & fix the query

On-call is paged for errors, runs the usual 5xx query, hits **No data** (metric renamed after deploy). Diagnostic empty state does triage; fixing to a real metric reveals the seeded **401 spike**.

### Beat 1 — Product context: the 2 a.m. page (~4 min)

**Frame Explore:** *“Explore is Grafana’s ad-hoc investigation surface — not a saved dashboard. On-call freehands a query during an incident; dashboards are the known signals.”*

**On-call story (say while you drive):**

> **2:04 a.m.** PagerDuty: `checkout-api — error ratio > 5% (SLO burn 14.4x)`. I open Explore → Prometheus → my usual 5xx query → **“No data.”**
>
> 2 a.m. math: wrong query? OTel rename (`http_requests_total` → something else)? `status` vs `http_status_code`? `job` vs `service`? Wrong tenant? Exporter dead (`absent()`)?
>
> Empty state answers **none** of that — grey “No data,” dead center. That’s a 2-minute fix vs a 40-minute goose chase.

| Detail | Why it sells |
|--------|----------------|
| SLO burn-rate alert | How teams actually page |
| `http_requests_total{status=~"5.."}` | Canonical RED error query |
| OTel rename / label drift | Common post-deploy “No data” |
| `job` vs `service` | #1 self-inflicted miss |

Beat 4 builds an empty state that **checks** these against the datasource — not tip lists.

#### Drive the empty state (Prometheus)

1. Open `/explore` → **Prometheus**
2. Empty query (metric doesn’t exist here; no `checkout` job):
   ```promql
   sum(rate(http_requests_total{job="checkout", status=~"5.."}[5m]))
   ```
3. After Beat 4: diagnosis names missing metric + bad label filter → **Copy fixed query**
4. Reveal query (seeded **401 spike**):
   ```promql
   sum by (status_code) (rate(grafana_http_request_duration_seconds_count[5m]))
   ```
5. Optional: run `up` first (graph), then the empty query (dead end).

**TestData fallback:** scenario **No Data Points** → `NoData` component (different from graph empty state). Ask path still works; diagnosis upgrade needs Prometheus.

Confirm centered **No data** before Ask / Design Mode.

**Talk:** “This is the 2 a.m. dead end — next we trace where Run goes, then improve this empty state from the browser.”

#### Optional — Explain toggle

Prometheus **Explain** annotates PromQL in plain English. It does not change execution. Use it to reinforce the pitch:

> “Grafana explains the query inline — but when results are empty, it just says ‘No data.’ That’s the gap we close with Cursor.”

| Layer | Who |
|-------|-----|
| Query (what PromQL does) | Grafana Explain |
| Codebase (Run → API → Go) | Cursor Ask (Beat 2) |
| Empty-state UX | Cursor Design Mode (Beat 4) |

### Beat 2 — Trace with Ask (~8 min)

Switch to **Ask**. Prompts:

1. **Where is Run?**  
   > In Grafana Explore, where is the Run query button defined? Start from ExploreToolbar and show me the click handler.

2. **Trace to network**  
   > From that Run action, trace how Explore executes the query — through frontend state / `runQueries` — until the network call. What HTTP method and path?

3. **Go handler**  
   > Which Go handler serves `POST /api/ds/query`? Point at `pkg/api/ds_query.go` and summarize in one paragraph.

**Map:** `ExploreToolbar` → `runQueries` → `runRequest` → `POST /api/ds/query` → `pkg/api/api.go` → `QueryMetricsV2`

**Talk:** “Ask is for understanding without editing yet.”

**Canvas:** After the trace, generate `explore-run-trace.canvas.tsx` (Run → API → Go) as a shareable artifact — not buried in chat.

**Talk:** “Canvas is the living source of truth for investigations like this.”

### Beat 3 — Agents Window (~2 min)

1. `Cmd+Shift+P` → **Open Agents Window**
2. Browser → http://localhost:3000/explore
3. Empty state still visible

**Talk:** “Same app, inside Cursor’s browser so Design Mode can target what we see.”

### Beat 4 — Design Mode: diagnostic empty state (~7 min)

**Lesson:** Graph “No data” is **`PanelDataErrorView.tsx`** (`PanelDataErrorView` → … → `ExploreGraph`) — **not** `NoData.tsx`. Trust the Design Mode selection.

**Caveats:** Agents Window browser · `Cmd+Shift+D` after load · edits **source** (not CSS-only) · needs `yarn start` HMR.

**Steps:**

1. `Cmd+Shift+D`
2. Click **No data** on the Prometheus graph → resolves to `PanelDataErrorView.tsx`
3. Paste this prompt (Agent-scale, multi-file — copy verbatim):

   > **Goal:** In Grafana Explore, turn the panel "No data" empty state into an *active diagnosis* that explains **why** a Prometheus query returned nothing — not a generic message.
   >
   > **Scope:** Explore only. `PanelDataErrorView.tsx` is shared with dashboards, so gate on panel context `eventsScope === 'explore'` (Explore's panel context doesn't set `app`). Dashboards keep minimal "No data".
   >
   > **Data needed:** failed query text + datasource uid from `data.request.targets`. Thread `queryResponse.request` from `Explore.tsx` → `GraphContainer` → `ExploreGraph` into `PanelRenderer` `data`.
   >
   > **Behavior** (via `getBackendSrv`: `GET /api/datasources/uid/{uid}/resources/api/v1/label/__name__/values` and `/api/v1/label/{name}/values`):
   > 1. Parse metric name and label matchers from the query.
   > 2. Missing metric → *"No metric named X"* + *"Did you mean …"* (ranked) + **"Copy fixed query"**.
   > 3. Exact (`=`) label matcher with no matching series → show valid values.
   > 4. Echo time range + failed query (Copy). Fallback: short checklist.
   >
   > **Constraints:** i18n via `t()`; no TypeScript `as` assertions; small dedicated component; don't change dashboard/panel-editor behavior.

4. **Produces:** `ExploreNoDataDiagnostics.tsx` + Explore-scoped `PanelDataErrorView.tsx` + request threading. Demo result: missing `http_requests_total` + `job="checkout"` matches nothing.
5. Prefer user-driven selection; agent implements across files.

**Talk:** “Visual selection → multi-file feature: empty state calls Prometheus’s label API — metric missing, which filter failed, fix one click away.”

**If you used Explain:** “We extended that explain-as-you-go spirit to the empty state — without leaving the browser.”

### Beat 5 — Verify + reveal (~3 min)

- Confirm HMR: time range, failed query + Copy, “did you mean”, culprit label + valid values
- Run the reveal query (Beat 1) → **401 spike**
- Optional Ask: which file changed? → `PanelDataErrorView.tsx`

**Talk:** “The empty state did the diagnosis; the fix reveals the actual incident signal.”

---

## Use Case 2 — Data looks wrong → find & fix a bug

Planted by `plant-uc2.sh` during setup; removed by `unplant-uc2.sh` / reset.

> **Say out loud:** intentional demo artifact — Grafana does not ship this.

### Beat 5b — Agent fix (~6 min)

1. Query many series:
   ```promql
   prometheus_http_requests_total
   ```
   (~56 series here)
2. Graph draws **1 line**; disclaimer: *"Showing only 20 series — Show all 56"* → mismatch = the tell.
3. **Ask** (trace + Canvas):
   > In Grafana Explore the graph renders only 1 series even though the query returns 56 and the disclaimer says "Showing only 20 series." Trace the series-limiting pipeline from the query result through `GraphContainer` to the exact function that caps the series, and identify the bug. Then generate a Cursor Canvas with a visual architecture diagram of the whole path — user query → `runQueries`/`runRequest` → `POST /api/ds/query` → Go handler → data frames back → `GraphContainer` `slicedData` → `limitSeriesForDisplay` → `PanelRenderer`/graph — and **highlight the node where the bug is** (the series cap).

   **Expected:** `limitSeries.ts` — `limitSeriesForDisplay` caps at hardcoded **`1`** instead of `MAX_NUMBER_OF_TIME_SERIES` (disclaimer still uses the real constant).

4. **Failing test** (optional RED yourself; prefer Agent loop):
   ```sh
   yarn jest public/app/features/explore/Graph/limitSeries.test.ts --watchAll=false
   ```
   (2 failed, 1 passed — length 1 vs 20)

5. **Agent** prompt:
   > `limitSeriesForDisplay` in `limitSeries.ts` caps the series at 1 instead of `MAX_NUMBER_OF_TIME_SERIES`. Fix it, then validate: (1) run `limitSeries.test.ts` until green, and (2) run a visual test with Playwright harness `scripts/demos/explore-trace/shot.mjs` against `prometheus_http_requests_total` and confirm the graph renders ~20 series instead of 1.

   ```sh
   export PLAYWRIGHT_BROWSERS_PATH="$HOME/Library/Caches/ms-playwright"
   EXPR='prometheus_http_requests_total' OUT='scripts/demos/explore-trace/.shot-uc2-after.png' \
     node scripts/demos/explore-trace/shot.mjs
   ```

**Talk:** “Fixed and proved twice — green unit test *and* a screenshot of the graph. Ask/Design improved UX (UC1); Agent + test fixed a real bug (UC2).”

---

### Beat 6 — Reset (~1 min)

```sh
./scripts/demos/reset.sh
./scripts/demos/reset.sh --save-kit   # local commit of kit on base; discard product edits
```

Confirm: base branch, `.demo-state` gone, `demo/explore-trace` deleted, traffic stopped.

---

## Safe change / do not touch

| Safe | Do not touch |
|------|----------------|
| UC1: `ExploreNoDataDiagnostics.tsx`, Explore-scoped `PanelDataErrorView.tsx`, request threading (`Explore` → `GraphContainer` → `ExploreGraph`) | `runQueries` / query pipeline |
| UC2: `limitSeries.ts` (`1` → `MAX_NUMBER_OF_TIME_SERIES`) | `pkg/api/ds_query.go`, `pkg/api/api.go` |
| Professional copy; optional `t()` | Dashboard No data, auth, alerting, migrations, broad refactors |

## Reset checklist

- [ ] `./scripts/demos/reset.sh` done
- [ ] On base branch · `.demo-state` removed · `demo/explore-trace` deleted

## Success criteria

- Start skill → this script; reset skill tears down
- Traffic keeps 401/404 spike fresh on `grafana_http_request_duration_seconds_count`
- **UC1:** Ask map (+ Canvas); Design Mode → active diagnosis via HMR; Copy fixed query → 401 spike
- **UC2:** Ask → `limitSeries.ts`; Agent fix → test green → ~20 series match disclaimer
- Reset → clean base, planted bug gone
