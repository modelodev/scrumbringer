# Testing Architecture: Typed BDD

> **Version:** 1.1
> **Status:** ADR Accepted (Revised)
> **Parent:** [Architecture](../architecture.md)

---

## Executive Summary

This document defines a **type-safe BDD testing architecture** for Gleam/Lustre applications. Instead of traditional Gherkin files (string-based), we use **Algebraic Data Types (ADTs)** to describe test specifications. A router automatically selects the appropriate backend (in-memory simulation or real browser) based on inferred capabilities.

### Key Decisions

| Decision | Rationale |
|----------|-----------|
| ADTs over strings | Type safety, refactoring support, IDE completion |
| Semantic `Target` types | Decouple specs from CSS selectors |
| Auto-inferred capabilities | Reduce human error in backend selection |
| `And` as presentation, not data | Cleaner model, derived for docs |
| Refs with phantom types + `run_id` | Real parallel test isolation |
| TestId as contract (not CSS) | Both backends resolve identically |
| Stdio JSON Protocol (typed commands) | Safe evolution, no stringly-typed args |
| Fixtures are channel-agnostic | Same spec can run in-memory or via API |

---

## Table of Contents

1. [Context and Problem](#1-context-and-problem)
2. [Architecture Overview](#2-architecture-overview)
3. [Layer 1: Domain Types (DSL)](#3-layer-1-domain-types-dsl)
4. [Layer 2: Spec Structure](#4-layer-2-spec-structure)
5. [Layer 3: Backends](#5-layer-3-backends)
6. [Layer 4: Execution Router](#6-layer-4-execution-router)
7. [Layer 5: Results and Reporting](#7-layer-5-results-and-reporting)
8. [Living Documentation](#8-living-documentation)
9. [Security Considerations](#9-security-considerations)
10. [Implementation Roadmap](#10-implementation-roadmap)
11. [Appendix: Full Type Definitions](#11-appendix-full-type-definitions)

---

## 1. Context and Problem

### 1.1 Why Not Traditional Gherkin?

Traditional BDD with Cucumber/Gherkin has known pain points at scale:

| Problem | Impact |
|---------|--------|
| String-based steps | Typos, duplication, no refactoring support |
| Regex step matching | Fragile, hard to discover available steps |
| No type checking | Runtime failures instead of compile-time |
| Manual backend selection | Forgetting `@browser` tag causes cryptic failures |
| Parallel test collisions | Hardcoded IDs like `"task-1"` cause flaky tests |

### 1.2 Why Not Pure Unit Tests?

Pure unit tests with `lustre/dev/simulate` are fast but limited:

- Cannot test real network effects (HTTP, WebSocket)
- Cannot test browser-specific behavior (drag-drop, localStorage)
- Cannot test CSS rendering or responsive layouts
- Cannot verify actual user experience
- **Effects are discarded** - simulate only tests MVU logic + view rendering

### 1.3 Our Solution: Typed BDD with Dual Backends

We need **both** fast unit-level tests and real E2E tests, unified under a single specification language that:

1. Is **type-safe** (compile-time verification)
2. Is **semantic** (describes intent, not implementation)
3. **Auto-selects** the appropriate backend
4. Supports **parallel execution** without collisions via `run_id` namespacing
5. Generates **living documentation**

---

## 2. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         LAYER 1: DOMAIN DSL                         │
│  ┌─────────┐ ┌─────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐ │
│  │ Ref(a)  │ │ Route   │ │  Target   │ │  Action   │ │Expectation│ │
│  │ +key()  │ │ typed   │ │ by domain │ │serializable│ │ ADT pure  │ │
│  └─────────┘ └─────────┘ └───────────┘ └───────────┘ └───────────┘ │
│                    ↓                                                │
│              TestContext(run_id) + materialize()                    │
└─────────────────────────────────────────────────────────────────────┘
                                 ↓
┌─────────────────────────────────────────────────────────────────────┐
│                      LAYER 2: SPEC STRUCTURE                        │
│  ┌────────────────────────────────────────────────────────────────┐│
│  │ Spec {                                                         ││
│  │   id, name, feature, tags,                                     ││
│  │   arrange: List(Fixture),  // Setup (channel-agnostic)         ││
│  │   steps: List(Step)        // Given/When/Then only             ││
│  │ }                                                              ││
│  │ + infer_capabilities() → List(Capability)                      ││
│  └────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────┘
                                 ↓
┌─────────────────────────────────────────────────────────────────────┐
│                      LAYER 3: EXECUTION ROUTER                      │
│                                                                     │
│   infer_capabilities(spec)                                          │
│     ├── [SimulateOnly] + [NeedsBrowser|Network|Storage|Clock]       │
│     │   → Conflict Error                                            │
│     ├── [] (empty) → Simulate Backend                               │
│     └── [NeedsBrowser|NeedsRealStorage|...] → Playwright Backend    │
└─────────────────────────────────────────────────────────────────────┘
                    ↓                              ↓
┌────────────────────────────────────────┐  ┌────────────────────────────────┐
│     BACKEND: SIMULATE                  │  │     BACKEND: PLAYWRIGHT        │
│  ──────────────────────────            │  │  ────────────────────────────  │
│  resolve: Target → query.test_id()     │  │  resolve: Target → test_id     │
│  exec: fold over steps (threaded sim)  │  │  encode: Command ADT → JSON    │
│  assert: model + view checks           │  │  + protocol_version            │
│  effects: DISCARDED (inject via msg)   │  │  + RunConfig                   │
│                                        │  │                                │
│  Fixtures: Build Model in-memory       │  │    ↓ Stdio JSON Protocol       │
│  (FixtureChannel.InMemory)             │  │  ┌────────────────────────┐   │
│                                        │  │  │ runner.js (Node)       │   │
│                                        │  │  │ - validates version    │   │
│                                        │  │  │ - getByTestId()        │   │
│                                        │  │  │ - attachments on fail  │   │
│                                        │  │  └────────────────────────┘   │
│                                        │  │  Fixtures: POST /api/test/fix │
│                                        │  │  (FixtureChannel.ViaApi)      │
└────────────────────────────────────────┘  └────────────────────────────────┘
                    ↓                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│                      LAYER 4: UNIFIED REPORTING                     │
│  ┌──────────┐  ┌──────────┐  ┌─────────────┐  ┌─────────────────┐  │
│  │ Console  │  │ JSON     │  │ Living Docs │  │ Attachments     │  │
│  │ progress │  │ for CI   │  │ Markdown    │  │ only on failure │  │
│  └──────────┘  └──────────┘  └─────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 3. Layer 1: Domain Types (DSL)

### 3.1 Typed References (Phantom Types) + Materialization

Refs are **opaque** to prevent accidental access. Use `key()` getter and `materialize()` with `run_id` for parallel isolation:

```gleam
// specs/domain/refs.gleam

/// Phantom-typed references for test isolation
/// OPAQUE: use key() to access the name
pub opaque type Ref(phantom) {
  Ref(name: String)
}

pub type TaskRef = Ref(Task)
pub type UserRef = Ref(User)
pub type ProjectRef = Ref(Project)
pub type CapabilityRef = Ref(Capability)
pub type TaskTypeRef = Ref(TaskType)

// Constructors
pub fn task(name: String) -> TaskRef { Ref(name) }
pub fn user(name: String) -> UserRef { Ref(name) }
pub fn project(name: String) -> ProjectRef { Ref(name) }
pub fn capability(name: String) -> CapabilityRef { Ref(name) }
pub fn task_type(name: String) -> TaskTypeRef { Ref(name) }

/// Get the symbolic name (for docs, debugging)
pub fn key(ref: Ref(a)) -> String {
  let Ref(name) = ref
  name
}
```

```gleam
// specs/domain/context.gleam

/// Test execution context - provides run_id for isolation
pub type TestContext {
  TestContext(run_id: String)
}

/// Materialize a ref to a unique ID for this test run
/// This is what gets used in data-test-id and fixture creation
pub fn materialize(ctx: TestContext, ref: Ref(a)) -> String {
  ctx.run_id <> "-" <> refs.key(ref)
}

/// Generate a unique run_id (call once per test suite execution)
pub fn new_context() -> TestContext {
  let id = generate_uuid_v4()  // or timestamp-based
  TestContext(run_id: id)
}
```

**Why this matters:** Two parallel CI runs using `task("task-1")` will create `abc123-task-1` and `def456-task-1`, avoiding collisions.

### 3.2 Typed Routes

Never use raw strings for navigation:

```gleam
// specs/domain/routes.gleam

pub type Route {
  // Auth routes
  Login
  ForgotPassword
  AcceptInvite(token: String)
  ResetPassword(token: String)

  // App routes
  Pool
  PoolWithProject(ProjectRef)
  TaskDetails(TaskRef)

  // Admin routes
  AdminSection(AdminSection)
}

pub type AdminSection {
  Invites
  Projects
  Members
  Capabilities
  TaskTypes
  Cards
  Workflows
  Rules
}

/// Convert route to path string (for navigation)
pub fn to_path(ctx: TestContext, route: Route) -> String {
  case route {
    Login -> "/"
    ForgotPassword -> "/forgot-password"
    AcceptInvite(token) -> "/accept-invite?token=" <> token
    ResetPassword(token) -> "/reset-password?token=" <> token
    Pool -> "/app/pool"
    PoolWithProject(ref) -> "/app/pool?project=" <> materialize(ctx, ref)
    TaskDetails(ref) -> "/app/task/" <> materialize(ctx, ref)
    AdminSection(section) -> "/app/admin/" <> section_to_path(section)
  }
}
```

### 3.3 Semantic Targets (Organized by Domain)

**Critical decision:** Targets are semantic UI elements, NOT CSS selectors.

```gleam
// specs/domain/targets.gleam

/// Top-level target organized by domain to avoid "god enum"
pub type Target {
  Auth(AuthTarget)
  Pool(PoolTarget)
  Admin(AdminTarget)
  Common(CommonTarget)
}

pub type AuthTarget {
  EmailInput
  PasswordInput
  PasswordConfirmInput
  SubmitButton
  ForgotPasswordLink
  ErrorMessage
}

pub type PoolTarget {
  TaskCard(TaskRef)
  ClaimButton(TaskRef)
  ReleaseButton(TaskRef)
  CompleteButton(TaskRef)
  StartWorkButton(TaskRef)
  MyTasksDropzone
  MyTasksSection
  FilterStatus(TaskStatus)
  FilterType(TaskTypeRef)
  FilterCapability(CapabilityRef)
  ViewModeToggle(ViewMode)
  CreateTaskButton
  CreateTaskDialog
  SearchInput
  TaskDetailsPanel
  NotesSection
  NoteInput
}

pub type AdminTarget {
  SectionTab(AdminSection)
  CreateButton
  EditButton(id: String)
  DeleteButton(id: String)
  SaveButton
  CancelButton
  DataTable
  DataRow(id: String)
}

pub type CommonTarget {
  Toast
  ToastMessage
  NavMenu
  Sidebar
  MobileDrawer
  HamburgerMenu
  ThemeSelector
  LocaleSelector
  UserMenu
  LogoutButton
  LoadingSpinner
  ErrorBoundary
}
```

### 3.4 Locator Composition (Correct Semantics)

Handle multiple instances and nesting with **explicit semantics**:

```gleam
// specs/domain/locators.gleam

pub type Locator {
  /// Single target
  One(Target)

  /// Direct child (CSS: parent > child)
  Child(parent: Locator, child: Locator)

  /// Any descendant (CSS: parent child)
  Descendant(parent: Locator, child: Locator)

  /// Nth occurrence of matches (0-indexed)
  /// NOT :nth-child - this is "nth match of this locator"
  Nth(locator: Locator, index: Int)
}

// Builder helpers
pub fn the(target: Target) -> Locator {
  One(target)
}

pub fn child_of(parent: Locator, child: Target) -> Locator {
  Child(parent, One(child))
}

pub fn within(parent: Locator, child: Target) -> Locator {
  Descendant(parent, One(child))
}

pub fn nth(locator: Locator, index: Int) -> Locator {
  Nth(locator, index)
}
```

**Example usage:**
```gleam
// Click the claim button inside task-1's card (descendant)
Click(within(the(Pool(TaskCard(task_1))), Pool(ClaimButton(task_1))))

// Click the second toast notification (nth match, not nth-child)
Click(nth(the(Common(Toast)), 1))

// First direct child button of a dialog
Click(child_of(the(Pool(CreateTaskDialog)), Common(SubmitButton)))
```

### 3.5 Actions (Serializable, with Actor support)

All actions must be **data-only** (no closures). Optional `Actor` for multi-user scenarios:

```gleam
// specs/domain/actions.gleam

/// Actor identity for multi-user tests
pub type Actor {
  Actor(name: String)
}

pub type Action {
  // Navigation
  Navigate(Route)

  // Interaction
  Click(Locator)
  DoubleClick(Locator)
  Type(locator: Locator, text: String)
  Clear(Locator)
  Select(locator: Locator, value: String)
  Check(Locator)
  Uncheck(Locator)

  // Advanced (NeedsBrowser)
  Drag(from: Locator, to: Locator)
  Hover(Locator)
  Focus(Locator)
  Blur(Locator)
  PressKey(key: String)
  Scroll(Locator)
  ScrollToBottom

  // Simulate-only: inject a message directly (for effect responses)
  InjectMsg(msg_constructor: String, args: List(String))

  // Multi-actor wrapper
  As(actor: Actor, action: Action)
}
```

### 3.6 Expectations (ADT, No Closures)

**Critical:** Expectations must be pure ADT for serializability.

```gleam
// specs/domain/expectations.gleam

pub type Expectation {
  // Visibility
  Visible(Locator)
  NotVisible(Locator)
  Exists(Locator)
  NotExists(Locator)

  // State
  Enabled(Locator)
  Disabled(Locator)
  Checked(Locator)
  Unchecked(Locator)
  Focused(Locator)

  // Content
  TextEquals(Locator, String)
  TextContains(Locator, String)
  TextMatches(Locator, pattern: String)
  ValueEquals(Locator, String)
  HasAttribute(Locator, name: String, value: String)
  HasClass(Locator, class: String)

  // Count
  HasCount(Locator, Int)
  HasMinCount(Locator, Int)

  // Navigation
  UrlIs(Route)
  UrlContains(String)

  // Timing wrapper (for async assertions)
  Eventually(Expectation, timeout_ms: Option(Int))

  // Simulate-only (model assertions) - triggers SimulateOnly capability
  ModelPageIs(Page)
  ModelUserIs(Option(UserRef))
  ModelHasToast(String)
  ModelFiltersEqual(filters: PoolFilters)

  // Multi-actor wrapper
  As(actor: Actor, exp: Expectation)
}
```

### 3.7 Preconditions

```gleam
// specs/domain/preconditions.gleam

pub type Precondition {
  // Navigation state
  On(Route)

  // Auth state
  LoggedInAs(UserRef)
  LoggedOut

  // App state
  ProjectSelected(ProjectRef)
  ViewModeIs(ViewMode)
  ThemeIs(Theme)
  LocaleIs(Locale)

  // Data state (verify, not create)
  TaskIsVisible(TaskRef)
  TaskIsClaimed(TaskRef, by: UserRef)
}
```

### 3.8 Fixtures (Channel-Agnostic)

Fixtures describe **what data** to create, not **how**. The channel (in-memory vs API) is determined by RunConfig:

```gleam
// specs/domain/fixtures.gleam

pub type Fixture {
  // Users
  CreateUser(ref: UserRef, email: String, role: Role)
  DeleteUser(ref: UserRef)

  // Projects
  CreateProject(ref: ProjectRef, name: String)

  // Tasks
  CreateTask(
    ref: TaskRef,
    project: ProjectRef,
    title: String,
    status: TaskStatus,
  )
  CreateTaskWithType(
    ref: TaskRef,
    project: ProjectRef,
    title: String,
    status: TaskStatus,
    task_type: TaskTypeRef,
  )

  // Capabilities
  CreateCapability(ref: CapabilityRef, name: String)
  AssignCapability(user: UserRef, capability: CapabilityRef)

  // Task Types
  CreateTaskType(ref: TaskTypeRef, name: String, icon: String)

  // Bulk scenarios (typed, not string)
  Seed(SeedScenario)

  // Scenarios that REQUIRE real backend (explicit)
  SeedRealOnly(RealOnlyScenario)
}

pub type SeedScenario {
  PoolWithVariedTasks      // 5 tasks, different statuses
  PoolEmpty                // No tasks
  MemberWithActiveSession  // User with ongoing work session
}

/// These scenarios cannot be simulated in-memory
pub type RealOnlyScenario {
  AdminWithFullOrg         // Complex org setup
  MultiUserScenario        // Multiple browser contexts needed
}

/// How fixtures are executed
pub type FixtureChannel {
  InMemory    // Build Model directly (simulate)
  ViaApi      // POST /api/test/fixtures (playwright)
}
```

### 3.9 Capabilities (Auto-Inferred)

```gleam
// specs/domain/capabilities.gleam

pub type Capability {
  NeedsBrowser       // Requires Playwright (real rendering, drag-drop)
  NeedsRealNetwork   // Requires real backend API
  NeedsRealStorage   // Requires localStorage/IndexedDB
  NeedsClock         // Requires time control (fake timers)
  SimulateOnly       // Cannot run in Playwright (model assertions)
}

/// All capabilities that make a spec non-simulable
pub const non_simulable = [NeedsBrowser, NeedsRealNetwork, NeedsRealStorage, NeedsClock]

/// Infer capabilities from an action
pub fn action_caps(action: Action) -> List(Capability) {
  case action {
    Drag(_, _) -> [NeedsBrowser]
    Scroll(_) | ScrollToBottom -> [NeedsBrowser]
    InjectMsg(_, _) -> [SimulateOnly]
    As(_, inner) -> action_caps(inner)
    _ -> []
  }
}

/// Infer capabilities from a fixture
/// NOTE: Most fixtures are channel-agnostic (can be in-memory or API)
pub fn fixture_caps(fixture: Fixture) -> List(Capability) {
  case fixture {
    // Only RealOnly scenarios force NeedsRealNetwork
    SeedRealOnly(_) -> [NeedsRealNetwork]
    // All other fixtures are channel-agnostic
    _ -> []
  }
}

/// Infer capabilities from a precondition
pub fn precondition_caps(pre: Precondition) -> List(Capability) {
  case pre {
    ThemeIs(_) -> [NeedsRealStorage]  // Theme persists in localStorage
    _ -> []
  }
}

/// Infer capabilities from an expectation
pub fn expectation_caps(exp: Expectation) -> List(Capability) {
  case exp {
    ModelPageIs(_) | ModelUserIs(_) | ModelHasToast(_) | ModelFiltersEqual(_) ->
      [SimulateOnly]
    Eventually(inner, _) -> expectation_caps(inner)
    As(_, inner) -> expectation_caps(inner)
    _ -> []
  }
}
```

---

## 4. Layer 2: Spec Structure

### 4.1 Step Type (No `And`)

**Key decision:** `And` is presentation, not semantics. It's derived when generating docs.

```gleam
// specs/domain/spec.gleam

pub type Step {
  Given(Precondition)
  When(Action)
  Then(Expectation)
  // NO And(...) - derived in presentation layer
}
```

### 4.2 Spec Type

```gleam
pub type Spec {
  Spec(
    id: String,
    name: String,
    feature: String,
    tags: List(String),
    arrange: List(Fixture),  // Technical setup, separate from steps
    steps: List(Step),
    // capabilities are INFERRED, not declared
  )
}
```

### 4.3 Capability Inference and Validation

```gleam
/// Infer all capabilities required by a spec
pub fn infer_capabilities(spec: Spec) -> List(Capability) {
  let fixture_caps = spec.arrange
    |> list.flat_map(fixture_caps)

  let step_caps = spec.steps
    |> list.flat_map(fn(step) {
      case step {
        Given(pre) -> precondition_caps(pre)
        When(action) -> action_caps(action)
        Then(exp) -> expectation_caps(exp)
      }
    })

  [fixture_caps, step_caps]
  |> list.flatten
  |> list.unique
}

/// Check if spec can run in simulate backend
pub fn can_simulate(spec: Spec) -> Bool {
  let caps = infer_capabilities(spec)
  !list.any(non_simulable, fn(cap) { list.contains(caps, cap) })
}

/// Check for conflicting capabilities
pub fn validate_capabilities(spec: Spec) -> Result(Nil, String) {
  let caps = infer_capabilities(spec)
  let has_simulate_only = list.contains(caps, SimulateOnly)
  let has_non_simulable = list.any(non_simulable, fn(cap) {
    list.contains(caps, cap)
  })

  case has_simulate_only && has_non_simulable {
    True -> Error(
      "Spec '" <> spec.id <> "' has conflicting capabilities: " <>
      "SimulateOnly cannot combine with " <>
      "NeedsBrowser/NeedsRealNetwork/NeedsRealStorage/NeedsClock"
    )
    False -> Ok(Nil)
  }
}
```

### 4.4 DSL Builder

```gleam
// specs/dsl.gleam

pub opaque type SpecBuilder {
  SpecBuilder(
    id: String,
    name: String,
    feature: String,
    tags: List(String),
    arrange: List(Fixture),
    steps: List(Step),
  )
}

pub fn spec(id: String, name: String) -> SpecBuilder {
  SpecBuilder(id, name, "", [], [], [])
}

pub fn feature(builder: SpecBuilder, f: String) -> SpecBuilder {
  SpecBuilder(..builder, feature: f)
}

pub fn tagged(builder: SpecBuilder, tags: List(String)) -> SpecBuilder {
  SpecBuilder(..builder, tags: list.append(builder.tags, tags))
}

pub fn arrange(builder: SpecBuilder, fixtures: List(Fixture)) -> SpecBuilder {
  SpecBuilder(..builder, arrange: list.append(builder.arrange, fixtures))
}

pub fn given(builder: SpecBuilder, pre: Precondition) -> SpecBuilder {
  SpecBuilder(..builder, steps: list.append(builder.steps, [Given(pre)]))
}

pub fn when_(builder: SpecBuilder, action: Action) -> SpecBuilder {
  SpecBuilder(..builder, steps: list.append(builder.steps, [When(action)]))
}

pub fn then_(builder: SpecBuilder, exp: Expectation) -> SpecBuilder {
  SpecBuilder(..builder, steps: list.append(builder.steps, [Then(exp)]))
}

pub fn build(builder: SpecBuilder) -> Result(Spec, String) {
  let spec = Spec(
    id: builder.id,
    name: builder.name,
    feature: builder.feature,
    tags: builder.tags,
    arrange: builder.arrange,
    steps: builder.steps,
  )

  // Validate before returning
  validate_capabilities(spec)
  |> result.map(fn(_) { spec })
}
```

---

## 5. Layer 3: Backends

### 5.1 Target Resolution (TestId, NOT CSS)

**Critical:** We resolve targets to **test_id values**, not CSS selectors. Both backends use this directly.

```gleam
// specs/resolvers/test_ids.gleam

/// Resolve Target to a test_id value (NOT a CSS selector)
/// This is used by:
/// - Simulate: query.test_id(value)
/// - Playwright: page.getByTestId(value)
pub fn resolve_target(ctx: TestContext, target: Target) -> String {
  case target {
    Auth(t) -> resolve_auth(t)
    Pool(t) -> resolve_pool(ctx, t)
    Admin(t) -> resolve_admin(t)
    Common(t) -> resolve_common(t)
  }
}

fn resolve_auth(target: AuthTarget) -> String {
  case target {
    EmailInput -> "auth-email"
    PasswordInput -> "auth-password"
    PasswordConfirmInput -> "auth-password-confirm"
    SubmitButton -> "auth-submit"
    ForgotPasswordLink -> "auth-forgot-password"
    ErrorMessage -> "auth-error"
  }
}

fn resolve_pool(ctx: TestContext, target: PoolTarget) -> String {
  case target {
    TaskCard(ref) -> "task-card:" <> materialize(ctx, ref)
    ClaimButton(ref) -> "task-claim:" <> materialize(ctx, ref)
    ReleaseButton(ref) -> "task-release:" <> materialize(ctx, ref)
    CompleteButton(ref) -> "task-complete:" <> materialize(ctx, ref)
    StartWorkButton(ref) -> "task-start-work:" <> materialize(ctx, ref)
    MyTasksDropzone -> "my-tasks-dropzone"
    MyTasksSection -> "my-tasks-section"
    FilterStatus(status) -> "filter-status:" <> status_to_string(status)
    FilterType(ref) -> "filter-type:" <> materialize(ctx, ref)
    FilterCapability(ref) -> "filter-capability:" <> materialize(ctx, ref)
    ViewModeToggle(mode) -> "view-mode:" <> mode_to_string(mode)
    CreateTaskButton -> "pool-create-task"
    CreateTaskDialog -> "pool-create-dialog"
    SearchInput -> "pool-search"
    TaskDetailsPanel -> "task-details-panel"
    NotesSection -> "task-notes"
    NoteInput -> "note-input"
  }
}

fn resolve_common(target: CommonTarget) -> String {
  case target {
    Toast -> "toast"
    ToastMessage -> "toast-message"
    NavMenu -> "nav-menu"
    Sidebar -> "sidebar"
    MobileDrawer -> "mobile-drawer"
    HamburgerMenu -> "hamburger-menu"
    ThemeSelector -> "theme-selector"
    LocaleSelector -> "locale-selector"
    UserMenu -> "user-menu"
    LogoutButton -> "logout-button"
    LoadingSpinner -> "loading-spinner"
    ErrorBoundary -> "error-boundary"
  }
}
```

### 5.2 Simulate Backend (Threaded Simulation)

**Important:** `lustre/dev/simulate` returns a new `Simulation` on each event. We must thread it through with `fold`:

```gleam
// specs/backends/simulate.gleam

import lustre/dev/simulate.{type Simulation}
import lustre/dev/query
import specs/resolvers/test_ids
import specs/domain/context.{type TestContext, materialize}

pub fn run(app, spec: Spec, ctx: TestContext) -> Result(SpecResult, String) {
  let start_time = now_ms()

  // Build initial model from fixtures (in-memory)
  let model = build_model_from_fixtures(ctx, spec.arrange)

  // Start simulation
  let sim0 = simulate.start(app, model)

  // Execute steps with threaded simulation
  let result = spec.steps
    |> list.index_fold(Ok(#(sim0, [])), fn(acc, step, i) {
      use #(sim, results) <- result.try(acc)
      case execute_step(ctx, sim, step, i) {
        Ok(#(sim2, step_result)) ->
          Ok(#(sim2, list.append(results, [step_result])))
        Error(#(sim2, step_result)) ->
          // On failure, mark remaining steps as skipped
          let remaining = list.drop(spec.steps, i + 1)
          let skipped = list.index_map(remaining, fn(_, j) {
            Skipped(i + 1 + j, "Previous step failed")
          })
          Error(#(sim2, list.append(results, [step_result, ..skipped])))
      }
    })

  let duration = now_ms() - start_time

  case result {
    Ok(#(_sim_final, step_results)) ->
      Ok(build_spec_result(ctx, spec, step_results, Simulate, duration))
    Error(#(_sim_final, step_results)) ->
      Ok(build_spec_result(ctx, spec, step_results, Simulate, duration))
  }
}

fn execute_step(
  ctx: TestContext,
  sim: Simulation,
  step: Step,
  index: Int,
) -> Result(#(Simulation, StepResult), #(Simulation, StepResult)) {
  case step {
    Given(pre) -> execute_precondition(ctx, sim, pre, index)
    When(action) -> execute_action(ctx, sim, action, index)
    Then(exp) -> execute_expectation(ctx, sim, exp, index)
  }
}

fn execute_action(
  ctx: TestContext,
  sim: Simulation,
  action: Action,
  index: Int,
) -> Result(#(Simulation, StepResult), #(Simulation, StepResult)) {
  case action {
    Click(locator) -> {
      let q = resolve_locator_to_query(ctx, locator)
      let sim2 = simulate.click(sim, on: q)
      Ok(#(sim2, Passed(index)))
    }

    Type(locator, text) -> {
      let q = resolve_locator_to_query(ctx, locator)
      let sim2 = simulate.input(sim, on: q, value: text)
      Ok(#(sim2, Passed(index)))
    }

    Navigate(route) -> {
      let path = routes.to_path(ctx, route)
      let sim2 = simulate.message(sim, UrlChanged(path))
      Ok(#(sim2, Passed(index)))
    }

    InjectMsg(msg_name, args) -> {
      // Simulate-only: inject effect response
      let msg = construct_msg(msg_name, args)
      let sim2 = simulate.message(sim, msg)
      Ok(#(sim2, Passed(index)))
    }

    // Actions not supported in simulate
    Drag(_, _) | Scroll(_) | ScrollToBottom ->
      Error(#(sim, Skipped(index, "Action requires browser")))

    As(_, inner) ->
      // Multi-actor not supported in simulate (single model)
      Error(#(sim, Skipped(index, "Multi-actor requires browser")))

    _ -> Ok(#(sim, Passed(index)))
  }
}

fn resolve_locator_to_query(ctx: TestContext, locator: Locator) -> query.Query {
  case locator {
    One(target) -> {
      let test_id = test_ids.resolve_target(ctx, target)
      query.element(matching: query.test_id(test_id))
    }

    Child(parent, child) ->
      query.child(
        of: resolve_locator_to_query(ctx, parent),
        matching: resolve_locator_to_query(ctx, child),
      )

    Descendant(parent, child) ->
      query.descendant(
        of: resolve_locator_to_query(ctx, parent),
        matching: resolve_locator_to_query(ctx, child),
      )

    Nth(inner, index) -> {
      // Use find_all and take nth element
      // This is handled specially in execute_* functions
      resolve_locator_to_query(ctx, inner)
    }
  }
}

fn execute_expectation(
  ctx: TestContext,
  sim: Simulation,
  exp: Expectation,
  index: Int,
) -> Result(#(Simulation, StepResult), #(Simulation, StepResult)) {
  case exp {
    Visible(locator) -> {
      let q = resolve_locator_to_query(ctx, locator)
      let view = simulate.view(sim)
      case query.find(in: view, matching: q) {
        Ok(_) -> Ok(#(sim, Passed(index)))
        Error(_) ->
          let attachments = [capture_model_snapshot(sim)]
          Error(#(sim, Failed(index, "Element not visible", attachments)))
      }
    }

    ModelPageIs(expected_page) -> {
      let model = simulate.model(sim)
      case model.core.page == expected_page {
        True -> Ok(#(sim, Passed(index)))
        False ->
          let msg = "Expected page " <> page_to_string(expected_page) <>
            ", got " <> page_to_string(model.core.page)
          Error(#(sim, Failed(index, msg, [])))
      }
    }

    // ... other expectations
    _ -> Ok(#(sim, Passed(index)))
  }
}

fn capture_model_snapshot(sim: Simulation) -> Attachment {
  let model = simulate.model(sim)
  let json = model_to_json(model)
  let path = write_temp_file("model-snapshot.json", json)
  Attachment(kind: ModelSnapshot, path: path)
}
```

### 5.3 Playwright Backend (Stdio JSON Protocol)

**Note:** This is a **Stdio JSON Protocol** (one-shot stdin→stdout), not JSON-RPC.

#### 5.3.1 Protocol Definition (Typed Commands)

```gleam
// specs/protocol.gleam

pub const protocol_version = 1

pub type RunConfig {
  RunConfig(
    base_url: String,
    default_timeout_ms: Int,
    screenshot_on_failure: Bool,
    trace_enabled: Bool,
    video_enabled: Bool,
    headless: Bool,
    viewport: #(Int, Int),
    slow_mo_ms: Int,
    fixture_token: String,  // Security: required header for fixture API
  )
}

pub type PlaywrightPayload {
  PlaywrightPayload(
    protocol_version: Int,
    run_id: String,
    config: RunConfig,
    spec: SerializedSpec,
  )
}

pub type SerializedSpec {
  SerializedSpec(
    id: String,
    name: String,
    arrange: List(SerializedFixture),
    steps: List(SerializedStep),
  )
}

/// Typed commands - NOT string + args dict
pub type SerializedStep {
  SerializedStep(
    index: Int,
    step_type: StepType,  // given, when, then
    command: Command,
    timeout_ms: Option(Int),
  )
}

pub type StepType {
  GivenStep
  WhenStep
  ThenStep
}

/// Command ADT - fully typed, serializable to JSON
pub type Command {
  // Navigation
  CmdNavigate(path: String)

  // Actions
  CmdClick(locator: SerializedLocator)
  CmdFill(locator: SerializedLocator, text: String)
  CmdClear(locator: SerializedLocator)
  CmdSelect(locator: SerializedLocator, value: String)
  CmdCheck(locator: SerializedLocator)
  CmdUncheck(locator: SerializedLocator)
  CmdDrag(from: SerializedLocator, to: SerializedLocator)
  CmdHover(locator: SerializedLocator)
  CmdFocus(locator: SerializedLocator)
  CmdPressKey(key: String)
  CmdScroll(locator: SerializedLocator)
  CmdScrollToBottom

  // Expectations
  CmdExpectVisible(locator: SerializedLocator)
  CmdExpectNotVisible(locator: SerializedLocator)
  CmdExpectEnabled(locator: SerializedLocator)
  CmdExpectDisabled(locator: SerializedLocator)
  CmdExpectTextEquals(locator: SerializedLocator, text: String)
  CmdExpectTextContains(locator: SerializedLocator, text: String)
  CmdExpectUrl(url: String)
  CmdExpectUrlContains(pattern: String)
  CmdExpectCount(locator: SerializedLocator, count: Int)
}

/// Locator as AST for proper Nth handling
pub type SerializedLocator {
  LocOne(test_id: String)
  LocChild(parent: SerializedLocator, child: SerializedLocator)
  LocDescendant(parent: SerializedLocator, child: SerializedLocator)
  LocNth(inner: SerializedLocator, index: Int)
}

pub type SerializedFixture {
  SerializedFixture(
    fixture_type: String,
    ref_key: String,          // Materialized ref
    data: Dict(String, Json),
  )
}
```

#### 5.3.2 JSON Encoder

```gleam
// specs/backends/playwright/encoder.gleam

pub fn encode_payload(payload: PlaywrightPayload) -> String {
  json.object([
    #("protocol_version", json.int(payload.protocol_version)),
    #("run_id", json.string(payload.run_id)),
    #("config", encode_config(payload.config)),
    #("spec", encode_spec(payload.spec)),
  ])
  |> json.to_string
}

fn encode_locator(loc: SerializedLocator) -> Json {
  case loc {
    LocOne(test_id) ->
      json.object([
        #("type", json.string("one")),
        #("test_id", json.string(test_id)),
      ])

    LocChild(parent, child) ->
      json.object([
        #("type", json.string("child")),
        #("parent", encode_locator(parent)),
        #("child", encode_locator(child)),
      ])

    LocDescendant(parent, child) ->
      json.object([
        #("type", json.string("descendant")),
        #("parent", encode_locator(parent)),
        #("child", encode_locator(child)),
      ])

    LocNth(inner, index) ->
      json.object([
        #("type", json.string("nth")),
        #("inner", encode_locator(inner)),
        #("index", json.int(index)),
      ])
  }
}

fn encode_command(cmd: Command) -> Json {
  case cmd {
    CmdClick(loc) ->
      json.object([
        #("kind", json.string("click")),
        #("locator", encode_locator(loc)),
      ])

    CmdFill(loc, text) ->
      json.object([
        #("kind", json.string("fill")),
        #("locator", encode_locator(loc)),
        #("text", json.string(text)),
      ])

    CmdDrag(from, to) ->
      json.object([
        #("kind", json.string("drag")),
        #("from", encode_locator(from)),
        #("to", encode_locator(to)),
      ])

    CmdExpectVisible(loc) ->
      json.object([
        #("kind", json.string("expect_visible")),
        #("locator", encode_locator(loc)),
      ])

    // ... other commands
  }
}
```

#### 5.3.3 Node.js Runner (Corrected)

```javascript
// e2e/runner.js
const { chromium, expect, selectors } = require('@playwright/test');
const fs = require('fs/promises');
const path = require('path');

const SUPPORTED_PROTOCOL_VERSION = 1;

// Configure Playwright to use data-test-id attribute
selectors.setTestIdAttribute('data-test-id');

async function main() {
  const input = JSON.parse(await readStdin());

  // Validate protocol version
  if (input.protocol_version !== SUPPORTED_PROTOCOL_VERSION) {
    fail(`Unsupported protocol version: ${input.protocol_version}, expected: ${SUPPORTED_PROTOCOL_VERSION}`);
  }

  const { run_id, config, spec } = input;

  // Ensure output directories exist
  await ensureDir(`/tmp/screenshots`);
  await ensureDir(`/tmp/html`);
  await ensureDir(`/tmp/traces`);
  if (config.video_enabled) {
    await ensureDir(`/tmp/videos/${run_id}`);
  }

  // Launch browser
  const browser = await chromium.launch({
    headless: config.headless,
    slowMo: config.slow_mo_ms,
  });

  const context = await browser.newContext({
    baseURL: config.base_url,
    viewport: { width: config.viewport[0], height: config.viewport[1] },
    recordVideo: config.video_enabled
      ? { dir: `/tmp/videos/${run_id}` }
      : undefined,
  });

  if (config.trace_enabled) {
    await context.tracing.start({ screenshots: true, snapshots: true });
  }

  const page = await context.newPage();
  const results = [];
  const startTime = Date.now();

  try {
    // Execute fixtures (arrange)
    for (const fixture of spec.arrange) {
      await executeFixture(page, fixture, config);
    }

    // Execute steps
    for (const step of spec.steps) {
      const stepStart = Date.now();
      try {
        await executeStep(page, step, config);
        results.push({
          status: 'passed',
          step_index: step.index,
          duration_ms: Date.now() - stepStart,
        });
      } catch (error) {
        const attachments = await captureFailureArtifacts(page, run_id, step.index, config);

        results.push({
          status: 'failed',
          step_index: step.index,
          reason: error.message,
          duration_ms: Date.now() - stepStart,
          attachments,
        });

        // Mark remaining steps as skipped
        for (let i = step.index + 1; i < spec.steps.length; i++) {
          results.push({
            status: 'skipped',
            step_index: i,
            reason: 'Previous step failed',
          });
        }

        break;
      }
    }
  } finally {
    const attachments = [];

    if (config.trace_enabled) {
      const tracePath = `/tmp/traces/${run_id}.zip`;
      await context.tracing.stop({ path: tracePath });
      attachments.push({ kind: 'Trace', path: tracePath });
    }

    if (config.video_enabled) {
      const videoPath = await page.video()?.path();
      if (videoPath) {
        attachments.push({ kind: 'Video', path: videoPath });
      }
    }

    await browser.close();

    // Output result
    const allPassed = results.every(r => r.status === 'passed');
    console.log(JSON.stringify({
      spec_id: spec.id,
      run_id,
      backend: 'Playwright',
      duration_ms: Date.now() - startTime,
      results,
      status: allPassed ? 'AllPassed' : 'SomeFailed',
      attachments,
    }));
  }
}

async function executeStep(page, step, config) {
  const timeout = step.timeout_ms || config.default_timeout_ms;
  const cmd = step.command;

  switch (cmd.kind) {
    case 'navigate':
      await page.goto(cmd.path);
      break;

    case 'click':
      await resolveLocator(page, cmd.locator).click({ timeout });
      break;

    case 'fill':
      await resolveLocator(page, cmd.locator).fill(cmd.text, { timeout });
      break;

    case 'clear':
      await resolveLocator(page, cmd.locator).clear({ timeout });
      break;

    case 'select':
      await resolveLocator(page, cmd.locator).selectOption(cmd.value, { timeout });
      break;

    case 'check':
      await resolveLocator(page, cmd.locator).check({ timeout });
      break;

    case 'uncheck':
      await resolveLocator(page, cmd.locator).uncheck({ timeout });
      break;

    case 'drag':
      await resolveLocator(page, cmd.from).dragTo(resolveLocator(page, cmd.to), { timeout });
      break;

    case 'hover':
      await resolveLocator(page, cmd.locator).hover({ timeout });
      break;

    case 'focus':
      await resolveLocator(page, cmd.locator).focus({ timeout });
      break;

    case 'press_key':
      await page.keyboard.press(cmd.key);
      break;

    case 'scroll':
      await resolveLocator(page, cmd.locator).scrollIntoViewIfNeeded({ timeout });
      break;

    case 'scroll_to_bottom':
      await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
      break;

    // Expectations
    case 'expect_visible':
      await expect(resolveLocator(page, cmd.locator)).toBeVisible({ timeout });
      break;

    case 'expect_not_visible':
      await expect(resolveLocator(page, cmd.locator)).not.toBeVisible({ timeout });
      break;

    case 'expect_enabled':
      await expect(resolveLocator(page, cmd.locator)).toBeEnabled({ timeout });
      break;

    case 'expect_disabled':
      await expect(resolveLocator(page, cmd.locator)).toBeDisabled({ timeout });
      break;

    case 'expect_text_equals':
      await expect(resolveLocator(page, cmd.locator)).toHaveText(cmd.text, { timeout });
      break;

    case 'expect_text_contains':
      await expect(resolveLocator(page, cmd.locator)).toContainText(cmd.text, { timeout });
      break;

    case 'expect_url':
      await expect(page).toHaveURL(cmd.url, { timeout });
      break;

    case 'expect_url_contains':
      await expect(page).toHaveURL(new RegExp(cmd.pattern), { timeout });
      break;

    case 'expect_count':
      await expect(resolveLocator(page, cmd.locator)).toHaveCount(cmd.count, { timeout });
      break;

    default:
      throw new Error(`Unknown command kind: ${cmd.kind}`);
  }
}

/**
 * Resolve a SerializedLocator to a Playwright Locator
 * Uses getByTestId for One, proper composition for Child/Descendant/Nth
 */
function resolveLocator(page, loc) {
  switch (loc.type) {
    case 'one':
      return page.getByTestId(loc.test_id);

    case 'child':
      // Direct child: parent.locator('> [data-test-id="..."]')
      const parentChild = resolveLocator(page, loc.parent);
      const childTestId = getTestIdFromLocator(loc.child);
      return parentChild.locator(`> [data-test-id="${childTestId}"]`);

    case 'descendant':
      // Any descendant: parent.getByTestId(child)
      const parentDesc = resolveLocator(page, loc.parent);
      return parentDesc.getByTestId(getTestIdFromLocator(loc.child));

    case 'nth':
      // Nth match (not nth-child!)
      return resolveLocator(page, loc.inner).nth(loc.index);

    default:
      throw new Error(`Unknown locator type: ${loc.type}`);
  }
}

function getTestIdFromLocator(loc) {
  if (loc.type === 'one') return loc.test_id;
  throw new Error('Nested locator in child/descendant must be One');
}

async function executeFixture(page, fixture, config) {
  const response = await page.request.post(`${config.base_url}/api/test/fixtures`, {
    headers: {
      'X-Test-Fixture-Token': config.fixture_token,
    },
    data: fixture,
  });

  if (!response.ok()) {
    const body = await response.text();
    throw new Error(`Fixture '${fixture.fixture_type}' failed: ${response.status()} - ${body}`);
  }
}

async function captureFailureArtifacts(page, runId, stepIndex, config) {
  const attachments = [];

  if (config.screenshot_on_failure) {
    const screenshotPath = `/tmp/screenshots/${runId}-${stepIndex}.png`;
    await page.screenshot({ path: screenshotPath, fullPage: true });
    attachments.push({ kind: 'Screenshot', path: screenshotPath });
  }

  // Always capture HTML on failure
  const htmlPath = `/tmp/html/${runId}-${stepIndex}.html`;
  await fs.writeFile(htmlPath, await page.content());
  attachments.push({ kind: 'Html', path: htmlPath });

  return attachments;
}

async function ensureDir(dir) {
  await fs.mkdir(dir, { recursive: true });
}

async function readStdin() {
  const chunks = [];
  for await (const chunk of process.stdin) {
    chunks.push(chunk);
  }
  return Buffer.concat(chunks).toString('utf8');
}

function fail(message) {
  console.error(JSON.stringify({ error: message }));
  process.exit(1);
}

main().catch(err => {
  fail(err.message);
});
```

---

## 6. Layer 4: Execution Router

```gleam
// specs/runner.gleam

import specs/backends/simulate as simulate_backend
import specs/backends/playwright as playwright_backend

pub type Backend {
  Simulate
  Playwright
}

/// Select backend based on inferred capabilities
pub fn select_backend(spec: Spec) -> Result(Backend, String) {
  // First validate
  use _ <- result.try(validate_capabilities(spec))

  // Then select
  case can_simulate(spec) {
    True -> Ok(Simulate)
    False -> Ok(Playwright)
  }
}

/// Run a single spec
pub fn run_spec(
  app,
  spec: Spec,
  config: RunConfig,
  ctx: TestContext,
) -> Result(SpecResult, String) {
  use backend <- result.try(select_backend(spec))

  case backend {
    Simulate -> simulate_backend.run(app, spec, ctx)
    Playwright -> playwright_backend.run(spec, config, ctx)
  }
}

/// Run all specs in catalog
pub fn run_all(
  app,
  specs: List(Spec),
  config: RunConfig,
) -> SuiteResult {
  let ctx = new_context()  // Single run_id for entire suite

  let results = specs
    |> list.map(fn(spec) {
      case run_spec(app, spec, config, ctx) {
        Ok(result) -> result
        Error(e) -> SpecResult(
          spec_id: spec.id,
          run_id: ctx.run_id,
          backend: Simulate,
          duration_ms: 0,
          steps: [],
          status: SetupFailed(e),
        )
      }
    })

  build_suite_result(results)
}

/// Run only specs matching tags
pub fn run_tagged(
  app,
  specs: List(Spec),
  tags: List(String),
  config: RunConfig,
) -> SuiteResult {
  specs
  |> list.filter(fn(spec) {
    list.any(tags, fn(tag) { list.contains(spec.tags, tag) })
  })
  |> run_all(app, _, config)
}

/// Run only fast specs (simulate backend)
pub fn run_fast(app, specs: List(Spec)) -> SuiteResult {
  let ctx = new_context()

  let results = specs
    |> list.filter(can_simulate)
    |> list.map(fn(spec) {
      simulate_backend.run(app, spec, ctx)
      |> result.unwrap(error_result(spec, ctx))
    })

  build_suite_result(results)
}
```

---

## 7. Layer 5: Results and Reporting

### 7.1 Result Types

```gleam
// specs/results.gleam

pub type AttachmentKind {
  Screenshot
  Html
  Trace
  Video
  ConsoleLog
  ModelSnapshot
}

pub type Attachment {
  Attachment(kind: AttachmentKind, path: String)
}

pub type StepResult {
  Passed(step_index: Int, duration_ms: Int)
  Failed(step_index: Int, reason: String, attachments: List(Attachment))
  Skipped(step_index: Int, reason: String)
}

pub type SpecStatus {
  AllPassed
  SomeFailed
  SetupFailed(reason: String)
  Skipped(reason: String)
}

pub type SpecResult {
  SpecResult(
    spec_id: String,
    run_id: String,
    backend: Backend,
    duration_ms: Int,
    steps: List(StepResult),
    status: SpecStatus,
    attachments: List(Attachment),  // Suite-level (trace, video)
  )
}

pub type SuiteResult {
  SuiteResult(
    run_id: String,
    total: Int,
    passed: Int,
    failed: Int,
    skipped: Int,
    duration_ms: Int,
    specs: List(SpecResult),
  )
}
```

### 7.2 Console Reporter

```gleam
// specs/reporters/console.gleam

pub fn report(results: SuiteResult) -> Nil {
  io.println("")
  io.println("═══════════════════════════════════════════════════")
  io.println("                   TEST RESULTS                     ")
  io.println("═══════════════════════════════════════════════════")
  io.println("Run ID: " <> results.run_id)
  io.println("")

  list.each(results.specs, fn(spec_result) {
    let icon = case spec_result.status {
      AllPassed -> "✅"
      SomeFailed -> "❌"
      SetupFailed(_) -> "💥"
      Skipped(_) -> "⏭️"
    }

    let backend = case spec_result.backend {
      Simulate -> "🧪"
      Playwright -> "🌐"
    }

    let duration = int.to_string(spec_result.duration_ms) <> "ms"

    io.println(icon <> " " <> backend <> " " <> spec_result.spec_id <> " (" <> duration <> ")")

    case spec_result.status {
      SomeFailed -> {
        list.each(spec_result.steps, fn(step) {
          case step {
            Failed(i, reason, attachments) -> {
              io.println("   └─ Step " <> int.to_string(i) <> " failed: " <> reason)
              list.each(attachments, fn(a) {
                io.println("      📎 " <> attachment_kind_to_string(a.kind) <> ": " <> a.path)
              })
            }
            _ -> Nil
          }
        })
      }
      SetupFailed(reason) ->
        io.println("   └─ Setup failed: " <> reason)
      _ -> Nil
    }
  })

  io.println("")
  io.println("───────────────────────────────────────────────────")
  io.println(
    "Total: " <> int.to_string(results.total) <>
    " | Passed: " <> int.to_string(results.passed) <>
    " | Failed: " <> int.to_string(results.failed) <>
    " | Skipped: " <> int.to_string(results.skipped)
  )
  io.println("Duration: " <> int.to_string(results.duration_ms) <> "ms")
  io.println("═══════════════════════════════════════════════════")
}
```

---

## 8. Living Documentation

### 8.1 Markdown Generator

`And` is **derived** during generation, not stored in the model. Specs are sorted for deterministic output.

```gleam
// specs/docs/generator.gleam

pub fn generate_full_docs(specs: List(Spec)) -> String {
  let by_feature = list.group(specs, fn(s) { s.feature })

  let header = "# Test Specifications\n\n" <>
    "> Auto-generated from typed specs. Do not edit manually.\n\n" <>
    "---\n\n"

  let toc = generate_toc(by_feature)

  let content = by_feature
    |> dict.to_list
    |> list.sort(fn(a, b) { string.compare(a.0, b.0) })  // Sort by feature
    |> list.map(fn(pair) {
      let #(feature, feature_specs) = pair
      // Sort specs within feature by id
      let sorted_specs = list.sort(feature_specs, fn(a, b) {
        string.compare(a.id, b.id)
      })
      generate_feature_section(feature, sorted_specs)
    })
    |> string.join("\n\n---\n\n")

  header <> toc <> "\n\n---\n\n" <> content
}

fn spec_to_markdown(spec: Spec) -> String {
  let caps = infer_capabilities(spec)
  let backend = case can_simulate(spec) {
    True -> "🧪 Simulate"
    False -> "🌐 Playwright"
  }

  let caps_str = caps
    |> list.map(capability_to_string)
    |> string.join(", ")

  let header = "### " <> spec.name <> "\n\n"
  let meta =
    "| Property | Value |\n" <>
    "|----------|-------|\n" <>
    "| **ID** | `" <> spec.id <> "` |\n" <>
    "| **Backend** | " <> backend <> " |\n" <>
    "| **Tags** | " <> string.join(spec.tags, ", ") <> " |\n" <>
    "| **Capabilities** | " <> caps_str <> " |\n\n"

  // Show arrange section if non-empty (collapsible)
  let arrange_md = case spec.arrange {
    [] -> ""
    fixtures -> {
      "<details>\n<summary>Technical Setup</summary>\n\n" <>
      list.map(fixtures, fixture_to_markdown) |> string.join("\n") <>
      "\n</details>\n\n"
    }
  }

  let steps_header = "**Steps:**\n\n"
  let steps_md = spec.steps
    |> add_and_markers
    |> list.map(step_to_markdown)
    |> string.join("\n")

  header <> meta <> arrange_md <> steps_header <> steps_md
}

/// Add "And" markers for consecutive steps of same type
fn add_and_markers(steps: List(Step)) -> List(#(Step, Bool)) {
  steps
  |> list.index_map(fn(step, i) {
    let is_continuation = case i > 0 {
      True -> {
        let assert Ok(prev_step) = list.at(steps, i - 1)
        same_step_type(prev_step, step)
      }
      False -> False
    }
    #(step, is_continuation)
  })
}

fn step_to_markdown(pair: #(Step, Bool)) -> String {
  let #(step, is_and) = pair

  let prefix = case is_and {
    True -> "  - **And** "
    False -> case step {
      Given(_) -> "- **Given** "
      When(_) -> "- **When** "
      Then(_) -> "- **Then** "
    }
  }

  prefix <> step_content_to_string(step)
}

fn step_content_to_string(step: Step) -> String {
  case step {
    Given(On(route)) -> "user is on " <> route_to_string(route)
    Given(LoggedInAs(ref)) -> "user is logged in as `" <> refs.key(ref) <> "`"
    Given(ProjectSelected(ref)) -> "project `" <> refs.key(ref) <> "` is selected"

    When(Click(locator)) -> "clicks on " <> locator_to_string(locator)
    When(Type(locator, text)) -> "types \"" <> text <> "\" in " <> locator_to_string(locator)
    When(Navigate(route)) -> "navigates to " <> route_to_string(route)
    When(Drag(from, to)) -> "drags " <> locator_to_string(from) <> " to " <> locator_to_string(to)
    When(InjectMsg(msg, _)) -> "receives message `" <> msg <> "` (simulate-only)"
    When(As(actor, inner)) -> "**[" <> actor.name <> "]** " <> step_content_to_string(When(inner))

    Then(Visible(locator)) -> locator_to_string(locator) <> " is visible"
    Then(NotVisible(locator)) -> locator_to_string(locator) <> " is not visible"
    Then(UrlIs(route)) -> "URL is " <> route_to_string(route)
    Then(TextContains(locator, text)) -> locator_to_string(locator) <> " contains \"" <> text <> "\""
    Then(Eventually(inner, _)) -> step_content_to_string(Then(inner)) <> " *(async)*"
    Then(ModelPageIs(page)) -> "model.page is `" <> page_to_string(page) <> "` *(simulate-only)*"
    Then(As(actor, inner)) -> "**[" <> actor.name <> "]** " <> step_content_to_string(Then(inner))

    _ -> "[complex step]"
  }
}

fn locator_to_string(locator: Locator) -> String {
  case locator {
    One(target) -> target_to_string(target)
    Child(parent, child) -> locator_to_string(child) <> " (child of " <> locator_to_string(parent) <> ")"
    Descendant(parent, child) -> locator_to_string(child) <> " within " <> locator_to_string(parent)
    Nth(inner, index) -> locator_to_string(inner) <> " [" <> int.to_string(index) <> "]"
  }
}
```

---

## 9. Security Considerations

### 9.1 Fixture API Protection

The `/api/test/fixtures` endpoint is **dangerous** - it can create/delete data. It MUST be protected:

```gleam
// server/routes/test_fixtures.gleam

/// CRITICAL: This endpoint must NEVER be enabled in production

pub fn handle_fixture_request(req: Request) -> Response {
  // 1. Check environment
  case envoy.get("APP_ENV") {
    Ok("production") -> {
      logging.warning("Fixture API called in production - blocked")
      response.new(403)
      |> response.set_body("Fixture API disabled in production")
    }

    _ -> {
      // 2. Validate token
      let token = request.get_header(req, "x-test-fixture-token")
      let expected = envoy.get("TEST_FIXTURE_TOKEN") |> result.unwrap("")

      case token == Ok(expected) && expected != "" {
        True -> execute_fixture(req)
        False -> {
          logging.warning("Fixture API called with invalid token")
          response.new(401)
          |> response.set_body("Invalid fixture token")
        }
      }
    }
  }
}
```

**Required configuration:**

```bash
# .env.test (NEVER commit)
APP_ENV=test
TEST_FIXTURE_TOKEN=your-secret-token-here

# CI environment variables
APP_ENV=test
TEST_FIXTURE_TOKEN=${{ secrets.TEST_FIXTURE_TOKEN }}
```

### 9.2 Cleanup Best Practices

- **Never use `CleanupAll`** - it's dangerous in parallel execution
- Use namespaced cleanup: `CleanupNamespace(run_id)`
- Prefer automatic cleanup by the runner after each spec
- In CI, use ephemeral databases per run when possible

---

## 10. Implementation Roadmap

### Phase 1: Core DSL (Week 1)

- [ ] Define all domain types (`refs.gleam`, `routes.gleam`, `targets.gleam`, etc.)
- [ ] Implement `TestContext` with `materialize()`
- [ ] Implement `Spec` type with capability inference
- [ ] Implement DSL builder (`spec()`, `given()`, `when_()`, `then_()`)
- [ ] Write 3-5 example specs for auth and pool features
- [ ] Add `data-test-id` attributes to existing Lustre views

### Phase 2: Simulate Backend (Week 2)

- [ ] Implement test_id resolution (NOT CSS)
- [ ] Implement `simulate_backend.run()` with threaded Simulation
- [ ] Implement expectation assertions against model and view
- [ ] Handle `Nth` locator via `query.find_all`
- [ ] Document effects limitation and `InjectMsg` pattern
- [ ] Make the example specs pass in simulate

### Phase 3: Playwright Backend (Week 3)

- [ ] Implement Command ADT encoder (typed, not strings)
- [ ] Write Node.js runner with `getByTestId()`
- [ ] Implement fixture API endpoint with token protection
- [ ] Implement Locator AST resolution in runner
- [ ] Test protocol communication Gleam ↔ Node
- [ ] Make drag-drop spec pass in Playwright

### Phase 4: Integration (Week 4)

- [ ] Implement execution router with auto-backend selection
- [ ] Implement console and JSON reporters
- [ ] Implement Markdown doc generator with stable ordering
- [ ] Add CLI commands (`gleam test -- --tags smoke`, `gleam test -- --e2e`)
- [ ] CI integration with parallel execution

### Phase 5: Polish (Week 5)

- [ ] Add more specs to catalog (target: 20-30 specs)
- [ ] Add multi-actor support for Playwright
- [ ] Add duration tracking per step
- [ ] Performance optimization
- [ ] Documentation

---

## 11. Appendix: Full Type Definitions

See individual module files in `specs/domain/`:

- `specs/domain/refs.gleam` - Phantom-typed references + `key()`
- `specs/domain/context.gleam` - TestContext + `materialize()`
- `specs/domain/routes.gleam` - Typed routes
- `specs/domain/targets.gleam` - Semantic UI targets by domain
- `specs/domain/locators.gleam` - Locator composition (Child/Descendant/Nth)
- `specs/domain/actions.gleam` - User actions + Actor
- `specs/domain/expectations.gleam` - Assertions (ADT only)
- `specs/domain/preconditions.gleam` - Given clauses
- `specs/domain/fixtures.gleam` - Test data setup (channel-agnostic)
- `specs/domain/capabilities.gleam` - Backend requirements + inference
- `specs/domain/spec.gleam` - Spec structure

---

## References

- [lustre/dev/simulate documentation](https://hexdocs.pm/lustre/lustre/dev/simulate.html)
- [lustre/dev/query documentation](https://hexdocs.pm/lustre/lustre/dev/query.html)
- [Playwright documentation](https://playwright.dev/)
- [Playwright getByTestId](https://playwright.dev/docs/locators#locate-by-test-id)
- [Is BDD Dying? - Automation Panda](https://automationpanda.com/2025/03/06/is-bdd-dying/)
- [dream_test - Gleam BDD framework](https://hexdocs.pm/dream_test/index.html)
