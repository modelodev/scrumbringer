import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, span, text}
import lustre/event
import scrumbringer_client/ui/attribute_value

pub type TabItem(id) {
  TabItem(id: id, label: String, count: Option(Int), has_indicator: Bool)
}

pub type Config(id, msg) {
  Config(
    tabs: List(TabItem(id)),
    active: id,
    container_class: String,
    tab_class: String,
    on_click: fn(id) -> msg,
    testid: Option(String),
  )
}

pub fn config(
  tabs tabs: List(TabItem(id)),
  active active: id,
  container_class container_class: String,
  tab_class tab_class: String,
  on_click on_click: fn(id) -> msg,
) -> Config(id, msg) {
  Config(tabs:, active:, container_class:, tab_class:, on_click:, testid: None)
}

pub fn with_testid(config: Config(id, msg), testid: String) -> Config(id, msg) {
  Config(..config, testid: Some(testid))
}

pub fn view(cfg: Config(id, msg)) -> Element(msg) {
  let Config(tabs:, active:, container_class:, tab_class:, on_click:, testid:) =
    cfg

  div(
    tablist_attributes(container_class, testid),
    indexed_buttons(tabs, tabs, 0, active, tab_class, on_click),
  )
}

fn tablist_attributes(
  container_class: String,
  testid: Option(String),
) -> List(attribute.Attribute(msg)) {
  let base = [attribute.class(container_class), attribute.role("tablist")]

  case testid {
    Some(value) -> [attribute.attribute("data-testid", value), ..base]
    None -> base
  }
}

pub fn panel(
  active_tab: id,
  tabs: List(TabItem(id)),
  content: Element(msg),
) -> Element(msg) {
  let index = active_index(tabs, active_tab)

  div(
    [
      attribute.class("detail-tabpanel"),
      attribute.attribute("role", "tabpanel"),
      attribute.id(tab_panel_dom_id(index)),
      attribute.attribute("aria-labelledby", tab_dom_id(index)),
    ],
    [content],
  )
}

fn indexed_buttons(
  remaining: List(TabItem(id)),
  all_tabs: List(TabItem(id)),
  index: Int,
  active: id,
  tab_class: String,
  on_click: fn(id) -> msg,
) -> List(Element(msg)) {
  case remaining {
    [] -> []
    [item, ..rest] -> {
      let previous_id = previous_tab_id(all_tabs, index)
      let next_id = next_tab_id(all_tabs, index)
      let first_id = first_tab_id(all_tabs, item.id)
      let last_id = last_tab_id(all_tabs, item.id)

      [
        tab_button(
          item,
          index,
          list.length(all_tabs),
          item.id == active,
          tab_class,
          on_click,
          first_id,
          last_id,
          previous_id,
          next_id,
        ),
        ..indexed_buttons(
          rest,
          all_tabs,
          index + 1,
          active,
          tab_class,
          on_click,
        )
      ]
    }
  }
}

fn tab_button(
  item: TabItem(id),
  index: Int,
  total: Int,
  is_active: Bool,
  base_class: String,
  on_click: fn(id) -> msg,
  first_id: id,
  last_id: id,
  previous_id: Option(id),
  next_id: Option(id),
) -> Element(msg) {
  let active_class = case is_active {
    True -> base_class <> " tab-active"
    False -> base_class
  }

  button(
    [
      attribute.class(active_class),
      attribute.role("tab"),
      attribute.id(tab_dom_id(index)),
      attribute.attribute("aria-controls", tab_panel_dom_id(index)),
      attribute.attribute("aria-selected", attribute_value.boolean(is_active)),
      attribute.attribute("aria-setsize", int.to_string(total)),
      attribute.attribute("aria-posinset", int.to_string(index + 1)),
      attribute.attribute("tabindex", case is_active {
        True -> "0"
        False -> "-1"
      }),
      on_arrow_navigation(
        item.id,
        previous_id,
        next_id,
        first_id,
        last_id,
        on_click,
      ),
      event.on_click(on_click(item.id)),
    ],
    [
      text(item.label),
      view_count(item.count),
      view_indicator(item.has_indicator),
    ],
  )
}

