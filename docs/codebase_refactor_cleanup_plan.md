# Codebase refactor cleanup plan

## 1. Executive summary

This is a final codebase refactor plan, not only a hotspot cleanup. The branch is
functionally healthy, but the codebase now needs a global pass by product layer:
domain, contracts, persistence, HTTP, client API, routing, state/update, product
surfaces, design system/styles, i18n/copy, seeds, tests, docs, and migrations.

The main decision is fixed here:

- `shared/src/domain/task/state.gleam` is the canonical task execution model.
- `shared/src/domain/task_status.gleam` remains a presentation/filter model.
- The former task-state compatibility module has been removed; repository,
  presenter, client, and test callers use the canonical execution model.
- `shared/src/domain/card/state.gleam` is the canonical card execution model.
- `shared/src/api/cards/contracts.gleam` uses typed `CardClosedReason`, not a
  raw close reason string.
- Legacy compatibility is allowed only as an intermediate refactor step. The
  final state must eliminate it or isolate it at a strictly external boundary
  with tests, owner, and explicit product justification.

Top priorities:

| Priority | Proposal | Valor | Complejidad | Riesgo |
| --- | --- | --- | --- | --- |
| P0 | Recompute execution baseline, document legacy removal, and remove stale architecture references | Alto | Baja | Bajo |
| P1 | Make card/task lifecycle ADTs canonical across shared, DB mappers, HTTP, client API, and UI | Alto | Alta | Alto |
| P1 | Normalize due dates across Date typing, DB/API codecs, project timezone, activity, seeds, and visual urgency | Alto | Media | Alto |
| P1 | Promote automations/workflows to a strategic refactor block | Alto | Alta | Medio |
| P1 | Define a canonical URL/routing contract for scopes, shows, automations, sidebar, and redirects | Alto | Alta | Alto |
| P1 | Refactor project settings, hierarchy configuration, permissions, and onboarding/wizard flows as one product area | Alto | Alta | Medio |
| P1 | Split seed scenarios and bind each to browser validation coverage | Alto | Media | Medio |
| P2 | Reduce Pool, Plan, Card Show, Task Show, Kanban, People, and Capability surfaces by feature-owned selectors and panels | Alto | Alta | Medio |
| P2 | Audit i18n/copy for legacy terms and key coverage | Alto | Media | Bajo |
| P2 | Audit styles/design system for dead classes, compat classes, focus/mobile states, and token consistency | Alto | Media | Medio |
| P2 | Partition oversized tests and fixtures after behavior coverage is locked | Medio | Media | Medio |

## 2. Baseline

This section records the audit that produced the plan. It is not a reusable
execution baseline. Every execution goal must recompute the baseline before
touching code.

Mandatory execution baseline:

- Record current branch, `HEAD`, upstream/ahead-behind state, and dirty files.
- Recompute the base comparison commit/branch and verify it is an ancestor.
- Recompute diff stat, changed-file layer inventory, deleted/renamed files, and
  largest current modules.
- Rerun shared, client, and server format/tests on the current checkout.
- Rerun static/schema checks used by the project before starting structural
  edits.
- Stop and update the plan if the current code has materially diverged from this
  audit.

Historical audit baseline:

- Base commit: `3511cf309cb45015109f81ab78733e6db34ca1a0`
- Code HEAD audited before plan-only commits: `bc76bca98b1d69b3f571438dbe4d661a56d04e49`
- Branch during audit: `main`, ahead of `origin/main`
- Base is an ancestor of the audited code HEAD
- Diff size at audit time: 855 files changed, 82,340 insertions, 34,675 deletions
- Change mix at audit time: 208 added files, 117 deleted files, 462 modified
  files, plus renames

Verification run before writing the plan, for audit context only:

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

Prior product decisions to reuse, not reinvent:

| Source | Use in this refactor |
| --- | --- |
| `docs/pool-work-surface-unification-plan.md` | Pool surface, work-surface composition, member workflows, and validation expectations. |
| `docs/card-task-show-redesign-plan.md` | Card Show and Task Show product direction, tabs, notes/activity/dependency behavior, and show routing. |
| `docs/card-task-show-ui-correction-plan.md` | Follow-up UI corrections for Card/Task Show that should be preserved. |
| `docs/card-tree-task-leaves-model.md` | Canonical hierarchy/product model for card trees and task leaves. |
| `docs/bottom-up-data-model-refactor-plan.md` | Data model refactor constraints and persistence migration context. |
| `docs/fin_refactor.md` | Workflow/automation finish-state decisions and final validation intent. |
| `docs/pull-flow-model-hardening-plan.md` | Pull-flow hardening constraints for Pool, claimability, and work lifecycle. |

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

Global refactor inventory:

| Layer | Representative files | Diagnosis |
| --- | --- | --- |
| Shared lifecycle/domain | `shared/src/domain/task/state.gleam`, `task_status.gleam`, `card/state.gleam`, `card/closure.gleam` | Card and task execution states have canonical ADTs; task status remains for presentation/filter projection. |
| Shared API contracts | `shared/src/api/tasks/contracts.gleam`, `shared/src/api/cards/contracts.gleam` | Task close and card close requests use typed close reasons. |
| Persistence/migrations | `db/schema.sql`, `db/migrations/*`, server SQL query files | Lifecycle strings and transitional migration values need explicit ownership. |
| Server repositories/use cases | `cards_db.gleam`, `projects_db.gleam`, `rules_engine.gleam`, `workflows/handlers.gleam`, task repository mappers | Product rules are concentrated in large orchestration modules. |
| HTTP/API | `http/cards.gleam`, `http/tasks/*`, `http/rules.gleam`, `http/projects.gleam`, `http/task_templates.gleam`, `http/api_tokens.gleam` | Endpoint modules are mostly split, but contract naming and lifecycle terms diverge. |
| Client API/state/update | `client_update.gleam`, `client_state.gleam`, `url_state.gleam`, `router.gleam`, `features/hydration/update.gleam`, `api/*` | URL, hydration, show state, sidebar scope, and feature routing are strategic boundaries. |
| Product surfaces | Pool, Plan, Card Show, Task Show, Kanban, Capability Board, People, Projects, Admin, Automations | Several surfaces are feature-sized and need selectors/view models before splitting DOM. |
| Admin/settings/security | `features/projects/*`, `features/admin/*`, `features/assignments/update.gleam`, `permissions.gleam`, API tokens, auth/reset/invite flows | Project settings, assignments, and permissions are central to the hierarchy model, not secondary CRUD. |
| I18n/copy | `i18n/text.gleam`, `i18n/en.gleam`, `i18n/es.gleam` | Large key surface needs terminology cleanup and coverage tests. |
| Styles/design system | `styles/ux.gleam`, `styles/layout.gleam`, UI modules | Existing system should be audited for dead classes, compat classes, mobile/focus states, and token drift. |
| Seeds/QA | `seed_builder.gleam`, `seed_db.gleam` | Seeds are QA infrastructure and must map to browser validation scenarios. |
| Tests | Large server/client tests, shared contract tests | Some tests protect behavior, but oversized files and repeated fixtures now slow maintenance. |

Largest modules that must be considered in the final refactor:

