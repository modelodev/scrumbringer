//// Task operation types for business logic orchestration.
////
//// ## Mission
////
//// Defines message, response, and error types for task operations.
//// These types form the contract between HTTP handlers and business logic.
////
//// ## Responsibilities
////
//// - Define task operation message types
//// - Define response types
//// - Define domain error types
////
//// ## Relations
////
//// - **handlers.gleam**: Uses these types for message handling
//// - **http/tasks.gleam**: Constructs messages and interprets responses

import domain/field_update
import domain/task as domain_task
import domain/task/state as task_state
import gleam/option.{type Option}
import pog
import scrumbringer_server/use_case/task_types_db

// =============================================================================
// Message Types
// =============================================================================

/// Task operation messages for business logic operations.
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
    parent_card_id: Option(Int),
  )

  /// Get a single task.
  GetTask(task_id: Int, user_id: Int)

  /// Update task fields. Available tasks are editable by project members;
  /// claimed tasks are editable only by the claiming user.
  UpdateTask(
    task_id: Int,
    user_id: Int,
    org_id: Int,
    version: Int,
    updates: TaskUpdates,
  )

  /// Delete a task only when it has no operational history.
  DeleteTask(task_id: Int, user_id: Int)

  /// Claim an available task.
  ClaimTask(task_id: Int, user_id: Int, org_id: Int, version: Int)

  /// Release a claimed task (owner only).
  ReleaseTask(task_id: Int, user_id: Int, org_id: Int, version: Int)

  /// Close a claimed task (owner only).
  CloseTask(task_id: Int, user_id: Int, org_id: Int, version: Int)
}

/// Task list filters.
pub type TaskFilters {
  TaskFilters(
    status: Option(task_state.TaskExecutionStateFilter),
    type_id: Option(Int),
    capability_id: Option(Int),
    q: Option(String),
    blocked: Option(Bool),
  )
}

/// Task update fields (ADT-based, no sentinels).
pub type TaskUpdates {
  TaskUpdates(
    title: field_update.FieldUpdate(String),
    description: field_update.FieldUpdate(String),
    priority: field_update.FieldUpdate(Int),
    type_id: field_update.FieldUpdate(Int),
    parent_card_id: field_update.FieldUpdate(Option(Int)),
    card_id: field_update.FieldUpdate(Option(Int)),
    due_date: field_update.FieldUpdate(Option(String)),
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
  TasksList(List(domain_task.Task))
  TaskResult(domain_task.Task)
  TaskDeleted(Int)
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

  /// Parent card cannot be explicitly set when task belongs to a card.
  TaskParentCardInheritedFromCard

  /// Task cannot be created in a card that already contains child cards.
  CardHasChildCards

  /// Invalid movement between pool and parent card lanes.
  InvalidMovePoolToParentCard

  /// Task type name already exists.
  TaskTypeAlreadyExists

  /// Task type has tasks associated (cannot delete).
  /// Story 4.9 AC14, AC23
  TaskTypeInUse

  /// Task is already claimed by someone else.
  AlreadyClaimed

  /// Task cannot be claimed while dependencies are open.
  TaskBlockedByDependencies(blocked_count: Int)

  /// Task is not currently released to the Pool.
  TaskNotClaimable

  /// Task card lineage is not active and cannot be claimed.
  TaskCardNotActive

  /// Task has operational history and must be closed instead of deleted.
  TaskHasOperationalHistory

  /// Invalid state transition (e.g., release unclaimed task).
  InvalidTransition

  /// Version conflict (optimistic locking).
  VersionConflict

  /// Claim ownership conflict (task claimed by another user).
  ClaimOwnershipConflict(current_claimed_by: Option(Int))

  /// Database error.
  DbError(pog.QueryError)
}
