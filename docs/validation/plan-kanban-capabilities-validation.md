# Plan / Kanban / Capacidades Validation

Date: 2026-06-21

## Automated Checks

- `cd apps/client && gleam format --check src test && gleam check && gleam test --target javascript`
  - Result: 1598 passed, no failures.
- `cd apps/server && gleam format --check src test && gleam check`
  - Result: passed.
- `cd shared && gleam format --check src test && gleam check`
  - Result: passed.
- `cd shared && gleam test --target erlang && gleam test --target javascript`
  - Result: 217 passed on each target.
- `cd packages/birl && gleam format --check src test && gleam check`
  - Result: passed.
- `cd packages/birl && gleam test --target erlang && gleam test --target javascript`
  - Result: 9 passed on each target.

Server test note:

- `cd apps/server && DATABASE_URL=... gleam test --target erlang -- --filter seed_db`
  did not isolate the requested filter in this project setup and ran unrelated
  server tests. It ended with 340 passed and 7 failures/timeouts from existing
  broader HTTP/integration coverage, not from the Plan scope bar or seed compile
  gates.

## Browser Smoke

Dev server:

- `scripts/dev-hot.sh` through Caddy at `http://127.0.0.1:8443`
- LAN access verified at `http://192.168.1.120:8443`

Authenticated browser checks:

- Opened `http://127.0.0.1:8443` with `npx agent-browser`.
- Logged in as `admin@example.com`.
- Opened Plan: header rendered `Kanban`, scope controls and `Cerradas`
  without a `Lente` section.
- Opened Capacidades: header rendered `Capacidades`, scope controls,
  `Lista`/`Matriz`, and `Cerradas` without a `Lente` section.

Findings:

- The shared scope bar renders in both Plan/Kanban and Capacidades.
- `Lente` has been removed from the top control strip; navigation remains in
  the left sidebar.
- The duplicated card `<select>` has been removed from render tests; card scope
  uses the search input/datalist path.
- A temporary seed database could not be created for runtime seed execution
  because the local Postgres user lacks `CREATE DATABASE`; the active dev DB was
  not reseeded to avoid disturbing the running app.
