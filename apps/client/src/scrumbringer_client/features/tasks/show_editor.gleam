import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option as opt
import gleam/string

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{
  button, div, form, input, option, select, text, textarea,
}
import lustre/event

import domain/card.{type Card}
import domain/remote.{type Remote, Failed, Loaded, Loading, NotAsked}
import domain/task.{type Task}
import domain/task/state as task_state
import domain/task_type.{type TaskType}

import scrumbringer_client/features/cards/card_target
import scrumbringer_client/features/cards/card_target_field
import scrumbringer_client/features/hierarchy/scope_view
import scrumbringer_client/features/tasks/show_permissions
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/button as ui_button
import scrumbringer_client/ui/form_field
import scrumbringer_client/ui/guidance

pub type Config(msg) {
  Config(
    locale: Locale,
    current_user_id: opt.Option(Int),
    editing: Bool,
    edit_title: String,
    edit_description: String,
    edit_priority: String,
    edit_type_id: String,
    edit_card_id: String,
    edit_card_query: String,
    edit_error: opt.Option(String),
    edit_in_flight: Bool,
    task_types: Remote(List(TaskType)),
    cards: List(Card),
    depth_names: List(scope_view.DepthName),
    on_edit_started: msg,
    on_edit_cancelled: msg,
    on_title_changed: fn(String) -> msg,
    on_description_changed: fn(String) -> msg,
    on_priority_changed: fn(String) -> msg,
    on_type_id_changed: fn(String) -> msg,
    on_card_id_changed: fn(String) -> msg,
    on_card_query_changed: fn(String) -> msg,
    on_submitted: msg,
  )
}

fn can_edit_task(config: Config(msg), current_task: Task) -> Bool {
  show_permissions.can_edit(config.current_user_id, current_task)
}

pub fn permission_hint(
  config: Config(msg),
  current_task: Task,
) -> opt.Option(String) {
  case current_task.state, can_edit_task(config, current_task) {
    _, True -> opt.None
    task_state.Closed(task_state.ClosedByClaimant, _, _), False ->
      opt.Some(i18n.t(config.locale, i18n_text.TaskEditClosedReadOnly))
    _, False -> opt.Some(i18n.t(config.locale, i18n_text.TaskEditRequiresClaim))
  }
}

pub fn task_description_text(current_task: Task) -> String {
  case current_task.description {
    opt.None -> ""
    opt.Some(description) -> description
  }
}

pub fn is_dirty(config: Config(msg), current_task: Task) -> Bool {
  string.trim(config.edit_title) != current_task.title
  || normalize_description(config.edit_description)
  != task_description_text(current_task)
  || config.edit_priority != int.to_string(current_task.priority)
  || effective_type_id(config, current_task)
  != int.to_string(task_type_id(current_task))
  || config.edit_card_id != id_to_string(current_task.card_id)
}

pub fn view_form(config: Config(msg), current_task: Task) -> Element(msg) {
  form(
    [
      attribute.class("task-show-edit-form"),
      attribute.id("task-show-edit-form"),
      event.on_submit(fn(_) { config.on_submitted }),
    ],
    [
      view_edit_section(i18n.t(config.locale, i18n_text.IdentitySection), [
        form_field.with_error(
          i18n.t(config.locale, i18n_text.Title),
          input([
            attribute.type_("text"),
            attribute.class("task-show-edit-input"),
            attribute.attribute("maxlength", "56"),
            attribute.value(config.edit_title),
            attribute.autofocus(True),
            event.on_input(config.on_title_changed),
            on_escape(config.on_edit_cancelled),
          ]),
          config.edit_error,
        ),
        form_field.view(
          i18n.t(config.locale, i18n_text.Description),
          textarea(
            [
              attribute.class("task-show-edit-textarea"),
              attribute.rows(5),
              attribute.value(config.edit_description),
              event.on_input(config.on_description_changed),
              on_ctrl_enter(config.on_submitted),
              on_escape(config.on_edit_cancelled),
            ],
            "",
          ),
        ),
      ]),
      view_edit_section(i18n.t(config.locale, i18n_text.TaskEditPlanning), [
        div([attribute.class("task-show-edit-grid")], [
          view_type_field(config, current_task),
          view_priority_field(config),
        ]),
      ]),
      view_edit_section(i18n.t(config.locale, i18n_text.TaskEditLocation), [
        div([attribute.class("task-show-edit-grid")], [
          view_card_field(config),
        ]),
      ]),
      form_field.hint(i18n.t(config.locale, i18n_text.TaskEditKeyboardHint)),
    ],
  )
}

