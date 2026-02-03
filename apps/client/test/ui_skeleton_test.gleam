import gleam/string
import gleeunit/should
import lustre/element

import scrumbringer_client/ui/skeleton

pub fn skeleton_line_has_skeleton_class_test() {
  let rendered = skeleton.skeleton_line("100%", "16px")
  let html = element.to_document_string(rendered)

  string.contains(html, "skeleton") |> should.be_true
}

pub fn skeleton_line_has_dimensions_test() {
  let rendered = skeleton.skeleton_line("200px", "20px")
  let html = element.to_document_string(rendered)

  string.contains(html, "200px") |> should.be_true
  string.contains(html, "20px") |> should.be_true
}

pub fn skeleton_card_has_skeleton_class_test() {
  let rendered = skeleton.skeleton_card()
  let html = element.to_document_string(rendered)

  string.contains(html, "skeleton") |> should.be_true
}
