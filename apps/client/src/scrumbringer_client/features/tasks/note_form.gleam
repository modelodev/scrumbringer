//// Pure task note form validation.

import gleam/option as opt
import gleam/string

pub type Input {
  Input(task_id: opt.Option(Int), content: String)
}

pub type Labels {
  Labels(content_required: String)
}

pub type Decision {
  NoTaskSelected
  Invalid(message: String)
  Ready(task_id: Int, content: String)
}

pub fn evaluate(input: Input, labels: Labels) -> Decision {
  case input.task_id {
    opt.None -> NoTaskSelected
    opt.Some(task_id) -> {
      let content = string.trim(input.content)

      case content == "" {
        True -> Invalid(labels.content_required)
        False -> Ready(task_id: task_id, content: content)
      }
    }
  }
}
