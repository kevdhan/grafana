---
name: kev-demo-grafana-explore-trace-reset
description: >-
  Field Engineer demo — RESET / tear down an active explore-trace demo. Drives
  ./scripts/demos/reset.sh: checks out the base branch, deletes the local
  demo/explore-trace branch, clears .demo-state, stops traffic + Grafana
  backend/frontend (so the next chat owns fresh terminals), unplants UC2, and
  removes the provisioned Prometheus datasource (leaving the Prometheus
  container running by default). Defaults to --save-kit: commits the reusable
  kit (scripts/demos, the demo skills, and the now-git-tracked Cursor primitives —
  .cursor/agents, .cursor/hooks, .cursor/rules/grafana-frontend-conventions.mdc,
  .cursor/skills/run-frontend-test, .gitignore allowlist) to the base branch and
  discards only the throwaway product changes, so kit work is never lost. External
  artifacts (Jira KHS-6, the internalsphere/kev-grafana Bugbot repo) live outside
  the repo and persist across resets — reset never deletes them. Use when the user says reset the explore-trace demo,
  tear down the demo, end the demo, clean up after the demo, or
  /kev-demo-grafana-explore-trace-reset. Companion to the start skill
  /kev-demo-grafana-explore-trace-start.
  Trigger via /kev-demo-grafana-explore-trace-reset.
---

# kev-demo-grafana-explore-trace-reset

Tears down an active **explore-trace** demo by driving `./scripts/demos/reset.sh`.
Companion to **`/kev-demo-grafana-explore-trace-start`**.

**Default behavior: `--save-kit`.** This skill always resets with `--save-kit` unless the user explicitly asks for a different flavor — so reusable kit changes are committed to the base branch and only the throwaway product changes (`public/app` / `pkg`) are discarded. You never have to remember the flag.

**What "kit" now covers.** Besides `scripts/demos/**` and the demo skills, the kit now includes the **git-tracked Cursor primitives** developed for UC2's Customize tour — `.cursor/agents/` (`plan-executor.md`), `.cursor/hooks/` (`format-frontend.sh` + `hooks.json` + `enforce-fieldsphere-gh.sh`), `.cursor/rules/grafana-frontend-conventions.mdc`, `.cursor/skills/run-frontend-test/`, and the `.gitignore` allowlist additions that make them trackable. `--save-kit` preserves all of these.

**External artifacts persist (never deleted).** The Jira ticket `KHS-6` (`fe-anysphere-demo` site, project KevinHan-Space) and the Bugbot demo repo `internalsphere/kev-grafana` (+ reusable PR #2) live **outside** this git repo. Reset does **not** touch them — they're reusable across runs. Only recreate `KHS-6` if it's gone missing.

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
6. Do **not** hand-kill traffic/FE/BE with ad-hoc `pkill` unless `reset.sh` failed — prefer the script’s `demo_stop_traffic` / `demo_stop_grafana_servers`.

## Steps

### 1. Confirm there's an active demo

```sh
cat .demo-state    # expect DEMO_ID=explore-trace, DEMO_BRANCH=demo/explore-trace, BASE_BRANCH=main
```

If `.demo-state` is missing, there's nothing to reset — say so and stop.

### 2. Run reset — DEFAULT is `--save-kit` (unsandboxed)

**Always reset with `--save-kit` unless the user explicitly asks otherwise.** Standard teardown:

- Commits reusable kit onto the base branch (local), discards `public/app` / `pkg` product changes
- **Stops the durable traffic shell** (`demo_stop_traffic`: `.demo-traffic.pid` + `pgrep` fallback for `seed-traffic.sh --watch`) — always, even with `--keep-servers`
- Stops **Grafana backend + frontend** (so a *new* Cursor chat’s start skill relaunches them → native terminals in that chat)
- Unplants UC2 (`unplant-uc2.sh`)
- Removes provisioned Prometheus datasource
- **Leaves Prometheus container running** on `:9090` (fast next spinup)

Run with `required_permissions: ["all"]`:

```sh
./scripts/demos/reset.sh --save-kit
```

Only deviate if the user explicitly requests it:

| Situation | Command |
|-----------|---------|
| **Default — keep kit, stop traffic + FE/BE, keep Prometheus** | `./scripts/demos/reset.sh --save-kit` |
| Same-chat iteration — leave FE/BE up (traffic still stopped) | add `--keep-servers` |
| Discard EVERYTHING including uncommitted kit (rare — confirm first) | `./scripts/demos/reset.sh --force --clean-untracked` |
| Keep the local demo branch | add `--keep-branch` |
| Full cold teardown (also stop Prometheus/devenv) | add `--stop-deps` (or run profile `reset.sh --stop-deps` then the reset above) |

### 3. Push the kit commit (offer — never auto-push)

`--save-kit` makes a **local** commit and deliberately does **not** push (review gate). After a clean reset, **offer to `git push origin main`** so the kit updates are durable on the fork; only push after the user approves.

### 4. Verify clean state

- `git branch --show-current` → base branch (`main`)
- `git status --short` → clean (product changes discarded)
- `.demo-state` gone; local `demo/explore-trace` deleted (unless `--keep-branch`)
- `/login` should **not** be 200 (FE/BE stopped) unless `--keep-servers`
- **Traffic stopped:** no live `seed-traffic.sh --watch`; `.demo-traffic.pid` gone
- Prometheus `:9090` still healthy unless `--stop-deps`
- This chat’s backend / frontend / **traffic** terminal tabs should end once those processes exit

## Notes / kit files preserved by `--save-kit`

Kit paths staged by `demo_commit_kit_to_base` (`scripts/demos/**`, `.cursor/skills/**`, `.cursor/agents/**`, `.cursor/hooks/**`, the two allowlisted `.cursor/rules/*.mdc`, and `.gitignore`) survive reset:

| File | Role |
|------|------|
| `scripts/demos/explore-trace/demo-script.md` | Full talk track (detailed) |
| `scripts/demos/explore-trace/demo-script-short.md` | Live-demo cheat sheet (Preview-friendly) |
| `.cursor/skills/kev-demo-grafana-explore-trace-*` | start / reset / health skills |
| `.cursor/skills/run-frontend-test/` | UC2 skill: correct single-test command for this repo |
| `.cursor/rules/grafana-frontend-conventions.mdc` | UC2 rule: frontend conventions (Customize tab) |
| `.cursor/hooks/format-frontend.sh` · `.cursor/hooks.json` · `.cursor/hooks/enforce-fieldsphere-gh.sh` | UC2 hooks: auto-Prettier + gh safety gate |
| `.cursor/agents/plan-executor.md` | UC2 subagent: Composer 2.5 writer (delegated fix) |
| `.gitignore` | Allowlist additions that keep `.cursor/agents`, `.cursor/hooks`, and the two rules trackable |

Product plants (`limitSeries.ts`, `GraphContainer.tsx` wiring, UC1 Design Mode edits under `public/app`) are discarded. **External** artifacts (Jira `KHS-6`, `internalsphere/kev-grafana` + PR #2) live outside git and are left untouched — reusable across runs.

## Related

- Start / run the demo: `/kev-demo-grafana-explore-trace-start`
- Health check: `/kev-demo-grafana-explore-trace-health`
- Orchestrator: `/kev-demo-kit`
- Scripts: `scripts/demos/reset.sh`, `scripts/demos/explore-trace/reset.sh` (kit staging: `demo_commit_kit_to_base` in `scripts/demos/_lib.sh`)
- Talk track: `demo-script.md` · cheat sheet: `demo-script-short.md`
