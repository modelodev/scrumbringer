import gleam/string
import lustre/element.{type Element}

pub fn contains(text: String, fragment: String) {
  let assert True = string.contains(text, fragment)
}

pub fn not_contains(text: String, fragment: String) {
  let assert False = string.contains(text, fragment)
}

pub fn html(view: Element(msg)) -> String {
  element.to_document_string(view)
}
