import gleam/list
import gleam/string
import gleeunit/should
import lustre/element
import lustre/element/html.{text}

import scrumbringer_client/features/layout/responsive_drawer

pub type TestMsg {
  NoOp
}

pub fn drawer_closed_has_no_open_class_test() {
  let rendered =
    responsive_drawer.view(False, responsive_drawer.Left, NoOp, text("Content"))

  let html = element.to_document_string(rendered)
  string.contains(html, "drawer-open") |> should.be_false
  string.contains(html, "drawer-overlay") |> should.be_true
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
  string.contains(html, "drawer-open") |> should.be_true
  string.contains(html, "Menu Content") |> should.be_true
}

pub fn drawer_has_overlay_always_test() {
  let rendered =
    responsive_drawer.view(False, responsive_drawer.Left, NoOp, text("Content"))

  let html = element.to_document_string(rendered)
  string.contains(html, "drawer-overlay") |> should.be_true
}

pub fn drawer_left_has_left_class_test() {
  let rendered =
    responsive_drawer.view(True, responsive_drawer.Left, NoOp, element.none())

  let html = element.to_document_string(rendered)
  string.contains(html, "drawer-left") |> should.be_true
}

pub fn drawer_right_has_right_class_test() {
  let rendered =
    responsive_drawer.view(True, responsive_drawer.Right, NoOp, element.none())

  let html = element.to_document_string(rendered)
  string.contains(html, "drawer-right") |> should.be_true
}

pub fn drawer_has_aria_modal_test() {
  let rendered =
    responsive_drawer.view(True, responsive_drawer.Left, NoOp, element.none())

  let html = element.to_document_string(rendered)
  string.contains(html, "aria-modal=\"true\"") |> should.be_true
}

pub fn drawer_has_role_dialog_test() {
  let rendered =
    responsive_drawer.view(True, responsive_drawer.Left, NoOp, element.none())

  let html = element.to_document_string(rendered)
  string.contains(html, "role=\"dialog\"") |> should.be_true
}

pub fn drawer_has_close_button_test() {
  let rendered =
    responsive_drawer.view(True, responsive_drawer.Left, NoOp, element.none())

  let html = element.to_document_string(rendered)
  string.contains(html, "drawer-close") |> should.be_true
}

pub fn drawer_has_testid_test() {
  let rendered =
    responsive_drawer.view(True, responsive_drawer.Left, NoOp, element.none())

  let html = element.to_document_string(rendered)
  string.contains(html, "left-drawer") |> should.be_true
}

pub fn drawer_with_element_none_content_renders_test() {
  let rendered =
    responsive_drawer.view(True, responsive_drawer.Left, NoOp, element.none())

  let html = element.to_document_string(rendered)
  string.contains(html, "drawer-content") |> should.be_true
}

pub fn drawer_positions_are_exhaustive_test() {
  let positions = [responsive_drawer.Left, responsive_drawer.Right]
  list.length(positions) |> should.equal(2)
}

pub fn drawer_left_and_right_have_different_testids_test() {
  let left =
    responsive_drawer.view(True, responsive_drawer.Left, NoOp, element.none())
  let right =
    responsive_drawer.view(True, responsive_drawer.Right, NoOp, element.none())

  let html_left = element.to_document_string(left)
  let html_right = element.to_document_string(right)

  string.contains(html_left, "left-drawer") |> should.be_true
  string.contains(html_right, "right-drawer") |> should.be_true
}
