//// Task API decoders.
////
//// ## Mission
////
//// Provides JSON decoders for task-related domain types.
////
//// ## Responsibilities
////
//// - Decode Task, TaskType, TaskNote, TaskPosition
//// - Decode WorkSession and WorkSessionsPayload
//// - Map status strings to domain types
////
//// ## Relations
////
//// - **../tasks.gleam**: Main API module that uses these decoders
//// - **domain/task.gleam**: Domain types being decoded

import gleam/dynamic/decode
import gleam/option

import scrumbringer_client/api/core.{optional_field}

import domain/task.{
  type Task, type TaskDependency, type TaskNote, type TaskPosition,
  type WorkSession, type WorkSessionsPayload, Task, TaskDependency, TaskNote,
  TaskPosition, WorkSession, WorkSessionsPayload,
}
import domain/task_state
import domain/task_status.{
  type OngoingBy, type WorkState, Available, OngoingBy, WorkAvailable,
  WorkClaimed, WorkCompleted, WorkOngoing,
}
import domain/task_type.{
  type TaskType, type TaskTypeInline, TaskType, TaskTypeInline,
}

// Re-export parse_task_status for use in decoders
pub const parse_task_status = task_status.parse_task_status

// =============================================================================
// Task Type Decoders
// =============================================================================

/// Decoder for TaskType.
/// Story 4.9 AC15: Added tasks_count field.
pub fn task_type_decoder() -> decode.Decoder(TaskType) {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  use icon <- decode.field("icon", decode.string)

  use capability_id <- optional_field("capability_id", decode.int)

  use tasks_count <- decode.optional_field("tasks_count", 0, decode.int)

  decode.success(TaskType(
    id: id,
    name: name,
    icon: icon,
    capability_id: capability_id,
    tasks_count: tasks_count,
  ))
}

/// Decoder for TaskTypeInline.
pub fn task_type_inline_decoder() -> decode.Decoder(TaskTypeInline) {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  use icon <- decode.field("icon", decode.string)
  decode.success(TaskTypeInline(id: id, name: name, icon: icon))
}

// =============================================================================
// Task Status Decoders
// =============================================================================

/// Decoder for OngoingBy.
pub fn ongoing_by_decoder() -> decode.Decoder(OngoingBy) {
  use user_id <- decode.field("user_id", decode.int)
  decode.success(OngoingBy(user_id: user_id))
}

/// Decoder for WorkState.
pub fn work_state_decoder() -> decode.Decoder(WorkState) {
  decode.string
  |> decode.map(fn(raw) {
    case raw {
      "available" -> WorkAvailable
      "claimed" -> WorkClaimed
      "ongoing" -> WorkOngoing
      "completed" -> WorkCompleted
      _ -> WorkClaimed
    }
  })
}

// =============================================================================
// Task Decoder
// =============================================================================

/// Decoder for Task type.
pub fn task_decoder() -> decode.Decoder(Task) {
  use id <- decode.field("id", decode.int)
  use project_id <- decode.field("project_id", decode.int)
  use type_id <- decode.field("type_id", decode.int)

  use task_type <- decode.field("task_type", task_type_inline_decoder())

  use ongoing_by <- optional_field("ongoing_by", ongoing_by_decoder())

  use title <- decode.field("title", decode.string)

  use description <- optional_field("description", decode.string)

  use priority <- decode.field("priority", decode.int)

  use status_raw <- decode.field("status", decode.string)

  use created_by <- decode.field("created_by", decode.int)

  use claimed_by <- optional_field("claimed_by", decode.int)
  use claimed_at <- optional_field("claimed_at", decode.string)
  use completed_at <- optional_field("completed_at", decode.string)

  let is_ongoing = status_raw == "ongoing"
  let state = case
    task_state.from_db(
      status_raw,
      is_ongoing,
      claimed_by,
      claimed_at,
      completed_at,
    )
  {
    Ok(s) -> s
    Error(_) -> task_state.Available
  }
  let status = task_state.to_status(state)
  let work_state = task_state.to_work_state(state)

  use created_at <- decode.field("created_at", decode.string)
  use version <- decode.field("version", decode.int)

  // Card (ficha) association - optional fields
  use card_id <- optional_field("card_id", decode.int)
  use card_title <- optional_field("card_title", decode.string)
  use card_color <- optional_field("card_color", decode.string)

  // Story 5.4 AC4: has_new_notes indicator
  use has_new_notes <- decode.optional_field(
    "has_new_notes",
    False,
    decode.bool,
  )

  // Story 5.6: blocked count + dependencies list
  use blocked_count <- decode.optional_field("blocked_count", 0, decode.int)
  use dependencies <- decode.optional_field(
    "dependencies",
    [],
    decode.list(task_dependency_decoder()),
  )

  decode.success(Task(
    id: id,
    project_id: project_id,
    type_id: type_id,
    task_type: task_type,
    ongoing_by: ongoing_by,
    title: title,
    description: description,
    priority: priority,
    state: state,
    status: status,
    work_state: work_state,
    created_by: created_by,
    created_at: created_at,
    version: version,
    card_id: card_id,
    card_title: card_title,
    card_color: card_color,
    has_new_notes: has_new_notes,
    blocked_count: blocked_count,
    dependencies: dependencies,
  ))
}

