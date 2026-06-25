# HT-12 UI Validation

Current validation target: the final `Card tree + Task leaves` model described
in `docs/card-tree-task-leaves-model.md`.

## Runtime

Use the normal local stack against an already running PostgreSQL service. Point
`DATABASE_URL` at the reachable database; for example, if the local service is
on port `5433`:

```sh
export DATABASE_URL="postgres://scrumbringer:scrumbringer@localhost:5433/scrumbringer_dev?sslmode=disable"
dbmate --url "$DATABASE_URL" migrate
scripts/dev-hot.sh
```

With default settings the app is available at:

- Local: `http://127.0.0.1:8443`
- LAN, on the host-reported IP, for example
  `http://$(hostname -I | awk '{print $1}'):8443`
- API origin: `http://127.0.0.1:8000/api/v1`
- Client dev server: `http://127.0.0.1:1234`

## Agent-Browser Sweep

Run the sweep with a clean browser session and inspect a fresh snapshot after
each navigation or mutation:

```sh
make ht12-sweep
```

To run the same sweep from the LAN URL used by the current host:

```sh
make ht12-sweep-lan
```

The sweep auto-detects common local Chrome/Chromium binaries. If the browser
binary is installed in a non-standard location, override it explicitly:

```sh
AGENT_BROWSER_EXECUTABLE_PATH=/path/to/chrome make ht12-sweep-lan
```

The script performs preflight checks, logs in through the public API, creates a
fresh project with a three-level card hierarchy, creates RootPool and card-scoped
tasks, exercises activation, move, claim, release, close, task delete,
task-delete-with-history, card delete, card-delete-with-children, and
card-delete-with-history paths. It also creates enough RootPool pressure to push
the project over `healthy_pool_limit`, verifies the activation response reports
`pool_open_after`, `healthy_pool_limit`, and `pool_health`, and checks that a
manual card close is rejected while a descendant task is claimed. It creates a
task under an already active card and proves that task enters the Pool
immediately, can be claimed, and can be closed. It also closes an
available-only branch and verifies the descendant card is closed and its task is
closed, with the server-side `closed_by_ancestor` reason covered by the HTTP
tests. The same API phase creates task-to-task dependencies, proves a blocked
task cannot be claimed, proves it becomes claimable after the dependency closes
or is removed, and verifies cycle and cross-project dependency rejections. Then
it opens the seeded project with agent-browser to capture desktop, tablet,
mobile, Pool, all-cards, and per-depth hierarchy evidence. For Pool, Cards, and
each depth route it verifies the DOM has exactly one active nav item with
`aria-current="page"` and that the expected `data-testid` is the selected item.
It also writes `db-schema-check.txt` with the database invariants that affect
activation, Pool visibility, task claim, dependencies, and delete-with-history
behavior.

The automation API phase creates an engine, templates, and rules for every
supported trigger family: `task_created`, `task_claimed`, `task_released`,
`task_completed`, `card_activated`, and `card_closed`. It verifies generated
task origins, rule execution records, duplicate close suppression, missing
template rejection, and the non-cascading guard that prevents
automation-created tasks from firing `task_created` rules.

The browser phase is intentionally evidence-oriented: the API phase proves the
mutations and server contracts, while the agent-browser phase proves that the
resulting user-facing routes render and remain inspectable at the expected
viewports. The sweep now asserts the Automations console anchors for Engines,
Rules, Templates, and Executions: the engine list route exposes
`automation-engine-row`, the focused rule route exposes `automation-rule-row`
and `automation-rule-builder`, the opened rule builder exposes
`automation-template-picker`, the template library exposes
`automation-template-row`, and execution history exposes `automation-execution-row`.
It also asserts the generated task origin anchor in Task Show
(`automation-created-task-origin`). Inspect `api-steps.log`, `scenario.env`,
snapshots, and screenshots in the sweep output directory for each run.

## Seed Scenario Coverage

The realistic seed is split by product scenario. Each module below must remain
represented by a server seed validation and at least one browser validation
surface:

