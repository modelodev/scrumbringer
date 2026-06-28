import gleam/string
import lustre/attribute
import support/render_assertions

import scrumbringer_client/ui/button
import scrumbringer_client/ui/icons

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
    |> render_assertions.html

  render_assertions.contains(html, "btn-primary")
  render_assertions.contains(html, "btn-global-action")
  render_assertions.contains(html, "btn-icon-text")
  render_assertions.contains(html, "pool-header-action")
  render_assertions.contains(html, "data-testid=\"btn-new-task\"")
  render_assertions.contains(html, "type=\"button\"")
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
    |> render_assertions.html

  render_assertions.contains(html, "btn-danger-icon")
  render_assertions.contains(html, "btn-entity-action")
  render_assertions.contains(html, "aria-label=\"Delete card\"")
  render_assertions.contains(html, "title=\"Delete card\"")
}

pub fn text_button_can_use_contextual_accessible_label_test() {
  let html =
    button.text("Remove", "msg", button.Danger, button.EntityAction)
    |> button.with_accessible_label("Remove: Platform")
    |> button.view
    |> render_assertions.html

  render_assertions.contains(html, ">Remove<")
  render_assertions.contains(html, "aria-label=\"Remove: Platform\"")
  render_assertions.contains(html, "title=\"Remove: Platform\"")
}

pub fn disabled_button_and_id_are_preserved_test() {
  let html =
    button.text("Activate", "msg", button.Primary, button.EntityAction)
    |> button.with_disabled(True)
    |> button.with_id("activate-button")
    |> button.with_testid("activate-testid")
    |> button.view
    |> render_assertions.html

  render_assertions.contains(html, "disabled")
  render_assertions.contains(html, "id=\"activate-button\"")
  render_assertions.contains(html, "data-testid=\"activate-testid\"")
}

pub fn submit_button_can_target_external_form_test() {
  let html =
    button.submit("Save", button.Primary, button.EntityAction)
    |> button.with_form("profile-form")
    |> button.with_disabled(True)
    |> button.view
    |> render_assertions.html

  render_assertions.contains(html, "type=\"submit\"")
  render_assertions.contains(html, "form=\"profile-form\"")
  render_assertions.contains(html, "disabled")
  let assert False = string.contains(html, "data-")
}

pub fn submit_icon_text_button_keeps_submit_semantics_test() {
  let html =
    button.submit_icon_text(
      "Create and activate",
      icons.Play,
      button.Primary,
      button.EntityAction,
    )
    |> button.with_form("card-create-form")
    |> button.with_testid("card-create-and-activate")
    |> button.view
    |> render_assertions.html

  render_assertions.contains(html, "type=\"submit\"")
  render_assertions.contains(html, "form=\"card-create-form\"")
  render_assertions.contains(html, "btn-primary")
  render_assertions.contains(html, "btn-icon-text")
  render_assertions.contains(html, "btn-icon-prefix")
  render_assertions.contains(html, "data-testid=\"card-create-and-activate\"")
  render_assertions.contains(html, "Create and activate")
}

pub fn extra_classes_are_accumulated_test() {
  let html =
    button.text("Save", "msg", button.Primary, button.EntityAction)
    |> button.with_class("btn-compact")
    |> button.with_class("btn-loading")
    |> button.view
    |> render_assertions.html

  render_assertions.contains(html, "btn-compact")
  render_assertions.contains(html, "btn-loading")
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
    |> render_assertions.html

  render_assertions.contains(html, "btn-icon")
  render_assertions.contains(html, "btn-xs")
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
    |> render_assertions.html

  render_assertions.contains(html, "data-tooltip=\"Claim\"")
  render_assertions.contains(html, "aria-label=\"Claim task\"")
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
    |> render_assertions.html

  render_assertions.contains(html, "aria-haspopup=\"dialog\"")
  render_assertions.contains(html, "aria-expanded=\"true\"")
  render_assertions.contains(html, "btn-global-action")
  render_assertions.contains(html, "btn-icon")
}

pub fn blocked_reason_removes_click_and_keeps_button_focusable_test() {
  let html =
    button.icon(
      "Delete card",
      "msg",
      icons.Trash,
      button.Danger,
      button.EntityAction,
    )
    |> button.with_blocked_reason("Cannot delete: has tasks")
    |> button.view
    |> render_assertions.html

  render_assertions.contains(html, "aria-disabled=\"true\"")
  render_assertions.contains(html, "data-tooltip=\"Cannot delete: has tasks\"")
  render_assertions.contains(html, "aria-label=\"Cannot delete: has tasks\"")
  render_assertions.contains(html, "title=\"Cannot delete: has tasks\"")
  let assert False = string.contains(html, " disabled")
  let assert False = string.contains(html, "data-lustre-on-click")
}
