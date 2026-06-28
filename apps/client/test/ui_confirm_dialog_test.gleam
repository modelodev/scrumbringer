import gleam/option
import lustre/element
import lustre/element/html.{text}
import support/render_assertions

import scrumbringer_client/ui/button
import scrumbringer_client/ui/confirm_dialog

pub fn confirm_dialog_uses_typed_danger_intent_test() {
  let html =
    confirm_dialog.view(confirm_dialog.ConfirmConfig(
      title: "Delete item",
      body: [text("This cannot be undone.")],
      confirm_label: "Delete",
      cancel_label: "Cancel",
      on_confirm: "confirm",
      on_cancel: "cancel",
      is_open: True,
      is_loading: False,
      error: option.None,
      confirm_intent: button.Danger,
    ))
    |> element.to_document_string

  render_assertions.contains(html, "btn-danger")
  render_assertions.contains(html, "btn-entity-action")
  render_assertions.not_contains(html, "class=\"btn-danger\"")
}

pub fn confirm_dialog_adds_loading_class_internally_test() {
  let html =
    confirm_dialog.view(confirm_dialog.ConfirmConfig(
      title: "Release tasks",
      body: [text("Release all tasks.")],
      confirm_label: "Release",
      cancel_label: "Cancel",
      on_confirm: "confirm",
      on_cancel: "cancel",
      is_open: True,
      is_loading: True,
      error: option.None,
      confirm_intent: button.Primary,
    ))
    |> element.to_document_string

  render_assertions.contains(html, "btn-primary")
  render_assertions.contains(html, "btn-loading")
  render_assertions.contains(html, "disabled")
  render_assertions.not_contains(html, "class=\"btn-primary btn-loading\"")
}
