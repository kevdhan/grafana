# Field Engineer demo kit
#
# Shared scripts to spin up / tear down disposable demo branches for customer
# sessions against this Grafana fork.
#
# ## Quick start
#
# ```sh
# ./scripts/demos/setup.sh <demo-id>
# # … run the demo with Cursor …
# ./scripts/demos/reset.sh
# ```
#
# ## Layout
#
# ```
# scripts/demos/
#   _lib.sh           shared helpers
#   setup.sh          create demo/<id> branch + write .demo-state
#   reset.sh          checkout base, delete demo branch, clear state
#   _template/        copy when adding a new demo profile
#   <demo-id>/        per-demo demo-script.md + optional setup.sh/reset.sh
# ```
#
# ## Adding a demo
#
# 1. Copy `_template/` → `<demo-id>/`
# 2. Fill in `demo-script.md` (talk track + Cursor prompts + safe change)
# 3. Add a matching skill under `.cursor/skills/kev-demo-<id>/` when ready
# 4. Wire the id into `.cursor/skills/kev-demo-kit/SKILL.md` catalog
#
# ## Fast spinup
#
# Reuse healthy :3000 (/login → 200). Else: PATH → go mod download → yarn start
# + non-race backend. Avoid make run-go (hardcodes -race). Helpers in _lib.sh.
# See `.cursor/skills/kev-demo-kit/SKILL.md`.
#
# ## Safety
#
# - Scripts refuse dirty worktrees unless `--force`
# - `reset.sh --force` only discards **tracked** changes (`git reset --hard`)
# - Untracked cleanup requires explicit `--force --clean-untracked`
# - Reset never force-pushes or deletes remote branches
# - Prefer local-only `demo/<id>` branches
#
# See also: `.cursor/skills/kev-demo-kit/SKILL.md` and `.cursor/rules/demo-safety.mdc`