| Module | Approx. lines | Refactor meaning |
| --- | ---: | --- |
| `apps/server/src/scrumbringer_server/sql.gleam` | 9388 | Generated artifact. Refactor query sources and repository boundaries, not this file by hand. |
| `apps/server/src/scrumbringer_server/seed_builder.gleam` | 3298 | Split into scenario builders tied to product validations. |
| `apps/client/src/scrumbringer_client/client_update.gleam` | 2379 | Root TEA is valid, but URL/show/bootstrap orchestration needs tighter ownership. |
| `apps/client/src/scrumbringer_client/client_view.gleam` | 2088 | App shell and route view composition need route-owned surfaces. |
| `apps/server/src/scrumbringer_server/seed_db.gleam` | 1889 | DB seed orchestration should mirror scenario modules. |
| `apps/client/src/scrumbringer_client/features/plan/structure_view.gleam` | 1827 | Extract selectors, rollups, policy, and move view model. |
| `apps/client/src/scrumbringer_client/features/projects/update.gleam` | 1640 | Project/settings flow is a first-class refactor block. |
| `apps/client/src/scrumbringer_client/components/card_show.gleam` | 1507 | Move to feature namespace and split panels/actions. |
| `apps/client/src/scrumbringer_client/i18n/es.gleam` / `en.gleam` / `text.gleam` | 1372 / 1347 / 1130 | Copy and key coverage need a dedicated slice. |
| `apps/client/src/scrumbringer_client/features/automations/rule_list.gleam` | 1273 | P1 strategic area, not secondary cleanup. |
| `apps/client/src/scrumbringer_client/features/capability_board/view.gleam` | 1209 | Needs shared task/action selectors, not a generic board. |
| `apps/server/src/scrumbringer_server/use_case/workflows/handlers.gleam` | 1171 | Split trigger matching, action execution, outcome, audit/history. |
| `apps/server/src/scrumbringer_server/use_case/cards_db.gleam` | 1166 | Split card lifecycle use cases after characterization. |
| `apps/server/src/scrumbringer_server/use_case/projects_db.gleam` | 1121 | Project hierarchy/settings persistence is central. |
| `apps/client/src/scrumbringer_client/url_state.gleam` | 991 | Canonical URL state and round-trip tests required. |
| `apps/client/src/scrumbringer_client/features/assignments/update.gleam` | 876 | Admin assignment/auth policy flow must be part of permissions cleanup. |
| `apps/client/src/scrumbringer_client/features/hydration/update.gleam` | 763 | Hydration coordinates auth, resources, routes, and redirects; it is a routing boundary. |
| `apps/client/src/scrumbringer_client/styles/ux.gleam` | 715 | Needs design-system/style audit. |
| `apps/client/src/scrumbringer_client/router.gleam` | 763 | Redirects, deep links, sidebar/show state contract. |

## 4. Diagnosis by critical flow

| Flow | Current shape | Cleanup target | Valor | Complejidad | Riesgo |
| --- | --- | --- | --- | --- | --- |
| Card lifecycle | DB uses `draft`/`active`/`closed`; shared has typed card state; card close contract still accepts raw reason string. | Use `domain/card/state.gleam` and typed `CardClosedReason` through shared contracts, mappers, presenters, and client API. | Alto | Media | Alto |
| Task lifecycle | `domain/task/state.gleam` has `Available`/`Claimed`/`Closed`; `task_status` maps closed presentation filters to the external `completed` value only at the boundary. | Keep `domain/task/state.gleam` canonical; keep `task_status` only for presentation/filter projection; remove or isolate any remaining lifecycle compatibility names. | Alto | Alta | Alto |
| Due dates | Card contracts, Pool urgency, card overdue surfaces, audit events, seeds, and UI labels all touch due-date semantics. | Define Date/project-timezone semantics, codecs, DB mapping, `DueDateChanged` activity, visual urgency rules, seeds, and browser validations. | Alto | Media | Alto |
| Pool claimability | Claim/release/close is split across task route, now-working, drag, and Pool fallback arms. | Pool owns canvas/filter/drag context; task mutation route owns lifecycle; fallback arms are removed by owner tests. | Alto | Alta | Medio |
| Plan/tree | `structure_view.gleam` combines scope, filters, move validity, rollups, labels, and DOM. | Extract selectors, rollups, action availability, and move view model before DOM split. | Alto | Media | Medio |
| Kanban | Board depends on lifecycle summaries and visibility. | Reuse lifecycle selectors; do not introduce a generic board abstraction. | Medio | Media | Medio |
| Capabilities | Capability board computes status visibility and actions. | Share task display/action helpers; keep capability-specific layout local. | Medio | Media | Bajo |
| People | People view/state inspect claimed/ongoing task state directly. | Share selectors for ownership, active work, and display labels. | Medio | Baja | Bajo |
| Card Show | Surface includes tabs, notes, activity, activation, action menus, task list, and policy decisions. | Move to feature namespace and split panels/actions using existing UI atoms. | Alto | Media | Medio |
| Task Show | Detail/edit/dependencies/notes/activity/transitions are route-coupled. | Keep one state owner; split pure panels and action contexts. | Alto | Media | Medio |
| Automations/workflows | Rule builder/list/history, workflow admin names, metrics, templates, engine, and handlers are strategic and large. | P1 split: builder/list/history, outcome ADT, engine purity, handler boundaries, naming cleanup. | Alto | Alta | Medio |
| Project settings/hierarchy | Project update/view/server persistence are large and define hierarchy behavior. | Treat settings, wizard, max depth, permissions, and project switching as one product model. | Alto | Alta | Medio |
| Routing/deep links/hydration | `url_state`, `router`, `hydration/update`, and `client_update` coordinate scopes, shows, sidebar, auth resources, redirects, admin, and automations. | Define canonical URL/hydration contract with round-trip tests; legacy redirects must be removed or isolated as external-boundary adapters. | Alto | Alta | Alto |
| Auth/security/API tokens/assignments | Auth, invite/reset, assignments, roles, permissions, and tokens are scattered across admin/client/server. | Audit boundary naming, root auth policy, permission checks, token flows, and tests as security-critical. | Alto | Media | Alto |
| I18n/copy | Large key modules may preserve old terms (`done`, `completed`, workflow/admin names). | Normalize product terms and add key coverage tests. | Alto | Media | Bajo |
| Styles/design system | Existing UI system is useful, but styles may contain dead classes and compat states. | Audit CSS classes, focus/mobile/interactive states, tokens, and DESIGN consistency. | Alto | Media | Medio |
| Migrations/schema | Transitional migration names and constraint values remain. | Classify as active contract, compatibility, or one-time migration residue. | Alto | Media | Alto |
| Seeds/browser QA | Seeds are rich product validation assets. | Map seed scenario -> product use case -> agent-browser validation. | Alto | Media | Medio |
| Tests | Large tests protect behavior but can become unmaintainable. | Partition fixtures and tests after behavior coverage is locked. | Medio | Media | Medio |

## 5. Diagnosis by architecture boundary

Shared/domain:

- `shared/src/domain/task/state.gleam` is the canonical internal task execution
  state. It should absorb `Available`, `Claimed`, `Closed`, close reasons, claim
  mode, and closed metadata.
