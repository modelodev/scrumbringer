# Refactor Plan (Ready)

## 0) Assumptions and Goals
- runtime: beam
- refactor stance: "API break allowed; functionality preserved"
- definition of done (DoD): inventory regenerated with fewer overlaps/duplication, tests green (`gleam check`, `gleam test`), HTTP smoke checks pass for touched endpoints

## 1) Summary of Key Findings (from inventory)
- Hotspots: "High public API surface" across multiple modules (e.g. `scrumbringer_server/http/api`, `scrumbringer_server/http/auth`, `scrumbringer_server/http/rule_metrics`, `scrumbringer_server/http/metrics_service`, `scrumbringer_server/services/store`) from `cross_module_analysis.hotspots`
- Overlaps/duplications: authorization helpers split between `scrumbringer_server/http/auth` and `scrumbringer_server/http/authorization` from `cross_module_analysis.overlaps` (Authorization checks)
- ADT opportunities: `TaskFilters(status: String, ...)` in `scrumbringer_server/services/workflows/types` and `derive_work_state(status: String, is_ongoing: Bool)` in `scrumbringer_server/http/metrics_service` from `adt_opportunities`
- OTP concerns (if beam): actor-based `scrumbringer_server/services/store` exists without explicit supervision in `otp_topology` (supervisors empty; worker present)

## 2) Execution Strategy
- Branching & PR sizing rules: 1 PR per targeted overlap/ADT/micro-structure change; each PR touches 1–5 main modules; no orthogonal refactors mixed
- Test strategy (unit/integration/OTP): prioritize unit tests for new ADTs and mapping logic; run existing integration tests if any; for OTP actor changes, add actor-level tests or message protocol checks
- Migration strategy for API breaks: phased (A: add ADT + compat; B: migrate callers and remove legacy). For auth overlap, add compat wrappers in old modules for one PR before removal

## 3) Backlog (prioritized)

### Epic E1: Authorization Helpers Consolidation
- Motivation (inventory references): `cross_module_analysis.overlaps` “Authorization checks” between `scrumbringer_server/http/auth` and `scrumbringer_server/http/authorization`
- Success metrics: duplicated authorization helpers reduced to a single internal API; HTTP handlers use unified helper
- Risks: API break in internal helpers; requires careful regression of authorization flows

#### PR 1: Introduce unified authorization service (size: M, risk: medium)
- Objective: centralize authorization checks to remove overlap
- Scope:
  - modules: [scrumbringer_server/http/auth, scrumbringer_server/http/authorization, scrumbringer_server/services/authorization (new)]
- Inventory drivers:
  - overlap: Authorization checks (`cross_module_analysis.overlaps`)
- Change plan (steps):
  1) Create `scrumbringer_server/services/authorization` with the shared helper functions
  2) Update `scrumbringer_server/http/authorization` to call the service (keep public API)
  3) Update `scrumbringer_server/http/auth` to call the service (keep public API)
  4) Add unit tests for the service (requires inspection in code)
- API changes (REQUIRED even if none):
  - public API:
    - added: [scrumbringer_server/services/authorization::{require_project_manager, require_project_manager_simple, require_project_manager_with_org_bypass, is_project_member, is_project_manager}]
    - removed: []
    - renamed/moved: []
    - signature/type changes: []
  - internal API (module-level):
    - added/removed/renamed/moved: [new module `scrumbringer_server/services/authorization`]
- Data model / ADT changes (if any):
  - new types: []
  - removed types: []
  - migration notes: none
- OTP impact (if any):
  - supervisors/workers affected: none
  - message protocol changes: none
  - restart semantics implications: none
- Validation:
  - commands: ["gleam check", "gleam test"]
  - new/updated tests: authorization helper unit tests
  - manual checks (if gateway/HTTP/ports): login + protected route checks
- Rollback plan: revert module additions and restore direct calls in `http/auth` and `http/authorization`
- Reviewer checklist: auth decisions preserved; error responses unchanged; handlers still compile without warnings

