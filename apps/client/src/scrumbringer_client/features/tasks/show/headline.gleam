//// Pure operational headline policy for Task Inspector.

import gleam/list
import gleam/option as opt
import gleam/string

import domain/remote.{type Remote, Loaded}
import domain/task as domain_task
import domain/task/state as task_execution_state

import scrumbringer_client/features/pool/blocking
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text

pub type Config {
  Config(
    locale: Locale,
    task: domain_task.Task,
    parent_card_title: opt.Option(String),
    current_user_id: opt.Option(Int),
    dependencies: Remote(List(domain_task.TaskDependency)),
  )
}

pub fn text(config: Config) -> String {
  let blockers = blocking_count(config)

  [primary_signal(config, blockers), ..context(config)]
  |> string.join(" · ")
}

fn primary_signal(config: Config, blockers: Int) -> String {
  case blockers {
    count if count > 0 -> t(config.locale, i18n_text.BlockedByTasks(count))
    _ -> state_signal(config)
  }
}

fn state_signal(config: Config) -> String {
  case config.task.state {
    task_execution_state.Available ->
      t(config.locale, i18n_text.TaskHeadlineAvailable)
    task_execution_state.Claimed(claimed_by: user_id, mode:, ..) ->
      claimed_signal(config, user_id, mode)
    task_execution_state.Closed(..) ->
      t(config.locale, i18n_text.TaskHeadlineClosed)
  }
}

fn claimed_signal(
  config: Config,
  claimed_by: Int,
  mode: task_execution_state.TaskClaimMode,
) -> String {
  case mode {
    task_execution_state.Taken ->
      case config.current_user_id == opt.Some(claimed_by) {
        True -> t(config.locale, i18n_text.TaskHeadlineClaimedByYou)
        False ->
          case config.current_user_id {
            opt.Some(_) ->
              t(config.locale, i18n_text.TaskHeadlineClaimedByOther)
            opt.None -> t(config.locale, i18n_text.TaskHeadlineClaimed)
          }
      }
    task_execution_state.Ongoing ->
      case config.current_user_id == opt.Some(claimed_by) {
        True -> t(config.locale, i18n_text.TaskHeadlineOngoingByYou)
        False ->
          case config.current_user_id {
            opt.Some(_) ->
              t(config.locale, i18n_text.TaskHeadlineOngoingByOther)
            opt.None -> t(config.locale, i18n_text.TaskHeadlineOngoing)
          }
      }
  }
}

fn context(config: Config) -> List(String) {
  []
  |> append_optional(config.parent_card_title)
  |> append_optional(due_date_label(config))
}

fn blocking_count(config: Config) -> Int {
  case config.dependencies {
    Loaded(dependencies) -> blocking.open_dependency_count(dependencies)
    _ -> config.task.blocked_count
  }
}

fn due_date_label(config: Config) -> opt.Option(String) {
  case config.task.due_date {
    opt.Some(date) ->
      opt.Some(t(config.locale, i18n_text.TaskDueDateLabel) <> " " <> date)
    opt.None -> opt.None
  }
}

fn append_optional(
  items: List(String),
  item: opt.Option(String),
) -> List(String) {
  case item {
    opt.Some(value) -> list.append(items, [value])
    opt.None -> items
  }
}

fn t(locale: Locale, key: i18n_text.Text) -> String {
  i18n.t(locale, key)
}
