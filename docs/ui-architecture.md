# ScrumBringer Frontend Architecture Document

## Template and Framework Selection

### Starter Template / Existing Project Decision
**Decision:** Existing codebase refactor (no starter template).  
**Basis:** The Sprint 3 refactor architecture explicitly states this is an existing codebase refactor and that no starter template is used. The UI is already implemented using the Lustre client (TEA, target=JavaScript), and this frontend architecture must align with that existing structure.

### Framework & UI Language
**Framework:** **Lustre** (TEA architecture, Gleam target=JavaScript).  
**Language:** **Gleam 1.13** for client and server.  
**Rationale:** This is already established as the stack in the project brief and the Sprint 3 refactor checklist, and the frontend must stay consistent with the current Lustre TEA patterns.

### Constraints from Existing Codebase
- **Monorepo layout proposed:** `client/` and `api/` packages.  
- **Client structure:** `client/src/app`, `client/src/ui`, `client/src/pages`, `client/src/api`, `client/src/domain`.  
- **Strict module hygiene:** files ≤100 lines unless justified; `////` module docs and `///` public function docs with examples.  
- **TEA purity rule:** view is pure; effects originate in update.  
- **No type duplication:** client imports shared domain types, no local equivalents.

### Required References / Inputs
- **PRD**: `docs/brief.md` (UI/UX rules for pool, my bar, skills view, now working).  
- **Architecture**: `docs/sprint-3-refactor-checklist.md` (client stack, source tree, TEA constraints).  
- **UX**: none provided (note: we will encode UI/UX rules from PRD).

### Change Log

| Date | Version | Description | Author |
| --- | --- | --- | --- |
| 2026-01-17 | 1.0 | Initial frontend architecture | Winston |

---

## Frontend Tech Stack

### Technology Stack Table

| Category | Technology | Version | Purpose | Rationale |
| --- | --- | --- | --- | --- |
| Framework | Lustre | 5.5.2 | TEA-based UI architecture | Established in refactor checklist; required for current client code. |
| UI Library | Lustre UI primitives | 5.5.2 | Core UI rendering primitives | No separate UI library noted; rely on Lustre core for views. |
| State Management | TEA (Lustre) | 5.5.2 | Deterministic state transitions | Explicitly required: update owns effects, view is pure. |
| Routing | Existing client router (in repo) | In-repo | Page navigation | Inherit the current routing approach; do not introduce a new router without approval. |
| Build Tool | Gleam compiler + existing scripts | Gleam 1.13 | Build client target=JavaScript | Stack decision in brief + checklist; existing build scripts assumed. |
| Styling | Existing client styling (in repo) | In-repo | UI styling layer | Inherit current approach; avoid introducing new styling frameworks. |
| Testing | gleam test + make test | Existing | Validation gates | Checklist enforces these as required tests. |
| Component Library | None (custom) | N/A | Custom UI components | No external component lib referenced; project uses custom Lustre components. |
| Form Handling | Custom (Lustre forms) | N/A | Input handling | No form lib mentioned; keep minimal custom pattern. |
| Animation | Custom CSS/JS (minimal) | N/A | Decay/priority visual effects | PRD implies visual effects; no specific lib mentioned. |
| Dev Tools | Existing repo tooling | In-repo | Formatting/linting | Use current repo config; no new tools without approval. |

---

## Dependency Inventory & Update Policy

### Dependency Inventory

- **Frontend runtime/framework:** Use the versions already defined in the repo (Lustre + Gleam).  
- **UI helpers/components:** No new libraries unless explicitly approved; inherit current repo dependencies.  
- **Testing tools:** Use the existing `gleam test`/`make test` setup in the repo.  

### Update Policy (Inherited)

- **Source of truth:** Repo lockfiles/configs are authoritative for versions.  
- **Updates:** Only upgrade dependencies through existing project process; do not introduce new dependencies during refactor work.  
- **Security patches:** Apply only after confirming compatibility with the current repo baseline.  

---

## Project Structure

