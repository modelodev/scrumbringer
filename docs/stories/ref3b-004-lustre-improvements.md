# Story ref3b-004: Mejoras Lustre de alto valor (keyed, optimistic, flags, routing)

## Status: Done

## Story
**As a** maintainer,
**I want** to apply high‑value Lustre patterns (keyed elements, optimistic updates, flags, debouncing, and routing state),
**so that** UI performance, UX responsiveness, and maintainability improve measurably.

## Acceptance Criteria
1. Dynamic lists (tasks, members, invites, projects) use keyed elements.
2. Task actions use optimistic updates with rollback on error.
3. Input debouncing protects against stale responses.
4. Router encodes filters or last selections in URL or localStorage (documented choice).
5. App startup supports flags-based config (or documented alternative).
6. Tests pass.

## Tasks / Subtasks

### A) Keyed elements in dynamic lists (Lustre example: 01‑basics/04‑keyed‑elements)
- [x] `features/pool/view.gleam` — keyed tasks list (pool/canvas/metrics) via `keyed.div`
- [x] `features/admin/view.gleam` — keyed admin tables (users, capabilities, members, task_types) via `keyed.tbody`
- [x] `features/projects/view.gleam` — keyed projects list via `keyed.tbody`
- [x] `features/invites/view.gleam` — keyed invite links list via `keyed.tbody`
- [x] `features/my_bar/view.gleam` — keyed claimed tasks list via `keyed.div`

### B) Optimistic updates for task actions (Lustre example: 03‑effects/06‑optimistic‑requests)
- [x] `features/tasks/update.gleam` — claim/release/complete optimistic update with snapshot/rollback
- [x] Rollback state when server response fails (restore from `member_tasks_snapshot`)
- [x] Error display via existing `member_now_working_error` field (no new ui/error.gleam needed)

### C) Debounce guard for search inputs (Lustre: 02‑inputs/03‑debouncing)
- [x] `features/admin/search.gleam` — attach request token via `org_users_search_token`
- [x] Ignore stale results (check token match before applying results)

### D) Routing or storage for state (Lustre: 04‑applications/01‑routing + 03‑effects/04‑local‑storage)
- [x] Already implemented: `theme.gleam`, `features/pool/update.gleam` (pool_prefs), `i18n/locale.gleam` all persist to localStorage
- [x] Selected project not persisted (by design: user selects project on each session)
- [x] Documented: localStorage strategy chosen over URL routing for user preferences

### E) Flags for app boot config (Lustre: 01‑basics/06‑flags)
- [x] Verified: API uses relative URLs (`/api/...`), no base_url config needed
- [x] Feature toggles not needed at this stage (single deployment target)
- [x] Documented: flags pattern available but not required for current architecture

### F) Fragments to reduce wrapper DOM (Lustre: 01‑basics/05‑fragments)
- [x] Replaced 39 instances of `div([], [])` with `element.none()` across 10 view files

### Verification
- [x] Run `gleam test` — 82 passed
- [x] Run `make test` — 69 server + 82 client passed

## Dev Notes
- Follow TEA purity: views are pure; effects only from update.
- Keep behavior unchanged except for responsiveness improvements.
- If any design choice deviates from tasks above, document in module header.

## Testing
- `gleam test`
- `make test`

## Change Log
| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-01-18 | 0.1 | Created ref3b-004 story from Lustre examples | assistant |

## Dev Agent Record

### Implementation Summary
All six tasks completed successfully applying Lustre best practices:

**A) Keyed Elements** — Added `lustre/element/keyed` imports and converted dynamic lists to use `keyed.div` and `keyed.tbody` with stable keys (entity IDs). Files: pool/view.gleam, admin/view.gleam, projects/view.gleam, invites/view.gleam, my_bar/view.gleam.

**B) Optimistic Updates** — Implemented snapshot/rollback pattern for task mutations (claim, release, complete). New fields in Model: `member_task_mutation_task_id`, `member_tasks_snapshot`. On mutation start: snapshot current tasks, apply optimistic state. On error: restore from snapshot. Files: client_state.gleam, features/tasks/update.gleam, scrumbringer_client.gleam.

