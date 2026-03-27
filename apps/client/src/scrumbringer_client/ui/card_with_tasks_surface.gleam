import domain/card.{type Card}
import domain/org.{type OrgUser}
import domain/task.{type Task, claimed_by}
import domain/task_status.{Available, Claimed, Completed}
import gleam/list
import gleam/option
import gleam/string
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
import scrumbringer_client/ui/task_color
import scrumbringer_client/ui/task_item
import scrumbringer_client/ui/task_status_utils
import scrumbringer_client/ui/task_type_icon
import scrumbringer_client/utils/text as text_utils

pub type SurfaceVariant {
  Milestone
  Kanban
}

pub type TaskDensity {
  Comfortable
  Compact
}

pub type Config(msg) {
  Config(
    locale: Locale,
    theme: Theme,
    card: Card,
    tasks: List(Task),
    org_users: List(OrgUser),
    preview_limit: Int,
    surface_variant: SurfaceVariant,
    task_density: TaskDensity,
    progress_completed: Int,
    progress_total: Int,
    description: option.Option(String),
    on_card_click: option.Option(msg),
    on_task_click: fn(Int) -> msg,
    on_task_claim: fn(Int, Int) -> msg,
    header_actions: List(Element(msg)),
    footer_actions: List(Element(msg)),
    root_attributes: List(attribute.Attribute(msg)),
    task_item_testid: option.Option(String),
  )
}

pub fn view(config: Config(msg)) -> Element(msg) {
  let attrs = [
    attribute.class(root_class(config.surface_variant)),
    ..config.root_attributes
  ]

  div(attrs, [
    view_header(config),
    view_description(config),
    view_progress(config),
    view_task_preview(config),
    view_footer(config),
  ])
}

fn view_header(config: Config(msg)) -> Element(msg) {
  div([attribute.class(header_class(config.surface_variant))], [
    div([attribute.class("card-surface-title-row")], [
      view_title(config),
      view_header_actions(config),
    ]),
  ])
}

fn view_title(config: Config(msg)) -> Element(msg) {
  let title_children =
    card_title_meta.elements(
      text(config.card.title),
      config.card.color,
      option.None,
      config.card.has_new_notes,
      i18n.t(config.locale, i18n_text.NewNotesTooltip),
      card_title_meta.ColorTitleNotes,
    )

  case config.on_card_click {
    option.Some(msg) ->
      button(
        [
          attribute.class(title_class(config.surface_variant)),
          attribute.type_("button"),
          event.on_click(msg),
        ],
        title_children,
      )
    option.None ->
      div(
        [attribute.class(title_class(config.surface_variant))],
        title_children,
      )
  }
}

fn view_header_actions(config: Config(msg)) -> Element(msg) {
  case config.header_actions {
    [] -> none()
    actions -> div([attribute.class("card-surface-header-actions")], actions)
  }
}

fn view_description(config: Config(msg)) -> Element(msg) {
  case config.description {
    option.Some(description) ->
      case string.trim(description) != "" {
        True ->
          div([attribute.class(description_class(config.surface_variant))], [
            text(description_for_density(config.task_density, description)),
          ])
        False -> none()
      }
    option.None -> none()
  }
}

fn view_progress(config: Config(msg)) -> Element(msg) {
  let variant = case config.task_density {
    Comfortable -> card_progress.Compact
    Compact -> card_progress.Default
  }

  div([attribute.class(progress_class(config.surface_variant))], [
    card_progress.view(
      config.progress_completed,
      config.progress_total,
      variant,
    ),
  ])
}

fn view_task_preview(config: Config(msg)) -> Element(msg) {
  case config.tasks {
    [] ->
      p([attribute.class("card-surface-empty")], [
        text(i18n.t(config.locale, i18n_text.NoTasksYet)),
      ])

    tasks -> {
      let preview = list.take(tasks, config.preview_limit)
      let hidden_count = list.length(tasks) - list.length(preview)

      div([attribute.class(body_class(config.surface_variant))], [
        ul(
          [attribute.class(task_list_class(config.task_density))],
          list.map(preview, fn(task) {
            li([attribute.class("card-surface-task-row")], [
              view_task(config, task),
            ])
          }),
        ),
        case hidden_count > 0 {
          True ->
            p([attribute.class("card-surface-overflow")], [
              text(i18n.t(config.locale, i18n_text.CardTasksMore(hidden_count))),
            ])
          False -> none()
        },
      ])
    }
  }
}

fn view_task(config: Config(msg), task: Task) -> Element(msg) {
  let blocked_class = case task.blocked_count > 0 {
    True -> " task-blocked"
    False -> ""
  }

  let secondary =
    div([attribute.class("task-item-meta")], [
      status_display(config, task),
      task_blocked_badge.view(config.locale, task, "task-blocked-inline"),
    ])

  task_item.view(
    task_item.Config(
      container_class: task_container_class(config, task) <> blocked_class,
      content_class: task_content_class(config.task_density),
      on_click: option.Some(config.on_task_click(task.id)),
      icon: option.Some(task_type_icon.view(
        task.task_type.icon,
        14,
        config.theme,
      )),
      icon_class: option.None,
      title: task_title_for_density(config.task_density, task.title),
      title_class: option.None,
      secondary: secondary,
      actions: task_actions_for(config, task),
      reserve_actions_slot: True,
      action_slot_class: action_slot_class(config.task_density),
      testid: config.task_item_testid,
    ),
    task_item.Div,
  )
}

