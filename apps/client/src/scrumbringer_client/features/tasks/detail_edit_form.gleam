//// Pure task detail edit form validation and change detection.

import gleam/string

import domain/task.{type Task}
import scrumbringer_client/features/tasks/detail_editor

pub type Input {
  Input(title: String, description: String)
}

pub type Labels {
  Labels(title_required: String, title_too_long_max_56: String)
}

pub type Decision {
  Invalid(message: String)
  Unchanged(title: String, description: String)
  Changed(title: String, description: String)
}

pub fn evaluate(current_task: Task, input: Input, labels: Labels) -> Decision {
  let title = string.trim(input.title)

  case validate_title(title, labels) {
    Error(message) -> Invalid(message)
    Ok(title) -> {
      let description = normalize_description(input.description)

      case is_dirty(current_task, title, description) {
        True -> Changed(title: title, description: description)
        False ->
          Unchanged(
            title: current_task.title,
            description: task_description_text(current_task),
          )
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

fn normalize_description(description: String) -> String {
  case string.trim(description) {
    "" -> ""
    _ -> description
  }
}

fn is_dirty(
  current_task: Task,
  next_title: String,
  next_description: String,
) -> Bool {
  next_title != current_task.title
  || next_description != task_description_text(current_task)
}
