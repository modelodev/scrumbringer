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
- [ ] Create `client_state.gleam` (Model/Msg/state types + docs)
- [ ] Create `client_update.gleam` (update + helpers; reduce nested cases)
- [ ] Create `client_view.gleam` (view + subviews; split >100‑line functions)
- [ ] Create `client_effects.gleam` (effect helpers)
- [ ] Create `client_router.gleam` (routing + URL helpers)
- [ ] Reduce `scrumbringer_client.gleam` to entry wiring
- [ ] Add module/type/function docs for all new modules

### Client: Split `api.gleam`
- [ ] `api/core.gleam` (request + error decoding)
- [ ] `api/auth.gleam`
- [ ] `api/projects.gleam`
- [ ] `api/tasks.gleam`
- [ ] `api/metrics.gleam`
- [ ] `api/org.gleam`
- [ ] Update imports + docs + examples

### Server: `http/tasks.gleam`
- [ ] `validators.gleam` (task input validation)
- [ ] `presenters.gleam` (task JSON builders)
- [ ] `filters.gleam` (filter parsing)
- [ ] Refactor handlers to ≤100 lines; no >2 nested cases
- [ ] Add module/type/function docs

---

## Verification (DoD)
- [ ] `make test` passes
- [ ] `gleam test` passes
- [ ] Hygiene rules verified
- [ ] Docs updated for all touched modules