#### PR 2: Remove duplicated authorization helpers (size: S, risk: low)
- Objective: eliminate redundant helpers in HTTP modules once service is used
- Scope:
  - modules: [scrumbringer_server/http/auth, scrumbringer_server/http/authorization]
- Inventory drivers:
  - overlap: Authorization checks (`cross_module_analysis.overlaps`)
- Change plan (steps):
  1) Remove redundant helper implementations in HTTP modules
  2) Update call sites to use service where needed
  3) Re-run unit tests
- API changes (REQUIRED even if none):
  - public API:
    - added: []
    - removed: [duplicated helper functions in `http/auth` and `http/authorization` if any are public]
    - renamed/moved: []
    - signature/type changes: []
  - internal API (module-level):
    - added/removed/renamed/moved: [remove internal helper implementations]
- Data model / ADT changes (if any):
  - new types: []
  - removed types: []
  - migration notes: none
- OTP impact (if any):
  - supervisors/workers affected: none
  - message protocol changes: none
  - restart semantics implications: none
- Validation:
  - commands: ["gleam check", "gleam test"]
  - new/updated tests: none
  - manual checks: auth-protected endpoints still behave
- Rollback plan: restore removed helpers
- Reviewer checklist: only one authorization source remains; no behavior change

### Epic E2: Task Status ADT (String -> ADT)
- Motivation (inventory references): `adt_opportunities` TaskFilters uses `status: String` in `scrumbringer_server/services/workflows/types`
- Success metrics: no stringly-typed task status in domain boundary; validated parsing at HTTP boundary
- Risks: broad API changes across task workflows and metrics; requires phased migration

#### PR 3: Phase A - Introduce TaskStatus ADT + compat parsing (size: M, risk: medium)
- Objective: add `TaskStatus` ADT without breaking callers
- Scope:
  - modules: [scrumbringer_server/services/workflows/types, scrumbringer_server/http/tasks/filters, scrumbringer_server/http/tasks/validators]
- Inventory drivers:
  - adt_opportunity: TaskFilters status string (`adt_opportunities` item 1)
- Change plan (steps):
  1) Add `TaskStatus` ADT in `services/workflows/types`
  2) Add parse/format helpers in `http/tasks/filters` or `http/tasks/validators`
  3) Add unit tests for parsing and formatting
  4) Keep `TaskFilters(status: String, ...)` until Phase B
- API changes (REQUIRED even if none):
  - public API:
    - added: [TaskStatus ADT + parse/format helpers]
    - removed: []
    - renamed/moved: []
    - signature/type changes: []
  - internal API (module-level):
    - added/removed/renamed/moved: []
- Data model / ADT changes (if any):
  - new types: [TaskStatus]
  - removed types: []
  - migration notes: Phase A introduces compat helpers, no call-site change yet
- OTP impact (if any):
  - supervisors/workers affected: none
  - message protocol changes: none
  - restart semantics implications: none
- Validation:
  - commands: ["gleam check", "gleam test"]
  - new/updated tests: TaskStatus parse/format unit tests
  - manual checks: task list filters by status
- Rollback plan: remove new ADT and helpers
- Reviewer checklist: status parsing matches existing string values; no endpoint behavior change

#### PR 4: Phase B - Migrate TaskFilters to TaskStatus (size: M, risk: medium)
- Objective: use `TaskStatus` end-to-end in workflow types and consumers
- Scope:
  - modules: [scrumbringer_server/services/workflows/types, scrumbringer_server/http/metrics_service, scrumbringer_server/sql, scrumbringer_server/http/tasks/filters]
- Inventory drivers:
  - adt_opportunity: TaskFilters status string (`adt_opportunities` item 1)
- Change plan (steps):
  1) Change `TaskFilters(status: String, ...)` -> `TaskFilters(status: TaskStatus, ...)`
  2) Update callers/decoders to construct `TaskStatus`
  3) Update SQL mapping to accept or encode `TaskStatus`
  4) Remove any legacy string-specific helpers