- `shared/src/domain/task_status.gleam` remains useful only as a UI/filter
  projection: available, claimed, ongoing, and closed labels, with `completed`
  retained only as an external filter value.
- `task_status.gleam` is allowed in final code only for UI labels, filter values,
  and presentation projections. It is prohibited as the domain execution model,
  persistence representation, repository truth, automation/rules-engine state,
  seed truth, or workflow transition model.
- The former task-state compatibility module has been deleted. Its deletion
  criteria were repository mappers, HTTP presenters, client task selectors,
  Plan/People/Capability/Card Show, and tests no longer needing it.
- `shared/src/domain/card/state.gleam`, `card/state_codec.gleam`,
  `card/activation.gleam`, and `card/closure.gleam` are the target shape:
  ADTs in domain, codecs at boundaries.
- `shared/src/domain/automation.gleam` has broad public surface. Keep the domain
  model, but move trigger/action string codecs to explicit boundary modules if
  they are only needed for DB/API/forms.

Task state migration phases:

| Phase | Consumers to migrate | Completion rule |
| --- | --- | --- |
| 1. Shared entity/codecs | `shared/src/domain/task.gleam`, `task/task_codec.gleam`, task creation helpers, API task contracts | Shared task data exposes canonical execution state or explicit presentation projections only. |
| 2. Server mappers/persistence | `repository/tasks/mappers.gleam`, `repository/tasks/queries.gleam`, SQL row adapters, seeds | Repositories return canonical task execution state; DB strings do not leak into use cases. |
| 3. HTTP presenters/filters | `http/tasks/presenters.gleam`, task filters, conflict handlers, dependency presenters, metrics presenters | HTTP compatibility strings exist only in response/request boundary code. |
| 4. Automation engine/workflows | `rules_engine.gleam`, `workflows/handlers.gleam`, `workflows/types.gleam`, task dependency use cases | Rules and workflow transitions use canonical execution state, not `task_status`. |
| 5. Client API/selectors | `api/tasks/*`, shared client selectors, Pool/People/Capability/Plan/Kanban selectors | Client state stores canonical execution state and derives presentation labels. |
| 6. Product surfaces | Pool, People, Card Show, Task Show, Plan, Kanban, Capability Board, now-working panels | Views consume selectors/presentation helpers only. |
| 7. Deletion | Old compatibility task-state module and obsolete tests/imports | Legacy file is removed and `rg task_state` shows no strategic callers outside intentional aliases. |

Shared API contracts:

- `shared/src/api/tasks/contracts.gleam` already points in the right direction
  by returning `execution_state = "closed"` plus `closed_reason`.
- `shared/src/api/cards/contracts.gleam` decodes card close requests into typed
  `CardClosedReason`.
- Contract modules should be the only shared place where external JSON strings
  are parsed.
- Due-date contract modules must define whether incoming values are date-only or
  datetime-like strings, how project timezone affects overdue/urgency, and how
  `DueDateChanged` activity is emitted.

Persistence/migrations:

- Generated `sql.gleam` is not a hand-refactor target.
- SQL query files and repository mappers are the actual boundaries for DB
  strings such as `draft`, `active`, `closed`, `available`, `claimed`,
  `completed`, and `closed_by_ancestor`.
- Transitional values such as `invalid_migrated_rule` must be classified before
  removal: persisted external-boundary compatibility, repair marker, or obsolete
  residue. Runtime legacy values are not an acceptable final state.
- Historical `_legacy` migration tables are acceptable only inside one-time
  migrations. They should not appear in runtime code or current docs as product
  concepts.

Server/use cases/HTTP:

- `cards_db.gleam` concentrates activation, close, rollup, movement, deletion,
  and raw SQL lifecycle strings. Split by use-case after characterization.
- `projects_db.gleam` is part of the hierarchy model and deserves first-class
  treatment with project settings/wizard/depth/permissions.
- `workflows/handlers.gleam` should split trigger matching, action execution,
  outcome construction, and audit/history recording.
- HTTP modules should normalize validation/conflict responses through typed
  domain outcomes, not duplicate string condition handling.

Client API/routing/state:

- API modules should expose domain-shaped results and keep JSON/string decoding
  at the edge.
- `url_state.gleam`, `router.gleam`, and `features/hydration/update.gleam` need a canonical route/hydration contract:
  page, section, selected project, Plan scope, show surface, automation deep
  links, sidebar state, auth resources, and any external-boundary redirects.
- `client_update.gleam` may remain the root TEA function, but bootstrap,
  route-sync, URL replace, show-stack normalization, and project switching need
  focused helpers and tests.
- `features/assignments/update.gleam` owns active admin assignment policy and
  must be audited with permissions, project settings, and auth-root policy.
- `features/pool/update.gleam` fallback no-op arms are transitional debt. Delete
  each group only after owner route tests prove coverage.

Product UI/styles/i18n:

- Existing UI components are a real asset. Do not create another design system.
- Feature-sized product surfaces belong under `features/`, not generic
  `components/`.
- `styles/ux.gleam`, `styles/layout.gleam`, and UI compatibility helpers need a
  real style audit, not only "use existing components".
- I18n keys and copy are product contracts. Closed/done/completed, workflow vs
  automation, task template terms, role/permission labels, and error messages
  must be normalized together.

Seeds/tests/docs:

- Seeds are QA infrastructure. They must map to explicit browser validations.
- Oversized tests should be split only after coverage is preserved. Do not
  remove duplication that provides useful behavioral matrix coverage.
- Docs should separate historical plans from current architecture.

## 6. UI, styles, and design system

Keep as shared UI:

- `ui/button.gleam`, `ui/action_menu.gleam`, `ui/data_table.gleam`
- `ui/filter_bar.gleam`, `features/layout/work_surface.gleam`
- `ui/dialog.gleam`, `ui/confirm_dialog.gleam`, `ui/empty_state.gleam`
- `ui/notes_list.gleam`, `ui/activity_feed.gleam`, `ui/show_tabs.gleam`
- `ui/card_state_badge.gleam`, `ui/task_state.gleam`, `ui/task_status_utils.gleam`

Move or split as feature code:

| Current module | Target | Reason | Valor | Complejidad | Riesgo |
| --- | --- | --- | --- | --- | --- |
| `components/card_show.gleam` | `features/cards/show.gleam` plus tab/action modules | Stateful Card Show surface, not a generic component. | Alto | Media | Medio |
| Task Show panels | `features/tasks/show_*` | Keep state owner, split panels/actions/selectors. | Alto | Media | Medio |
| `components/card_crud_dialog.gleam` | Keep until card admin/member creation flows settle | It removes real duplication today. | Medio | Baja | Bajo |
| `components/task_type_crud_dialog.gleam` | Admin feature candidate | Move only during admin/settings cleanup. | Medio | Baja | Bajo |
| `components/crud_dialog_base.gleam` | Keep, then remove compat class helpers when unused | Useful base, but must not become a framework. | Medio | Media | Bajo |

Style/design-system audit:

| Target | Work | Valor | Complejidad | Riesgo |
| --- | --- | --- | --- | --- |
| `styles/ux.gleam` | Find duplicate/dead classes, interactive states, focus states, mobile rules, old modal/detail naming. | Alto | Media | Medio |
| `styles/layout.gleam` | Audit app shell, sidebar, responsive constraints, show overlays, work surfaces, z-index conventions. | Alto | Media | Medio |
| UI compat classes | Inventory consumers and delete when no tests/CSS depend on them. | Medio | Media | Bajo |
| Tokens/tone classes | Align status tones for draft/active/closed and available/claimed/ongoing/closed. | Alto | Baja | Medio |
| DESIGN consistency | Verify no new surface violates existing product register: dense operational UI, restrained controls, no nested cards. | Alto | Baja | Bajo |

UI cleanup principles:

- Do not build a second UI framework.
- Do not create a generic workflow designer or universal board.
- Keep operational surfaces dense, scannable, and consistent.
- Prefer product-specific selectors/view models before splitting DOM.
- Validate desktop and mobile screenshots for layout overlap, focus visibility,
  and button text fit.

## 7. Hotspots module by module

| Module | Diagnosis | Proposal | Valor | Complejidad | Riesgo |
| --- | --- | --- | --- | --- | --- |
| `shared/src/domain/task/state.gleam` | Canonical model exists but is not fully adopted. | Make it the source of truth for task execution. | Alto | Media | Alto |
| Former task-state compatibility module | Compatibility model with `Done/completed`. | Deleted after callers migrated. A final bridge is not acceptable. | Alto | Media | Alto |
| `shared/src/domain/task_status.gleam` | Useful flattened UI/filter model but still used outside presentation today. | Keep only for filters/presentation; remove from repositories, seeds, metrics truth, workflows, and rules engine. | Alto | Media | Alto |
| `shared/src/domain/task.gleam` | Task entity exposes compatibility helpers. | Move helpers to canonical lifecycle or presentation selectors. | Alto | Media | Alto |
| `shared/src/domain/card/state.gleam` | Good canonical card state. | Use through card close/activate/move contracts. | Alto | Baja | Medio |
| `shared/src/api/cards/contracts.gleam` | Card close reason is raw string. | P1: typed `CardClosedReason` decoding and tests. | Alto | Baja | Alto |
| `shared/src/api/tasks/contracts.gleam` | Typed close contract already points to canonical model. | Add compatibility and closed-reason tests. | Alto | Baja | Medio |
| `apps/server/src/scrumbringer_server/repository/tasks/mappers.gleam` | Task DB to domain choke point. | Convert rows into canonical execution state. | Alto | Media | Alto |
| `apps/server/src/scrumbringer_server/use_case/cards_db.gleam` | Card lifecycle SQL/use-case concentration. | Split activation, closure, rollup, movement, deletion. | Alto | Alta | Medio |
| `apps/server/src/scrumbringer_server/use_case/projects_db.gleam` | Project hierarchy/settings persistence is large. | Split settings, membership/permissions, hierarchy config, project lifecycle. | Alto | Alta | Medio |
| `apps/server/src/scrumbringer_server/use_case/workflows/handlers.gleam` | Automation orchestration hotspot. | Split trigger matching, action execution, outcome, audit/history. | Alto | Alta | Medio |
| `apps/server/src/scrumbringer_server/use_case/rules_engine.gleam` | Strategic automation core. | Keep pure, add outcome ADT and behavior matrix tests. | Alto | Media | Medio |
| `apps/server/src/scrumbringer_server/http/cards.gleam` | Broad action/error mapping. | Use typed lifecycle outcomes and card contract reasons. | Alto | Media | Medio |
| `apps/server/src/scrumbringer_server/http/tasks/*` | Good split, but lifecycle terms diverge. | Normalize closed/completed only at external response boundaries; eliminate internal compatibility. | Alto | Media | Alto |
| Due-date modules/contracts | Due dates cross card contracts, Pool urgency, card overdue UI, activity, seeds, and tests. | Add Date/timezone semantics, codecs, DB mapping, visual urgency policy, and `DueDateChanged` validation. | Alto | Media | Alto |
| `apps/server/src/scrumbringer_server/http/projects.gleam` | Project settings/hierarchy endpoint boundary. | Align with project settings product model. | Alto | Media | Medio |
| `apps/server/src/scrumbringer_server/http/task_templates.gleam` | Automation vocabulary overlaps admin/task templates. | Decide naming and scope with automations refactor. | Medio | Media | Medio |
| `apps/server/src/scrumbringer_server/http/api_tokens.gleam` | Security-sensitive admin API. | Audit permissions, error responses, copy, and tests. | Alto | Media | Alto |
| `apps/server/src/scrumbringer_server/seed_builder.gleam` | Massive scenario builder. | Split by validation scenario and browser flow. | Alto | Media | Medio |
| `apps/server/src/scrumbringer_server/seed_db.gleam` | Large persistence orchestration. | Mirror scenario modules and preserve deterministic IDs. | Alto | Media | Medio |
| `apps/client/src/scrumbringer_client/client_update.gleam` | Root update plus route/show/bootstrap orchestration. | Keep root; extract route sync, show stack, bootstrap, project switch helpers. | Alto | Alta | Medio |
| `apps/client/src/scrumbringer_client/url_state.gleam` | Large URL state contract. | Define canonical round-trip model for scopes, shows, sidebar, automations. | Alto | Alta | Alto |
| `apps/client/src/scrumbringer_client/router.gleam` | Legacy redirects and route parsing. | Preserve behavior with tests during migration; final state removes legacy redirects or isolates externally justified adapters. | Alto | Media | Alto |
| `apps/client/src/scrumbringer_client/features/hydration/update.gleam` | Hydration coordinates auth, resources, routes, and redirects. | Make route/resource hydration explicit and test redirect/resource decisions. | Alto | Media | Alto |
| `apps/client/src/scrumbringer_client/features/pool/update.gleam` | Transitional fallback knows many features. | Remove by owner route tests, one group at a time. | Alto | Alta | Medio |
| `apps/client/src/scrumbringer_client/features/pool/urgency.gleam` | Pool due-date urgency policy is small but cross-cutting. | Tie urgency to canonical due-date semantics and timezone policy. | Alto | Baja | Medio |
| `apps/client/src/scrumbringer_client/ui/card_with_tasks_surface.gleam` | Card overdue visualization consumes due-date semantics. | Validate overdue labels/tone against canonical due-date policy. | Medio | Baja | Medio |
| `apps/client/src/scrumbringer_client/components/card_show.gleam` | Feature-sized surface under components. | Move/split into Card Show feature. | Alto | Media | Medio |
| `apps/client/src/scrumbringer_client/features/plan/structure_view.gleam` | View plus selectors/policy/move logic. | Extract selectors, action availability, move view model. | Alto | Media | Medio |
| `apps/client/src/scrumbringer_client/features/projects/update.gleam` | Large project/settings orchestration. | Split project wizard/settings/depth/permissions flows. | Alto | Alta | Medio |
| `apps/client/src/scrumbringer_client/features/projects/view.gleam` | Large settings/project UI surface. | Extract sections and reuse existing operational UI. | Alto | Media | Medio |
| `apps/client/src/scrumbringer_client/features/assignments/update.gleam` | Active admin assignment update flow with auth/root policy. | Include in permissions/settings cleanup and test permission-negative paths. | Alto | Media | Alto |
| `apps/client/src/scrumbringer_client/features/automations/rule_list.gleam` | Builder/list/template selection combined. | P1 split builder, list, filters, template picker, rule sentence. | Alto | Media | Medio |
| `apps/client/src/scrumbringer_client/features/automations/execution_history.gleam` | Strategic validation/debug surface. | Keep separate; align naming and filters with automation outcome model. | Alto | Media | Medio |
| `apps/client/src/scrumbringer_client/features/admin/workflows.gleam` | Active debt despite old admin naming. | Decide temporary internal name or rename toward automations. | Alto | Media | Medio |
| `apps/client/src/scrumbringer_client/features/admin/task_templates.gleam` | Still active automation-related admin surface. | Treat as active debt; align with automation templates naming. | Medio | Media | Medio |
| `apps/client/src/scrumbringer_client/features/admin/rule_metrics.gleam` | Active metrics surface under admin naming. | Align permission/copy/route names with automations. | Medio | Media | Medio |
| `apps/client/src/scrumbringer_client/i18n/text.gleam` | Large key contract. | Add key coverage and terminology cleanup. | Alto | Media | Bajo |
| `apps/client/src/scrumbringer_client/i18n/en.gleam` / `es.gleam` | Large copy maps. | Normalize closed/done/completed and workflow/automation terms. | Alto | Media | Bajo |
| `apps/client/src/scrumbringer_client/styles/ux.gleam` / `layout.gleam` | Large style surfaces. | Audit dead/compat classes, responsive/focus states, tokens. | Alto | Media | Medio |

