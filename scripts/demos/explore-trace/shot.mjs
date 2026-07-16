// Throwaway self-test harness for the explore-trace demo (demo branch only).
// Launches headless Chromium (via Playwright), opens Explore with a preloaded
// Prometheus query, and screenshots the result so the agent can visually verify
// the empty state / graph without manual clicking.
//
// Usage:
//   node scripts/demos/explore-trace/shot.mjs
// Env overrides:
//   BASE_URL   (default http://localhost:3000)
//   DS_UID     (default demo-explore-trace-prom)
//   EXPR       (default the status_code="500" no-data query)
//   OUT        (default scripts/demos/explore-trace/.shot.png)
//   RANGE_FROM (default now-1h)
import { chromium } from '@playwright/test';

const BASE_URL = process.env.BASE_URL || 'http://localhost:3000';
const DS_UID = process.env.DS_UID || 'demo-explore-trace-prom';
const EXPR = process.env.EXPR || 'sum(rate(grafana_http_request_duration_seconds_count{status_code="500"}[5m]))';
const OUT = process.env.OUT || 'scripts/demos/explore-trace/.shot.png';
const RANGE_FROM = process.env.RANGE_FROM || 'now-1h';

const panes = {
  demo: {
    datasource: DS_UID,
    queries: [
      {
        refId: 'A',
        expr: EXPR,
        range: true,
        datasource: { type: 'prometheus', uid: DS_UID },
      },
    ],
    range: { from: RANGE_FROM, to: 'now' },
  },
};

const url = `${BASE_URL}/explore?schemaVersion=1&orgId=1&panes=${encodeURIComponent(JSON.stringify(panes))}`;

const browser = await chromium.launch();
const context = await browser.newContext({
  httpCredentials: { username: 'admin', password: 'admin' },
  viewport: { width: 1200, height: 950 },
});
const page = await context.newPage();

// 1. Log in via the UI so we get a real session cookie (basic-auth header alone
//    doesn't establish the SPA session; Grafana redirects to /login otherwise).
console.log('→ logging in');
await page.goto(`${BASE_URL}/login`, { waitUntil: 'networkidle', timeout: 60000 });
await page.getByPlaceholder(/email or username/i).fill('admin');
await page.getByPlaceholder('password').fill('admin');
await page.getByRole('button', { name: /log in/i }).click();
await page.waitForLoadState('networkidle');
// admin/admin first login may prompt a password change — skip it if shown.
try {
  await page.getByRole('button', { name: /skip/i }).click({ timeout: 4000 });
} catch {
  // no password-change prompt; continue
}

// 2. Open Explore with the preloaded query and let it run.
console.log('→ navigating:', url);
await page.goto(url, { waitUntil: 'networkidle', timeout: 60000 });
await page.waitForTimeout(5000);
await page.screenshot({ path: OUT, fullPage: false });
console.log('→ screenshot written:', OUT);

await browser.close();
