import gleam/option
import gleam/string
import lustre/element
import lustre/element/html.{text}

import scrumbringer_client/ui/button
import scrumbringer_client/ui/confirm_dialog

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

fn assert_not_contains(html: String, fragment: String) {
  let assert False = string.contains(html, fragment)
}

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

  assert_contains(html, "btn-danger")
  assert_contains(html, "btn-entity-action")
  assert_not_contains(html, "class=\"btn-danger\"")
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

  assert_contains(html, "btn-primary")
  assert_contains(html, "btn-loading")
  assert_contains(html, "disabled")
  assert_not_contains(html, "class=\"btn-primary btn-loading\"")
}
