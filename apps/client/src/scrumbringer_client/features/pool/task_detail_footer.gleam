//// Task detail modal footer.

import gleam/list
import gleam/option as opt

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div}

import domain/task.{type Task, claimed_by}
import domain/task_state
import domain/task_status

import scrumbringer_client/features/tasks/claimability
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
    editing: Bool,
    edit_in_flight: Bool,
    edit_dirty: Bool,
    on_close: msg,
    on_edit_cancelled: msg,
    on_edit_submitted: msg,
    on_claim: fn(Int, Int) -> msg,
    on_release: fn(Int, Int) -> msg,
    on_complete: fn(Int, Int) -> msg,
    on_delete: fn(Int) -> msg,
  )
}

fn t(config: Config(msg), key: i18n_text.Text) -> String {
  i18n.t(config.locale, key)
}

pub fn view(config: Config(msg)) -> Element(msg) {
  let actions = case config.editing {
    True -> edit_actions(config)
    False -> reading_actions(config)
  }

  div([attribute.class("modal-footer task-detail-footer")], actions)
}

fn reading_actions(config: Config(msg)) -> List(Element(msg)) {
  let close_button =
    text_button(
      t(config, i18n_text.Close),
      config.on_close,
      button.Secondary,
      False,
    )
    |> button.view

  let actions = case config.task {
    opt.None -> []
    opt.Some(task) -> task_actions(config, task)
  }

  list.append([close_button], actions)
}

fn edit_actions(config: Config(msg)) -> List(Element(msg)) {
  let cancel =
    text_button(
      t(config, i18n_text.Cancel),
      config.on_edit_cancelled,
      button.Secondary,
      config.edit_in_flight,
    )
    |> button.view

  let save =
    text_button(
      t(config, i18n_text.Save),
      config.on_edit_submitted,
      button.Primary,
      config.edit_in_flight || !config.edit_dirty,
    )
    |> button.with_class(case config.edit_in_flight {
      True -> "btn-loading task-detail-save"
      False -> "task-detail-save"
    })
    |> button.view

  [cancel, save]
}

fn task_actions(config: Config(msg), task: Task) -> List(Element(msg)) {
  let is_mine = claimed_by(task) == config.current_user_id
  case task_state.to_work_state(task.state) {
    task_status.WorkAvailable ->
      [
        delete_button(config, task, case task.blocked_count > 0 {
          True -> opt.Some(i18n_text.TaskBlockedByDependencies)
          False -> opt.None
        }),
      ]
      |> list.append(claim_actions(config, task))

    task_status.WorkClaimed | task_status.WorkOngoing ->
      case is_mine {
        True -> [
          delete_button(
            config,
            task,
            opt.Some(i18n_text.TaskHasOperationalHistory),
          ),
          text_button(
            t(config, i18n_text.Release),
            config.on_release(task.id, task.version),
            button.Secondary,
            config.disable_actions,
          )
            |> button.view,
          text_button(
            t(config, i18n_text.Complete),
            config.on_complete(task.id, task.version),
            button.Primary,
            config.disable_actions,
          )
            |> button.view,
        ]
        False -> [
          delete_button(
            config,
            task,
            opt.Some(i18n_text.TaskHasOperationalHistory),
          ),
        ]
      }

    task_status.WorkDone -> [
      delete_button(config, task, opt.Some(i18n_text.TaskHasOperationalHistory)),
    ]
  }
}

fn delete_button(
  config: Config(msg),
  task: Task,
  blocked_reason: opt.Option(i18n_text.Text),
) -> Element(msg) {
  let base_button =
    button.text(
      t(config, i18n_text.Delete),
      config.on_delete(task.id),
      button.Danger,
      button.EntityAction,
    )

  case config.disable_actions, blocked_reason {
    True, _ -> button.with_disabled(base_button, True)
    False, opt.Some(reason) ->
      button.with_blocked_reason(base_button, t(config, reason))
    False, opt.None -> base_button
  }
  |> button.view
}

fn claim_actions(config: Config(msg), task: Task) -> List(Element(msg)) {
  case claimability.can_claim(task) {
    True -> [claim_button(config, task)]
    False -> []
  }
}

fn claim_button(config: Config(msg), task: Task) -> Element(msg) {
  let base_button =
    button.text(
      t(config, i18n_text.ClaimTask),
      config.on_claim(task.id, task.version),
      button.Primary,
      button.EntityAction,
    )

  case config.disable_actions {
    True -> button.with_disabled(base_button, True)
    False -> base_button
  }
  |> button.view
}

fn text_button(
  label: String,
  on_click: msg,
  intent: button.Intent,
  disabled: Bool,
) -> button.Config(msg) {
  button.text(label, on_click, intent, button.EntityAction)
  |> button.with_disabled(disabled)
}
