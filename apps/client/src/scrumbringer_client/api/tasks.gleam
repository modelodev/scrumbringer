//// Tasks API functions for Scrumbringer client.
////
//// ## Mission
////
//// Provides unified access to task management API operations including listing,
//// creating, claiming, releasing, completing tasks, and managing task positions.
////
//// ## Responsibilities
////
//// - Re-export task API functions from split modules
//// - Re-export domain types for backwards compatibility
////
//// ## Usage
////
//// ```gleam
//// import scrumbringer_client/api/tasks
////
//// tasks.list_project_tasks(project_id, filters, TasksFetched)
//// tasks.claim_task(task_id, version, TaskClaimed)
//// tasks.complete_task(task_id, version, TaskCompleted)
//// ```
////
//// ## Relations
////
//// - **tasks/decoders.gleam**: JSON decoders for task types
//// - **tasks/operations.gleam**: Core task CRUD operations
//// - **tasks/task_types.gleam**: Task type API functions
//// - **tasks/notes.gleam**: Task notes API functions
//// - **tasks/active.gleam**: Active task API functions
//// - **tasks/positions.gleam**: Task position API functions
//// - **tasks/capabilities.gleam**: User capability API functions

// Re-export domain types for backwards compatibility
import domain/task.{
  type ActiveTask, type ActiveTaskPayload, type Task, type TaskFilters,
  type TaskNote, type TaskPosition,
}
import domain/task_status
import domain/task_type.{type TaskType, type TaskTypeInline}

// Import split modules for re-export
import scrumbringer_client/api/tasks/active
import scrumbringer_client/api/tasks/capabilities
import scrumbringer_client/api/tasks/decoders
import scrumbringer_client/api/tasks/notes
import scrumbringer_client/api/tasks/operations
import scrumbringer_client/api/tasks/positions
import scrumbringer_client/api/tasks/task_types

// =============================================================================
// Re-export Types (for module documentation)
// =============================================================================

// These type aliases are here for documentation purposes to show what types
// this module provides access to. The actual types are imported directly
// from the domain modules.

pub type TaskAlias =
  Task

pub type TaskFiltersAlias =
  TaskFilters

pub type TaskNoteAlias =
  TaskNote

pub type TaskPositionAlias =
  TaskPosition

pub type ActiveTaskAlias =
  ActiveTask

pub type ActiveTaskPayloadAlias =
  ActiveTaskPayload

pub type TaskTypeAlias =
  TaskType

pub type TaskTypeInlineAlias =
  TaskTypeInline

// =============================================================================
// Re-export Functions: Status
// =============================================================================

pub const parse_task_status = task_status.parse_task_status

pub const task_status_to_string = task_status.task_status_to_string

// =============================================================================
// Re-export Functions: Decoders
// =============================================================================

pub const task_decoder = decoders.task_decoder

pub const active_task_payload_decoder = decoders.active_task_payload_decoder

// =============================================================================
// Re-export Functions: Task Types
// =============================================================================

pub const list_task_types = task_types.list_task_types

pub const create_task_type = task_types.create_task_type

// Story 4.9 AC13-14: Update and delete task types
pub const update_task_type = task_types.update_task_type

pub const delete_task_type = task_types.delete_task_type

// =============================================================================
// Re-export Functions: Operations
// =============================================================================

pub const project_tasks_url = operations.project_tasks_url

pub const list_project_tasks = operations.list_project_tasks

pub const create_task = operations.create_task

pub const create_task_with_card = operations.create_task_with_card

pub const claim_task = operations.claim_task

pub const release_task = operations.release_task

pub const complete_task = operations.complete_task

// =============================================================================
// Re-export Functions: Notes
// =============================================================================

pub const list_task_notes = notes.list_task_notes

pub const add_task_note = notes.add_task_note

// =============================================================================
// Re-export Functions: Work Sessions (multi-session)
// =============================================================================

pub const get_work_sessions = active.get_work_sessions

pub const start_work_session = active.start_work_session

pub const pause_work_session = active.pause_work_session

pub const heartbeat_work_session = active.heartbeat_work_session

// =============================================================================
// Re-export Functions: Active Task (legacy - deprecated)
// =============================================================================

pub const get_me_active_task = active.get_me_active_task

pub const start_me_active_task = active.start_me_active_task

pub const pause_me_active_task = active.pause_me_active_task

pub const heartbeat_me_active_task = active.heartbeat_me_active_task

// =============================================================================
// Re-export Functions: Positions
// =============================================================================

pub const list_me_task_positions = positions.list_me_task_positions

pub const upsert_me_task_position = positions.upsert_me_task_position

// =============================================================================
// Re-export Functions: Capabilities (Project-Scoped)
// =============================================================================

pub const get_member_capability_ids = capabilities.get_member_capability_ids

pub const put_member_capability_ids = capabilities.put_member_capability_ids
