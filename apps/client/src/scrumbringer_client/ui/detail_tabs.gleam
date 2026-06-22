//// Generic detail-surface tab bar and tabpanel helpers.

import gleam/int
import gleam/list
import gleam/option.{type Option}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div}

import scrumbringer_client/ui/tabs as base_tabs

pub type TabItem(id) {
  TabItem(id: id, label: String, count: Option(Int), has_indicator: Bool)
}

pub type Config(id, msg) {
  Config(
    active_tab: id,
    tabs: List(TabItem(id)),
    container_class: String,
    tab_class: String,
    on_tab_click: fn(id) -> msg,
  )
}

pub fn view(config: Config(id, msg)) -> Element(msg) {
  base_tabs.view(base_tabs.config(
    tabs: list.map(config.tabs, to_base_tab),
    active: config.active_tab,
    container_class: config.container_class,
    tab_class: config.tab_class,
    on_click: config.on_tab_click,
  ))
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
      attribute.id(tabpanel_id(index)),
      attribute.attribute("aria-labelledby", tab_id(index)),
    ],
    [content],
  )
}

pub fn tab_id(index: Int) -> String {
  "modal-tab-" <> int.to_string(index)
}

pub fn tabpanel_id(index: Int) -> String {
  "modal-tabpanel-" <> int.to_string(index)
}

fn to_base_tab(item: TabItem(id)) -> base_tabs.TabItem(id) {
  base_tabs.TabItem(
    id: item.id,
    label: item.label,
    count: item.count,
    has_indicator: item.has_indicator,
  )
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
