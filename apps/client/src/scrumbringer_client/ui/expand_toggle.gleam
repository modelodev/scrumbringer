import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{span, text}

pub fn view(expanded: Bool) -> Element(msg) {
  view_with_class(expanded, "expand-icon")
}

pub fn view_with_class(expanded: Bool, class_name: String) -> Element(msg) {
  span([attribute.class(class_name)], [text(symbol(expanded))])
}

fn symbol(expanded: Bool) -> String {
  case expanded {
    True -> "▼"
    False -> "▶"
  }
}
