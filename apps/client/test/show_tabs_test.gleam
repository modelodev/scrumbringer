import gleam/option as opt
import gleam/string
import lustre/element
import lustre/element/html

import scrumbringer_client/ui/detail_tabs
import scrumbringer_client/ui/show_tabs

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

pub fn card_items_start_with_work_and_count_visible_work_test() {
  let items =
    show_tabs.card_items(
      show_tabs.CardLabels(
        summary: "Summary",
        work: "Work",
        notes: "Notes",
        activity: "Activity",
      ),
      3,
      1,
      True,
    )

  let assert [
    detail_tabs.TabItem(
      id: show_tabs.CardWorkTab,
      label: "Work",
      count: opt.Some(3),
      has_indicator: False,
    ),
    detail_tabs.TabItem(
      id: show_tabs.CardSummaryTab,
      label: "Summary",
      count: opt.None,
      has_indicator: False,
    ),
    detail_tabs.TabItem(
      id: show_tabs.CardNotesTab,
      label: "Notes",
      count: opt.Some(1),
      has_indicator: True,
    ),
    detail_tabs.TabItem(
      id: show_tabs.CardActivityTab,
      label: "Activity",
      count: opt.None,
      has_indicator: False,
    ),
  ] = items
  let assert show_tabs.CardWorkTab = show_tabs.default_card_tab()
}

pub fn task_items_render_closed_task_show_contract_test() {
  let items =
    show_tabs.task_items(
      show_tabs.TaskLabels(
        details: "Details",
        dependencies: "Dependencies",
        notes: "Notes",
        activity: "Activity",
      ),
      2,
      False,
    )

  let assert [
    detail_tabs.TabItem(
      id: show_tabs.TaskDetailsTab,
      label: "Details",
      count: opt.None,
      has_indicator: False,
    ),
    detail_tabs.TabItem(
      id: show_tabs.TaskDependenciesTab,
      label: "Dependencies",
      count: opt.None,
      has_indicator: False,
    ),
    detail_tabs.TabItem(
      id: show_tabs.TaskNotesTab,
      label: "Notes",
      count: opt.Some(2),
      has_indicator: False,
    ),
    detail_tabs.TabItem(
      id: show_tabs.TaskActivityTab,
      label: "Activity",
      count: opt.None,
      has_indicator: False,
    ),
  ] = items
}

pub fn detail_tabs_panel_sets_accessible_tab_contract_test() {
  let tabs =
    show_tabs.task_items(
      show_tabs.TaskLabels(
        details: "Details",
        dependencies: "Dependencies",
        notes: "Notes",
        activity: "Activity",
      ),
      0,
      False,
    )

  let html =
    detail_tabs.panel(show_tabs.TaskActivityTab, tabs, html.div([], []))
    |> element.to_document_string

  assert_contains(html, "detail-tabpanel")
  assert_contains(html, "role=\"tabpanel\"")
  assert_contains(html, "modal-tabpanel-3")
  assert_contains(html, "aria-labelledby=\"modal-tab-3\"")
}
