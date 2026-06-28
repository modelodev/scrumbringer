import gleam/option.{None, Some}
import gleam/string
import lustre/element
import support/domain_fixtures
import support/render_assertions

import domain/remote.{Loaded}
import domain/task.{
  type Task, type TaskDependency, AutomationOrigin, Task, TaskDependency,
}
import domain/task/state as task_state
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/features/tasks/show/summary as task_show_summary
import scrumbringer_client/i18n/locale

fn forbidden_fragment(parts: List(String)) -> String {
  string.join(parts, "")
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

  render_assertions.contains(html, "Operational summary")
  render_assertions.contains(html, "task-inspector-facts")
  render_assertions.contains(
    html,
    "data-testid=\"task-show-summary-status-indicator\"",
  )
  render_assertions.contains(html, "task-status-indicator")
  render_assertions.contains(html, "Available")
  render_assertions.contains(html, "P2")
  render_assertions.contains(html, "Feature")
  render_assertions.contains(html, "Release card")
  render_assertions.contains(html, "Claim to My Tasks")
  render_assertions.contains(html, "No active blockers")
  render_assertions.not_contains(
    html,
    forbidden_fragment(["task", "-show-summary-grid"]),
  )
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

  render_assertions.contains(html, "Blocked by 1 tasks")
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
          rule_name: Some("Development closed"),
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

  render_assertions.contains(html, "Origin")
  render_assertions.contains(html, "Created by automation")
  render_assertions.contains(html, "data-testid=\"automation-origin-status\"")
  render_assertions.contains(
    html,
    "Release flow -&gt; Development closed -&gt; QA Verification v3",
  )
  render_assertions.contains(html, "data-testid=\"automation-origin-trace\"")
  render_assertions.contains(
    html,
    "data-testid=\"automation-origin-primary-link\"",
  )
  render_assertions.contains(html, ">Go to automation<")
  render_assertions.contains(
    html,
    "href=\"/config/workflows?project=1&amp;mode=executions&amp;execution=101\"",
  )
  render_assertions.contains(
    html,
    "data-testid=\"automation-origin-engine-link\"",
  )
  render_assertions.contains(
    html,
    "data-testid=\"automation-origin-rule-link\"",
  )
  render_assertions.contains(
    html,
    "data-testid=\"automation-origin-template-link\"",
  )
  render_assertions.contains(html, ">View engine<")
  render_assertions.contains(html, ">View rule<")
  render_assertions.contains(html, ">View template<")
  render_assertions.contains(
    html,
    "href=\"/config/workflows?project=1&amp;engine=3\"",
  )
  render_assertions.contains(
    html,
    "href=\"/config/workflows?project=1&amp;engine=3&amp;rule=8\"",
  )
  render_assertions.contains(
    html,
    "href=\"/config/workflows?project=1&amp;mode=templates&amp;template=12\"",
  )
  render_assertions.not_contains(html, "Created by automation -&gt;")
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
          rule_name: Some("Development closed"),
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

  render_assertions.contains(html, "Origen")
  render_assertions.contains(html, "Creada por automatización")
  render_assertions.contains(html, ">Ir a automatización<")
  render_assertions.contains(html, ">Ver motor<")
  render_assertions.contains(html, ">Ver regla<")
  render_assertions.contains(html, ">Ver plantilla<")
  render_assertions.not_contains(html, "Creada por automatización -&gt;")
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

  render_assertions.contains(
    html,
    "Engine #3 -&gt; Rule #8 -&gt; Template #12 v3",
  )
  render_assertions.contains(html, ">Go to automation<")
  render_assertions.contains(
    html,
    "href=\"/config/workflows?project=1&amp;engine=3&amp;rule=8\"",
  )
  render_assertions.contains(
    html,
    "data-testid=\"automation-origin-primary-link\"",
  )
  render_assertions.not_contains(
    html,
    "data-testid=\"automation-origin-rule-link\"",
  )
  render_assertions.not_contains(html, "Motor #3")
  render_assertions.not_contains(html, "Plantilla #12")
}

fn task() -> Task {
  Task(
    ..domain_fixtures.task(42, "Prepare release", 1),
    task_type: TaskTypeInline(id: 1, name: "Feature", icon: "sparkles"),
    priority: 2,
    created_by: 7,
    created_at: "2026-06-01T10:00:00Z",
    version: 3,
  )
}

fn dependency(id: Int, state: task_state.TaskExecutionState) -> TaskDependency {
  TaskDependency(..domain_fixtures.dependency(id), state: state)
}

fn closed_done_state() -> task_state.TaskExecutionState {
  task_state.Closed(task_state.ClosedByClaimant, "2026-06-01T10:00:00Z", 7)
}
