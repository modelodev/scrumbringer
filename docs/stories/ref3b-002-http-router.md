# Story ref3b-002: Extraer router HTTP dedicado

## Status: Done

## Story
**As a** maintainer,
**I want** to move HTTP routing into a dedicated module,
**so that** `scrumbringer_server.gleam` remains a clean bootstrap file.

## Acceptance Criteria
1. A new `web/router.gleam` module exists and contains routing + middleware chain.
2. `scrumbringer_server.gleam` delegates routing (bootstrap only).
3. No route behavior changes.
4. Tests pass (`gleam test`, `make test`).

## Tasks / Subtasks

- [x] Create `apps/server/src/scrumbringer_server/web/router.gleam`.
- [x] Move route table + middleware chain from `scrumbringer_server.gleam` to `web/router.gleam`.
- [x] Update `scrumbringer_server.gleam` to call router entrypoint.
- [x] Ensure handlers remain under `http/*` and imports updated.
- [x] Add `////` + `///` docs in new module.

### Verification
- [x] Run `gleam test`
- [x] Run `make test`

## Dev Notes
- No behavioral changes; refactor only.
- Router module should be thin and composable.

## Testing
- `gleam test`
- `make test`

## Change Log
| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-01-18 | 0.1 | Created ref3b-002 story | assistant |

## Dev Agent Record

**Agent**: James (Dev)
**Date**: 2026-01-18
**Model**: claude-opus-4-5-20251101

### Implementation Summary

Extracted HTTP routing from `scrumbringer_server.gleam` into a dedicated `web/router.gleam` module:

**Architecture:**
- `scrumbringer_server.gleam` now handles only bootstrap (DB pool, server lifecycle)
- `web/router.gleam` owns all route patterns and dispatches to `http/*` handlers
- `RouterCtx` type encapsulates db + jwt_secret for request handling

**Routes organized by domain:**
- Auth routes (register, login, logout, me, password-resets)
- Org routes (invites, invite-links, users, metrics)
- Project routes (projects, members, task-types, tasks)
- Task routes (claim, release, complete, notes)
- Capabilities routes
- Me routes (task-positions, active-task, metrics)
- Health check

**AC Verification:**
1. ✓ `web/router.gleam` module exists with routing + middleware chain
2. ✓ `scrumbringer_server.gleam` delegates to router (bootstrap only)
3. ✓ No route behavior changes
4. ✓ Tests pass: Server 69, Client 82

### File List

**Created:**
- `apps/server/src/scrumbringer_server/web/router.gleam`

**Modified:**
- `apps/server/src/scrumbringer_server.gleam`

### Verification

- Build: ✓ 0 warnings
- Tests: ✓ Server 69, Client 82

## QA Results

### Review Date: 2026-01-18

### Reviewed By: Quinn (Test Architect)

### Code Quality Assessment

Clean extraction refactor. The router module is well-structured with:
- Clear module documentation (`////` block)
- Logical route grouping by domain (auth, org, projects, tasks, capabilities, me)
- Proper context conversion functions (`auth_ctx`, `password_resets_ctx`)
- Type-safe `RouterCtx` encapsulating dependencies

The main module is now focused on bootstrap concerns (DB pool, server lifecycle) as intended.

### Refactoring Performed

None required. Implementation follows coding standards.

### Compliance Check

- Coding Standards: ✓ Module docs, type annotations, pipeline style
- Project Structure: ✓ New `web/` directory appropriate for routing concerns
- Testing Strategy: ✓ Existing tests validate behavior unchanged
- All ACs Met: ✓ All 4 acceptance criteria verified

### Improvements Checklist

- [x] Module documentation present
- [x] Route grouping with comments for clarity
- [x] Context conversion functions properly scoped as private

### Security Review

No security concerns. Routing logic unchanged, auth handlers called identically.

### Performance Considerations

No performance impact. Single additional function call for context creation is negligible.

### Files Modified During Review

None.

### Gate Status

Gate: PASS → docs/qa/gates/ref3b-002-http-router.yml

### Recommended Status

✓ Ready for Done
