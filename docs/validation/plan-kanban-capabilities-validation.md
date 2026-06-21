# Plan / Kanban / Capacidades Validation

Date: 2026-06-21

## Automated Checks

- `cd apps/client && gleam format src test && gleam check`
  - Result: passed.
- `cd apps/client && gleam test`
  - Result: 1606 passed, no failures.
- `cd apps/server && DATABASE_URL=postgres://scrumbringer:scrumbringer@localhost:5433/scrumbringer_dev?sslmode=disable gleam check`
  - Result: passed.
- `DATABASE_URL=postgres://scrumbringer:scrumbringer@localhost:5433/scrumbringer_dev?sslmode=disable scripts/ht12-db-schema-check.sh`
  - Result: passed.
- `scripts/ht12-plan-check.sh`
  - Result: passed.
- `scripts/ht12-static-check.sh`
  - Result: passed.
- `git diff --check`
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

- `cd apps/server && DATABASE_URL=postgres://scrumbringer:scrumbringer@localhost:5433/scrumbringer_dev?sslmode=disable gleam test`
  was executed against the shared dev database after seed/runtime validation.
  It ended with 239 passed and 7 failures. The failures were stateful HTTP
  integration assertions and a DB timeout caused by non-isolated dev data, e.g.
  `TASK_NOT_CLAIMABLE` for a task no longer in the Pool and an extra seeded
  `General` task type in a sorted-list assertion. Compile, schema and client
  gates passed.

## Browser Smoke

Dev server:

- `scripts/dev-hot.sh` through Caddy at `http://127.0.0.1:8443`
- LAN access verified at `http://192.168.1.120:8443`

Authenticated browser checks:

- Opened `http://127.0.0.1:8443` with `npx agent-browser`.
- Logged in as `admin@example.com`.
- Opened Pool: seeded tasks were visible in the Pool, including
  `P3 - Task Extra #34`, `P3 - Task G #31` and `P3 - Task F #30`.
- Opened Plan / Estructura: header rendered `Proyecto`, `Nivel`, `Card`,
  `Estructura`, `Kanban` and `Cerradas` without a `Lente` section.
- Switched scope to `Card`: rendered one scope `<select>` and one
  `plan-scope-card-search` search/datalist input; no duplicate card selector.
- Selected `Release 1.5 - Launch train #30`: table filtered to the selected
  subtree and rendered contextual detail.
- Switched Plan to `Kanban`: rendered `.kanban-board`, kept the same scope
  controls and did not render `Lente`.
- Opened Capacidades: header reused the same scope controls and did not render
  `Lente`.
- Mobile viewport `390x844`: page width stayed at `390px` with no horizontal
  page overflow.

Findings:

- The shared scope bar renders in both Plan/Kanban and Capacidades.
- `Lente` has been removed from the top control strip; navigation remains in
  the left sidebar.
- The duplicated card `<select>` has been removed; card scope uses the search
  input/datalist path.
- The richer seed is loaded in `scrumbringer_dev` and exposes Pool tasks and
  Plan cards suitable for browser validation.
- Browser captures:
  - `/tmp/scrumbringer-plan-structure.png`
  - `/tmp/scrumbringer-plan-capabilities-card.png`
  - `/tmp/scrumbringer-plan-mobile.png`
