import gleam/string
import lustre/element

import scrumbringer_client/features/milestones/empty_state
import scrumbringer_client/i18n/locale
import scrumbringer_client/i18n/text as i18n_text

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

fn assert_not_contains(html: String, fragment: String) {
  let assert False = string.contains(html, fragment)
}

pub fn milestones_empty_state_renders_create_action_without_root_model_test() {
  let html =
    empty_state.view(empty_state.EmptyConfig(
      locale: locale.En,
      message: i18n_text.MilestonesEmpty,
      can_manage: True,
      on_create: "create",
    ))
    |> element.to_document_string

  assert_contains(html, "No milestones yet")
  assert_contains(html, "data-testid=\"milestones-create-empty\"")
  assert_contains(html, "Create first milestone")
}

pub fn milestones_empty_state_hides_create_action_without_permission_test() {
  let html =
    empty_state.view(empty_state.EmptyConfig(
      locale: locale.En,
      message: i18n_text.MilestonesNoResults,
      can_manage: False,
      on_create: "create",
    ))
    |> element.to_document_string

  assert_contains(html, "No milestones match current filters")
  assert_not_contains(html, "data-testid=\"milestones-create-empty\"")
}

pub fn milestones_create_button_renders_without_root_model_test() {
  let html =
    empty_state.create_button(empty_state.CreateButtonConfig(
      locale: locale.En,
      can_manage: True,
      on_create: "create",
    ))
    |> element.to_document_string

  assert_contains(html, "data-testid=\"milestones-create-button\"")
  assert_contains(html, "btn-primary")
  assert_contains(html, "btn-global-action")
  assert_contains(html, "Create milestone")
}

pub fn milestones_create_button_hides_without_permission_test() {
  let html =
    empty_state.create_button(empty_state.CreateButtonConfig(
      locale: locale.En,
      can_manage: False,
      on_create: "create",
    ))
    |> element.to_document_string

  assert_not_contains(html, "data-testid=\"milestones-create-button\"")
}
