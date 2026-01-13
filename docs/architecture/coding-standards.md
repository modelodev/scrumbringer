# Coding Standards

> **Version:** 1.0
> **Parent:** [Architecture](../architecture.md)

---

## Gleam Conventions

### Naming

| Element | Convention | Example |
|---------|------------|---------|
| Modules | snake_case | `task_service.gleam` |
| Types | PascalCase | `Task`, `UserCapability` |
| Functions | snake_case | `get_pool_tasks`, `claim_task` |
| Constants | snake_case | `max_priority` |
| Type parameters | lowercase single letter | `Result(a, e)` |

### Module Structure

```gleam
// 1. Imports (stdlib first, then external, then internal)
import gleam/list
import gleam/result
import lustre/element
import scrumbringer/task

// 2. Type definitions
pub type Task {
  Task(id: Int, title: String, status: Status)
}

pub type Status {
  Available
  Claimed(by: Int)
  Completed
}

// 3. Constants
pub const max_priority = 5

// 4. Public functions
pub fn create(title: String) -> Task {
  Task(id: 0, title: title, status: Available)
}

// 5. Private functions
fn validate_title(title: String) -> Result(String, Error) {
  // ...
}
```

### Error Handling

**Always use Result types, never panic:**

```gleam
// Good
pub fn find_task(id: Int) -> Result(Task, TaskError) {
  case lookup(id) {
    Ok(task) -> Ok(task)
    Error(_) -> Error(TaskNotFound(id))
  }
}

// Bad - never use todo or panic in production code
pub fn find_task(id: Int) -> Task {
  case lookup(id) {
    Ok(task) -> task
    Error(_) -> panic  // Never do this
  }
}
```

**Define domain-specific error types:**

```gleam
pub type TaskError {
  TaskNotFound(id: Int)
  NotAuthorized(user_id: Int)
  VersionConflict(expected: Int, actual: Int)
  ValidationError(field: String, message: String)
}
```

### Pattern Matching

**Prefer exhaustive pattern matching:**

```gleam
// Good - handles all cases explicitly
pub fn status_label(status: Status) -> String {
  case status {
    Available -> "Available"
    Claimed(by: _) -> "In Progress"
    Completed -> "Done"
  }
}

// Avoid wildcard when possible
pub fn status_label(status: Status) -> String {
  case status {
    Available -> "Available"
    _ -> "Other"  // Avoid - loses type safety
  }
}
```

### Pipelines

**Use pipelines for data transformations:**

```gleam
// Good
tasks
|> list.filter(fn(t) { t.status == Available })
|> list.sort(by_priority)
|> list.take(10)

// Avoid deep nesting
list.take(list.sort(list.filter(tasks, fn(t) { t.status == Available }), by_priority), 10)
```

---

## Lustre Patterns

### Component Structure

```gleam
// src/components/task_card.gleam

import lustre/attribute.{class}
import lustre/element.{type Element}
import lustre/element/html.{div, span, button}

// Types
pub type TaskCard {
  TaskCard(task: Task, on_claim: fn() -> Msg)
}

// View function
pub fn view(card: TaskCard) -> Element(Msg) {
  let size_class = priority_to_size(card.task.priority)
  let decay_style = calculate_decay_style(card.task.created_at)

  div([class("task-card " <> size_class), decay_style], [
    span([class("task-title")], [element.text(card.task.title)]),
    button([on_click(card.on_claim)], [element.text("Claim")]),
  ])
}
```

### Message Types

```gleam
pub type Msg {
  // User actions
  UserClickedClaim(task_id: Int)
  UserReleasedTask(task_id: Int)
  UserMovedTask(task_id: Int, x: Int, y: Int)

  // Server responses
  ServerConfirmedClaim(task: Task)
  ServerRejectedClaim(error: TaskError)

  // Internal
  TimerTicked
}
```

### Update Function

