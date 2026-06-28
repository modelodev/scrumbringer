import gleam/option
import support/render_assertions

import scrumbringer_client/ui/action_buttons
import scrumbringer_client/ui/icons

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
    |> render_assertions.html

  render_assertions.contains(html, "btn-icon")
  render_assertions.contains(html, "btn-xs")
  render_assertions.contains(html, "claim-action")
  render_assertions.contains(html, "data-tooltip=\"Claim\"")
  render_assertions.contains(html, "data-testid=\"claim-testid\"")
  render_assertions.contains(html, "aria-label=\"Claim task\"")
}

pub fn delete_button_uses_danger_icon_contract_test() {
  let html =
    action_buttons.delete_button_with_testid("Delete", "msg", "delete-testid")
    |> render_assertions.html

  render_assertions.contains(html, "btn-danger-icon")
  render_assertions.contains(html, "btn-entity-action")
  render_assertions.contains(html, "data-testid=\"delete-testid\"")
  render_assertions.contains(html, "aria-label=\"Delete\"")
}

pub fn delete_button_availability_distinguishes_busy_and_blocked_test() {
  let busy_html =
    action_buttons.delete_button_with_availability_and_testid(
      "Delete",
      "msg",
      action_buttons.Busy,
      "delete-testid",
    )
    |> render_assertions.html

  render_assertions.contains(busy_html, "disabled")
  render_assertions.contains(busy_html, "aria-label=\"Delete\"")
  render_assertions.contains(busy_html, "data-testid=\"delete-testid\"")

  let blocked_html =
    action_buttons.delete_button_with_availability_and_testid(
      "Delete",
      "msg",
      action_buttons.Blocked("Cannot delete: has tasks"),
      "delete-testid",
    )
    |> render_assertions.html

  render_assertions.contains(blocked_html, "aria-disabled=\"true\"")
  render_assertions.contains(blocked_html, "btn-delete-blocked")
  render_assertions.contains(blocked_html, "data-testid=\"delete-testid\"")
  render_assertions.contains(
    blocked_html,
    "data-tooltip=\"Cannot delete: has tasks\"",
  )
  render_assertions.contains(
    blocked_html,
    "aria-label=\"Cannot delete: has tasks\"",
  )
}
