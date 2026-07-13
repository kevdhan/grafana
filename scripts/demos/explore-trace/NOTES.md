# explore-trace — Ask + Design Mode demo

**Demo id:** `explore-trace`  
**Skill:** `/kev-demo-grafana-explore-trace`  
**Branch:** `demo/explore-trace` (created by setup, deleted by reset)  
**Timebox:** ~25 min  
**Login:** `admin` / `admin` → `http://localhost:3000`

## Customer pain (Value Map)

Engineers ask: *“Where does Run query actually go?”* and *“Can Cursor change UI from what I see in the browser?”*

This demo answers both: Ask maps Explore Run → API → Go; Design Mode proves visual selection → source edit → HMR.

| Bucket | Story in this demo |
|--------|--------------------|
| 1 — Codebase understanding | Ask: Run button → `runQueries` → `POST /api/ds/query` → Go handler |
| 2 — Agent edits | Design Mode prompt lands a change in `NoData.tsx` |
| 3 — Skills / orchestration | `/kev-demo-grafana-explore-trace` + demo kit setup/reset |
| 4 — Terminal / servers | Fast spinup: warm `go mod download`, non-race backend, `/login` → 200 before beats |
| 8 — Browser tool | Agents Window browser + Design Mode (`Cmd+Shift+D`) |

## Preflight

1. `./scripts/demos/setup.sh explore-trace` (or via `/kev-demo-grafana-explore-trace`) — creates `demo/explore-trace`; profile `setup.sh` starts/provisions Prometheus and warms Go modules when `:3000` is cold. **Run unsandboxed** (`required_permissions: ["all"]`) so it can reach Docker (see Data source note).
2. **PATH** — `go version` / `node -v` (often need `export PATH="$HOME/.local/go/bin:$HOME/.local/node/bin:$PATH"`)
3. **Reuse if healthy** — `curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/login` → `200` means skip restart
4. Else warm + start:
   - Pin durable Go caches if agent Shell sandboxed them (`GOMODCACHE=$HOME/go/pkg/mod`, `GOCACHE=$HOME/Library/Caches/go-build`); prefer unsandboxed Shell for download/build
   - `go mod download` (wait; retry once on proxy timeout)
   - Frontend: `yarn start` — **must run outside the Cursor sandbox** (`required_permissions: ["all"]`). Sandboxed, FSEvents is blocked and webpack floods `EMFILE: too many open files, watch`, killing the watcher in ~10s. Don't try `CHOKIDAR_USEPOLLING=true` (this repo's chokidar crashes with `ERR_INVALID_ARG_TYPE`); and `unset` any polling env vars since agent Shell env persists across calls.
   - Backend: if recent `bin/grafana` exists → `./bin/grafana server -profile -profile-addr=127.0.0.1 -profile-port=6000 -packaging=dev cfg:app_mode=development` (build once with `go build -o bin/grafana ./pkg/cmd/grafana`); else non-race `go run ./pkg/cmd/grafana -- server -packaging=dev cfg:app_mode=development`  
     Or `make run`. **Avoid** `make run-go` (hardcodes `-race`, slow cold compile)
5. **Health gate** — do not start product beats until `/login` is `200` (frontend compile alone is not enough)
6. Plugin version-compat log noise is OK if `/login` is 200
7. Know shortcuts: Agents Window (`Cmd+Shift+P` → “Open Agents Window”); Design Mode `Cmd+Shift+D`

### Data source (Prometheus strongly preferred, TestData fallback)

Prometheus makes the 2 a.m. story authentic — a real PromQL query that genuinely returns empty. Don't fake it by renaming TestData.

- `setup.sh` starts a local Prometheus (`localhost:9090`) via `make devenv sources=prometheus` and provisions it as the **default** datasource (`conf/provisioning/datasources/demo-explore-trace.yaml`, gitignored).
- **Run `setup.sh` unsandboxed** (`required_permissions: ["all"]`). The Cursor sandbox blocks the Docker socket, so setup thinks Docker is absent and **falsely falls back to TestData even when Docker Desktop is running**. (Verify Docker for real with an unsandboxed `docker ps`.)
- **Basic auth:** devenv Prometheus (`web.yml`) requires `admin`/`admin`; the provisioned datasource and `demo_prometheus_ok` send those creds. Without them, `/-/healthy` and queries return **401**.
- **First-run build ~1 min** (pulls/builds images). If the 30s health poll expires mid-build → TestData fallback; just re-run `./scripts/demos/explore-trace/setup.sh` once the container is up (fast reuse path, provisions via reload API — no backend restart).
- Verify: `curl -s -u admin:admin http://localhost:3000/api/datasources/uid/demo-explore-trace-prom/health` → `"status":"OK"`.
- If Docker is **genuinely** absent, TestData → No Data Points still works; the Run → `/api/ds/query` → Go path is identical. Say so out loud instead of pretending it's Prometheus.
- Prometheus is a container independent of the git branch, so it's reused across iterations (fast). Top-level `reset.sh` leaves it running; for a cold teardown run `scripts/demos/explore-trace/reset.sh --stop-deps` (calls `make devenv-down`).

## Product story (two phases)

```
Ask:     Run query → explore state → POST /api/ds/query → pkg/api/ds_query.go
Design:  Agents Window → select No Data UI → prompt → edit NoData.tsx → HMR
```

Same running app for both phases — not Ask-only.

---

## Live demo beats

### Beat 0 — Setup (~2–5 min cold; ~0 if reusing)