- API changes (REQUIRED even if none):
  - public API:
    - added: []
    - removed: []
    - renamed/moved: []
    - signature/type changes: [TaskFilters status field String -> TaskStatus]
  - internal API (module-level):
    - added/removed/renamed/moved: [helper encoders if needed]
- Data model / ADT changes (if any):
  - new types: []
  - removed types: [legacy string status in TaskFilters]
  - migration notes: Phase B removes legacy usage
- OTP impact (if any):
  - supervisors/workers affected: none
  - message protocol changes: none
  - restart semantics implications: none
- Validation:
  - commands: ["gleam check", "gleam test"]
  - new/updated tests: update workflow/task filter tests
  - manual checks: task filter endpoints by status
- Rollback plan: revert TaskFilters type change, keep compat helpers
- Reviewer checklist: no query regressions; metrics still display correct status

### Epic E3: WorkState ADT (derive_work_state)
- Motivation (inventory references): `adt_opportunities` in `scrumbringer_server/http/metrics_service` uses `status: String` + `is_ongoing: Bool` to derive `work_state: String`
- Success metrics: derived work state is typed and explicit; no fallthrough to arbitrary strings
- Risks: limited to metrics pipeline; low impact

#### PR 5: Phase A - Introduce WorkState ADT (size: S, risk: low)
- Objective: add `WorkState` ADT and constructor
- Scope:
  - modules: [scrumbringer_server/http/metrics_service]
- Inventory drivers:
  - adt_opportunity: WorkState in metrics (`adt_opportunities` item 2)
- Change plan (steps):
  1) Add `WorkState` ADT and `work_state_from(status, is_ongoing)`
  2) Add unit tests for WorkState derivation
  3) Keep `work_state: String` in `ProjectTask` temporarily
- API changes (REQUIRED even if none):
  - public API:
    - added: [WorkState ADT, work_state_from]
    - removed: []
    - renamed/moved: []
    - signature/type changes: []
  - internal API (module-level):
    - added/removed/renamed/moved: []
- Data model / ADT changes (if any):
  - new types: [WorkState]
  - removed types: []
  - migration notes: Phase A adds ADT, no consumer change
- OTP impact (if any):
  - supervisors/workers affected: none
  - message protocol changes: none
  - restart semantics implications: none
- Validation:
  - commands: ["gleam check", "gleam test"]
  - new/updated tests: WorkState derivation unit tests
  - manual checks: metrics endpoints still respond
- Rollback plan: remove WorkState ADT and constructor
- Reviewer checklist: WorkState maps existing status/is_ongoing logic exactly

#### PR 6: Phase B - Migrate metrics presenters to WorkState (size: S, risk: low)
- Objective: use WorkState instead of string
- Scope:
  - modules: [scrumbringer_server/http/metrics_service, scrumbringer_server/http/metrics_presenters]
- Inventory drivers:
  - adt_opportunity: WorkState in metrics (`adt_opportunities` item 2)
- Change plan (steps):
  1) Change `ProjectTask.work_state` to `WorkState`
  2) Update presenters to render WorkState to JSON
  3) Remove `derive_work_state` string fallback
- API changes (REQUIRED even if none):
  - public API:
    - added: []
    - removed: []
    - renamed/moved: []
    - signature/type changes: [ProjectTask.work_state String -> WorkState]
  - internal API (module-level):
    - added/removed/renamed/moved: [remove derive_work_state if unused]
- Data model / ADT changes (if any):
  - new types: []
  - removed types: [string work_state]
  - migration notes: Phase B finalizes ADT usage
- OTP impact (if any):
  - supervisors/workers affected: none
  - message protocol changes: none
  - restart semantics implications: none
- Validation:
  - commands: ["gleam check", "gleam test"]
  - new/updated tests: update presenter tests
  - manual checks: metrics JSON output compatibility
- Rollback plan: revert ProjectTask field to String; restore derive_work_state
- Reviewer checklist: JSON output remains stable for consumers

