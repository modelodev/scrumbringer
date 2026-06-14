//// Task detail modal tabs and tabpanel presenter.

import gleam/list

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div}

import domain/remote.{type Remote, Failed, Loaded, Loading, NotAsked}
import domain/task.{type TaskNote}

import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/task_tabs

pub type Config(msg) {
  Config(
    locale: Locale,
    active_tab: task_tabs.Tab,
    notes: Remote(List(TaskNote)),
    on_tab_clicked: fn(task_tabs.Tab) -> msg,
  )
}

pub fn view(config: Config(msg)) -> Element(msg) {
  task_tabs.view(task_tabs.Config(
    active_tab: config.active_tab,
    notes_count: notes_count(config.notes),
    has_new_notes: False,
    labels: task_tabs.Labels(
      tasks: t(config.locale, i18n_text.TabDetails),
      notes: t(config.locale, i18n_text.TabNotes),
      metrics: t(config.locale, i18n_text.TabMetrics),
    ),
    on_tab_click: config.on_tab_clicked,
  ))
}

pub fn panel(active_tab: task_tabs.Tab, content: Element(msg)) -> Element(msg) {
  div(
    [
      attribute.class("detail-tabpanel"),
      attribute.attribute("role", "tabpanel"),
      attribute.id(tabpanel_id(active_tab)),
      attribute.attribute("aria-labelledby", tab_id(active_tab)),
    ],
    [content],
  )
}

fn notes_count(notes: Remote(List(TaskNote))) -> Int {
  case notes {
    Loaded(notes) -> list.length(notes)
    NotAsked -> 0
    Loading -> 0
    Failed(_) -> 0
  }
}

fn t(locale: Locale, key: i18n_text.Text) -> String {
  i18n.t(locale, key)
}

fn tabpanel_id(tab: task_tabs.Tab) -> String {
  case tab {
    task_tabs.TasksTab -> "modal-tabpanel-0"
    task_tabs.NotesTab -> "modal-tabpanel-1"
    task_tabs.MetricsTab -> "modal-tabpanel-2"
  }
}

fn tab_id(tab: task_tabs.Tab) -> String {
  case tab {
    task_tabs.TasksTab -> "modal-tab-0"
    task_tabs.NotesTab -> "modal-tab-1"
    task_tabs.MetricsTab -> "modal-tab-2"
  }
}
