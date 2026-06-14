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
import domain/milestone.{type MilestoneProgress, Completed}
import domain/remote.{type Remote, Failed, Loaded, Loading, NotAsked}
import domain/task.{type Task}
import domain/task_state
import domain/task_type.{type TaskType}

import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/form_field

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
    edit_milestone_id: String,
    edit_error: opt.Option(String),
    edit_in_flight: Bool,
    task_types: Remote(List(TaskType)),
    cards: List(Card),
    milestones: Remote(List(MilestoneProgress)),
    parent_card_title: opt.Option(String),
    on_edit_started: msg,
    on_edit_cancelled: msg,
    on_title_changed: fn(String) -> msg,
    on_description_changed: fn(String) -> msg,
    on_priority_changed: fn(String) -> msg,
    on_type_id_changed: fn(String) -> msg,
    on_card_id_changed: fn(String) -> msg,
    on_milestone_id_changed: fn(String) -> msg,
    on_submitted: msg,
  )
}

pub fn can_edit_task(config: Config(msg), current_task: Task) -> Bool {
  case config.current_user_id, task_state.claimed_by(current_task.state) {
    opt.Some(user_id), opt.Some(claimed_by) -> user_id == claimed_by
    opt.Some(_), opt.None -> True
    _, _ -> False
  }
}

pub fn permission_hint(
  config: Config(msg),
  current_task: Task,
) -> opt.Option(String) {
  case can_edit_task(config, current_task) {
    True -> opt.None
    False -> opt.Some(i18n.t(config.locale, i18n_text.TaskEditRequiresClaim))
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
  || config.edit_milestone_id != id_to_string(current_task.milestone_id)
}

pub fn view_form(config: Config(msg), current_task: Task) -> Element(msg) {
  form(
    [
      attribute.class("task-detail-edit-form"),
      attribute.id("task-detail-edit-form"),
      event.on_submit(fn(_) { config.on_submitted }),
    ],
    [
      form_field.with_error(
        i18n.t(config.locale, i18n_text.Title),
        input([
          attribute.type_("text"),
          attribute.class("task-detail-edit-input"),
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
            attribute.class("task-detail-edit-textarea"),
            attribute.rows(5),
            attribute.value(config.edit_description),
            event.on_input(config.on_description_changed),
            on_ctrl_enter(config.on_submitted),
            on_escape(config.on_edit_cancelled),
          ],
          "",
        ),
      ),
      div([attribute.class("task-detail-edit-grid")], [
        view_type_field(config, current_task),
        view_priority_field(config),
        view_card_field(config),
        view_milestone_field(config),
      ]),
      form_field.hint(i18n.t(config.locale, i18n_text.TaskEditKeyboardHint)),
      div([attribute.class("task-detail-edit-actions")], [
        button(
          [
            attribute.type_("button"),
            attribute.class("btn btn-secondary"),
            event.on_click(config.on_edit_cancelled),
            attribute.disabled(config.edit_in_flight),
          ],
          [text(i18n.t(config.locale, i18n_text.Cancel))],
        ),
        button(
          [
            attribute.type_("submit"),
            attribute.class(case config.edit_in_flight {
              True -> "btn btn-primary btn-loading"
              False -> "btn btn-primary"
            }),
            attribute.disabled(
              config.edit_in_flight || !is_dirty(config, current_task),
            ),
          ],
          [text(i18n.t(config.locale, i18n_text.Save))],
        ),
      ]),
    ],
  )
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
              button(
                [
                  attribute.type_("button"),
                  attribute.class(
                    "btn btn-sm btn-secondary task-detail-edit-toggle",
                  ),
                  event.on_click(config.on_edit_started),
                ],
                [text(i18n.t(config.locale, i18n_text.EditTask))],
              )
            False -> element.none()
          }
      },
    ]),
    case config.editing {
      True -> element.none()
      False ->
        case permission_hint(config, current_task) {
          opt.Some(hint) ->
            div(
              [attribute.class("task-section-hint task-edit-permission-hint")],
              [text(hint)],
            )
          opt.None -> element.none()
        }
    },
    div([attribute.class("task-details-rule")], []),
  ])
}

fn view_type_field(config: Config(msg), current_task: Task) -> Element(msg) {
  form_field.view(
    i18n.t(config.locale, i18n_text.TaskType),
    select(
      [
        attribute.value(effective_type_id(config, current_task)),
        event.on_input(config.on_type_id_changed),
        attribute.disabled(
          config.edit_in_flight || !remote_loaded(config.task_types),
        ),
      ],
      task_type_options(config, effective_type_id(config, current_task)),
    ),
  )
}

