# Story ref3b-005: Router frontend autocontenido (parse/push/replace/title)

## Status: Done

## Story
**As a** maintainer,
**I want** the frontend router to encapsulate parse/format/push/replace/title logic,
**so that** routing behavior is centralized and consistent.

## Acceptance Criteria
1. `router.gleam` owns parsing and URL construction (Route ↔ Uri).
2. `router.gleam` exposes `push`, `replace`, and `update_page_title`.
3. No routing logic remains scattered in other modules.
4. Tests pass.

## Tasks / Subtasks
- [x] Move any URL formatting/parsing helpers into `router.gleam`.
- [x] Add `update_page_title(route)`.
- [x] Ensure `push/replace` are only used from router module.
- [x] Update call sites.
- [x] Add `////` + `///` docs.

## Testing
- `gleam test`
- `make test`

## Change Log
| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-01-18 | 0.1 | Created ref3b-005 story | assistant |

## Dev Agent Record

### Implementation Summary

Centralized all routing logic in `router.gleam`:

1. **Added navigation effects**: `push(route)` and `replace(route)` functions that create Lustre effects for browser history manipulation.

2. **Added page title support**:
   - `update_page_title(route, locale)` - effect that sets browser document title
   - `page_title_for_route(route, locale)` - returns the title string
   - Added `set_document_title` FFI binding

3. **Refactored existing code**:
   - `write_url` in `client_update.gleam` now delegates to `router.push`/`router.replace`
   - `replace_url` in `client_update.gleam` now uses `router.replace(current_route(model))`
   - Removed unused `url_for_model` function

4. **View code clarity**: Renamed `page_title` to `admin_section_label` in `client_view.gleam` with documentation clarifying it's for i18n text keys, not routing.

### Files Modified
- apps/client/src/scrumbringer_client/router.gleam (added push, replace, update_page_title, page_title_for_route)
- apps/client/src/scrumbringer_client/client_update.gleam (updated write_url, replace_url)
- apps/client/src/scrumbringer_client/client_view.gleam (renamed page_title → admin_section_label)
- apps/client/src/scrumbringer_client/client_ffi.gleam (added set_document_title)
- apps/client/src/scrumbringer_client/client_ffi.gleam (added set_document_title)

### Test Results
- gleam test: 82 passed
- make test: 69 server + 82 client passed

## QA Results

### Review Date: 2026-01-18

### Reviewed By: Quinn (Test Architect)

### Code Quality Assessment

Excellent implementation. The routing logic has been cleanly centralized in `router.gleam`:

- **Clean API design**: `push`, `replace`, and `update_page_title` provide a clear, type-safe interface for navigation
- **Proper encapsulation**: `history_push_state` and `history_replace_state` are now only called from within router.gleam
- **Good documentation**: Module header updated with comprehensive usage examples, all new public functions have docstrings
- **Consistent patterns**: The new functions follow existing Lustre effect patterns (`effect.from`)

The FFI addition for `set_document_title` is minimal and follows the defensive coding style of existing FFI functions (checking for `undefined` environments).

### Refactoring Performed

None required. The implementation is clean and follows established patterns.

### Compliance Check

- Coding Standards: ✓ Follows Gleam conventions, proper module structure
- Project Structure: ✓ Router in correct location, FFI properly placed
- Testing Strategy: ✓ Existing tests pass (82 client + 69 server)
- All ACs Met: ✓ All 4 acceptance criteria verified

### Improvements Checklist

- [x] Router owns URL parsing and construction
- [x] Router exposes push, replace, update_page_title
- [x] No routing logic scattered (history calls only in router.gleam)
- [x] Comprehensive documentation added
- [ ] Consider adding unit tests for `page_title_for_route` (future improvement)

### Security Review

No security concerns. The changes are purely structural refactoring of routing logic with no new attack surface.

### Performance Considerations

No performance impact. The refactoring adds a minimal indirection layer that has negligible cost.

### Files Modified During Review

None. No refactoring performed.

### Gate Status

Gate: **PASS** → docs/qa/gates/ref3b-005-router-frontend.yml

### Recommended Status

✓ Ready for Done

The implementation cleanly achieves the goal of centralizing routing logic in `router.gleam`. The API is well-designed, properly documented, and the test suite passes.
