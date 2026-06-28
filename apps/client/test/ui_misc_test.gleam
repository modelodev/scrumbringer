import gleam/option.{Some}
import scrumbringer_client/features/admin/org_user_fallback
import scrumbringer_client/ui/action_menu
import scrumbringer_client/ui/attribute_value
import scrumbringer_client/ui/card_section_header
import scrumbringer_client/ui/copyable_input
import scrumbringer_client/ui/empty_state
import scrumbringer_client/ui/error_banner
import scrumbringer_client/ui/error_notice
import support/render_assertions

pub fn attribute_value_boolean_serializes_html_booleans_test() {
  let assert "true" = attribute_value.boolean(True)
  let assert "false" = attribute_value.boolean(False)
}

pub fn org_user_fallback_builds_stable_admin_placeholder_test() {
  let user = org_user_fallback.from_id(42)

  let assert 42 = user.id
  let assert "User #42" = user.email
  let assert "" = user.created_at
}

pub fn empty_state_view_renders_title_description_and_action_test() {
  let state =
    empty_state.new("magnifying-glass", "No results", "Try again")
    |> empty_state.with_meaning(empty_state.NoResults)
    |> empty_state.with_action("Retry", "msg")

  let html =
    empty_state.view(state)
    |> render_assertions.html

  render_assertions.contains(html, "No results")
  render_assertions.contains(html, "Try again")
  render_assertions.contains(html, "Retry")
  render_assertions.contains(html, "empty-state-no-results")
}

pub fn empty_state_action_uses_semantic_button_test() {
  let state =
    empty_state.new("magnifying-glass", "No results", "Try again")
    |> empty_state.with_action("Retry", "msg")

  let html =
    empty_state.view(state)
    |> render_assertions.html

  render_assertions.contains(html, "btn-primary")
  render_assertions.contains(html, "btn-entity-action")
  render_assertions.contains(html, "type=\"button\"")
  render_assertions.not_contains(html, "type=\"submit\"")
}

pub fn action_menu_renders_links_as_menu_items_test() {
  let html =
    action_menu.view(
      "Open in",
      "open-trigger",
      "open-menu",
      Some("Open in"),
      "open-menu",
      "open-trigger",
      "open-panel",
      "open-item",
      [action_menu.link_item("Plan", "open-plan", "/app?view=cards")],
    )
    |> render_assertions.html

  render_assertions.contains(html, "href=\"/app?view=cards\"")
  render_assertions.contains(html, "role=\"menuitem\"")
  render_assertions.contains(html, "data-testid=\"open-plan\"")
  render_assertions.contains(html, "popover=\"auto\"")
  render_assertions.contains(html, "popovertarget=\"open-menu-panel\"")
  render_assertions.not_contains(html, "<details")
}

pub fn empty_state_simple_renders_description_test() {
  let html =
    empty_state.simple("hand-raised", "Nothing here")
    |> render_assertions.html

  render_assertions.contains(html, "Nothing here")
}

pub fn empty_state_notice_preserves_local_class_and_loading_role_test() {
  let html =
    empty_state.notice_with_class(
      "clock",
      "Loading people...",
      empty_state.Loading,
      "people-state people-loading",
    )
    |> render_assertions.html

  render_assertions.contains(html, "people-state people-loading")
  render_assertions.contains(html, "empty-state-loading")
  render_assertions.contains(html, "role=\"status\"")
  render_assertions.contains(html, "aria-live=\"polite\"")
}

pub fn empty_state_error_notice_renders_alert_role_test() {
  let html =
    empty_state.notice(
      "exclamation-triangle",
      "Could not load data",
      empty_state.Error,
    )
    |> render_assertions.html

  render_assertions.contains(html, "empty-state-error")
  render_assertions.contains(html, "role=\"alert\"")
  render_assertions.contains(html, "Could not load data")
}

pub fn card_section_header_uses_shared_button_classes_test() {
  let html =
    card_section_header.view(card_section_header.Config(
      title: "Notes",
      button_label: "Add note",
      button_disabled: False,
      on_button_click: "msg",
    ))
    |> render_assertions.html

  render_assertions.contains(html, "card-section-header")
  render_assertions.contains(html, "btn-primary")
  render_assertions.contains(html, "btn-entity-action")
  render_assertions.contains(html, "btn-sm")
  render_assertions.not_contains(html, "btn btn-sm btn-primary")
}

pub fn card_section_header_extended_keeps_extra_button_class_test() {
  let html =
    card_section_header.view_extended(card_section_header.ExtendedConfig(
      title: "Tasks",
      button_label: "Add task",
      button_disabled: True,
      on_button_click: "msg",
      container_class: Some("detail-section-header"),
      button_class: Some("task-section-action"),
    ))
    |> render_assertions.html

  render_assertions.contains(html, "detail-section-header")
  render_assertions.contains(html, "task-section-action")
  render_assertions.contains(html, "btn-primary")
  render_assertions.contains(html, "disabled")
  render_assertions.not_contains(html, "btn btn-sm btn-primary")
}

pub fn copyable_input_uses_shared_button_test() {
  let html =
    copyable_input.view(
      "Invite link",
      "https://example.test/i",
      "msg",
      "Copy",
      Some("Copied"),
    )
    |> render_assertions.html

  render_assertions.contains(html, "Invite link")
  render_assertions.contains(html, "readonly")
  render_assertions.contains(html, "btn-secondary")
  render_assertions.contains(html, "btn-entity-action")
  render_assertions.contains(html, "type=\"button\"")
}

pub fn error_notice_renders_error_text_test() {
  let error_html =
    error_notice.view("Boom")
    |> render_assertions.html

  render_assertions.contains(error_html, "Boom")
}

pub fn error_banner_renders_message_test() {
  let html = error_banner.view("Oops") |> render_assertions.html
  render_assertions.contains(html, "Oops")
  render_assertions.contains(html, "error-banner")
}
