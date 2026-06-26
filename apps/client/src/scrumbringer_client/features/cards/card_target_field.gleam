//// Shared visual field for selecting a card target.

import gleam/int
import gleam/list
import gleam/option as opt

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, input, label, span, text}
import lustre/event

import scrumbringer_client/features/cards/card_target.{
  type CardTargetOption, type DisabledReason,
}

pub type Config(msg) {
  Config(
    label: String,
    placeholder: String,
    selected_label: String,
    query: String,
    options: List(CardTargetOption),
    loading: Bool,
    error: opt.Option(String),
    disabled: Bool,
    empty_title: String,
    empty_body: String,
    loading_label: String,
    retry_label: String,
    hint: opt.Option(String),
    show_empty: Bool,
    listbox_id: String,
    testid_prefix: String,
    disabled_reason_label: fn(DisabledReason) -> String,
    on_query_changed: fn(String) -> msg,
    on_selected: fn(String) -> msg,
    on_retry: opt.Option(msg),
  )
}

pub fn view(config: Config(msg)) -> Element(msg) {
  let input_value = case config.query {
    "" -> config.selected_label
    query -> query
  }

  div([attribute.class("card-target-field")], [
    label([attribute.class("card-target-label")], [text(config.label)]),
    input([
      attribute.type_("search"),
      attribute.class("card-target-input"),
      attribute.attribute("data-testid", config.testid_prefix <> "-search"),
      attribute.attribute("role", "combobox"),
      attribute.attribute("aria-controls", config.listbox_id),
      attribute.attribute("aria-expanded", bool_string(options_visible(config))),
      attribute.attribute("aria-autocomplete", "list"),
      attribute.attribute("autocomplete", "off"),
      attribute.attribute("aria-label", config.label),
      attribute.placeholder(config.placeholder),
      attribute.value(input_value),
      attribute.disabled(config.disabled || config.loading),
      event.on_input(config.on_query_changed),
      event.on_change(config.on_query_changed),
    ]),
    view_options(config),
  ])
}

fn view_options(config: Config(msg)) -> Element(msg) {
  case options_visible(config) {
    False -> element.none()
    True ->
      div(
        [
          attribute.id(config.listbox_id),
          attribute.class("card-target-options"),
          attribute.attribute("data-testid", config.testid_prefix <> "-options"),
          attribute.attribute("role", "listbox"),
        ],
        case config.loading, config.error, config.options {
          True, _, _ -> [
            span([attribute.class("card-target-empty")], [
              text(config.loading_label),
            ]),
          ]
          False, opt.Some(message), _ -> [view_error(config, message)]
          False, opt.None, [] ->
            case config.show_empty {
              True -> list.append([view_empty(config)], view_hint(config))
              False -> view_hint(config)
            }
          False, opt.None, options ->
            list.append(
              list.map(options, fn(option) { view_option(config, option) }),
              view_hint(config),
            )
        },
      )
  }
}

fn view_empty(config: Config(msg)) -> Element(msg) {
  div([attribute.class("card-target-empty")], [
    span([attribute.class("card-target-empty-title")], [
      text(config.empty_title),
    ]),
    span([attribute.class("card-target-empty-body")], [
      text(config.empty_body),
    ]),
  ])
}

fn view_error(config: Config(msg), message: String) -> Element(msg) {
  div([attribute.class("card-target-empty")], [
    span([attribute.class("card-target-empty-title")], [text(message)]),
    case config.on_retry {
      opt.Some(msg) ->
        button(
          [
            attribute.type_("button"),
            attribute.class("btn btn-secondary btn-sm card-target-retry"),
            attribute.attribute("data-testid", config.testid_prefix <> "-retry"),
            attribute.disabled(config.disabled),
            event.on_click(msg),
          ],
          [text(config.retry_label)],
        )
      opt.None -> element.none()
    },
  ])
}

fn view_hint(config: Config(msg)) -> List(Element(msg)) {
  case config.hint {
    opt.Some(message) -> [
      span([attribute.class("card-target-hint")], [text(message)]),
    ]
    opt.None -> []
  }
}

fn view_option(config: Config(msg), target: CardTargetOption) -> Element(msg) {
  let disabled = case target.disabled_reason {
    opt.Some(_) -> True
    opt.None -> False
  }

  button(
    [
      attribute.type_("button"),
      attribute.class(option_class(disabled)),
      attribute.attribute("data-testid", config.testid_prefix <> "-option"),
      attribute.attribute("data-card-id", int.to_string(target.id)),
      attribute.attribute("role", "option"),
      attribute.attribute("aria-label", target.label),
      attribute.disabled(config.disabled || disabled),
      event.on_click(config.on_selected(int.to_string(target.id))),
    ],
    [
      span([attribute.class("card-target-title")], [text(target.title)]),
      span([attribute.class("card-target-meta")], [
        text(
          target.path
          <> " - "
          <> target.level_name
          <> " #"
          <> int.to_string(target.id),
        ),
      ]),
      case target.disabled_reason {
        opt.Some(reason) ->
          span([attribute.class("card-target-reason")], [
            text(config.disabled_reason_label(reason)),
          ])
        opt.None -> element.none()
      },
    ],
  )
}

fn options_visible(config: Config(msg)) -> Bool {
  config.loading
  || config.error != opt.None
  || !list.is_empty(config.options)
  || config.hint != opt.None
  || config.show_empty
}

fn option_class(disabled: Bool) -> String {
  case disabled {
    True -> "card-target-option is-disabled"
    False -> "card-target-option"
  }
}

fn bool_string(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
}
