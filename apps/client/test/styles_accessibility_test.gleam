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
