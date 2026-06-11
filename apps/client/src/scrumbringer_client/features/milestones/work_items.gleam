import domain/card.{type Card, Card}
import domain/milestone.{type Milestone}
import domain/org.{type OrgUser}
import domain/task.{type Task, Task}
import domain/task_status.{type TaskStatus}
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option
import lustre/attribute.{type Attribute}
import lustre/element.{type Element, none}
import lustre/element/html.{div, p, span, text}
import lustre/element/keyed
import lustre/event

import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/theme.{type Theme}
import scrumbringer_client/ui/card_progress
import scrumbringer_client/ui/color_picker
import scrumbringer_client/ui/move_menu
import scrumbringer_client/ui/task_blocked_badge
import scrumbringer_client/ui/task_item
import scrumbringer_client/ui/task_type_icon

pub type Config(msg) {
  Config(
    locale: Locale,
    theme: Theme,
    milestone_id: Int,
    cards: List(Card),
    loose_tasks: List(Task),
    org_users: List(OrgUser),
    tasks_for_card: fn(Int) -> List(Task),
    destinations: List(Milestone),
    can_move: Bool,
    can_drag: Bool,
    card_header_actions: fn(Card) -> List(Element(msg)),
    on_task_open: fn(Int) -> msg,
    on_task_claim: fn(Int, Int) -> msg,
    on_card_drag_started: fn(Int) -> msg,
    on_task_drag_started: fn(Int) -> msg,
    on_drag_ended: msg,
    on_card_move: fn(Int, Int) -> msg,
    on_task_move: fn(Int, Int) -> msg,
    task_status_label: fn(TaskStatus) -> String,
  )
}

pub fn view_cards_section(config: Config(msg)) -> Element(msg) {
  case config.cards {
    [] -> none()
    cards ->
      div([attribute.class("milestone-content-section detail-section")], [
        p([attribute.class("milestone-subsection-title detail-section-title")], [
          text(i18n.t(config.locale, i18n_text.MilestoneCardsLabel)),
        ]),
        keyed.div(
          [attribute.class("milestone-cards-list")],
          list.map(cards, fn(card) {
            let Card(id: card_id, ..) = card
            #(int.to_string(card_id), view_card_row(config, card, card_id))
          }),
        ),
      ])
  }
}

pub fn view_loose_tasks_panel(config: Config(msg)) -> Element(msg) {
  case config.loose_tasks {
    [] -> none()
    _ ->
      div([attribute.class("milestone-loose-tasks-panel")], [
        div([attribute.class("milestone-content-note")], [
          p([attribute.class("milestone-subsection-title")], [
            text(i18n.t(config.locale, i18n_text.MilestoneLooseTasksNotice)),
          ]),
          p([attribute.class("milestone-item-description")], [
            text(i18n.t(config.locale, i18n_text.MilestoneLooseTasksHint)),
          ]),
        ]),
        view_loose_tasks_section(config),
      ])
  }
}

fn view_card_row(config: Config(msg), card: Card, card_id: Int) -> Element(msg) {
  let row_testid =
    "milestone-card-row:"
    <> int.to_string(config.milestone_id)
    <> ":"
    <> int.to_string(card_id)
  let card_tasks = config.tasks_for_card(card_id)
  let actions = case config.can_move {
    True ->
      list.append(config.card_header_actions(card), [
        view_move_card_actions(config, card_id),
      ])
    False -> config.card_header_actions(card)
  }

  let attrs = [
    attribute.class("milestone-card-wrapper"),
    attribute.attribute("data-testid", row_testid),
  ]

  div(
    list.append(
      attrs,
      drag_attrs(config.can_drag, config.on_card_drag_started(card_id), config),
    ),
    [view_delivery_card_row(config, card, card_tasks, actions)],
  )
}

fn view_delivery_card_row(
  config: Config(msg),
  card: Card,
  tasks: List(Task),
  actions: List(Element(msg)),
) -> Element(msg) {
  div(
    [
      attribute.class("milestone-delivery-card"),
      attribute.attribute("data-testid", "milestone-delivery-card"),
    ],
    [
      span(
        [
          attribute.class(
            "milestone-card-swatch " <> color_picker.border_class(card.color),
          ),
          attribute.attribute("aria-hidden", "true"),
        ],
        [],
      ),
      div([attribute.class("milestone-delivery-card-main")], [
        div([attribute.class("milestone-delivery-card-title-row")], [
          span([attribute.class("milestone-delivery-card-title")], [
            text(card.title),
          ]),
          div(
            [attribute.class("milestone-card-status-items")],
            view_structural_status(config, card, tasks),
          ),
        ]),
        div([attribute.class("milestone-delivery-card-progress")], [
          card_progress.view(
            card.completed_count,
            card.task_count,
            card_progress.Compact,
          ),
        ]),
      ]),
      view_card_actions(actions),
    ],
  )
}

