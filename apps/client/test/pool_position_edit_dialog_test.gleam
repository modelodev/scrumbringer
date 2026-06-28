import gleam/option.{None, Some}
import support/render_assertions

import scrumbringer_client/features/pool/position_edit_dialog
import scrumbringer_client/i18n/locale

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
    |> render_assertions.html

  render_assertions.contains(html, "Edit position")
  render_assertions.contains(html, "value=\"12\"")
  render_assertions.contains(html, "value=\"34\"")
  render_assertions.contains(html, "Save")
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
    |> render_assertions.html

  render_assertions.contains(html, "Invalid coordinates")
  render_assertions.contains(html, "btn-loading")
  render_assertions.contains(html, "Saving")
  render_assertions.contains(html, "disabled")
}
