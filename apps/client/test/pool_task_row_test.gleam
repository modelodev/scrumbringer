import gleam/option.{None, Some}
import gleam/string
import lustre/element

import domain/card
import domain/task.{AutomationOrigin, Task}
import domain/task_state
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/features/pool/task_row
import scrumbringer_client/i18n/locale
import scrumbringer_client/theme

fn assert_contains(text: String, fragment: String) {
  let assert True = string.contains(text, fragment)
}

fn assert_not_contains(text: String, fragment: String) {
  let assert False = string.contains(text, fragment)
}

pub fn task_row_renders_claimable_list_item_without_root_model_test() {
  let html =
    task_row.view(task_row.Config(
      locale: locale.En,
      theme: theme.Default,
      task: sample_task(),
      card_color: Some(card.Blue),
      highlight_class: " is-highlight-source highlight-info",
      disable_actions: False,
      on_claim: "claim",
      on_open: "open",
    ))
    |> element.to_document_string

  assert_contains(html, "task-row card-border-blue")
  assert_contains(html, "is-highlight-source highlight-info")
  assert_contains(html, "Prepare release")
  assert_contains(html, "title=\"Claim this task and move it to My Tasks\"")
}

pub fn task_row_hides_claim_action_when_blocked_test() {
  let html =
    task_row.view(task_row.Config(
      locale: locale.En,
      theme: theme.Default,
      task: Task(..sample_task(), blocked_count: 1),
      card_color: None,
      highlight_class: "",
      disable_actions: False,
      on_claim: "claim",
      on_open: "open",
    ))
    |> element.to_document_string

  assert_contains(html, "task-blocked")
  assert_contains(html, "task-blocked-count")
  assert_not_contains(html, "title=\"Claim this task and move it to My Tasks\"")
}

pub fn task_row_localizes_automation_origin_chip_test() {
  let html =
    task_row.view(task_row.Config(
      locale: locale.Es,
      theme: theme.Default,
      task: Task(
        ..sample_task(),
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
      card_color: None,
      highlight_class: "",
      disable_actions: False,
      on_claim: "claim",
      on_open: "open",
    ))
    |> element.to_document_string

  assert_contains(html, "data-testid=\"automation-created-task-origin\"")
  assert_contains(html, "Automatización #8")
  assert_contains(html, "title=\"Creada por regla de automatización #8\"")
  assert_not_contains(html, "Created by automation")
}

fn sample_task() {
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
    version: 1,
    parent_card_id: None,
    card_id: Some(10),
    card_title: Some("Release card"),
    card_color: Some(card.Blue),
    has_new_notes: False,
    blocked_count: 0,
    dependencies: [],
    automation_origin: None,
  )
}
