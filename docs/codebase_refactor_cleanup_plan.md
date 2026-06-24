# Codebase refactor cleanup plan

## 1. Executive summary

The branch is in a healthy functional state: format and tests pass across shared,
client, and server. The remaining risk is not broken behavior; it is accumulated
complexity after the card/task hierarchy, Pool unification, Task Show/Card Show,
and automation work.

The highest value cleanup is to make the new card/task lifecycle model canonical
at explicit boundaries, then reduce client orchestration and feature-sized view
modules without inventing generic frameworks. The plan should proceed by narrow
slices that preserve behavior and keep tests green after every slice.

Top priorities:

| Priority | Proposal | Valor | Complejidad | Riesgo |
| --- | --- | --- | --- | --- |
| P0 | Freeze baseline and remove stale legacy/doc references | Alto | Baja | Bajo |
| P1 | Resolve task lifecycle duality: `completed`/`closed`, `task_state`/`domain/task/state` | Alto | Media | Alto |
| P1 | Centralize SQL/API lifecycle mapping at repository and contract boundaries | Alto | Media | Medio |
| P1 | Split Pool/root client dispatch by owned feature routes, not by generic dispatcher | Alto | Alta | Medio |
| P2 | Move Card Show/Task Show product surfaces out of generic `components/` and split by tabs/actions | Alto | Media | Medio |
| P2 | Extract Plan/tree selectors and action policy from `structure_view.gleam` | Alto | Media | Medio |
| P2 | Retire compatibility CSS/test helpers only after consumers are migrated | Medio | Media | Bajo |

## 2. Baseline

Diff baseline:

- Base commit: `3511cf309cb45015109f81ab78733e6db34ca1a0`
- Current HEAD audited: `bc76bca98b1d69b3f571438dbe4d661a56d04e49`
- Branch: `main`, ahead of `origin/main` by 234 commits during the audit
- Base is an ancestor of HEAD
- Diff size: 855 files changed, 82,340 insertions, 34,675 deletions
- Change mix: 208 added files, 117 deleted files, 462 modified files, plus renames

Verification run before writing this plan:

| Area | Command | Result |
| --- | --- | --- |
| Shared | `cd shared && gleam format --check src test && gleam test` | 241 passed |
| Client | `cd apps/client && gleam format --check src test && gleam test --target javascript` | 1757 passed |
| Server | `cd apps/server && gleam format --check src test && DATABASE_URL=... SB_DB_POOL_SIZE=2 gleam test --target erlang` | 580 passed |
| Git whitespace | `git diff --check` | Passed |

Skill note: the refactor skill references `rules/gleam/coding-standards.md` and
`rules/gleam/testing-practices.md`, but those files were not present in this
checkout. The active local standard used for this audit is
`docs/architecture/coding-standards.md`.

## 3. Inventory by layers

Approximate touched files by layer from `3511cf3..HEAD`:

| Layer | Files |
| --- | ---: |
| Client tests | 193 |
| Client feature views | 159 |
| Server SQL/generated SQL | 76 |
| Server HTTP/web | 68 |
| Shared domain | 54 |
| Server tests | 54 |
| Server use cases | 47 |
| Client UI components | 38 |
| Docs | 30 |
| DB migrations/schema | 28 |
| Shared tests | 23 |
| Client API | 19 |
| Client state/update | 11 |
| Server repositories | 7 |
| Scripts | 7 |
| Client styles | 7 |
| Server seeds | 3 |
| Shared API | 2 |

Largest current modules:

| Module | Approx. lines | Diagnosis |
| --- | ---: | --- |
| `apps/server/src/scrumbringer_server/sql.gleam` | 9388 | Generated artifact; do not hand-refactor. Reduce complexity through query files and repository boundaries. |
| `apps/server/src/scrumbringer_server/seed_builder.gleam` | 3298 | Fixture construction is too central for product validation flows. Split by domain scenario. |
| `apps/client/src/scrumbringer_client/client_update.gleam` | 2379 | Acceptable as TEA root, but still owns too much route/effect orchestration. |
| `apps/client/src/scrumbringer_client/client_view.gleam` | 2088 | App shell and route view composition remain broad. |
| `apps/server/src/scrumbringer_server/seed_db.gleam` | 1889 | DB seed orchestration should become scenario-based. |
| `apps/client/src/scrumbringer_client/features/plan/structure_view.gleam` | 1827 | View, filtering, policy, summaries, labels, and drag/move behavior are combined. |
| `apps/client/src/scrumbringer_client/components/card_show.gleam` | 1507 | Feature-sized product surface living in generic components. |
| `apps/client/src/scrumbringer_client/features/projects/update.gleam` | 1640 | Project CRUD/update orchestration hotspot. |
| `apps/client/src/scrumbringer_client/features/capability_board/view.gleam` | 1209 | Board, filters, labels, task actions, and rollups mixed. |
| `apps/server/src/scrumbringer_server/use_case/workflows/handlers.gleam` | 1171 | Automation use-case orchestration hotspot. |
| `apps/server/src/scrumbringer_server/use_case/cards_db.gleam` | 1166 | Card lifecycle SQL/use-case logic is concentrated. |
| `apps/client/src/scrumbringer_client/features/people/view.gleam` | 868 | People roster and task state presentation are mixed. |

## 4. Diagnosis by critical flow

| Flow | Current shape | Cleanup target | Valor | Complejidad | Riesgo |
| --- | --- | --- | --- | --- | --- |
| Card lifecycle | DB uses `draft`/`active`/`closed`; shared has `domain/card/state`; server `cards_db.gleam` still performs many raw SQL string checks. | Keep lifecycle rules in shared/domain and repository mappers; leave raw strings only at DB/API edges. | Alto | Media | Medio |
| Task lifecycle | New `domain/task/state` has `Available`/`Claimed`/`Closed`; older `task_state`/`task_status` still uses `Done` and API `completed`. | Choose one canonical internal model and document external compatibility strings. | Alto | Media | Alto |
| Pool claimability | Claim/release/complete is split into task routes, now-working, drag, and Pool update fallback. | Make Pool own canvas/filter behavior; task mutation route owns lifecycle actions. Remove fallback arms once routing proves coverage. | Alto | Alta | Medio |
| Plan/tree | `structure_view.gleam` computes scope, filters, move validity, rollups, labels, and DOM. | Extract pure selectors and action availability; keep DOM local. | Alto | Media | Medio |
| Kanban | Board uses card/task summaries and status filtering. | Reuse extracted lifecycle selectors; avoid a generic board abstraction. | Medio | Media | Medio |
| Capabilities | Capability board imports task status helpers and computes visibility/action affordances. | Share task presentation helpers and keep capability-specific layout local. | Medio | Media | Bajo |
| People | People view and state inspect claimed/ongoing task state directly. | Share selectors for "owned by user", "actively working", and display label. | Medio | Baja | Bajo |
| Card Show | Product surface includes tabs, notes, activity, activation, action menus, task list, and policies. | Move to feature namespace and split tab content/actions. | Alto | Media | Medio |
| Task Show | Task detail, dependencies, notes, activity, edit state, and transitions are route-coupled. | Keep one show state owner, split pure panels and action contexts. | Alto | Media | Medio |
| Card movement | Plan view and card policy already encode move constraints. | Centralize move policy labels and destinations; avoid duplicating disabled reasons in views. | Alto | Media | Medio |
| Due dates | Due date changes are represented in audit events and view sorting. | Keep due-date parsing/sorting in selectors, not view branches. | Medio | Baja | Bajo |
| Blockers/dependencies | SQL maps closed execution state to legacy `completed` labels for dependency views. | Treat as boundary compatibility and add tests before changing labels. | Alto | Media | Alto |
| Notes/activity | Card and task show surfaces share concepts but differ by target. | Share UI atoms (`notes_list`, `activity_feed`) only; keep target-specific APIs separate. | Medio | Baja | Bajo |
| Automations/workflows | `rule_list.gleam`, `admin/workflows.gleam`, and server handlers are feature-rich. | Split rule builder/list/history surfaces; keep domain automation ADTs. | Medio | Media | Medio |
| Project settings | Project update/view modules are large. | Extract dialog flows only where tests show repeated state/update shape. | Medio | Media | Medio |
| Validation seeds | Seeds cover rich product scenarios but are concentrated. | Split into named scenario modules and keep deterministic IDs/labels. | Alto | Media | Medio |

