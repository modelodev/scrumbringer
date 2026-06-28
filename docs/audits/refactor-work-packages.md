# Refactor work packages

These packages are derived from `refactor-candidates.md`. They are intentionally small enough to execute independently after the audit is reviewed.

## Completed packages

- WP-00: the previous client-only card tasks endpoint was resolved by deleting the dead client API and stale backend route comment. `endpoint-map.md` now reports zero client endpoint shapes without router shape.

## WP-01: Notes contract and presentation unification

### Problem

Task notes and card notes repeat endpoint shapes, client API calls, UI note rendering and test fixtures.

### Evidence

- Server: `http/task_notes.gleam`, `http/card_notes.gleam`, note SQL files.
- Client: `api/tasks/notes.gleam`, card note calls in `api/cards.gleam`.
- UI: note rendering in task show, card show and shared note UI modules.

### Design decision

Keep resource-specific handlers if authorization differs, but extract shared note contract/presenter/rendering and shared test fixtures.

### Changes planned

- Add or reuse a shared `NoteResource`/`ResourceNote` ADT if it removes duplicated branch logic.
- Keep Parse -> Process -> Present in handlers.
- Move common note HTML into `ui/notes_list`/`ui/note_content`.
- Rewrite tests around public endpoints and rendered output.

### Code to remove

- Duplicate note JSON mappers.
- Repeated note list markup in show views.
- Duplicated fixtures that only differ by task/card prefix.

### Acceptance criteria

- Both task and card notes still pass endpoint tests.
- Shared note rendering has focused tests.
- No generic CRUD abstraction is introduced.

## WP-02: Resource view tracking coverage hardening

### Current state

Task/card view registration already shares the HTTP flow through `http/resource_views.gleam`; `task_views.gleam` and `card_views.gleam` only keep resource-specific project lookup and error mapping.

### Problem

The remaining risk is not duplicated production flow, but weak regression coverage around the shared flow and accidental reintroduction of local status mapping.

### Evidence

- `/api/v1/views/tasks/{task_id}`
- `/api/v1/views/cards/{card_id}`
- `http/resource_views.gleam`
- `http/task_views.gleam`
- `http/card_views.gleam`

### Design decision

Keep the current small shared handler. Do not introduce a `ResourceViewed(Task|Card)` ADT unless a future use case needs resource values outside HTTP routing.

### Code to remove

- Any future duplicate response/status mapping inside `task_views.gleam` or `card_views.gleam`.
- Tests that duplicate the same shared status matrix without resource-specific authorization value.

### Acceptance criteria

- Tests cover task and card authorization separately.
- Shared flow remains in `http/resource_views.gleam`.
- `task_views.gleam` and `card_views.gleam` stay limited to project lookup and resource-specific error mapping.

## WP-03: Inspector/show ownership hardening

### Problem

Card Show and Task Show share inspector primitives but product state still risks leaking into `ui/`.

### Evidence

- `features/cards/show*`
- `features/tasks/show/*`
- `ui/inspector_*`
- inspector tests.

### Design decision

`ui/inspector_*` owns visual shell/actions only. Product-specific sections, state, messages and effects stay in `features/cards/show` or `features/tasks/show`.

### Code to remove

- Product conditionals from UI primitives.
- Duplicate local action-menu markup.
- Tests that import internals instead of rendering the public show surface.

### Acceptance criteria

- UI primitives have snapshot/string render tests with accessible labels.
- Show features cover public behavior via route/update/view entry points.

## WP-04: Status metric visual language consolidation

### Problem

Totals, closed, blocked, available, claimed and in-progress metrics are represented with mixed text/icon/badge patterns.

### Evidence

- `ui/task_metric.gleam`
- `ui/card_progress.gleam`
- feature-local badges in pool/card/task views.

### Design decision

Create semantic metric primitives with icon, numeric value, tooltip and accessible label. Keep domain-specific aggregation outside the primitive.

### Code to remove

- Local text badges for the same metric concepts.
- Repeated icon+number markup.

### Acceptance criteria

- Hover/title or equivalent accessible label exists for every icon-only metric.
- Tests cover labels and numeric output.

## WP-05: Public API accidental surface cleanup

### Problem

Some tests appear to couple to internal helpers, forcing public APIs that production does not need.

### Evidence

See `test-coverage-map.md` rows marked with `Private-helper signal`.

### Design decision

Tests should enter through production entry points unless the helper is a pure, intentionally shared module.

### Code to remove

- `pub fn` handlers used only by tests.
- Test-only success wrappers in production modules.

### Acceptance criteria

- `rg "\.(handle_|success_effect|apply_)" apps/client/test apps/server/test` is reviewed and reduced to justified cases.
- Privatized helpers remain covered through public behavior.

## WP-06: Large module responsibility review

### Problem

Large modules can hide multiple responsibilities, but splitting by line count alone creates churn.

### Evidence

See `refactor-candidates.md` large modules table.

### Design decision

Split only when a new local owner removes duplicated branches, effect orchestration or unrelated view sections.

### Code to remove

- Repeated branches in route/update roots.
- Private helpers that become local to the new owner.

### Acceptance criteria

- Each split leaves fewer responsibilities in the original module.
- New modules have focused tests or are covered by public route/update/view tests.
