//// Template utilities for rules engine task creation.
////
//// Keeps variable substitution isolated from rule evaluation logic.

import gleam/int
import gleam/string

pub type EventContext {
  EventContext(
    origin: String,
    trigger: String,
    project_name: String,
    user_name: String,
    task_title: String,
    task_type: String,
    card_title: String,
    card_level: String,
  )
}

/// Build a link to the triggering resource for template substitution.
pub fn format_origin_link(resource_type: String, resource_id: Int) -> String {
  case resource_type {
    "task" ->
      "[Task #"
      <> int.to_string(resource_id)
      <> "](/tasks/"
      <> int.to_string(resource_id)
      <> ")"
    _ ->
      "[Card #"
      <> int.to_string(resource_id)
      <> "](/cards/"
      <> int.to_string(resource_id)
      <> ")"
  }
}

/// Substitute workflow template variables with event context values.
pub fn substitute(text: String, context: EventContext) -> String {
  text
  |> string.replace("{{origin}}", context.origin)
  |> string.replace("{{trigger}}", context.trigger)
  |> string.replace("{{project}}", context.project_name)
  |> string.replace("{{user}}", context.user_name)
  |> string.replace("{{task_title}}", context.task_title)
  |> string.replace("{{task_type}}", context.task_type)
  |> string.replace("{{card_title}}", context.card_title)
  |> string.replace("{{card_level}}", context.card_level)
}
