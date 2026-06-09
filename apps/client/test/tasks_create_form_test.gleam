import gleam/option.{None, Some}

import scrumbringer_client/features/tasks/create_form

fn labels() -> create_form.Labels {
  create_form.Labels(
    select_project_first: "Select a project first",
    title_required: "Title required",
    title_too_long_max_56: "Title too long",
    type_required: "Type required",
    priority_must_be_1_to_5: "Priority must be 1 to 5",
  )
}

fn input() -> create_form.Input {
  create_form.Input(
    selected_project_id: Some(1),
    title: " Ship task ",
    description: " Useful detail ",
    type_id: "8",
    priority: "5",
    card_id: Some(7),
    milestone_id: Some(9),
  )
}

pub fn create_form_card_id_from_input_accepts_positive_ids_test() {
  let assert Some(42) = create_form.card_id_from_input("42")
}

pub fn create_form_card_id_from_input_rejects_empty_zero_and_invalid_test() {
  let assert None = create_form.card_id_from_input("")
  let assert None = create_form.card_id_from_input("0")
  let assert None = create_form.card_id_from_input("abc")
}

pub fn create_form_validate_returns_normalized_submission_test() {
  let assert Ok(submission) = create_form.validate(input(), labels())

  let assert 1 = submission.project_id
  let assert "Ship task" = submission.title
  let assert Some("Useful detail") = submission.description
  let assert 5 = submission.priority
  let assert 8 = submission.type_id
  let assert Some(7) = submission.card_id
  let assert Some(9) = submission.milestone_id
}

pub fn create_form_validate_treats_blank_description_as_none_test() {
  let assert Ok(submission) =
    create_form.validate(
      create_form.Input(..input(), description: "   "),
      labels(),
    )

  let assert None = submission.description
}

pub fn create_form_validate_reports_first_error_test() {
  let assert Error("Select a project first") =
    create_form.validate(
      create_form.Input(..input(), selected_project_id: None, title: ""),
      labels(),
    )

  let assert Error("Title required") =
    create_form.validate(create_form.Input(..input(), title: " "), labels())

  let assert Error("Type required") =
    create_form.validate(create_form.Input(..input(), type_id: "x"), labels())

  let assert Error("Priority must be 1 to 5") =
    create_form.validate(create_form.Input(..input(), priority: "8"), labels())
}
