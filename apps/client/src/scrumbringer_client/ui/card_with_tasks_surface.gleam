import domain/card.{type Card, Closed}
import domain/org.{type OrgUser}
import domain/task.{type Task, claimed_by}
import domain/task_status.{Available, Claimed, Done}
import gleam/list
import gleam/option
import gleam/order
import gleam/string
import lustre/attribute
import lustre/element.{type Element, none}
import lustre/element/html.{button, div, li, p, span, text, ul}
import lustre/event

import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/theme.{type Theme}
import scrumbringer_client/ui/card_progress
import scrumbringer_client/ui/card_title_meta
import scrumbringer_client/ui/color_picker
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/task_actions
import scrumbringer_client/ui/task_blocked_badge
import scrumbringer_client/ui/task_color
import scrumbringer_client/ui/task_item
import scrumbringer_client/ui/task_state as task_state_ui
import scrumbringer_client/ui/task_status_utils
import scrumbringer_client/ui/task_type_icon
import scrumbringer_client/utils/text as text_utils

pub type Config(msg) {
  Config(
    locale: Locale,
    theme: Theme,
    card: Card,
    tasks: List(Task),
    org_users: List(OrgUser),
    preview_limit: Int,
    progress_completed: Int,
    progress_total: Int,
    project_today: String,
    description: option.Option(String),
    status_items: List(Element(msg)),
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
  let attrs = [attribute.class(root_class()), ..config.root_attributes]

  div(attrs, [
    view_header(config),
    view_due_date(config),
    view_description(config),
    view_progress(config),
    view_status_items(config),
    view_task_preview(config),
    view_footer(config),
  ])
}

fn view_header(config: Config(msg)) -> Element(msg) {
  div([attribute.class(header_class())], [
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
      option.map(config.card.color, color_picker.css_var),
      option.None,
      config.card.has_new_notes,
      i18n.t(config.locale, i18n_text.NewNotesTooltip),
      card_title_meta.ColorTitleNotes,
    )

  case config.on_card_click {
    option.Some(msg) ->
      button(
        [
          attribute.class(title_class()),
          attribute.type_("button"),
          event.on_click(msg),
        ],
        title_children,
      )
    option.None -> div([attribute.class(title_class())], title_children)
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
          div([attribute.class(description_class())], [
            text(description_for_card(description)),
          ])
        False -> none()
      }
    option.None -> none()
  }
}

fn view_due_date(config: Config(msg)) -> Element(msg) {
  case config.card.due_date {
    option.Some(due_date) ->
      div(
        [
          attribute.class(due_date_class(
            config.card.state,
            due_date,
            config.project_today,
          )),
          attribute.attribute("title", due_date),
        ],
        [text(due_date)],
      )
    option.None -> none()
  }
}

fn due_date_class(card_state, due_date: String, project_today: String) -> String {
  let base = "card-due-date"
  case
    card_state != Closed && string.compare(due_date, project_today) == order.Lt
  {
    True -> base <> " card-due-date-overdue"
    False -> base
  }
}

fn view_progress(config: Config(msg)) -> Element(msg) {
  div([attribute.class(progress_class())], [
    card_progress.view(
      config.progress_completed,
      config.progress_total,
      card_progress.Default,
    ),
  ])
}

fn view_status_items(config: Config(msg)) -> Element(msg) {
  case config.status_items {
    [] -> none()
    items -> div([attribute.class(status_items_class())], items)
  }
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

      div([attribute.class(body_class())], [
        ul(
          [attribute.class(task_list_class())],
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
      content_class: task_content_class(),
      leading: option.None,
      on_click: option.Some(config.on_task_click(task.id)),
      content_title: option.None,
      content_label: option.None,
      icon: option.Some(task_type_icon.view(
        task.task_type.icon,
        14,
        config.theme,
      )),
      icon_class: option.None,
      title: task_title(task.title),
      title_class: option.None,
      secondary: secondary,
      actions: task_actions_for(config, task),
      reserve_actions_slot: True,
      action_slot_class: action_slot_class(),
      testid: config.task_item_testid,
    ),
    task_item.Div,
  )
}

fn status_display(config: Config(msg), task: Task) -> Element(msg) {
  case task.status {
    Claimed(_) ->
      span(
        [
          attribute.class("task-claimed-by"),
          attribute.attribute(
            "title",
            task_state_ui.hint(config.locale, task.status),
          ),
        ],
        [text(compact_claimed_name(config, task))],
      )
    Available ->
      span(
        [
          attribute.class("task-status-muted"),
          attribute.attribute(
            "title",
            task_state_ui.hint(config.locale, task.status),
          ),
        ],
        [text(task_status_utils.label(config.locale, task.status))],
      )
    Done ->
      span(
        [
          attribute.class("task-status"),
          attribute.attribute(
            "title",
            task_state_ui.hint(config.locale, task.status),
          ),
        ],
        [text(task_status_utils.label(config.locale, task.status))],
      )
  }
}

fn compact_claimed_name(config: Config(msg), task: Task) -> String {
  case claimed_email(config, task) {
    option.Some(email) -> truncate_email(email)
    option.None -> "?"
  }
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
  case task.status {
    Available ->
      task_item.single_action(task_actions.claim_icon_with_class(
        task_state_ui.next_action(config.locale, task.status),
        config.on_task_claim(task.id, task.version),
        icons.XSmall,
        False,
        "btn-claim-mini",
        option.None,
        option.None,
      ))
    _ -> task_item.no_actions()
  }
}

fn task_container_class(config: Config(msg), task: Task) -> String {
  let border_class =
    task.card_color
    |> option.or(config.card.color)
    |> task_color.card_border_class

  "task-item kanban-task-item card-surface-task card-surface-task-compact "
  <> border_class
}

fn task_content_class() -> String {
  "task-item-content kanban-task-content"
}

fn action_slot_class() -> option.Option(String) {
  option.Some("task-item-action-slot-compact")
}

fn task_title(title: String) -> String {
  text_utils.truncate(title, 25)
}

fn description_for_card(description: String) -> String {
  text_utils.truncate(description, 80)
}

fn truncate_email(email: String) -> String {
  case string.split(email, "@") {
    [local, ..] -> text_utils.truncate(local, 10)
    _ -> text_utils.truncate(email, 10)
  }
}

fn root_class() -> String {
  "card-surface kanban-card card-surface-kanban"
}

fn header_class() -> String {
  "card-surface-header kanban-card-header"
}

fn title_class() -> String {
  "card-surface-title kanban-card-title"
}

fn description_class() -> String {
  "card-surface-description kanban-card-desc"
}

fn progress_class() -> String {
  "card-surface-progress kanban-card-progress"
}

fn status_items_class() -> String {
  "card-surface-status-items kanban-card-health"
}

fn body_class() -> String {
  "card-surface-body kanban-card-body"
}

fn task_list_class() -> String {
  "card-surface-task-list kanban-card-tasks"
}

fn view_footer(config: Config(msg)) -> Element(msg) {
  case config.footer_actions {
    [] -> none()
    actions -> div([attribute.class("card-surface-footer")], actions)
  }
}
