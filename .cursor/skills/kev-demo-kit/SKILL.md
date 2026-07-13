---
name: kev-demo-kit
description: >-
  Orchestrate Field Engineer customer demos against this Grafana fork. Use when
  the user says setup demo, reset demo, start a customer demo, spin up a demo
  branch, tear down after a demo, or mentions kev-demo-kit / FE demo workflow.
  Trigger via /kev-demo-kit.
---

# Grafana FE demo kit (`kev-demo-kit`)

Personal/FE-owned demo orchestration. Future per-demo skills should also use the
`kev-` prefix (e.g. `/kev-demo-grafana-explore-trace-start`) so they cluster in the skill picker.

## When to use

- Preparing a **customer demo** in this repo
- **Resetting** after a session so the next demo starts clean
- Adding a **new demo profile** under `scripts/demos/`

Do **not** use this for normal feature development unless the user explicitly wants a disposable `demo/*` branch.

## Safety (always)

1. Prefer the scripts — do not free-hand destructive git.
2. Never `git push --force` to `main` / `master`.
3. Never delete **remote** demo branches unless the user explicitly asks.
4. If the working tree is dirty, stop and ask (or use script `--force` only with confirmation).
5. After every customer session, run reset before starting another demo.
6. Do **not** pass `--clean-untracked` unless the user explicitly wants untracked files removed.

## Setup a demo

```sh
./scripts/demos/setup.sh <demo-id>
```

Optional: `--force` (recreate), `--from <base-branch>` (default `main`).

Then:

1. Read `scripts/demos/<demo-id>/NOTES.md` if it exists (talk track + prompts).
2. Start servers with the **fast spinup** sequence below (do not proceed on frontend-only readiness).
3. Confirm `http://localhost:3000/login` returns **200** (admin / admin).
4. Run the demo beats from NOTES / the matching `kev-demo-*` skill.

## Fast spinup (all demos)

Cold backends can burn ~5 minutes on `go mod download` / `proxy.golang.org`, and `make run-go` always passes `-race` (slow first compile). Follow this every time:

1. **PATH** — `go version` / `node -v` must work. Local installs often need:
   ```sh
   export PATH="$HOME/.local/go/bin:$HOME/.local/node/bin:$PATH"
   ```
2. **Reuse** — if `/login` is already `200` and yarn HMR is up, **do not restart**. Never kill a mid-start `go run` / `make run` (loses download progress).
3. **Warm modules** when cold:
   ```sh
   # Agent Shell may redirect caches under cursor-sandbox-cache — pin durable paths:
   export GOMODCACHE="${GOMODCACHE:-$HOME/go/pkg/mod}"
   export GOCACHE="${GOCACHE:-$HOME/Library/Caches/go-build}"
   go mod download   # wait; retry once on proxy timeout
   ```
   Shared helper: `demo_warm_go_modules` in `scripts/demos/_lib.sh`. Prefer `required_permissions: ["all"]` for download/build so caches stick.
4. **Start** (separate terminals):
   - Frontend: `yarn start`
   - Backend (prefer non-race):
     - **Fastest restart** if recent `bin/grafana` exists (`bin/` gitignored):
       ```sh
       go build -o bin/grafana ./pkg/cmd/grafana
       ./bin/grafana server -profile -profile-addr=127.0.0.1 -profile-port=6000 -packaging=dev cfg:app_mode=development
       ```
     - Else: `go run ./pkg/cmd/grafana -- server -packaging=dev cfg:app_mode=development`
     Or `make run` (Air; race only if `.go-race-enabled-locally` / `GO_RACE`).
   - **Avoid** `make run-go` for demos — hardcoded `-race`.
5. **Health gate** — poll until `curl … http://localhost:3000/login` is `200` before any product beats. Frontend “Compiled successfully” is not sufficient.
6. **Ignore** background plugin version-compat log noise if `/login` is 200.

## Reset after a demo

```sh
./scripts/demos/reset.sh
```

Optional: `--force` (discard tracked changes), `--keep-branch`, `--clean-untracked` (rare).

Confirm you are back on `main` (or the recorded base branch) and `.demo-state` is gone.

## Catalog (fill as demos ship)

| demo-id | Skill | Status | Primary Cursor story |
|---------|-------|--------|----------------------|
| explore-trace | `kev-demo-grafana-explore-trace-start` (start) / `kev-demo-grafana-explore-trace-reset` (teardown) | ready | UC1: Ask Run → API → Go + Design Mode active-diagnosis empty state; UC2: Agent fixes a units bug via a failing test (Buckets 1–4 + 8) |

Candidate demos (discuss before building):

1. **alerting-rules** — Find alerting list → APIs → safe copy tweak (Buckets 1 + 2)
2. **dashboard-scene** — Architecture of dashboard-scene / mutation API (Bucket 1)
3. **home-greeting** — Tiny safe UI/i18n change with HMR (Bucket 2)
4. **connections-advisor** — Connections UI → apps/advisor (Buckets 1 + 4)
5. **value-arc** — Combo bootstrap → Explore ask+build → reset (Buckets 1–3)

## Adding a new demo

1. Copy `scripts/demos/_template/` → `scripts/demos/<demo-id>/`
2. Write `NOTES.md` (pain → prompts → safe change → do-not-touch)
3. Create `.cursor/skills/kev-demo-<demo-id>/SKILL.md` that calls setup/reset and follows NOTES
4. Add a row to the catalog table above

## Related skills already in this repo (fork-shipped, not `kev-`)

- `initial-setup` — deps + first run
- `start-dev-server` / `dev-server-hot-reload` — bring servers up
- `github-fieldsphere-fork` — keep GitHub ops on fieldsphere/grafana
