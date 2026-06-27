//// Pure operational headline policy for Card Inspector.

import gleam/int
import gleam/option
import gleam/string

import domain/card.{type Card}

import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/card_state

pub type Config {
  Config(locale: Locale, card: Card)
}

pub fn text(config: Config) -> String {
  [
    card_state.label(config.locale, config.card.state),
    due_date_label(config),
    work_label(config),
  ]
  |> string.join(" · ")
}

fn due_date_label(config: Config) -> String {
  case config.card.due_date {
    option.Some(date) ->
      t(config.locale, i18n_text.TaskDueDateLabel) <> " " <> date
    option.None -> t(config.locale, i18n_text.NoDueDate)
  }
}

fn work_label(config: Config) -> String {
  case config.card.task_count {
    0 -> t(config.locale, i18n_text.CardTasksEmpty)
    total ->
      int.to_string(config.card.closed_count)
      <> " "
      <> t(config.locale, i18n_text.CardTasksClosed)
      <> " · "
      <> int.to_string(total)
      <> " "
      <> t(config.locale, i18n_text.CardTasks)
  }
}

fn t(locale: Locale, key: i18n_text.Text) -> String {
  i18n.t(locale, key)
}
