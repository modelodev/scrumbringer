import gleam/string
import gleeunit/should

import scrumbringer_client/styles

pub fn base_css_includes_required_indicator_styles_test() {
  let css = styles.base_css()

  string.contains(css, "required-indicator") |> should.be_true
}

pub fn base_css_includes_touch_target_size_test() {
  let css = styles.base_css()

  string.contains(css, "min-width: 44px") |> should.be_true
  string.contains(css, "min-height: 44px") |> should.be_true
}

pub fn base_css_includes_highlight_utility_classes_test() {
  let css = styles.base_css()

  string.contains(css, ".is-highlight-source") |> should.be_true
  string.contains(css, ".is-highlight-target") |> should.be_true
  string.contains(css, ".is-highlight-dimmed") |> should.be_true
  string.contains(css, ".highlight-info") |> should.be_true
  string.contains(css, ".highlight-success") |> should.be_true
}

pub fn highlight_utility_classes_do_not_define_transitions_test() {
  let css = styles.base_css()

  string.contains(css, ".is-highlight-source { transition") |> should.be_false
  string.contains(css, ".is-highlight-target { transition") |> should.be_false
  string.contains(css, ".is-highlight-dimmed { transition") |> should.be_false
}
