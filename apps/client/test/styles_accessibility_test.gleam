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
