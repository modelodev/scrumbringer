//// Task row mappers for converting SQL rows to domain types.
////
//// ## Mission
////
//// Provides mapping functions to convert database row types from squirrel-generated
//// SQL modules into domain Task records with type-safe status handling.
////
//// ## Responsibilities
////
//// - Convert SQL row types to Task records
//// - Handle nullable field mapping (Int/String → Option)
//// - Parse status strings into TaskStatus ADT
////
//// ## Non-responsibilities
////
//// - Database queries (see `queries.gleam`)
//// - Business logic (see `services/task_workflow_actor.gleam`)
////
//// ## Relations
////
//// - **queries.gleam**: Uses these mappers after DB queries
//// - **sql.gleam**: Provides row types from squirrel
//// - **domain/task_status**: Provides TaskStatus ADT

import domain/task.{type TaskDependency, TaskDependency}
import domain/task_status
import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option, None, Some}
import scrumbringer_server/sql

/// Task record with type-safe status.
///
/// The `status` field uses the `TaskStatus` ADT instead of strings,
/// enabling compile-time verification of status handling.
pub type Task {
  Task(
    id: Int,
    project_id: Int,
    type_id: Int,
    type_name: String,
    type_icon: String,
    title: String,
    description: Option(String),
    priority: Int,
    status: task_status.TaskStatus,
    ongoing_by_user_id: Option(Int),
    created_by: Int,
    claimed_by: Option(Int),
    claimed_at: Option(String),
    completed_at: Option(String),
    created_at: String,
    version: Int,
    card_id: Option(Int),
    card_title: Option(String),
    card_color: Option(String),
    /// Story 5.4 AC4: True if task has notes newer than user's last view.
    has_new_notes: Bool,
    /// Story 5.6: Number of incomplete dependencies blocking this task.
    blocked_count: Int,
    /// Story 5.6: Dependencies blocking this task.
    dependencies: List(TaskDependency),
  )
}

/// Map a list query row to Task.
pub fn from_list_row(row: sql.TasksListRow) -> Task {
  from_fields(
    id: row.id,
    project_id: row.project_id,
    type_id: row.type_id,
    type_name: row.type_name,
    type_icon: row.type_icon,
    title: row.title,
    description: row.description,
    priority: row.priority,
    status: row.status,
    is_ongoing: row.is_ongoing,
    ongoing_by_user_id: row.ongoing_by_user_id,
    created_by: row.created_by,
    claimed_by: row.claimed_by,
    claimed_at: row.claimed_at,
    completed_at: row.completed_at,
    created_at: row.created_at,
    version: row.version,
    card_id: row.card_id,
    card_title: row.card_title,
    card_color: row.card_color,
    has_new_notes: row.has_new_notes,
    blocked_count: row.blocked_count,
    dependencies: decode_dependencies(row.dependencies),
  )
}

/// Map a get query row to Task.
pub fn from_get_row(row: sql.TasksGetForUserRow) -> Task {
  from_fields(
    id: row.id,
    project_id: row.project_id,
    type_id: row.type_id,
    type_name: row.type_name,
    type_icon: row.type_icon,
    title: row.title,
    description: row.description,
    priority: row.priority,
    status: row.status,
    is_ongoing: row.is_ongoing,
    ongoing_by_user_id: row.ongoing_by_user_id,
    created_by: row.created_by,
    claimed_by: row.claimed_by,
    claimed_at: row.claimed_at,
    completed_at: row.completed_at,
    created_at: row.created_at,
    version: row.version,
    card_id: row.card_id,
    card_title: row.card_title,
    card_color: row.card_color,
    has_new_notes: False,
    blocked_count: row.blocked_count,
    dependencies: decode_dependencies(row.dependencies),
  )
}

/// Map a create query row to Task.
pub fn from_create_row(row: sql.TasksCreateRow) -> Task {
  from_fields(
    id: row.id,
    project_id: row.project_id,
    type_id: row.type_id,
    type_name: row.type_name,
    type_icon: row.type_icon,
    title: row.title,
    description: row.description,
    priority: row.priority,
    status: row.status,
    is_ongoing: row.is_ongoing,
    ongoing_by_user_id: row.ongoing_by_user_id,
    created_by: row.created_by,
    claimed_by: row.claimed_by,
    claimed_at: row.claimed_at,
    completed_at: row.completed_at,
    created_at: row.created_at,
    version: row.version,
    card_id: row.card_id,
    card_title: row.card_title,
    card_color: row.card_color,
    has_new_notes: False,
    blocked_count: row.blocked_count,
    dependencies: decode_dependencies(row.dependencies),
  )
}

/// Map an update query row to Task.
pub fn from_update_row(row: sql.TasksUpdateRow) -> Task {
  from_fields(
    id: row.id,
    project_id: row.project_id,
    type_id: row.type_id,
    type_name: row.type_name,
    type_icon: row.type_icon,
    title: row.title,
    description: row.description,
    priority: row.priority,
    status: row.status,
    is_ongoing: row.is_ongoing,
    ongoing_by_user_id: row.ongoing_by_user_id,
    created_by: row.created_by,
    claimed_by: row.claimed_by,
    claimed_at: row.claimed_at,
    completed_at: row.completed_at,
    created_at: row.created_at,
    version: row.version,
    card_id: row.card_id,
    card_title: row.card_title,
    card_color: row.card_color,
    has_new_notes: False,
    blocked_count: row.blocked_count,
    dependencies: decode_dependencies(row.dependencies),
  )
}

