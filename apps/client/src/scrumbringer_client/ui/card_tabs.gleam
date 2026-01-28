//// Card detail modal tabs component.

import gleam/int
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, span, text}
import lustre/event

pub type Tab {
  TasksTab
  NotesTab
}

pub type Labels {
  Labels(tasks: String, notes: String)
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

pub fn view(config: Config(msg)) -> Element(msg) {
  let Config(
    active_tab: active_tab,
    notes_count: notes_count,
    has_new_notes: has_new_notes,
    labels: labels,
    on_tab_click: on_tab_click,
  ) = config

  div([attribute.class("card-tabs"), attribute.role("tablist")], [
    tab_button(TasksTab, labels.tasks, active_tab, None, False, on_tab_click),
    tab_button(
      NotesTab,
      labels.notes,
      active_tab,
      case notes_count > 0 {
        True -> Some(notes_count)
        False -> None
      },
      has_new_notes,
      on_tab_click,
    ),
  ])
}

fn tab_button(
  tab: Tab,
  label: String,
  active_tab: Tab,
  count: Option(Int),
  has_new: Bool,
  on_click: fn(Tab) -> msg,
) -> Element(msg) {
  let is_active = tab == active_tab
  let base_class = "card-tab"
  let active_class = case is_active {
    True -> base_class <> " tab-active"
    False -> base_class
  }

  button(
    [
      attribute.class(active_class),
      attribute.role("tab"),
      attribute.attribute("aria-selected", case is_active {
        True -> "true"
        False -> "false"
      }),
      event.on_click(on_click(tab)),
    ],
    [
      text(label),
      case count {
        Some(n) ->
          span([attribute.class("tab-count")], [
            text(" (" <> int.to_string(n) <> ")"),
          ])
        None -> element.none()
      },
      case has_new {
        True ->
          span([attribute.class("new-notes-indicator")], [text("●")])
        False -> element.none()
      },
    ],
  )
}
