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
//// - Parse task execution state into the canonical lifecycle ADT
////
//// ## Non-responsibilities
////
//// - Database queries (see `queries.gleam`)
//// - Task automation coordination (see `use_case/workflows/handlers.gleam`)
////
//// ## Relations
////
//// - **queries.gleam**: Uses these mappers after DB queries
//// - **sql.gleam**: Provides row types from squirrel
//// - **domain/task/state**: Provides canonical task execution state

import domain/card
import domain/task.{
  type AutomationOrigin, type OngoingBy, type Task, type TaskDependency,
  AutomationOrigin, OngoingBy, Task, TaskDependency,
}
import domain/task/state as task_state
import domain/task_type.{TaskTypeInline}
import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option, None, Some}
import gleam/result
import helpers/option as option_helpers
import scrumbringer_server/sql
import scrumbringer_server/use_case/service_error.{type ServiceError, Unexpected}

/// Map a list query row to Task.
pub fn from_list_row(row: sql.TasksListRow) -> Result(Task, ServiceError) {
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
    closed_at: row.closed_at,
    created_at: row.created_at,
    due_date: row.due_date,
    version: row.version,
    parent_card_id: row.parent_card_id,
    card_id: row.card_id,
    card_title: row.card_title,
    card_color: row.card_color,
    has_new_notes: row.has_new_notes,
    blocked_count: row.blocked_count,
    dependencies: row.dependencies,
    automation_origin: automation_origin_from_fields(
      row.created_from_rule_id,
      row.automation_workflow_id,
      row.automation_workflow_name,
      row.automation_rule_name,
      row.automation_execution_id,
      row.automation_template_id,
      row.automation_template_name,
      row.automation_template_version,
    ),
  )
}

/// Map a get query row to Task.
pub fn from_get_row(row: sql.TasksGetForUserRow) -> Result(Task, ServiceError) {
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
    closed_at: row.closed_at,
    created_at: row.created_at,
    due_date: row.due_date,
    version: row.version,
    parent_card_id: row.parent_card_id,
    card_id: row.card_id,
    card_title: row.card_title,
    card_color: row.card_color,
    has_new_notes: False,
    blocked_count: row.blocked_count,
    dependencies: row.dependencies,
    automation_origin: automation_origin_from_fields(
      row.created_from_rule_id,
      row.automation_workflow_id,
      row.automation_workflow_name,
      row.automation_rule_name,
      row.automation_execution_id,
      row.automation_template_id,
      row.automation_template_name,
      row.automation_template_version,
    ),
  )
}

/// Map a create query row to Task.
pub fn from_create_row(row: sql.TasksCreateRow) -> Result(Task, ServiceError) {
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
    closed_at: row.closed_at,
    created_at: row.created_at,
    due_date: row.due_date,
    version: row.version,
    parent_card_id: row.parent_card_id,
    card_id: row.card_id,
    card_title: row.card_title,
    card_color: row.card_color,
    has_new_notes: False,
    blocked_count: row.blocked_count,
    dependencies: row.dependencies,
    automation_origin: automation_origin_from_fields(
      row.created_from_rule_id,
      row.automation_workflow_id,
      row.automation_workflow_name,
      row.automation_rule_name,
      row.automation_execution_id,
      row.automation_template_id,
      row.automation_template_name,
      row.automation_template_version,
    ),
  )
}

/// Map an update query row to Task.
pub fn from_update_row(row: sql.TasksUpdateRow) -> Result(Task, ServiceError) {
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
    closed_at: row.closed_at,
    created_at: row.created_at,
    due_date: row.due_date,
    version: row.version,
    parent_card_id: row.parent_card_id,
    card_id: row.card_id,
    card_title: row.card_title,
    card_color: row.card_color,
    has_new_notes: False,
    blocked_count: row.blocked_count,
    dependencies: row.dependencies,
    automation_origin: automation_origin_from_fields(
      row.created_from_rule_id,
      row.automation_workflow_id,
      row.automation_workflow_name,
      row.automation_rule_name,
      row.automation_execution_id,
      row.automation_template_id,
      row.automation_template_name,
      row.automation_template_version,
    ),
  )
}

