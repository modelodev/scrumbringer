import gleam/option.{None, Some}
import support/domain_fixtures

import domain/task.{type Task, Task}
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/features/tasks/show_edit_form

fn labels() -> show_edit_form.Labels {
  show_edit_form.Labels(
    title_required: "Title required",
    title_too_long_max_56: "Title too long",
    type_required: "Type required",
    priority_must_be_1_to_5: "Priority must be 1-5",
    card_required: "Card required",
  )
}

fn input(title: String, description: String) -> show_edit_form.Input {
  show_edit_form.Input(
    title: title,
    description: description,
    priority: "2",
    type_id: "1",
    card_id: "10",
  )
}

fn sample_task() -> Task {
  Task(
    ..domain_fixtures.task(42, "Prepare release", 1),
    description: Some("Review checklist."),
    priority: 2,
    created_at: "2026-03-20T14:00:00Z",
    version: 3,
    card_id: Some(10),
  )
}

pub fn show_edit_form_reports_blank_title_test() {
  let assert show_edit_form.Invalid("Title required") =
    show_edit_form.evaluate(sample_task(), input("   ", "Review"), labels())
}

pub fn show_edit_form_reports_long_title_test() {
  let long_title = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

  let assert show_edit_form.Invalid("Title too long") =
    show_edit_form.evaluate(
      sample_task(),
      input(long_title, "Review"),
      labels(),
    )
}

pub fn show_edit_form_returns_unchanged_canonical_values_test() {
  let assert show_edit_form.Unchanged(submission) =
    show_edit_form.evaluate(
      sample_task(),
      input(" Prepare release ", "Review checklist."),
      labels(),
    )

  let assert "Prepare release" = submission.title
  let assert "Review checklist." = submission.description
  let assert 2 = submission.priority
  let assert 1 = submission.type_id
  let assert Some(10) = submission.card_id
}

pub fn show_edit_form_returns_changed_normalized_values_test() {
  let assert show_edit_form.Changed(submission) =
    show_edit_form.evaluate(
      sample_task(),
      input(" Updated title ", "   "),
      labels(),
    )

  let assert "Updated title" = submission.title
  let assert "" = submission.description
}

pub fn show_edit_form_reports_missing_type_test() {
  let invalid_input = show_edit_form.Input(..input("Title", ""), type_id: "")
  let invalid_task =
    Task(
      ..sample_task(),
      type_id: 0,
      task_type: TaskTypeInline(id: 0, name: "", icon: ""),
    )

  let assert show_edit_form.Invalid("Type required") =
    show_edit_form.evaluate(invalid_task, invalid_input, labels())
}

pub fn show_edit_form_keeps_current_type_when_input_is_empty_test() {
  let unchanged_input =
    show_edit_form.Input(
      ..input("Prepare release", "Review checklist."),
      type_id: "",
    )

  let assert show_edit_form.Unchanged(submission) =
    show_edit_form.evaluate(sample_task(), unchanged_input, labels())

  let assert 1 = submission.type_id
}

pub fn show_edit_form_reports_invalid_priority_test() {
  let invalid_input = show_edit_form.Input(..input("Title", ""), priority: "6")

  let assert show_edit_form.Invalid("Priority must be 1-5") =
    show_edit_form.evaluate(sample_task(), invalid_input, labels())
}

pub fn show_edit_form_keeps_selected_card_test() {
  let changed_input = show_edit_form.Input(..input("Title", ""), card_id: "9")

  let assert show_edit_form.Changed(submission) =
    show_edit_form.evaluate(sample_task(), changed_input, labels())

  let assert Some(9) = submission.card_id
}

pub fn show_edit_form_description_text_uses_empty_for_absent_description_test() {
  let task = Task(..sample_task(), description: None)

  let assert "" = show_edit_form.task_description_text(task)
}