## 8. Obsolete and active legacy debt

Already removed in the diff and should stay removed:

- The deleted timeline-goal feature modules, API client, server HTTP/service
  modules, shared domain modules, and tests.
- `components/card_detail_modal.gleam`.
- Old task detail footer/header/summary/tabs modules.

Active legacy or compatibility debt:

| Candidate | Action | Valor | Complejidad | Riesgo |
| --- | --- | --- | --- | --- |
| Admin workflow/template/rule metrics naming | Treat as active debt, not removed code. Decide whether names remain temporary internals or move to automations. | Alto | Media | Medio |
| `permissions.TaskTemplates`, `permissions.RuleMetrics` | Audit permission vocabulary with automations and admin navigation. | Alto | Media | Alto |
| `router.gleam` legacy config slug redirect | Keep only during migration with tests. Final state deletes it or isolates it as an external URL adapter with owner and justification. | Alto | Media | Alto |
| UI compat class helpers | Inventory consumers and delete after CSS/tests migrate. Final state should not keep compat helpers for internal layouts. | Medio | Media | Bajo |
| `api/payload_fields.gleam` legacy PATCH active flag | Replace when workflow/rule endpoints accept canonical payloads; if external compatibility remains, isolate it in API boundary code only. | Medio | Media | Medio |
| SQL projections from `closed` to `completed` | Keep only as explicit external API compatibility during lifecycle migration; final internal code must use canonical closed semantics. | Alto | Media | Alto |
| DB `invalid_migrated_rule` trigger kind | Verify data need before schema cleanup; remove unless it is a documented external/persisted repair boundary. | Medio | Media | Alto |
| Docs referencing deleted modules as current | Remove or archive as historical. | Alto | Baja | Bajo |
| Copy keys containing old terms | Normalize in i18n slice. | Alto | Media | Bajo |
| Dead CSS classes from replaced surfaces | Remove in style audit with visual/browser validation. | Medio | Media | Medio |

## 9. Global simplification opportunities

| Opportunity | Proposal | Valor | Complejidad | Riesgo |
| --- | --- | --- | --- | --- |
| Lifecycle strings scattered across DB/API/UI | Only DB query files, repository mappers, and API contracts may parse external lifecycle strings. | Alto | Alta | Alto |
| Automation concepts split between workflows/rules/templates/metrics names | Define automation vocabulary and migrate routes/copy/permissions intentionally. | Alto | Alta | Medio |
| URL/show/scope state spread across router, url_state, client_update, Pool | Define one route state contract with encode/decode round-trip tests. | Alto | Alta | Alto |
| Project settings treated as CRUD | Reframe as hierarchy configuration and permissioned project lifecycle. | Alto | Alta | Medio |
| Repeated task status labels in Plan/People/Capability/Card Show | Use shared presentation helpers backed by canonical lifecycle projections. | Medio | Baja | Bajo |
| Seed builder size | Split by validation scenario with browser test mapping. | Alto | Media | Medio |
| Style compatibility | Remove compat classes only with consumer inventory and screenshots. | Medio | Media | Bajo |
| Test fixture duplication | Extract fixtures when it reduces large test maintenance without hiding behavior. | Medio | Media | Medio |
| Docs historical noise | Mark historical plans clearly and keep architecture docs current. | Medio | Baja | Bajo |

## 10. Type and contract improvements

| Type improvement | Target | Valor | Complejidad | Riesgo |
| --- | --- | --- | --- | --- |
| Canonical task execution state | `domain/task/state.gleam`, repository mappers, HTTP presenters, client selectors | Alto | Alta | Alto |
| Presentation task status projection | `domain/task_status.gleam`, UI/filter helpers | Medio | Baja | Medio |
| Retire compatibility task state | Legacy task-state callers | Alto | Media | Alto |
| Typed card close request reason | `shared/src/api/cards/contracts.gleam` using `domain/card/state.CardClosedReason` | Alto | Baja | Alto |
| Due-date value object and codecs | Shared contracts, DB mappers, activity events, client selectors, visual urgency | Alto | Media | Alto |
| Typed automation outcome | `rules_engine.gleam`, `workflows/handlers.gleam`, HTTP presenters, execution history | Alto | Media | Medio |
| Route state ADT | `url_state.gleam`, `router.gleam`, client route sync | Alto | Alta | Alto |
| Hydration/resource state contract | `features/hydration/update.gleam`, auth resources, redirects, selected project startup | Alto | Media | Alto |
| Project hierarchy settings type | Project settings/wizard/depth/permissions server and client | Alto | Media | Medio |
| Assignment permission outcome | `features/assignments/update.gleam`, permissions, server assignment APIs | Alto | Media | Alto |
| Permission vocabulary | `permissions.gleam`, admin/automation routes, API tokens | Alto | Media | Alto |
| Newtype IDs at new boundaries | Card/task/user/project APIs where ID modules already exist | Medio | Media | Medio |

Do not type every string for style reasons. Promote strings when they encode a
business invariant, cross more than one boundary, or are duplicated in tests,
SQL, API, and UI.

## 11. Lustre, routing, i18n, and styles

Lustre/state:

| Improvement | Target | Valor | Complejidad | Riesgo |
| --- | --- | --- | --- | --- |
| Keep root TEA but reduce orchestration helpers | `client_update.gleam` | Alto | Alta | Medio |
| Feature-owned show surfaces | Card Show and Task Show | Alto | Media | Medio |
| Pure selectors before view split | Plan, Capability, People, Kanban, Projects | Alto | Media | Bajo |
| Remove Pool fallback arms by owner tests | `features/pool/update.gleam` | Alto | Alta | Medio |
| Automations route/update naming cleanup | Automations/admin workflow modules | Alto | Media | Medio |

Feature update policy pattern:

- Keep feature-owned updates returning local model, parent effect, and explicit
  policies rather than hiding behavior in generic frameworks.
- Normalize naming and semantics for `AuthPolicy`, `RefreshPolicy`,
  `CorePolicy`, root policy, and focus policy across admin, Pool, tasks,
  projects, assignments, capabilities, invites, members, task types, and API
  tokens.
- `route_support` modules should remain thin adapters that apply auth timing,
  refresh, and core-selection policy around feature updates.
- Do not introduce one universal update result type unless it removes repeated
  policy plumbing in multiple feature families without obscuring flow.
- Every policy-bearing feature update must have tests for auth-negative,
  refresh/no-refresh, and effect ordering behavior.

Routing/URL:

| Improvement | Target | Valor | Complejidad | Riesgo |
| --- | --- | --- | --- | --- |
| Canonical route state | Page, section, selected project, Plan scope, show stack, sidebar, automations | Alto | Alta | Alto |
| Round-trip tests | `url_state` encode/decode, router parse/build | Alto | Media | Alto |
| No redundant history writes | `router.replace`, `router.push`, `client_update.replace_url`, hydration route sync | Alto | Baja | Alto |
| Legacy redirects | Config slug and old admin routes | Medio | Media | Medio |
| Deep links | Card Show, Task Show, automation metrics/history, Plan scopes | Alto | Media | Alto |

Blocking routing rule: no code path may call `history.replaceState` or
`history.pushState` when the normalized target URL already equals the current
browser URL. Preserve and test the `router.write_browser_url` guard so route
normalization, hydration, and show-stack sync do not reintroduce excessive
history/location writes.

I18n/copy:

| Improvement | Target | Valor | Complejidad | Riesgo |
| --- | --- | --- | --- | --- |
| Key coverage tests | `i18n/text.gleam`, `en.gleam`, `es.gleam` | Alto | Baja | Bajo |
| Terminology cleanup | closed/done/completed, workflow/automation, task template, pool/plan/show | Alto | Media | Bajo |
| Error/capability/admin copy consistency | HTTP/client error surfaces and admin pages | Medio | Media | Bajo |
| Remove obsolete keys | Deleted timeline-goal/detail/admin surfaces | Medio | Baja | Bajo |

Styles:

| Improvement | Target | Valor | Complejidad | Riesgo |
| --- | --- | --- | --- | --- |
| Dead class scan | `styles/ux.gleam`, `styles/layout.gleam`, UI/component classes | Alto | Media | Medio |
| Compat class removal | UI helpers and styles | Medio | Media | Bajo |
| Focus/mobile/interactive states | Buttons, menus, dialogs, show overlays, work surfaces | Alto | Media | Medio |
| Token/tone consistency | Card/task states, alerts, badges, filters | Alto | Baja | Bajo |

## 12. Execution plan by slices

1. Baseline, legacy removal register, and stale docs
   - Recompute current branch, `HEAD`, upstream status, diff stat, changed-file
     inventory, deleted/renamed files, largest modules, and current green
     checks before touching code.
   - Inventory active legacy names, stale docs, dead module references,
     transitional DB values, redirects, SQL projections, and CSS compat classes.
   - Mark every legacy item as delete, migrate, or strictly external-boundary
     adapter. No internal compatibility may be accepted as final state.
   - Valor: Alto. Complejidad: Baja. Riesgo: Bajo.

2. Canonical lifecycle contracts
   - Adopt `domain/task/state.gleam` as canonical task execution state.
   - Keep `task_status.gleam` as presentation/filter projection.
   - Remove `task_state.gleam` after callers migrate; do not keep it as final
     bridge.
   - Type card close reason in shared card contracts.
   - Valor: Alto. Complejidad: Alta. Riesgo: Alto.

3. Due-date semantics
   - Define Date/project-timezone semantics for cards/tasks and UI urgency.
   - Normalize codecs, DB mapping, `DueDateChanged` activity, seeds, and visual
     overdue/urgency validation.
   - Valor: Alto. Complejidad: Media. Riesgo: Alto.

4. Persistence, migrations, and repository boundaries
   - Centralize lifecycle string decoding in repository mappers.
   - Classify migration-only residue vs external-boundary compatibility.
   - Remove runtime legacy values unless they are strictly justified persisted
     boundary data.
   - Do not hand-edit generated `sql.gleam`.
   - Valor: Alto. Complejidad: Alta. Riesgo: Alto.

5. HTTP/API contract normalization
   - Normalize card/task lifecycle responses, conflict responses, and validation
     errors.
   - Include API tokens/auth/security-sensitive endpoints in audit scope.
   - Valor: Alto. Complejidad: Media. Riesgo: Alto.

6. Automations/workflows/rules/templates/metrics
    - Promote to P1.
    - Split rule builder, rule list, template picker, execution history, metrics.
    - Add outcome ADT and clean workflow/rule/task template naming.
    - Replace compatibility payloads after endpoint tests; any remaining support
      must be isolated at API boundary code only.
    - Valor: Alto. Complejidad: Alta. Riesgo: Medio.

7. Routing, URL state, and hydration
   - Define canonical route/hydration state for page, section, selected project,
     Plan scope, show stack, sidebar, automations, auth resources, and deep
     links.
   - Add round-trip tests and redirect/resource-decision tests.
   - Make redundant history writes a blocking failure: no `history.replaceState`
     or `history.pushState` when the normalized URL already matches the current
     browser URL.
   - Delete legacy redirects or isolate strictly external URL adapters.
   - Valor: Alto. Complejidad: Alta. Riesgo: Alto.

8. Feature update policies
   - Normalize `AuthPolicy`, `RefreshPolicy`, `CorePolicy`, root policy, focus
     policy, and route-support behavior across feature-owned updates.
   - Keep policy plumbing explicit; do not add a generic framework unless it
     removes real duplication without hiding effects.
   - Valor: Alto. Complejidad: Media. Riesgo: Medio.

9. Project settings, hierarchy, assignments, permissions, and wizard
   - Treat projects as hierarchy configuration and permissioned product setup,
     not CRUD.
   - Split project view/update/server persistence by settings area.
   - Include `features/assignments/update.gleam` and root auth policy tests.
   - Valor: Alto. Complejidad: Alta. Riesgo: Medio.

10. Client state/update and Pool ownership
   - Extract bootstrap, project switching, show-stack, route sync helpers.
   - Remove Pool fallback arms by owner route tests.
   - Valor: Alto. Complejidad: Alta. Riesgo: Medio.

11. Card Show and Task Show
    - Move Card Show to feature namespace.
    - Split Card/Task panels for summary, work/tasks, notes, activity,
      dependencies, and actions.
    - Valor: Alto. Complejidad: Media. Riesgo: Medio.

12. Plan/tree, Kanban, Capabilities, and People
    - Extract selectors, rollups, action availability, task labels, ownership,
      due-date visibility, and move view model.
    - Keep layouts product-specific.
    - Valor: Alto. Complejidad: Media. Riesgo: Medio.

13. I18n/copy
    - Normalize closed/done/completed and workflow/automation terminology.
    - Normalize due-date, overdue, assignment, permission, and hydration/redirect
      copy.
    - Add key coverage tests and remove obsolete keys.
    - Valor: Alto. Complejidad: Media. Riesgo: Bajo.

