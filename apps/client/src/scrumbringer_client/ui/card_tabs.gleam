//// Card detail modal tabs component.
////
//// Thin wrapper over generic tabs.gleam for card detail modal context.

import lustre/element.{type Element}

import scrumbringer_client/ui/detail_tabs

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

  detail_tabs.view(detail_tabs.Config(
    active_tab: active_tab,
    notes_count: notes_count,
    has_new_notes: has_new_notes,
    labels: detail_tabs.Labels(
      tasks: labels.tasks,
      notes: labels.notes,
      metrics: labels.metrics,
    ),
    tasks_id: TasksTab,
    notes_id: NotesTab,
    metrics_id: MetricsTab,
    container_class: "card-tabs modal-tabs",
    tab_class: "card-tab modal-tab",
    on_tab_click: on_tab_click,
  ))
}
