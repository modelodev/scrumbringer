import gleam/string
import lustre/element
import scrumbringer_client/features/admin/org_user_fallback
import scrumbringer_client/i18n/locale
import scrumbringer_client/theme
import scrumbringer_client/ui/attribute_value
import scrumbringer_client/ui/empty_state
import scrumbringer_client/ui/error_banner
import scrumbringer_client/ui/error_notice

import scrumbringer_client/ui/layout

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

pub fn layout_theme_switch_renders_options_test() {
  let html =
    layout.theme_switch(locale.En, theme.Default, fn(_s) { "msg" })
    |> element.to_document_string

  let assert True = string.contains(html, "default")
  let assert True = string.contains(html, "dark")
}

pub fn layout_locale_switch_renders_options_test() {
  let html =
    layout.locale_switch(locale.En, fn(_s) { "msg" })
    |> element.to_document_string

  let assert True = string.contains(html, "es")
  let assert True = string.contains(html, "en")
}