14. Styles/design-system
    - Audit `styles/ux.gleam`, `styles/layout.gleam`, UI classes, focus states,
      mobile constraints, tokens, and dead/compat classes.
    - Validate with browser screenshots.
    - Valor: Alto. Complejidad: Media. Riesgo: Medio.

15. Seeds and product validation matrix
    - Split seeds by scenario.
    - Map every scenario to a browser validation case.
    - Include due dates, assignments, hydration/deep-link startup, automations,
      permissions, and API token scenarios.
    - Valor: Alto. Complejidad: Media. Riesgo: Medio.

16. Test suite maintainability
    - Partition huge tests and shared fixtures where they reduce maintenance.
    - Preserve behavior coverage before deleting redundant cases.
    - Valor: Medio. Complejidad: Media. Riesgo: Medio.

17. Final docs and anti-overengineering sweep
    - Update architecture docs and mark historical plans.
    - Remove obsolete wrappers, unused public APIs, dead styles, stale seeds, and
      compatibility code with proven removal criteria.
    - Valor: Alto. Complejidad: Media. Riesgo: Medio.

## 13. Tests per slice

| Slice | Minimum tests |
| --- | --- |
| Baseline/docs | Recompute `HEAD`, diff stat, layer inventory, largest modules, current test baseline, `git diff --check`, and grep for deleted modules in current architecture docs. |
| Lifecycle contracts | Shared tests for task/card state codecs, card close reason decode, task close response, compatibility projections. |
| Due dates | Shared/API codec tests, DB mapper tests, project timezone/overdue selector tests, `DueDateChanged` activity tests, Pool/Card visual urgency tests. |
| Persistence/repository | Server tests for claim/release/close/close-by-ancestor, card activate/close/rollup/move, dependency blocking. |
| HTTP/API | Server HTTP tests for lifecycle conflicts, validation, auth/API token permissions, project settings errors. |
| Routing/URL/hydration | Encode/decode round-trip tests, redirect-resource decision tests, no-redundant-history-write tests, deep link tests for Card Show, Task Show, Plan scopes, automations, and startup hydration. |
| Feature update policies | Tests for auth policy timing, refresh/no-refresh, core-selection policy, root/focus policy, route-support adapters, and effect ordering. |
| Project settings/assignments | Client update/view tests, server project settings tests, assignments update tests, permissions matrix tests, wizard/depth behavior. |
| Client update/Pool | Route owner tests, show-stack tests, project switching tests, Pool fallback removal tests. |
| Card/Task Show | Component/update tests for tabs, notes, activity, dependencies, create/edit/close/activate/claim/release. |
| Plan/Kanban/Capabilities/People | Selector tests for visibility, rollups, status labels, ownership, move validity, action availability. |
| Automations | Rule engine matrix tests, outcome ADT tests, handler tests, HTTP workflow/rule/template tests, client builder/list/history tests. |
| I18n/copy | Key coverage tests for `text`, `en`, `es`; terminology grep for legacy terms. |
| Styles/design | Dead class scan, browser screenshots, focus/mobile checks, reduced-motion/focus-visible checks where relevant. |
| Seeds/browser matrix | Server seed tests plus seed scenario to agent-browser validation coverage. Every reproducible browser defect must become an automated selector/update/API test when it can be expressed below browser level. |
| Test maintainability | Fixture extraction tests, split large tests without reducing behavior matrix. |
| Final | Shared/client/server format and tests, static checks, DB schema checks, browser validations. |

Use `let assert` in Gleam tests. Keep snapshot tests only where they protect
meaningful UI structure. Prefer behavior tests for lifecycle, routing, security,
permissions, and automation outcomes.

Large-test work inventory:

| Test file | Approx. lines | Split around |
| --- | ---: | --- |
| `apps/server/test/tasks_http_test.gleam` | 3695 | list/create, patch/delete, transitions, dependencies, lifecycle compatibility, permission failures. |
| `apps/server/test/notes_and_positions_http_test.gleam` | 1980 | notes, pin/delete flows, positions, hover/Pool concerns. |
| `apps/server/test/rules_engine_test.gleam` | 1703 | trigger matching, action execution, suppression/outcome matrix. |
| `apps/server/test/projects_http_test.gleam` | 1533 | project CRUD, settings, hierarchy depth, permissions, wizard/setup behavior. |
| `apps/server/test/fixtures.gleam` | 1523 | scenario fixtures, auth users, hierarchy data, automation data. |
| `apps/server/test/rule_metrics_http_test.gleam` | 1224 | org/project metrics, drilldowns, date ranges, permission-negative paths. |
| `apps/server/test/rules_http_test.gleam` | 1133 | rule CRUD, payload compatibility, automation contracts. |
| `apps/server/test/integration/rules_trigger_on_close_test.gleam` | 1087 | lifecycle-trigger integration matrix. |
| `apps/client/test/people_view_test.gleam` | 1030 | roster, ownership, task status labels, capability filters. |
| `apps/server/test/cards_http_test.gleam` | 1020 | card lifecycle, move, close, due dates, operational history. |
| `apps/server/test/task_templates_http_test.gleam` | 1004 | template CRUD, automation usage, archive/delete behavior. |
| `apps/server/test/api_tokens_http_test.gleam` | 944 | token create/revoke, permissions, security responses. |

Split large tests only when it makes behavior ownership clearer. Do not split by
line count alone, and do not hide important matrices behind opaque helpers.

## 14. Acceptance criteria

The final refactor is complete only when:

- The execution baseline was recomputed at the start of the goal and any drift
  from this planning audit was reflected before code changes.
- Prior product decision docs were reused and not contradicted without an
  explicit replacement decision.
- `domain/task/state.gleam` is the canonical task execution model in new domain,
  repository, HTTP, client API, and selector code.
- `task_status.gleam` is explicitly presentation/filter-only and is absent from
  final persistence, repository truth, seeds truth, workflows, metrics truth, and
  rules-engine state.
- `task_state.gleam` is removed. It may exist only during intermediate commits,
  never as the final state.
- Card close requests use typed `CardClosedReason`.
- Due dates have canonical Date/project-timezone semantics across contracts, DB,
  activity, seeds, Pool urgency, and card overdue UI.
- Internal DB/API compatibility strings are removed. Any remaining compatibility
  is strictly external-boundary adapter code with owner, tests, and product
  justification.
- Automations/workflows/rules/templates/metrics have a clear vocabulary,
  outcome ADT, split builder/list/history surfaces, and no hidden legacy payload
  assumptions.
- Project settings, hierarchy depth, wizard/setup, permissions, API tokens, and
  project switching are covered as one product area.
- URL state and hydration have round-trip/resource-decision tests. Legacy
  redirects are deleted or isolated as strictly external URL adapters.
- Route sync preserves the no-op history-write rule: no `history.replaceState`
  or `history.pushState` call when the normalized target URL equals the current
  browser URL.
- Card Show, Task Show, Plan, Pool, Kanban, People, Capability Board, Projects,
  and Automations have feature-owned selectors/view models where needed.
- I18n keys are covered and terminology is consistent in English and Spanish.
- Styles have no known dead classes, accidental compat classes, missing focus
  states, or mobile layout regressions.