| Seed module | Product coverage | Browser validation surface |
| --- | --- | --- |
| `seed_workspace_scenarios.gleam` | Users, active/inactive membership, healthy and saturated project pool limits | Project switch, Pool health, People, Assignments |
| `seed_capability_scenarios.gleam` | Capabilities, task types, project member capability assignments | Capability Board and People filters |
| `seed_card_scenarios.gleam` | Card profile colors and per-project card inventory | Plan all-cards and Card Show inspection |
| `seed_task_scenarios.gleam` | Available, claimed, closed, RootPool, card-scoped, workflow-origin, and pool-lifetime task states | Pool, Task Show, Kanban, People ownership |
| `seed_plan_scenarios.gleam` | Direct-task cards, capability matrix cards, blockers, due dates, draft activation impact | Plan structure, card-scoped Kanban, activation impact, blocked work |
| `seed_people_scenarios.gleam` | Distributed ownership, overloaded members, ongoing work, blocked claimed work, free-person states | People route and scoped People view |
| `seed_root_card_scenarios.gleam` | Draft, active, closed, empty, card-heavy, and task-leaf root cards | Plan depth routes, all-cards route, root-card hierarchy inspection |
| `seed_activity_scenarios.gleam` | Notes, pinned notes, task positions, and work sessions | Card Show, Task Show, activity stream, Now Working |
| `seed_audit_events.gleam` | Canonical audit event history for task lifecycle and comments | Activity stream and metrics/history views |
| `seed_automation_definitions.gleam` | Engines, workflows, rules, templates, inactive and empty automation states | Automations Engines, Rules, Templates, Metrics |
| `seed_automation_executions.gleam` | Applied rule execution history from real rule evaluation | Automations Executions and generated-task origin |
| `seed_automation_diagnostics.gleam` | Ignored duplicate execution, missing template warning, noisy execution history | Automations diagnostics, execution history filters, metrics |

When adding a seed scenario, update this table, `seed_builder_validation_test`,
and the HT-12 static source list in `final_cleanup_ht12_ffi.erl` in the same
slice.

For database-only diagnostics:

```sh
make ht12-db-check
```

For static coverage of the documented scenario:

```sh
make ht12-plan-check
make ht12-static-check
```

The plan check guards this document's scenario coverage. The static check guards
the implementation against writing the retired `tasks.status` column in
lifecycle SQL; HT-12 uses `tasks.execution_state` as the canonical lifecycle
state.

Latest LAN evidence on this host:

- App URL: `http://192.168.1.120:8443`
- Database: `postgres://scrumbringer:scrumbringer@localhost:5433/scrumbringer_dev?sslmode=disable`
- Sweep: `/tmp/scrumbringer-ht12-sweep-20260620143550`
- Seeded project: `HT12143550`
- Final URL: `http://192.168.1.120:8443/app/pool?project=55&view=pool`
- Result: static, plan, database, API lifecycle, route-active, and responsive
  captures passed. The Pool canvas uses horizontal scroll for persisted desktop
  coordinates and resets to a one-column touch layout on mobile, avoiding the
  previous card overlap/cropping. The sweep auto-detected `/usr/bin/chromium`,
  clicked through `Cards`, each depth view, and back to `Pool` from the sidebar,
  recorded `localhost:5433 - aceptando conexiones`, and cleaned up its
  `ht12-sweep-*` browser session on exit.

### 1. Project And Hierarchy Setup

- Create or open a project dedicated to the run.
- Configure at least three card depth labels, for example:
  `Initiative`, `Feature`, `Task group`.
- Expected default labels for new projects are `Initiative`, `Feature`, and
  `Task group`; `Cards` remains the all-cards view, not a configured hierarchy
  depth.
- Create two depth-1 cards.
- Under the first depth-1 card, create two depth-2 cards.
- Under one depth-2 card, create two depth-3 cards.
- Verify the left sidebar shows `Pool`, `Cards`, each configured depth, and the
  admin sections without selecting several hierarchy links at once.
- Expected: every Pool/Card/depth route has exactly one active nav item with
  `aria-current="page"`.
- Expected: `Cards` is active only for the all-cards route.
- Expected: each depth route is active only for its own depth, and selecting a
  depth changes the visible hierarchy scope instead of behaving as a no-op.

### 2. Card Tree Navigation And Moves

- Open the all-cards view.
- Open each depth view from the sidebar.
- Open a card detail from each level.
- Move one card within the same parent.
- Move one card to another compatible parent.
- Try to create a task in a card that already contains child cards.
- Expected: hierarchy views preserve context, move actions refresh the tree, and
  the UI prevents mixing child cards and tasks in the same card.
- Expected: placing a task in a card that already contains child cards returns
  `CARD_HAS_CHILD_CARDS`.
- Expected: ambiguous task placement that specifies both `card_id` and
  `parent_card_id` returns `TASK_PARENT_CARD_CONFLICT`, not a removed planning
  artifact error code.

### 3. Task Creation Contexts

- From `Pool`, create a `RootPool` task.
- From a `Draft` card that accepts tasks, create a prepared task.
- From an `Active` card that accepts tasks, create a task that should enter the
  Pool immediately.
- Expected: the create dialog is contextual. Opening it from `Pool` creates a
  `RootPool` task; opening it from a card keeps that card as the fixed context.
  The dialog does not expose a central card selector.
- Expected: the create UI explains whether the task enters the Pool now or stays
  prepared until activation. No task is auto-claimed after creation.
