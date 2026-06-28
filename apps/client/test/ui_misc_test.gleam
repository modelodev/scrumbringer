import gleam/option.{Some}
import gleam/string
import lustre/element
import scrumbringer_client/features/admin/org_user_fallback
import scrumbringer_client/ui/action_menu
import scrumbringer_client/ui/attribute_value
import scrumbringer_client/ui/card_section_header
import scrumbringer_client/ui/copyable_input
import scrumbringer_client/ui/empty_state
import scrumbringer_client/ui/error_banner
import scrumbringer_client/ui/error_notice

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
    |> element.to_document_string

  let assert True = string.contains(html, "No results")
  let assert True = string.contains(html, "Try again")
  let assert True = string.contains(html, "Retry")
  let assert True = string.contains(html, "empty-state-no-results")
}

pub fn empty_state_action_uses_semantic_button_test() {
  let state =
    empty_state.new("magnifying-glass", "No results", "Try again")
    |> empty_state.with_action("Retry", "msg")

  let html =
    empty_state.view(state)
    |> element.to_document_string

  let assert True = string.contains(html, "btn-primary")
  let assert True = string.contains(html, "btn-entity-action")
  let assert True = string.contains(html, "type=\"button\"")
  let assert False = string.contains(html, "type=\"submit\"")
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
    |> element.to_document_string

  let assert True = string.contains(html, "href=\"/app?view=cards\"")
  let assert True = string.contains(html, "role=\"menuitem\"")
  let assert True = string.contains(html, "data-testid=\"open-plan\"")
  let assert True = string.contains(html, "popover=\"auto\"")
  let assert True = string.contains(html, "popovertarget=\"open-menu-panel\"")
  let assert False = string.contains(html, "<details")
}

pub fn empty_state_simple_renders_description_test() {
  let html =
    empty_state.simple("hand-raised", "Nothing here")
    |> element.to_document_string

  let assert True = string.contains(html, "Nothing here")
}

pub fn empty_state_notice_preserves_local_class_and_loading_role_test() {
  let html =
    empty_state.notice_with_class(
      "clock",
      "Loading people...",
      empty_state.Loading,
      "people-state people-loading",
    )
    |> element.to_document_string

  let assert True = string.contains(html, "people-state people-loading")
  let assert True = string.contains(html, "empty-state-loading")
  let assert True = string.contains(html, "role=\"status\"")
  let assert True = string.contains(html, "aria-live=\"polite\"")
}

pub fn empty_state_error_notice_renders_alert_role_test() {
  let html =
    empty_state.notice(
      "exclamation-triangle",
      "Could not load data",
      empty_state.Error,
    )
    |> element.to_document_string

  let assert True = string.contains(html, "empty-state-error")
  let assert True = string.contains(html, "role=\"alert\"")
  let assert True = string.contains(html, "Could not load data")
}

pub fn card_section_header_uses_shared_button_classes_test() {
  let html =
    card_section_header.view(card_section_header.Config(
      title: "Notes",
      button_label: "Add note",
      button_disabled: False,
      on_button_click: "msg",
    ))
    |> element.to_document_string

  let assert True = string.contains(html, "card-section-header")
  let assert True = string.contains(html, "btn-primary")
  let assert True = string.contains(html, "btn-entity-action")
  let assert True = string.contains(html, "btn-sm")
  let assert False = string.contains(html, "btn btn-sm btn-primary")
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
    |> element.to_document_string

  let assert True = string.contains(html, "detail-section-header")
  let assert True = string.contains(html, "task-section-action")
  let assert True = string.contains(html, "btn-primary")
  let assert True = string.contains(html, "disabled")
  let assert False = string.contains(html, "btn btn-sm btn-primary")
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
    |> element.to_document_string

  let assert True = string.contains(html, "Invite link")
  let assert True = string.contains(html, "readonly")
  let assert True = string.contains(html, "btn-secondary")
  let assert True = string.contains(html, "btn-entity-action")
  let assert True = string.contains(html, "type=\"button\"")
}

pub fn error_notice_renders_error_text_test() {
  let error_html =
    error_notice.view("Boom")
    |> element.to_document_string

  let assert True = string.contains(error_html, "Boom")
}

pub fn error_banner_renders_message_test() {
  let html = error_banner.view("Oops") |> element.to_document_string
  let assert True = string.contains(html, "Oops")
  let assert True = string.contains(html, "error-banner")
}
