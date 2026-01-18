# Story ref3b-006: Update handlers pequeños por feature

## Status: Done

## Story
**As a** maintainer,
**I want** each update path to delegate to small `handle_*` functions,
**so that** update logic remains readable and testable.

## Acceptance Criteria
1. `update` delegates into per‑feature `handle_*` functions.
2. Each handler is ≤50 lines when feasible.
3. Behavior unchanged and tests pass.

## Tasks / Subtasks
- [x] Split large update cases into `handle_*` functions per feature.
- [x] Move handlers to `features/*/update.gleam` when possible.
- [x] Keep `app/update.gleam` as dispatcher only.
- [x] Add `////` + `///` docs.

## Testing
- `gleam test`
- `make test`

## Change Log
| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-01-18 | 0.1 | Created ref3b-006 story | assistant |
| 2026-01-18 | 1.0 | Implemented - delegated handlers to feature modules | Claude Opus 4.5 |

## Dev Agent Record

### Agent Model Used
Claude Opus 4.5 (claude-opus-4-5-20251101)

### Completion Notes
- Created 3 new update modules: `features/pool/update.gleam`, `features/metrics/update.gleam`, `features/skills/update.gleam`
- Extended existing `features/tasks/update.gleam` with notes handlers
- Refactored `client_update.gleam` to delegate pool, metrics, skills, positions, and notes handlers to feature modules
- All handlers follow the `handle_*` naming convention with `///` documentation
- Module-level `////` docs explain mission, responsibilities, non-responsibilities, and relations
- `client_update.gleam` reduced from ~2290 lines to ~1700 lines (26% reduction)
- Removed unused imports and helper functions from `client_update.gleam`

### Debug Log References
N/A - No blocking issues encountered

### File List
| File | Action |
|------|--------|
| `apps/client/src/scrumbringer_client/features/pool/update.gleam` | Created |
| `apps/client/src/scrumbringer_client/features/metrics/update.gleam` | Created |
| `apps/client/src/scrumbringer_client/features/skills/update.gleam` | Created |
| `apps/client/src/scrumbringer_client/features/tasks/update.gleam` | Modified (added notes handlers) |
| `apps/client/src/scrumbringer_client/client_update.gleam` | Modified (delegates to feature modules) |

## QA Results