- Expected: the active card Pool case is asserted in the automated sweep by
  creating, reading, claiming, and completing the task.
- Expected: trying to claim a task prepared under a `Draft` card returns
  `TASK_NOT_CLAIMABLE` until the containing card is activated.

### 4. Activation And Pool Impact

- Open a draft branch with descendant tasks.
- Activate it.
- Confirm the impact dialog shows descendant cards and tasks entering the Pool.
- Confirm the activation response includes Pool health: `pool_open_after`,
  `healthy_pool_limit`, and `pool_health`.
- With RootPool pressure above the default healthy limit, expected:
  `pool_health` is `exceeds_healthy_limit` and the UI warns without blocking the
  action.
- Navigate to `Pool`.
- Expected: tasks under the activated branch appear in the Pool if they are
  available, unblocked, and under an active card.
- Expected: Activation does not activate ancestors.

### 5. Claim, Release, Close

- Open a Pool task detail.
- Claim the task.
- Expected: the task leaves available Pool state and becomes claimed by the
  current user without a generic database error.
- Release the task.
- Expected: it returns to the Pool as available and records a release event.
- Claim it again, then close it.
- Expected: it becomes closed and no longer appears as claimable work.
- While a descendant task is claimed, attempt to close the parent branch.
- Expected: the server returns `CARD_HAS_CLAIMED_DESCENDANT` and the UI explains
  that the task must be closed or released before closing the branch.
- Close an active available-only branch.
- Expected: the branch closes, descendant available tasks are closed instead
  of hard-deleted, and the server records the close reason as
  `closed_by_ancestor`.

### 6. Delete And Operational History

- Create a fresh task with no operational history and delete it.
- Create another task, claim it, then attempt delete from all reachable menus.
- Create a fresh card with no children/history and delete it.
- Attempt to delete a card with child cards.
- Activate an otherwise empty card, then attempt delete.
- Expected: delete is disabled with contextual help, or the server returns
  `TASK_HAS_OPERATIONAL_HISTORY` and the UI restores the task without losing
  state. A claimed task is closed or released, not hard-deleted.
- Expected: stale or alternate delete clicks in the client submit DELETE only
  for visible available tasks with no dependency blockers; claimed, done, or
  blocked tasks are ignored locally. The backend remains authoritative for
  non-visible operational history such as notes, claim audit, activation, and
  dependency history.
- Expected: cards with children return `CONFLICT_HAS_CHILD_CARDS`; cards with
  activation/close/comment/audit history return `CARD_HAS_OPERATIONAL_HISTORY`
  and should be closed instead of hard-deleted.

### 7. Task Dependencies

- Create a task that depends on another open task in the same project.
- Attempt to claim the blocked task.
- Expected: the server returns `CONFLICT_BLOCKED`; the UI explains that
  open dependencies block claiming.
- Close the dependency task, then claim the previously blocked task.
- Expected: the task is claimable again without creating a new visual state.
- Create and then remove another dependency.
- Expected: the dependent task is claimable after the relation is removed.
- Attempt to create a circular dependency.
- Expected: the server rejects it with a validation error.
- Attempt to create a dependency across projects.
- Expected: the server rejects it; dependencies remain task-to-task within one
  project and are not introduced between cards.

### 6. Capabilities And People

- Open the project Capabilities board.
- Open the project People view.
- Open the same Capabilities and People views scoped to a card.
- Expected: the board keeps the same card/work-scope language as Plan and
  Kanban, and filters/scope controls do not overlap or disappear.
- Expected: the People view shows real project members, claimed/ongoing work,
  blockers, and empty/free-person states without duplicating actions that belong
  in Task Show.

### 7. Automation Console

- In the same seeded project, create an automation engine.
- Create a task template for generated follow-up work.
- Create an active rule that triggers on `task_completed` and creates a task
  from that template.
- Close a matching origin task.
- Expected: rule executions include an applied execution with
  `template_version`, `created_task_id`, and the generated task.
- Expected: opening the generated task in Task Show exposes its
  `automation_origin`, including the rule, engine, execution, template, and
  template version.
- Expected: the Automations console opens the Engines list, focused Rules view,
  Templates mode, and Executions mode for the created project without retired
  `/config/templates` or `/config/rule-metrics` surfaces.

### 8. Responsive And Usability Pass

Repeat the main Pool, card detail, activation, claim, and delete-history checks
at:

```sh
npx agent-browser set viewport 900 1100
npx agent-browser screenshot /tmp/scrumbringer-ht12-tablet.png
npx agent-browser set viewport 390 844
npx agent-browser screenshot /tmp/scrumbringer-ht12-mobile.png
```

Expected: no overlapping text, unreachable actions, clipped menus, blank panels,
or modal footer controls covering content. Touch targets remain usable.

