import domain/card.{type Card}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{
  button, div, input, label, option as html_option, select, span, text,
}
import lustre/event

import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/hierarchy/scope_view
import scrumbringer_client/features/plan/card_picker
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text

pub type Config(msg) {
  Config(
    locale: Locale,
    cards: List(Card),
    depth_names: List(scope_view.DepthName),
    scope_kind: member_pool.PlanScopeKind,
    selected_depth: Option(Int),
    selected_card_id: Option(Int),
    show_closed: Bool,
    id_prefix: String,
    mode_controls: List(ModeControl(msg)),
    on_scope_kind_change: fn(String) -> msg,
    on_scope_depth_change: fn(String) -> msg,
    on_scope_card_change: fn(String) -> msg,
    on_closed_toggled: fn(Bool) -> msg,
  )
}

pub type ModeControl(msg) {
  ModeControl(
    label: String,
    value: String,
    active: Bool,
    testid: String,
    on_select: msg,
  )
}

pub fn view(config: Config(msg)) -> Element(msg) {
  div(
    [
      attribute.class("plan-scope-bar"),
      attribute.attribute("data-testid", "plan-scope-bar"),
    ],
    [
      view_scope_controls(config),
      view_mode_controls(config),
      label([attribute.class("plan-closed-toggle")], [
        input([
          attribute.type_("checkbox"),
          attribute.checked(config.show_closed),
          attribute.attribute("data-testid", "plan-closed-toggle"),
          event.on_check(config.on_closed_toggled),
        ]),
        span([], [text(i18n.t(config.locale, i18n_text.PlanClosed))]),
      ]),
    ],
  )
}

fn view_scope_controls(config: Config(msg)) -> Element(msg) {
  div([attribute.class("plan-scope-controls")], [
    label([], [text(i18n.t(config.locale, i18n_text.PlanScope))]),
    select(
      [
        attribute.attribute("data-testid", "plan-scope-kind"),
        attribute.value(scope_kind_value(config.scope_kind)),
        event.on_input(config.on_scope_kind_change),
        event.on_change(config.on_scope_kind_change),
      ],
      [
        html_option(
          [attribute.value("project")],
          i18n.t(config.locale, i18n_text.PlanScopeProject),
        ),
        html_option(
          [attribute.value("level")],
          i18n.t(config.locale, i18n_text.PlanScopeLevel),
        ),
        html_option(
          [attribute.value("card")],
          i18n.t(config.locale, i18n_text.PlanScopeCard),
        ),
      ],
    ),
    case config.scope_kind {
      member_pool.PlanScopeProject -> element.none()
      member_pool.PlanScopeLevel -> view_depth_selector(config)
      member_pool.PlanScopeCard -> view_card_search(config)
    },
  ])
}

fn view_depth_selector(config: Config(msg)) -> Element(msg) {
  select(
    [
      attribute.attribute("data-testid", "plan-scope-depth"),
      attribute.value(option_int_to_string(config.selected_depth)),
      event.on_input(config.on_scope_depth_change),
      event.on_change(config.on_scope_depth_change),
    ],
    [
      html_option(
        [attribute.value("")],
        i18n.t(config.locale, i18n_text.PlanScopeAllLevels),
      ),
      ..list.map(config.depth_names, fn(depth_name) {
        let scope_view.DepthName(depth: depth, plural_name: name, ..) =
          depth_name
        html_option(
          [
            attribute.value(int.to_string(depth)),
            attribute.selected(config.selected_depth == Some(depth)),
          ],
          name,
        )
      })
    ],
  )
}

