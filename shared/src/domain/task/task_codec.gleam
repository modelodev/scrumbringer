//// Task JSON decoders.

import gleam/dynamic/decode
import gleam/option

import domain/card/card_codec
import domain/task.{
  type Task, type TaskDependency, type TaskNote, type TaskPosition,
  type WorkSession, type WorkSessionsPayload, Task, TaskDependency, TaskNote,
  TaskPosition, WorkSession, WorkSessionsPayload,
}
import domain/task_state
import domain/task_status.{
  type OngoingBy, type WorkState, Available, OngoingBy, WorkAvailable,
  parse_task_status, parse_work_state,
}
import domain/task_type.{
  type TaskType, type TaskTypeInline, TaskType, TaskTypeInline,
}

// =============================================================================
// Task Type Decoders
// =============================================================================

/// Decoder for TaskType.
/// Story 4.9 AC15: Added tasks_count field.
pub fn task_type_decoder() -> decode.Decoder(TaskType) {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  use icon <- decode.field("icon", decode.string)

  use capability_id <- decode.optional_field(
    "capability_id",
    option.None,
    decode.optional(decode.int),
  )

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
  use raw <- decode.then(decode.string)
  case parse_work_state(raw) {
    Ok(state) -> decode.success(state)
    Error(_) -> decode.failure(WorkAvailable, "WorkState")
  }
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

  use ongoing_by <- decode.optional_field(
    "ongoing_by",
    option.None,
    decode.optional(ongoing_by_decoder()),
  )

  use title <- decode.field("title", decode.string)

  use description <- decode.optional_field(
    "description",
    option.None,
    decode.optional(decode.string),
  )

  use priority <- decode.field("priority", decode.int)

  use status_raw <- decode.field("status", decode.string)

  use created_by <- decode.field("created_by", decode.int)

  use claimed_by <- decode.optional_field(
    "claimed_by",
    option.None,
    decode.optional(decode.int),
  )
  use claimed_at <- decode.optional_field(
    "claimed_at",
    option.None,
    decode.optional(decode.string),
  )
  use completed_at <- decode.optional_field(
    "completed_at",
    option.None,
    decode.optional(decode.string),
  )

  let is_ongoing = status_raw == "ongoing"
  use state <- decode.then(task_state_decoder_from_fields(
    status_raw,
    is_ongoing,
    claimed_by,
    claimed_at,
    completed_at,
  ))

  use created_at <- decode.field("created_at", decode.string)
  use due_date <- decode.optional_field(
    "due_date",
    option.None,
    decode.optional(decode.string),
  )
  use version <- decode.field("version", decode.int)
  use parent_card_id <- decode.optional_field(
    "parent_card_id",
    option.None,
    decode.optional(decode.int),
  )

  // Card (ficha) association - optional fields
  use card_id <- decode.optional_field(
    "card_id",
    option.None,
    decode.optional(decode.int),
  )
  use card_title <- decode.optional_field(
    "card_title",
    option.None,
    decode.optional(decode.string),
  )
  use card_color <- decode.optional_field(
    "card_color",
    option.None,
    card_codec.optional_color_decoder(),
  )

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
    created_by: created_by,
    created_at: created_at,
    due_date: due_date,
    version: version,
    parent_card_id: parent_card_id,
    card_id: card_id,
    card_title: card_title,
    card_color: card_color,
    has_new_notes: has_new_notes,
    blocked_count: blocked_count,
    dependencies: dependencies,
  ))
}

pub fn task_state_decoder_from_fields(
  status_raw: String,
  is_ongoing: Bool,
  claimed_by: option.Option(Int),
  claimed_at: option.Option(String),
  completed_at: option.Option(String),
) -> decode.Decoder(task_state.TaskState) {
  case
    task_state.from_db(
      status_raw,
      is_ongoing,
      claimed_by,
      claimed_at,
      completed_at,
    )
  {
    Ok(state) -> decode.success(state)
    Error(_) -> decode.failure(task_state.Available, "TaskState")
  }
}

/// Decoder for TaskDependency.
pub fn task_dependency_decoder() -> decode.Decoder(TaskDependency) {
  use depends_on_task_id <- decode.field("task_id", decode.int)
  use title <- decode.field("title", decode.string)
  use status_raw <- decode.field("status", decode.string)
  use claimed_by <- decode.optional_field(
    "claimed_by",
    option.None,
    decode.optional(decode.string),
  )

  case parse_task_status(status_raw) {
    Ok(status) ->
      decode.success(TaskDependency(
        depends_on_task_id: depends_on_task_id,
        title: title,
        status: status,
        claimed_by: claimed_by,
      ))
    Error(_) ->
      decode.failure(
        TaskDependency(
          depends_on_task_id: depends_on_task_id,
          title: title,
          status: Available,
          claimed_by: claimed_by,
        ),
        "TaskDependency.status",
      )
  }
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
  use accumulated <- decode.optional_field(
    "accumulated_s",
    option.None,
    decode.optional(decode.int),
  )

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
