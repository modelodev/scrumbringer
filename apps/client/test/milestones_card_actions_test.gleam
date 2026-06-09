import gleam/string
import lustre/element

import scrumbringer_client/features/milestones/card_actions
import scrumbringer_client/i18n/locale

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

fn assert_not_contains(html: String, fragment: String) {
  let assert False = string.contains(html, fragment)
}

fn config(can_manage: Bool) -> card_actions.Config(String) {
  card_actions.Config(
    locale: locale.En,
    card_id: 42,
    card_title: "Release card",
    can_manage: can_manage,
    on_create_task: "create-task",
    on_edit: "edit",
    on_delete: "delete",
  )
}

fn render(config: card_actions.Config(String)) -> String {
  card_actions.view(config)
  |> element.fragment
  |> element.to_document_string
}

pub fn milestones_card_actions_render_management_actions_without_root_model_test() {
  let html = render(config(True))

  assert_contains(html, "Add task to Release card")
  assert_contains(html, "Edit card")
  assert_contains(html, "Delete card")
}

pub fn milestones_card_actions_hide_management_actions_without_permission_test() {
  let html = render(config(False))

  assert_contains(html, "Add task to Release card")
  assert_not_contains(html, "Edit card")
  assert_not_contains(html, "Delete card")
}
