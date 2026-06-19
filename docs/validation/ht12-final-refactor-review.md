# HT-12 Final Refactor Review

Parent branch resolution followed the `gleam-refactor` skill order:

- Upstream: none configured for `new_hierarchy`
- Parent used: `main`
- Scope command: `git diff --name-only main...HEAD`

## Refactor Summary

- Domain/shared: uses the `CardHierarchy` structural wrapper, updated tests,
  and keeps card/task leaf invariants in shared domain modules.
- Server: removed obsolete hierarchy metrics and generated SQL surfaces,
  replaced remaining parent-card error naming, removed old API-token scopes,
  converted seed creation to root cards, and added a migration to remove the
  final migration-report artifact table.
- Client: renamed the visible hierarchy feature module path, CSS classes, i18n
  keys, tests, and task placement helper names away from removed card-tree
  terminology.
- Tests/gates: converted obsolete hierarchy endpoint metric tests to supported
  card/task metric coverage, made final cleanup gates self-excluding, and kept
  rejected legacy-route coverage through constructed legacy strings.
- Docs: updated API, skill, architecture, audit, and validation docs to use the
  final hierarchy/task-leaf terminology.

## Applied Improvements

- High value / medium complexity / low risk: removed obsolete generated SQL and
  metrics code for deleted hierarchy endpoints.
- High value / medium complexity / medium risk: renamed the client hierarchy
  surface consistently across modules, CSS classes, i18n, and tests.
- High value / low complexity / low risk: removed obsolete API-token scopes and
  updated supported-scope tests.
- Medium value / low complexity / low risk: made anti-legacy regression tests
  avoid direct self-matches while preserving rejection coverage.
- Medium value / low complexity / low risk: updated docs and validation records
  to reflect the final model.

## Rejected Improvements

- Rewriting historical migrations that transform removed data was rejected for
  this cleanup pass. Those files preserve migration history; the live schema and
  active code are clean, and a forward migration removes the leftover report
  table.
- Adding new abstraction layers around hierarchy/card presentation was rejected;
  the cleanup reduced naming and stale surfaces without introducing wrappers.
- Removing `parent_card_id` from database-facing code was rejected here because
  it is the current persisted parent link for cards/tasks and changing it would
  be a separate schema/API migration.

## Verification

- `gleam format --check src test` passed in `shared`, `apps/client`, and
  `apps/server`.
- `gleam check` passed in `shared`, `apps/client`, and `apps/server`.
- `gleam test --target erlang` passed in `shared`: `221 passed`.
- `gleam test --target javascript` passed in `apps/client`: `1566 passed`.
- Direct HT-12 cleanup gate invocation through `final_cleanup_ht12_ffi` returned
  no violations.
- Anti-legacy scans returned no matches for removed hierarchy, legacy
  delivery/state, or old task-event terms in active source, tests, docs, and
  schema outside `docs/card-tree-task-leaves-model.md`.
- `agent-browser` validation passed on desktop, tablet, and mobile; screenshots
  are listed in `docs/validation/ht12-ui-validation.md`.

## Known Test Limitation

`gleam test --target erlang` in `apps/server` still runs the whole DB-backed
suite and requires `DATABASE_URL`. Without that environment it fails at fixture
bootstrap, so the final pure cleanup gates were invoked directly and the server
package was verified with `gleam check` plus formatting.
