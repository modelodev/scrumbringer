import gleam/string
import lustre/element
import lustre/element/html

import domain/remote
import scrumbringer_client/features/layout/member_mobile_shell
import scrumbringer_client/features/now_working/mobile as now_working_mobile
import scrumbringer_client/i18n/locale
import scrumbringer_client/theme

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

fn assert_not_contains(html: String, fragment: String) {
  let assert False = string.contains(html, fragment)
}

fn now_working_config() -> now_working_mobile.Config(String) {
  now_working_mobile.Config(
    locale: locale.En,
    theme: theme.Default,
    panel_expanded: False,
    user_id: 7,
    tasks: remote.NotAsked,
    active_sessions: [],
    server_offset_ms: 0,
    disable_actions: False,
    on_panel_toggled: "panel-toggled",
    on_pause: "pause",
    on_complete: fn(_, _) { "complete" },
    on_start: fn(_) { "start" },
    on_release: fn(_, _) { "release" },
  )
}

fn shell_config() -> member_mobile_shell.Config(String) {
  member_mobile_shell.Config(
    title: "Pool",
    theme: theme.Default,
    left_drawer_open: True,
    right_drawer_open: False,
    main_content: html.div([], [element.text("Main")]),
    left_content: html.div([], [element.text("Left")]),
    right_content: html.div([], [element.text("Right")]),
    now_working: now_working_config(),
    on_left_drawer_toggle: "left",
    on_right_drawer_toggle: "right",
    on_drawers_close: "close",
  )
}

pub fn topbar_drawer_buttons_use_semantic_icon_buttons_test() {
  let html =
    shell_config()
    |> member_mobile_shell.view
    |> element.to_document_string

  assert_contains(html, "data-testid=\"mobile-menu-btn\"")
  assert_contains(html, "data-testid=\"mobile-user-btn\"")
  assert_contains(html, "aria-label=\"Open navigation menu\"")
  assert_contains(html, "aria-label=\"Open activity panel\"")
  assert_contains(html, "aria-expanded=\"true\"")
  assert_contains(html, "aria-expanded=\"false\"")
  assert_contains(html, "btn-global-action")
  assert_contains(html, "btn-icon")
  assert_not_contains(html, "class=\"mobile-menu-btn\"")
  assert_not_contains(html, "class=\"mobile-user-btn\"")
  assert_not_contains(html, "heroicon-inline")
}