fn view_structural_status(
  config: Config(msg),
  card: Card,
  tasks: List(Task),
) -> List(Element(msg)) {
  let blocked_count = list.count(tasks, fn(task) { task.blocked_count > 0 })

  case
    card.task_count == 0,
    blocked_count > 0,
    card.completed_count >= card.task_count,
    card.completed_count == 0
  {
    True, _, _, _ -> [
      view_status_chip(
        i18n.t(config.locale, i18n_text.MilestoneCardEmpty),
        "empty",
      ),
    ]
    _, True, _, _ -> [
      view_status_chip(
        i18n.t(config.locale, i18n_text.MilestoneCardBlocked),
        "blocked",
      ),
    ]
    _, _, True, _ -> [
      view_status_chip(
        i18n.t(config.locale, i18n_text.MilestoneCardComplete),
        "complete",
      ),
    ]
    _, _, _, True -> [
      view_status_chip(
        i18n.t(config.locale, i18n_text.MilestoneCardNoProgress),
        "no-progress",
      ),
    ]
    _, _, _, _ -> []
  }
}

fn view_status_chip(label: String, tone: String) -> Element(msg) {
  span(
    [
      attribute.class("milestone-card-status-chip " <> tone),
      attribute.attribute("data-testid", "milestone-card-status-chip"),
    ],
    [text(label)],
  )
}

fn view_card_actions(actions: List(Element(msg))) -> Element(msg) {
  case actions {
    [] -> none()
    _ -> div([attribute.class("milestone-card-actions")], actions)
  }
}

fn view_loose_tasks_section(config: Config(msg)) -> Element(msg) {
  div([attribute.class("milestone-content-section detail-section")], [
    p([attribute.class("milestone-subsection-title detail-section-title")], [
      text(i18n.t(config.locale, i18n_text.MilestoneTasksLabel)),
    ]),
    keyed.div(
      [attribute.class("milestone-cards-list")],
      list.map(config.loose_tasks, fn(task) {
        let Task(id: task_id, ..) = task
        #(int.to_string(task_id), view_loose_task_row(config, task, task_id))
      }),
    ),
  ])
}

fn view_loose_task_row(
  config: Config(msg),
  task: Task,
  task_id: Int,
) -> Element(msg) {
  let Task(title: title, status: status, ..) = task

  let attrs = [
    attribute.class("milestone-task-row detail-item-row"),
    attribute.attribute(
      "data-testid",
      "milestone-task-row:"
        <> int.to_string(config.milestone_id)
        <> ":"
        <> int.to_string(task_id),
    ),
  ]

  let secondary =
    div([attribute.class("task-item-meta milestone-task-meta")], [
      span([attribute.class("milestone-task-status")], [
        text(config.task_status_label(status)),
      ]),
      task_blocked_badge.view(config.locale, task, "task-blocked-inline"),
    ])

  let actions = case config.can_move {
    True -> [view_move_task_actions(config, task_id)]
    False -> task_item.no_actions()
  }

  div(
    list.append(
      attrs,
      drag_attrs(config.can_drag, config.on_task_drag_started(task_id), config),
    ),
    [
      task_item.view(
        task_item.Config(
          container_class: "task-item milestone-task-item",
          content_class: "task-item-content milestone-task-content",
          leading: option.None,
          on_click: option.Some(config.on_task_open(task_id)),
          icon: option.Some(task_type_icon.view(
            task.task_type.icon,
            14,
            config.theme,
          )),
          icon_class: option.None,
          title: title,
          title_class: option.Some("milestone-card-title"),
          secondary: secondary,
          actions: actions,
          reserve_actions_slot: config.can_move,
          action_slot_class: option.Some("milestone-task-action-slot"),
          testid: option.None,
        ),
        task_item.Div,
      ),
    ],
  )
}

fn view_move_card_actions(config: Config(msg), card_id: Int) -> Element(msg) {
  move_menu.view(
    i18n.t(config.locale, i18n_text.MilestoneMoveTo),
    "milestone-move-menu-card:"
      <> int.to_string(config.milestone_id)
      <> ":"
      <> int.to_string(card_id),
    list.map(config.destinations, fn(dest) {
      move_menu.option(
        dest.name,
        "milestone-move-card:"
          <> int.to_string(config.milestone_id)
          <> ":"
          <> int.to_string(card_id)
          <> ":"
          <> int.to_string(dest.id),
        config.on_card_move(card_id, dest.id),
      )
    }),
  )
}

fn view_move_task_actions(config: Config(msg), task_id: Int) -> Element(msg) {
  move_menu.view(
    i18n.t(config.locale, i18n_text.MilestoneMoveTo),
    "milestone-move-menu-task:"
      <> int.to_string(config.milestone_id)
      <> ":"
      <> int.to_string(task_id),
    list.map(config.destinations, fn(dest) {
      move_menu.option(
        dest.name,
        "milestone-move-task:"
          <> int.to_string(config.milestone_id)
          <> ":"
          <> int.to_string(task_id)
          <> ":"
          <> int.to_string(dest.id),
        config.on_task_move(task_id, dest.id),
      )
    }),
  )
}

fn drag_attrs(
  can_drag: Bool,
  on_drag_started: msg,
  config: Config(msg),
) -> List(Attribute(msg)) {
  case can_drag {
    True -> [
      attribute.attribute("draggable", "true"),
      event.on("dragstart", decode.success(on_drag_started)),
      event.on("dragend", decode.success(config.on_drag_ended)),
    ]
    False -> []
  }
}
