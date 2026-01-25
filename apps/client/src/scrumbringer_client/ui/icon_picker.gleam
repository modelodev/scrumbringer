//// Icon picker component for task type creation.
////
//// Provides a visual grid interface for selecting icons from the curated catalog.
//// Features search filtering and category tabs.

import gleam/list
import gleam/string

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

import scrumbringer_client/ui/icon_catalog.{
  type CatalogIcon, type IconCategory, All,
}

// =============================================================================
// Types
// =============================================================================

/// Messages emitted by the icon picker.
pub type IconPickerMsg {
  SearchChanged(String)
  CategoryChanged(String)
  IconSelected(String)
}

// =============================================================================
// View
// =============================================================================

/// Render the icon picker component.
///
/// Arguments:
/// - search_query: Current search text
/// - active_category: Currently selected category (as string ID)
/// - selected_icon: Currently selected icon ID (if any)
/// - on_msg: Message handler callback
pub fn view(
  search_query: String,
  active_category: String,
  selected_icon: String,
  on_msg: fn(IconPickerMsg) -> msg,
) -> Element(msg) {
  let category = category_from_string(active_category)

  // Get filtered icons
  let icons = case string.trim(search_query) {
    "" -> icon_catalog.by_category(category)
    query -> {
      let searched = icon_catalog.search(query)
      case category {
        All -> searched
        _ -> list.filter(searched, fn(i) { i.category == category })
      }
    }
  }

  html.div([attribute.class("icon-picker")], [
    // Search input
    html.div([attribute.class("icon-picker-search")], [
      html.input([
        attribute.type_("text"),
        attribute.placeholder("Buscar iconos..."),
        attribute.value(search_query),
        attribute.class("form-control form-control-sm"),
        event.on_input(fn(v) { on_msg(SearchChanged(v)) }),
      ]),
    ]),
    // Category tabs
    html.div(
      [attribute.class("icon-picker-tabs")],
      list.map(icon_catalog.categories(), fn(cat) {
        let cat_id = category_to_string(cat)
        let is_active = cat_id == active_category
        html.button(
          [
            attribute.class(
              "icon-picker-tab"
              <> case is_active {
                True -> " active"
                False -> ""
              },
            ),
            attribute.type_("button"),
            event.on_click(on_msg(CategoryChanged(cat_id))),
          ],
          [html.text(icon_catalog.category_label(cat))],
        )
      }),
    ),
    // Icon grid
    html.div([attribute.class("icon-picker-grid")], case list.length(icons) {
      0 -> [
        html.div([attribute.class("icon-picker-empty")], [
          html.text("No se encontraron iconos"),
        ]),
      ]
      _ ->
        list.map(icons, fn(icon) {
          render_icon_button(icon, icon.id == selected_icon, on_msg)
        })
    }),
  ])
}

/// Render a single icon button in the grid.
fn render_icon_button(
  icon: CatalogIcon,
  is_selected: Bool,
  on_msg: fn(IconPickerMsg) -> msg,
) -> Element(msg) {
  html.button(
    [
      attribute.class(
        "icon-picker-item"
        <> case is_selected {
          True -> " selected"
          False -> ""
        },
      ),
      attribute.type_("button"),
      attribute.attribute("title", icon.label),
      event.on_click(on_msg(IconSelected(icon.id))),
    ],
    [
      html.span([attribute.class("icon-picker-icon")], [
        icon_catalog.render(icon.id, 24),
      ]),
      html.span([attribute.class("icon-picker-label")], [
        html.text(icon.label),
      ]),
    ],
  )
}

// =============================================================================
// Category Conversion
// =============================================================================

/// Convert category enum to string ID.
pub fn category_to_string(cat: IconCategory) -> String {
  case cat {
    icon_catalog.All -> "all"
    icon_catalog.Tasks -> "tasks"
    icon_catalog.Status -> "status"
    icon_catalog.Priority -> "priority"
    icon_catalog.Objects -> "objects"
    icon_catalog.Actions -> "actions"
  }
}

/// Convert string ID to category enum.
pub fn category_from_string(s: String) -> IconCategory {
  case s {
    "tasks" -> icon_catalog.Tasks
    "status" -> icon_catalog.Status
    "priority" -> icon_catalog.Priority
    "objects" -> icon_catalog.Objects
    "actions" -> icon_catalog.Actions
    _ -> icon_catalog.All
  }
}
