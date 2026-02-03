//// Template utilities for rules engine task creation.
////
//// Keeps variable substitution isolated from rule evaluation logic.

import gleam/int
import gleam/string

/// Build a link to the triggering resource for template substitution.
pub fn format_father_link(resource_type: String, resource_id: Int) -> String {
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
pub fn substitute(
  text: String,
  father: String,
  from_state: String,
  to_state: String,
  project_name: String,
  user_name: String,
) -> String {
  text
  |> string.replace("{{father}}", father)
  |> string.replace("{{from_state}}", from_state)
  |> string.replace("{{to_state}}", to_state)
  |> string.replace("{{project}}", project_name)
  |> string.replace("{{user}}", user_name)
}
