---
name: github-fieldsphere-fork
description: Ensure GitHub context, issues, and pull request work targets the fieldsphere/grafana fork. Use for any GitHub-related task, including issues, PRs, commits, searches, or repository context.
---

# GitHub fork targeting: fieldsphere/grafana

## Instructions

- Always use `fieldsphere/grafana` for GitHub queries and operations (issues, PRs, commits, code search, and repo context).
- Exception: the Bugbot-on-PR demo uses `fieldsphere/kev-grafana` as a dedicated sandbox. Write actions (repo/branch/PR creation) may target `fieldsphere/kev-grafana`; the `gh` safety hook allows it alongside `fieldsphere/grafana`.
- For mutating `gh` CLI commands (for example `pr create`, `pr edit`, `pr merge`, issue/release writes), always pass `--repo fieldsphere/grafana`.
- For read-only/sync operations, upstream `grafana/grafana` may be used when explicitly needed (for example comparing, listing, syncing, or fetching context), but never as the target for write actions.
- For GitHub MCP tools, set owner to `fieldsphere` and repo to `grafana` (or include this in the tool query when required).
- For PR creation and PR updates, explicitly state the target repo in user-facing output, e.g. `Target repo: fieldsphere/grafana`, and include the PR URL.
- Never create, edit, or merge PRs/issues/releases against `grafana/grafana` unless the user explicitly requests upstream.
- If the target repo is ambiguous, check `git remote -v` and still prefer `fieldsphere/grafana`.