**C) Stale Response Protection** — Added `org_users_search_token` to Model. Each search increments token, responses include token, results only applied if token matches current. Files: client_state.gleam, features/admin/search.gleam, client_update.gleam.

**D) Storage Strategy** — Verified existing localStorage persistence for theme, locale, and pool_prefs. No changes needed — strategy already in place and documented.

**E) Flags Pattern** — Verified API uses relative URLs, flags not needed for current architecture. Pattern documented for future use.

**F) Fragments** — Replaced 39 instances of `div([], [])` with `element.none()` across 10 files to reduce unnecessary DOM nodes.

### Files Modified
- apps/client/src/scrumbringer_client/client_state.gleam
- apps/client/src/scrumbringer_client/client_update.gleam
- apps/client/src/scrumbringer_client/client_view.gleam
- apps/client/src/scrumbringer_client.gleam
- apps/client/src/scrumbringer_client/features/pool/view.gleam
- apps/client/src/scrumbringer_client/features/admin/view.gleam
- apps/client/src/scrumbringer_client/features/admin/search.gleam
- apps/client/src/scrumbringer_client/features/projects/view.gleam
- apps/client/src/scrumbringer_client/features/invites/view.gleam
- apps/client/src/scrumbringer_client/features/my_bar/view.gleam
- apps/client/src/scrumbringer_client/features/skills/view.gleam
- apps/client/src/scrumbringer_client/features/auth/view.gleam
- apps/client/src/scrumbringer_client/features/now_working/view.gleam
- apps/client/src/scrumbringer_client/ui/layout.gleam
- apps/client/src/scrumbringer_client/ui/toast.gleam

### Test Results
- gleam test: 82 passed
- make test: 69 server + 82 client passed

## QA Results

### Review Date: 2026-01-18

### Reviewed By: Quinn (Test Architect)

### Code Quality Assessment

Excellent implementation of Lustre best practices. The code follows TEA (The Elm Architecture) patterns correctly:

- **Keyed elements**: Properly implemented using `keyed.div` and `keyed.tbody` with stable entity IDs as keys. This ensures efficient DOM reconciliation when lists change.

- **Optimistic updates**: Well-structured snapshot/rollback pattern in `features/tasks/update.gleam`. The implementation:
  - Snapshots task list before mutation (lines 400-405)
  - Applies optimistic state immediately (lines 408-461)
  - Restores from snapshot on error (lines 465-470)
  - Clears optimistic state on success (lines 477-483)

- **Stale response protection**: Token-based approach in `features/admin/search.gleam` is idiomatic. The token increment on each search and comparison on results prevents race conditions cleanly.

- **Fragments**: Correct use of `element.none()` instead of `div([], [])` reduces DOM node count.

### Refactoring Performed

None required. The implementation is clean and follows established patterns.

### Compliance Check

- Coding Standards: ✓ Follows Gleam conventions, proper module structure
- Project Structure: ✓ Files in correct locations under features/
- Testing Strategy: ✓ Existing tests pass (82 client + 69 server)
- All ACs Met: ✓ All 6 acceptance criteria verified

### Improvements Checklist

- [x] Keyed elements for dynamic lists (5 view files)
- [x] Optimistic updates with snapshot/rollback
- [x] Stale response protection via tokens
- [x] LocalStorage strategy verified and documented
- [x] Flags pattern documented (not needed for current arch)
- [x] Fragments replacing empty divs
- [ ] Consider adding unit tests for rollback scenarios (future improvement)

### Security Review

No security concerns. The optimistic update pattern properly handles error rollback without exposing sensitive state. Token-based stale response protection prevents data inconsistency but does not involve authentication.

### Performance Considerations

Positive performance impact:
- Keyed elements: O(n) → O(1) for item updates in lists
- Fragments: Reduced DOM node count by 39 unnecessary wrapper divs
- Optimistic updates: Immediate UI feedback improves perceived performance

### Files Modified During Review

None. No refactoring performed.

### Gate Status

Gate: **PASS** → docs/qa/gates/ref3b-004-lustre-improvements.yml

### Recommended Status

✓ Ready for Done

The implementation is solid, well-documented, and all acceptance criteria are met. The patterns follow Lustre best practices and the existing test suite passes.
