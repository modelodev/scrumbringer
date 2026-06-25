//// Card tree scope views for member navigation.

import domain/card.{type Card, Closed}
import domain/task.{type Task}
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, h3, h4, section, span, text}
import lustre/event

import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text

pub type DepthName {
  DepthName(depth: Int, singular_name: String, plural_name: String)
}

pub type Scope {
  DepthScope(Int)
  CardScope(Int)
}

pub type Config(msg) {
  Config(
    locale: Locale,
    cards: List(Card),
    tasks: List(Task),
    depth_names: List(DepthName),
    scope: Scope,
    include_closed: Bool,
    on_card_opened: fn(Int) -> msg,
    on_task_opened: fn(Int) -> msg,
    on_include_closed_toggled: msg,
  )
}

pub fn view(config: Config(msg)) -> Element(msg) {
  section(
    [
      attribute.class("card-tree-scope-shell"),
      attribute.attribute("data-testid", "card-tree-scope"),
      attribute.attribute("data-scope", scope_id(config.scope)),
    ],
    [
      view_header(config),
      case config.scope {
        DepthScope(depth) -> view_depth_scope(config, depth)
        CardScope(card_id) -> view_card_scope(config, card_id)
      },
    ],
  )
}

fn view_header(config: Config(msg)) -> Element(msg) {
  div([attribute.class("card-tree-header")], [
    div([], [
      h3([], [text(scope_title(config))]),
      span([attribute.class("card-tree-subtitle")], [
        text(i18n.t(config.locale, i18n_text.HierarchyScopeSubtitle)),
      ]),
    ]),
    button(
      [
        attribute.class("scope-toggle-btn"),
        attribute.attribute("data-testid", "include-closed-toggle"),
        event.on_click(config.on_include_closed_toggled),
      ],
      [text("Incluir cerradas")],
    ),
  ])
}

fn view_depth_scope(config: Config(msg), depth: Int) -> Element(msg) {
  let cards =
    visible_cards(config)
    |> list.filter(fn(card) { card_depth(card, config.cards) == depth })

  case cards {
    [] -> view_empty_depth(config, depth)
    _ -> view_card_grid(config, cards)
  }
}

fn view_card_scope(config: Config(msg), card_id: Int) -> Element(msg) {
  let direct_cards =
    visible_cards(config)
    |> list.filter(fn(card) { card.parent_card_id == Some(card_id) })
  let direct_tasks =
    config.tasks
    |> list.filter(fn(task) { task.card_id == Some(card_id) })

  div([attribute.class("card-tree-card-scope")], [
    view_card_grid(config, direct_cards),
    view_tasks(
      i18n.t(config.locale, i18n_text.HierarchyScopeDirectTasks),
      direct_tasks,
      config.on_task_opened,
    ),
  ])
}

fn view_card_grid(config: Config(msg), cards: List(Card)) -> Element(msg) {
  let dense_class = case list.length(cards) > 4 {
    True -> " card-tree-grid-dense"
    False -> ""
  }
  div(
    [attribute.class("card-tree-grid" <> dense_class)],
    list.map(cards, fn(card) { view_card(config, card) }),
  )
}

fn view_card(config: Config(msg), card: Card) -> Element(msg) {
  button(
    [
      attribute.class("card-tree-card"),
      attribute.attribute("data-testid", "card-tree-card"),
      event.on_click(config.on_card_opened(card.id)),
    ],
    [
      span([attribute.class("card-tree-card-title")], [text(card.title)]),
      span([attribute.class("card-tree-card-meta")], [
        text(depth_label(
          config.locale,
          config.depth_names,
          card_depth(card, config.cards),
        )),
      ]),
    ],
  )
}

fn view_tasks(
  title: String,
  tasks: List(Task),
  on_task_opened: fn(Int) -> msg,
) -> Element(msg) {
  div([attribute.class("card-tree-task-group")], [
    h4([], [text(title)]),
    div(
      [attribute.class("card-tree-task-list")],
      list.map(tasks, fn(task) {
        button(
          [
            attribute.class("card-tree-task"),
            attribute.attribute("data-testid", "card-tree-task"),
            event.on_click(on_task_opened(task.id)),
          ],
          [text(task.title)],
        )
      }),
    ),
  ])
}

fn view_empty_depth(config: Config(msg), depth: Int) -> Element(msg) {
  let name = depth_label(config.locale, config.depth_names, depth)
  div([attribute.class("card-tree-empty")], [
    h4([], [
      text(i18n.t(config.locale, i18n_text.HierarchyScopeEmptyDepthTitle)),
    ]),
    span([], [
      text(i18n.t(config.locale, i18n_text.HierarchyScopeEmptyDepthBody(name))),
    ]),
  ])
}

fn visible_cards(config: Config(msg)) -> List(Card) {
  case config.include_closed {
    True -> config.cards
    False -> list.filter(config.cards, fn(card) { card.state != Closed })
  }
}

fn card_depth(card: Card, cards: List(Card)) -> Int {
  case card.parent_card_id {
    None -> 1
    Some(parent_id) ->
      case list.find(cards, fn(candidate) { candidate.id == parent_id }) {
        Ok(parent) -> 1 + card_depth(parent, cards)
        Error(_) -> 1
      }
  }
}

fn depth_label(
  locale: Locale,
  depth_names: List(DepthName),
  depth: Int,
) -> String {
  case list.find(depth_names, fn(name) { name.depth == depth }) {
    Ok(DepthName(plural_name: plural, ..)) -> plural
    Error(_) -> i18n.t(locale, i18n_text.HierarchyScopeDepthFallback(depth))
  }
}

fn scope_title(config: Config(msg)) -> String {
  case config.scope {
    DepthScope(depth) -> depth_label(config.locale, config.depth_names, depth)
    CardScope(_) -> i18n.t(config.locale, i18n_text.HierarchyScopeCardTitle)
  }
}

fn scope_id(scope: Scope) -> String {
  case scope {
    DepthScope(depth) -> "depth:" <> int.to_string(depth)
    CardScope(card_id) -> "card:" <> int.to_string(card_id)
  }
}
