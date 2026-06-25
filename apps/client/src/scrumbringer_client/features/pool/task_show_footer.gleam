//// Task Show footer action bar.

import gleam/int
import gleam/list
import gleam/option as opt

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div}

import domain/task.{type Task, claimed_by}
import domain/task/state as task_state

import scrumbringer_client/features/tasks/claimability
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/action_menu
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
    on_start_work: fn(Int) -> msg,
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

  div([attribute.class("task-show-footer task-action-bar")], actions)
}

fn reading_actions(config: Config(msg)) -> List(Element(msg)) {
  case config.task {
    opt.None -> []
    opt.Some(task) -> task_actions(config, task)
  }
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
      True -> "btn-loading task-show-save"
      False -> "task-show-save"
    })
    |> button.view

  [cancel, save]
}

fn task_actions(config: Config(msg), task: Task) -> List(Element(msg)) {
  let is_mine = claimed_by(task) == config.current_user_id

  case task.state {
    task_state.Available -> [
      claim_button(config, task),
      secondary_actions_menu(config, task, allow_release: False),
    ]

    task_state.Claimed(mode: task_state.Taken, ..) ->
      case is_mine {
        True -> [
          start_work_button(config, task),
          secondary_actions_menu(config, task, allow_release: True),
        ]
        False -> [secondary_actions_menu(config, task, allow_release: False)]
      }

    task_state.Claimed(mode: task_state.Ongoing, ..) ->
      case is_mine {
        True -> [
          text_button(
            t(config, i18n_text.TaskNextActionClose),
            config.on_complete(task.id, task.version),
            button.Primary,
            config.disable_actions,
          )
            |> button.with_testid("task-show-primary-complete")
            |> button.view,
          secondary_actions_menu(config, task, allow_release: True),
        ]
        False -> [secondary_actions_menu(config, task, allow_release: False)]
      }

    task_state.Closed(..) -> [
      secondary_actions_menu(config, task, allow_release: False),
    ]
  }
}

fn secondary_actions_menu(
  config: Config(msg),
  task: Task,
  allow_release allow_release: Bool,
) -> Element(msg) {
  action_menu.view(
    "⋯",
    "task-show-secondary-actions-trigger",
    "task-show-secondary-actions-" <> int_to_string(task.id),
    opt.Some(t(config, i18n_text.HierarchyMoreActions)),
    "secondary-actions-menu",
    "secondary-actions-trigger task-show-secondary-actions-trigger",
    "secondary-actions-panel task-show-secondary-actions-panel",
    "secondary-actions-item task-show-secondary-actions-item",
    secondary_action_items(config, task, allow_release),
  )
}

fn secondary_action_items(
  config: Config(msg),
  task: Task,
  allow_release: Bool,
) -> List(action_menu.Item(msg)) {
  let release_items = case allow_release {
    True if config.disable_actions -> [
      action_menu.disabled_item(
        t(config, i18n_text.TaskNextActionRelease),
        "task-show-secondary-release",
        t(config, i18n_text.Working),
        config.on_release(task.id, task.version),
      ),
    ]
    True -> [
      action_menu.item(
        t(config, i18n_text.TaskNextActionRelease),
        "task-show-secondary-release",
        config.on_release(task.id, task.version),
      ),
    ]
    False -> []
  }

  let delete_item = case config.disable_actions {
    True ->
      action_menu.disabled_item(
        t(config, i18n_text.Delete),
        "task-show-secondary-delete",
        t(config, i18n_text.Working),
        config.on_delete(task.id),
      )
    False ->
      action_menu.disabled_item(
        t(config, i18n_text.Delete),
        "task-show-secondary-delete",
        t(config, i18n_text.TaskHasOperationalHistory),
        config.on_delete(task.id),
      )
  }

  list.append(release_items, [delete_item])
}

fn claim_button(config: Config(msg), task: Task) -> Element(msg) {
  let blocked_by_dependencies = task.blocked_count > 0
  let base_button =
    button.text(
      t(config, i18n_text.ClaimTask),
      config.on_claim(task.id, task.version),
      button.Primary,
      button.EntityAction,
    )
    |> button.with_testid("task-show-primary-claim")

  case config.disable_actions, blocked_by_dependencies {
    True, _ -> button.with_disabled(base_button, True)
    False, True ->
      button.with_blocked_reason(
        base_button,
        t(config, i18n_text.TaskBlockedByDependencies),
      )
    False, False ->
      button.with_disabled(base_button, !claimability.can_claim(task))
  }
  |> button.view
}

fn start_work_button(config: Config(msg), task: Task) -> Element(msg) {
  button.text(
    t(config, i18n_text.TaskNextActionStart),
    config.on_start_work(task.id),
    button.Primary,
    button.EntityAction,
  )
  |> button.with_testid("task-show-primary-start")
  |> button.with_disabled(config.disable_actions)
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

fn int_to_string(value: Int) -> String {
  value |> int.to_string
}