## 5. Diagnosis by architecture boundary

Shared/domain:

- `shared/src/domain/task.gleam` uses `task_state.TaskState` while
  `shared/src/domain/task/state.gleam` defines the newer execution-state model.
- `shared/src/domain/task_status.gleam` still exposes `TaskPhase` with `Done`
  serialized as `completed`.
- `shared/src/api/tasks/contracts.gleam` serializes close responses as
  `execution_state = "closed"` with `closed_reason`, while repository mappers and
  older task presenters still speak in `completed_at` and `completed`.
- `shared/src/domain/card/state.gleam`, `state_codec.gleam`, `activation.gleam`,
  and `closure.gleam` are the healthier shape: ADTs at domain level, codecs at
  boundaries.

Server/repository/use case:

- `cards_db.gleam` concentrates card activation, close, rollup, move, delete, and
  raw lifecycle strings. Its behavior is important and should be split only after
  characterization tests.
- SQL query files still contain compatibility projections such as mapping
  `tasks.execution_state = 'closed'` to `completed` in dependency/list responses.
- `repository/tasks/mappers.gleam` is the real task lifecycle choke point. It
  should own conversion from SQL rows to the canonical task model.
- `sql.gleam` is generated and large. Refactor source query files or repository
  callers, not the generated file directly.

HTTP/contracts:

- Card close request currently keeps reason as `String` in
  `shared/src/api/cards/contracts.gleam`; task close uses a typed
  `TaskClosedReason`. Card should converge toward typed request reasons.
- Error responses in `http/cards.gleam` and `http/tasks/*` are readable but
  should share lifecycle conflict helpers where semantics match.

Client/API/state/update:

- API modules should expose domain-shaped results and keep JSON/string decoding
  at the edge.
- `client_update.gleam` can remain the root TEA update function, but route-level
  side effects, URL sync, and show-stack normalization should be smaller helpers
  with focused tests.
- `features/pool/update.gleam` has many "handled earlier" no-op fallback arms.
  This is a useful transitional safety net, but it is also evidence that Pool
  knows too many feature message variants.

Views/UI/styles:

- The design system already exists (`button`, `data_table`, `filter_bar`,
  `work_surface`, `empty_state`, `dialog`, `activity_feed`, `notes_list`,
  `show_tabs`, `signal_chip`, `tone`). Do not build another generic UI layer.
- Feature-sized product surfaces should live under `features/`, not generic
  `components/`.
- Compatibility classes in UI helpers are acceptable while migrating tests and
  CSS, but should be tracked and removed intentionally.

Seeds/tests/docs:

- Seeds are now product validation assets. They need scenario modules, not a
  single ever-growing builder.
- Tests are broad and valuable. The next cleanup should reduce redundant
  snapshots only after behavior-level tests exist.
- Docs still contain historical references to removed milestone/detail modules;
  clean docs as part of the first slice so future agents do not chase deleted
  architecture.

## 6. UI componentization

Keep as shared UI:

- `ui/button.gleam`, `ui/action_menu.gleam`, `ui/data_table.gleam`
- `ui/filter_bar.gleam`, `features/layout/work_surface.gleam`
- `ui/dialog.gleam`, `ui/confirm_dialog.gleam`, `ui/empty_state.gleam`
- `ui/notes_list.gleam`, `ui/activity_feed.gleam`, `ui/show_tabs.gleam`
- `ui/card_state_badge.gleam`, `ui/task_state.gleam`, `ui/task_status_utils.gleam`

Move or split as feature code:

| Current module | Target | Reason | Valor | Complejidad | Riesgo |
| --- | --- | --- | --- | --- | --- |
| `components/card_show.gleam` | `features/cards/show.gleam` plus tab/action modules | It is a stateful Card Show feature, not a generic component. | Alto | Media | Medio |
| `components/card_crud_dialog.gleam` | Keep until Card admin/member creation flows settle | It still removes real duplication; avoid churn now. | Medio | Baja | Bajo |
| `components/task_type_crud_dialog.gleam` | Keep as admin feature candidate | Only move if admin namespace cleanup is already active. | Bajo | Baja | Bajo |
| `components/crud_dialog_base.gleam` | Keep, then remove compat class helpers when unused | It is useful but should not grow into a framework. | Medio | Media | Bajo |

