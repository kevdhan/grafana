---
name: kev-demo-grafana-explore-trace-reset
description: >-
  Field Engineer demo — RESET / tear down an active explore-trace demo. Drives
  ./scripts/demos/reset.sh: checks out the base branch, deletes the local
  demo/explore-trace branch, clears .demo-state, stops the background traffic
  generator, and removes the provisioned Prometheus datasource (leaving the
  Prometheus container running by default). Defaults to --save-kit: commits the
  reusable kit to the base branch and discards only the throwaway product changes,
  so kit work is never lost. Use when the user says reset the explore-trace demo,
  tear down the demo, end the demo, clean up after the demo, or
  /kev-demo-grafana-explore-trace-reset. Companion to the start skill
  /kev-demo-grafana-explore-trace-start.
  Trigger via /kev-demo-grafana-explore-trace-reset.
---

# kev-demo-grafana-explore-trace-reset

Tears down an active **explore-trace** demo by driving `./scripts/demos/reset.sh`.
Companion to **`/kev-demo-grafana-explore-trace-start`**.

**Default behavior: `--save-kit`.** This skill always resets with `--save-kit` unless the user explicitly asks for a different flavor — so reusable kit changes are committed to the base branch and only the throwaway product changes (`public/app` / `pkg`) are discarded. You never have to remember the flag.

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

### 2. Run reset — DEFAULT is `--save-kit` (unsandboxed)

**Always reset with `--save-kit` unless the user explicitly asks otherwise.** It is the standard teardown for this demo: it commits the reusable kit (`scripts/demos`, `.cursor/skills`, demo-safety rule, `.gitignore`) onto the base branch as a **local** commit, then discards the live product changes under `public/app` / `pkg` — so kit work is never lost and the Explore/panel UI + planted bug are always reset. It also **stops the background traffic generator** (`.demo-traffic.pid`) and **removes the provisioned Prometheus datasource** (leaving the Prometheus container running for a fast next spinup).

Run with `required_permissions: ["all"]` (so it can reach Docker for the datasource reload and manage processes):

```sh
./scripts/demos/reset.sh --save-kit
```

Only deviate if the user explicitly requests it:

| Situation | Command |
|-----------|---------|
| **Default — keep kit, reset the demo** | `./scripts/demos/reset.sh --save-kit` |
| Discard EVERYTHING including uncommitted kit (rare — confirm first) | `./scripts/demos/reset.sh --force --clean-untracked` |
| Keep the local demo branch | add `--keep-branch` |
| Full cold teardown (also stop Prometheus/devenv containers) | `./scripts/demos/explore-trace/reset.sh --stop-deps`, then the reset above |

### 3. Push the kit commit (offer — never auto-push)

`--save-kit` makes a **local** commit and deliberately does **not** push (review gate). After a clean reset, **offer to `git push origin main`** so the kit updates are durable on the fork; only push after the user approves.

### 4. Verify clean state

- `git branch --show-current` → base branch (`main`)
- `git status --short` → clean (product changes discarded)
- `.demo-state` gone; local `demo/explore-trace` deleted (unless `--keep-branch`)

## Related

- Start / run the demo: `/kev-demo-grafana-explore-trace-start`
- Orchestrator: `/kev-demo-kit`
- Scripts: `scripts/demos/reset.sh`, `scripts/demos/explore-trace/reset.sh`