```text
client/
├── src/
│   ├── app/                          # TEA root
│   │   ├── model.gleam               # Global Model (aggregates feature models)
│   │   ├── update.gleam              # Top-level update, dispatches to feature updates
│   │   ├── view.gleam                # Pure root view (composes pages)
│   │   ├── messages.gleam            # Global Msg ADT (wraps feature Msg)
│   │   └── effects.gleam             # Effect runners; API calls only here
│   ├── features/                     # Domain feature modules (each owns Msg/update/view)
│   │   ├── pool/
│   │   │   ├── model.gleam
│   │   │   ├── messages.gleam
│   │   │   ├── update.gleam          # Dispatches effects via app/effects
│   │   │   └── view.gleam            # Pure view for Pool (available tasks only)
│   │   ├── my_bar/
│   │   │   ├── model.gleam
│   │   │   ├── messages.gleam
│   │   │   ├── update.gleam
│   │   │   └── view.gleam            # Ordered list: priority desc → status → created_at
│   │   ├── skills/
│   │   │   ├── model.gleam
│   │   │   ├── messages.gleam
│   │   │   ├── update.gleam
│   │   │   └── view.gleam            # Rows: label left, checkbox right
│   │   └── now_working/
│   │       ├── model.gleam
│   │       ├── messages.gleam
│   │       ├── update.gleam
│   │       └── view.gleam            # List + per-task timer (start/pause/complete/release)
│   ├── pages/                        # Composition only (no logic)
│   │   ├── pool_page.gleam
│   │   ├── my_bar_page.gleam
│   │   ├── skills_page.gleam
│   │   └── now_working_page.gleam
│   ├── ui/                           # Reusable pure UI components
│   │   ├── task_card.gleam
│   │   ├── task_list.gleam
│   │   ├── skill_row.gleam
│   │   ├── action_buttons.gleam
│   │   └── layout.gleam
│   ├── api/                          # Typed API boundary definitions
│   │   ├── tasks_api.gleam
│   │   ├── skills_api.gleam
│   │   ├── now_working_api.gleam
│   │   └── auth_api.gleam
│   ├── domain/                       # Re-export shared domain types (no duplication)
│   └── routes/                       # Routing config (if used)
├── gleam.toml
└── test/                             # Client tests (location TBD)
```

---

## Component Standards

### Component Template

```gleam
//// TaskCard component: renders a task with actions and drag handle
//// Usage: task_card(task, actions)

import lustre/element.{Element, div, button, text}
import lustre/attribute.{class}
import client/domain/task.{Task}
import client/ui/action_buttons.{action_buttons}

pub fn task_card(task: Task, on_action: ActionHandler) -> Element {
  div([class("task-card")], [
    div([class("task-title")], [text(task.title)]),
    action_buttons(task, on_action),
    div([class("drag-handle")], [text("⋮⋮")]),
  ])
}
```

**Notes:**
- All UI components are **pure** (no effects, no API calls).
- Every module must include `////` module docs and `///` docs for public functions with examples.
- Keep files **≤100 lines** unless explicitly justified.

### Naming Conventions

- **Modules (files):** `snake_case.gleam` (e.g., `task_card.gleam`, `my_bar_page.gleam`)  
- **Feature modules:** `client/features/<feature>/model|messages|update|view.gleam`  
- **Components:** Functions named in `snake_case` (e.g., `task_card`, `skill_row`)  
- **Messages:** `Msg` ADT per feature; global `AppMsg` (or similar) wraps feature messages  
- **Actions/Commands:** `*_action` or `*_cmd` suffix for intent clarity  
- **Domain imports:** Always from `client/domain/*` (re-exported from shared) — no local duplication

---

## State Management

### Store Structure

```text
client/src/
├── app/
│   ├── model.gleam        # AppModel (aggregates feature models)
│   ├── messages.gleam     # AppMsg (wraps feature Msg)
│   ├── update.gleam       # dispatches feature updates
│   └── effects.gleam      # command/effect handling + API calls
└── features/
    ├── pool/
    │   ├── model.gleam
    │   ├── messages.gleam
    │   ├── update.gleam
    │   └── view.gleam
    ├── my_bar/
    │   ├── model.gleam
    │   ├── messages.gleam
    │   ├── update.gleam
    │   └── view.gleam
    ├── skills/
    │   ├── model.gleam
    │   ├── messages.gleam
    │   ├── update.gleam
    │   └── view.gleam
    └── now_working/
        ├── model.gleam
        ├── messages.gleam
        ├── update.gleam
        └── view.gleam
```

### State Management Template

```gleam
//// Feature update pattern: pure update + effects delegated to app/effects

import client/app/messages.{AppMsg}
import client/features/pool/messages.{PoolMsg}
import client/features/pool/model.{PoolModel}
import client/app/effects.{Effect, none, fetch_pool}

pub fn update(msg: PoolMsg, model: PoolModel) -> #(PoolModel, Effect) {
  case msg {
    PoolMsg.LoadRequested -> #(model, fetch_pool())
    PoolMsg.TasksLoaded(tasks) -> #(PoolModel(..model, tasks: tasks), none())
    PoolMsg.ClaimRequested(task_id) -> #(model, fetch_pool_claim(task_id))
  }
}

/// App update dispatches feature updates
pub fn app_update(msg: AppMsg, model: AppModel) -> #(AppModel, Effect) {
  case msg {
    AppMsg.Pool(pool_msg) -> {
      let #(pool_model, effect) = pool_update(pool_msg, model.pool)
      #(AppModel(..model, pool: pool_model), effect)
    }
    // ... other features
  }
}
```

