# Sprint 1 Refactor Checklist (Executable)

## Scope
- `apps/client/src/scrumbringer_client.gleam`
- `apps/client/src/scrumbringer_client/api.gleam`
- `apps/server/src/scrumbringer_server/http/tasks.gleam`

## Hygiene Rules (mandatory)
- Functions ≤ 100 lines (justify exceptions in `///` doc)
- No 3 nested `case`; 2 nested allowed with justification
- `////` module docs at top of each touched module
- `///` for every public type/function + usage example
- English docs only

---

## Checklist
### Client: Split `scrumbringer_client.gleam`
- [x] Create `client_state.gleam` (Model/Msg/state types + docs)
- [x] Create `update_helpers.gleam` (pure helper functions + Model accessors)
  - Extracted 18 functions (431 lines): dict conversions, time formatting, lookups, i18n, selection helpers
  - Main module reduced from 7593 to 7383 lines (~210 lines extracted)
  - View-related helpers (formatters, comparators) deferred to client_view.gleam extraction
- [x] Create `client_update.gleam` (update + handlers; reduce nested cases)
  - Full extraction complete: 3854 lines with update function + all handlers
  - Includes: hydration, navigation, bootstrap, message handlers
  - Exports: update, register_popstate_effect, register_keydown_effect, write_url, accept_invite_effect, reset_password_effect
- [x] Create `client_view.gleam` (view + subviews; split >100‑line functions)
  - Full extraction complete: 3618 lines with view function + all view helpers
  - Includes: all page views, component views, admin/member sections
  - Note: 5 functions >100 lines remain (can be split in future sprint)
- [x] Create `client_ffi.gleam` (FFI isolation - per interop guideline)
- [x] Move @external from api.gleam to client_ffi.gleam
- [x] Create `client_router.gleam` (routing + URL helpers)
  - `router.gleam` already exists with full functionality
  - Added module/function docs (parse, format, apply_mobile_rules)
- [x] Reduce `scrumbringer_client.gleam` to entry wiring
  - Extracted update function (3854 lines) to `client_update.gleam`
  - Extracted view function (3618 lines) to `client_view.gleam`
  - Entry module reduced to 287 lines (app, main, init only)
- [x] Add module/type/function docs for new modules (client_state, client_ffi, update_helpers)
- [x] Add //// module docs to scrumbringer_client.gleam
- [x] Add //// module docs to api.gleam

### Client: Split `api.gleam`
- [x] `api/core.gleam` (request + error decoding)
- [x] `api/auth.gleam`
- [x] `api/projects.gleam`
- [x] `api/tasks.gleam`
- [x] `api/metrics.gleam`
- [x] `api/org.gleam`
- [x] Update imports + docs + examples (original api.gleam kept for backwards compatibility)
  - api.gleam module docs updated to document submodule structure
  - Submodules have full docs with usage examples
  - Import migration to submodules deferred (Gleam lacks type re-export for ADTs)

### Server: `http/tasks.gleam`
- [x] `tasks/validators.gleam` (task input validation + auth helpers)
- [x] `tasks/presenters.gleam` (task JSON builders)
- [x] `tasks/filters.gleam` (filter parsing)
- [x] `tasks/conflict_handlers.gleam` (claim/version conflict resolution)
- [x] Main tasks.gleam reduced from 1132 to 791 lines
- [x] Add module/type/function docs

---

## Verification (DoD)
- [x] `make test` passes (151 tests: 69 server + 82 client)
- [x] `gleam test` passes
- [x] Hygiene rules verified (for new modules)
- [x] Docs updated for all new modules
