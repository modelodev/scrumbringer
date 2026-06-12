//// Pool task row view.

import gleam/option as opt

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div}

import domain/card.{type CardColor}
import domain/task.{type Task, Task}

import scrumbringer_client/features/pool/labels as pool_labels
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/theme.{type Theme}
import scrumbringer_client/ui/action_buttons
import scrumbringer_client/ui/task_actions
import scrumbringer_client/ui/task_blocked_badge
import scrumbringer_client/ui/task_color
import scrumbringer_client/ui/task_item
import scrumbringer_client/ui/task_type_icon

pub type Config(msg) {
  Config(
    locale: Locale,
    theme: Theme,
    task: Task,
    card_color: opt.Option(CardColor),
    highlight_class: String,
    disable_actions: Bool,
    on_claim: msg,
    on_open: msg,
  )
}

pub fn view(config: Config(msg)) -> Element(msg) {
  let Task(title: title, task_type: task_type, blocked_count: blocked_count, ..) =
    config.task

  let claim_actions = case blocked_count > 0 {
    True -> []
    False ->
      task_actions.claim_only(
        pool_labels.claim_this_task(config.locale),
        config.on_claim,
        action_buttons.SizeXs,
        config.disable_actions,
        "",
        opt.None,
        opt.None,
      )
  }

  let border_class = task_color.card_border_class(config.card_color)
  let blocked_class = case config.task.blocked_count > 0 {
    True -> " task-blocked"
    False -> ""
  }

  task_item.view(
    task_item.Config(
      container_class: "task-row "
        <> border_class
        <> blocked_class
        <> config.highlight_class,
      content_class: "task-row-title",
      leading: opt.None,
      on_click: opt.Some(config.on_open),
      content_title: opt.None,
      content_label: opt.None,
      icon: opt.Some(task_type_icon.view(task_type.icon, 16, config.theme)),
      icon_class: opt.None,
      title: title,
      title_class: opt.None,
      secondary: div([attribute.class("task-row-meta")], [
        task_blocked_badge.view(
          config.locale,
          config.task,
          "task-blocked-inline",
        ),
      ]),
      actions: [div([attribute.class("task-row-actions")], claim_actions)],
      reserve_actions_slot: False,
      action_slot_class: opt.None,
      testid: opt.None,
    ),
    task_item.Div,
  )
}