/// Map a claim query row to Task.
pub fn from_claim_row(row: sql.TasksClaimRow) -> Task {
  from_fields(
    id: row.id,
    project_id: row.project_id,
    type_id: row.type_id,
    type_name: row.type_name,
    type_icon: row.type_icon,
    title: row.title,
    description: row.description,
    priority: row.priority,
    status: row.status,
    is_ongoing: row.is_ongoing,
    ongoing_by_user_id: row.ongoing_by_user_id,
    created_by: row.created_by,
    claimed_by: row.claimed_by,
    claimed_at: row.claimed_at,
    completed_at: row.completed_at,
    created_at: row.created_at,
    version: row.version,
    card_id: row.card_id,
    card_title: row.card_title,
    card_color: row.card_color,
    has_new_notes: False,
    blocked_count: row.blocked_count,
    dependencies: decode_dependencies(row.dependencies),
  )
}

/// Map a release query row to Task.
pub fn from_release_row(row: sql.TasksReleaseRow) -> Task {
  from_fields(
    id: row.id,
    project_id: row.project_id,
    type_id: row.type_id,
    type_name: row.type_name,
    type_icon: row.type_icon,
    title: row.title,
    description: row.description,
    priority: row.priority,
    status: row.status,
    is_ongoing: row.is_ongoing,
    ongoing_by_user_id: row.ongoing_by_user_id,
    created_by: row.created_by,
    claimed_by: row.claimed_by,
    claimed_at: row.claimed_at,
    completed_at: row.completed_at,
    created_at: row.created_at,
    version: row.version,
    card_id: row.card_id,
    card_title: row.card_title,
    card_color: row.card_color,
    has_new_notes: False,
    blocked_count: row.blocked_count,
    dependencies: decode_dependencies(row.dependencies),
  )
}

/// Map a complete query row to Task.
pub fn from_complete_row(row: sql.TasksCompleteRow) -> Task {
  from_fields(
    id: row.id,
    project_id: row.project_id,
    type_id: row.type_id,
    type_name: row.type_name,
    type_icon: row.type_icon,
    title: row.title,
    description: row.description,
    priority: row.priority,
    status: row.status,
    is_ongoing: row.is_ongoing,
    ongoing_by_user_id: row.ongoing_by_user_id,
    created_by: row.created_by,
    claimed_by: row.claimed_by,
    claimed_at: row.claimed_at,
    completed_at: row.completed_at,
    created_at: row.created_at,
    version: row.version,
    card_id: row.card_id,
    card_title: row.card_title,
    card_color: row.card_color,
    has_new_notes: False,
    blocked_count: row.blocked_count,
    dependencies: decode_dependencies(row.dependencies),
  )
}

/// Internal: construct Task from raw field values.
fn from_fields(
  id id: Int,
  project_id project_id: Int,
  type_id type_id: Int,
  type_name type_name: String,
  type_icon type_icon: String,
  title title: String,
  description description: String,
  priority priority: Int,
  status status: String,
  is_ongoing is_ongoing: Bool,
  ongoing_by_user_id ongoing_by_user_id: Int,
  created_by created_by: Int,
  claimed_by claimed_by: Int,
  claimed_at claimed_at: String,
  completed_at completed_at: String,
  created_at created_at: String,
  version version: Int,
  card_id card_id: Int,
  card_title card_title: String,
  card_color card_color: String,
  has_new_notes has_new_notes: Bool,
  blocked_count blocked_count: Int,
  dependencies dependencies: List(TaskDependency),
) -> Task {
  Task(
    id: id,
    project_id: project_id,
    type_id: type_id,
    type_name: type_name,
    type_icon: type_icon,
    title: title,
    description: string_option(description),
    priority: priority,
    status: task_status.from_db(status, is_ongoing),
    ongoing_by_user_id: int_option(ongoing_by_user_id),
    created_by: created_by,
    claimed_by: int_option(claimed_by),
    claimed_at: string_option(claimed_at),
    completed_at: string_option(completed_at),
    created_at: created_at,
    version: version,
    card_id: int_option(card_id),
    card_title: string_option(card_title),
    card_color: string_option(card_color),
    has_new_notes: has_new_notes,
    blocked_count: blocked_count,
    dependencies: dependencies,
  )
}

fn decode_dependencies(raw: String) -> List(TaskDependency) {
  case json.parse(from: raw, using: decode.list(task_dependency_decoder())) {
    Ok(deps) -> deps
    Error(_) -> []
  }
}

fn task_dependency_decoder() -> decode.Decoder(TaskDependency) {
  use depends_on_task_id <- decode.field("task_id", decode.int)
  use title <- decode.field("title", decode.string)
  use status_str <- decode.field("status", decode.string)
  use claimed_by <- decode.optional_field(
    "claimed_by",
    None,
    decode.optional(decode.string),
  )
  let status = case task_status.parse_task_status(status_str) {
    Ok(s) -> s
    Error(_) -> task_status.Available
  }
  decode.success(TaskDependency(
    depends_on_task_id: depends_on_task_id,
    title: title,
    status: status,
    claimed_by: claimed_by,
  ))
}

/// Convert 0 to None, non-zero to Some.
fn int_option(value: Int) -> Option(Int) {
  case value {
    0 -> None
    v -> Some(v)
  }
}

/// Convert empty string to None, non-empty to Some.
fn string_option(value: String) -> Option(String) {
  case value {
    "" -> None
    v -> Some(v)
  }
}