UI cleanup principles:

- No new "universal board", "universal detail modal", or "generic workflow
  designer" abstraction.
- Use existing `work_surface` and `filter_bar` for operational views.
- Prefer product-specific modules for Card Show, Task Show, Plan, Pool, People,
  Capabilities, and Automations.
- Use icons/buttons already in the local UI system; avoid text-heavy controls
  where icon controls exist.

## 7. Hotspots module by module

| Module | Diagnosis | Proposal | Valor | Complejidad | Riesgo |
| --- | --- | --- | --- | --- | --- |
| `shared/src/domain/task.gleam` | Task entity exposes older `task_state` helpers. | Define whether this remains the API/presenter model or migrates to `domain/task/state`. | Alto | Media | Alto |
| `shared/src/domain/task_state.gleam` | Good invariant shape, but uses `Done/completed`. | Either rename into compatibility module or replace with new execution state. | Alto | Media | Alto |
| `shared/src/domain/task/state.gleam` | Better closed-reason model. | Make this the canonical lifecycle for new contracts. | Alto | Media | Medio |
| `shared/src/domain/task_status.gleam` | UI-facing flattened status remains useful. | Keep as presenter type, not persistence truth. | Medio | Baja | Medio |
| `shared/src/api/tasks/contracts.gleam` | Typed close contract already points to new model. | Add tests that lock `closed_reason` and compatibility behavior. | Alto | Baja | Medio |
| `shared/src/api/cards/contracts.gleam` | Card close reason is still raw string. | Introduce typed `CardClosedReason` request decoding. | Medio | Baja | Medio |
| `apps/server/src/scrumbringer_server/repository/tasks/mappers.gleam` | Central conversion from SQL to domain. | Refactor around canonical task lifecycle after tests. | Alto | Media | Alto |
| `apps/server/src/scrumbringer_server/use_case/cards_db.gleam` | Contains lifecycle SQL and card policies. | Split activation/closure/move/delete into internal helpers or modules after characterization. | Alto | Alta | Medio |
| `apps/server/src/scrumbringer_server/use_case/workflows/handlers.gleam` | Automation orchestration is large. | Split trigger matching, action execution, audit/history recording. | Medio | Media | Medio |
| `apps/server/src/scrumbringer_server/use_case/rules_engine.gleam` | Domain engine is central to automation behavior. | Keep pure and test-driven; avoid moving HTTP/DB concerns into it. | Alto | Media | Medio |
| `apps/server/src/scrumbringer_server/http/cards.gleam` | Error mapping and action endpoints are broad. | Extract lifecycle response helpers only after card contract typing. | Medio | Media | Bajo |
| `apps/server/src/scrumbringer_server/http/tasks/*` | Tasks are already split by filters/transitions/dependencies/presenters. | Normalize lifecycle terms and conflict helpers; avoid recombining. | Alto | Media | Medio |
| `apps/server/src/scrumbringer_server/seed_builder.gleam` | Massive scenario builder. | Split by scenario: hierarchy, pool, automation, notes/activity, permissions. | Alto | Media | Medio |
| `apps/server/src/scrumbringer_server/seed_db.gleam` | Large persistence orchestration. | Pair with scenario builder split; keep DB insert order explicit. | Alto | Media | Medio |
| `apps/client/src/scrumbringer_client/client_update.gleam` | Root TEA dispatcher with route/effect helpers. | Keep root, extract route sync/show-stack/bootstrap helpers with tests. | Alto | Alta | Medio |
| `apps/client/src/scrumbringer_client/features/pool/update.gleam` | Transitional no-op fallback knows many feature messages. | Remove groups only after specific route `try_update` tests prove handling. | Alto | Alta | Medio |
| `apps/client/src/scrumbringer_client/components/card_show.gleam` | Feature-sized stateful surface. | Move/split into Card Show feature modules. | Alto | Media | Medio |
| `apps/client/src/scrumbringer_client/features/plan/structure_view.gleam` | Combines selectors, policy labels, drag behavior, and DOM. | Extract selectors/action availability/move view model. | Alto | Media | Medio |
| `apps/client/src/scrumbringer_client/features/views/kanban_board.gleam` | Board presentation depends on lifecycle summaries. | Reuse selectors; do not abstract all board layouts. | Medio | Media | Bajo |
| `apps/client/src/scrumbringer_client/features/capability_board/view.gleam` | Similar status/action logic to Plan/People. | Share task display helpers, keep capability layout specific. | Medio | Media | Bajo |
| `apps/client/src/scrumbringer_client/features/people/view.gleam` | Roster and task state display mixed. | Extract member task selectors. | Medio | Baja | Bajo |
| `apps/client/src/scrumbringer_client/features/automations/rule_list.gleam` | Rule list, builder, filters, and template selection are broad. | Split builder form from list/history once behavior tests are in place. | Medio | Media | Medio |
| `apps/client/src/scrumbringer_client/router.gleam` | Contains legacy config slug redirects. | Remove only after redirect acceptance tests and docs update. | Medio | Baja | Bajo |

