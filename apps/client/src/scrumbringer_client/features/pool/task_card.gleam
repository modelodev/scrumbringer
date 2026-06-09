import gleam/int
import gleam/option.{type Option}

import domain/card.{type CardColor}
import domain/task.{type Task, type TaskNote, Task}
import domain/task_state
import domain/task_status.{Available, Claimed}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, text}
import lustre/event

import scrumbringer_client/features/pool/labels as pool_labels
import scrumbringer_client/features/pool/task_hover
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/theme.{type Theme}
import scrumbringer_client/ui/action_buttons
import scrumbringer_client/ui/event_decoders
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/task_actions
import scrumbringer_client/ui/task_blocked_badge
import scrumbringer_client/ui/task_color
import scrumbringer_client/ui/task_type_icon

pub type Config(msg) {
  Config(
    locale: Locale,
    theme: Theme,
    task: Task,
    current_user_id: Option(Int),
    card_title: Option(String),
    card_color: Option(CardColor),
    x: Int,
    y: Int,
    age_days: Int,
    highlight_class: String,
    touch_preview: Bool,
    disable_actions: Bool,
    hidden_blocked_count: Option(Int),
    notes: List(TaskNote),
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
  let Task(
    id: id,
    task_type: task_type,
    title: title,
    status: status,
    blocked_count: blocked_count,
    ..,
  ) = config.task

  let is_mine =
    task_state.claimed_by(config.task.state) == config.current_user_id
  let card_classes =
    card_classes(
      config.card_color,
      config.x,
      config.age_days,
      config.task.blocked_count,
      config.highlight_class,
      config.touch_preview,
    )
  let style = card_style(config.x, config.y)
  let primary_action =
    primary_action(config.locale, status, blocked_count, is_mine, config)
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
          task_blocked_badge.view(
            config.locale,
            config.task,
            "task-blocked-card",
          ),
          primary_action,
        ]),
        div([attribute.class("task-card-actions-right")], [
          drag_handle,
          complete_action,
        ]),
      ]),
      div([attribute.class("task-card-body")], [
        div([attribute.class("task-card-center")], [
          div([attribute.class("task-card-center-icon")], [
            task_type_icon.view(task_type.icon, 22, config.theme),
          ]),
          div(
            [
              attribute.class("task-card-title"),
              attribute.attribute("title", title),
            ],
            [text(title)],
          ),
        ]),
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

fn primary_action(
  locale: Locale,
  status,
  blocked_count: Int,
  is_mine: Bool,
  config: Config(msg),
) -> Element(msg) {
  case status, is_mine {
    Available, _ if blocked_count > 0 -> element.none()
    Available, _ ->
      task_actions.claim_icon(
        pool_labels.claim(locale),
        config.on_claim,
        action_buttons.SizeXs,
        config.disable_actions,
        "",
        option.None,
        option.None,
      )

    Claimed(_), True ->
      task_actions.release_icon(
        pool_labels.release(locale),
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
  case config.task.status, is_mine {
    Claimed(_), True ->
      task_actions.complete_icon(
        pool_labels.complete(locale),
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
  let with_decay = case decay_to_shake_class(age_days) {
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
  "position:absolute; left:clamp(0px,"
  <> int.to_string(x)
  <> "px,calc(100% - "
  <> size_str
  <> "px)); top:max(0px,"
  <> int.to_string(y)
  <> "px); width:"
  <> size_str
  <> "px; height:"
  <> size_str
  <> "px;"
}

fn decay_to_shake_class(age_days: Int) -> String {
  case age_days {
    d if d < 9 -> ""
    d if d < 18 -> "decay-shake-low"
    d if d < 27 -> "decay-shake-medium"
    _ -> "decay-shake-high"
  }
}
