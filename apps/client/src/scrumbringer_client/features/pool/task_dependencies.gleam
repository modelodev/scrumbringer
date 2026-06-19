//// Task detail dependencies tab.

import gleam/int
import gleam/list
import gleam/option as opt
import gleam/string

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, form, span, text}
import lustre/event

import domain/remote.{type Remote, Failed, Loaded, Loading, NotAsked}
import domain/task.{type Task, type TaskDependency, TaskDependency}
import domain/task_status

import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/features/pool/blocking
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/action_buttons
import scrumbringer_client/ui/card_section_header
import scrumbringer_client/ui/dialog
import scrumbringer_client/ui/error_notice
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/search_select
import scrumbringer_client/ui/task_state

pub type Config(msg) {
  Config(
    locale: Locale,
    task_id: Int,
    task: opt.Option(Task),
    dependencies: Remote(List(TaskDependency)),
    dialog_mode: dialog_mode.DialogMode,
    search_query: String,
    candidates: Remote(List(Task)),
    selected_task_id: opt.Option(Int),
    add_in_flight: Bool,
    add_error: opt.Option(String),
    remove_in_flight: opt.Option(Int),
    on_dialog_opened: msg,
    on_dialog_closed: msg,
    on_add_submitted: msg,
    on_search_changed: fn(String) -> msg,
    on_selected: fn(Int) -> msg,
    on_remove: fn(Int) -> msg,
  )
}

fn t(config: Config(msg), key: i18n_text.Text) -> String {
  i18n.t(config.locale, key)
}

pub fn view(config: Config(msg)) -> Element(msg) {
  div([attribute.class("task-dependencies-section detail-section")], [
    card_section_header.view_with_class(
      "card-section-header",
      card_section_header.Config(
        title: header_title(config),
        button_label: "+ " <> t(config, i18n_text.AddDependency),
        button_disabled: opt.is_none(config.task),
        on_button_click: config.on_dialog_opened,
      ),
    ),
    div([attribute.class("task-section-hint")], [
      text(t(config, i18n_text.TaskDependenciesHint)),
    ]),
    dependencies_content(config),
    case config.dialog_mode {
      dialog_mode.DialogClosed -> element.none()
      _ -> dependency_dialog(config)
    },
  ])
}

fn header_title(config: Config(msg)) -> String {
  let title = t(config, i18n_text.Dependencies)
  let count = case config.dependencies {
    Loaded(deps) -> blocking.incomplete_dependency_count(deps)
    _ -> 0
  }

  case count > 0 {
    True -> title <> " (" <> int.to_string(count) <> ")"
    False -> title
  }
}

fn dependencies_content(config: Config(msg)) -> Element(msg) {
  case config.dependencies {
    NotAsked | Loading ->
      empty_state(config, i18n_text.Loading, i18n_text.LoadingEllipsis)

    Failed(err) -> error_notice.view(err.message)

    Loaded(deps) ->
      case deps {
        [] ->
          empty_state(
            config,
            i18n_text.NoDependencies,
            i18n_text.TaskDependenciesEmptyHint,
          )
        _ ->
          div(
            [attribute.class("task-dependencies-list")],
            list.map(deps, fn(dep) { dependency_row(config, dep) }),
          )
      }
  }
}

fn empty_state(
  config: Config(msg),
  title: i18n_text.Text,
  body: i18n_text.Text,
) -> Element(msg) {
  div([attribute.class("task-empty-state detail-empty-state")], [
    div([attribute.class("task-empty-title")], [text(t(config, title))]),
    div([attribute.class("task-empty-body")], [text(t(config, body))]),
  ])
}

