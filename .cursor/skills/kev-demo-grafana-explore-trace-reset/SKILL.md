---
name: kev-demo-grafana-explore-trace-reset
description: >-
  Field Engineer demo — RESET / tear down an active explore-trace demo. Drives
  ./scripts/demos/reset.sh: checks out the base branch, deletes the local
  demo/explore-trace branch, clears .demo-state, stops the background traffic
  generator, and removes the provisioned Prometheus datasource (leaving the
  Prometheus container running by default). Use when the user says reset the
  explore-trace demo, tear down the demo, end the demo, clean up after the demo,
  or /kev-demo-grafana-explore-trace-reset. Companion to the start skill
  /kev-demo-grafana-explore-trace-start.
  Trigger via /kev-demo-grafana-explore-trace-reset.
---

# kev-demo-grafana-explore-trace-reset

Tears down an active **explore-trace** demo by driving `./scripts/demos/reset.sh`.
Companion to **`/kev-demo-grafana-explore-trace-start`**.

## When to use

- User triggers `/kev-demo-grafana-explore-trace-reset`
- User asks to reset / tear down / end / clean up after the explore-trace demo
- Before starting a fresh demo run, to guarantee a clean base

## Safety (always)

1. Use `./scripts/demos/reset.sh` — no free-hand destructive git.
2. Never force-push `main` / `master`; never delete remote branches.
3. `--clean-untracked` is destructive (removes untracked files) — only pass it if the user explicitly wants it, and it requires `--force`.
4. If `.demo-state` names a **different** demo than expected, confirm before resetting.
5. `--save-kit` makes a **local** commit only and prints a `git push origin main` reminder — do not auto-push; let the user approve the push.

## Steps

### 1. Confirm there's an active demo

```sh
cat .demo-state    # expect DEMO_ID=explore-trace, DEMO_BRANCH=demo/explore-trace, BASE_BRANCH=main
```

If `.demo-state` is missing, there's nothing to reset — say so and stop.

### 2. Pick the teardown flavor

| Goal | Command |
|------|---------|
| Plain teardown (clean tree) | `./scripts/demos/reset.sh` |
| **Keep kit work, reset the demo** (recommended after building live changes) | `./scripts/demos/reset.sh --save-kit` |
| Discard uncommitted tracked + untracked product changes explicitly | `./scripts/demos/reset.sh --force --clean-untracked` |
| Keep the demo branch (rare) | `./scripts/demos/reset.sh --keep-branch` |
| Full cold teardown incl. stopping Prometheus/devenv containers | `./scripts/demos/explore-trace/reset.sh --stop-deps` then `./scripts/demos/reset.sh` |

Notes:
- `--save-kit` commits the reusable demo kit (`scripts/demos`, `.cursor/skills`, demo-safety rule, `.gitignore`) onto the base branch as a **local** commit, then discards the live product changes under `public/app` / `pkg`. This is the usual choice when the demo built UI/bug changes that must be reset while preserving kit improvements.
- Plain `reset.sh` will refuse a dirty tree unless `--force` (tracked) / `--clean-untracked` (untracked) — or use `--save-kit`, which discards the product paths for you.

### 3. Run it (unsandboxed)

Run with `required_permissions: ["all"]` so it can reach Docker (datasource reload) and manage processes cleanly.

The script (via the profile `reset.sh`) also **stops the background traffic generator** (`.demo-traffic.pid`) and **removes the provisioned Prometheus datasource**, leaving the Prometheus container running for a fast next spinup (`--stop-deps` to stop it).

### 4. Verify clean state

- `git branch --show-current` → base branch (`main`)
- `git status --short` → clean (product changes discarded)
- `.demo-state` gone; local `demo/explore-trace` deleted (unless `--keep-branch`)

If `--save-kit` created a commit, remind the user to `git push origin main` when ready.

## Related

- Start / run the demo: `/kev-demo-grafana-explore-trace-start`
- Orchestrator: `/kev-demo-kit`
- Scripts: `scripts/demos/reset.sh`, `scripts/demos/explore-trace/reset.sh`
