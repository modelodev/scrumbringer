//// Task workflow types for business logic orchestration.
////
//// ## Mission
////
//// Defines message, response, and error types for task workflow operations.
//// These types form the contract between HTTP handlers and business logic.
////
//// ## Responsibilities
////
//// - Define workflow message types
//// - Define response types
//// - Define domain error types
////
//// ## Relations
////
//// - **handlers.gleam**: Uses these types for message handling
//// - **http/tasks.gleam**: Constructs messages and interprets responses

import gleam/option.{type Option}
import pog
import scrumbringer_server/persistence/tasks/mappers as tasks_mappers
import scrumbringer_server/services/task_types_db

// =============================================================================
// Message Types
// =============================================================================

/// Task workflow messages for business logic operations.
pub type Message {
  /// List task types for a project.
  ListTaskTypes(project_id: Int, user_id: Int)

  /// Create a new task type in a project.
  CreateTaskType(
    project_id: Int,
    user_id: Int,
    org_id: Int,
    name: String,
    icon: String,
    capability_id: Option(Int),
  )

  /// List tasks with filters.
  ListTasks(project_id: Int, user_id: Int, filters: TaskFilters)

  /// Create a new task.
  CreateTask(
    project_id: Int,
    user_id: Int,
    org_id: Int,
    title: String,
    description: String,
    priority: Int,
    type_id: Int,
  )

  /// Get a single task.
  GetTask(task_id: Int, user_id: Int)

  /// Update a task (owner only).
  UpdateTask(task_id: Int, user_id: Int, version: Int, updates: TaskUpdates)

  /// Claim an available task.
  ClaimTask(task_id: Int, user_id: Int, org_id: Int, version: Int)

  /// Release a claimed task (owner only).
  ReleaseTask(task_id: Int, user_id: Int, org_id: Int, version: Int)

  /// Complete a claimed task (owner only).
  CompleteTask(task_id: Int, user_id: Int, org_id: Int, version: Int)
}

/// Task list filters.
pub type TaskFilters {
  TaskFilters(status: String, type_id: Int, capability_id: Int, q: String)
}

/// Task update fields (sentinel values indicate no change).
pub type TaskUpdates {
  TaskUpdates(title: String, description: String, priority: Int, type_id: Int)
}

// =============================================================================
// Response Types
// =============================================================================

/// Successful response variants.
pub type Response {
  TaskTypesList(List(task_types_db.TaskType))
  TaskTypeCreated(task_types_db.TaskType)
  TasksList(List(tasks_mappers.Task))
  TaskResult(tasks_mappers.Task)
}

// =============================================================================
// Error Types
// =============================================================================

/// Domain errors for task operations.
pub type Error {
  /// User is not authorized (not a project member/admin).
  NotAuthorized

  /// Resource not found.
  NotFound

  /// Validation error with message.
  ValidationError(String)

  /// Task type name already exists.
  TaskTypeAlreadyExists

  /// Task is already claimed by someone else.
  AlreadyClaimed

  /// Invalid state transition (e.g., release unclaimed task).
  InvalidTransition

  /// Version conflict (optimistic locking).
  VersionConflict

  /// Claim ownership conflict (task claimed by another user).
  ClaimOwnershipConflict(current_claimed_by: Option(Int))

  /// Database error.
  DbError(pog.QueryError)
}

// =============================================================================
// Constants
// =============================================================================

/// Maximum allowed characters for task title.
pub const max_task_title_chars = 56

/// Sentinel value indicating an optional string field was not provided.
pub const unset_string = "__unset__"
