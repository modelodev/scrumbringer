import gleam/option.{None, Some}
import lustre/element.{type Element}

import scrumbringer_client/ui/tabs

pub type Labels {
  Labels(primary: String, notes: String)
}

pub type Config(tab, msg) {
  Config(
    primary_tab: tab,
    notes_tab: tab,
    active_tab: tab,
    notes_count: Int,
    has_new_notes: Bool,
    labels: Labels,
    container_class: String,
    tab_class: String,
    on_tab_click: fn(tab) -> msg,
  )
}

pub fn view(config: Config(tab, msg)) -> Element(msg) {
  let Config(
    primary_tab: primary_tab,
    notes_tab: notes_tab,
    active_tab: active_tab,
    notes_count: notes_count,
    has_new_notes: has_new_notes,
    labels: labels,
    container_class: container_class,
    tab_class: tab_class,
    on_tab_click: on_tab_click,
  ) = config

  tabs.view(tabs.config(
    tabs: [
      tabs.TabItem(
        id: primary_tab,
        label: labels.primary,
        count: None,
        has_indicator: False,
      ),
      tabs.TabItem(
        id: notes_tab,
        label: labels.notes,
        count: case notes_count > 0 {
          True -> Some(notes_count)
          False -> None
        },
        has_indicator: has_new_notes,
      ),
    ],
    active: active_tab,
    container_class: container_class,
    tab_class: tab_class,
    on_click: on_tab_click,
  ))
}
