import gleam/option.{None, Some}
import gleam/string
import lustre/element

import scrumbringer_client/features/pool/position_edit_dialog
import scrumbringer_client/i18n/locale

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

pub fn position_edit_dialog_renders_fields_test() {
  let html =
    position_edit_dialog.view(position_edit_dialog.Config(
      locale: locale.En,
      x: "12",
      y: "34",
      error: None,
      in_flight: False,
      on_close: "close",
      on_x_changed: fn(value) { "x-" <> value },
      on_y_changed: fn(value) { "y-" <> value },
      on_submit: "submit",
    ))
    |> element.to_document_string

  assert_contains(html, "Edit position")
  assert_contains(html, "value=\"12\"")
  assert_contains(html, "value=\"34\"")
  assert_contains(html, "Save")
}

pub fn position_edit_dialog_renders_loading_and_error_test() {
  let html =
    position_edit_dialog.view(position_edit_dialog.Config(
      locale: locale.En,
      x: "left",
      y: "34",
      error: Some("Invalid coordinates"),
      in_flight: True,
      on_close: "close",
      on_x_changed: fn(value) { "x-" <> value },
      on_y_changed: fn(value) { "y-" <> value },
      on_submit: "submit",
    ))
    |> element.to_document_string

  assert_contains(html, "Invalid coordinates")
  assert_contains(html, "btn-loading")
  assert_contains(html, "Saving")
  assert_contains(html, "disabled")
}
