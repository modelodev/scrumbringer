//// Shared wrapper for detail modal tab bars.

import gleam/option as opt
import lustre/element.{type Element}

import scrumbringer_client/ui/tabs

pub type Labels {
  Labels(tasks: String, notes: String, metrics: String)
}

pub type Config(id, msg) {
  Config(
    active_tab: id,
    notes_count: Int,
    has_new_notes: Bool,
    labels: Labels,
    tasks_id: id,
    notes_id: id,
    metrics_id: id,
    container_class: String,
    tab_class: String,
    on_tab_click: fn(id) -> msg,
  )
}

pub fn view(config: Config(id, msg)) -> Element(msg) {
  let Config(
    active_tab: active_tab,
    notes_count: notes_count,
    has_new_notes: has_new_notes,
    labels: labels,
    tasks_id: tasks_id,
    notes_id: notes_id,
    metrics_id: metrics_id,
    container_class: container_class,
    tab_class: tab_class,
    on_tab_click: on_tab_click,
  ) = config

  tabs.view(tabs.config(
    tabs: [
      tabs.TabItem(
        id: tasks_id,
        label: labels.tasks,
        count: opt.None,
        has_indicator: False,
      ),
      tabs.TabItem(
        id: notes_id,
        label: labels.notes,
        count: case notes_count > 0 {
          True -> opt.Some(notes_count)
          False -> opt.None
        },
        has_indicator: has_new_notes,
      ),
      tabs.TabItem(
        id: metrics_id,
        label: labels.metrics,
        count: opt.None,
        has_indicator: False,
      ),
    ],
    active: active_tab,
    container_class: container_class,
    tab_class: tab_class,
    on_click: on_tab_click,
  ))
}