fn view_card_search(config: Config(msg)) -> Element(msg) {
  let listbox_id = config.id_prefix <> "-active-card-options"
  let options = card_picker.active_options(config.cards, config.depth_names)

  div([attribute.class("plan-card-scope-control")], [
    input([
      attribute.type_("search"),
      attribute.attribute("data-testid", "plan-scope-card-search"),
      attribute.attribute("role", "combobox"),
      attribute.attribute("aria-controls", listbox_id),
      attribute.attribute("aria-expanded", "true"),
      attribute.attribute("autocomplete", "off"),
      attribute.placeholder(i18n.t(config.locale, i18n_text.PlanScopeSelectCard)),
      attribute.value(card_picker.selected_label(
        config.cards,
        config.depth_names,
        config.selected_card_id,
      )),
      event.on_input(fn(value) {
        config.on_scope_card_change(card_picker.search_value_to_card_id(
          config.cards,
          config.depth_names,
          value,
        ))
      }),
      event.on_change(fn(value) {
        config.on_scope_card_change(card_picker.search_value_to_card_id(
          config.cards,
          config.depth_names,
          value,
        ))
      }),
    ]),
    view_card_options(listbox_id, options, config.on_scope_card_change),
  ])
}

fn view_card_options(
  listbox_id: String,
  options: List(card_picker.CardOption),
  on_scope_card_change: fn(String) -> msg,
) -> Element(msg) {
  div(
    [
      attribute.id(listbox_id),
      attribute.class("plan-card-picker-options"),
      attribute.attribute("data-testid", "plan-scope-card-options"),
      attribute.attribute("role", "listbox"),
    ],
    case options {
      [] -> [
        span(
          [
            attribute.class("plan-card-picker-empty"),
            attribute.attribute("data-testid", "plan-scope-card-no-results"),
          ],
          [text("Sin cards activas")],
        ),
      ]
      _ ->
        list.map(options, fn(option) {
          view_card_option(option, on_scope_card_change)
        })
    },
  )
}

fn view_card_option(
  option: card_picker.CardOption,
  on_scope_card_change: fn(String) -> msg,
) -> Element(msg) {
  button(
    [
      attribute.type_("button"),
      attribute.class("plan-card-picker-option"),
      attribute.attribute("data-testid", "plan-scope-card-option"),
      attribute.attribute("data-card-id", int.to_string(option.id)),
      attribute.attribute("role", "option"),
      attribute.attribute("aria-label", option.label),
      event.on_click(on_scope_card_change(int.to_string(option.id))),
    ],
    [
      span([attribute.class("plan-card-picker-title")], [text(option.title)]),
      span([attribute.class("plan-card-picker-meta")], [
        text(
          option.path
          <> " - "
          <> option.level_name
          <> " #"
          <> int.to_string(option.id),
        ),
      ]),
    ],
  )
}

fn view_mode_controls(config: Config(msg)) -> Element(msg) {
  case config.mode_controls {
    [] -> element.none()
    controls ->
      div([attribute.class("plan-mode-controls")], [
        span([attribute.class("plan-mode-label")], [
          text(i18n.t(config.locale, i18n_text.PlanMode)),
        ]),
        ..list.map(controls, view_mode_button)
      ])
  }
}

fn view_mode_button(control: ModeControl(msg)) -> Element(msg) {
  let class = case control.active {
    True -> "plan-mode-btn is-active"
    False -> "plan-mode-btn"
  }

  button(
    [
      attribute.type_("button"),
      attribute.class(class),
      attribute.attribute("data-testid", control.testid),
      attribute.attribute("data-value", control.value),
      attribute.attribute("aria-pressed", bool_string(control.active)),
      event.on_click(control.on_select),
    ],
    [text(control.label)],
  )
}

fn scope_kind_value(scope_kind: member_pool.PlanScopeKind) -> String {
  case scope_kind {
    member_pool.PlanScopeProject -> "project"
    member_pool.PlanScopeLevel -> "level"
    member_pool.PlanScopeCard -> "card"
  }
}

fn option_int_to_string(value: Option(Int)) -> String {
  case value {
    Some(int_value) -> int.to_string(int_value)
    None -> ""
  }
}

fn bool_string(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
}
