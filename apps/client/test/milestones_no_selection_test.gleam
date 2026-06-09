import gleam/string
import lustre/element

import scrumbringer_client/features/milestones/no_selection
import scrumbringer_client/i18n/locale

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

pub fn milestones_no_selection_renders_without_root_model_test() {
  let html =
    no_selection.view(locale.En)
    |> element.to_document_string

  assert_contains(html, "milestone-detail-empty")
  assert_contains(html, "Select a milestone")
  assert_contains(html, "Choose a milestone from the list")
}
