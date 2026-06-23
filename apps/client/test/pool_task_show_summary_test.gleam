import gleam/option.{None, Some}
import gleam/string
import lustre/element

import domain/remote.{Loaded}
import domain/task.{
  type Task, type TaskDependency, AutomationOrigin, Task, TaskDependency,
}
import domain/task_state
import domain/task_status.{type TaskPhase, Available, Done}
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/features/pool/task_show_summary
import scrumbringer_client/i18n/locale

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

pub fn task_show_summary_renders_operational_context_test() {
  let html =
    task_show_summary.view(task_show_summary.Config(
      locale: locale.En,
      task: task(),
      dependencies: Loaded([]),
      parent_card_title: Some("Release card"),
    ))
    |> element.to_document_string

  assert_contains(html, "Operational summary")
  assert_contains(html, "Available")
  assert_contains(html, "P2")
  assert_contains(html, "Feature")
  assert_contains(html, "Release card")
  assert_contains(html, "Unassigned")
  assert_contains(html, "No active blockers")
}

pub fn task_show_summary_uses_loaded_dependency_blockers_test() {
  let html =
    task_show_summary.view(task_show_summary.Config(
      locale: locale.En,
      task: Task(..task(), blocked_count: 0),
      dependencies: Loaded([
        dependency(11, Available),
        dependency(12, Done),
      ]),
      parent_card_title: None,
    ))
    |> element.to_document_string

  assert_contains(html, "Blocked by 1 tasks")
}

pub fn task_show_summary_links_automation_origin_to_executions_test() {
  let html =
    task_show_summary.view(task_show_summary.Config(
      locale: locale.En,
      task: Task(
        ..task(),
        automation_origin: Some(AutomationOrigin(
          rule_id: 8,
          execution_id: Some(101),
          template_id: Some(12),
          template_version: Some(3),
        )),
      ),
      dependencies: Loaded([]),
      parent_card_title: None,
    ))
    |> element.to_document_string

  assert_contains(html, "Automation")
  assert_contains(html, "Execution #101")
  assert_contains(html, "data-testid=\"automation-created-task-origin\"")
  assert_contains(
    html,
    "href=\"/config/workflows?project=1&amp;mode=executions\"",
  )
}

fn task() -> Task {
  Task(
    id: 42,
    project_id: 1,
    type_id: 1,
    task_type: TaskTypeInline(id: 1, name: "Feature", icon: "sparkles"),
    ongoing_by: None,
    title: "Prepare release",
    description: Some("Task description"),
    priority: 2,
    state: task_state.Available,
    created_by: 7,
    created_at: "2026-06-01T10:00:00Z",
    due_date: None,
    version: 3,
    parent_card_id: None,
    card_id: None,
    card_title: None,
    card_color: None,
    has_new_notes: False,
    blocked_count: 0,
    dependencies: [],
    automation_origin: None,
  )
}

fn dependency(id: Int, status: TaskPhase) -> TaskDependency {
  TaskDependency(
    depends_on_task_id: id,
    title: "Dependency",
    status: status,
    claimed_by: None,
  )
}
