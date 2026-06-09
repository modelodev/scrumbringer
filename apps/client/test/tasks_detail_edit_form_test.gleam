import gleam/option.{None, Some}

import domain/task.{type Task, Task}
import domain/task_state
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/features/tasks/detail_edit_form

fn labels() -> detail_edit_form.Labels {
  detail_edit_form.Labels(
    title_required: "Title required",
    title_too_long_max_56: "Title too long",
  )
}

fn input(title: String, description: String) -> detail_edit_form.Input {
  detail_edit_form.Input(title: title, description: description)
}

fn sample_task() -> Task {
  let state = task_state.Available
  Task(
    id: 42,
    project_id: 1,
    type_id: 1,
    task_type: TaskTypeInline(id: 1, name: "Bug", icon: "bug-ant"),
    ongoing_by: None,
    title: "Prepare release",
    description: Some("Review checklist."),
    priority: 2,
    state: state,
    status: task_state.to_status(state),
    work_state: task_state.to_work_state(state),
    created_by: 1,
    created_at: "2026-03-20T14:00:00Z",
    version: 3,
    milestone_id: None,
    card_id: None,
    card_title: None,
    card_color: None,
    has_new_notes: False,
    blocked_count: 0,
    dependencies: [],
  )
}

pub fn detail_edit_form_reports_blank_title_test() {
  let assert detail_edit_form.Invalid("Title required") =
    detail_edit_form.evaluate(sample_task(), input("   ", "Review"), labels())
}

pub fn detail_edit_form_reports_long_title_test() {
  let long_title = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

  let assert detail_edit_form.Invalid("Title too long") =
    detail_edit_form.evaluate(
      sample_task(),
      input(long_title, "Review"),
      labels(),
    )
}

pub fn detail_edit_form_returns_unchanged_canonical_values_test() {
  let assert detail_edit_form.Unchanged("Prepare release", "Review checklist.") =
    detail_edit_form.evaluate(
      sample_task(),
      input(" Prepare release ", "Review checklist."),
      labels(),
    )
}

pub fn detail_edit_form_returns_changed_normalized_values_test() {
  let assert detail_edit_form.Changed("Updated title", "") =
    detail_edit_form.evaluate(
      sample_task(),
      input(" Updated title ", "   "),
      labels(),
    )
}

pub fn detail_edit_form_description_text_uses_empty_for_absent_description_test() {
  let task = Task(..sample_task(), description: None)

  let assert "" = detail_edit_form.task_description_text(task)
}
