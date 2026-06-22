import gleam/list
import gleam/option.{type Option, None, Some}

import domain/task as domain_task
import lustre/element.{type Element}

import scrumbringer_client/features/pool/blocking
import scrumbringer_client/features/pool/labels as pool_labels
import scrumbringer_client/features/tasks/claimability
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/task_hover_popup
import scrumbringer_client/ui/task_state as task_state_ui
import scrumbringer_client/ui/task_status_utils

pub type Config(msg) {
  Config(
    locale: Locale,
    task: domain_task.Task,
    card_title: Option(String),
    age_days: Int,
    hidden_blocked_count: Option(Int),
    notes: List(domain_task.TaskNote),
    current_user_id: Option(Int),
    on_open: msg,
  )
}

pub fn view(config: Config(msg)) -> Element(msg) {
  task_hover_popup.view(task_hover_popup.TaskHoverConfig(
    card_label: pool_labels.parent_card(config.locale),
    card_title: config.card_title,
    status_label: i18n.t(config.locale, i18n_text.Status),
    status_value: task_state_ui.label(
      config.locale,
      domain_task.status(config.task),
    ),
    status_hint: task_state_ui.hint(
      config.locale,
      domain_task.status(config.task),
    ),
    next_action_label: i18n.t(config.locale, i18n_text.TaskNextActionLabel),
    next_action_value: next_action_value(config),
    age_label: pool_labels.age(config.locale),
    age_value: pool_labels.created_ago_days(config.locale, config.age_days),
    description_label: pool_labels.description(config.locale),
    description: task_description(config.task),
    blocked_label: blocked_label(config.locale, config.task),
    blocked_items: blocked_items(config.locale, config.task),
    blocked_hidden_note: hidden_blocked_note(
      config.locale,
      config.hidden_blocked_count,
    ),
    notes_label: notes_label(config.locale, config.notes),
    notes: hover_notes(config.locale, config.current_user_id, config.notes),
    open_label: pool_labels.open_task(config.locale),
    on_open: config.on_open,
  ))
}

fn next_action_value(config: Config(msg)) -> String {
  case
    claimability.can_claim(config.task),
    blocked_label(config.locale, config.task)
  {
    False, Some(_) -> pool_labels.open_task(config.locale)
    _, _ ->
      task_state_ui.next_action(config.locale, domain_task.status(config.task))
  }
}

fn task_description(task: domain_task.Task) -> String {
  case task.description {
    None -> ""
    Some(text) -> text
  }
}

fn blocked_label(locale: Locale, task: domain_task.Task) -> Option(String) {
  let count = list.length(blocking.incomplete_dependencies(task))
  case count > 0 {
    True -> Some(pool_labels.blocked_by_tasks(locale, count))
    False -> None
  }
}

fn blocked_items(locale: Locale, task: domain_task.Task) -> List(String) {
  blocking.incomplete_dependencies(task)
  |> list.take(2)
  |> list.map(fn(dep) {
    dep.title <> " · " <> task_status_utils.label(locale, dep.status)
  })
}

fn hidden_blocked_note(
  locale: Locale,
  hidden_count: Option(Int),
) -> Option(String) {
  case hidden_count {
    Some(count) if count > 0 ->
      Some(pool_labels.hidden_blocked_by_filters(locale, count))
    _ -> None
  }
}

fn notes_label(
  locale: Locale,
  notes: List(domain_task.TaskNote),
) -> Option(String) {
  case notes {
    [] -> None
    _ -> Some(pool_labels.recent_notes(locale))
  }
}

fn hover_notes(
  locale: Locale,
  current_user_id: Option(Int),
  notes: List(domain_task.TaskNote),
) -> List(task_hover_popup.HoverNote) {
  list.map(notes, fn(note) {
    let domain_task.TaskNote(
      user_id: user_id,
      created_at: created_at,
      content: content,
      ..,
    ) = note
    let author = case current_user_id == Some(user_id) {
      True -> pool_labels.current_user(locale)
      False -> pool_labels.user_number(locale, user_id)
    }
    task_hover_popup.HoverNote(
      author: author,
      created_at: created_at,
      content: content,
    )
  })
}
