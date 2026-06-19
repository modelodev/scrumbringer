//// Pure task detail edit form validation and change detection.

import gleam/int
import gleam/option as opt
import gleam/string

import domain/task.{type Task}
import scrumbringer_client/features/tasks/detail_editor

pub type Input {
  Input(
    title: String,
    description: String,
    priority: String,
    type_id: String,
    card_id: String,
  )
}

pub type Labels {
  Labels(
    title_required: String,
    title_too_long_max_56: String,
    type_required: String,
    priority_must_be_1_to_5: String,
  )
}

pub type Submission {
  Submission(
    title: String,
    description: String,
    priority: Int,
    type_id: Int,
    card_id: opt.Option(Int),
  )
}

pub type Decision {
  Invalid(message: String)
  Unchanged(submission: Submission)
  Changed(submission: Submission)
}

pub fn evaluate(current_task: Task, input: Input, labels: Labels) -> Decision {
  let title = string.trim(input.title)

  case validate_title(title, labels) {
    Error(message) -> Invalid(message)
    Ok(title) -> {
      case
        validate_type_id(
          effective_type_input(input.type_id, current_task),
          labels,
        )
      {
        Error(message) -> Invalid(message)
        Ok(type_id) ->
          case validate_priority(input.priority, labels) {
            Error(message) -> Invalid(message)
            Ok(priority) -> {
              let card_id = optional_id_from_input(input.card_id)
              let submission =
                Submission(
                  title: title,
                  description: normalize_description(input.description),
                  priority: priority,
                  type_id: type_id,
                  card_id: card_id,
                )

              case is_dirty(current_task, submission) {
                True -> Changed(submission)
                False -> Unchanged(submission)
              }
            }
          }
      }
    }
  }
}

pub fn task_description_text(current_task: Task) -> String {
  detail_editor.task_description_text(current_task)
}

fn validate_title(title: String, labels: Labels) -> Result(String, String) {
  case title == "" {
    True -> Error(labels.title_required)
    False ->
      case string.length(title) > 56 {
        True -> Error(labels.title_too_long_max_56)
        False -> Ok(title)
      }
  }
}

fn validate_type_id(type_id: String, labels: Labels) -> Result(Int, String) {
  case int.parse(type_id) {
    Ok(id) if id > 0 -> Ok(id)
    _ -> Error(labels.type_required)
  }
}

fn validate_priority(priority: String, labels: Labels) -> Result(Int, String) {
  case int.parse(priority) {
    Ok(value) if value >= 1 && value <= 5 -> Ok(value)
    _ -> Error(labels.priority_must_be_1_to_5)
  }
}

fn normalize_description(description: String) -> String {
  case string.trim(description) {
    "" -> ""
    _ -> description
  }
}

fn is_dirty(current_task: Task, submission: Submission) -> Bool {
  submission.title != current_task.title
  || submission.description != task_description_text(current_task)
  || submission.priority != current_task.priority
  || submission.type_id != task_type_id(current_task)
  || submission.card_id != current_task.card_id
}

pub fn task_type_id(task: Task) -> Int {
  case task.type_id > 0 {
    True -> task.type_id
    False -> task.task_type.id
  }
}

fn effective_type_input(type_id: String, current_task: Task) -> String {
  case string.trim(type_id) {
    "" -> int.to_string(task_type_id(current_task))
    value -> value
  }
}

fn optional_id_from_input(value: String) -> opt.Option(Int) {
  case int.parse(value) {
    Ok(id) if id > 0 -> opt.Some(id)
    _ -> opt.None
  }
}
