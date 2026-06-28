import gleam/option.{None, Some}
import lustre/element
import support/domain_fixtures
import support/render_assertions

import domain/card
import domain/remote.{Loaded}
import domain/task.{type Task, Task}
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/capability_scope.{AllCapabilities}
import scrumbringer_client/features/pool/available_tasks
import scrumbringer_client/features/pool/control_bar
import scrumbringer_client/features/pool/task_card
import scrumbringer_client/features/pool/task_row
import scrumbringer_client/features/pool/view as pool_view
import scrumbringer_client/features/pool/visibility.{
  type PoolVisibility, AllOpen, Blocked, ReadyToClaim,
}
import scrumbringer_client/i18n/locale
import scrumbringer_client/pool_prefs
import scrumbringer_client/theme

pub fn pool_renders_header_control_bar_and_body_test() {
  let html =
    pool_view.view_pool_main(main_config(pool_prefs.Canvas))
    |> element.to_document_string

  render_assertions.contains(html, "class=\"work-surface pool-view\"")
  render_assertions.contains(html, "work-surface-chrome")
  render_assertions.contains(html, "work-surface-header")
  render_assertions.contains(html, "work-surface-filters")
  render_assertions.contains(html, "work-surface-content")
  render_assertions.contains(html, "data-testid=\"pool-control-bar\"")
  render_assertions.contains(html, "id=\"member-canvas\"")
  render_assertions.contains(html, "Task 1")
  render_assertions.contains(html, ">7<")
  render_assertions.not_contains(html, "My tasks")
}

pub fn pool_list_mode_renders_task_rows_test() {
  let html =
    pool_view.view_pool_main(main_config(pool_prefs.List))
    |> element.to_document_string

  render_assertions.contains(html, "class=\"task-list\"")
  render_assertions.contains(html, "task-row")
  render_assertions.contains(html, "Task 1")
}

pub fn pool_ready_to_claim_empty_mentions_blocked_tasks_test() {
  let blocked = Task(..sample_task(), blocked_count: 2)
  let html =
    pool_view.view_pool_main(main_config_with(
      pool_prefs.Canvas,
      Loaded([blocked]),
      ReadyToClaim,
    ))
    |> element.to_document_string

  render_assertions.contains(html, "No claimable tasks right now")
  render_assertions.contains(html, "There are 1 blocked tasks")
  render_assertions.contains(html, "View blocked")
  render_assertions.not_contains(html, "Create your first task")
}

pub fn pool_blocked_empty_does_not_suggest_new_task_test() {
  let html =
    pool_view.view_pool_main(main_config_with(
      pool_prefs.Canvas,
      Loaded([sample_task()]),
      Blocked,
    ))
    |> element.to_document_string

  render_assertions.contains(html, "No blocked tasks")
  render_assertions.contains(html, "View open")
  render_assertions.not_contains(html, "Create your first task")
}

fn main_config(view_mode: pool_prefs.ViewMode) -> pool_view.MainConfig(String) {
  main_config_with(view_mode, Loaded([sample_task()]), AllOpen)
}

fn main_config_with(
  view_mode: pool_prefs.ViewMode,
  tasks,
  visibility: PoolVisibility,
) -> pool_view.MainConfig(String) {
  pool_view.MainConfig(
    locale: locale.En,
    has_active_projects: True,
    on_create_opened: "create",
    available_tasks: available_tasks.Config(
      tasks: tasks,
      task_types: Loaded([]),
      my_capability_ids: Loaded([]),
      type_filter: None,
      capability_filter: None,
      search_query: "",
      capability_scope: AllCapabilities,
      visibility: visibility,
    ),
    control_bar: control_bar.Config(
      locale: locale.En,
      task_types: [],
      capabilities: [],
      capability_scope: AllCapabilities,
      type_filter: None,
      capability_filter: None,
      search_query: "",
      visibility: visibility,
      view_mode: view_mode,
      on_capability_scope_change: fn(_) { "scope" },
      on_type_filter_change: fn(_) { "type" },
      on_capability_filter_change: fn(_) { "capability" },
      on_search_change: fn(_) { "search" },
      on_visibility_change: fn(_) { "visibility" },
      on_view_mode_change: fn(_) { "view-mode" },
    ),
    healthy_pool_limit: 7,
    view_mode: view_mode,
    task_card_config: fn(task) { task_card_config(task) },
    task_row_config: fn(task) { task_row_config(task) },
  )
}

fn task_card_config(task: Task) -> task_card.Config(String) {
  task_card.Config(
    locale: locale.En,
    theme: theme.Default,
    task: task,
    current_user_id: Some(7),
    card_title: Some("Release card"),
    card_color: Some(card.Blue),
    x: 100,
    y: 40,
    age_days: 1,
    project_today: "2026-06-19",
    highlight_class: "",
    touch_preview: False,
    disable_actions: False,
    hidden_blocked_count: None,
    notes: [],
    on_claim: "claim",
    on_release: "release",
    on_close: "close",
    on_open: "open",
    on_hover_opened: "hover-opened",
    on_hover_closed: "hover-closed",
    on_focused: "focused",
    on_blurred: "blurred",
    on_drag_started: fn(_, _) { "drag" },
    on_touch_started: fn(_, _) { "touch-start" },
    on_touch_ended: "touch-end",
  )
}

fn task_row_config(task: Task) -> task_row.Config(String) {
  task_row.Config(
    locale: locale.En,
    theme: theme.Default,
    task: task,
    card_color: Some(card.Blue),
    highlight_class: "",
    disable_actions: False,
    on_claim: "claim",
    on_open: "open",
  )
}

fn sample_task() {
  Task(
    ..domain_fixtures.task(1, "Task 1", 1),
    task_type: TaskTypeInline(id: 1, name: "Feature", icon: "sparkles"),
    description: Some("Task description"),
    priority: 2,
    created_by: 7,
    created_at: "2026-06-01T10:00:00Z",
    card_id: Some(10),
    card_title: Some("Release card"),
    card_color: Some(card.Blue),
  )
}