## 8. Obsolete/legacy code to remove

Already removed in the diff and should stay removed:

- `features/milestones/*`, `api/milestones.gleam`, server milestone HTTP/service
  modules, milestone shared domain/tests.
- `components/card_detail_modal.gleam`.
- Old task detail footer/header/summary/tabs modules.
- Old admin task template/workflow rule view modules replaced by newer admin and
  automation surfaces.

Active legacy or compatibility candidates:

| Candidate | Action | Valor | Complejidad | Riesgo |
| --- | --- | --- | --- | --- |
| Docs referencing deleted milestone/detail modules | Remove or mark historical. | Alto | Baja | Bajo |
| `router.gleam` legacy config slug redirect | Keep until route compatibility window is closed; then delete with tests. | Medio | Baja | Bajo |
| UI compat class helpers in `button`, `signal_chip`, `crud_dialog_base`, `empty_state`, `action_buttons` | Track consumers and remove when CSS/tests no longer require them. | Medio | Media | Bajo |
| `api/payload_fields.gleam` legacy PATCH active flag | Keep only if workflow/rule endpoints still require it; otherwise migrate endpoint payloads. | Medio | Media | Medio |
| DB `invalid_migrated_rule` trigger kind | Verify production/dev data need; remove constraint value only after migration check. | Medio | Media | Alto |
| SQL projections from `closed` to `completed` | Treat as API compatibility until the task lifecycle migration is complete. | Alto | Media | Alto |

## 9. Simplification opportunities

| Opportunity | Proposal | Valor | Complejidad | Riesgo |
| --- | --- | --- | --- | --- |
| Lifecycle strings scattered across SQL/API/UI | Introduce explicit codec modules and repository mappers as the only string boundaries. | Alto | Media | Alto |
| Repeated task status labels in Plan/People/Capability/Card Show | Reuse `ui/task_state.gleam` and `ui/task_status_utils.gleam`; move missing labels there. | Medio | Baja | Bajo |
| Pool fallback arms | Delete one group at a time after route tests cover the owner. | Alto | Alta | Medio |
| Seed builder size | Split scenario modules with stable public entrypoints. | Alto | Media | Medio |
| Card move disabled reasons | Keep in `features/cards/policy.gleam`; views should consume labels/view models. | Alto | Baja | Medio |
| Docs as historical noise | Archive or mark old plans as executed/historical; keep architecture docs current. | Medio | Baja | Bajo |

## 10. Type improvements

| Type improvement | Target | Valor | Complejidad | Riesgo |
| --- | --- | --- | --- | --- |
| Canonical task execution state | `domain/task/state.gleam`, task repository mappers, HTTP presenters | Alto | Media | Alto |
| Typed card close request reason | `shared/src/api/cards/contracts.gleam` | Medio | Baja | Medio |
| Newtype IDs at boundaries | Avoid raw `Int` for new card/task/user APIs where modules already provide IDs. | Medio | Media | Medio |
| Automation trigger/action boundary codecs | Keep `domain/automation.gleam` pure; move string codecs to boundary helpers if public surface grows. | Medio | Media | Medio |
| Plan action availability view model | Replace raw disabled strings in `structure_view.gleam` with typed action availability. | Alto | Baja | Bajo |
| Task ownership selectors | Shared client selectors for claimed-by/current-user/ongoing. | Medio | Baja | Bajo |

