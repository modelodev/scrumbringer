import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element, none}
import lustre/element/html.{button, div, text}
import lustre/event

pub type Item(msg) {
  Item(
    label: String,
    testid: String,
    on_click: msg,
    disabled: Bool,
    title: Option(String),
  )
}

pub fn item(label: String, testid: String, on_click: msg) -> Item(msg) {
  Item(label, testid, on_click, False, None)
}

pub fn disabled_item(
  label: String,
  testid: String,
  reason: String,
  on_click: msg,
) -> Item(msg) {
  Item(label, testid, on_click, True, Some(reason))
}

pub fn view(
  trigger_label: String,
  trigger_testid: String,
  menu_id: String,
  trigger_aria_label: Option(String),
  menu_class: String,
  trigger_class: String,
  items_class: String,
  item_class: String,
  items: List(Item(msg)),
) -> Element(msg) {
  case items {
    [] -> none()
    _ ->
      element.element(
        "details",
        [
          attribute.class(menu_class),
          attribute.attribute("data-testid", menu_class),
        ],
        [
          element.element(
            "summary",
            [
              attribute.class(trigger_class),
              attribute.attribute("data-testid", trigger_testid),
              attribute.attribute("role", "button"),
              attribute.attribute("aria-label", case trigger_aria_label {
                Some(value) -> value
                None -> trigger_label
              }),
              attribute.attribute("aria-haspopup", "menu"),
              attribute.attribute("aria-controls", menu_id <> "-panel"),
            ],
            [text(trigger_label)],
          ),
          div(
            [
              attribute.class(items_class),
              attribute.attribute("id", menu_id <> "-panel"),
              attribute.attribute("role", "menu"),
            ],
            list.map(items, fn(menu_item) {
              let Item(label:, testid:, on_click:, disabled:, title:) =
                menu_item

              button(
                [
                  attribute.class(item_class),
                  attribute.attribute("data-testid", testid),
                  attribute.attribute("type", "button"),
                  attribute.attribute("role", "menuitem"),
                  attribute.attribute("aria-disabled", bool_string(disabled)),
                  attribute.attribute("title", option_to_string(title)),
                  attribute.disabled(disabled),
                  event.on_click(on_click),
                ],
                [text(label)],
              )
            }),
          ),
        ],
      )
  }
}

fn option_to_string(value: Option(String)) -> String {
  case value {
    Some(text) -> text
    None -> ""
  }
}

fn bool_string(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
}
