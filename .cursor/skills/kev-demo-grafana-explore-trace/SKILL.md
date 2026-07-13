---
name: kev-demo-grafana-explore-trace
description: >-
  Field Engineer demo: Ask-mode trace of Grafana Explore Run → API → Go, then
  Agents Window + Design Mode to improve the Explore empty state in NoData.tsx.
  Use when the user says explore-trace demo, grafana explore demo,
  /kev-demo-grafana-explore-trace, or wants the Ask + Design Mode Grafana demo.
  Trigger via /kev-demo-grafana-explore-trace.
---

# kev-demo-grafana-explore-trace

Orchestrates the **explore-trace** customer demo: Ask maps the request path;
Design Mode lands a visible empty-state change. Full talk track lives in
`scripts/demos/explore-trace/NOTES.md`.

## Branch lifecycle

| Step | Command | Git effect |
|------|---------|------------|
| Setup | `./scripts/demos/setup.sh explore-trace` | Creates local branch `demo/explore-trace` from `main` (or `--from`), writes `.demo-state` |
| Reset | `./scripts/demos/reset.sh` | Checks out base (`main`), **deletes** local `demo/explore-trace`, clears `.demo-state` |

Always run setup at the start and reset at the end of a customer session.

## When to use

- User triggers `/kev-demo-grafana-explore-trace`
- User asks to run the Grafana Explore Ask + Design Mode demo
- User wants the first FE Value Map demo (Buckets 1–4 + 8)

## Safety (always)

1. Prefer `./scripts/demos/setup.sh` / `./scripts/demos/reset.sh` — no free-hand destructive git.
2. Never force-push `main` / `master`. Never delete remote branches unless asked.
3. Do **not** pass `--clean-untracked` unless the user explicitly wants it.
4. During the live Design Mode beat, change **primarily** `public/app/features/explore/NoData.tsx` only.
5. Do **not** change `runQueries`, the Explore query pipeline, `pkg/api/ds_query.go`, auth, or alerting in the live demo.
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

#### Backend cold-start notes

- Cold `go mod download` / `proxy.golang.org` timeouts can stall for minutes before Grafana listens on `:3000`.
- Cursor agent Shell may sandbox `GOMODCACHE` / `GOCACHE` under `/var/folders/.../cursor-sandbox-cache/` — set durable `$HOME` caches (or reuse a warm sandbox cache) and prefer unsandboxed Shell for downloads/builds.
- Prefer `./bin/grafana server …` over `go run` / `make run-go` when a recent `bin/grafana` exists.
- Plugin installer may log version-compat errors (e.g. “not compatible with your Grafana version: 9.2.0”) — **harmless** for this empty-state demo if `/login` is 200.
- Login: `admin` / `admin`.

### 3. Product context (the 2 a.m. page)

Frame Explore as the ad-hoc **incident investigation** surface (not a saved dashboard), then tell the on-call story from NOTES Beat 1: a paged engineer runs a 5xx-rate query and hits a dead-end **No data** empty state. Full narrative + talk track live in `scripts/demos/explore-trace/NOTES.md`.

Guide the FE/customer to land the empty state:

- **Prometheus (preferred)** — open `/explore`, pick **Prometheus**, run a query that returns nothing for the window (mirrors a metric renamed by a deploy):
  ```promql
  sum(rate(http_requests_total{job="checkout", status=~"5.."}[5m]))
  ```
  Optional contrast: run `up` first (draws a graph), then the query above (empty) to show the difference.
- **TestData (fallback)** — pick **TestData** → scenario **No Data Points**.

Either way, confirm the centered **No data** empty state (`data-testid="explore-no-data"`) is visible before Ask / Design Mode. See the full recipe + why-it's-realistic table in NOTES Beat 1.

### 4. Ask beats (codebase understanding)

Switch to **Ask** mode. Walk the prompts from NOTES (adapt lightly):

1. Where is the Run query button / handler in `ExploreToolbar`?
2. Trace through frontend state / `runQueries` to the network call (`POST /api/ds/query`).
3. Which Go handler serves that path? Point at `pkg/api/ds_query.go` and summarize.

Do **not** edit code in this beat — map only.

### 5. Agents Window + Design Mode

1. Guide: `Cmd+Shift+P` → **Open Agents Window** → Browser → `http://localhost:3000/explore`
2. Ensure empty state is visible
3. Design Mode: `Cmd+Shift+D` after the page fully loads
4. Prefer **user-driven** selection of the No Data / empty-state UI in the browser
5. Use (or adapt) the NOTES prompt: *Make this empty state clearer and more helpful for Explore*
6. Implement the prompted change in `public/app/features/explore/NoData.tsx`
7. If touching user-visible strings, use i18n via `t()` when that matches repo pattern

Call out Design Mode caveats from NOTES (Agents Window browser; source edit not CSS-only sidebar; needs HMR).

### 6. Verify

- Confirm Explore empty state updated via HMR
- Optional Ask: which file changed for the empty state?

### 7. Reset (delete demo branch)

```sh
./scripts/demos/reset.sh
```

Confirm base branch, `.demo-state` gone, no leftover `demo/explore-trace` (unless `--keep-branch`).

Profile `reset.sh` removes the provisioned Prometheus datasource and, by default, **leaves the Prometheus container running** for a fast next iteration. For a full cold teardown (stop containers via `make devenv-down`), run `./scripts/demos/explore-trace/reset.sh --stop-deps`. Top-level reset owns branch teardown.

## Safe change constraints

| Allowed | Not allowed in live demo |
|---------|--------------------------|
| `NoData.tsx` empty-state UX / copy | `runQueries` / query pipeline |
| Tiny i18n `t()` if required | `pkg/api/ds_query.go` |
| Professional, reversible UI | Auth, alerting, migrations, broad refactors |

## Related

- Orchestrator: `/kev-demo-kit` (`.cursor/skills/kev-demo-kit/SKILL.md`)
- Servers: `start-dev-server` / `dev-server-hot-reload`
- Notes: `scripts/demos/explore-trace/NOTES.md`
