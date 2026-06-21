# Plan / Kanban / Capacidades Validation

Date: 2026-06-21

## Automated Checks

- `cd apps/client && gleam test`
- `cd apps/client && gleam format --check src test`
- `cd apps/client && gleam check`
- `cd shared && gleam test`
- `cd shared && gleam format --check src test`

## Browser Smoke

Dev server:

- `cd apps/client && gleam run -m lustre/dev start --host=127.0.0.1 --port=1234`

Headless browser checks:

- Desktop screenshot: `chromium --headless=new --no-sandbox --disable-gpu --virtual-time-budget=5000 --window-size=1440,1000 --screenshot=/tmp/scrumbringer-plan-desktop.png http://127.0.0.1:1234`
- Mobile screenshot: `chromium --headless=new --no-sandbox --disable-gpu --virtual-time-budget=5000 --window-size=390,844 --screenshot=/tmp/scrumbringer-plan-mobile.png http://127.0.0.1:1234`
- DOM dump: `chromium --headless=new --no-sandbox --disable-gpu --virtual-time-budget=5000 --dump-dom http://127.0.0.1:1234`

Findings:

- The client bundle loads and renders the auth screen in Chromium.
- The local browser smoke could not reach authenticated Plan, Kanban, or Capacidades surfaces because no backend session was available; coverage for those states is provided by Lustre render tests.
- The initial auth screen reports `Request failed` without the API backend, which is expected for this isolated client smoke.