---

## API Integration

### Service Template

```gleam
//// tasks_api: typed client boundary for task operations
//// Canonical types live in shared/domain; client/domain re-exports ONLY.

import client/domain/task.{Task, TaskId}
import client/domain/api_result.{ApiResult, ApiError}
import client/api/decoders.{decode_task, decode_tasks}
import client/app/effects.{Effect, http_get, http_post}

pub fn fetch_available_tasks() -> Effect {
  http_get("/api/tasks?status=available", decode: decode_tasks)
}

pub fn claim_task(task_id: TaskId) -> Effect {
  http_post("/api/tasks/claim", json: task_id, decode: decode_task)
}

pub fn release_task(task_id: TaskId) -> Effect {
  http_post("/api/tasks/release", json: task_id, decode: decode_task)
}

pub fn complete_task(task_id: TaskId) -> Effect {
  http_post("/api/tasks/complete", json: task_id, decode: decode_task)
}
```

### API Client Configuration

```gleam
//// Centralized HTTP client config (cookies + error handling)

import client/domain/api_result.{ApiResult, ApiError}
import client/app/effects.{HttpConfig, http_config}

pub fn api_config() -> HttpConfig {
  http_config(
    base_url: "/api",
    include_cookies: True,  // JWT cookie auth per brief
    timeout_ms: 8000
  )
}

/// Map HTTP errors to ApiError ADT
pub fn map_error(status: Int, body: String) -> ApiError {
  case status {
    401 -> ApiError.Unauthorized
    403 -> ApiError.Forbidden
    404 -> ApiError.NotFound
    _ -> ApiError.Unexpected(body)
  }
}
```

### Decoder / Mapper Note (Required)

```gleam
//// decoders.gleam
//// JSON → shared domain ADT mappers (explicit, no ad-hoc records)

import shared/domain/task.{Task, TaskId}
import client/domain/api_result.{ApiResult, ApiError}

pub fn decode_task(json: Json) -> ApiResult(Task) {
  // explicit mapping with validation, returns ApiResult
}
```

---

## Frontend TEA Flow Diagram

```mermaid
graph TD
  U[User] -->|Action| V[View (Pure)]
  V -->|Msg| UPT[Update]
  UPT -->|Cmd/Effect| FX[Effects/API]
  FX -->|Response| UPT
  UPT -->|Model| V
```

---

## Routing

### Route Configuration

```gleam
//// routes.gleam
//// Minimal route config for page composition; no side effects here.
//// Inherit the router already used in the client repo.

type Route {
  Pool
  MyBar
  Skills
  NowWorking
  Login
}

pub fn parse_route(path: String) -> Route {
  case path {
    "/pool" -> Pool
    "/my-bar" -> MyBar
    "/skills" -> Skills
    "/now-working" -> NowWorking
    "/login" -> Login
    _ -> Pool
  }
}

pub fn view_route(route: Route, model: AppModel) -> Element {
  case route {
    Pool -> pool_page.view(model)
    MyBar -> my_bar_page.view(model)
    Skills -> skills_page.view(model)
    NowWorking -> now_working_page.view(model)
    Login -> login_page.view(model)
  }
}
```

**Protected Route Pattern (Auth Guard)**

```gleam
//// auth_guard.gleam (composition-only)
pub fn require_auth(session: Session, view: Element) -> Element {
  case session.is_authenticated {
    True -> view
    False -> login_page.view()
  }
}
```

**Routing Tooling Rule**
- Use the router already present in the client repo.
- Do not introduce a new routing dependency without explicit approval.

---

## Client-Side Security Posture

### UI Security Rules

- **XSS Prevention:** Never render untrusted HTML. All user-generated content (e.g., task notes) must be rendered as text.  
- **CSRF Awareness:** Rely on same-site cookie strategy from backend; client must not expose or manipulate tokens directly.  
- **Safe Errors:** Map server errors to user-safe messages; never render raw error bodies.  
- **Input Validation:** Validate inputs on the client for UX only; server remains the source of truth.  

---

## Styling Guidelines

### Styling Approach