/// Map a claim query row to Task.
pub fn from_claim_row(row: sql.TasksClaimRow) -> Result(Task, ServiceError) {
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
    closed_at: row.closed_at,
    created_at: row.created_at,
    due_date: row.due_date,
    version: row.version,
    parent_card_id: row.parent_card_id,
    card_id: row.card_id,
    card_title: row.card_title,
    card_color: row.card_color,
    has_new_notes: False,
    blocked_count: row.blocked_count,
    dependencies: row.dependencies,
    automation_origin: automation_origin_from_fields(
      row.created_from_rule_id,
      row.automation_workflow_id,
      row.automation_workflow_name,
      row.automation_rule_name,
      row.automation_execution_id,
      row.automation_template_id,
      row.automation_template_name,
      row.automation_template_version,
    ),
  )
}

/// Map a release query row to Task.
pub fn from_release_row(row: sql.TasksReleaseRow) -> Result(Task, ServiceError) {
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
    closed_at: row.closed_at,
    created_at: row.created_at,
    due_date: row.due_date,
    version: row.version,
    parent_card_id: row.parent_card_id,
    card_id: row.card_id,
    card_title: row.card_title,
    card_color: row.card_color,
    has_new_notes: False,
    blocked_count: row.blocked_count,
    dependencies: row.dependencies,
    automation_origin: automation_origin_from_fields(
      row.created_from_rule_id,
      row.automation_workflow_id,
      row.automation_workflow_name,
      row.automation_rule_name,
      row.automation_execution_id,
      row.automation_template_id,
      row.automation_template_name,
      row.automation_template_version,
    ),
  )
}

/// Map a close-transition query row to Task.
pub fn from_close_row(row: sql.TasksCloseRow) -> Result(Task, ServiceError) {
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
    closed_at: row.closed_at,
    created_at: row.created_at,
    due_date: row.due_date,
    version: row.version,
    parent_card_id: row.parent_card_id,
    card_id: row.card_id,
    card_title: row.card_title,
    card_color: row.card_color,
    has_new_notes: False,
    blocked_count: row.blocked_count,
    dependencies: row.dependencies,
    automation_origin: automation_origin_from_fields(
      row.created_from_rule_id,
      row.automation_workflow_id,
      row.automation_workflow_name,
      row.automation_rule_name,
      row.automation_execution_id,
      row.automation_template_id,
      row.automation_template_name,
      row.automation_template_version,
    ),
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
  closed_at closed_at: String,
  created_at created_at: String,
  due_date due_date: String,
  version version: Int,
  parent_card_id parent_card_id: Int,
  card_id card_id: Int,
  card_title card_title: String,
  card_color card_color: String,
  has_new_notes has_new_notes: Bool,
  blocked_count blocked_count: Int,
  dependencies dependencies_raw: String,
  automation_origin automation_origin: Option(AutomationOrigin),
) -> Result(Task, ServiceError) {
  let claimed_by_option = option_helpers.int_to_option(claimed_by)
  let claimed_at_option = option_helpers.string_to_option(claimed_at)
  let closed_at_option = option_helpers.string_to_option(closed_at)

  use state <- result.try(
    task_state.from_db(
      status,
      is_ongoing,
      claimed_by_option,
      claimed_at_option,
      closed_at_option,
    )
    |> result.map_error(fn(error) { invalid_task_state_error(status, error) }),
  )
  use dependencies <- result.try(decode_dependencies(dependencies_raw))
  use parsed_card_color <- result.try(parse_optional_card_color(card_color))

  Ok(Task(
    id: id,
    project_id: project_id,
    type_id: type_id,
    task_type: TaskTypeInline(id: type_id, name: type_name, icon: type_icon),
    ongoing_by: ongoing_by_from_user_id(ongoing_by_user_id),
    title: title,
    description: option_helpers.string_to_option(description),
    priority: priority,
    state: state,
    created_by: created_by,
    created_at: created_at,
    due_date: option_helpers.string_to_option(due_date),
    version: version,
    parent_card_id: option_helpers.int_to_option(parent_card_id),
    card_id: option_helpers.int_to_option(card_id),
    card_title: option_helpers.string_to_option(card_title),
    card_color: parsed_card_color,
    has_new_notes: has_new_notes,
    blocked_count: blocked_count,
    dependencies: dependencies,
    automation_origin: automation_origin,
  ))
}