## Current Execution Status

The latest automated attempt, on 2026-06-20 at 14:09 Europe/Madrid, passed
against the already-running PostgreSQL service on port `5433`. PostgreSQL was
not started by the test agent. The app runtime was started with:

```sh
DATABASE_URL="postgres://scrumbringer:scrumbringer@localhost:5433/scrumbringer_dev?sslmode=disable" scripts/dev-hot.sh
```

Runtime evidence:

```text
pg_isready -h /var/run/postgresql -p 5433 ... -> accepting connections
psql postgres://...@localhost:5433/... -> scrumbringer_dev|scrumbringer|::1|5433
curl http://127.0.0.1:8443/ -> 200 OK
curl http://127.0.0.1:8000/api/v1/auth/me -> 401 AUTH_REQUIRED
curl http://192.168.1.120:8443/ -> 200 OK
curl http://192.168.1.110:8443/ -> could not connect
```

The active runtime for this run was therefore available at
`http://127.0.0.1:8443` and `http://192.168.1.120:8443`.

Across the HT-12 hardening passes, the repair migration and the database
diagnostic were hardened for the task-claim path: the repair migration now
explicitly creates the card lifecycle columns and the task columns used by claim
(`card_id`, `pool_lifetime_s`, `last_entered_pool_at`, and
`created_from_rule_id`) instead of relying on older migration history. This
addresses the static cause most likely to surface as a generic `Database error`
when claiming from the Pool against a partially migrated database. A later
hardening pass also normalizes defaults/not-null constraints for
`pool_lifetime_s`, `cards.execution_state`, and
`project_settings.healthy_pool_limit`, and replaces stale lifecycle constraints
when they do not admit the HT-12 states and closed reasons.

The task creation UI now follows contextual creation from D5.1: Pool creation
has no card selector and creates RootPool tasks, while card creation keeps the
origin card as fixed context. If that context becomes invalid before submit
because the card is closed, missing, or already contains child cards, the dialog
explains the problem and disables submit. The API still returns explicit errors
such as `CARD_HAS_CHILD_CARDS` and `TASK_PARENT_CARD_CONFLICT` if a stale or
crafted request bypasses the UI.

The task delete UI now has a second client-side guard below the visible footer:
the mutation handler only submits hard delete for locally visible available and
unblocked tasks. This covers stale DOM or alternate entry points for claimed or
dependency-blocked tasks; the server still decides hidden operational history
and returns `TASK_HAS_OPERATIONAL_HISTORY` when a hard delete is not allowed.

The card/task contextual UI was also tightened for the multilingual user sweep:
task creation context hints now come from i18n keys instead of embedded English
strings, Spanish card phase labels render as `Draft`, `En curso`, and
`Closed`, and card action blockers use typed reasons translated by the modal.
This prevents card detail and creation flows from leaking English copy in the
Spanish UI while keeping the policy layer free of display strings.

Latest checks and sweep:

- `cd apps/server && gleam format --check src test`
- `cd apps/server && gleam check`
- `cd apps/client && gleam format --check src test`
- `cd apps/client && gleam test --target javascript` (`1591 passed`)
- `cd shared && gleam format --check src test`
- `cd shared && gleam test` (`217 passed`)
- `bash scripts/ht12-static-check.sh`
- `bash scripts/ht12-plan-check.sh`
- `bash scripts/ht12-db-schema-check.sh`
- `bash -n scripts/ht12-agent-browser-sweep.sh scripts/ht12-static-check.sh scripts/ht12-plan-check.sh scripts/ht12-db-schema-check.sh scripts/dev-hot.sh`
- `git diff --check`
- `make ht12-sweep-lan`
  passed and wrote evidence to `/tmp/scrumbringer-ht12-sweep-20260620143550`.
- `BASE_URL=http://127.0.0.1:18443 API_BASE=http://127.0.0.1:18000 DATABASE_URL="postgres://scrumbringer:scrumbringer@localhost:5433/scrumbringer_dev?sslmode=disable" bash scripts/ht12-agent-browser-sweep.sh`
  passed and wrote automation trigger coverage evidence to
  `/tmp/scrumbringer-ht12-sweep-20260624092846`.
- `BASE_URL=http://127.0.0.1:8443 API_BASE=http://127.0.0.1:8000 DATABASE_URL="postgres://scrumbringer:scrumbringer@localhost:5433/scrumbringer_dev?sslmode=disable" bash scripts/ht12-agent-browser-sweep.sh`
  passed with split Automations assertions for engines, rules, builder picker,
  templates, executions, generated task origin, responsive screenshots, and
  card-scoped routes. Evidence:
  `/tmp/scrumbringer-ht12-sweep-20260625005323`.
