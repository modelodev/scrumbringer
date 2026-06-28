//// ResponsiveDrawer - Drawer component for mobile/tablet
////
//// Mission: Provide slide-out drawer panels for mobile layouts.
////
//// Responsibilities:
//// - Render drawer with content
//// - Handle open/close animation
//// - Overlay backdrop
//// - Close on backdrop click or Escape
////
//// Non-responsibilities:
//// - Drawer content (passed as children)
//// - Global state management (handled by parent)

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div}
import lustre/event

/// Drawer position (left or right)
pub type DrawerPosition {
  Left
  Right
}

/// Renders a responsive drawer
pub fn view(
  is_open: Bool,
  position: DrawerPosition,
  on_close: msg,
  content: Element(msg),
) -> Element(msg) {
  case is_open {
    False -> element.none()
    True -> view_open(position, on_close, content)
  }
}

fn view_open(
  position: DrawerPosition,
  on_close: msg,
  content: Element(msg),
) -> Element(msg) {
  let position_class = case position {
    Left -> " drawer-left"
    Right -> " drawer-right right"
  }

  let testid = case position {
    Left -> "left-drawer"
    Right -> "right-drawer"
  }

  let dialog_label = case position {
    Left -> "Navigation drawer"
    Right -> "Activity drawer"
  }

  element.fragment([
    div(
      [
        attribute.class("drawer-overlay open"),
        attribute.attribute("data-testid", testid <> "-overlay"),
        event.on_click(on_close),
      ],
      [],
    ),
    div(
      [
        attribute.class("drawer" <> position_class <> " drawer-open open"),
        attribute.attribute("data-testid", testid),
        attribute.attribute("role", "dialog"),
        attribute.attribute("aria-modal", "true"),
        attribute.attribute("aria-label", dialog_label),
      ],
      [
        div([attribute.class("drawer-header")], [
          button(
            [
              attribute.class("drawer-close"),
              attribute.attribute("data-testid", "drawer-close"),
              attribute.attribute("aria-label", "Close drawer"),
              event.on_click(on_close),
            ],
            [element.text("\u{00D7}")],
          ),
        ]),
        div([attribute.class("drawer-content")], [content]),
      ],
    ),
  ])
}
