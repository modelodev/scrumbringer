# Workflows post-implementation improvement plan

## Purpose

This document captures the improvement plan after the first implementation pass of
`docs/fin_refactor.md` for automations/workflows.

The goal is not to redesign the whole product again. The goal is to close the
gaps found in the implemented workflows block before the final codebase refactor:

- keep ScrumBringer's workflow model organic: rules create claimable work in the
  Pool, they do not assign work or force a process stepper;
- keep rules understandable as cause -> effect, not as a technical CRUD table;
- make illegal rule states unrepresentable where practical;
- reuse the same work-surface language used by Pool, Plan, Capabilities, People,
  Card Show and Task Show;
- remove legacy/obsolete code paths rather than preserving compatibility layers.

## Current diagnosis

The implementation has good foundations in the shared domain, but it is not ready
to be considered complete.

### What is working conceptually

- `shared/src/domain/automation.gleam` moves the model toward ADTs for triggers,
  actions, statuses and card scopes.
- Due date is not a workflow trigger, which matches the product decision: overdue
  work must be visible in operational views, not become another automation source.
- Rule executions are typed more clearly and created tasks can expose automation
  origin.
- The main automations console starts using the same `work_surface` language as
  the rest of the redesigned app.
- There is meaningful test coverage in shared codecs/domain and several client
  automation views.

### Executability gate

Before executing this plan or the final refactor, the branch must be buildable.
The review found several compile-time drifts around the new automation route and
console config. Some may already be fixed in the working tree, but they should
remain as an explicit gate:

1. `router.page_title_for_route` must handle `ConfigAutomation`.
2. `current_config_route` must not call functions inside Gleam guard clauses.
3. Tests constructing `automations_console.Config` must include every labelled
   field, including selected automation entity state.
4. `apps/client/src/scrumbringer_client/automation_deep_link.gleam` is imported
   but untracked.
   A clean checkout would fail even if the compile error is fixed locally.

These checks must pass before any UI validation or final refactor can be trusted.

## Target product behavior

Automations are managed from one console with four modes:

- Engines: workflow containers, activation state and health.
- Rules: cause -> effect definitions.
- Templates: reusable task blueprints.
- Executions: traceability of what rules created and what was ignored.

Rules must read as workflow sentences:

```text
When [Development task] is completed
create [QA checklist task]
in [same card]
```

For card rules:

```text
When [any card] is activated
create [Kickoff task]
in [that card]
```

or:

```text
When [card at depth 2] is closed
create [Delivery review task]
in [that card]
```

The UI must not expose implementation terms such as `resource_type`, `to_state`,
`applied`, `suppressed`, old rule target fields, or legacy workflow CRUD language
as the primary interaction model.

## Scope decisions

### Triggers

Keep the supported trigger families explicit and closed:

- `TaskCreated`
- `TaskClaimed`
- `TaskCompleted`
- `CardActivated`
- `CardClosed`

Do not add due date triggers in this iteration.

Do not allow automation-created tasks to trigger new automations. This must be
enforced in the type/API boundary and covered by tests.

### Actions

Keep the initial action set to one action:

- `CreateTask(template_id)`

One rule creates one task from one template. This keeps workflows readable as
step-by-step chains:

```text
development completed -> create QA
QA completed -> create merge request
```

Do not implement multi-action rules in this iteration. If the product later needs
one trigger to create multiple tasks, that should be designed explicitly instead
of hiding fan-out inside the first model.

### Card scope

Use only these scopes:

- `AnyCard`
- `AtDepth(depth)`

Do not introduce subtree-specific card scopes. They add power, but they also
couple rules to fragile hierarchy branches and make workflows harder to reason
about.

The UI must expose the card scope whenever the selected trigger subject is Card.
If the backend/domain supports `AtDepth`, the rule builder must make it creatable
and the rules engine must match it correctly.

### Rule completeness

Incomplete rules cannot be saved.

A rule draft is complete only when it has:

- engine;
- trigger subject;
- trigger event;
- card scope when subject is Card;
- task type when subject is Task and required by the selected trigger;
- exactly one template;
- one supported action.

The UI may show an incomplete draft locally, but the save action must be
structurally impossible or disabled until the draft validates into a typed
`ValidRuleDraft`.

## Improvement slices

### Slice 1: make the branch executable

1. Verify the `ConfigAutomation` branch in the router page-title function.
2. Verify `current_config_route` uses plain pattern matching and precomputed
   values, not function calls inside guards.
3. Track or remove `automation_deep_link.gleam`; do not leave it untracked.
4. Add focused router tests for `ConfigAutomation` formatting/title behavior.
5. Keep console tests in sync with `automations_console.Config`.
6. Run:
   - `cd shared && gleam test`
   - `cd apps/client && gleam test`
   - server tests only when `DATABASE_URL` is available.

Acceptance:

- `apps/client` compiles.
- The automations console route can be opened.
- Old `/config/templates` and `/config/rule-metrics` routes redirect or resolve
  to the single automations console without exposing duplicate left-sidebar
  entries.

### Slice 2: centralize automation deep links

1. Use one route/deep-link helper for all automation entity links:
   - engine;
   - rule;
   - template;
   - execution.
2. Replace manual query-string construction in Task Show automation-origin links.
3. Keep the helper typed around a selection ADT, not free-form query strings.

Acceptance:

- Clicking an automation origin from Task Show opens the automations console with
  the relevant entity selected.
- No view hand-builds automation query params directly.
- Deep-link labels are i18n-ready and do not hardcode UI copy in routing helpers.

### Slice 3: remove `active`/`status` duplication

1. Choose one source of truth for rule state.
2. Prefer `AutomationRuleStatus` as the domain truth:
   - `RuleActive`
   - `RulePaused`
   - `RuleRequiresReview(reason)`
3. Derive boolean active/inactive only at rendering boundaries if absolutely
   necessary.
4. Make missing templates produce a single coherent status, not `active=True`
   alongside `RequiresReview`.

Acceptance:

- A rule cannot be both active and requires-review in the client model.
- The UI pattern matches on status instead of branching first on `rule.active`.
- Presenters and codecs do not emit/read redundant state unless strictly needed
  by storage, and any storage projection is immediately normalized into the ADT.

### Slice 4: make the rule builder type-driven

1. Replace stringly form state for rule subject/event/template with typed draft
   state.
2. Keep a conversion boundary:
   - `RuleDraftForm` for incomplete UI editing;
   - `ValidRuleDraft` for submit-ready payloads.
3. A submit event must not fire an invalid save attempt.
4. Add the card-scope picker:
   - `AnyCard`;
   - `AtDepth(depth)`;
   - no subtree option.
5. Add a searchable template picker with preview.

Acceptance:

- Incomplete rules cannot be submitted with Enter or click.
- Card triggers can create both `AnyCard` and `AtDepth` rules.
- The rule preview updates as a readable cause -> effect sentence.
- Tests cover incomplete drafts, valid task rules, valid card rules and invalid
  depth.

### Slice 5: make backend matching reflect the ADT

1. Ensure persisted trigger data preserves enough information to match:
   - task type;
   - task/card state transition;
   - card depth when relevant.
2. Update rule matching so `AtDepth(2)` does not fire for cards at other depths.
3. Keep idempotency as event-key + rule identity.
4. Duplicate event/rule attempts should not create another task and should not be
   presented as a new successful outcome.

Acceptance:

- `AnyCard` card rule fires for any matching card event.
- `AtDepth(n)` card rule fires only for that depth.
- Automation-created tasks do not trigger automations.
- Duplicate event/rule processing creates no task and is visible as idempotent
  protection only where useful for diagnostics.

### Slice 6: redesign rules mode as workflow sentences

Replace the current technical rules table as the primary UI.

Primary layout:

```text
Automatizaciones
Crea trabajo automatico en el Pool sin asignarlo a nadie.

[Motores] [Reglas] [Plantillas] [Ejecuciones]

Reglas
[Buscar] [Motor] [Estado]                          [+ Regla]

┌────────────────────────────────────────────────────────────┐
│ Development completed -> QA checklist                      │
│ Motor: Delivery workflow     Estado: Activa                 │
│ Cuando task Development se completa                         │
│ Crea task desde plantilla QA checklist en la misma card      │
│ 12 creadas · ultima ejecucion hace 2 h                      │
│ [Editar] [Pausar] [...]                                     │
└────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────┐
│ Card depth 2 closed -> Delivery review                      │
│ Motor: Release workflow      Estado: Requiere revision      │
│ Falta plantilla                                                │
│ [Editar] [Resolver] [...]                                   │
└────────────────────────────────────────────────────────────┘
```

Keep a dense table only for executions, where tabular data is appropriate.

Acceptance:

- Rules mode explains cause, effect, target and health without requiring the user
  to decode database-like fields.
- The list works at desktop and mobile widths without horizontal scroll as the
  primary experience.
- Old rule CRUD components are removed if no longer used.

### Slice 7: align visual language and accessibility

1. Use the same surface hierarchy as other main views:
   - `work_surface` shell;
   - concise header;
   - mode tabs;
   - filter bar;
   - content list/table depending on mode.
2. Avoid nested cards where a full-width section or row is enough.
3. Make dialogs/drawers accessible:
   - Escape closes;
   - reasonable initial focus;
   - focus returns to origin;
   - secondary menus have labels;
   - tabs are keyboard navigable.
4. Move hardcoded copy to i18n.

Acceptance:

- No new automations UI uses `section_header` as a nested page header inside the
  central work surface.
- `data-testid` values are unique on a page.
- English/Spanish smoke tests still find non-empty translations.

### Slice 8: execution traceability

Executions mode should answer:

