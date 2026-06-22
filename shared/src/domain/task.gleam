//// Task domain types for ScrumBringer.
////
//// Defines the core Task type and related structures for task management.
////
//// ## Usage
////
//// ```gleam
//// import shared/domain/task.{type Task, type TaskFilters}
//// import shared/domain/task_status.{type TaskPhase}
////
//// let filters = TaskFilters(status: Some(Available), type_id: None, capability_id: None, q: None)
//// ```

import domain/card
import domain/task_state
import domain/task_status.{type OngoingBy, type TaskPhase, type WorkState}
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
    state: task_state.TaskState,
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
    /// Story 5.6: Number of incomplete dependencies blocking this task.
    blocked_count: Int,
    /// Story 5.6: Dependencies blocking this task.
    dependencies: List(TaskDependency),
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
///   status: Claimed(Taken),
///   claimed_by: Some("alice@example.com"),
/// )
/// ```
pub type TaskDependency {
  TaskDependency(
    depends_on_task_id: Int,
    title: String,
    status: TaskPhase,
    claimed_by: Option(String),
  )
}

/// A note on a task.
///
/// ## Example
///
/// ```gleam
/// TaskNote(
///   id: 1,
///   task_id: 1,
///   user_id: 1,
///   content: "Added more details",
///   created_at: "2024-01-17T12:00:00Z",
/// )
/// ```
pub type TaskNote {
  TaskNote(
    id: Int,
    task_id: Int,
    user_id: Int,
    content: String,
    created_at: String,
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

/// Filters for listing tasks.
///
/// ## Example
///
/// ```gleam
/// TaskFilters(status: Some(Available), type_id: None, capability_id: Some(1), q: None, blocked: None)
/// ```
pub type TaskFilters {
  TaskFilters(
    status: Option(TaskPhase),
    type_id: Option(Int),
    capability_id: Option(Int),
    q: Option(String),
    blocked: Option(Bool),
  )
}

// =============================================================================
// Helpers
// =============================================================================

pub fn with_state(task: Task, state: task_state.TaskState) -> Task {
  Task(..task, state: state)
}

pub fn status(task: Task) -> TaskPhase {
  task_state.to_status(task.state)
}

pub fn work_state(task: Task) -> WorkState {
  task_state.to_work_state(task.state)
}

pub fn claimed_by(task: Task) -> Option(Int) {
  task_state.claimed_by(task.state)
}

pub fn claimed_at(task: Task) -> Option(String) {
  task_state.claimed_at(task.state)
}

pub fn completed_at(task: Task) -> Option(String) {
  task_state.completed_at(task.state)
}
