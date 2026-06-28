import gleam/list
import lustre/element
import lustre/element/html.{text}
import support/assertions.{assert_equal}
import support/render_assertions

import scrumbringer_client/features/layout/responsive_drawer

pub type TestMsg {
  NoOp
}

pub fn drawer_closed_has_no_open_class_test() {
  let rendered =
    responsive_drawer.view(False, responsive_drawer.Left, NoOp, text("Content"))

  let html = element.to_document_string(rendered)
  render_assertions.not_contains(html, "drawer-open")
  render_assertions.not_contains(html, "drawer-overlay")
}

pub fn drawer_open_has_open_class_test() {
  let rendered =
    responsive_drawer.view(
      True,
      responsive_drawer.Left,
      NoOp,
      text("Menu Content"),
    )

  let html = element.to_document_string(rendered)
  render_assertions.contains(html, "drawer-open")
  render_assertions.contains(html, "Menu Content")
}

pub fn drawer_open_has_overlay_test() {
  let rendered =
    responsive_drawer.view(True, responsive_drawer.Left, NoOp, text("Content"))

  let html = element.to_document_string(rendered)
  render_assertions.contains(html, "drawer-overlay")
}

pub fn drawer_left_has_left_class_test() {
  let rendered =
    responsive_drawer.view(True, responsive_drawer.Left, NoOp, element.none())

  let html = element.to_document_string(rendered)
  render_assertions.contains(html, "drawer-left")
}

pub fn drawer_right_has_right_class_test() {
  let rendered =
    responsive_drawer.view(True, responsive_drawer.Right, NoOp, element.none())

  let html = element.to_document_string(rendered)
  render_assertions.contains(html, "drawer-right")
}

pub fn drawer_has_aria_modal_test() {
  let rendered =
    responsive_drawer.view(True, responsive_drawer.Left, NoOp, element.none())

  let html = element.to_document_string(rendered)
  render_assertions.contains(html, "aria-modal=\"true\"")
}

pub fn drawer_has_role_dialog_test() {
  let rendered =
    responsive_drawer.view(True, responsive_drawer.Left, NoOp, element.none())

  let html = element.to_document_string(rendered)
  render_assertions.contains(html, "role=\"dialog\"")
}

pub fn drawer_has_close_button_test() {
  let rendered =
    responsive_drawer.view(True, responsive_drawer.Left, NoOp, element.none())

  let html = element.to_document_string(rendered)
  render_assertions.contains(html, "drawer-close")
}

pub fn drawer_has_testid_test() {
  let rendered =
    responsive_drawer.view(True, responsive_drawer.Left, NoOp, element.none())

  let html = element.to_document_string(rendered)
  render_assertions.contains(html, "left-drawer")
}

pub fn drawer_with_element_none_content_renders_test() {
  let rendered =
    responsive_drawer.view(True, responsive_drawer.Left, NoOp, element.none())

  let html = element.to_document_string(rendered)
  render_assertions.contains(html, "drawer-content")
}

pub fn drawer_positions_are_exhaustive_test() {
  let positions = [responsive_drawer.Left, responsive_drawer.Right]
  list.length(positions) |> assert_equal(2)
}

pub fn drawer_left_and_right_have_different_testids_test() {
  let left =
    responsive_drawer.view(True, responsive_drawer.Left, NoOp, element.none())
  let right =
    responsive_drawer.view(True, responsive_drawer.Right, NoOp, element.none())

  let html_left = element.to_document_string(left)
  let html_right = element.to_document_string(right)

  render_assertions.contains(html_left, "left-drawer")
  render_assertions.contains(html_right, "right-drawer")
}
