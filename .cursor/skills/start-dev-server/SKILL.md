---
name: start-dev-server
description: Run commands to start Grafana local dev after initial setup. Use when the user asks how to start the dev server, run Grafana locally, or run frontend/backend watchers.
---

# Start dev server

## Instructions
When asked how to start the dev server after initial setup, run the commands below using the Shell tool. Do not ask the user to run them.

### Preflight
Before starting new processes, check if they are already running by inspecting the terminals folder. If `yarn start` fails with a missing `node_modules` state file (or no `node_modules` is present), run the frontend dependency install in this order:

```sh
corepack enable
corepack install
yarn install --immutable
```

### Backend server
Run from the repo root:

```sh
make run
```

### Frontend assets watcher
Run from the repo root:

```sh
yarn start
```

## Notes
- Run both commands in separate terminals for full local dev.
- If port `3000` is already in use **and** `http://localhost:3000/login` returns 200, reuse it — do not kill a healthy or mid-start backend.
- Wait for readiness: backend should log `HTTP Server Listen`, frontend should log `Compiled successfully` (and finish type-checking) before opening the browser.
- **Health gate:** treat the app as ready only when `curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/login` returns `200`. Frontend compile alone is not enough.
- After both are ready, `curl -I http://localhost:3000/` should redirect to `/login`.
- `http://localhost:3000/login` is the smoke check (admin / admin).
- If the embedded `@Browser` shows `chrome-error://chromewebdata/` or won't load, open `http://localhost:3000/login` in the local system browser instead.

### Demo / cold-start (Field Engineer)

For customer demos, prefer the **fast spinup** in `kev-demo-kit` / `kev-demo-grafana-explore-trace`:

1. Ensure `PATH` includes local Go/Node if needed (`~/.local/go/bin`, `~/.local/node/bin`)
2. Reuse `:3000` when `/login` is already 200
3. Otherwise `go mod download` first (retry once on proxy timeout)
4. Prefer non-race backend: `go run ./pkg/cmd/grafana -- server -packaging=dev cfg:app_mode=development` (or `make run`)
5. **Avoid** `make run-go` for demos — it hardcodes `-race` and slows cold compiles a lot
6. Do not proceed to demo beats until `/login` is 200
