import lustre/element
import lustre/element/html
import support/render_assertions

import domain/remote
import scrumbringer_client/features/layout/member_mobile_shell
import scrumbringer_client/features/now_working/mobile as now_working_mobile
import scrumbringer_client/i18n/locale
import scrumbringer_client/theme

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
    on_close: fn(_, _) { "close" },
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
    |> render_assertions.html

  render_assertions.contains(html, "data-testid=\"mobile-menu-btn\"")
  render_assertions.contains(html, "data-testid=\"mobile-user-btn\"")
  render_assertions.contains(html, "aria-label=\"Open navigation menu\"")
  render_assertions.contains(html, "aria-label=\"Open activity panel\"")
  render_assertions.contains(html, "aria-expanded=\"true\"")
  render_assertions.contains(html, "aria-expanded=\"false\"")
  render_assertions.contains(html, "btn-global-action")
  render_assertions.contains(html, "btn-icon")
  render_assertions.not_contains(html, "class=\"mobile-menu-btn\"")
  render_assertions.not_contains(html, "class=\"mobile-user-btn\"")
  render_assertions.not_contains(html, "heroicon-inline")
}