```gleam
pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    UserClickedClaim(task_id) -> {
      // Optimistic update
      let model = mark_as_claiming(model, task_id)
      let effect = send_claim_command(task_id, model.task_version)
      #(model, effect)
    }

    ServerConfirmedClaim(task) -> {
      let model = update_task(model, task)
      #(model, effect.none())
    }

    ServerRejectedClaim(error) -> {
      // Revert optimistic update
      let model = revert_claim(model, error)
      #(model, show_notification(error))
    }

    _ -> #(model, effect.none())
  }
}
```

---

## SQL Conventions

### Query Files

Place SQL queries in `src/queries/`:

```
src/queries/
├── tasks.sql
├── users.sql
└── projects.sql
```

### Query Format

```sql
-- src/queries/tasks.sql

-- name: get_pool_tasks
-- Get all available tasks for a project
SELECT
    t.id,
    t.title,
    t.description,
    t.priority,
    t.status,
    t.created_at,
    t.version,
    tt.name AS type_name,
    tt.icon AS type_icon
FROM tasks t
JOIN task_types tt ON t.type_id = tt.id
WHERE t.status = 'available'
  AND t.project_id = $1
ORDER BY t.priority DESC, t.created_at ASC;

-- name: claim_task
-- Attempt to claim a task (optimistic concurrency)
UPDATE tasks
SET claimed_by = $1,
    claimed_at = NOW(),
    status = 'claimed',
    version = version + 1
WHERE id = $2
  AND status = 'available'
  AND version = $3
RETURNING *;
```

### Naming

- Query names: `verb_noun` (get_task, create_user, update_status)
- Tables: plural snake_case (tasks, task_notes)
- Columns: singular snake_case (created_at, user_id)
- Foreign keys: `referenced_table_id` (user_id, project_id)

---

## File Organization

### Feature-Based Structure

```
src/
├── scrumbringer.gleam       # Entry point
├── router.gleam             # Route definitions
├── components/              # Reusable UI components
│   ├── task_card.gleam
│   └── pool.gleam
├── pages/                   # Page-level components
│   ├── login.gleam
│   └── dashboard.gleam
├── services/                # Business logic
│   ├── task_service.gleam
│   └── auth_service.gleam
├── queries/                 # SQL files for Squirrel
│   └── tasks.sql
└── types/                   # Shared type definitions
    ├── task.gleam
    └── error.gleam
```

---

## Testing

### Test Organization

```
test/
├── scrumbringer_test.gleam  # Main test entry
├── task_service_test.gleam
└── task_test.gleam
```

### Test Naming

```gleam
// test/task_service_test.gleam
import gleeunit/should

pub fn claim_task_succeeds_when_available_test() {
  let task = create_available_task()
  let result = claim_task(task, user_id: 1)

  result
  |> should.be_ok
  |> fn(t) { t.status }
  |> should.equal(Claimed(by: 1))
}

pub fn claim_task_fails_when_already_claimed_test() {
  let task = create_claimed_task(by: 2)
  let result = claim_task(task, user_id: 1)

  result
  |> should.be_error
  |> should.equal(TaskAlreadyClaimed)
}
```

---

## Documentation

### Public Functions

Document all public functions with examples:

```gleam
/// Calculate the visual decay factor for a task based on age.
///
/// Returns a float between 0.0 (new) and 1.0 (30+ days old).
///
/// ## Examples
///
/// ```gleam
/// calculate_decay(created_today)     // 0.0
/// calculate_decay(created_15_days_ago) // 0.5
/// calculate_decay(created_30_days_ago) // 1.0
/// ```
pub fn calculate_decay(created_at: Time) -> Float {
  // ...
}
```

### Module Documentation

```gleam
//// Task Service
////
//// Handles all task-related business logic including:
//// - Creating tasks
//// - Claiming and releasing tasks
//// - Completing tasks
//// - Managing task positions
////
//// All operations validate user permissions and handle
//// optimistic concurrency via version fields.

import gleam/result
// ...
```

---

## Commit Messages

Follow conventional commits:

```
feat: add task claiming functionality
fix: resolve version conflict on concurrent claims
refactor: extract task validation to separate module
docs: add API documentation for task endpoints
test: add tests for claim conflict scenarios
```
