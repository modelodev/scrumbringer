import gleam/list
import gleam/string
import lustre/element
import lustre/element/html.{text}

import scrumbringer_client/features/layout/responsive_drawer

pub type TestMsg {
  NoOp
}

fn assert_contains(html: String, text: String) {
  let assert True = string.contains(html, text)
}

fn assert_not_contains(html: String, text: String) {
  let assert False = string.contains(html, text)
}

fn assert_equal(actual: a, expected: a) {
  let assert True = actual == expected
}

pub fn drawer_closed_has_no_open_class_test() {
  let rendered =
    responsive_drawer.view(False, responsive_drawer.Left, NoOp, text("Content"))

  let html = element.to_document_string(rendered)
  assert_not_contains(html, "drawer-open")
  assert_contains(html, "drawer-overlay")
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
  assert_contains(html, "drawer-open")
  assert_contains(html, "Menu Content")
}

pub fn drawer_has_overlay_always_test() {
  let rendered =
    responsive_drawer.view(False, responsive_drawer.Left, NoOp, text("Content"))

  let html = element.to_document_string(rendered)
  assert_contains(html, "drawer-overlay")
}

pub fn drawer_left_has_left_class_test() {
  let rendered =
    responsive_drawer.view(True, responsive_drawer.Left, NoOp, element.none())

  let html = element.to_document_string(rendered)
  assert_contains(html, "drawer-left")
}

pub fn drawer_right_has_right_class_test() {
  let rendered =
    responsive_drawer.view(True, responsive_drawer.Right, NoOp, element.none())

  let html = element.to_document_string(rendered)
  assert_contains(html, "drawer-right")
}

pub fn drawer_has_aria_modal_test() {
  let rendered =
    responsive_drawer.view(True, responsive_drawer.Left, NoOp, element.none())

  let html = element.to_document_string(rendered)
  assert_contains(html, "aria-modal=\"true\"")
}

pub fn drawer_has_role_dialog_test() {
  let rendered =
    responsive_drawer.view(True, responsive_drawer.Left, NoOp, element.none())

  let html = element.to_document_string(rendered)
  assert_contains(html, "role=\"dialog\"")
}

pub fn drawer_has_close_button_test() {
  let rendered =
    responsive_drawer.view(True, responsive_drawer.Left, NoOp, element.none())

  let html = element.to_document_string(rendered)
  assert_contains(html, "drawer-close")
}

pub fn drawer_has_testid_test() {
  let rendered =
    responsive_drawer.view(True, responsive_drawer.Left, NoOp, element.none())

  let html = element.to_document_string(rendered)
  assert_contains(html, "left-drawer")
}

pub fn drawer_with_element_none_content_renders_test() {
  let rendered =
    responsive_drawer.view(True, responsive_drawer.Left, NoOp, element.none())

  let html = element.to_document_string(rendered)
  assert_contains(html, "drawer-content")
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

  assert_contains(html_left, "left-drawer")
  assert_contains(html_right, "right-drawer")
}
