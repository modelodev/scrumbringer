import gleam/string
import lustre/attribute
import lustre/element

import scrumbringer_client/ui/button
import scrumbringer_client/ui/icons

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

pub fn primary_global_button_renders_semantic_classes_test() {
  let html =
    button.icon_text(
      "New task",
      "msg",
      icons.Plus,
      button.Primary,
      button.GlobalAction,
    )
    |> button.with_class("pool-header-action")
    |> button.with_testid("btn-new-task")
    |> button.view
    |> element.to_document_string

  assert_contains(html, "btn-primary")
  assert_contains(html, "btn-global-action")
  assert_contains(html, "btn-icon-text")
  assert_contains(html, "pool-header-action")
  assert_contains(html, "data-testid=\"btn-new-task\"")
  assert_contains(html, "type=\"button\"")
}

pub fn icon_only_button_has_accessible_label_test() {
  let html =
    button.icon(
      "Delete card",
      "msg",
      icons.Trash,
      button.Danger,
      button.EntityAction,
    )
    |> button.view
    |> element.to_document_string

  assert_contains(html, "btn-danger-icon")
  assert_contains(html, "btn-entity-action")
  assert_contains(html, "aria-label=\"Delete card\"")
  assert_contains(html, "title=\"Delete card\"")
}

pub fn text_button_can_use_contextual_accessible_label_test() {
  let html =
    button.text("Remove", "msg", button.Danger, button.EntityAction)
    |> button.with_accessible_label("Remove: Platform")
    |> button.view
    |> element.to_document_string

  assert_contains(html, ">Remove<")
  assert_contains(html, "aria-label=\"Remove: Platform\"")
  assert_contains(html, "title=\"Remove: Platform\"")
}

pub fn disabled_button_and_id_are_preserved_test() {
  let html =
    button.text("Activate", "msg", button.Primary, button.EntityAction)
    |> button.with_disabled(True)
    |> button.with_id("activate-button")
    |> button.with_testid("activate-testid")
    |> button.view
    |> element.to_document_string

  assert_contains(html, "disabled")
  assert_contains(html, "id=\"activate-button\"")
  assert_contains(html, "data-testid=\"activate-testid\"")
}

pub fn autofocus_button_renders_native_attribute_test() {
  let html =
    button.text("Cancel", "msg", button.Secondary, button.EntityAction)
    |> button.with_autofocus(True)
    |> button.view
    |> element.to_document_string

  assert_contains(html, "autofocus")
}

pub fn submit_button_can_target_external_form_test() {
  let html =
    button.submit("Save", button.Primary, button.EntityAction)
    |> button.with_form("profile-form")
    |> button.with_disabled(True)
    |> button.view
    |> element.to_document_string

  assert_contains(html, "type=\"submit\"")
  assert_contains(html, "form=\"profile-form\"")
  assert_contains(html, "disabled")
  let assert False = string.contains(html, "data-")
}

pub fn compatibility_classes_are_accumulated_test() {
  let html =
    button.text("Save", "msg", button.Primary, button.EntityAction)
    |> button.with_class("btn-compact")
    |> button.with_class("btn-loading")
    |> button.view
    |> element.to_document_string

  assert_contains(html, "btn-compact")
  assert_contains(html, "btn-loading")
}

pub fn neutral_icon_button_does_not_force_intent_class_test() {
  let html =
    button.icon(
      "Edit",
      "msg",
      icons.Pencil,
      button.Neutral,
      button.EntityAction,
    )
    |> button.view
    |> element.to_document_string

  assert_contains(html, "btn-icon")
  assert_contains(html, "btn-xs")
  let assert False = string.contains(html, "btn-primary")
  let assert False = string.contains(html, "btn-secondary")
  let assert False = string.contains(html, "btn-ghost")
}

pub fn tooltip_is_rendered_when_provided_test() {
  let html =
    button.icon(
      "Claim task",
      "msg",
      icons.HandRaised,
      button.Neutral,
      button.EntityAction,
    )
    |> button.with_tooltip("Claim")
    |> button.view
    |> element.to_document_string

  assert_contains(html, "data-tooltip=\"Claim\"")
  assert_contains(html, "aria-label=\"Claim task\"")
}

pub fn stop_propagation_button_preserves_semantic_contract_test() {
  let html =
    button.icon_text(
      "Attach template",
      "msg",
      icons.Plus,
      button.Primary,
      button.EntityAction,
    )
    |> button.with_stop_propagation
    |> button.view
    |> element.to_document_string

  assert_contains(html, "btn-primary")
  assert_contains(html, "btn-entity-action")
  assert_contains(html, "btn-icon-text")
  assert_contains(html, "aria-label=\"Attach template\"")
}

pub fn button_can_carry_specific_accessibility_attributes_test() {
  let html =
    button.icon(
      "Preferences",
      "msg",
      icons.Cog,
      button.Neutral,
      button.GlobalAction,
    )
    |> button.with_attribute(attribute.attribute("aria-haspopup", "dialog"))
    |> button.with_attribute(attribute.attribute("aria-expanded", "true"))
    |> button.view
    |> element.to_document_string

  assert_contains(html, "aria-haspopup=\"dialog\"")
  assert_contains(html, "aria-expanded=\"true\"")
  assert_contains(html, "btn-global-action")
  assert_contains(html, "btn-icon")
}