fn status_display(config: Config(msg), task: Task) -> Element(msg) {
  case config.task_density, task.status {
    Compact, Claimed(_) ->
      span([attribute.class("task-claimed-by")], [
        text(compact_claimed_name(config, task)),
      ])
    Comfortable, Claimed(_) -> {
      let status_icon = task_status_utils.claimed_icon(task.status)
      span([attribute.class("task-claimed-by")], [
        text(
          i18n.t(config.locale, i18n_text.ClaimedBy)
          <> " "
          <> comfortable_claimed_name(config, task),
        ),
        span([attribute.class("task-claimed-icon")], [
          icons.nav_icon(status_icon, icons.XSmall),
        ]),
      ])
    }
    _, Available ->
      span([attribute.class("task-status-muted")], [
        text(task_status_utils.label(config.locale, task.status)),
      ])
    _, Completed ->
      span([attribute.class("task-status")], [
        text(task_status_utils.label(config.locale, task.status)),
      ])
  }
}

fn compact_claimed_name(config: Config(msg), task: Task) -> String {
  case claimed_email(config, task) {
    option.Some(email) -> truncate_email(email)
    option.None -> "?"
  }
}

fn comfortable_claimed_name(config: Config(msg), task: Task) -> String {
  claimed_email(config, task)
  |> option.unwrap(i18n.t(config.locale, i18n_text.UnknownUser))
}

fn claimed_email(config: Config(msg), task: Task) -> option.Option(String) {
  case claimed_by(task) {
    option.Some(user_id) ->
      list.find(config.org_users, fn(user) { user.id == user_id })
      |> option.from_result
      |> option.map(fn(user) { user.email })
    option.None -> option.None
  }
}

fn task_actions_for(config: Config(msg), task: Task) -> List(Element(msg)) {
  case config.task_density, task.status {
    Compact, Available ->
      task_item.single_action(task_actions.claim_icon_with_class(
        i18n.t(config.locale, i18n_text.Claim),
        config.on_task_claim(task.id, task.version),
        icons.XSmall,
        False,
        "btn-claim-mini",
        option.None,
        option.None,
      ))
    Comfortable, Available ->
      task_item.single_action(task_actions.claim_icon(
        i18n.t(config.locale, i18n_text.ClaimThisTask),
        config.on_task_claim(task.id, task.version),
        action_buttons.SizeXs,
        False,
        "btn-claim",
        option.None,
        option.Some("task-claim-btn"),
      ))
    _, _ -> task_item.no_actions()
  }
}

fn task_container_class(config: Config(msg), task: Task) -> String {
  case config.task_density {
    Compact -> {
      let border_class =
        task.card_color
        |> option.or(config.card.color)
        |> task_color.card_border_class

      "task-item kanban-task-item card-surface-task card-surface-task-compact "
      <> border_class
    }
    Comfortable -> "task-item card-preview-task card-surface-task"
  }
}

fn task_content_class(density: TaskDensity) -> String {
  case density {
    Compact -> "task-item-content kanban-task-content"
    Comfortable -> "task-item-content"
  }
}

fn action_slot_class(density: TaskDensity) -> option.Option(String) {
  case density {
    Compact -> option.Some("task-item-action-slot-compact")
    Comfortable -> option.None
  }
}

fn task_title_for_density(density: TaskDensity, title: String) -> String {
  case density {
    Compact -> text_utils.truncate(title, 25)
    Comfortable -> title
  }
}

fn description_for_density(density: TaskDensity, description: String) -> String {
  case density {
    Compact -> text_utils.truncate(description, 80)
    Comfortable -> description
  }
}

fn truncate_email(email: String) -> String {
  case string.split(email, "@") {
    [local, ..] -> text_utils.truncate(local, 10)
    _ -> text_utils.truncate(email, 10)
  }
}

fn root_class(surface_variant: SurfaceVariant) -> String {
  case surface_variant {
    Milestone -> "card-surface card-preview card-preview-milestone"
    Kanban -> "card-surface kanban-card card-surface-kanban"
  }
}

fn header_class(surface_variant: SurfaceVariant) -> String {
  case surface_variant {
    Milestone -> "card-surface-header card-preview-header"
    Kanban -> "card-surface-header kanban-card-header"
  }
}

fn title_class(surface_variant: SurfaceVariant) -> String {
  case surface_variant {
    Milestone -> "card-surface-title card-preview-title"
    Kanban -> "card-surface-title kanban-card-title"
  }
}

fn description_class(surface_variant: SurfaceVariant) -> String {
  case surface_variant {
    Milestone -> "card-surface-description"
    Kanban -> "card-surface-description kanban-card-desc"
  }
}

fn progress_class(surface_variant: SurfaceVariant) -> String {
  case surface_variant {
    Milestone -> "card-surface-progress card-preview-progress"
    Kanban -> "card-surface-progress kanban-card-progress"
  }
}

fn body_class(surface_variant: SurfaceVariant) -> String {
  case surface_variant {
    Milestone -> "card-surface-body card-preview-body"
    Kanban -> "card-surface-body kanban-card-body"
  }
}

fn task_list_class(density: TaskDensity) -> String {
  case density {
    Comfortable -> "card-surface-task-list card-preview-tasks"
    Compact -> "card-surface-task-list kanban-card-tasks"
  }
}

fn view_footer(config: Config(msg)) -> Element(msg) {
  case config.footer_actions {
    [] -> none()
    actions ->
      div([attribute.class("card-surface-footer card-preview-footer")], actions)
  }
}
