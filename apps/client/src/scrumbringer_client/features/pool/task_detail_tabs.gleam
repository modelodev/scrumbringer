//// Task detail modal tabs and tabpanel presenter.

import gleam/list

import lustre/element.{type Element}

import domain/remote.{type Remote, Failed, Loaded, Loading, NotAsked}
import domain/task.{type TaskNote}

import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/detail_tabs
import scrumbringer_client/ui/show_tabs

pub type Config(msg) {
  Config(
    locale: Locale,
    active_tab: show_tabs.TaskShowTab,
    notes: Remote(List(TaskNote)),
    on_tab_clicked: fn(show_tabs.TaskShowTab) -> msg,
  )
}

pub fn view(config: Config(msg)) -> Element(msg) {
  let tabs = task_items(config)

  detail_tabs.view(detail_tabs.Config(
    active_tab: config.active_tab,
    tabs: tabs,
    container_class: "task-tabs modal-tabs detail-tabs",
    tab_class: "task-tab modal-tab detail-tab",
    on_tab_click: config.on_tab_clicked,
  ))
}

pub fn panel(
  active_tab: show_tabs.TaskShowTab,
  tabs: List(detail_tabs.TabItem(show_tabs.TaskShowTab)),
  content: Element(msg),
) -> Element(msg) {
  detail_tabs.panel(active_tab, tabs, content)
}

pub fn task_items(
  config: Config(msg),
) -> List(detail_tabs.TabItem(show_tabs.TaskShowTab)) {
  show_tabs.task_items(
    show_tabs.TaskLabels(
      details: t(config.locale, i18n_text.TabDetails),
      dependencies: t(config.locale, i18n_text.TabDependencies),
      notes: t(config.locale, i18n_text.TabNotes),
      activity: t(config.locale, i18n_text.TabActivity),
    ),
    notes_count(config.notes),
    False,
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