fn on_arrow_navigation(
  current_id: id,
  previous_id: Option(id),
  next_id: Option(id),
  first_id: id,
  last_id: id,
  on_click: fn(id) -> msg,
) -> attribute.Attribute(msg) {
  event.advanced("keydown", {
    use key <- decode.field("key", decode.string)

    case key {
      "ArrowLeft" ->
        case previous_id {
          Some(id) ->
            decode.success(event.handler(
              on_click(id),
              prevent_default: True,
              stop_propagation: True,
            ))
          None ->
            decode.failure(
              event.handler(
                on_click(current_id),
                prevent_default: False,
                stop_propagation: False,
              ),
              expected: "tab-left",
            )
        }

      "ArrowRight" ->
        case next_id {
          Some(id) ->
            decode.success(event.handler(
              on_click(id),
              prevent_default: True,
              stop_propagation: True,
            ))
          None ->
            decode.failure(
              event.handler(
                on_click(current_id),
                prevent_default: False,
                stop_propagation: False,
              ),
              expected: "tab-right",
            )
        }

      "Home" ->
        decode.success(event.handler(
          on_click(first_id),
          prevent_default: True,
          stop_propagation: True,
        ))

      "End" ->
        decode.success(event.handler(
          on_click(last_id),
          prevent_default: True,
          stop_propagation: True,
        ))

      _ ->
        decode.failure(
          event.handler(
            on_click(current_id),
            prevent_default: False,
            stop_propagation: False,
          ),
          expected: "tab-arrow",
        )
    }
  })
}

fn first_tab_id(tabs: List(TabItem(id)), current_id: id) -> id {
  case tab_id_at(tabs, 0) {
    Some(id) -> id
    None -> current_id
  }
}

fn last_tab_id(tabs: List(TabItem(id)), current_id: id) -> id {
  case tab_id_at(tabs, list.length(tabs) - 1) {
    Some(id) -> id
    None -> current_id
  }
}

fn tab_dom_id(index: Int) -> String {
  "modal-tab-" <> int.to_string(index)
}

fn tab_panel_dom_id(index: Int) -> String {
  "modal-tabpanel-" <> int.to_string(index)
}

fn previous_tab_id(tabs: List(TabItem(id)), index: Int) -> Option(id) {
  case tabs {
    [] -> None
    _ ->
      case index <= 0 {
        True -> tab_id_at(tabs, list.length(tabs) - 1)
        False -> tab_id_at(tabs, index - 1)
      }
  }
}

fn next_tab_id(tabs: List(TabItem(id)), index: Int) -> Option(id) {
  case tabs {
    [] -> None
    _ ->
      case index >= list.length(tabs) - 1 {
        True -> tab_id_at(tabs, 0)
        False -> tab_id_at(tabs, index + 1)
      }
  }
}

fn tab_id_at(tabs: List(TabItem(id)), target_index: Int) -> Option(id) {
  tab_id_at_loop(tabs, target_index, 0)
}

fn tab_id_at_loop(
  tabs: List(TabItem(id)),
  target_index: Int,
  current_index: Int,
) -> Option(id) {
  case tabs {
    [] -> None
    [item, ..rest] ->
      case current_index == target_index {
        True -> Some(item.id)
        False -> tab_id_at_loop(rest, target_index, current_index + 1)
      }
  }
}

fn active_index(tabs: List(TabItem(id)), active_tab: id) -> Int {
  active_index_loop(tabs, active_tab, 0)
}

fn active_index_loop(tabs: List(TabItem(id)), active_tab: id, index: Int) -> Int {
  case tabs {
    [] -> 0
    [item, ..rest] ->
      case item.id == active_tab {
        True -> index
        False -> active_index_loop(rest, active_tab, index + 1)
      }
  }
}

fn view_count(count: Option(Int)) -> Element(msg) {
  case count {
    Some(n) if n > 0 ->
      span([attribute.class("tab-count")], [
        text(" (" <> int.to_string(n) <> ")"),
      ])
    Some(_) -> element.none()
    None -> element.none()
  }
}

fn view_indicator(has_indicator: Bool) -> Element(msg) {
  case has_indicator {
    True -> span([attribute.class("new-notes-indicator")], [text("●")])
    False -> element.none()
  }
}