**Approach:** Minimal custom CSS (or Lustre inline styles) consistent with the existing codebase.  
**Rationale:** No styling framework is specified in the PRD or refactor checklist, so we avoid introducing Tailwind or CSS‑in‑JS without explicit approval. Keep styling lightweight, explicit, and aligned with Lustre component structure.

**Tooling Rule:**
- Inherit the **current styling approach in the repo**.
- Do not add new styling frameworks or preprocessors without explicit approval.

**Core rules:**
- Styles must not violate TEA purity (no DOM mutation outside view render).  
- Pool cards must always expose action affordances and drag handle, even at smallest size.  
- My Bar is a **static ordered list** (not floating or draggable by default).  
- My Skills uses **row layout**: label left, checkbox right.  
- Now Working requires a **list + per‑task timer**; mobile hides Pool and shows My Bar + Now Working only.  

### Global Theme Variables

```css
:root {
  /* Colors */
  --color-bg: #0f1115;
  --color-surface: #1a1e26;
  --color-text: #e6e9ef;
  --color-muted: #a0a4ab;
  --color-primary: #5cc8ff;
  --color-accent: #9b59ff;
  --color-success: #4cd964;
  --color-warning: #f5a623;
  --color-danger: #ff5c5c;

  /* Spacing */
  --space-xs: 4px;
  --space-sm: 8px;
  --space-md: 12px;
  --space-lg: 16px;
  --space-xl: 24px;

  /* Typography */
  --font-family: "Inter", system-ui, sans-serif;
  --font-size-sm: 12px;
  --font-size-md: 14px;
  --font-size-lg: 18px;
  --font-weight-regular: 400;
  --font-weight-medium: 500;
  --font-weight-bold: 700;

  /* Shadows */
  --shadow-sm: 0 1px 2px rgba(0,0,0,0.2);
  --shadow-md: 0 4px 12px rgba(0,0,0,0.25);

  /* Dark Mode */
  --color-bg-dark: #0f1115;
  --color-surface-dark: #1a1e26;
  --color-text-dark: #e6e9ef;
}
```

---

## Frontend Performance Strategy

### Large Pool Rendering

- **Virtualize long lists** of pool cards when task count is high.  
- **Batch updates** to avoid frequent re-renders during drag/decay updates.  
- **Avoid layout thrash:** Prefer fixed card sizes for priority tiers to reduce reflow.  

### Timer Updates (Now Working)

- **Throttle timer renders** to once per second (or coarser) to avoid excessive re-renders.  
- **Isolate timer updates** to the Now Working list to prevent global model churn.  

---

## Frontend Observability (Minimal)

- **Logging:** Log client errors and failed optimistic actions to console (or existing repo logging hook).  
- **Metrics (lightweight):** Track counts of failed claims/releases/completes and retry attempts.  
- **Privacy:** Never log PII, tokens, or raw error payloads.  

---

## Resilience & Error Handling (Frontend)

### Optimistic UI Failure Handling

- **Rollback:** If an optimistic action fails (claim/release/complete/start/pause), the feature update must revert the local model to the last known server‑confirmed state.  
- **Retry:** For transient failures, allow a single automatic retry; on repeated failure, surface a user‑visible error.  
- **Error Banner/Toast:** Provide a consistent, non‑blocking error banner/toast indicating the action failed and whether it was retried.  
- **Conflict Handling:** If the server rejects due to version conflict, reload the affected entity and reapply local ordering rules (e.g., My Bar ordering).  

### Error Surface Rules

- Never expose raw server errors. Map to user‑safe messages.  
- Auth errors (401/403) should route to login or show an auth error banner.  
- Keep errors within the feature boundary; global banner only for cross‑feature failures.

---

## Testing Requirements

### Component Test Template

```gleam
//// task_card_test.gleam
//// Basic component rendering + interaction tests (pure view)

import client/ui/task_card.{task_card}
import client/domain/task.{Task, TaskId}
import gleam/test.{test, assert}

test "task_card renders title and actions" {
  let task = Task(id: TaskId("t1"), title: "Refactor pool", ...)
  let view = task_card(task, noop_action)

  assert render_contains(view, "Refactor pool")
  assert render_contains(view, "Claim")
  assert render_contains(view, "⋮⋮") // drag handle visible
}
```

### Testing Best Practices

