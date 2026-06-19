//// Pure task creation form parsing and validation.

import gleam/int
import gleam/option as opt
import gleam/string

pub type Input {
  Input(
    selected_project_id: opt.Option(Int),
    title: String,
    description: String,
    type_id: String,
    priority: String,
    card_id: opt.Option(Int),
  )
}

pub type Labels {
  Labels(
    select_project_first: String,
    title_required: String,
    title_too_long_max_56: String,
    type_required: String,
    priority_must_be_1_to_5: String,
  )
}

pub type Submission {
  Submission(
    project_id: Int,
    title: String,
    description: opt.Option(String),
    priority: Int,
    type_id: Int,
    card_id: opt.Option(Int),
  )
}

pub fn card_id_from_input(value: String) -> opt.Option(Int) {
  case int.parse(value) {
    Ok(id) if id > 0 -> opt.Some(id)
    _ -> opt.None
  }
}

pub fn validate(input: Input, labels: Labels) -> Result(Submission, String) {
  case input.selected_project_id {
    opt.None -> Error(labels.select_project_first)
    opt.Some(project_id) -> validate_title(input, labels, project_id)
  }
}

fn validate_title(
  input: Input,
  labels: Labels,
  project_id: Int,
) -> Result(Submission, String) {
  let title = string.trim(input.title)

  case title == "" {
    True -> Error(labels.title_required)
    False -> validate_title_length(input, labels, project_id, title)
  }
}

fn validate_title_length(
  input: Input,
  labels: Labels,
  project_id: Int,
  title: String,
) -> Result(Submission, String) {
  case string.length(title) > 56 {
    True -> Error(labels.title_too_long_max_56)
    False -> validate_type_id(input, labels, project_id, title)
  }
}

fn validate_type_id(
  input: Input,
  labels: Labels,
  project_id: Int,
  title: String,
) -> Result(Submission, String) {
  case int.parse(input.type_id) {
    Error(_) -> Error(labels.type_required)
    Ok(type_id) -> validate_priority(input, labels, project_id, title, type_id)
  }
}

fn validate_priority(
  input: Input,
  labels: Labels,
  project_id: Int,
  title: String,
  type_id: Int,
) -> Result(Submission, String) {
  case int.parse(input.priority) {
    Ok(priority) if priority >= 1 && priority <= 5 ->
      Ok(Submission(
        project_id: project_id,
        title: title,
        description: description(input.description),
        priority: priority,
        type_id: type_id,
        card_id: input.card_id,
      ))

    _ -> Error(labels.priority_must_be_1_to_5)
  }
}

fn description(value: String) -> opt.Option(String) {
  case string.trim(value) {
    "" -> opt.None
    description -> opt.Some(description)
  }
}
