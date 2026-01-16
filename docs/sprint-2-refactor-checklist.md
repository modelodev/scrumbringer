# Sprint 2 Refactor Checklist (Executable)

## Scope
- Client workflows
- Server actor workflows
- Metrics extraction
- Global hygiene/doc audit

## Hygiene Rules (mandatory)
- Functions ≤ 100 lines (justify exceptions in `///` doc)
- No 3 nested `case`; 2 nested allowed with justification
- `////` module docs at top of each touched module
- `///` for every public type/function + usage example
- English docs only

---

## Checklist
### Client: Workflow Modules
- [ ] Create `client_workflows/now_working.gleam` (state + messages + handlers)
- [ ] Create `client_workflows/tasks.gleam`
- [ ] Create `client_workflows/i18n.gleam`
- [ ] Update `client_update.gleam` to delegate workflows
- [ ] Add module/type/function docs

### Server: Actor Workflow Modules
- [ ] Create `services/task_workflow_actor.gleam` (message ADTs + handler)
- [ ] Create `services/now_working_actor.gleam`
- [ ] Update `http/tasks.gleam` + `http/me_active_task.gleam` to delegate
- [ ] Add module/type/function docs

### Server: Metrics Separation
- [ ] Create `metrics_service.gleam`
- [ ] Create `metrics_presenters.gleam`
- [ ] Update `http/org_metrics.gleam` to use service/presenters

### Global Hygiene + Docs Audit
- [ ] Audit touched modules for nested cases + line length
- [ ] Ensure module docs and public API docs are complete
- [ ] Update docs when behavior/purpose changed

---

## Verification (DoD)
- [ ] `make test` passes
- [ ] `gleam test` passes
- [ ] Hygiene rules verified
- [ ] Docs updated for all touched modules
