//// Closed tab contracts for Card Show and Task Show.

import gleam/option as opt

import scrumbringer_client/ui/detail_tabs

pub type CardShowTab {
  CardSummaryTab
  CardWorkTab
  CardNotesTab
  CardActivityTab
}

pub type TaskShowTab {
  TaskDetailsTab
  TaskDependenciesTab
  TaskNotesTab
  TaskActivityTab
}

pub type CardLabels {
  CardLabels(summary: String, work: String, notes: String, activity: String)
}

pub type TaskLabels {
  TaskLabels(
    details: String,
    dependencies: String,
    notes: String,
    activity: String,
  )
}

pub fn card_items(
  labels: CardLabels,
  work_count: Int,
  notes_count: Int,
  has_new_notes: Bool,
) -> List(detail_tabs.TabItem(CardShowTab)) {
  [
    detail_tabs.TabItem(
      id: CardWorkTab,
      label: labels.work,
      count: positive_count(work_count),
      has_indicator: False,
    ),
    detail_tabs.TabItem(
      id: CardSummaryTab,
      label: labels.summary,
      count: opt.None,
      has_indicator: False,
    ),
    detail_tabs.TabItem(
      id: CardNotesTab,
      label: labels.notes,
      count: positive_count(notes_count),
      has_indicator: has_new_notes,
    ),
    detail_tabs.TabItem(
      id: CardActivityTab,
      label: labels.activity,
      count: opt.None,
      has_indicator: False,
    ),
  ]
}

pub fn default_card_tab() -> CardShowTab {
  CardWorkTab
}

pub fn task_items(
  labels: TaskLabels,
  notes_count: Int,
  has_new_notes: Bool,
) -> List(detail_tabs.TabItem(TaskShowTab)) {
  [
    detail_tabs.TabItem(
      id: TaskDetailsTab,
      label: labels.details,
      count: opt.None,
      has_indicator: False,
    ),
    detail_tabs.TabItem(
      id: TaskDependenciesTab,
      label: labels.dependencies,
      count: opt.None,
      has_indicator: False,
    ),
    detail_tabs.TabItem(
      id: TaskNotesTab,
      label: labels.notes,
      count: positive_count(notes_count),
      has_indicator: has_new_notes,
    ),
    detail_tabs.TabItem(
      id: TaskActivityTab,
      label: labels.activity,
      count: opt.None,
      has_indicator: False,
    ),
  ]
}

fn positive_count(count: Int) -> opt.Option(Int) {
  case count > 0 {
    True -> opt.Some(count)
    False -> opt.None
  }
}
