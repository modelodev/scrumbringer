////
//// Task type icon rendering helpers.
////

import gleam/string
import lustre/element.{type Element}

import scrumbringer_client/theme.{type Theme}
import scrumbringer_client/ui/icon_catalog

/// Render a task type icon if it exists in the catalog.
pub fn view(icon_name: String, size: Int, theme: Theme) -> Element(msg) {
  case string.is_empty(icon_name) {
    True -> element.none()
    False -> {
      let class = case theme {
        theme.Dark -> "icon-theme-dark"
        theme.Default -> ""
      }
      case icon_catalog.exists(icon_name) {
        True -> icon_catalog.render_with_class(icon_name, size, class)
        False -> element.none()
      }
    }
  }
}
