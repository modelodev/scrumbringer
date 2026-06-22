import gleam/int
import gleam/option.{type Option}
import gleam/order
import gleam/string

import domain/card.{type CardColor}
import domain/note/entity.{type Note}
import domain/task as domain_task
import domain/task_state
import domain/task_status.{Claimed}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, span, text}
import lustre/event

import scrumbringer_client/features/pool/labels as pool_labels
import scrumbringer_client/features/pool/task_hover
import scrumbringer_client/features/pool/urgency
import scrumbringer_client/features/tasks/claimability
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/theme.{type Theme}
import scrumbringer_client/ui/action_buttons
import scrumbringer_client/ui/event_decoders
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/task_actions
import scrumbringer_client/ui/task_blocked_badge
import scrumbringer_client/ui/task_color
import scrumbringer_client/ui/task_state as task_state_ui
import scrumbringer_client/ui/task_type_icon

pub type Config(msg) {
  Config(
    locale: Locale,
    theme: Theme,
    task: domain_task.Task,
    current_user_id: Option(Int),
    card_title: Option(String),
    card_color: Option(CardColor),
    x: Int,
    y: Int,
    age_days: Int,
    project_today: String,
    highlight_class: String,
    touch_preview: Bool,
    disable_actions: Bool,
    hidden_blocked_count: Option(Int),
    notes: List(Note),
    on_claim: msg,
    on_release: msg,
    on_complete: msg,
    on_open: msg,
    on_hover_opened: msg,
    on_hover_closed: msg,
    on_focused: msg,
    on_blurred: msg,
    on_drag_started: fn(Int, Int) -> msg,
    on_touch_started: fn(Int, Int) -> msg,
    on_touch_ended: msg,
  )
}

pub fn view(config: Config(msg)) -> Element(msg) {
  let domain_task.Task(id: id, task_type: task_type, title: title, ..) =
    config.task
  let status = domain_task.status(config.task)

  let is_mine =
    task_state.claimed_by(config.task.state) == config.current_user_id
  let card_classes =
    card_classes(
      config.card_color,
      config.x,
      config.age_days,
      config.task.due_date,
      config.project_today,
      config.task.blocked_count,
      config.highlight_class,
      config.touch_preview,
    )
  let style = card_style(config.x, config.y)
  let top_left_action = top_left_action(config.locale, status, is_mine, config)
  let claim_action = claim_action(config.locale, config)
  let drag_handle = drag_handle(config.locale, config.on_drag_started)
  let complete_action = complete_action(config.locale, is_mine, config)

  div(
    [
      attribute.class(card_classes),
      attribute.attribute("style", style),
      attribute.id("task-card-" <> int.to_string(id)),
      attribute.attribute(
        "aria-describedby",
        "task-preview-" <> int.to_string(id),
      ),
      attribute.attribute("aria-label", task_accessible_label(config)),
      attribute.attribute("title", task_accessible_label(config)),
      attribute.attribute("tabindex", "0"),
      event.on("mouseenter", event_decoders.message(config.on_hover_opened)),
      event.on("mouseleave", event_decoders.message(config.on_hover_closed)),
      event.on("focus", event_decoders.message(config.on_focused)),
      event.on("blur", event_decoders.message(config.on_blurred)),
      event.on(
        "touchstart",
        event_decoders.touch_client_position(config.on_touch_started),
      ),
      event.on("touchend", event_decoders.message(config.on_touch_ended)),
      event.on("touchcancel", event_decoders.message(config.on_touch_ended)),
    ],
    [
      div([attribute.class("task-card-top")], [
        div([attribute.class("task-card-actions-left")], [
          claim_action,
          due_signal(config),
          automation_origin_signal(config.task.automation_origin),
          top_left_action,
        ]),
        div([attribute.class("task-card-actions-right")], [
          drag_handle,
          complete_action,
        ]),
      ]),
      div([attribute.class("task-card-body")], [
        button(
          [
            attribute.class("task-card-open-action"),
            attribute.attribute("type", "button"),
            attribute.attribute(
              "aria-label",
              pool_labels.open_task(config.locale) <> ": " <> title,
            ),
            event.on_click(config.on_open),
          ],
          [
            span([attribute.class("task-card-center")], [
              span([attribute.class("task-card-center-icon")], [
                task_type_icon.view(task_type.icon, 22, config.theme),
              ]),
              span(
                [
                  attribute.class("task-card-title"),
                  attribute.attribute("title", title),
                ],
                [text(title)],
              ),
              mobile_context(config),
            ]),
          ],
        ),
      ]),
      div(
        [
          attribute.attribute("id", "task-preview-" <> int.to_string(id)),
          attribute.attribute(
            "aria-describedby",
            "task-preview-" <> int.to_string(id),
          ),
        ],
        [
          task_hover.view(task_hover.Config(
            locale: config.locale,
            task: config.task,
            card_title: config.card_title,
            age_days: config.age_days,
            hidden_blocked_count: config.hidden_blocked_count,
            notes: config.notes,
            current_user_id: config.current_user_id,
            on_open: config.on_open,
          )),
        ],
      ),
    ],
  )
}