Do not type every DB or JSON string immediately. Only promote strings that cross
multiple boundaries or encode business invariants.

## 11. Lustre/UI improvements

| Improvement | Target | Valor | Complejidad | Riesgo |
| --- | --- | --- | --- | --- |
| Keep root TEA but reduce orchestration helpers | `client_update.gleam` | Alto | Alta | Medio |
| Feature-owned show surfaces | Card Show and Task Show | Alto | Media | Medio |
| Pure selectors before view split | Plan, Capability, People, Kanban | Alto | Media | Bajo |
| Reduce modal-first product behavior only where workflow benefits | Card/Task create/edit/show flows | Medio | Media | Medio |
| Standard empty/loading/error states | Use `empty_state.Meaning`, `remote`, and existing UI helpers | Medio | Baja | Bajo |
| Compatibility class retirement | UI helpers and styles | Medio | Media | Bajo |

Lustre rule for this cleanup: split update/view modules only when a clear owner
exists. Do not add dispatch indirection that makes messages harder to trace.

## 12. Execution plan by slices

1. Baseline and stale reference cleanup
   - Update architecture docs that mention deleted milestone/detail modules.
   - Create a legacy/compatibility inventory in docs or code comments.
   - Valor: Alto. Complejidad: Baja. Riesgo: Bajo.

2. Task lifecycle contract decision
   - Decide canonical internal model for task execution.
   - Add tests around `closed`/`completed` compatibility before code changes.
   - Valor: Alto. Complejidad: Media. Riesgo: Alto.

3. Repository and SQL boundary cleanup
   - Centralize task/card lifecycle decoding in repository mappers.
   - Leave generated `sql.gleam` alone.
   - Valor: Alto. Complejidad: Media. Riesgo: Alto.

4. HTTP and shared API contract normalization
   - Type card close reason.
   - Normalize lifecycle conflict helper responses.
   - Valor: Medio. Complejidad: Media. Riesgo: Medio.

5. Client API/state/update routing cleanup
   - Extract show-stack and URL sync helpers.
   - Remove Pool no-op fallback groups only with owner tests.
   - Valor: Alto. Complejidad: Alta. Riesgo: Medio.

6. Card Show and Task Show feature split
   - Move Card Show to feature namespace.
   - Split notes/activity/tasks/actions panels while preserving parent messages.
   - Valor: Alto. Complejidad: Media. Riesgo: Medio.

7. Plan/tree selectors and policy extraction
   - Extract rollups, visibility, action availability, and move view model.
   - Keep DOM in `structure_view.gleam`.
   - Valor: Alto. Complejidad: Media. Riesgo: Medio.

8. Kanban/Capabilities/People selector reuse
   - Reuse task labels/ownership/action selectors.
   - Avoid generic board abstraction.
   - Valor: Medio. Complejidad: Media. Riesgo: Bajo.

9. Automations and workflow cleanup
   - Split rule builder/list/history surfaces.
   - Keep engine/domain behavior under test.
   - Valor: Medio. Complejidad: Media. Riesgo: Medio.

10. Seeds and validation scenarios
    - Split seed builder by named product scenario.
    - Preserve deterministic validation data.
    - Valor: Alto. Complejidad: Media. Riesgo: Medio.

11. Tests/docs/final sweep
    - Remove redundant tests only after behavior coverage exists.
    - Run static, unit, server DB, and browser validations.
    - Valor: Alto. Complejidad: Media. Riesgo: Medio.

## 13. Tests per slice

