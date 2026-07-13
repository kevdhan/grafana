# explore-trace — two Explore use cases (Ask · Design · Agent)

**Demo id:** `explore-trace`  
**Skills:** `/kev-demo-grafana-explore-trace-start` (start/run) · `/kev-demo-grafana-explore-trace-reset` (teardown)  
**Branch:** `demo/explore-trace` (created by setup, deleted by reset)  
**Timebox:** ~30 min  
**Login:** `admin` / `admin` → `http://localhost:3000`

## Customer pain (Value Map)

Engineers ask: *“Where does Run query actually go?”*, *“Can Cursor change UI from what I see in the browser?”*, and *“Can it actually root-cause and fix a real bug?”*

This demo answers all three across **two Explore use cases**:

- **Use Case 1 — No data → diagnose & fix the query.** Ask maps Explore Run → API → Go; Design Mode builds an *active-diagnosis* empty state that queries the datasource to explain **why** (metric "did you mean" + which label filter matched nothing), one-click fix.
- **Use Case 2 — Data looks wrong → find & fix a bug.** Ask traces the graph data pipeline; Agent fixes a units bug and turns a failing unit test green.

| Bucket | Story in this demo |
|--------|--------------------|
| 1 — Codebase understanding | Ask: Run button → `runQueries` → `POST /api/ds/query` → Go handler; Ask traces the Explore graph scaling pipeline (UC2) |
| 2 — Agent edits | Design Mode builds the active-diagnosis empty state (`ExploreNoDataDiagnostics.tsx` + `PanelDataErrorView.tsx`) (UC1); Agent fixes the units bug in `scaleSeries.ts` (UC2) |
| 3 — Skills / orchestration | `/kev-demo-grafana-explore-trace-start` + `/kev-demo-grafana-explore-trace-reset` + demo kit setup/reset |
| 4 — Terminal / servers | Fast spinup: warm `go mod download`, non-race backend, `/login` → 200 before beats; `seed-traffic.sh` for real error data |
| 8 — Browser tool | Agents Window browser + Design Mode (`Cmd+Shift+D`); Cursor Canvas as a shareable trace artifact |

## Preflight

1. `./scripts/demos/setup.sh explore-trace` (or via `/kev-demo-grafana-explore-trace-start`) — creates `demo/explore-trace`; profile `setup.sh` starts/provisions Prometheus and warms Go modules when `:3000` is cold. **Run unsandboxed** (`required_permissions: ["all"]`) so it can reach Docker (see Data source note).
2. **PATH** — `go version` / `node -v` (often need `export PATH="$HOME/.local/go/bin:$HOME/.local/node/bin:$PATH"`)
3. **Reuse if healthy** — `curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/login` → `200` means skip restart
4. Else warm + start:
   - Pin durable Go caches if agent Shell sandboxed them (`GOMODCACHE=$HOME/go/pkg/mod`, `GOCACHE=$HOME/Library/Caches/go-build`); prefer unsandboxed Shell for download/build
   - `go mod download` (wait; retry once on proxy timeout)
   - Frontend: `yarn start` — **must run outside the Cursor sandbox** (`required_permissions: ["all"]`). Sandboxed, FSEvents is blocked and webpack floods `EMFILE: too many open files, watch`, killing the watcher in ~10s. Don't try `CHOKIDAR_USEPOLLING=true` (this repo's chokidar crashes with `ERR_INVALID_ARG_TYPE`); and `unset` any polling env vars since agent Shell env persists across calls.
   - Backend: if recent `bin/grafana` exists → `./bin/grafana server -profile -profile-addr=127.0.0.1 -profile-port=6000 -packaging=dev cfg:app_mode=development` (build once with `go build -o bin/grafana ./pkg/cmd/grafana`); else non-race `go run ./pkg/cmd/grafana -- server -packaging=dev cfg:app_mode=development`  
     Or `make run`. **Avoid** `make run-go` (hardcodes `-race`, slow cold compile)
