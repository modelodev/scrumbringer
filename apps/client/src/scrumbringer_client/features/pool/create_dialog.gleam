//// Task creation dialog view.

import gleam/int
import gleam/list
import gleam/option as opt

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, form, input, option, select, text}
import lustre/event

import domain/card.{type Card, Active, Closed, Draft}
import domain/remote.{type Remote, Failed, Loaded, Loading, NotAsked}
import domain/task_type.{type TaskType}

import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/button as ui_button
import scrumbringer_client/ui/color_picker
import scrumbringer_client/ui/dialog
import scrumbringer_client/ui/form_field
import scrumbringer_client/ui/icons

pub type Config(msg) {
  Config(
    locale: Locale,
    error: opt.Option(String),
    title: String,
    description: String,
    priority: String,
    type_id: String,
    card_id: opt.Option(Int),
    in_flight: Bool,
    task_types: Remote(List(TaskType)),
    cards: List(Card),
    on_close: msg,
    on_submit: msg,
    on_title_changed: fn(String) -> msg,
    on_description_changed: fn(String) -> msg,
    on_priority_changed: fn(String) -> msg,
    on_type_id_changed: fn(String) -> msg,
    on_type_options_retry_clicked: msg,
    on_card_id_changed: fn(String) -> msg,
  )
}

fn t(config: Config(msg), key: i18n_text.Text) -> String {
  i18n.t(config.locale, key)
}

pub fn view(config: Config(msg)) -> Element(msg) {
  dialog.view_with_close_label(
    dialog.DialogConfig(
      title: t(config, i18n_text.NewTask),
      icon: opt.Some(icons.nav_icon(icons.ClipboardDoc, icons.Medium)),
      size: dialog.DialogMd,
      on_close: config.on_close,
    ),
    t(config, i18n_text.Close),
    True,
    config.error,
    [
      form(
        [
          event.on_submit(fn(_) { config.on_submit }),
          attribute.id("task-create-form"),
        ],
        [
          view_title_field(config),
          view_description_field(config),
          view_priority_field(config),
          view_type_field(config),
          view_card_selector(config),
          view_creation_context_hint(config),
        ],
      ),
    ],
    [
      dialog.cancel_button_with_locale(config.locale, config.on_close),
      dialog.submit_button_with_locale_form(
        config.locale,
        "task-create-form",
        config.in_flight,
        False,
        i18n_text.Create,
        i18n_text.Creating,
      ),
    ],
  )
}

fn view_creation_context_hint(config: Config(msg)) -> Element(msg) {
  div(
    [
      attribute.class("task-create-context-hint"),
      attribute.attribute("data-testid", "task-create-context-hint"),
    ],
    [text(creation_context_hint(config))],
  )
}

fn creation_context_hint(config: Config(msg)) -> String {
  case config.card_id {
    opt.None ->
      "Root Pool task. Requires manage flow; it will be available in the Pool and will not be auto-claimed."
    opt.Some(card_id) ->
      case selected_card(config.cards, card_id) {
        opt.Some(card) -> card_context_hint(card)
        opt.None -> "This task will not be auto-claimed."
      }
  }
}

fn selected_card(cards: List(Card), card_id: Int) -> opt.Option(Card) {
  list.find(cards, fn(card) { card.id == card_id })
  |> opt.from_result
}

fn card_context_hint(card: Card) -> String {
  case card.state {
    Draft ->
      "This task will not be auto-claimed. It will stay prepared until this card is activated."
    Active ->
      "This task will enter the Pool when created and be available for someone with the matching capability. It will not be auto-claimed."
    Closed -> "Closed cards cannot receive new tasks."
  }
}

fn view_title_field(config: Config(msg)) -> Element(msg) {
  form_field.view(
    t(config, i18n_text.Title),
    input([
      attribute.type_("text"),
      attribute.attribute("maxlength", "56"),
      attribute.value(config.title),
      event.on_input(config.on_title_changed),
    ]),
  )
}

fn view_description_field(config: Config(msg)) -> Element(msg) {
  form_field.view(
    t(config, i18n_text.Description),
    input([
      attribute.type_("text"),
      attribute.value(config.description),
      event.on_input(config.on_description_changed),
    ]),
  )
}

fn view_priority_field(config: Config(msg)) -> Element(msg) {
  form_field.with_hint(
    t(config, i18n_text.Priority),
    input([
      attribute.type_("number"),
      attribute.attribute("min", "1"),
      attribute.attribute("max", "5"),
      attribute.value(config.priority),
      event.on_input(config.on_priority_changed),
    ]),
    "1 = "
      <> t(config, i18n_text.PriorityHighest)
      <> ", 5 = "
      <> t(config, i18n_text.PriorityLowest),
  )
}

fn view_type_field(config: Config(msg)) -> Element(msg) {
  form_field.view(
    t(config, i18n_text.TypeLabel),
    div([], [
      select(
        [
          attribute.value(config.type_id),
          event.on_input(config.on_type_id_changed),
          attribute.disabled(case config.task_types {
            Loaded(_) -> False
            _ -> True
          }),
        ],
        task_type_options(config),
      ),
      case config.task_types {
        Failed(_) ->
          ui_button.text(
            t(config, i18n_text.Retry),
            config.on_type_options_retry_clicked,
            ui_button.Secondary,
            ui_button.EntityAction,
          )
          |> ui_button.view
        _ -> element.none()
      },
    ]),
  )
}

fn task_type_options(config: Config(msg)) -> List(Element(msg)) {
  case config.task_types {
    Loaded(task_types) -> [
      option([attribute.value("")], t(config, i18n_text.SelectType)),
      ..list.map(task_types, fn(tt) {
        option([attribute.value(int.to_string(tt.id))], tt.name)
      })
    ]
    Loading -> [
      option([attribute.value("")], t(config, i18n_text.LoadingEllipsis)),
    ]
    NotAsked -> [
      option([attribute.value("")], t(config, i18n_text.SelectProjectFirst)),
    ]
    Failed(_) -> [
      option([attribute.value("")], t(config, i18n_text.ErrorLoadingTasks)),
    ]
  }
}

fn view_card_selector(config: Config(msg)) -> Element(msg) {
  form_field.view(
    t(config, i18n_text.ParentCardLabel),
    select(
      [
        attribute.value(card_id_to_string(config.card_id)),
        event.on_input(config.on_card_id_changed),
      ],
      [
        option(
          [
            attribute.value(""),
            attribute.selected(opt.is_none(config.card_id)),
          ],
          t(config, i18n_text.NoCard),
        ),
        ..list.map(config.cards, fn(card) { view_card_option(config, card) })
      ],
    ),
  )
}

fn view_card_option(config: Config(msg), card: Card) -> Element(msg) {
  let color_indicator = case card.color {
    opt.Some(color) -> color_picker.color_emoji(color) <> " "
    opt.None -> ""
  }

  let is_selected = config.card_id == opt.Some(card.id)

  option(
    [attribute.value(int.to_string(card.id)), attribute.selected(is_selected)],
    color_indicator <> card.title,
  )
}

fn card_id_to_string(card_id: opt.Option(Int)) -> String {
  case card_id {
    opt.Some(id) -> int.to_string(id)
    opt.None -> ""
  }
}