- what fired;
- which rule fired;
- which template was used;
- which task was created;
- whether it was ignored because of idempotency, review-required status, missing
  template, or unsupported/incomplete rule;
- when it happened.

Mockup:

```text
Ejecuciones
[Buscar] [Motor] [Regla] [Resultado]

┌────────────────────────────────────────────────────────────┐
│ Creada task QA checklist                                   │
│ Regla: Development completed -> QA checklist               │
│ Plantilla: QA checklist v4                                 │
│ Origen: Task #482 completada · Destino: Task #731           │
│ hace 8 min                                                  │
│ [Abrir task] [Abrir regla]                                  │
└────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────┐
│ Ignorada por idempotencia                                  │
│ Regla: Development completed -> QA checklist               │
│ El evento ya habia sido procesado para esta regla           │
│ hace 9 min                                                  │
└────────────────────────────────────────────────────────────┘
```

Acceptance:

- Task Show automation origin links back to the matching execution/rule/template.
- Executions can be filtered enough to debug noisy workflows.
- Idempotent duplicates do not appear as new successful creations.

### Slice 9: cleanup obsolete code

Remove or rename obsolete surfaces once the new console covers them:

- old workflow CRUD dialog if unused;
- old rule CRUD dialog if unused;
- old standalone task-template/rule-metrics views if replaced by console modes;
- route/query helpers that manually encode old workflow sections;
- old tests that assert legacy UI terminology.

Do not keep compatibility code unless it protects real persisted URLs/data and is
documented as a small routing redirect. Internal code should use current
automation names.

Acceptance:

- `rg "workflow_crud_dialog|rule_crud_dialog|resource_type|to_state|suppressed"`
  shows only storage/query compatibility, tests for migration boundaries, or no
  matches.
- Left sidebar shows a single automations entry.
- No dead component remains imported only by tests.

## Tests to add or harden

### Shared/domain

- Rule draft validates required fields.
- Incomplete rule cannot become `ValidRuleDraft`.
- Card scopes encode/decode:
  - `AnyCard`;
  - `AtDepth(1)`;
  - invalid depths rejected.
- Due date trigger decoding fails.
- Automation-created task trigger is unrepresentable or rejected.
- Status derivation cannot produce active + requires-review simultaneously.

### Client

- Router handles `ConfigAutomation`.
- Task Show automation-origin links use central deep-link helper.
- Rule builder disabled/blocked for incomplete rules, including Enter submit.
- Card rule builder exposes scope picker.
- Template picker supports search and preview.
- Rules mode renders sentence rows, not technical columns as primary UI.
- `data-testid` values are unique for:
  - `automations-surface`;
  - `automation-rule-row`;
  - `automation-rule-builder`;
  - `automation-template-picker`;
  - `automation-execution-row`.
- Dialog/drawer accessibility:
  - Escape closes;
  - focus returns to opener;
  - tabs can be navigated by keyboard.

### Server

- Task completed rule creates exactly one task from template.
- Task claimed/created triggers match only intended task types.
- Card activated/closed `AnyCard` rule fires.
- Card activated/closed `AtDepth(n)` rule fires only at matching depth.
- Duplicate event/rule does not create another task.
- Automation-created tasks do not trigger automations.
- Missing template causes requires-review/skip behavior consistently.
- Non-manager cannot create/edit/pause/archive automations.

### Browser validation

Use agent-browser once available.

Cases:

1. Open automations console from left sidebar.
2. Create engine.
3. Create template.
4. Create `TaskCompleted -> CreateTask(template)` rule.
5. Complete a matching task and verify the generated task appears in Pool.
6. Open generated task, verify automation origin.
7. Click origin, verify deep link opens automations console with entity selected.
8. Create `CardActivated AnyCard -> CreateTask(template)` rule.
9. Create `CardClosed AtDepth(2) -> CreateTask(template)` rule and verify depth
   matching.
10. Confirm automation-created task does not cascade into more automation.
11. Pause rule, verify it stops firing.
12. Break template reference or simulate missing template, verify requires-review.
13. Validate desktop and mobile layouts for engines, rules, templates and
    executions.

## Recommended execution order

1. Fix P0 compile/tracking issues.
2. Centralize automation deep links.
3. Remove `active`/`status` duplication.
4. Type the rule draft and add card scope picker.
5. Align backend matching with card scope.
6. Redesign Rules mode into sentence rows.
7. Improve Template picker and Execution traceability.
8. Accessibility/i18n pass.
9. Remove obsolete legacy components/routes/tests.
10. Run full tests and browser validation.
11. Commit.

## Relationship with the final refactor

This plan should feed into the final codebase refactor analysis, but it should not
wait for a broad cleanup to fix the executable blockers.

The final refactor should use workflows as one of the audit samples for:

- domain ADT boundaries;
- shared/client/server codec naming;
- no duplicated state;
- no unused legacy UI components;
- no hardcoded UI copy;
- feature-local component extraction before global abstractions.
