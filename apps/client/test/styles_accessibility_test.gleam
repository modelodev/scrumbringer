import support/render_assertions

import scrumbringer_client/styles

pub fn base_css_includes_required_indicator_styles_test() {
  let css = styles.base_css()

  render_assertions.contains(css, "required-indicator")
}

pub fn base_css_includes_touch_target_size_test() {
  let css = styles.base_css()

  render_assertions.contains(css, "min-width: 44px")
  render_assertions.contains(css, "min-height: 44px")
}

pub fn base_css_includes_highlight_utility_classes_test() {
  let css = styles.base_css()

  render_assertions.contains(css, ".is-highlight-source")
  render_assertions.contains(css, ".is-highlight-target")
  render_assertions.contains(css, ".is-highlight-dimmed")
  render_assertions.contains(css, ".highlight-info")
  render_assertions.contains(css, ".highlight-success")
}

pub fn highlight_utility_classes_do_not_define_transitions_test() {
  let css = styles.base_css()

  render_assertions.not_contains(css, ".is-highlight-source { transition")
  render_assertions.not_contains(css, ".is-highlight-target { transition")
  render_assertions.not_contains(css, ".is-highlight-dimmed { transition")
}

pub fn base_css_includes_polished_reduced_motion_rules_test() {
  let css = styles.base_css()

  render_assertions.contains(css, "prefers-reduced-motion: reduce")
  render_assertions.contains(css, "transition-delay: 0ms")
  render_assertions.contains(css, ".decay-shake-low")
}

pub fn progress_fills_avoid_width_transitions_test() {
  let css = styles.base_css()

  render_assertions.contains(css, "--progress-width")
  render_assertions.contains(css, "transition: clip-path")
  render_assertions.not_contains(css, "transition: width")
  render_assertions.not_contains(css, "transition: max-height")
}

pub fn touch_claim_actions_are_visible_without_hover_test() {
  let css = styles.base_css()

  render_assertions.contains(css, "@media (hover: none), (pointer: coarse)")
  render_assertions.contains(css, ".btn-claim-mini { opacity: 1")
}

pub fn auth_actions_stay_grouped_on_mobile_test() {
  let css = styles.base_css()

  render_assertions.contains(
    css,
    ".auth-actions { align-items: center; flex-wrap: wrap",
  )
  render_assertions.contains(css, ".auth-submit { flex: 1 1 132px")
  render_assertions.contains(css, "@media (max-width: 340px)")
}

pub fn left_sidebar_reserves_scrollbar_space_and_truncates_nav_labels_test() {
  let css = styles.base_css()

  render_assertions.contains(css, "grid-template-columns: minmax(248px, 264px)")
  render_assertions.contains(css, "scrollbar-gutter: stable")
  render_assertions.contains(css, ".nav-link { display: flex")
  render_assertions.contains(css, "width: 100%; min-width: 0")
  render_assertions.contains(css, ".nav-label { flex: 1; min-width: 0")
  render_assertions.contains(css, "text-overflow: ellipsis")
  render_assertions.contains(css, ".nav-link .nav-icon, .nav-link .badge")
}

pub fn pool_canvas_can_scroll_horizontally_without_collapsing_cards_test() {
  let css = styles.base_css()

  render_assertions.contains(css, ".content.pool-main { overflow-x: auto")
  render_assertions.contains(css, ".pool-main { flex: 1 1 auto")
  render_assertions.contains(css, "overflow-x: auto; overflow-y: hidden")
  render_assertions.contains(
    css,
    "width: 100% !important; min-width: 0 !important",
  )
}

pub fn card_show_uses_wide_panel_and_mobile_fullscreen_test() {
  let css = styles.base_css()

  render_assertions.contains(css, ".card-show { position: fixed")
  render_assertions.contains(css, "justify-content: flex-end")
  render_assertions.contains(css, "width: min(920px, calc(100vw - 48px))")
  render_assertions.contains(css, ".card-show, .task-show { padding: 0")
  render_assertions.contains(css, "height: 100dvh; max-height: 100dvh")
}

pub fn plan_tree_branch_rows_do_not_shift_tree_geometry_test() {
  let css = styles.base_css()

  render_assertions.contains(
    css,
    ".plan-tree-cell.has-children .plan-tree-title",
  )
  render_assertions.not_contains(css, ".plan-tree-cell.has-children {")
  render_assertions.contains(
    css,
    ".plan-tree-gutter { display: inline-flex; align-items: stretch; align-self: stretch",
  )
  render_assertions.contains(
    css,
    ".plan-tree-node.is-open::after { content: \"\"; position: absolute; left: 11px; top: 13px; bottom: -12px",
  )
  render_assertions.contains(
    css,
    ".plan-tree-rail.is-continue::before, .plan-tree-rail.is-elbow::before { left: 11px; top: -12px; bottom: -12px",
  )
}
