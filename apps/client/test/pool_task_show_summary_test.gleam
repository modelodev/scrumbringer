import gleam/option.{None, Some}
import gleam/string
import lustre/element

import domain/remote.{Loaded}
import domain/task.{
  type Task, type TaskDependency, AutomationOrigin, Task, TaskDependency,
}
import domain/task/state as task_state
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/features/pool/task_show_summary
import scrumbringer_client/i18n/locale

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

fn assert_not_contains(html: String, fragment: String) {
  let assert False = string.contains(html, fragment)
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
        dependency(11, task_state.Available),
        dependency(12, closed_done_state()),
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
          workflow_id: Some(3),
          workflow_name: Some("Release flow"),
          rule_name: Some("Development completed"),
          execution_id: Some(101),
          template_id: Some(12),
          template_name: Some("QA Verification"),
          template_version: Some(3),
        )),
      ),
      dependencies: Loaded([]),
      parent_card_title: None,
    ))
    |> element.to_document_string

  assert_contains(html, "Origin")
  assert_contains(html, "Created by automation")
  assert_contains(
    html,
    "Release flow -&gt; Development completed -&gt; QA Verification v3",
  )
  assert_contains(html, "data-testid=\"automation-created-task-origin\"")
  assert_contains(
    html,
    "href=\"/config/workflows?project=1&amp;mode=executions&amp;execution=101\"",
  )
  assert_contains(html, "data-testid=\"automation-origin-engine-link\"")
  assert_contains(html, "data-testid=\"automation-origin-rule-link\"")
  assert_contains(html, "data-testid=\"automation-origin-template-link\"")
  assert_contains(html, ">View engine<")
  assert_contains(html, ">View rule<")
  assert_contains(html, ">View template<")
  assert_contains(html, "href=\"/config/workflows?project=1&amp;engine=3\"")
  assert_contains(
    html,
    "href=\"/config/workflows?project=1&amp;engine=3&amp;rule=8\"",
  )
  assert_contains(
    html,
    "href=\"/config/workflows?project=1&amp;mode=templates&amp;template=12\"",
  )
}

pub fn task_show_summary_localizes_automation_origin_test() {
  let html =
    task_show_summary.view(task_show_summary.Config(
      locale: locale.Es,
      task: Task(
        ..task(),
        automation_origin: Some(AutomationOrigin(
          rule_id: 8,
          workflow_id: Some(3),
          workflow_name: Some("Release flow"),
          rule_name: Some("Development completed"),
          execution_id: Some(101),
          template_id: Some(12),
          template_name: Some("QA Verification"),
          template_version: Some(3),
        )),
      ),
      dependencies: Loaded([]),
      parent_card_title: None,
    ))
    |> element.to_document_string

  assert_contains(html, "Origen")
  assert_contains(html, "Creada por automatización")
  assert_contains(html, ">Ver motor<")
  assert_contains(html, ">Ver regla<")
  assert_contains(html, ">Ver plantilla<")
}

pub fn task_show_summary_localizes_partial_automation_origin_fallbacks_test() {
  let html =
    task_show_summary.view(task_show_summary.Config(
      locale: locale.En,
      task: Task(
        ..task(),
        automation_origin: Some(AutomationOrigin(
          rule_id: 8,
          workflow_id: Some(3),
          workflow_name: None,
          rule_name: None,
          execution_id: None,
          template_id: Some(12),
          template_name: None,
          template_version: Some(3),
        )),
      ),
      dependencies: Loaded([]),
      parent_card_title: None,
    ))
    |> element.to_document_string

  assert_contains(html, "Engine #3 -&gt; Rule #8 -&gt; Template #12 v3")
  assert_not_contains(html, "Motor #3")
  assert_not_contains(html, "Plantilla #12")
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

fn dependency(id: Int, state: task_state.TaskExecutionState) -> TaskDependency {
  TaskDependency(
    depends_on_task_id: id,
    title: "Dependency",
    state: state,
    claimed_by: None,
  )
}

fn closed_done_state() -> task_state.TaskExecutionState {
  task_state.Closed(task_state.Done, "2026-06-01T10:00:00Z", 7)
}
