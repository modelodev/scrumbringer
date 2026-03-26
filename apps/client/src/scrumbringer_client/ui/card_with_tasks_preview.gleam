import domain/card.{type Card}
import domain/org.{type OrgUser}
import domain/task.{type Task, claimed_by}
import domain/task_status.{Available, Claimed, Completed}
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element, none}
import lustre/element/html.{button, div, li, p, span, text, ul}
import lustre/event

import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/theme.{type Theme}
import scrumbringer_client/ui/action_buttons
import scrumbringer_client/ui/card_progress
import scrumbringer_client/ui/card_title_meta
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/task_actions
import scrumbringer_client/ui/task_blocked_badge
import scrumbringer_client/ui/task_item
import scrumbringer_client/ui/task_status_utils
import scrumbringer_client/ui/task_type_icon

pub type Variant {
  Milestone
}

pub type Config(msg) {
  Config(
    locale: Locale,
    theme: Theme,
    card: Card,
    tasks: List(Task),
    org_users: List(OrgUser),
    preview_limit: Int,
    variant: Variant,
    on_card_click: Option(msg),
    on_task_click: fn(Int) -> msg,
    on_task_claim: fn(Int, Int) -> msg,
    footer_actions: List(Element(msg)),
    testid: Option(String),
  )
}

pub fn view(config: Config(msg)) -> Element(msg) {
  let attrs = [attribute.class(root_class(config.variant))]
  let attrs = case config.testid {
    Some(value) -> [attribute.attribute("data-testid", value), ..attrs]
    None -> attrs
  }

  div(attrs, [
    view_header(config),
    view_task_preview(config),
    view_footer(config),
  ])
}

fn view_header(config: Config(msg)) -> Element(msg) {
  let title_children =
    card_title_meta.elements(
      text(config.card.title),
      config.card.color,
      None,
      config.card.has_new_notes,
      i18n.t(config.locale, i18n_text.NewNotesTooltip),
      card_title_meta.ColorTitleNotes,
    )

  let title_element = case config.on_card_click {
    Some(msg) ->
      button(
        [
          attribute.class("card-preview-title"),
          attribute.type_("button"),
          event.on_click(msg),
        ],
        title_children,
      )
    None -> div([attribute.class("card-preview-title")], title_children)
  }

  div([attribute.class("card-preview-header")], [
    title_element,
    card_progress.view(
      config.card.completed_count,
      config.card.task_count,
      card_progress.Compact,
    ),
  ])
}

fn view_task_preview(config: Config(msg)) -> Element(msg) {
  case config.tasks {
    [] ->
      p([attribute.class("card-preview-empty")], [
        text(i18n.t(config.locale, i18n_text.NoTasksYet)),
      ])

    tasks -> {
      let preview = list.take(tasks, config.preview_limit)
      let hidden_count = list.length(tasks) - list.length(preview)

      div([attribute.class("card-preview-body")], [
        ul(
          [attribute.class("card-preview-tasks")],
          list.map(preview, fn(task) {
            li([attribute.class("card-preview-task-row")], [
              view_task(config, task),
            ])
          }),
        ),
        case hidden_count > 0 {
          True ->
            p([attribute.class("card-preview-overflow")], [
              text(i18n.t(config.locale, i18n_text.CardTasksMore(hidden_count))),
            ])
          False -> none()
        },
      ])
    }
  }
}

fn view_task(config: Config(msg), task: Task) -> Element(msg) {
  let status_display = case task.status {
    Claimed(_) -> {
      let claimed_email = case claimed_by(task) {
        Some(user_id) ->
          list.find(config.org_users, fn(user) { user.id == user_id })
          |> option.from_result
          |> option.map(fn(user) { user.email })
          |> option.unwrap(i18n.t(config.locale, i18n_text.UnknownUser))
        None -> i18n.t(config.locale, i18n_text.UnknownUser)
      }
      let status_icon = task_status_utils.claimed_icon(task.status)
      span([attribute.class("task-claimed-by")], [
        text(i18n.t(config.locale, i18n_text.ClaimedBy) <> " " <> claimed_email),
        span([attribute.class("task-claimed-icon")], [
          icons.nav_icon(status_icon, icons.XSmall),
        ]),
      ])
    }
    Available ->
      span([attribute.class("task-status-muted")], [
        text(task_status_utils.label(config.locale, task.status)),
      ])
    Completed ->
      span([attribute.class("task-status")], [
        text(task_status_utils.label(config.locale, task.status)),
      ])
  }

  let actions = case task.status {
    Available ->
      task_item.single_action(task_actions.claim_icon(
        i18n.t(config.locale, i18n_text.ClaimThisTask),
        config.on_task_claim(task.id, task.version),
        action_buttons.SizeXs,
        False,
        "btn-claim",
        None,
        Some("task-claim-btn"),
      ))
    _ -> task_item.no_actions()
  }

  let blocked_class = case task.blocked_count > 0 {
    True -> " task-blocked"
    False -> ""
  }

  let secondary =
    div([attribute.class("task-item-meta")], [
      status_display,
      task_blocked_badge.view(config.locale, task, "task-blocked-inline"),
    ])

  task_item.view(
    task_item.Config(
      container_class: "task-item card-preview-task" <> blocked_class,
      content_class: "task-item-content",
      on_click: Some(config.on_task_click(task.id)),
      icon: Some(task_type_icon.view(task.task_type.icon, 14, config.theme)),
      icon_class: None,
      title: task.title,
      title_class: None,
      secondary: secondary,
      actions: actions,
      reserve_actions_slot: True,
      action_slot_class: None,
      testid: Some("card-preview-task-item"),
    ),
    task_item.Div,
  )
}

fn view_footer(config: Config(msg)) -> Element(msg) {
  case config.footer_actions {
    [] -> none()
    actions -> div([attribute.class("card-preview-footer")], actions)
  }
}

fn root_class(variant: Variant) -> String {
  case variant {
    Milestone -> "card-preview card-preview-milestone"
  }
}
