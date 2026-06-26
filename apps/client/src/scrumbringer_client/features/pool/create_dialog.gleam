//// Task creation dialog view.

import gleam/int
import gleam/list
import gleam/option as opt
import gleam/string

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, form, input, option, select, text}
import lustre/event

import domain/card.{type Card, Active, Draft}
import domain/remote.{type Remote, Failed, Loaded, Loading, NotAsked}
import domain/task_type.{type TaskType}

import scrumbringer_client/features/cards/card_target
import scrumbringer_client/features/cards/card_target_field
import scrumbringer_client/features/hierarchy/scope_view
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/button as ui_button
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
    card_query: String,
    in_flight: Bool,
    task_types: Remote(List(TaskType)),
    cards: List(Card),
    cards_loading: Bool,
    depth_names: List(scope_view.DepthName),
    on_close: msg,
    on_submit: msg,
    on_title_changed: fn(String) -> msg,
    on_description_changed: fn(String) -> msg,
    on_priority_changed: fn(String) -> msg,
    on_type_id_changed: fn(String) -> msg,
    on_card_id_changed: fn(String) -> msg,
    on_card_query_changed: fn(String) -> msg,
    on_type_options_retry_clicked: msg,
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
          view_card_field(config),
        ],
      ),
    ],
    [
      dialog.cancel_button_with_locale(config.locale, config.on_close),
      dialog.submit_button_with_locale_form(
        config.locale,
        "task-create-form",
        config.in_flight,
        create_context_blocks_submit(config),
        i18n_text.Create,
        i18n_text.Creating,
      ),
    ],
  )
}

fn view_card_field(config: Config(msg)) -> Element(msg) {
  let options =
    card_target.active_task_targets(config.cards, config.depth_names)
  let filtered_options = card_target.filter_options(options, config.card_query)

  div([attribute.class("task-create-card-target")], [
    card_target_field.view(card_target_field.Config(
      label: t(config, i18n_text.TaskCreateActiveCardLabel),
      placeholder: t(config, i18n_text.TaskCreateRequiresCard),
      selected_label: card_target.selected_label(options, config.card_id),
      query: config.card_query,
      options: filtered_options,
      loading: config.cards_loading,
      disabled: config.in_flight,
      empty_title: t(config, i18n_text.TaskCreateNoActiveCards),
      empty_body: t(config, i18n_text.TaskCreateRequiresCard),
      loading_label: t(config, i18n_text.LoadingEllipsis),
      listbox_id: "task-create-card-options",
      testid_prefix: "task-create-card",
      show_options_when_empty: config.card_id == opt.None,
      on_query_changed: config.on_card_query_changed,
      on_selected: config.on_card_id_changed,
    )),
    view_invalid_card_hint(config),
  ])
}

fn view_invalid_card_hint(config: Config(msg)) -> Element(msg) {
  case config.card_id {
    opt.None -> element.none()
    opt.Some(card_id) ->
      case selected_card(config.cards, card_id) {
        opt.None -> invalid_hint(t(config, i18n_text.TaskCreateMissingCard))
        opt.Some(card) ->
          case
            card.state == Active && !card_has_child_cards(config.cards, card)
          {
            True -> element.none()
            False -> invalid_hint(card_context_hint(config, card))
          }
      }
  }
}

fn invalid_hint(message: String) -> Element(msg) {
  div(
    [
      attribute.class("task-create-context-hint"),
      attribute.attribute("data-testid", "task-create-context-hint"),
    ],
    [text(message)],
  )
}

fn selected_card(cards: List(Card), card_id: Int) -> opt.Option(Card) {
  list.find(cards, fn(card) { card.id == card_id })
  |> opt.from_result
}

fn card_context_hint(config: Config(msg), card: Card) -> String {
  case card.state, card_has_child_cards(config.cards, card) {
    _, True -> t(config, i18n_text.TaskCreateCardHasChildCards)
    Draft, False -> t(config, i18n_text.TaskCreateInactiveCard)
    _, False -> t(config, i18n_text.TaskCreateClosedCard)
  }
}

fn view_title_field(config: Config(msg)) -> Element(msg) {
  form_field.view(
    t(config, i18n_text.Title),
    input([
      attribute.id("task-create-title"),
      attribute.attribute("aria-label", t(config, i18n_text.Title)),
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
      attribute.id("task-create-description"),
      attribute.attribute("aria-label", t(config, i18n_text.Description)),
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
      attribute.id("task-create-priority"),
      attribute.attribute("aria-label", t(config, i18n_text.Priority)),
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
          attribute.id("task-create-type"),
          attribute.attribute("aria-label", t(config, i18n_text.TypeLabel)),
          attribute.value(config.type_id),
          event.on_input(config.on_type_id_changed),
          event.on_change(config.on_type_id_changed),
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

fn card_has_child_cards(cards: List(Card), card: Card) -> Bool {
  list.any(cards, fn(candidate) {
    candidate.parent_card_id == opt.Some(card.id)
  })
}

fn create_context_blocks_submit(config: Config(msg)) -> Bool {
  case create_form_blocks_submit(config) {
    True -> True
    False -> create_card_context_blocks_submit(config)
  }
}

fn create_form_blocks_submit(config: Config(msg)) -> Bool {
  string.trim(config.title) == ""
  || string.length(string.trim(config.title)) > 56
  || type_blocks_submit(config.type_id)
  || priority_blocks_submit(config.priority)
}

fn type_blocks_submit(type_id_value: String) -> Bool {
  case int.parse(type_id_value) {
    Ok(_) -> False
    Error(_) -> True
  }
}

fn priority_blocks_submit(priority_value: String) -> Bool {
  case int.parse(priority_value) {
    Ok(priority) -> priority < 1 || priority > 5
    Error(_) -> True
  }
}

fn create_card_context_blocks_submit(config: Config(msg)) -> Bool {
  case config.card_id {
    opt.None -> True
    opt.Some(card_id) -> {
      case selected_card(config.cards, card_id) {
        opt.None -> True
        opt.Some(card) ->
          card.state != Active || card_has_child_cards(config.cards, card)
      }
    }
  }
}
