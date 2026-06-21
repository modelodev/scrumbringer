# Plan / Kanban / Capacidades Validation

Date: 2026-06-21

Parent branch for this refactor: `main`.

## Automated Checks

- `cd apps/client && gleam format src test && gleam check`
  - Result: passed.
- `cd apps/client && gleam test`
  - Result: 1608 passed, no failures.
- `cd apps/client && gleam test --target javascript`
  - Result: 1608 passed, no failures.
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

Server test note:

- The full server integration suite was not used as the final gate for this
  pass because prior execution against the shared dev database produced stateful
  failures after seed/browser interaction. Server compile, schema, HT12 plan and
  HT12 static gates are green.

## Seed

- Re-loaded `scrumbringer_dev` with:
  - `cd apps/server && DATABASE_URL=postgres://scrumbringer:scrumbringer@localhost:5433/scrumbringer_dev?sslmode=disable gleam run -m scrumbringer_server/seed`
- Result:
  - Projects: 4
  - Users: 6
  - Task types: 3
  - Workflows: 6
  - Rules: 3
  - Tasks: 81
  - Cards: 24
  - Rule executions: 3
  - Task events: 176
- After reseed, Pool displayed seeded tasks including `P6 - Task Extra #34`,
  `P6 - Task G #31` and `P6 - Task F #30`.

## Browser Smoke

Dev server:

- `scripts/dev-hot.sh` through Caddy at `http://127.0.0.1:8443`
- LAN access verified with HTTP 200 at `http://192.168.1.120:8443`

Authenticated browser checks with `npx agent-browser`:

- Logged in as `admin@example.com`.
- Opened Plan / Estructura and confirmed:
  - `plan-filter-status` and `plan-filter-sort` render.
  - `Lente` / `Lens` are absent.
  - No desktop horizontal overflow.
- Collapsed and expanded the first tree node:
  - collapsed state changed `aria-expanded` to `false`;
  - visible row triggers went from 10 to 8;
  - descendants `P3 - Architecture #2` and `P3 - Sprint Planning #1` were hidden;
  - expanding restored 10 visible row triggers.
- Changed status filter to `draft`:
  - filter value became `draft`;
  - Active rows were not visible;
  - Draft rows remained visible.
- Changed sort to `pool_impact`:
  - filter value became `pool_impact`;
  - row triggers remained stable.
- Switched scope to `Card`:
  - rendered `plan-scope-kind` plus `plan-scope-card-search`;
  - no duplicate `plan-scope-card` select exists.
- Selected `Release 1.5 - Launch train #30`:
  - central detail rendered;
  - contextual actions rendered from the same Plan table/detail surface.
- Opened the existing card detail custom element from Plan:
  - `card-detail-modal` rendered;
  - metrics/view/notes requests were issued.
- Opened `card-move-action`:
  - `card-move-dialog` rendered;
  - invalid destinations were listed with reasons;
  - no duplicated Plan-specific move logic was added.
- Opened `card-activate-action` on a Draft card:
  - `card-activation-dialog` rendered;
  - confirmation text showed hierarchy impact: 1 card and 5 tasks;
  - confirmation was cancelled to avoid mutating dev data.
- Mobile viewport `390x844`:
  - `documentElement.scrollWidth` stayed equal to viewport width;
  - `Lente` / `Lens` stayed absent;
  - status and sort filters remained present.

Browser captures:

- `/tmp/scrumbringer-plan-structure-refactor-desktop.png`
- `/tmp/scrumbringer-plan-structure-refactor-mobile.png`

Implementation notes:

- `PlanFilters` now exists as a typed value for status, sort, search and
  `include_closed`.
- Plan collapse state is stored in typed member pool state and survives normal
  re-rendering.
- Hidden closed ancestors no longer break visible-tree collapse: visible cards
  are attached to their nearest visible parent.
- Plan actions intentionally reuse the existing card detail modal for move and
  activation rules instead of duplicating operational logic in the table.