fn mobile_context(config: Config(msg)) -> Element(msg) {
  span([attribute.class("task-card-mobile-context")], [
    card_context(config.card_title),
    span([attribute.class("task-card-mobile-age")], [
      text(pool_labels.created_ago_days(config.locale, config.age_days)),
    ]),
    description_context(config.task.description),
  ])
}

fn task_accessible_label(config: Config(msg)) -> String {
  let base = config.task.title
  let with_blocked = case config.task.blocked_count > 0 {
    True ->
      base
      <> ". "
      <> pool_labels.blocked_by_tasks(config.locale, config.task.blocked_count)
    False -> base
  }

  case due_label(config) {
    option.Some(label) -> with_blocked <> ". " <> label
    option.None -> with_blocked
  }
}

fn due_signal(config: Config(msg)) -> Element(msg) {
  case due_label(config) {
    option.Some(label) ->
      span(
        [
          attribute.class(
            "task-card-signal task-card-signal-due " <> due_class(config),
          ),
          attribute.attribute("data-testid", "task-card-signal-due"),
          attribute.attribute("title", label),
          attribute.attribute("aria-label", label),
        ],
        [icons.nav_icon(icons.Calendar, icons.XSmall)],
      )
    option.None -> element.none()
  }
}

fn automation_origin_signal(
  origin: Option(domain_task.AutomationOrigin),
) -> Element(msg) {
  case origin {
    option.Some(domain_task.AutomationOrigin(rule_id: rule_id, ..)) -> {
      let label = "Created by automation rule #" <> int.to_string(rule_id)
      span(
        [
          attribute.class("task-card-signal task-card-signal-automation"),
          attribute.attribute("data-testid", "automation-created-task-origin"),
          attribute.attribute("title", label),
          attribute.attribute("aria-label", label),
        ],
        [icons.nav_icon(icons.Automation, icons.XSmall)],
      )
    }
    option.None -> element.none()
  }
}

fn due_label(config: Config(msg)) -> Option(String) {
  case config.task.due_date {
    option.Some(due_date) ->
      case string.compare(due_date, config.project_today) {
        order.Lt ->
          option.Some(pool_labels.task_overdue(config.locale, due_date))
        order.Eq -> option.Some(pool_labels.task_due_today(config.locale))
        order.Gt ->
          option.Some(pool_labels.task_due_soon(config.locale, due_date))
      }
    option.None -> option.None
  }
}

fn due_class(config: Config(msg)) -> String {
  case config.task.due_date {
    option.Some(due_date) ->
      case string.compare(due_date, config.project_today) {
        order.Lt -> "is-overdue"
        order.Eq -> "is-due-today"
        order.Gt -> "is-due-soon"
      }
    option.None -> ""
  }
}

fn card_context(card_title: Option(String)) -> Element(msg) {
  case card_title {
    option.Some(title) ->
      case string.trim(title) {
        "" -> element.none()
        _ ->
          span(
            [
              attribute.class("task-card-mobile-card"),
              attribute.attribute("title", title),
            ],
            [text(title)],
          )
      }
    _ -> element.none()
  }
}

