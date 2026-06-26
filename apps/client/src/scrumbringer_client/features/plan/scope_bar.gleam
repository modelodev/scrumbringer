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
import scrumbringer_client/features/plan/scope_card_field
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
    card_query: String,
    show_closed: Bool,
    id_prefix: String,
    mode_controls: List(ModeControl(msg)),
    refinement_controls: List(Element(msg)),
    show_closed_control: Bool,
    on_scope_kind_change: fn(String) -> msg,
    on_scope_depth_change: fn(String) -> msg,
    on_scope_card_change: fn(String) -> msg,
    on_scope_card_search_change: fn(String) -> msg,
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
      view_refinement_controls(config),
      view_closed_toggle(config),
    ],
  )
}

fn view_closed_toggle(config: Config(msg)) -> Element(msg) {
  case config.show_closed_control {
    False -> element.none()
    True ->
      label([attribute.class("plan-closed-toggle")], [
        input([
          attribute.type_("checkbox"),
          attribute.checked(config.show_closed),
          attribute.attribute("data-testid", "plan-closed-toggle"),
          event.on_check(config.on_closed_toggled),
        ]),
        span([], [text(i18n.t(config.locale, i18n_text.PlanClosed))]),
      ])
  }
}

fn view_refinement_controls(config: Config(msg)) -> Element(msg) {
  case config.refinement_controls {
    [] -> element.none()
    controls -> div([attribute.class("plan-refinement-controls")], controls)
  }
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
  div([attribute.class("plan-card-scope-control")], [
    scope_card_field.view(scope_card_field.Config(
      locale: config.locale,
      cards: config.cards,
      depth_names: config.depth_names,
      selected_card_id: config.selected_card_id,
      query: config.card_query,
      id_prefix: config.id_prefix,
      on_query_changed: config.on_scope_card_search_change,
      on_selected: config.on_scope_card_change,
    )),
  ])
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
