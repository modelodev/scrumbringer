//// Task detail modal footer.

import gleam/list
import gleam/option as opt

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div}

import domain/task.{type Task, claimed_by}
import domain/task_state
import domain/task_status

import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/button

pub type Config(msg) {
  Config(
    locale: Locale,
    task: opt.Option(Task),
    current_user_id: opt.Option(Int),
    disable_actions: Bool,
    on_close: msg,
    on_claim: fn(Int, Int) -> msg,
    on_release: fn(Int, Int) -> msg,
    on_complete: fn(Int, Int) -> msg,
  )
}

fn t(config: Config(msg), key: i18n_text.Text) -> String {
  i18n.t(config.locale, key)
}

pub fn view(config: Config(msg)) -> Element(msg) {
  let close_button =
    text_button(
      t(config, i18n_text.Close),
      config.on_close,
      button.Secondary,
      False,
    )

  let actions = case config.task {
    opt.None -> []
    opt.Some(task) -> task_actions(config, task)
  }

  div(
    [attribute.class("modal-footer task-detail-footer")],
    list.append([close_button], actions),
  )
}

fn task_actions(config: Config(msg), task: Task) -> List(Element(msg)) {
  let is_mine = claimed_by(task) == config.current_user_id
  case task_state.to_work_state(task.state) {
    task_status.WorkAvailable -> [
      text_button(
        t(config, i18n_text.ClaimTask),
        config.on_claim(task.id, task.version),
        button.Primary,
        config.disable_actions || task.blocked_count > 0,
      ),
    ]

    task_status.WorkClaimed | task_status.WorkOngoing ->
      case is_mine {
        True -> [
          text_button(
            t(config, i18n_text.Release),
            config.on_release(task.id, task.version),
            button.Secondary,
            config.disable_actions,
          ),
          text_button(
            t(config, i18n_text.Complete),
            config.on_complete(task.id, task.version),
            button.Primary,
            config.disable_actions,
          ),
        ]
        False -> []
      }

    task_status.WorkCompleted -> []
  }
}

fn text_button(
  label: String,
  on_click: msg,
  intent: button.Intent,
  disabled: Bool,
) -> Element(msg) {
  button.text(label, on_click, intent, button.EntityAction)
  |> button.with_disabled(disabled)
  |> button.view
}
