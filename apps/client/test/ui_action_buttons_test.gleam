import gleam/option
import gleam/string
import lustre/element

import scrumbringer_client/ui/action_buttons
import scrumbringer_client/ui/icons

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

pub fn task_icon_button_preserves_tooltip_and_testid_test() {
  let html =
    action_buttons.task_icon_button(
      "Claim task",
      "msg",
      icons.HandRaised,
      action_buttons.SizeXs,
      False,
      "claim-action",
      option.Some("Claim"),
      option.Some("claim-testid"),
    )
    |> element.to_document_string

  assert_contains(html, "btn-icon")
  assert_contains(html, "btn-xs")
  assert_contains(html, "claim-action")
  assert_contains(html, "data-tooltip=\"Claim\"")
  assert_contains(html, "data-testid=\"claim-testid\"")
  assert_contains(html, "aria-label=\"Claim task\"")
}

pub fn delete_button_uses_danger_icon_contract_test() {
  let html =
    action_buttons.delete_button_with_testid("Delete", "msg", "delete-testid")
    |> element.to_document_string

  assert_contains(html, "btn-danger-icon")
  assert_contains(html, "btn-entity-action")
  assert_contains(html, "data-testid=\"delete-testid\"")
  assert_contains(html, "aria-label=\"Delete\"")
}

pub fn delete_button_with_disabled_and_testid_preserves_contract_test() {
  let html =
    action_buttons.delete_button_with_disabled_and_testid(
      "Delete user",
      "msg",
      True,
      "delete-user-testid",
    )
    |> element.to_document_string

  assert_contains(html, "btn-danger-icon")
  assert_contains(html, "btn-entity-action")
  assert_contains(html, "disabled")
  assert_contains(html, "data-testid=\"delete-user-testid\"")
  assert_contains(html, "aria-label=\"Delete user\"")
}

pub fn delete_button_blocked_with_testid_explains_blocked_action_test() {
  let html =
    action_buttons.delete_button_blocked_with_testid(
      "Cannot delete: has tasks",
      "msg",
      "delete-blocked-testid",
    )
    |> element.to_document_string

  assert_contains(html, "btn-danger-icon")
  assert_contains(html, "btn-delete-blocked")
  assert_contains(html, "aria-disabled=\"true\"")
  assert_contains(html, "data-tooltip=\"Cannot delete: has tasks\"")
  assert_contains(html, "data-testid=\"delete-blocked-testid\"")
  assert_contains(html, "aria-label=\"Cannot delete: has tasks\"")
}

pub fn delete_button_availability_distinguishes_busy_and_blocked_test() {
  let busy_html =
    action_buttons.delete_button_with_availability_and_testid(
      "Delete",
      "msg",
      action_buttons.Busy,
      "delete-testid",
    )
    |> element.to_document_string

  assert_contains(busy_html, "disabled")
  assert_contains(busy_html, "aria-label=\"Delete\"")

  let blocked_html =
    action_buttons.delete_button_with_availability_and_testid(
      "Delete",
      "msg",
      action_buttons.Blocked("Cannot delete: has tasks"),
      "delete-testid",
    )
    |> element.to_document_string

  assert_contains(blocked_html, "aria-disabled=\"true\"")
  assert_contains(blocked_html, "data-tooltip=\"Cannot delete: has tasks\"")
  assert_contains(blocked_html, "aria-label=\"Cannot delete: has tasks\"")
}
