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

import domain/field_update
import domain/task_status
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

  /// Update an existing task type.
  /// Story 4.9 AC13
  UpdateTaskType(
    type_id: Int,
    user_id: Int,
    name: String,
    icon: String,
    capability_id: Option(Int),
  )

  /// Delete a task type (only if no tasks use it).
  /// Story 4.9 AC14
  DeleteTaskType(type_id: Int, user_id: Int)

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
    card_id: Option(Int),
    milestone_id: Option(Int),
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
  TaskFilters(
    status: Option(TaskStatus),
    type_id: Option(Int),
    capability_id: Option(Int),
    q: Option(String),
    blocked: Option(Bool),
  )
}

/// Task status ADT for typed status handling.
pub type TaskStatus =
  task_status.TaskStatus

/// Task update fields (ADT-based, no sentinels).
pub type TaskUpdates {
  TaskUpdates(
    title: field_update.FieldUpdate(String),
    description: field_update.FieldUpdate(String),
    priority: field_update.FieldUpdate(Int),
    type_id: field_update.FieldUpdate(Int),
    milestone_id: field_update.FieldUpdate(Option(Int)),
  )
}

// =============================================================================
// Response Types
// =============================================================================

/// Successful response variants.
pub type Response {
  TaskTypesList(List(task_types_db.TaskType))
  TaskTypeCreated(task_types_db.TaskType)
  TaskTypeUpdated(task_types_db.TaskType)
  TaskTypeDeleted(Int)
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

  /// Milestone cannot be explicitly set when task belongs to a card.
  TaskMilestoneInheritedFromCard

  /// Invalid movement between pool and milestone lanes.
  InvalidMovePoolToMilestone

  /// Task type name already exists.
  TaskTypeAlreadyExists

  /// Task type has tasks associated (cannot delete).
  /// Story 4.9 AC14, AC23
  TaskTypeInUse

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
