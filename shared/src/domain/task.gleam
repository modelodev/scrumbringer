//// Task domain types for ScrumBringer.
////
//// Defines the core Task type and related structures for task management.
////
//// ## Usage
////
//// ```gleam
//// import shared/domain/task.{type Task, type TaskFilters}
//// import shared/domain/task_status.{type TaskStatus}
////
//// let filters = TaskFilters(status: Some("available"), type_id: None, capability_id: None, q: None)
//// ```

import domain/task_status.{type OngoingBy, type TaskStatus, type WorkState}
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
///   status: Available,
///   work_state: WorkAvailable,
///   created_by: 1,
///   claimed_by: None,
///   claimed_at: None,
///   completed_at: None,
///   created_at: "2024-01-17T12:00:00Z",
///   version: 1,
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
    status: TaskStatus,
    work_state: WorkState,
    created_by: Int,
    claimed_by: Option(Int),
    claimed_at: Option(String),
    completed_at: Option(String),
    created_at: String,
    version: Int,
    // Card (ficha) association
    card_id: Option(Int),
    card_title: Option(String),
    card_color: Option(String),
    /// Story 5.4 AC4: True if task has notes newer than user's last view.
    has_new_notes: Bool,
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

/// Currently active task for a user (legacy single-session type).
///
/// ## Example
///
/// ```gleam
/// ActiveTask(task_id: 1, project_id: 1, started_at: "2024-01-17T12:00:00Z", accumulated_s: 3600)
/// ```
pub type ActiveTask {
  ActiveTask(
    task_id: Int,
    project_id: Int,
    started_at: String,
    accumulated_s: Int,
  )
}

/// Payload containing active task and server timestamp (legacy single-session).
///
/// ## Example
///
/// ```gleam
/// ActiveTaskPayload(active_task: Some(active_task), as_of: "2024-01-17T12:00:00Z")
/// ```
pub type ActiveTaskPayload {
  ActiveTaskPayload(active_task: Option(ActiveTask), as_of: String)
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
/// TaskFilters(status: Some("available"), type_id: None, capability_id: Some(1), q: None)
/// ```
pub type TaskFilters {
  TaskFilters(
    status: Option(String),
    type_id: Option(Int),
    capability_id: Option(Int),
    q: Option(String),
  )
}
