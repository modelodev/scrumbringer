//// Task detail modal tabs component.
////
//// Thin wrapper over generic tabs.gleam for task detail modal context.
//// Provides DETALLES | NOTAS tabs for viewing task information and notes.

import lustre/element.{type Element}

import scrumbringer_client/ui/notes_tabs

// =============================================================================
// Types
// =============================================================================

/// Tab variants for Task Detail Modal.
pub type Tab {
  DetailsTab
  NotesTab
}

/// Labels for tabs (i18n compatible).
pub type Labels {
  Labels(details: String, notes: String)
}

/// Configuration for task tabs component.
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

/// Renders the task tabs using the generic tabs component.
pub fn view(config: Config(msg)) -> Element(msg) {
  let Config(active_tab:, notes_count:, has_new_notes:, labels:, on_tab_click:) =
    config

  notes_tabs.view(notes_tabs.Config(
    primary_tab: DetailsTab,
    notes_tab: NotesTab,
    active_tab: active_tab,
    notes_count: notes_count,
    has_new_notes: has_new_notes,
    labels: notes_tabs.Labels(primary: labels.details, notes: labels.notes),
    container_class: "task-tabs",
    tab_class: "task-tab",
    on_tab_click: on_tab_click,
  ))
}
