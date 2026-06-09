import gleam/option.{None, Some}
import gleam/string
import lustre/element

import domain/task.{Task, TaskDependency}
import domain/task_state
import domain/task_status.{Available, Claimed, Completed, Taken, WorkAvailable}
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/features/pool/blocked_claim_modal
import scrumbringer_client/i18n/locale

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

fn assert_not_contains(html: String, fragment: String) {
  let assert False = string.contains(html, fragment)
}

pub fn blocked_claim_modal_renders_incomplete_dependencies_test() {
  let html =
    blocked_claim_modal.view(blocked_claim_modal.Config(
      locale: locale.En,
      task_id: 42,
      task: Some(sample_task()),
      on_confirm: "confirm",
      on_cancel: "cancel",
    ))
    |> element.to_document_string

  assert_contains(html, "Blocked task")
  assert_contains(html, "Prepare release")
  assert_contains(html, "This task depends on 2 incomplete tasks.")
  assert_contains(html, "OAuth setup - Available")
  assert_contains(html, "API review - Claimed by alex@example.com")
  assert_not_contains(html, "Completed blocker")
  assert_contains(html, "Claim")
  assert_contains(html, "Cancel")
}

pub fn blocked_claim_modal_uses_task_number_when_task_is_missing_test() {
  let html =
    blocked_claim_modal.view(blocked_claim_modal.Config(
      locale: locale.En,
      task_id: 99,
      task: None,
      on_confirm: "confirm",
      on_cancel: "cancel",
    ))
    |> element.to_document_string

  assert_contains(html, "Task #99")
  assert_contains(html, "This task depends on 0 incomplete tasks.")
  assert_not_contains(html, "blocked-claim-list")
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
    status: Available,
    work_state: WorkAvailable,
    created_by: 7,
    created_at: "2026-06-01T10:00:00Z",
    version: 1,
    milestone_id: None,
    card_id: None,
    card_title: None,
    card_color: None,
    has_new_notes: False,
    blocked_count: 2,
    dependencies: [
      TaskDependency(
        depends_on_task_id: 1,
        title: "OAuth setup",
        status: Available,
        claimed_by: None,
      ),
      TaskDependency(
        depends_on_task_id: 2,
        title: "API review",
        status: Claimed(Taken),
        claimed_by: Some("alex@example.com"),
      ),
      TaskDependency(
        depends_on_task_id: 3,
        title: "Completed blocker",
        status: Completed,
        claimed_by: None,
      ),
    ],
  )
}