- Run setup script; confirm branch `demo/explore-trace` and `.demo-state`
- Follow **Preflight** fast spinup; login only after `/login` → 200
- Do **not** kill a mid-start backend — that wastes module download progress

**Talk:** “We keep customer demos on disposable `demo/*` branches so reset is one script.”

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

That last column **is the list of things a helpful empty state should suggest** — which is exactly what we prompt Design Mode to add to `NoData.tsx` in Beat 4.

#### Getting the empty state on screen

**Preferred — real Prometheus datasource** (provisioned by `setup.sh` when Docker is up; see `demo_ensure_prometheus`):

1. Open `/explore`, pick **Prometheus**
2. Run a query that returns nothing for the window — mirrors the “metric was renamed” cause:
   ```promql
   sum(rate(http_requests_total{job="checkout", status=~"5.."}[5m]))
   ```
   (No `checkout` job is scraped locally, so this returns empty → authentic “No data”.)
3. Optional contrast: run `up` first (returns series → a graph), then the query above (empty) to show the *difference* between “data” and the dead-end empty state.

> **Basic auth:** the devenv Prometheus block (`web.yml`) requires `admin`/`admin`. The provisioned datasource and the `demo_prometheus_ok` health check both send those creds — if you provision Prometheus by hand, set `basicAuth: true` + `basicAuthUser/Password`, or `/-/healthy` and queries return **401** (this previously caused setup to fall back to TestData even though the container was up).
>
> **First-run timing:** `make devenv sources=prometheus` builds several images (~1 min cold). The 30s health poll can expire mid-build and fall back to TestData; just re-run `./scripts/demos/explore-trace/setup.sh` once the container is up — it takes the fast reuse path and provisions the datasource.

**Fallback — TestData** (no Docker / Prometheus not running):

1. Open `/explore`, pick **TestData**
2. Scenario **No Data Points** (`no_data_points`) → Explore renders `NoData` (`data-testid="explore-no-data"`)
3. Say out loud: *“TestData is a mock backend so this never flakes; the Run → API → Go path we trace next is identical to real Prometheus.”*

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

`ExploreToolbar` (Run) → explore query / `runQueries` → `POST /api/ds/query` → `pkg/api/ds_query.go`

**Talk:** “Ask is for understanding the system without editing it yet.”

### Beat 3 — Agents Window browser (~2 min)

1. `Cmd+Shift+P` → **Open Agents Window**
2. Open Browser → `http://localhost:3000/explore`
3. Ensure the empty state is still visible (re-run the empty Prometheus/TestData query if needed)

**Talk:** “Same app, now inside Cursor’s browser so Design Mode can target what we see.”

### Beat 4 — Design Mode on NoData (~7 min)

**Caveats (say out loud — don’t oversell):**

- Design Mode lives in the **Agents Window** browser ([Cursor Design Mode docs](https://cursor.com/docs/agent/design-mode))
- Toggle **`Cmd+Shift+D`** after the page has fully loaded
- Selection + natural-language prompt → agent edits **source** (not a live CSS-only sidebar)
- Needs **`yarn start`** HMR so the empty state updates without a manual rebuild

**Steps:**

1. Enable Design Mode (`Cmd+Shift+D`)
2. Click the empty-state / **No data** text (prefer the `explore-no-data` panel)
3. Prompt — tie it back to the 2 a.m. story (pick one):

   > Make this empty state clearer and more helpful for Explore

   Stronger (lands the on-call guidance from Beat 1):

   > This "No data" state is a dead end for an on-call engineer. Make it clearer and add a short list of things to check — time range, query filters / metric and label names, and whether the data source is reporting.

4. Prefer **user-driven** selection in the browser; agent implements the change primarily in `public/app/features/explore/NoData.tsx`
5. If adding/changing user-visible strings, follow repo i18n (`t()`) when that is the local pattern

**Talk:** “Visual → code → hot reload. That’s the agent loop customers care about.”

**Callback to the Explain hook (if you used it in Beat 1):** “Remember Grafana’s Explain toggle explaining the query? We just extended that same explain-as-you-go spirit to the empty state — the one place Grafana left blank — without leaving the browser.”

### Beat 5 — Verify (~2 min)

- Confirm Explore empty state updated via HMR
- Optional Ask: “What file changed for the Explore empty state?”

### Beat 6 — Reset (~1 min)

```sh
./scripts/demos/reset.sh
```

Confirm: back on `main` (or recorded base), `.demo-state` gone, no leftover `demo/explore-trace` branch.

---

## Safe change (agent may do)

- Touch primarily `public/app/features/explore/NoData.tsx`
- Optional tiny i18n string if the repo pattern requires `t()`
- Keep copy **professional** — no jokes, no customer-name hardcoding
- Visible, reversible empty-state UX only

## Do not touch (live demo)

- `runQueries` / Explore query pipeline
- `pkg/api/ds_query.go` or datasource query API behavior
- Auth, billing, migrations, alert-evaluation core
- Broad refactors outside `NoData.tsx`

## Reset checklist

- [ ] `./scripts/demos/reset.sh` completed
- [ ] On base branch (`main` unless recorded otherwise)
- [ ] `.demo-state` removed
- [ ] Local `demo/explore-trace` branch deleted (unless `--keep-branch`)
- [ ] No need for profile `reset.sh` side effects (none seeded)

## Success criteria

- FE can trigger `/kev-demo-grafana-explore-trace` and follow this script
- Customer sees Ask produce an accurate Run → API → Go map
- Customer sees Design Mode select UI → code edit → Explore empty state updates
- Reset returns to a clean base with no leftover demo branch
