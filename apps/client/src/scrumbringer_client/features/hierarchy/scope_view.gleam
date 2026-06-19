//// Card tree scope/profile views for member navigation.

import domain/card.{type Card, type CardPhase, Active, Closed, Draft}
import domain/task.{type Task}
import domain/task_type.{type TaskType}
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, h3, h4, section, span, text}
import lustre/event

import scrumbringer_client/i18n/locale.{type Locale}

pub type DepthName {
  DepthName(depth: Int, singular_name: String, plural_name: String)
}

pub type Scope {
  DepthScope(Int)
  CardScope(Int)
  TrackingProfile
  CoordinationProfile
  ExecutionProfile
}

pub type Config(msg) {
  Config(
    locale: Locale,
    cards: List(Card),
    tasks: List(Task),
    task_types: List(TaskType),
    capabilities: List(#(Int, String)),
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
        TrackingProfile -> view_tracking_profile(config)
        CoordinationProfile -> view_coordination_profile(config)
        ExecutionProfile -> view_execution_profile(config)
      },
    ],
  )
}

fn view_header(config: Config(msg)) -> Element(msg) {
  div([attribute.class("card-tree-header")], [
    div([], [
      h3([], [text(scope_title(config))]),
      span([attribute.class("card-tree-subtitle")], [
        text("Track nested cards and task leaves by scope."),
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
    view_tasks("Direct tasks", direct_tasks, config.on_task_opened),
  ])
}

fn view_tracking_profile(config: Config(msg)) -> Element(msg) {
  div(
    [attribute.class("card-tree-profile card-tree-tracking")],
    list.append(
      [
        view_scope_section(
          "Tracking",
          view_card_grid(config, visible_cards(config)),
        ),
      ],
      list.append(view_depth_sections(config), [
        view_scope_section("Coordination", view_coordination_profile(config)),
        view_scope_section("Execution", view_execution_profile(config)),
        view_card_scope_preview(config),
      ]),
    ),
  )
}

fn view_coordination_profile(config: Config(msg)) -> Element(msg) {
  div([attribute.class("card-tree-profile card-tree-coordination")], [
    view_state_group(config, "Draft", Draft),
    view_state_group(config, "Active", Active),
    view_state_group(config, "Closed", Closed),
  ])
}

fn view_execution_profile(config: Config(msg)) -> Element(msg) {
  div([attribute.class("card-tree-profile card-tree-execution")], [
    h4([], [text("Execution")]),
    ..list.map(config.capabilities, fn(capability) {
      let #(capability_id, name) = capability
      view_tasks(
        name,
        tasks_for_capability(config, capability_id),
        config.on_task_opened,
      )
    })
  ])
}

fn view_scope_section(title: String, body: Element(msg)) -> Element(msg) {
  div([attribute.class("card-tree-section")], [
    h4([attribute.class("card-tree-section-title")], [text(title)]),
    body,
  ])
}

fn view_depth_sections(config: Config(msg)) -> List(Element(msg)) {
  list.map(config.depth_names, fn(depth_name) {
    let DepthName(depth: depth, plural_name: plural, ..) = depth_name
    view_scope_section(plural, view_depth_scope(config, depth))
  })
}

fn view_card_scope_preview(config: Config(msg)) -> Element(msg) {
  let cards = visible_cards(config)
  case list.find(cards, fn(card) { has_direct_cards(config, card.id) }) {
    Ok(card) -> view_card_scope_section(config, card)
    Error(_) -> view_first_card_with_direct_contents(config, cards)
  }
}

fn view_first_card_with_direct_contents(
  config: Config(msg),
  cards: List(Card),
) -> Element(msg) {
  case list.find(cards, fn(card) { has_direct_contents(config, card.id) }) {
    Ok(card) -> view_card_scope_section(config, card)
    Error(_) ->
      div([attribute.class("card-tree-section card-tree-section-empty")], [
        h4([attribute.class("card-tree-section-title")], [text("Card scope")]),
        view_empty_depth(config, 1),
      ])
  }
}

fn view_card_scope_section(config: Config(msg), card: Card) -> Element(msg) {
  view_scope_section(
    "Card scope: " <> card.title,
    view_card_scope(config, card.id),
  )
}

fn has_direct_cards(config: Config(msg), card_id: Int) -> Bool {
  list.any(config.cards, fn(card) { card.parent_card_id == Some(card_id) })
}

fn has_direct_contents(config: Config(msg), card_id: Int) -> Bool {
  let has_cards = has_direct_cards(config, card_id)
  let has_tasks =
    list.any(config.tasks, fn(task) { task.card_id == Some(card_id) })
  has_cards || has_tasks
}

fn view_state_group(
  config: Config(msg),
  label: String,
  state: CardPhase,
) -> Element(msg) {
  let cards =
    visible_cards(config) |> list.filter(fn(card) { card.state == state })
  div([attribute.class("card-tree-state-group")], [
    h4([], [text(label)]),
    view_card_grid(config, cards),
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
        text(depth_label(config.depth_names, card_depth(card, config.cards))),
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
  let name = depth_label(config.depth_names, depth)
  div([attribute.class("card-tree-empty")], [
    h4([], [text("No cards at this level")]),
    span([], [text("Create a card at this level to start filling " <> name)]),
  ])
}

fn visible_cards(config: Config(msg)) -> List(Card) {
  case config.include_closed {
    True -> config.cards
    False -> list.filter(config.cards, fn(card) { card.state != Closed })
  }
}

fn tasks_for_capability(config: Config(msg), capability_id: Int) -> List(Task) {
  config.tasks
  |> list.filter(fn(task) {
    case
      list.find(config.task_types, fn(task_type) {
        task_type.id == task.type_id
      })
    {
      Ok(task_type) -> task_type.capability_id == Some(capability_id)
      Error(_) -> False
    }
  })
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

fn depth_label(depth_names: List(DepthName), depth: Int) -> String {
  case list.find(depth_names, fn(name) { name.depth == depth }) {
    Ok(DepthName(plural_name: plural, ..)) -> plural
    Error(_) -> "Depth " <> int.to_string(depth)
  }
}

fn scope_title(config: Config(msg)) -> String {
  case config.scope {
    DepthScope(depth) -> depth_label(config.depth_names, depth)
    CardScope(_) -> "Card scope"
    TrackingProfile -> "Tracking"
    CoordinationProfile -> "Coordination"
    ExecutionProfile -> "Execution"
  }
}

fn scope_id(scope: Scope) -> String {
  case scope {
    DepthScope(depth) -> "depth:" <> int.to_string(depth)
    CardScope(card_id) -> "card:" <> int.to_string(card_id)
    TrackingProfile -> "profile:tracking"
    CoordinationProfile -> "profile:coordination"
    ExecutionProfile -> "profile:execution"
  }
}
