import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{span, text}

pub fn view(expanded: Bool) -> Element(msg) {
  view_with_class(expanded, "expand-icon")
}

pub fn view_with_class(expanded: Bool, class_name: String) -> Element(msg) {
  let classes =
    class_name
    <> case expanded {
      True -> " is-expanded"
      False -> ""
    }

  span([attribute.class(classes)], [text(symbol())])
}

fn symbol() -> String {
  "▶"
}