fn view_edit_section(
  title: String,
  children: List(Element(msg)),
) -> Element(msg) {
  div([attribute.class("task-show-edit-section")], [
    div([attribute.class("task-show-edit-section-title")], [text(title)]),
    ..children
  ])
}

pub fn view_intro(config: Config(msg), current_task: Task) -> Element(msg) {
  let can_edit = can_edit_task(config, current_task)

  div([attribute.class("task-details-intro")], [
    div([attribute.class("task-details-intro-row")], [
      div([attribute.class("task-details-title")], [
        text(i18n.t(config.locale, i18n_text.TabDetails)),
      ]),
      case config.editing {
        True -> element.none()
        False ->
          case can_edit {
            True ->
              ui_button.text(
                i18n.t(config.locale, i18n_text.EditTask),
                config.on_edit_started,
                ui_button.Secondary,
                ui_button.EntityAction,
              )
              |> ui_button.with_class("task-show-edit-toggle")
              |> ui_button.view
            False -> element.none()
          }
      },
    ]),
    case config.editing {
      True -> element.none()
      False ->
        case permission_hint(config, current_task) {
          opt.Some(hint) -> guidance.section(hint)
          opt.None -> element.none()
        }
    },
    div([attribute.class("task-details-rule")], []),
  ])
}

fn view_type_field(config: Config(msg), current_task: Task) -> Element(msg) {
  let selected = effective_type_id(config, current_task)

  form_field.view(
    i18n.t(config.locale, i18n_text.TaskType),
    select(
      [
        attribute.value(selected),
        event.on_input(config.on_type_id_changed),
        attribute.disabled(
          config.edit_in_flight || !remote_loaded(config.task_types),
        ),
      ],
      task_type_options(config, selected),
    ),
  )
}

fn task_type_options(
  config: Config(msg),
  selected: String,
) -> List(Element(msg)) {
  case config.task_types {
    Loaded(task_types) -> [
      empty_option(i18n.t(config.locale, i18n_text.SelectTaskType), selected),
      ..list.map(task_types, fn(task_type) {
        let value = int.to_string(task_type.id)
        select_option(value, task_type.name, selected)
      })
    ]
    Loading -> [
      empty_option(i18n.t(config.locale, i18n_text.LoadingEllipsis), selected),
    ]
    NotAsked -> [
      empty_option(
        i18n.t(config.locale, i18n_text.SelectProjectFirst),
        selected,
      ),
    ]
    Failed(_) -> [
      empty_option(i18n.t(config.locale, i18n_text.ErrorLoadingTasks), selected),
    ]
  }
}

fn view_priority_field(config: Config(msg)) -> Element(msg) {
  form_field.view(
    i18n.t(config.locale, i18n_text.Priority),
    div(
      [
        attribute.class("task-priority-segmented"),
        attribute.attribute("role", "group"),
        attribute.attribute(
          "aria-label",
          i18n.t(config.locale, i18n_text.Priority),
        ),
      ],
      list.map([1, 2, 3, 4, 5], fn(priority) {
        priority_option(config, priority)
      }),
    ),
  )
}

fn priority_option(config: Config(msg), priority: Int) -> Element(msg) {
  let value = int.to_string(priority)
  let selected = config.edit_priority == value
  let label = i18n.t(config.locale, i18n_text.PriorityShort(priority))

  button(
    [
      attribute.type_("button"),
      attribute.class(case selected {
        True -> "task-priority-option selected"
        False -> "task-priority-option"
      }),
      attribute.attribute("aria-pressed", case selected {
        True -> "true"
        False -> "false"
      }),
      attribute.disabled(config.edit_in_flight),
      event.on_click(config.on_priority_changed(value)),
    ],
    [text(label)],
  )
}

