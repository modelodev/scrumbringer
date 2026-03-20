import gleam/dynamic/decode
import gleam/option as opt
import gleam/string

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, form, input, text, textarea}
import lustre/event

import domain/task.{type Task}
import domain/task_state

import scrumbringer_client/client_state.{type Model, type Msg, pool_msg}
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/helpers/i18n as helpers_i18n
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/form_field
import scrumbringer_client/utils/card_queries

pub fn can_edit_task(model: Model, current_task: Task) -> Bool {
  case model.core.user, task_state.claimed_by(current_task.state) {
    opt.Some(user), opt.Some(claimed_by) -> user.id == claimed_by
    opt.Some(_), opt.None -> True
    _, _ -> False
  }
}

pub fn permission_hint(model: Model, current_task: Task) -> opt.Option(String) {
  case can_edit_task(model, current_task) {
    True -> opt.None
    False ->
      opt.Some(helpers_i18n.i18n_t(model, i18n_text.TaskEditRequiresClaim))
  }
}

pub fn task_description_text(current_task: Task) -> String {
  opt.unwrap(current_task.description, "")
}

pub fn is_dirty(model: Model, current_task: Task) -> Bool {
  string.trim(model.member.pool.member_task_detail_edit_title)
  != current_task.title
  || normalize_description(
    model.member.pool.member_task_detail_edit_description,
  )
  != task_description_text(current_task)
}

pub fn view_form(model: Model, current_task: Task) -> Element(Msg) {
  let is_saving = model.member.pool.member_task_detail_edit_in_flight

  form(
    [
      attribute.class("task-detail-edit-form"),
      attribute.id("task-detail-edit-form"),
      event.on_submit(fn(_) {
        pool_msg(pool_messages.MemberTaskDetailEditSubmitted)
      }),
    ],
    [
      form_field.with_error(
        helpers_i18n.i18n_t(model, i18n_text.Title),
        input([
          attribute.type_("text"),
          attribute.class("task-detail-edit-input"),
          attribute.attribute("maxlength", "56"),
          attribute.value(model.member.pool.member_task_detail_edit_title),
          attribute.autofocus(True),
          event.on_input(fn(value) {
            pool_msg(pool_messages.MemberTaskDetailEditTitleChanged(value))
          }),
          on_escape(pool_msg(pool_messages.MemberTaskDetailEditCancelled)),
        ]),
        model.member.pool.member_task_detail_edit_error,
      ),
      form_field.view(
        helpers_i18n.i18n_t(model, i18n_text.Description),
        textarea(
          [
            attribute.class("task-detail-edit-textarea"),
            attribute.rows(5),
            attribute.value(
              model.member.pool.member_task_detail_edit_description,
            ),
            event.on_input(fn(value) {
              pool_msg(pool_messages.MemberTaskDetailEditDescriptionChanged(
                value,
              ))
            }),
            on_ctrl_enter(pool_msg(pool_messages.MemberTaskDetailEditSubmitted)),
            on_escape(pool_msg(pool_messages.MemberTaskDetailEditCancelled)),
          ],
          "",
        ),
      ),
      form_field.hint(helpers_i18n.i18n_t(model, i18n_text.TaskEditKeyboardHint)),
      div([attribute.class("task-detail-edit-actions")], [
        button(
          [
            attribute.type_("button"),
            attribute.class("btn btn-secondary"),
            event.on_click(pool_msg(pool_messages.MemberTaskDetailEditCancelled)),
            attribute.disabled(is_saving),
          ],
          [text(helpers_i18n.i18n_t(model, i18n_text.Cancel))],
        ),
        button(
          [
            attribute.type_("submit"),
            attribute.class(case is_saving {
              True -> "btn btn-primary btn-loading"
              False -> "btn btn-primary"
            }),
            attribute.disabled(is_saving || !is_dirty(model, current_task)),
          ],
          [text(helpers_i18n.i18n_t(model, i18n_text.Save))],
        ),
      ]),
    ],
  )
}

pub fn view_intro(model: Model, current_task: Task) -> Element(Msg) {
  let can_edit = can_edit_task(model, current_task)
  let is_editing = model.member.pool.member_task_detail_editing

  div([attribute.class("task-details-intro")], [
    div([attribute.class("task-details-intro-row")], [
      div([attribute.class("task-details-title")], [
        text(helpers_i18n.i18n_t(model, i18n_text.TabDetails)),
      ]),
      case is_editing {
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
                  event.on_click(pool_msg(
                    pool_messages.MemberTaskDetailEditStarted,
                  )),
                ],
                [text(helpers_i18n.i18n_t(model, i18n_text.EditTask))],
              )
            False -> element.none()
          }
      },
    ]),
    case is_editing {
      True -> element.none()
      False ->
        case permission_hint(model, current_task) {
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

pub fn view_readonly_fields(model: Model, current_task: Task) -> Element(Msg) {
  let desc = case current_task.description {
    opt.Some(value) -> value
    opt.None -> "-"
  }
  let desc_empty = desc == "-"

  div([attribute.class("task-details-stack")], [
    view_intro(model, current_task),
    case model.member.pool.member_task_detail_editing {
      True -> view_form(model, current_task)
      False -> element.none()
    },
    view_value_field(
      helpers_i18n.i18n_t(model, i18n_text.ParentCardLabel),
      parent_card_label(model, current_task),
      parent_card_is_empty(model, current_task),
    ),
    case model.member.pool.member_task_detail_editing {
      True -> element.none()
      False ->
        view_value_field(
          helpers_i18n.i18n_t(model, i18n_text.Description),
          desc,
          desc_empty,
        )
    },
  ])
}

fn view_value_field(label: String, value: String, muted: Bool) -> Element(Msg) {
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

fn parent_card_label(model: Model, current_task: Task) -> String {
  let #(resolved_card_title, _resolved_card_color) =
    card_queries.resolve_task_card_info(model, current_task)
  let no_card_label = helpers_i18n.i18n_t(model, i18n_text.NoCard)

  case resolved_card_title {
    opt.Some(title) -> title
    opt.None -> no_card_label
  }
}

fn parent_card_is_empty(model: Model, current_task: Task) -> Bool {
  let #(resolved_card_title, _resolved_card_color) =
    card_queries.resolve_task_card_info(model, current_task)
  resolved_card_title == opt.None
}

fn normalize_description(description: String) -> String {
  case string.trim(description) {
    "" -> ""
    _ -> description
  }
}

fn on_ctrl_enter(submit_msg: Msg) -> attribute.Attribute(Msg) {
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

fn on_escape(cancel_msg: Msg) -> attribute.Attribute(Msg) {
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
