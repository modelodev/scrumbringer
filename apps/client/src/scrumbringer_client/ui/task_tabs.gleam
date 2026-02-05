//// Task detail modal tabs component.
////
//// Thin wrapper over generic tabs.gleam for task detail modal context.
//// Provides DETALLES | NOTAS tabs for viewing task information and notes.

import gleam/option as opt
import lustre/element.{type Element}

import scrumbringer_client/ui/tabs

// =============================================================================
// Types
// =============================================================================

/// Tab variants for Task Detail Modal.
pub type Tab {
  DetailsTab
  DependenciesTab
  NotesTab
}

/// Labels for tabs (i18n compatible).
pub type Labels {
  Labels(details: String, dependencies: String, notes: String)
}

/// Configuration for task tabs component.
pub type Config(msg) {
  Config(
    active_tab: Tab,
    dependencies_count: Int,
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
  let Config(
    active_tab: active_tab,
    dependencies_count: dependencies_count,
    notes_count: notes_count,
    has_new_notes: has_new_notes,
    labels: labels,
    on_tab_click: on_tab_click,
  ) = config

  tabs.view(tabs.config(
    tabs: [
      tabs.TabItem(
        id: DetailsTab,
        label: labels.details,
        count: opt.None,
        has_indicator: False,
      ),
      tabs.TabItem(
        id: DependenciesTab,
        label: labels.dependencies,
        count: case dependencies_count > 0 {
          True -> opt.Some(dependencies_count)
          False -> opt.None
        },
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
    ],
    active: active_tab,
    container_class: "task-tabs modal-tabs",
    tab_class: "task-tab modal-tab",
    on_click: on_tab_click,
  ))
}
