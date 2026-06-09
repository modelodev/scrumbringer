import gleam/option.{None, Some}

import scrumbringer_client/features/tasks/note_form

fn labels() -> note_form.Labels {
  note_form.Labels(content_required: "Content required")
}

pub fn note_form_noops_without_selected_task_test() {
  let assert note_form.NoTaskSelected =
    note_form.evaluate(
      note_form.Input(task_id: None, content: "Useful note"),
      labels(),
    )
}

pub fn note_form_reports_blank_content_test() {
  let assert note_form.Invalid("Content required") =
    note_form.evaluate(
      note_form.Input(task_id: Some(42), content: "   "),
      labels(),
    )
}

pub fn note_form_returns_trimmed_content_test() {
  let assert note_form.Ready(42, "Useful note") =
    note_form.evaluate(
      note_form.Input(task_id: Some(42), content: "  Useful note  "),
      labels(),
    )
}
