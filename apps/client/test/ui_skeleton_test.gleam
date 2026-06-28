import gleam/string
import lustre/element

import scrumbringer_client/ui/skeleton

pub fn skeleton_line_has_skeleton_class_test() {
  let rendered = skeleton.skeleton_line("100%", "16px")
  let html = element.to_document_string(rendered)

  let assert True = string.contains(html, "skeleton")
}

pub fn skeleton_line_has_dimensions_test() {
  let rendered = skeleton.skeleton_line("200px", "20px")
  let html = element.to_document_string(rendered)

  let assert True = string.contains(html, "200px")
  let assert True = string.contains(html, "20px")
}
