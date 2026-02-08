//// Card detail modal tabs component.
////
//// Thin wrapper over generic tabs.gleam for card detail modal context.

import lustre/element.{type Element}

import gleam/option as opt
import scrumbringer_client/ui/tabs

// =============================================================================
// Types (Public API preserved)
// =============================================================================

pub type Tab {
  TasksTab
  NotesTab
  MetricsTab
}

pub type Labels {
  Labels(tasks: String, notes: String, metrics: String)
}

pub type Config(msg) {
  Config(
    active_tab: Tab,
    notes_count: Int,
    has_new_notes: Bool,
    labels: Labels,
    on_tab_click: fn(Tab) -> msg,
  )
}

// =============================================================================
// View
// =============================================================================

/// Renders the card tabs using the generic tabs component.
pub fn view(config: Config(msg)) -> Element(msg) {
  let Config(active_tab:, notes_count:, has_new_notes:, labels:, on_tab_click:) =
    config

  tabs.view(tabs.config(
    tabs: [
      tabs.TabItem(
        id: TasksTab,
        label: labels.tasks,
        count: opt.None,
        has_indicator: False,
      ),
      tabs.TabItem(
        id: NotesTab,
        label: labels.notes,
        count: case notes_count > 0 {
          True -> opt.Some(notes_count)
          False -> opt.None
        },
        has_indicator: has_new_notes,
      ),
      tabs.TabItem(
        id: MetricsTab,
        label: labels.metrics,
        count: opt.None,
        has_indicator: False,
      ),
    ],
    active: active_tab,
    container_class: "card-tabs modal-tabs",
    tab_class: "card-tab modal-tab",
    on_click: on_tab_click,
  ))
}