fn view_card_field(config: Config(msg)) -> Element(msg) {
  let options =
    card_target.active_task_targets(config.cards, config.depth_names)
  let selected_card_id = parse_card_id(config.edit_card_id)

  card_target_field.view(card_target_field.Config(
    label: i18n.t(config.locale, i18n_text.ParentCardLabel),
    placeholder: i18n.t(config.locale, i18n_text.TaskCreateRequiresCard),
    selected_label: card_target.selected_label(options, selected_card_id),
    query: config.edit_card_query,
    options: card_target.filter_options(options, config.edit_card_query),
    loading: False,
    disabled: config.edit_in_flight,
    empty_title: i18n.t(config.locale, i18n_text.TaskCreateNoActiveCards),
    empty_body: i18n.t(config.locale, i18n_text.TaskCreateRequiresCard),
    loading_label: i18n.t(config.locale, i18n_text.LoadingEllipsis),
    listbox_id: "task-show-edit-card-options",
    testid_prefix: "task-show-edit-card",
    show_options_when_empty: selected_card_id == opt.None,
    on_query_changed: config.on_card_query_changed,
    on_selected: config.on_card_id_changed,
  ))
}

fn empty_option(label: String, selected: String) -> Element(msg) {
  select_option("", label, selected)
}

fn select_option(value: String, label: String, selected: String) -> Element(msg) {
  option([attribute.value(value), attribute.selected(selected == value)], label)
}

fn remote_loaded(remote: Remote(List(item))) -> Bool {
  case remote {
    Loaded(_) -> True
    _ -> False
  }
}

fn parse_card_id(value: String) -> opt.Option(Int) {
  case int.parse(value) {
    Ok(id) if id > 0 -> opt.Some(id)
    _ -> opt.None
  }
}

pub fn view_readonly_fields(
  config: Config(msg),
  current_task: Task,
) -> Element(msg) {
  let desc = case current_task.description {
    opt.Some(value) -> value
    opt.None -> i18n.t(config.locale, i18n_text.TaskDescriptionEmpty)
  }
  let desc_empty = current_task.description == opt.None

  div([attribute.class("task-show-editor-stack")], [
    view_intro(config, current_task),
    case config.editing {
      True -> view_form(config, current_task)
      False -> element.none()
    },
    case config.editing {
      True -> element.none()
      False ->
        view_value_field(
          i18n.t(config.locale, i18n_text.Description),
          desc,
          desc_empty,
        )
    },
  ])
}

fn view_value_field(label: String, value: String, muted: Bool) -> Element(msg) {
  div([attribute.class("task-show-field")], [
    div([attribute.class("task-show-field-label")], [text(label)]),
    div(
      [
        attribute.class(case muted {
          True -> "task-show-field-value muted"
          False -> "task-show-field-value"
        }),
      ],
      [text(value)],
    ),
  ])
}

fn normalize_description(description: String) -> String {
  case string.trim(description) {
    "" -> ""
    _ -> description
  }
}

fn id_to_string(id: opt.Option(Int)) -> String {
  case id {
    opt.Some(value) -> int.to_string(value)
    opt.None -> ""
  }
}

fn task_type_id(task: Task) -> Int {
  case task.type_id > 0 {
    True -> task.type_id
    False -> task.task_type.id
  }
}

fn effective_type_id(config: Config(msg), current_task: Task) -> String {
  case config.edit_type_id {
    "" -> int.to_string(task_type_id(current_task))
    value -> value
  }
}

fn on_ctrl_enter(submit_msg: msg) -> attribute.Attribute(msg) {
  event.advanced("keydown", {
    use key <- decode.field("key", decode.string)
    use ctrl_key <- decode.field("ctrlKey", decode.bool)
    use meta_key <- decode.field("metaKey", decode.bool)

    case key {
      "Enter" ->
        case ctrl_key || meta_key {
          True ->
            decode.success(event.handler(
              submit_msg,
              prevent_default: True,
              stop_propagation: True,
            ))
          False ->
            decode.failure(
              event.handler(
                submit_msg,
                prevent_default: False,
                stop_propagation: False,
              ),
              expected: "ctrl-enter",
            )
        }
      _ ->
        decode.failure(
          event.handler(
            submit_msg,
            prevent_default: False,
            stop_propagation: False,
          ),
          expected: "ctrl-enter",
        )
    }
  })
}

fn on_escape(cancel_msg: msg) -> attribute.Attribute(msg) {
  event.advanced("keydown", {
    use key <- decode.field("key", decode.string)

    case key {
      "Escape" ->
        decode.success(event.handler(
          cancel_msg,
          prevent_default: True,
          stop_propagation: True,
        ))
      _ ->
        decode.failure(
          event.handler(
            cancel_msg,
            prevent_default: False,
            stop_propagation: False,
          ),
          expected: "escape",
        )
    }
  })
}
