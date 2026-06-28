# Codebase file-by-file audit

Generated: 2026-06-28

## Scope and baseline

- HEAD at generation time: `f227c56c6b112f3e35bd304b20bfd44f07794161`
- Files inventoried: 1262
- Gleam modules inventoried: 966
- Server route patterns inventoried: 78
- Client API call sites inventoried: 102
- Frontend component/view/update candidates inventoried: 205
- Test files inventoried: 369

The inventory includes tracked files plus untracked, non-ignored files in the current worktree, because the worktree is the authoritative state for this audit.

## Inventory by package

| Package | Files |
| --- | --- |
| ci | 1 |
| client | 653 |
| database | 38 |
| deploy | 5 |
| docs | 57 |
| root | 49 |
| script | 14 |
| server | 340 |
| shared | 105 |

## Inventory by kind

| Kind | Files |
| --- | --- |
| api_client | 20 |
| config | 15 |
| docs | 92 |
| domain_model | 66 |
| endpoint_handler | 85 |
| ffi | 10 |
| lustre_component | 2 |
| lustre_route | 18 |
| lustre_update | 37 |
| lustre_view | 147 |
| module | 173 |
| repository | 5 |
| route | 1 |
| script | 13 |
| sql | 152 |
| support | 13 |
| test | 369 |
| use_case | 44 |

## Main findings

1. Resolved: no client API shape currently lacks an exact router shape. The previous card-tasks client-only endpoint is no longer an open P0.
2. P1: the codebase has parallel resource families where unification should be driven by domain adjacency, not by file size. The strongest families are task/card notes, task/card view tracking, task/card show inspector surfaces and status metrics.
3. P1: backend route coverage is centralized and discoverable in `web/router.gleam`, but method/status matrices live in handlers and tests; endpoint refactors must preserve Parse -> Process -> Present boundaries.
4. P2: frontend has many feature-local views and update modules. This is healthy when it preserves product ownership, but repeated UI language should be pulled into semantic UI primitives with accessible labels and tests.
5. P2: shared modules should remain reserved for full-stack contracts and canonical domain types. The duplicate-basename report is a prompt for review, not permission to move everything to shared.
6. P2: tests mostly use public behavior, but rows marked with private-helper signals should be audited because they can keep accidental `pub fn` surfaces alive.

## Responsibility audit

- Backend: handlers should keep HTTP Parse -> Process -> Present, while repositories/SQL remain storage owners. Candidate unifications should target presenters/contracts first, not merge route families blindly.
- Frontend: `features/*` should own product state, messages and effects. `ui/*` should own visual primitives, accessibility and reusable rendering only.
- Shared: only canonical domain types and full-stack contracts should move here. Same basename across packages is evidence for review, not automatic shared extraction.
- Tests: tests should protect public behavior. Any test preserving a public helper that production does not need should be rewritten before privatizing that helper.

## Priority order

| Priority | Area | Reason |
| --- | --- | --- |
| P1 | Task/Card notes | Repeated endpoint/client/UI/test surface with high reuse potential. |
| P1 | Task/Card resource views | Same behavioral shape with separate handlers and tests. |
| P1 | Card/Task show inspector ownership | Product state and UI primitives are adjacent and should keep clean boundaries. |
| P2 | Metric visual language | Repeated counters/badges should share accessible semantic primitives. |
| P2 | Public API accidental surface | Tests may keep internals public. |

## Deliverables

- `codebase-inventory.yml`: raw file-by-file inventory generated locally by
  `scripts/codebase_audit.py` and intentionally not versioned.
- `endpoint-map.md`: server routes, handlers, client call-site counts and static mismatches.
- `component-map.md`: frontend views/components with state/accessibility/test signals.
- `module-map.md`: all Gleam modules with public surface and consumers.
- `test-coverage-map.md`: tests by type and coupling signal.
- `refactor-candidates.md`: prioritized candidates and detected risk signals.
- `refactor-work-packages.md`: executable packages for the next phase.

## Completion status

This audit has completed the inventory and generated the requested maps. The raw inventory is reproducible with `python3 scripts/codebase_audit.py`; the curated maps and work packages remain versioned. The next step is not to refactor globally, but to review and execute the work packages one by one, starting with candidates that delete duplicated code or close accidental public APIs.