fn task_type_options(
  config: Config(msg),
  selected: String,
) -> List(Element(msg)) {
  case config.task_types {
    Loaded(task_types) -> [
      option(
        [attribute.value(""), attribute.selected(selected == "")],
        i18n.t(config.locale, i18n_text.SelectTaskType),
      ),
      ..list.map(task_types, fn(task_type) {
        let value = int.to_string(task_type.id)
        option(
          [attribute.value(value), attribute.selected(selected == value)],
          task_type.name,
        )
      })
    ]
    Loading -> [
      option(
        [attribute.value(""), attribute.selected(selected == "")],
        i18n.t(config.locale, i18n_text.LoadingEllipsis),
      ),
    ]
    NotAsked -> [
      option(
        [attribute.value(""), attribute.selected(selected == "")],
        i18n.t(config.locale, i18n_text.SelectProjectFirst),
      ),
    ]
    Failed(_) -> [
      option(
        [attribute.value(""), attribute.selected(selected == "")],
        i18n.t(config.locale, i18n_text.ErrorLoadingTasks),
      ),
    ]
  }
}

fn view_priority_field(config: Config(msg)) -> Element(msg) {
  form_field.view(
    i18n.t(config.locale, i18n_text.Priority),
    input([
      attribute.type_("number"),
      attribute.attribute("min", "1"),
      attribute.attribute("max", "5"),
      attribute.value(config.edit_priority),
      attribute.disabled(config.edit_in_flight),
      event.on_input(config.on_priority_changed),
    ]),
  )
}

fn view_card_field(config: Config(msg)) -> Element(msg) {
  form_field.view(
    i18n.t(config.locale, i18n_text.ParentCardLabel),
    select(
      [
        attribute.value(config.edit_card_id),
        attribute.disabled(config.edit_in_flight),
        event.on_input(config.on_card_id_changed),
      ],
      [
        option(
          [attribute.value(""), attribute.selected(config.edit_card_id == "")],
          i18n.t(config.locale, i18n_text.NoCard),
        ),
        ..list.map(config.cards, fn(card) {
          let value = int.to_string(card.id)
          option(
            [
              attribute.value(value),
              attribute.selected(config.edit_card_id == value),
            ],
            card.title,
          )
        })
      ],
    ),
  )
}

fn view_milestone_field(config: Config(msg)) -> Element(msg) {
  form_field.view(
    i18n.t(config.locale, i18n_text.Milestones),
    select(
      [
        attribute.value(config.edit_milestone_id),
        attribute.disabled(
          config.edit_in_flight
          || config.edit_card_id != ""
          || !remote_loaded(config.milestones),
        ),
        event.on_input(config.on_milestone_id_changed),
      ],
      milestone_options(config),
    ),
  )
}

fn milestone_options(config: Config(msg)) -> List(Element(msg)) {
  case config.milestones {
    Loaded(milestones) -> [
      option(
        [
          attribute.value(""),
          attribute.selected(config.edit_milestone_id == ""),
        ],
        "-",
      ),
      ..milestones
      |> list.filter(fn(progress) {
        progress.milestone.state != Completed
        || config.edit_milestone_id == int.to_string(progress.milestone.id)
      })
      |> list.map(fn(progress) {
        let value = int.to_string(progress.milestone.id)
        option(
          [
            attribute.value(value),
            attribute.selected(config.edit_milestone_id == value),
          ],
          progress.milestone.name,
        )
      })
    ]
    Loading -> [
      option(
        [
          attribute.value(""),
          attribute.selected(config.edit_milestone_id == ""),
        ],
        i18n.t(config.locale, i18n_text.LoadingEllipsis),
      ),
    ]
    NotAsked -> [
      option(
        [
          attribute.value(""),
          attribute.selected(config.edit_milestone_id == ""),
        ],
        "-",
      ),
    ]
    Failed(_) -> [
      option(
        [
          attribute.value(""),
          attribute.selected(config.edit_milestone_id == ""),
        ],
        i18n.t(config.locale, i18n_text.MilestonesLoadError),
      ),
    ]
  }
}

fn remote_loaded(remote: Remote(List(item))) -> Bool {
  case remote {
    Loaded(_) -> True
    _ -> False
  }
}

pub fn view_readonly_fields(
  config: Config(msg),
  current_task: Task,
) -> Element(msg) {
  let desc = case current_task.description {
    opt.Some(value) -> value
    opt.None -> "-"
  }
  let desc_empty = desc == "-"

  div([attribute.class("task-details-stack")], [
    view_intro(config, current_task),
    case config.editing {
      True -> view_form(config, current_task)
      False -> element.none()
    },
    view_value_field(
      i18n.t(config.locale, i18n_text.ParentCardLabel),
      parent_card_label(config),
      parent_card_is_empty(config),
    ),
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
  div([attribute.class("task-detail-field")], [
    div([attribute.class("task-detail-field-label")], [text(label)]),
    div(
      [
        attribute.class(case muted {
          True -> "task-detail-field-value muted"
          False -> "task-detail-field-value"
        }),
      ],
      [text(value)],
    ),
  ])
}

fn parent_card_label(config: Config(msg)) -> String {
  case config.parent_card_title {
    opt.Some(title) -> title
    opt.None -> i18n.t(config.locale, i18n_text.NoCard)
  }
}

fn parent_card_is_empty(config: Config(msg)) -> Bool {
  config.parent_card_title == opt.None
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
