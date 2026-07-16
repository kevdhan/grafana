---
name: run-frontend-test
description: Run a single Grafana frontend (Jest) test file the correct way in this repo and interpret the result. Use when the user asks to run, check, or validate a frontend/unit test, or after editing a public/app *.ts / *.tsx file that has a matching *.test.* file.
---

# Run a Grafana frontend test

## Command
Run one test file, no watch mode:

```bash
node .yarn/releases/yarn-*.cjs jest <path/to/file.test.tsx> --watchAll=false
```

Repo gotchas this exists to encode:
- `yarn` is frequently not on `$PATH` here — invoke the pinned release directly via `node .yarn/releases/yarn-*.cjs` instead of bare `yarn`.
- Always pass `--watchAll=false`; the plain `yarn test` script watches and never exits.
- Filter by test name with `-t "pattern"`. Only pass `-u` (update snapshots) when that is explicitly intended.

## Interpret the result
- Report pass/fail counts (e.g. "3/3 passed").
- On failure: quote the failing `expect` and the received value, map it back to the code under test, and propose the minimal fix.
- Never weaken, skip, or delete assertions just to make a test pass.

## Example
```bash
node .yarn/releases/yarn-*.cjs jest public/app/features/explore/Graph/limitSeries.test.ts --watchAll=false
```