| Slice | Minimum tests |
| --- | --- |
| Baseline/docs | `git diff --check`; docs link/reference grep for removed module names. |
| Task lifecycle | Shared tests for task state codecs, repository mapper tests, HTTP task close tests, dependency tests. |
| SQL/repository | Server tests for claim/release/complete/close-by-ancestor, card close/rollup, dependency blocking. |
| HTTP/contracts | Shared API contract tests plus server HTTP tests for validation and conflicts. |
| Client routing/update | Client update tests for route sync, show-stack normalization, Pool route ownership. |
| Card/Task Show | Component/update tests for tabs, notes, activity, close/create/edit actions. |
| Plan/tree | Selector unit tests for scope, closed visibility, move validity, rollups, due-date sorting. |
| Kanban/Capabilities/People | View/update tests for task visibility, ownership, action affordances. |
| Automations | Rule engine unit tests, handler tests, HTTP rule/workflow tests, client form tests. |
| Seeds | Server seed tests plus validation scripts that assert required scenarios exist. |
| Final | Shared/client/server format and tests, static checks, browser validations. |

Use `let assert` in Gleam tests. Keep snapshot tests only where they protect
meaningful UI structure; prefer behavior tests for lifecycle and routing.

## 14. Acceptance criteria

The cleanup/refactor goal is complete only when:

- No active code imports deleted milestone/detail modules.
- Docs no longer present deleted modules as current architecture.
- Task lifecycle has a documented canonical internal model.
- DB/API compatibility strings are isolated to codecs, SQL, or repository mappers.
- `cards_db.gleam`, `client_update.gleam`, `pool/update.gleam`,
  `card_show.gleam`, and `structure_view.gleam` are smaller or have clearer
  internal ownership with tests.
- Feature-sized UI surfaces live under `features/` unless they are genuinely
  reusable components.
- Compatibility helpers have an owner and removal criteria.
- Seed scenarios are named and testable.
- Shared, client, and server tests pass.
- Browser validations pass for Pool, Plan/tree, Card Show, Task Show,
  Capability board, People, Kanban, Automations, and project settings.

## 15. Recommended agent-browser validations

Run after each UI-affecting slice:

| Area | Validation |
| --- | --- |
| Pool | Claim, release, complete, drag-to-claim, filters, view mode, now-working panel. |
| Plan/tree | Scope by depth/card, show closed toggle, status/sort filters, move card by menu and drag, create task/subcard actions. |
| Kanban | Card/task visibility, closed/done filtering, action affordances. |
| Card Show | Open/close, tabs, notes add/delete/pin, activity more, activate, create task, create subcard, close/delete affordances. |
| Task Show | Open/close, edit, notes, dependencies add/remove, activity more, claim/release/complete. |
| Capabilities | Board filters, task status labels, member capability dialogs. |
| People | Roster search/sort/filter, claimed/ongoing labels, task action visibility. |
| Automations | Workflow list, rule builder, template picker, enable/disable, execution history, metrics drilldown. |
| Project settings | Members, invites, task types, cards, API tokens, project switching. |

Use screenshots and DOM checks for layout overlap on desktop and mobile. For
state transitions, validate both UI feedback and server-persisted refresh.

## 16. Rejected overengineering improvements

Do not do these as part of the cleanup:

- Do not manually refactor generated `sql.gleam`.
- Do not create a generic service/manager/facade layer over use cases.
- Do not invent a second design system or generic `Surface` framework.
- Do not force Plan, Kanban, Capability Board, and People into one generic board.
- Do not move feature-specific Card Show/Task Show panels into `ui/`.
- Do not remove all modals as a blanket rule.
- Do not convert every string to an ADT; focus on business invariants and
  repeated boundary strings.
- Do not rewrite the router as a full state machine before removing narrower
  legacy redirects.
- Do not collapse all automation UI into one generic workflow builder.

## 17. Future commit order

Recommended commit sequence:

1. Baseline checks and stale docs/obsolete references.
2. Shared task/card lifecycle type decisions and contract tests.
3. SQL/repository lifecycle boundary cleanup.
4. Server use-case split for cards/tasks/workflows.
5. HTTP payload, presenter, and conflict response normalization.
6. Client API decoding and state selector cleanup.
7. Root `client_update.gleam` route/show-stack helper extraction.
8. Pool update ownership cleanup and no-op fallback reduction.
9. Card Show and Task Show feature module split.
10. Plan/tree selector and move-policy extraction.
11. Kanban, Capability Board, and People selector reuse.
12. Automations/rules UI and handler split.
13. Seed scenario split.
14. Test pruning/additions and browser validations.
15. Docs update and final anti-legacy, anti-duplication, anti-overengineering sweep.