5. **Health gate** — do not start product beats until `/login` is `200` (frontend compile alone is not enough)
6. **Error data is auto-generated per demo run.** When Grafana is up, `setup.sh` starts a **continuous** background traffic generator (`seed-traffic.sh --watch`, pid in `.demo-traffic.pid`) that curls Grafana to produce a steady status-code mix on its own `grafana_http_request_duration_seconds_count` metric (scraped as `job="grafana"`): steady 200s plus **401** (auth failures) and 404s. No extra container. `reset.sh` stops it.
   - **Why continuous, not one-shot:** scraped metrics (memory, `up`, request counts) are already generated continuously by the running stack, but the 401/404 *error* signal only exists while we generate it — a one-shot burst decays out of `rate()[5m]` in ~5 min. The watcher keeps 401/404 fresh so **any** time window (5m / 15m / 60m) shows the spike.
   - If setup ran before Grafana was up (so it couldn't start), start it manually (unsandboxed): `./scripts/demos/explore-trace/seed-traffic.sh --watch &` — or a one-shot burst right before the beat: `./scripts/demos/explore-trace/seed-traffic.sh`.
7. Plugin version-compat log noise is OK if `/login` is 200
8. Know shortcuts: Agents Window (`Cmd+Shift+P` → “Open Agents Window”); Design Mode `Cmd+Shift+D`

### Data source (Prometheus strongly preferred, TestData fallback)

Prometheus makes the 2 a.m. story authentic — a real PromQL query that genuinely returns empty. Don't fake it by renaming TestData.

- `setup.sh` starts a local Prometheus (`localhost:9090`) via `make devenv sources=prometheus` and provisions it as the **default** datasource (`conf/provisioning/datasources/demo-explore-trace.yaml`, gitignored).
- **Run `setup.sh` unsandboxed** (`required_permissions: ["all"]`). The Cursor sandbox blocks the Docker socket, so setup thinks Docker is absent and **falsely falls back to TestData even when Docker Desktop is running**. (Verify Docker for real with an unsandboxed `docker ps`.)
- **Basic auth:** devenv Prometheus (`web.yml`) requires `admin`/`admin`; the provisioned datasource and `demo_prometheus_ok` send those creds. Without them, `/-/healthy` and queries return **401**.
- **First-run build ~1 min** (pulls/builds images). If the 30s health poll expires mid-build → TestData fallback; just re-run `./scripts/demos/explore-trace/setup.sh` once the container is up (fast reuse path, provisions via reload API — no backend restart).
- Verify: `curl -s -u admin:admin http://localhost:3000/api/datasources/uid/demo-explore-trace-prom/health` → `"status":"OK"`.
- If Docker is **genuinely** absent, TestData → No Data Points still works; the Run → `/api/ds/query` → Go path is identical. Say so out loud instead of pretending it's Prometheus.
- Prometheus is a container independent of the git branch, so it's reused across iterations (fast). Top-level `reset.sh` leaves it running; for a cold teardown run `scripts/demos/explore-trace/reset.sh --stop-deps` (calls `make devenv-down`).

## Product story (two use cases)

```
UC1  No data → diagnose & fix the query (the 2 a.m. page)
  Ask:     Run query → explore state → POST /api/ds/query → pkg/api/ds_query.go
  Canvas:  capture the Run → API → Go trace as a shareable artifact
  Design:  Agents Window → select the No data DOM node → prompt → edit
           PanelDataErrorView.tsx (the Explore-scoped empty state) → HMR

UC2  Data looks wrong → find & fix a bug with Cursor
  Ask:     Explore graph → dataWithConfig memo → applyExploreByteScaling → scaleSeries.ts
  Agent:   fix the byte-scaling divisor → failing unit test goes green → graph corrects
```

Same running app for both use cases — Ask/Design to understand & improve UX (UC1), Agent + a failing test to root-cause & fix a real bug (UC2).

---

## Live demo beats

### Beat 0 — Setup (~2–5 min cold; ~0 if reusing)

- Run setup script; confirm branch `demo/explore-trace` and `.demo-state`
- Follow **Preflight** fast spinup; login only after `/login` → 200
- Do **not** kill a mid-start backend — that wastes module download progress

**Talk:** “We keep customer demos on disposable `demo/*` branches so reset is one script.”

---

## Use Case 1 — No data → diagnose & fix the query (the 2 a.m. page)

Beats 1–5. On-call is paged for an error-rate spike, runs the 5xx query they always reach for, and hits **No data** — because a deploy renamed the metric. The improved diagnostic empty state does the triage; fixing the query to a real metric reveals the actual **401 spike** seeded by `seed-traffic.sh`.

> **Error data:** `setup.sh` runs `seed-traffic.sh --watch` in the background (Preflight step 6), so the 401 spike stays fresh for 5m/15m/60m windows for the whole session. `reset.sh` stops it.

### Beat 1 — Product context: the 2 a.m. page (~4 min)

**Frame Explore first (one line):** *“Explore is Grafana’s ad-hoc investigation surface — not a saved dashboard. It’s where on-call engineers freehand a query during an incident, then pivot metrics → logs → traces. Dashboards are the known-important signals; Explore is for the question nobody built a panel for yet.”*

**Then tell the on-call story (say it out loud while you drive):**

> **2:04 a.m., Saturday. PagerDuty fires:** `checkout-api — error ratio > 5% (SLO burn rate 14.4x)`. I’m on call.
>
> I open Explore, pick our **Prometheus** datasource, and reach for the query I always run first — 5xx rate for the service:
>
> ```promql
> sum(rate(http_requests_total{job="checkout", status=~"5.."}[5m]))
> ```
>
> I set the range to the last 15 minutes, hit **Run**, and get… **“No data.”**
>
> Now I’m doing the 2 a.m. math: Is checkout actually fine and my query wrong? Did last night’s deploy that moved us to OpenTelemetry rename `http_requests_total` → `http_server_requests_seconds_count`? Did the label change from `status` to `http_status_code`? Is `job="checkout"` even right — or is it `service="checkout"` now? Wrong Prometheus tenant? Did the exporter die so the series went *absent*?
>
> Grafana’s empty state answers **none** of that. It just says “No data,” greyed out, dead center. That blank screen is the difference between a 2-minute fix and a 40-minute goose chase.

**Why this scenario is realistic (the details that sell it):**

| Detail | Why it lands |
|--------|--------------|
| SLO **burn-rate** alert (14.4x) | How modern teams actually page (Google SRE multi-window), not raw thresholds |
| `http_requests_total{status=~"5.."}` | Canonical RED-method error query; every Prometheus user recognizes it |
| OTel migration renamed the metric | Very common real cause of “No data” — metric/label drift after a deploy |
| `absent()` / stale series | Subtle case: query is right but the exporter stopped, so nothing returns |
| `job` vs `service` label mismatch | The #1 self-inflicted “No data” |

That last column is exactly what the empty state should help with — and in Beat 4 we prompt Design Mode to build an empty state that **actively checks** them against the datasource (does the metric exist? does each label filter match anything?), not just list them as tips.

#### Getting the empty state on screen

**Preferred — real Prometheus datasource** (provisioned by `setup.sh` when Docker is up; see `demo_ensure_prometheus`):

1. Open `/explore`, pick **Prometheus**
2. Run the 5xx query the on-call always reaches for — returns nothing because a deploy renamed the metric (`http_requests_total` doesn't exist here):
   ```promql
   sum(rate(http_requests_total{job="checkout", status=~"5.."}[5m]))
   ```
   (No `checkout` job is scraped locally, so this returns empty → authentic “No data”.)
3. The **active-diagnosis** empty state (Beat 4) queries the datasource and names the cause: *"No metric named `http_requests_total` — did you mean `prometheus_http_requests_total`?"* and *"the filter `job="checkout"` matches no series"* → the fix is one click ("Copy fixed query").
4. **Fix to the real metric and see data** — the graph fills in and shows the real **401 spike** seeded earlier (the errors they were paged for):
   ```promql
   sum by (status_code) (rate(grafana_http_request_duration_seconds_count[5m]))
   ```
   (`prometheus_http_requests_total` is another real metric you can show.) Talk point: **the empty state did the diagnosis; the fix reveals the actual incident signal.**
5. Optional contrast: run `up` first (returns series → a graph), then the empty 5xx query, to show the *difference* between “data” and the dead-end empty state.

> **Basic auth:** the devenv Prometheus block (`web.yml`) requires `admin`/`admin`. The provisioned datasource and the `demo_prometheus_ok` health check both send those creds — if you provision Prometheus by hand, set `basicAuth: true` + `basicAuthUser/Password`, or `/-/healthy` and queries return **401** (this previously caused setup to fall back to TestData even though the container was up).
>
> **First-run timing:** `make devenv sources=prometheus` builds several images (~1 min cold). The 30s health poll can expire mid-build and fall back to TestData; just re-run `./scripts/demos/explore-trace/setup.sh` once the container is up — it takes the fast reuse path and provisions the datasource.

**Fallback — TestData** (no Docker / Prometheus not running):

1. Open `/explore`, pick **TestData**
2. Scenario **No Data Points** (`no_data_points`) → Explore renders the `NoData` component (`data-testid="explore-no-data"`) — a *different* Explore empty state from the graph one we improve in Beat 4
3. Say out loud: *“TestData is a mock backend so this never flakes; the Run → API → Go path we trace next is identical to real Prometheus.”*

> **Note:** the active-diagnosis empty state (Beat 4) lives on the **Prometheus graph** path (`PanelDataErrorView.tsx`) and needs the datasource's label API, so prefer Prometheus to land the full Use Case 1 payoff. With TestData you still get an authentic “No data” for the Ask trace, but not the diagnostic upgrade.

Confirm the centered **No data** empty state is visible before switching to Ask / Design Mode.

**Talk:** “This is the real Explore dead end customers hit at 2 a.m. — we’re about to trace where Run goes, then improve this empty state from the browser.”

#### Optional hook — the "Explain" toggle (if a customer notices it)

The Prometheus query builder has an **Explain** toggle that annotates each part of the PromQL in plain English (`fetch series` → `rate()` → `sum()`). It explains **what the query computes** — a native, hand-written authoring aid. It does *not* run anything differently.

Use it to your advantage — it **reinforces** the empty-state pitch, it doesn't compete with it:

> “Grafana clearly believes in inline explanation — see this Explain toggle walking through my PromQL. But that philosophy stops at the results panel: when the query returns nothing, the empty state just says ‘No data.’ It doesn’t say *why* or *what to try next*. That’s exactly the gap we’ll close with Cursor — extending Grafana’s own explain-as-you-go spirit to the empty state.”

**Keep three layers distinct** (pre-empt a customer conflating them):

| Layer | Who explains it |
|-------|-----------------|
| The **query** (what this PromQL does) | Grafana’s `Explain` toggle (native) |
| The **codebase** (how Run → API → Go executes) | Cursor **Ask** (Beat 2) |
| The **empty-state UX** (what to do on “No data”) | Cursor **Design Mode** (Beat 4) |

Explain = your query. Ask = the code. Design Mode = the UI. No overlap.

### Beat 2 — Trace with Ask (~8 min)

Switch Cursor to **Ask** mode. Use these prompts (adapt lightly; keep the path):

1. **Where is Run?**  
   > In Grafana Explore, where is the Run query button defined? Start from ExploreToolbar and show me the click handler.

2. **Trace to network**  
   > From that Run action, trace how Explore actually executes the query — through frontend state / `runQueries` — until the network call. What HTTP method and path does it hit?

3. **Which Go handler?**  
   > Which Go handler serves `POST /api/ds/query`? Point me at `pkg/api/ds_query.go` (or the real entry) and summarize what it does in one paragraph.

**Expected map (for FE coaching):**

`ExploreToolbar` (Run) → `runQueries` → `runRequest` → `POST /api/ds/query` → `pkg/api/api.go` route → `pkg/api/ds_query.go` `QueryMetricsV2`

**Talk:** “Ask is for understanding the system without editing it yet.”

#### Capture it in a Cursor Canvas (shareable source of truth)

After the Ask trace, generate/open a **Cursor Canvas** (`explore-run-trace.canvas.tsx`) that captures the Run → API → Go path as a standalone artifact engineers can open beside chat and share with teammates — instead of a trace buried in a chat thread.

**Talk:** “Canvas is the team's living source-of-truth for investigations like this — it doesn't disappear when the chat scrolls. We can capture the Use Case 2 bug RCA the same way.”

### Beat 3 — Agents Window browser (~2 min)

1. `Cmd+Shift+P` → **Open Agents Window**
2. Open Browser → `http://localhost:3000/explore`
3. Ensure the empty state is still visible (re-run the empty Prometheus/TestData query if needed)

**Talk:** “Same app, now inside Cursor’s browser so Design Mode can target what we see.”

### Beat 4 — Design Mode: build the diagnostic empty state (~7 min)

**Where the empty state actually lives (say this — it's the lesson):**

The “No data” state for an empty Prometheus **graph** query is rendered by the shared panel component **`public/app/features/panel/components/PanelDataErrorView.tsx`** (stack: `PanelDataErrorView > TimeSeriesPanel > … > ExploreGraph`) — **not** `NoData.tsx`, which is a *different* Explore empty state. Selecting the real DOM node in Design Mode revealed the true component. **Trust the selection over the assumption** — that's how you find the right file fast.

**Caveats (say out loud — don’t oversell):**

- Design Mode lives in the **Agents Window** browser ([Cursor Design Mode docs](https://cursor.com/docs/agent/design-mode))
- Toggle **`Cmd+Shift+D`** after the page has fully loaded
- Selection + natural-language prompt → agent edits **source** (not a live CSS-only sidebar)
- Needs **`yarn start`** HMR so the empty state updates without a manual rebuild

**Steps:**

1. Enable Design Mode (`Cmd+Shift+D`)
2. Click the **No data** text on the Prometheus graph — the selection resolves to `PanelDataErrorView.tsx`
3. Give the **structured prompt** below. This is an **Agent-scale, multi-file change** kicked off from the visual selection — not a CSS tweak — so it names the scope, the data it needs (which must be threaded in), and the exact behavior. Copy it verbatim to reproduce what's implemented here:

   > **Goal:** In Grafana Explore, turn the panel "No data" empty state into an *active diagnosis* that explains **why** a Prometheus query returned nothing — not a generic message.
   >
   > **Scope:** Explore only. `PanelDataErrorView.tsx` is shared with dashboards, so gate the new behavior on the panel context `eventsScope === 'explore'` (Explore's panel context doesn't set `app`). Dashboards must keep the minimal "No data".
   >
   > **Data needed:** the failed query text + datasource uid, from the panel's `data.request.targets`. `ExploreGraph` doesn't pass `request` today — thread `queryResponse.request` from `Explore.tsx` → `GraphContainer` → `ExploreGraph` into the `PanelRenderer` `data`.
   >
   > **Behavior** (query the datasource resource proxy via `getBackendSrv`: `GET /api/datasources/uid/<uid>/resources/api/v1/label/__name__/values` for metric names, `/api/v1/label/<name>/values` for a label's values):
   > 1. Parse the metric name and label matchers from the query.
   > 2. If the metric name isn't in the datasource's metric list → show *"No metric named X exists"* + the closest real metric names (*"Did you mean …"*, ranked by similarity) + a **"Copy fixed query"** button that swaps in the top suggestion.
   > 3. For each exact (`=`) label matcher whose value isn't among that label's real values → show *"The filter name=\"value\" matches no series"* + the valid values.
   > 4. Also echo the queried time range and the failed query (with a Copy button). If nothing conclusive is found, fall back to a short "things to check" checklist.
   >
   > **Constraints:** user-visible strings via i18n (`t()` / `<Trans>`); no TypeScript type assertions (`as`); keep the diagnosis in a small dedicated component; don't change dashboard or panel-editor behavior.

4. **What this produces (already implemented here):**
   - New component `public/app/features/panel/components/ExploreNoDataDiagnostics.tsx` — async diagnosis via the resource proxy (metric "did you mean" + label-matcher isolation).
   - `PanelDataErrorView.tsx` renders it **Explore-scoped** (query echo + time range + Copy retained; checklist as fallback when the datasource can't be introspected).
   - `request` threaded through `Explore.tsx` → `GraphContainer.tsx` → `ExploreGraph.tsx` so the empty state actually has the query + datasource uid.
   - Result on the demo query: *"No metric named `http_requests_total` — did you mean `prometheus_http_requests_total`?"* + *"The filter `job="checkout"` matches no series; values: grafana, node_exporter, prometheus…"*
5. Prefer **user-driven** selection in the browser; the agent implements across the files above.

**Talk:** “Visual selection → a real, multi-file feature: the empty state now calls Prometheus's own label API to tell you the metric doesn't exist and which filter matched nothing — with the fix one click away. That's not a mockup; it's a feature Grafana could ship.”

**Callback to the Explain hook (if you used it in Beat 1):** “Remember Grafana’s Explain toggle explaining the query? We just extended that same explain-as-you-go spirit to the empty state — the one place Grafana left blank — without leaving the browser.”

### Beat 5 — Verify + reveal the incident (~3 min)

- Confirm the Explore empty state updated via HMR (time range, failed query + Copy, the "No metric named … did you mean" suggestion, and the culprit label filter with its valid values)
- **Fix the query** to a real metric and watch the graph fill in with the seeded **401 spike** — the errors they were paged for:
  ```promql
  sum by (status_code) (rate(grafana_http_request_duration_seconds_count[5m]))
  ```
- Optional Ask: “What file changed for the Explore empty state?” → `PanelDataErrorView.tsx`

**Talk:** “The empty state did the diagnosis; the fix reveals the actual incident signal.”

---

## Use Case 2 — Data looks wrong → find & fix a bug with Cursor

A planted, safe, reversible bug (it lives on the `demo/explore-trace` branch and is discarded by reset). This is where Cursor **Agent** root-causes and fixes a real defect, with a **failing unit test** as the reproducible artifact.

> **This bug is an intentional demo artifact** — say so out loud so nobody thinks Grafana ships it.

### Beat 5b — Data looks wrong → Agent fix (~6 min)

1. In Explore (Prometheus), query a memory metric that **returns data**:
   ```promql
   go_memstats_alloc_bytes{job="grafana"}
   ```
2. The graph shows values **~1000× too large** (GB rendered as if TB) — a **units bug**.
3. Use Cursor **Ask** to trace the Explore graph data pipeline to the culprit: `public/app/features/explore/Graph/scaleSeries.ts`. The function `bytesToMegabytes` divides bytes by `1000` (kilobytes-ish) instead of the correct mebibyte divisor `1024 * 1024`. It's wired into `ExploreGraph.tsx` (`dataWithConfig` memo → `applyExploreByteScaling`), **scoped to byte-named series** so Use Case 1's rate/status series are unaffected.
4. Show the reproducible artifact — a **failing unit test**:
   ```sh
   yarn jest public/app/features/explore/Graph/scaleSeries.test.ts --watchAll=false
   ```
   (Currently **3 failed, 1 passed** — the failure shows `Received [1048.576, 8388.608]` vs `Expected [1, 8]`.)
5. Cursor **Agent** fixes the divisor (`bytes / (1024 * 1024)`), the test goes **green**, and the memory graph corrects.

**Talk:** “Two Cursor modes across two use cases: Ask/Design to understand & improve the UX (UC1), Agent + a failing test to root-cause & fix a real bug (UC2). Capture this RCA in a Canvas too if the customer wants a shareable record.”

---

### Beat 6 — Reset (~1 min)

```sh
./scripts/demos/reset.sh
```

**One-command "keep my kit, reset the demo":**
```sh
./scripts/demos/reset.sh --save-kit
```
`--save-kit` commits the reusable demo-kit changes (`scripts/demos`, `.cursor/skills`, demo-safety rule, `.gitignore`) onto the base branch as a **local** commit (never auto-pushed — it prints a `git push origin main` reminder to respect the review gate), then discards the live product changes under `public/app` / `pkg`. This encodes the split: kit is preserved, the Explore/panel UI + planted bug are thrown away.

Confirm: back on `main` (or recorded base), `.demo-state` gone, no leftover `demo/explore-trace` branch. (Also stops the background traffic generator.)

---

## Safe change (agent may do)

- UC1: the Explore-scoped empty state — `public/app/features/panel/components/ExploreNoDataDiagnostics.tsx` (the active diagnosis) + `PanelDataErrorView.tsx` (guarded by `eventsScope === 'explore'`), plus threading `request` through `Explore.tsx` → `GraphContainer.tsx` → `ExploreGraph.tsx`
- UC2: fix the byte-scaling divisor in `public/app/features/explore/Graph/scaleSeries.ts` (planted demo bug) so `scaleSeries.test.ts` passes
- Optional tiny i18n string if the repo pattern requires `t()`
- Keep copy **professional** — no jokes, no customer-name hardcoding
- Visible, reversible UX / bug-fix only

## Do not touch (live demo)

- `runQueries` / Explore query pipeline
- `pkg/api/ds_query.go` / `pkg/api/api.go` or datasource query API behavior
- Auth, billing, migrations, alert-evaluation core
- Dashboard "No data" behavior in `PanelDataErrorView.tsx` (keep it minimal — Explore-scoped changes only)
- Broad refactors outside `PanelDataErrorView.tsx` / `scaleSeries.ts`

## Reset checklist

- [ ] `./scripts/demos/reset.sh` completed
- [ ] On base branch (`main` unless recorded otherwise)
- [ ] `.demo-state` removed
- [ ] Local `demo/explore-trace` branch deleted (unless `--keep-branch`)
- [ ] No need for profile `reset.sh` side effects (none seeded)

## Success criteria

- FE can trigger `/kev-demo-grafana-explore-trace-start` and follow this script (and `/kev-demo-grafana-explore-trace-reset` to tear down)
- `seed-traffic.sh --watch` (auto-started by setup, stopped by reset) keeps a real 401/404 spike on `grafana_http_request_duration_seconds_count` fresh for any time window
- **UC1:** Ask produces an accurate Run → API → Go map (optionally captured in a Cursor Canvas); Design Mode selects the real empty-state node → builds the active diagnosis across `ExploreNoDataDiagnostics.tsx` + `PanelDataErrorView.tsx` (+ `request` threading) → the empty state shows "No metric named … did you mean" and the culprit label filter, updating via HMR; "Copy fixed query" → the fixed query returns data and reveals the seeded 401 spike
- **UC2:** Ask traces the graph pipeline to `scaleSeries.ts`; Agent fixes the byte divisor → `scaleSeries.test.ts` goes green → memory graph corrects
- Reset returns to a clean base with no leftover demo branch (planted bug discarded)
