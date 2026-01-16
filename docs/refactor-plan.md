# Refactor Plan (Two Phases)

## Goals
- Enforce hygiene constraints across Gleam modules before continuing feature development.
- Adopt Gleam best practices using TDD, strong types, interop isolation, and actor model patterns.
- Standardize module and API documentation (English, concise, mandatory updates on change).

## Constraints (Non‑Negotiable)
- Functions must be **≤ 100 lines**, unless a clear justification is documented.
- **No 3 nested `case`**; **2 nested `case` only with justification** in function doc comment.

## Documentation Conventions (Gleam)
- `////` module doc at top of each module:
  - Mission
  - Responsibilities
  - Non‑responsibilities
  - Relations to other modules (types + methods)
- `///` for every **public type** and **public function**:
  - Purpose (concise)
  - Example usage for functions
- `//` for normal comments
- English only
- Update docs whenever refactor changes purpose or behavior

---

## Phase 1 — Aggressive Hygiene + Skill‑Driven Refactor
**Guided by skills**: `gleam-tdd-development`, `gleam-type-system`, `gleam-interop`, `gleam-actor-model`

### 1. Baseline Scan (no code changes)
- Identify functions >100 lines and nested `case` depth >2.
- Produce refactor backlog per module (client + server).

### 2. TDD Guardrails (gleam‑tdd‑development)
- Add/strengthen tests *before* extraction or logic change.
- Each refactorable flow gets at least one regression test.

### 3. Type‑System Corrections (gleam‑type‑system)
- Replace tuple chains with named types/records.
- Replace nested `case` in decode/flow logic with explicit ADTs or `Result`/`Option` helpers.

### 4. Interop Isolation (gleam‑interop)
- Extract FFI boundary functions into dedicated modules.
- Prohibit nested `case` in FFI wrappers; keep wrappers flat.

### 5. Actor‑Model Segmentation (gleam‑actor‑model)
- Extract stateful flows into actor‑style modules (state + message ADTs).
- Reduce `case` nesting by message dispatch/handlers.

### 6. Documentation Sweep (mandatory)
- Add module docs to all touched modules.
- Add public type/function docs with examples.
- Add justifications for any exceptions (line length or nested case).

**Phase 1 Exit Gate**
- ✅ All touched functions ≤100 lines or justified
- ✅ No >2 nested cases
- ✅ Docs updated (module + public API)
- ✅ Tests green (`make test`, `gleam test`)

---

## Phase 2 — Structural Decomposition + Consistency Pass

### 1. Module Decomposition
- Split mega‑modules into focused domains:
  - Client: `state`, `update`, `view`, `effects`, `routing`
  - Server: `handlers`, `services`, `db`, `actors`

### 2. Workflow Modules
- Extract workflows (e.g. “task mutations”, “now working”) into dedicated modules with clear contracts.

### 3. Strict Hygiene Enforcement
- CI checklist: function length, nesting, documentation
- Stop‑the‑line if violations found

### 4. Documentation Audit
- Full sweep of public API docs
- Ensure module relationships and responsibilities are explicit

**Phase 2 Exit Gate**
- ✅ All modules aligned to new structure
- ✅ No hygiene violations in touched code
- ✅ All public types/functions documented
- ✅ Tests green

---

## Verification Checklist (both phases)
- `make test`
- `gleam test`
- Manual review: function size + nested case depth
- Docs review: module + public API

## Supporting Backlog (Residual)
- `docs/refactor-backlog.md`
- Note: this backlog is **temporary** and must be removed once the refactor plan is fully executed and sprint work resumes.

## Sprint Checklists
- `docs/sprint-1-refactor-checklist.md`
- `docs/sprint-2-refactor-checklist.md`

---

## Risks & Mitigation
| Risk | Mitigation |
|------|------------|
| Regression from refactor | TDD guardrails + diff‑scoped tests |
| Documentation drift | Required doc update per change |
| Scope explosion | Strict phase boundaries + backlog |

---

# Appendix A — Client Refactor Actions
1. Split `scrumbringer_client.gleam` into `client_state`, `client_update`, `client_view`, `client_effects`, `client_router`.
2. Extract view helpers >100 lines into dedicated view modules.
3. Replace nested `case` in update flows with helper functions or ADTs.
4. Isolate FFI functions in `client/interop` module(s) with flat logic.
5. Add module docs + public API docs for all extracted modules.

# Appendix B — Server Refactor Actions
1. Split HTTP handlers (`http/*.gleam`) into `handlers` + `presenters` (JSON builders) + `validators`.
2. Extract workflow‑state modules (Now Working, Task Mutations) into actor‑style modules with message ADTs.
3. Reduce nested `case` in request parsing/validation with helper modules.
4. Isolate SQL adapters and map rows via typed record helpers.
5. Add module docs + public type/function docs in all touched modules.

# Appendix C — Global Refactor Target Scan (Priority List)
## Client (highest priority first)
1. `apps/client/src/scrumbringer_client.gleam`
   - Monolithic module with oversized `update/2`, `init/1`, `hydrate_model/1` and deeply nested cases.
   - Split into `state/update/view/effects/router` modules and extract workflows.
2. `apps/client/src/scrumbringer_client/api.gleam`
   - Large decoder/request surface (~1.6k LOC). Split by domain (auth/projects/tasks/metrics/org).
3. `apps/client/src/scrumbringer_client/router.gleam`
   - Centralized parsing/formatting logic feeding nested cases in main module.

## Server (highest priority first)
1. `apps/server/src/scrumbringer_server/http/tasks.gleam`
   - Deeply nested handler logic; split validation/decoding/response shaping.
2. `apps/server/src/scrumbringer_server/services/tasks_db.gleam`
   - Dense DB operations; split by query vs mutation; prepare for actor workflow orchestration.
3. `apps/server/src/scrumbringer_server/http/org_metrics.gleam`
   - Response shaping + metrics logic intertwined; extract service layer.
4. `apps/server/src/scrumbringer_server/sql.gleam`
   - Very large generated module; refactor via generator/wrappers, not manual edits.