### Epic E4: OTP Store Actor Hygiene
- Motivation (inventory references): `otp_topology` shows worker `scrumbringer_server/services/store` with no supervisors listed; actor used for tests
- Success metrics: explicit supervision or clear scoping to tests; documented restart behavior
- Risks: change to runtime behavior if store used outside tests (requires inspection)

#### PR 7: Document store actor as test-only (size: S, risk: low)
- Objective: confirm usage and document store actor as test-only (no runtime supervision needed)
- Scope:
  - modules: [scrumbringer_server/services/store, apps/server/test/support/test_helpers.gleam]
- Inventory drivers:
  - otp_topology: store actor worker without supervisors
- Change plan (steps):
  1) Confirmed: no `store.start` usage in runtime modules (grep); only `store_state` used by handlers and persistence
  2) Add module doc note clarifying store actor is test-only and state is volatile
  3) Add note in `test_helpers.gleam` about store lifecycle expectations
- API changes (REQUIRED even if none):
  - public API:
    - added: []
    - removed: []
    - renamed/moved: []
    - signature/type changes: []
  - internal API (module-level):
    - added/removed/renamed/moved: [possible supervisor start function; requires inspection]
- Data model / ADT changes (if any):
  - new types: []
  - removed types: []
  - migration notes: none
- OTP impact (if any):
  - supervisors/workers affected: none (test-only actor)
  - message protocol changes: none
  - restart semantics implications: document state loss on restart
- Validation:
  - commands: ["gleam check", "gleam test"]
  - new/updated tests: add actor lifecycle test if applicable
  - manual checks: none
- Rollback plan: revert supervision changes
- Reviewer checklist: store usage confirmed; no behavior change in tests

## 4) Global API Change Log (for review)
- PR 1:
  - add `scrumbringer_server/services/authorization` public functions
- PR 2:
  - remove duplicated public helpers in `scrumbringer_server/http/auth` and `scrumbringer_server/http/authorization` (if public)
- PR 3:
  - add `TaskStatus` ADT + parsing/formatting helpers
- PR 4:
  - change `TaskFilters.status: String` -> `TaskStatus`
- PR 5:
  - add `WorkState` ADT + constructor
- PR 6:
  - change `ProjectTask.work_state: String` -> `WorkState`
- PR 7:
  - no public API changes expected (requires inspection)

## 5) Suggested Regeneration Loop
- after each PR: regenerate inventory + ensure overlaps/duplication decreases
- stop conditions: no remaining overlaps, ADT opportunities resolved or explicitly deferred, OTP topology clarified

## 6) Execution Status
- status: executed
- commits:
  - fase 1: 4fc01c2
  - fase 2 auth helpers: 5419929
  - fase 3 task status adt: 55750da
  - fase 4 task filters adt: 26754b7
  - fase 5 workstate adt: ea1796f
  - fase 6 workstate migration: d7e8743
  - fase 7 store docs: c151300

## 7) Validation Evidence (2026-01-25)

### Commit verification
- `git log --oneline -n 20` includes:
  - 4fc01c2 fase 1 refactor
  - 5419929 fase 2 auth helpers
  - 55750da fase 3 task status adt
  - 26754b7 fase 4 task filters adt
  - ea1796f fase 5 workstate adt
  - d7e8743 fase 6 workstate migration
  - c151300 fase 7 store docs

### Tests (apps/server)
- Command: `DATABASE_URL=... gleam check && DATABASE_URL=... gleam test`
- Result: `gleam check` ok; `gleam test` ok
  - 168 passed, no failures

### Authorization dedup follow-up
- Updated `apps/server/src/scrumbringer_server/http/capabilities.gleam` to remove local `require_project_manager` and use `services/authorization.require_project_manager_with_org_bypass`.
- Re-ran `gleam test` with DATABASE_URL; 168 passed, no failures.

### HTTP smoke checks
- Not executed (requires DATABASE_URL + running server)

### Inventory regeneration
- Not executed (no inventory script found in repo)
