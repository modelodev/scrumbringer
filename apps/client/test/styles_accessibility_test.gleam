import gleam/string

import scrumbringer_client/styles

fn assert_contains(css: String, text: String) {
  let assert True = string.contains(css, text)
}

fn assert_not_contains(css: String, text: String) {
  let assert False = string.contains(css, text)
}

pub fn base_css_includes_required_indicator_styles_test() {
  let css = styles.base_css()

  assert_contains(css, "required-indicator")
}

pub fn base_css_includes_touch_target_size_test() {
  let css = styles.base_css()

  assert_contains(css, "min-width: 44px")
  assert_contains(css, "min-height: 44px")
}

pub fn base_css_includes_highlight_utility_classes_test() {
  let css = styles.base_css()

  assert_contains(css, ".is-highlight-source")
  assert_contains(css, ".is-highlight-target")
  assert_contains(css, ".is-highlight-dimmed")
  assert_contains(css, ".highlight-info")
  assert_contains(css, ".highlight-success")
}

pub fn highlight_utility_classes_do_not_define_transitions_test() {
  let css = styles.base_css()

  assert_not_contains(css, ".is-highlight-source { transition")
  assert_not_contains(css, ".is-highlight-target { transition")
  assert_not_contains(css, ".is-highlight-dimmed { transition")
}

pub fn base_css_includes_polished_reduced_motion_rules_test() {
  let css = styles.base_css()

  assert_contains(css, "prefers-reduced-motion: reduce")
  assert_contains(css, "transition-delay: 0ms")
  assert_contains(css, ".decay-shake-low")
}

pub fn progress_fills_avoid_width_transitions_test() {
  let css = styles.base_css()

  assert_contains(css, "--progress-width")
  assert_contains(css, "transition: clip-path")
  assert_not_contains(css, "transition: width")
  assert_not_contains(css, "transition: max-height")
}

pub fn touch_claim_actions_are_visible_without_hover_test() {
  let css = styles.base_css()

  assert_contains(css, "@media (hover: none), (pointer: coarse)")
  assert_contains(css, ".btn-claim-mini { opacity: 1")
}

pub fn auth_actions_stay_grouped_on_mobile_test() {
  let css = styles.base_css()

  assert_contains(css, ".auth-actions { align-items: center; flex-wrap: wrap")
  assert_contains(css, ".auth-submit { flex: 1 1 132px")
  assert_contains(css, "@media (max-width: 340px)")
}

pub fn left_sidebar_reserves_scrollbar_space_and_truncates_nav_labels_test() {
  let css = styles.base_css()

  assert_contains(css, "grid-template-columns: minmax(248px, 264px)")
  assert_contains(css, "scrollbar-gutter: stable")
  assert_contains(css, ".nav-link { display: flex")
  assert_contains(css, "width: 100%; min-width: 0")
  assert_contains(css, ".nav-label { flex: 1; min-width: 0")
  assert_contains(css, "text-overflow: ellipsis")
  assert_contains(css, ".nav-link .nav-icon, .nav-link .badge")
}

pub fn pool_canvas_can_scroll_horizontally_without_collapsing_cards_test() {
  let css = styles.base_css()

  assert_contains(css, ".content.pool-main { overflow-x: auto")
  assert_contains(css, ".pool-main { flex: 1 1 auto")
  assert_contains(css, "overflow-x: auto; overflow-y: hidden")
  assert_contains(css, "width: 100% !important; min-width: 0 !important")
}

pub fn card_show_uses_wide_panel_and_mobile_fullscreen_test() {
  let css = styles.base_css()

  assert_contains(css, ".card-show { position: fixed")
  assert_contains(css, "justify-content: flex-end")
  assert_contains(css, "width: min(920px, calc(100vw - 48px))")
  assert_contains(css, ".card-show { padding: 0; align-items: stretch")
  assert_contains(css, "height: 100dvh; max-height: 100dvh")
}

pub fn plan_tree_branch_rows_do_not_shift_tree_geometry_test() {
  let css = styles.base_css()

  assert_contains(css, ".plan-tree-cell.has-children .plan-tree-title")
  assert_not_contains(css, ".plan-tree-cell.has-children {")
  assert_contains(
    css,
    ".plan-tree-gutter { display: inline-flex; align-items: stretch; align-self: stretch",
  )
  assert_contains(
    css,
    ".plan-tree-node.is-open::after { content: \"\"; position: absolute; left: 10px; top: 13px; bottom: -12px",
  )
  assert_contains(
    css,
    ".plan-tree-rail.is-continue::before, .plan-tree-rail.is-elbow::before { left: 11px; top: -12px; bottom: -12px",
  )
}