- Seed scenarios are named, deterministic, and mapped to browser validations.
- Oversized tests are partitioned where that improves maintainability.
- Shared, client, and server checks pass.
- Browser validations pass for the product-critical flows.

## 15. Seed and agent-browser validation matrix

Every seed scenario must support at least one browser validation. Each
validation must name the user, URL, seed data, key testids, action, expected
visual result, and the automated test to add if a reproducible defect appears.

| Scenario | User | Initial URL | Seed expectation | Key testid | Action | Expected result | Bug becomes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Hierarchy with draft/active/closed cards | Project manager | `/member?view=plan` | Tree contains draft, active, and closed cards | `plan-structure-view` | Scope by depth/card, move card, activate subtree, close card, toggle closed | Tree, rollups, disabled reasons, and show-closed state update without layout overlap | Plan selector/update test or card HTTP lifecycle test |
| Claimable task leaves | Member | `/member?view=pool` | Available, claimed, ongoing, and closed task leaves | Pool task/card testids | Claim, release, close, drag-to-claim, start/pause work | Pool and now-working state refresh correctly and no invalid action remains enabled | Task mutation update test or server task transition test |
| Due dates and overdue work | Member and project manager | `/member?view=pool` and `/member?view=plan` | Cards/tasks include future, today, overdue, and no due date | Due-date/urgency labels | Create/change/remove due date and refresh | Timezone-aware urgency, overdue tone, sorting, and `DueDateChanged` activity are correct | Due-date selector, API contract, activity, or card/task HTTP test |
| Dependencies/blockers | Member | Task Show deep link | Task has open and closed dependencies | dependency list/dialog testids | Add/remove dependency and close dependency | Blocked badge and available actions update correctly | Dependency update/API test |
| Notes/activity | Member | Card Show and Task Show deep links | Notes and activity exist for card and task targets | notes/activity testids | Add/delete/pin note and paginate activity | Target-specific notes/activity update and survive refresh | Notes update/API or activity HTTP test |
| Automations/rules/templates | Project manager | Automation/rule route | Workflow, rules, templates, execution history, metrics | rule builder/list/history testids | Create/edit rule, choose template, trigger rule, inspect history/metrics | Outcome, execution history, metrics, and copy use canonical automation vocabulary | Rule engine, handler, HTTP, or client builder test |
| Project settings/hierarchy config | Project manager | Project settings route | Project has hierarchy depth labels, members, and settings | project settings testids | Change settings, max depth labels, permissions, project switch | Settings persist, hierarchy labels update, permissions respected | Project update/API or permissions test |
| People/capabilities | Project manager | People and Capability Board routes | Members have varied capabilities and task ownership | people/capability board testids | Assign capabilities, filter members, inspect ownership/status | Roster and board reflect canonical task status projections | People/capability selector or view test |
| Auth/invites/API tokens | Org admin and non-admin | Admin/security routes | Invites and tokens exist; restricted user exists | token/invite/security testids | Login/logout, accept invite, create/revoke token, attempt forbidden action | Auth flow succeeds and forbidden states are explicit | Auth/API token/invite HTTP or update test |
| Assignments and permissions | Project manager and restricted user | Assignments route | Assignable users and capability/member permissions exist | assignments testids | Assign/remove users, change role, switch project | Permission-positive and permission-negative paths are correct | Assignments update/API or permission matrix test |
| Hydration/deep-link startup | Authenticated member/admin | Cold deep links for show, Plan, automations, settings | Selected project and resources exist | route/show/shell testids | Open URL in fresh session and refresh | Resources hydrate once, selected project/sidebar/show state match URL, no redundant history write | URL/hydration/client update test |
| I18n/copy | Any authenticated user | Key product routes | English and Spanish locales available | locale switch/test surface ids | Switch locale and scan key surfaces | Closed/done/completed, automation/workflow, due-date, and permission terms are consistent | I18n key coverage or copy assertion test |
| Responsive layout | Member/admin | Pool, Plan, Shows, Automations, Settings | Same scenarios as above | route root testids | Capture desktop and mobile screenshots | No overlap, clipped dropdowns, invisible focus, or button text overflow | View/layout test, selector test, or style cleanup item |

Run after each UI-affecting slice:

- Desktop and mobile screenshots.
- DOM checks for non-overlap, visible focus, button text fit, and expected
  testids.
- State transition validation after server refresh.
- Permission-negative paths, not only happy paths.
- Every reproducible defect found with agent-browser must become an automated
  selector, update, shared contract, or API test when it can be reproduced below
  the browser layer.

## 16. Rejected overengineering improvements

Do not do these as part of the final refactor:

- Do not manually refactor generated `sql.gleam`.
- Do not create generic `service`, `manager`, or `facade` layers without proven
  duplication across at least two product areas.
- Do not invent a second design system or a generic surface framework.
- Do not force Plan, Kanban, Capability Board, and People into one generic board.
- Do not move feature-specific Card Show/Task Show panels into `ui/`.
- Do not rename every admin/workflow module in one unsafe sweep. Rename only
  when routes, permissions, copy, and tests move together.
- Do not remove all modals as a blanket rule.
- Do not convert every string to an ADT. Focus on business invariants and
  repeated boundary strings.
- Do not rewrite the router as a new framework before defining route-state tests.
- Do not collapse automation UI into a generic workflow designer.
- Do not split tests by line count alone. Split around behavior ownership.
- Do not keep temporary compatibility as a final result. Either remove it or
  isolate it as explicitly justified external-boundary adapter code.

## 17. Future commit order

Recommended commit sequence:

1. Recompute execution baseline, diff scope, large-module inventory, and tests.
2. Reconcile prior product decision docs with the current goal.
3. Compatibility register, runtime legacy removal plan, and stale docs cleanup.
4. Shared lifecycle tests and canonical task/card contract decisions.
5. Typed card close reason and task lifecycle compatibility tests.
6. `task_state` consumer migration and `task_status` usage restrictions.
7. Due-date Date/timezone contract, activity, DB, seed, and UI urgency tests.
8. SQL/repository lifecycle and due-date boundary cleanup.
9. Migration/schema compatibility classification and runtime legacy removal.
10. HTTP payload, presenter, conflict, auth, and API token normalization.
11. Automations/rules/templates/metrics outcome model and server/client split.
12. URL state, hydration contract, no-redundant-history-write tests, deep links, and redirect policy.
13. Feature update policy normalization for auth, refresh, core, root, focus, and route-support.
14. Project settings, hierarchy depth, wizard, assignments, permissions, and project switching.
15. Client API decoding and shared selectors.
16. Root `client_update.gleam` route/show-stack/bootstrap extraction.
17. Pool ownership cleanup and fallback reduction.
18. Card Show and Task Show feature module split.
19. Plan/tree selector, rollup, due-date visibility, and move-policy extraction.
20. Kanban, Capability Board, and People selector reuse.
21. I18n/copy terminology and key coverage.
22. Styles/design-system audit and compat/dead class removal.
23. Seed scenario split and browser validation matrix.
24. Test fixture cleanup and partition of oversized tests.
25. Architecture docs update and final anti-legacy, anti-duplication,
    anti-overengineering sweep.
