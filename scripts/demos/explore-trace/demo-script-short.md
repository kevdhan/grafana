# explore-trace — cheat sheet

Full talk track: [`demo-script.md`](./demo-script.md)  
**Skills:** `/kev-demo-grafana-explore-trace-start` · `/kev-demo-grafana-explore-trace-reset`  
**Login:** `admin` / `admin` → http://localhost:3000 · **Branch:** `demo/explore-trace`

| UC | Story | Cursor modes |
|----|-------|--------------|
| 1 | No data → diagnose & fix query | Ask → Canvas → Design Mode |
| 2 | Data looks wrong → fix planted bug | Ask → Agent + test |

---

## Preflight

```sh
./scripts/demos/setup.sh explore-trace   # unsandboxed; follow === DEMO READINESS ===
# NOT READY → start FE/BE/traffic as durable background shells (exec …), then re-run:
./scripts/demos/explore-trace/setup.sh
```

- PATH: `export PATH="$HOME/.local/go/bin:$HOME/.local/node/bin:$PATH"`
- Backend: `./bin/grafana server …` (avoid `make run-go`) · Frontend: `yarn start` (unsandboxed; `unset` polling env)
- Traffic: durable shell after `/login` 200 — `echo $$ > .demo-traffic.pid; exec bash scripts/demos/explore-trace/seed-traffic.sh --watch 12` (never `nohup`)
- Prometheus `:9090` preferred · 401s = unauthenticated curls, **never** wrong password
- Shortcuts: Agents Window `Cmd+Shift+P` · Design Mode `Cmd+Shift+D`

---

## Beat 0 — Setup

**Talk:** Disposable `demo/*` branches; reset is one script.

**Do:** Ready gate `READY` → login after `/login` → 200.

---

## UC1 — No data → diagnose & fix

### Beat 1 — 2 a.m. page

**Talk:** Explore = ad-hoc incident surface (not a dashboard). PagerDuty: checkout error burn. Filter the request metric for `5xx` → **No data** (errors here are 401s, not 500s). Empty state answers nothing.

**Do:** `/explore` → Prometheus → run broken query → confirm centered No data.

```promql
sum(rate(grafana_http_request_duration_seconds_count{status_code="500"}[5m]))
```

Fix — swap `500` → `401` (from the recommendation) to reveal the spike:

```promql
sum(rate(grafana_http_request_duration_seconds_count{status_code="401"}[5m]))
```

Optional: Explain toggle = query only; Ask = codebase; Design = empty-state UX.

### Beat 2 — Ask + Canvas

**Talk:** Ask understands without editing. Canvas = shareable source of truth.

**Prompts:**
1. Where is Run query in ExploreToolbar?
2. Trace `runQueries` → network — method + path?
3. Which Go handler for `POST /api/ds/query`? (`ds_query.go`)

**Map:** `ExploreToolbar` → `runQueries` → `runRequest` → `POST /api/ds/query` → `api.go` → `QueryMetricsV2`

Then: generate Cursor Canvas `explore-run-trace.canvas.tsx`.

### Beat 3 — Agents Window

**Talk:** Same app inside Cursor’s browser for Design Mode.

**Do:** Agents Window → Browser → `http://localhost:3000/explore` · empty state visible.

### Beat 4 — Design Mode

**Talk:** Selection finds the real file (`PanelDataErrorView.tsx`, not `NoData.tsx`). Visual select → multi-file feature.

**Do:** `Cmd+Shift+D` → select No data → paste prompt (needs `yarn start` HMR):

> **Goal:** Explore "No data" → active diagnosis of why Prometheus returned nothing.
>
> **Scope:** Gate on `eventsScope === 'explore'`. Dashboards stay minimal.
>
> **Data:** Thread `queryResponse.request` Explore → GraphContainer → ExploreGraph into PanelRenderer `data`.
>
> **Behavior:** Via `getBackendSrv` label APIs (`…/label/__name__/values`, `…/label/{name}/values`): missing metric → "did you mean" + Copy fixed query; bad `=` label filters → show valid values; echo time range + query; checklist fallback.
>
> **Constraints:** i18n `t()`; no `as`; dedicated component; don't change dashboard behavior.

**Lands in:** `ExploreNoDataDiagnostics.tsx` + `PanelDataErrorView.tsx` + request threading.

### Beat 5 — Verify + reveal

**Talk:** Empty state diagnosed; fix shows the real incident (401 spike).

**Do:** Confirm HMR diagnosis → run reveal query above → optional Ask: which file changed? → `PanelDataErrorView.tsx`

---

## UC2 — Data looks wrong → Agent fix

**Talk:** Intentional demo artifact (planted by setup). Ask/Design improved UX; Agent + failing test fixes a real bug.

### Beat 5b

**Do:**
```promql
prometheus_http_requests_total
```
Graph: **1 line** · Disclaimer: *"Showing only 20 series"* → mismatch.

**Ask prompt:**
> Graph shows 1 series, disclaimer says 20 of 56. Trace series-limiting through GraphContainer to the cap bug. Canvas: query → runQueries → POST /api/ds/query → Go → frames → GraphContainer → limitSeriesForDisplay → graph; **highlight the bug node**.

**Expected:** `limitSeries.ts` caps at `1` instead of `MAX_NUMBER_OF_TIME_SERIES`.

**RED test (optional):**
```sh
yarn jest public/app/features/explore/Graph/limitSeries.test.ts --watchAll=false
```

**Agent prompt:**
> Fix `limitSeriesForDisplay` (`1` → `MAX_NUMBER_OF_TIME_SERIES`). (1) Green `limitSeries.test.ts`. (2) Visual: Playwright `shot.mjs` on `prometheus_http_requests_total` → ~20 series.

```sh
export PLAYWRIGHT_BROWSERS_PATH="$HOME/Library/Caches/ms-playwright"
EXPR='prometheus_http_requests_total' OUT='scripts/demos/explore-trace/.shot-uc2-after.png' \
  node scripts/demos/explore-trace/shot.mjs
```

---

## Beat 6 — Reset

```sh
./scripts/demos/reset.sh            # tear down
./scripts/demos/reset.sh --save-kit # keep kit on base, discard product edits
```

---

## Safe / don’t touch

| Safe | Don’t |
|------|-------|
| UC1: `ExploreNoDataDiagnostics.tsx`, Explore-scoped `PanelDataErrorView.tsx`, request threading | `runQueries` / query pipeline |
| UC2: `limitSeries.ts` `1` → `MAX_NUMBER_OF_TIME_SERIES` | `ds_query.go` / `api.go` |
| Professional copy only | Dashboard No data, auth, alerting, broad refactors |