fn automation_origin_from_fields(
  rule_id: Int,
  workflow_id: Int,
  workflow_name: String,
  rule_name: String,
  execution_id: Int,
  template_id: Int,
  template_name: String,
  template_version: Int,
) -> Option(AutomationOrigin) {
  case option_helpers.int_to_option(rule_id) {
    Some(id) ->
      Some(AutomationOrigin(
        rule_id: id,
        workflow_id: option_helpers.int_to_option(workflow_id),
        workflow_name: option_helpers.string_to_option(workflow_name),
        rule_name: option_helpers.string_to_option(rule_name),
        execution_id: option_helpers.int_to_option(execution_id),
        template_id: option_helpers.int_to_option(template_id),
        template_name: option_helpers.string_to_option(template_name),
        template_version: option_helpers.int_to_option(template_version),
      ))
    None -> None
  }
}

fn ongoing_by_from_user_id(user_id: Int) -> Option(OngoingBy) {
  case option_helpers.int_to_option(user_id) {
    Some(value) -> Some(OngoingBy(user_id: value))
    None -> None
  }
}

fn parse_optional_card_color(
  color: String,
) -> Result(Option(card.CardColor), ServiceError) {
  card.parse_optional_color(color)
  |> result.map_error(fn(_) {
    Unexpected("Invalid persisted card color: " <> color)
  })
}

fn invalid_task_state_error(
  status: String,
  error: task_state.TaskExecutionStateError,
) -> ServiceError {
  let reason = case error {
    task_state.UnknownStatus(value) -> "unknown status " <> value
    task_state.ClaimedMissingUser -> "claimed missing user"
    task_state.ClaimedMissingAt -> "claimed missing at"
    task_state.ClosedMissingAt -> "closed missing at"
    task_state.ClosedWithClaim -> "closed with claim"
    task_state.AvailableWithClaim -> "available with claim"
  }

  Unexpected(
    "Invalid persisted task state: " <> status <> " (" <> reason <> ")",
  )
}

fn decode_dependencies(
  raw: String,
) -> Result(List(TaskDependency), ServiceError) {
  case json.parse(from: raw, using: decode.list(task_dependency_decoder())) {
    Ok(deps) -> Ok(deps)
    Error(_) ->
      Error(Unexpected("Invalid persisted task dependencies: " <> raw))
  }
}

fn task_dependency_decoder() -> decode.Decoder(TaskDependency) {
  use depends_on_task_id <- decode.field("task_id", decode.int)
  use title <- decode.field("title", decode.string)
  use status_str <- decode.field("status", decode.string)
  use is_ongoing <- decode.optional_field("is_ongoing", False, decode.bool)
  use claimed_by_user_id <- decode.optional_field(
    "claimed_by_user_id",
    None,
    decode.optional(decode.int),
  )
  use claimed_at <- decode.optional_field(
    "claimed_at",
    None,
    decode.optional(decode.string),
  )
  use closed_at <- decode.optional_field(
    "closed_at",
    None,
    decode.optional(decode.string),
  )
  use claimed_by <- decode.optional_field(
    "claimed_by",
    None,
    decode.optional(decode.string),
  )
  case
    task_state.from_db(
      status_str,
      is_ongoing,
      claimed_by_user_id,
      claimed_at,
      closed_at,
    )
  {
    Ok(state) ->
      decode.success(TaskDependency(
        depends_on_task_id: depends_on_task_id,
        title: title,
        state: state,
        claimed_by: claimed_by,
      ))
    Error(_) ->
      decode.failure(
        TaskDependency(
          depends_on_task_id: depends_on_task_id,
          title: title,
          state: task_state.Available,
          claimed_by: claimed_by,
        ),
        "TaskDependency.state: " <> status_str,
      )
  }
}