1. **Unit Tests:** Test feature update functions (pure logic) in `features/*/update.gleam`.  
2. **Integration Tests:** Validate API boundary decoding + effects wiring (e.g., decode JSON → domain ADTs).  
3. **E2E Tests:** Critical flows: claim → start → pause → complete.  
4. **Coverage Goals:** Prioritize critical path + domain invariants; avoid arbitrary % targets unless required.  
5. **Test Structure:** Arrange–Act–Assert.  
6. **Mock External Dependencies:** API calls, routing, timers.  
7. **Accessibility Tests:** Include keyboard navigation and ARIA label checks for critical flows.  

---

## Environment Configuration

### Server-Side (BEAM / API)

**Runtime Environment via `envoy`**  
- All server configuration is provided through `envoy` (BEAM runtime).  
- Variables include auth, DB, and API settings; no secrets in client.

### Client-Side (Lustre)

**No direct environment variables in client.**  
Client configuration is injected at build time or via a global config object:

```js
// index.html or bootstrap script
window.__SCRUMBRINGER_CONFIG__ = {
  apiBaseUrl: "/api",
  authCookieName: "sb_jwt",
  featureNowWorking: true,
  poolDecayDays: 7
}
```

**Client access pattern (Gleam pseudo):**

```gleam
//// config.gleam
pub fn get_config() -> Config {
  // Read from window.__SCRUMBRINGER_CONFIG__
}
```

---

## Accessibility Standards

### Accessibility Requirements (WCAG AA)

- **WCAG Target:** WCAG 2.1 AA for all user‑facing UI.  
- **Keyboard Navigation:** All interactive controls (claim/release/complete/start/pause, drag handles) must be reachable and operable via keyboard.  
- **ARIA Labels:** Provide ARIA labels for icon‑only buttons and drag handles.  
- **Focus Management:** Maintain visible focus styles; ensure focus order follows visual order.  
- **Screen Reader Support:** Provide text equivalents for status indicators and timers.  

### ARIA Examples

```html
<button aria-label="Claim task">+</button>
<div role="status" aria-live="polite">Task claimed</div>
```

**Focus Example**

```css
:focus-visible { outline: 2px solid var(--color-primary); }
```

### Accessibility Testing

- **Manual:** Keyboard‑only walkthrough for Pool, My Bar, Skills, Now Working.  
- **Automated:** Run a11y checks as part of UI testing (tool choice inherits current repo tooling).  
- **Regression:** Verify focus order and ARIA labels in critical flows.  

---

## Frontend Developer Standards

### Critical Coding Rules

1. **TEA purity is non‑negotiable:** `view` must remain pure; all side effects originate in `update` and are executed via `app/effects`.  
2. **No type duplication outside shared domain:** Client must import domain ADTs from `shared/domain` (via `client/domain` re‑exports).  
3. **Feature isolation:** Each feature (`pool`, `my_bar`, `skills`, `now_working`) owns its `model/messages/update/view` modules.  
4. **API calls only in effects:** No HTTP calls in views/components/pages.  
5. **Explicit JSON mapping:** All API responses must be decoded into domain ADTs via explicit mappers (no ad‑hoc records).  
6. **Module hygiene enforced:** Files must be ≤100 lines unless explicitly justified in module docs.  
7. **Documentation required:** Every module must include `////` docs; every public function must include `///` docs with examples.  
8. **UI rules from PRD must be enforced:**  
   - Pool shows **only** `available` tasks.  
   - My Bar is a **static ordered list** (priority desc → status → created_at).  
   - My Skills uses **row layout** (label left, checkbox right).  
   - Pool cards always show actions + drag handle.  
   - Now Working supports multiple simultaneous tasks with timers; mobile hides Pool.  
9. **Auth boundaries enforced:** Only claimers can edit/complete; never expose any “assignee” field or UI affordance.  

### Quick Reference

**Common Commands**
- `gleam test` — run Gleam tests (required)  
- `make test` — full test gate (required)  
- `gleam format` — format Gleam code (if configured)  

**Key Import Patterns**
- `client/domain/*` for shared ADTs (re‑export only)  
- `client/app/effects` for API calls and commands  
- `client/features/<feature>/*` for feature models and updates  

**File Naming Conventions**
- Modules: `snake_case.gleam`  
- Feature modules: `client/features/<feature>/{model,messages,update,view}.gleam`  
- Pages: `client/pages/<feature>_page.gleam`  
- UI components: `client/ui/<component>.gleam`  

**Project-Specific Patterns**
- Global dispatch via `app/update` wrapping feature messages.  
- Views are pure; effects are centralized in `app/effects`.  
- Explicit JSON → ADT decoding in `client/api/decoders`.  
- Pool/My Bar/Skills/Now Working rules from PRD are mandatory UX constraints.
