import gleam/string
import lustre/element.{type Element}

pub fn contains(text: String, fragment: String) {
  let assert True = string.contains(text, fragment)
}

pub fn not_contains(text: String, fragment: String) {
  let assert False = string.contains(text, fragment)
}

pub fn count_occurrences(text: String, fragment: String) -> Int {
  count_occurrences_loop(text, fragment, 0)
}

fn count_occurrences_loop(text: String, fragment: String, count: Int) -> Int {
  case fragment == "" {
    True -> 0
    False ->
      case string.split_once(text, fragment) {
        Ok(#(_, after)) -> count_occurrences_loop(after, fragment, count + 1)
        Error(_) -> count
      }
  }
}

pub fn occurs(text: String, fragment: String, expected: Int) {
  let assert True = count_occurrences(text, fragment) == expected
}

pub fn html(view: Element(msg)) -> String {
  element.to_document_string(view)
}

pub fn fragment_html(elements: List(Element(msg))) -> String {
  element.fragment(elements)
  |> html
}

pub fn view_contains(view: Element(msg), fragment: String) {
  contains(html(view), fragment)
}

pub fn view_not_contains(view: Element(msg), fragment: String) {
  not_contains(html(view), fragment)
}
