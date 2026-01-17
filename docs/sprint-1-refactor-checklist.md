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
- [ ] Create `client_update.gleam` (update + handlers; reduce nested cases)
  - Remaining: update still has domain handlers + effect-creating helpers
  - Approach: extract handlers by domain (auth, member, admin) in future sprint
- [ ] Create `client_view.gleam` (view + subviews; split >100‑line functions)
  - view is ~3460 lines with many subviews
- [x] Create `client_ffi.gleam` (FFI isolation - per interop guideline)
- [x] Move @external from api.gleam to client_ffi.gleam
- [ ] Create `client_router.gleam` (routing + URL helpers) — NOTE: `router.gleam` already exists
- [ ] Reduce `scrumbringer_client.gleam` to entry wiring
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
- [ ] Update imports + docs + examples (original api.gleam kept for backwards compatibility)

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