fn description_context(description: Option(String)) -> Element(msg) {
  case description {
    option.Some(value) ->
      case string.trim(value) {
        "" -> element.none()
        _ ->
          span(
            [
              attribute.class("task-card-mobile-description"),
              attribute.attribute("title", value),
            ],
            [text(value)],
          )
      }
    _ -> element.none()
  }
}

fn top_left_action(
  locale: Locale,
  status,
  is_mine: Bool,
  config: Config(msg),
) -> Element(msg) {
  case status, is_mine {
    Claimed(_), True ->
      task_actions.release_icon(
        task_state_ui.release_action(locale),
        config.on_release,
        action_buttons.SizeXs,
        config.disable_actions,
        "",
        option.None,
        option.None,
      )

    _, _ -> element.none()
  }
}

fn claim_action(locale: Locale, config: Config(msg)) -> Element(msg) {
  case claimability.can_claim(config.task), config.task.blocked_count > 0 {
    True, _ -> claim_primary_action(locale, config)
    False, True -> claim_blocked_action(locale, config)
    False, False -> element.none()
  }
}

fn claim_blocked_action(locale: Locale, config: Config(msg)) -> Element(msg) {
  task_actions.claim_icon_blocked(
    task_blocked_badge.tooltip_text(locale, config.task),
    config.on_claim,
    action_buttons.SizeXs,
    "task-card-primary-action task-card-primary-action-blocked",
    option.None,
  )
}

fn claim_primary_action(locale: Locale, config: Config(msg)) -> Element(msg) {
  let descriptive_label =
    task_state_ui.next_action(locale, domain_task.status(config.task))

  task_actions.claim_icon(
    descriptive_label,
    config.on_claim,
    action_buttons.SizeXs,
    config.disable_actions,
    "task-card-primary-action",
    option.None,
    option.None,
  )
}

fn drag_handle(
  locale: Locale,
  on_drag_started: fn(Int, Int) -> msg,
) -> Element(msg) {
  button(
    [
      attribute.class("btn-xs btn-icon secondary-action drag-handle"),
      attribute.attribute("title", pool_labels.drag(locale)),
      attribute.attribute("aria-label", pool_labels.drag(locale)),
      attribute.attribute("type", "button"),
      event.on(
        "mousedown",
        event_decoders.mouse_client_position(on_drag_started),
      ),
    ],
    [icons.nav_icon(icons.DragHandle, icons.Small)],
  )
}

fn complete_action(
  locale: Locale,
  is_mine: Bool,
  config: Config(msg),
) -> Element(msg) {
  case domain_task.status(config.task), is_mine {
    Claimed(_), True ->
      task_actions.complete_icon(
        task_state_ui.complete_action(locale),
        config.on_complete,
        action_buttons.SizeXs,
        config.disable_actions,
        "secondary-action",
        option.None,
        option.None,
      )

    _, _ -> element.none()
  }
}

fn card_classes(
  card_color: Option(CardColor),
  x: Int,
  age_days: Int,
  due_date: Option(String),
  project_today: String,
  blocked_count: Int,
  highlight_class: String,
  touch_preview: Bool,
) -> String {
  let base_classes = case x > 760 {
    True -> "task-card preview-left"
    False -> "task-card"
  }
  let with_border = case task_color.card_border_class(card_color) {
    "" -> base_classes
    border_class -> base_classes <> " " <> border_class
  }
  let with_decay = case urgency.shake_class(age_days, due_date, project_today) {
    "" -> with_border
    shake_class -> with_border <> " " <> shake_class
  }
  let with_blocked = case blocked_count > 0 {
    True -> with_decay <> " task-blocked"
    False -> with_decay
  }
  let with_highlight = with_blocked <> highlight_class
  case touch_preview {
    True -> with_highlight <> " touch-preview"
    False -> with_highlight
  }
}

fn card_style(x: Int, y: Int) -> String {
  let size = 128
  let size_str = int.to_string(size)
  "position:absolute; left:max(0px,"
  <> int.to_string(x)
  <> "px); top:max(0px,"
  <> int.to_string(y)
  <> "px); width:"
  <> size_str
  <> "px; height:"
  <> size_str
  <> "px;"
}