fn dependency_row(config: Config(msg), dep: TaskDependency) -> Element(msg) {
  let TaskDependency(
    depends_on_task_id: depends_on_task_id,
    title: title,
    status: status,
    claimed_by: claimed_by,
  ) = dep

  let status_label = task_state.label(config.locale, status)

  let status_note = case status {
    task_status.Done -> status_label
    task_status.Claimed(_) ->
      case claimed_by {
        opt.Some(email) -> t(config, i18n_text.ClaimedBy) <> " " <> email
        opt.None -> status_label
      }
    _ -> status_label
  }

  let icon = case status {
    task_status.Done -> icons.nav_icon(icons.CheckCircle, icons.Small)
    _ -> icons.nav_icon(icons.Warning, icons.Small)
  }

  let is_removing = config.remove_in_flight == opt.Some(depends_on_task_id)

  div([attribute.class("task-dependency-row detail-item-row")], [
    div([attribute.class("task-dependency-main")], [
      span([attribute.class("task-dependency-icon")], [icon]),
      div([attribute.class("task-dependency-text")], [
        span([attribute.class("task-dependency-title")], [text(title)]),
        span([attribute.class("task-dependency-status")], [text(status_note)]),
      ]),
    ]),
    action_buttons.task_icon_button(
      t(config, i18n_text.Remove),
      config.on_remove(depends_on_task_id),
      icons.XMark,
      action_buttons.SizeXs,
      is_removing || config.task_id == depends_on_task_id,
      "task-dependency-remove",
      opt.None,
      opt.None,
    ),
  ])
}

fn dependency_dialog(config: Config(msg)) -> Element(msg) {
  let current_task_id = case config.task {
    opt.Some(task) -> task.id
    opt.None -> 0
  }

  let query = string.trim(config.search_query)
  let results = filtered_candidates(config.candidates, current_task_id, query)

  dialog.view_with_close_label(
    dialog.DialogConfig(
      title: t(config, i18n_text.AddDependency),
      icon: opt.Some(icons.nav_icon(icons.Plus, icons.Medium)),
      size: dialog.DialogMd,
      on_close: config.on_dialog_closed,
    ),
    t(config, i18n_text.Close),
    True,
    config.add_error,
    [
      form(
        [
          event.on_submit(fn(_) { config.on_add_submitted }),
          attribute.id("task-dependency-form"),
        ],
        [
          search_select.view(search_select.Config(
            label: t(config, i18n_text.TaskDependsOn),
            placeholder: t(config, i18n_text.SearchPlaceholder),
            value: config.search_query,
            on_change: config.on_search_changed,
            input_attributes: [],
            results: results,
            render_item: fn(task) { dependency_candidate_item(config, task) },
            empty_label: t(config, i18n_text.NoMatchingTasks),
            loading_label: t(config, i18n_text.LoadingEllipsis),
            error_label: fn(message) { message },
            class: "task-dependency-search",
          )),
        ],
      ),
    ],
    [
      dialog.cancel_button_with_locale(config.locale, config.on_dialog_closed),
      dialog.submit_button_with_locale_form(
        config.locale,
        "task-dependency-form",
        config.add_in_flight,
        opt.is_none(config.selected_task_id),
        i18n_text.Add,
        i18n_text.Adding,
      ),
    ],
  )
}

fn filtered_candidates(
  candidates: Remote(List(Task)),
  current_task_id: Int,
  query: String,
) -> Remote(List(Task)) {
  case candidates {
    Loaded(tasks) -> {
      let candidates =
        list.filter(tasks, fn(task) {
          task.id != current_task_id && task.status != task_status.Done
        })

      case string.is_empty(query) {
        True -> Loaded(candidates)
        False ->
          Loaded(
            list.filter(candidates, fn(task) {
              string.contains(
                string.lowercase(task.title),
                string.lowercase(query),
              )
            }),
          )
      }
    }
    Loading -> Loading
    NotAsked -> NotAsked
    Failed(err) -> Failed(err)
  }
}

fn dependency_candidate_item(config: Config(msg), task: Task) -> Element(msg) {
  let is_selected = config.selected_task_id == opt.Some(task.id)
  let status = task_state.label(config.locale, task.status)

  button(
    [
      attribute.type_("button"),
      attribute.class(case is_selected {
        True -> "dependency-candidate selected"
        False -> "dependency-candidate"
      }),
      event.on_click(config.on_selected(task.id)),
    ],
    [
      span([attribute.class("dependency-candidate-title")], [text(task.title)]),
      span([attribute.class("dependency-candidate-status")], [text(status)]),
    ],
  )
}