/// Decoder for TaskDependency.
pub fn task_dependency_decoder() -> decode.Decoder(TaskDependency) {
  use depends_on_task_id <- decode.field("task_id", decode.int)
  use title <- decode.field("title", decode.string)
  use status_raw <- decode.field("status", decode.string)
  let status = case parse_task_status(status_raw) {
    Ok(s) -> s
    Error(_) -> Available
  }
  use claimed_by <- optional_field("claimed_by", decode.string)

  decode.success(TaskDependency(
    depends_on_task_id: depends_on_task_id,
    title: title,
    status: status,
    claimed_by: claimed_by,
  ))
}

// =============================================================================
// Task Note Decoder
// =============================================================================

/// Decoder for TaskNote.
pub fn note_decoder() -> decode.Decoder(TaskNote) {
  use id <- decode.field("id", decode.int)
  use task_id <- decode.field("task_id", decode.int)
  use user_id <- decode.field("user_id", decode.int)
  use content <- decode.field("content", decode.string)
  use created_at <- decode.field("created_at", decode.string)

  decode.success(TaskNote(
    id: id,
    task_id: task_id,
    user_id: user_id,
    content: content,
    created_at: created_at,
  ))
}

// =============================================================================
// Task Position Decoder
// =============================================================================

/// Decoder for TaskPosition.
pub fn position_decoder() -> decode.Decoder(TaskPosition) {
  use task_id <- decode.field("task_id", decode.int)
  use user_id <- decode.field("user_id", decode.int)
  use x <- decode.field("x", decode.int)
  use y <- decode.field("y", decode.int)
  use updated_at <- decode.field("updated_at", decode.string)

  decode.success(TaskPosition(
    task_id: task_id,
    user_id: user_id,
    x: x,
    y: y,
    updated_at: updated_at,
  ))
}

// =============================================================================
// Work Sessions Decoders (Multi-Session Model)
// =============================================================================

/// Decoder for WorkSession.
pub fn work_session_decoder() -> decode.Decoder(WorkSession) {
  use task_id <- decode.field("task_id", decode.int)
  use started_at <- decode.field("started_at", decode.string)
  use accumulated <- optional_field("accumulated_s", decode.int)

  let accumulated_s = case accumulated {
    option.Some(v) -> v
    option.None -> 0
  }

  decode.success(WorkSession(
    task_id: task_id,
    started_at: started_at,
    accumulated_s: accumulated_s,
  ))
}

/// Decoder for work sessions payload.
pub fn work_sessions_payload_decoder() -> decode.Decoder(WorkSessionsPayload) {
  use active_sessions <- decode.field(
    "active_sessions",
    decode.list(work_session_decoder()),
  )
  use as_of <- decode.field("as_of", decode.string)
  decode.success(WorkSessionsPayload(
    active_sessions: active_sessions,
    as_of: as_of,
  ))
}
