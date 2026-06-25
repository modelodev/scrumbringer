//// Task domain types for ScrumBringer.
////
//// Defines the core Task type and related structures for task management.
////
//// ## Usage
////
//// ```gleam
//// import shared/domain/task.{type Task}
//// import shared/domain/task/state as task_state
//// ```

import domain/card
import domain/task/state as task_state
import domain/task_type.{type TaskTypeInline}
import gleam/option.{type Option}

// =============================================================================
// Types
// =============================================================================

/// A task in a project.
///
/// ## Example
///
/// ```gleam
/// Task(
///   id: 1,
///   project_id: 1,
///   type_id: 1,
///   task_type: TaskTypeInline(id: 1, name: "Bug", icon: "bug"),
///   ongoing_by: None,
///   title: "Fix login button",
///   description: Some("Button doesn't respond on mobile"),
///   priority: 3,
///   created_by: 1,
///   claimed_by: None,
///   claimed_at: None,
///   completed_at: None,
///   created_at: "2024-01-17T12:00:00Z",
///   due_date: None,
///   version: 1,
///   blocked_count: 0,
///   dependencies: [],
/// )
/// ```
pub type Task {
  Task(
    id: Int,
    project_id: Int,
    type_id: Int,
    task_type: TaskTypeInline,
    ongoing_by: Option(OngoingBy),
    title: String,
    description: Option(String),
    priority: Int,
    state: task_state.TaskExecutionState,
    created_by: Int,
    created_at: String,
    due_date: Option(String),
    version: Int,
    parent_card_id: Option(Int),
    // Card (ficha) association
    card_id: Option(Int),
    card_title: Option(String),
    card_color: Option(card.CardColor),
    /// Story 5.4 AC4: True if task has notes newer than user's last view.
    has_new_notes: Bool,
    /// Story 5.6: Number of open dependencies blocking this task.
    blocked_count: Int,
    /// Story 5.6: Dependencies blocking this task.
    dependencies: List(TaskDependency),
    automation_origin: Option(AutomationOrigin),
  )
}

/// User currently working on a task.
///
/// ## Example
///
/// ```gleam
/// case task.ongoing_by {
///   Some(OngoingBy(user_id)) -> show_user_avatar(user_id)
///   None -> Nil
/// }
/// ```
pub type OngoingBy {
  OngoingBy(user_id: Int)
}

/// Traceability for a task created by automation.
pub type AutomationOrigin {
  AutomationOrigin(
    rule_id: Int,
    workflow_id: Option(Int),
    workflow_name: Option(String),
    rule_name: Option(String),
    execution_id: Option(Int),
    template_id: Option(Int),
    template_name: Option(String),
    template_version: Option(Int),
  )
}

/// A dependency entry for a task.
///
/// ## Example
///
/// ```gleam
/// TaskDependency(
///   depends_on_task_id: 12,
///   title: "Configure OAuth",
///   state: task_state.Claimed(7, "2026-06-18T10:00:00Z", task_state.Taken),
///   claimed_by: Some("alice@example.com"),
/// )
/// ```
pub type TaskDependency {
  TaskDependency(
    depends_on_task_id: Int,
    title: String,
    state: task_state.TaskExecutionState,
    claimed_by: Option(String),
  )
}

/// Position of a task in the user's pool view.
///
/// ## Example
///
/// ```gleam
/// TaskPosition(task_id: 1, user_id: 1, x: 100, y: 200, updated_at: "2024-01-17T12:00:00Z")
/// ```
pub type TaskPosition {
  TaskPosition(task_id: Int, user_id: Int, x: Int, y: Int, updated_at: String)
}

/// An active work session on a task (multi-session model).
///
/// ## Example
///
/// ```gleam
/// WorkSession(task_id: 1, started_at: "2024-01-17T12:00:00Z", accumulated_s: 3600)
/// ```
pub type WorkSession {
  WorkSession(task_id: Int, started_at: String, accumulated_s: Int)
}

/// Payload containing multiple active work sessions and server timestamp.
///
/// ## Example
///
/// ```gleam
/// WorkSessionsPayload(active_sessions: [session1, session2], as_of: "2024-01-17T12:00:00Z")
/// ```
pub type WorkSessionsPayload {
  WorkSessionsPayload(active_sessions: List(WorkSession), as_of: String)
}

// =============================================================================
// Helpers
// =============================================================================

pub fn with_state(task: Task, state: task_state.TaskExecutionState) -> Task {
  Task(..task, state: state)
}

pub fn dependency_is_closed(dependency: TaskDependency) -> Bool {
  case dependency.state {
    task_state.Closed(..) -> True
    task_state.Available | task_state.Claimed(..) -> False
  }
}

pub fn claimed_by(task: Task) -> Option(Int) {
  task_state.claimed_by(task.state)
}

pub fn claimed_at(task: Task) -> Option(String) {
  task_state.claimed_at(task.state)
}

pub fn closed_at(task: Task) -> Option(String) {
  task_state.closed_at(task.state)
}
