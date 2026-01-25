//// Pool Dialog Components for Scrumbringer client.
////
//// ## Mission
////
//// Render modal dialogs for the pool view: task creation, task details, and
//// position editing.
////
//// ## Responsibilities
////
//// - Task creation dialog with form fields
//// - Task details modal with notes list
//// - Position edit modal for manual coordinate entry
////
//// ## Non-responsibilities
////
//// - Dialog state management (see features/pool/update.gleam, features/tasks/update.gleam)
//// - Form validation (handled by update handlers)
////
//// ## Relations
////
//// - **features/pool/view.gleam**: Imports and renders these dialogs
//// - **client_state.gleam**: Provides Model, Msg types

import gleam/int
import gleam/list
import gleam/option as opt

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{
  button, div, h3, input, label, option, p, select, span, text,
}
import lustre/event

import domain/task

import scrumbringer_client/client_state.{
  type Model, type Msg, Failed, Loaded, Loading, MemberCreateDescriptionChanged,
  MemberCreateDialogClosed, MemberCreatePriorityChanged, MemberCreateSubmitted,
  MemberCreateTitleChanged, MemberCreateTypeIdChanged, MemberNoteContentChanged,
  MemberNoteSubmitted, MemberPositionEditClosed, MemberPositionEditSubmitted,
  MemberPositionEditXChanged, MemberPositionEditYChanged,
  MemberTaskDetailsClosed, NotAsked, pool_msg,
}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/icons
import scrumbringer_client/update_helpers

// =============================================================================
// Task Creation Dialog
// =============================================================================

/// Renders the task creation dialog.
pub fn view_create_dialog(model: Model) -> Element(Msg) {
  div([attribute.class("dialog-overlay")], [
    div([attribute.class("dialog dialog-md")], [
      // Header with icon (Story 4.8 UX: consistent with card dialog)
      div([attribute.class("dialog-header")], [
        div([attribute.class("dialog-title")], [
          span([attribute.class("dialog-icon")], [
            icons.nav_icon(icons.ClipboardDoc, icons.Medium),
          ]),
          h3([], [text(update_helpers.i18n_t(model, i18n_text.NewTask))]),
        ]),
        button(
          [
            attribute.class("dialog-close"),
            attribute.attribute("aria-label", "Close"),
            event.on_click(pool_msg(MemberCreateDialogClosed)),
          ],
          [text("×")],
        ),
      ]),
      // Error message (if any)
      case model.member.member_create_error {
        opt.Some(err) ->
          div([attribute.class("dialog-error")], [
            icons.nav_icon(icons.Warning, icons.Small),
            text(err),
          ])
        opt.None -> element.none()
      },
      // Body with form fields
      div([attribute.class("dialog-body")], [
        div([attribute.class("field")], [
          label([], [text(update_helpers.i18n_t(model, i18n_text.Title))]),
          input([
            attribute.type_("text"),
            attribute.attribute("maxlength", "56"),
            attribute.value(model.member.member_create_title),
            event.on_input(fn(value) {
              pool_msg(MemberCreateTitleChanged(value))
            }),
          ]),
        ]),
        div([attribute.class("field")], [
          label([], [text(update_helpers.i18n_t(model, i18n_text.Description))]),
          input([
            attribute.type_("text"),
            attribute.value(model.member.member_create_description),
            event.on_input(fn(value) {
              pool_msg(MemberCreateDescriptionChanged(value))
            }),
          ]),
        ]),
        div([attribute.class("field")], [
          label([], [text(update_helpers.i18n_t(model, i18n_text.Priority))]),
          input([
            attribute.type_("number"),
            attribute.value(model.member.member_create_priority),
            event.on_input(fn(value) {
              pool_msg(MemberCreatePriorityChanged(value))
            }),
          ]),
        ]),
        div([attribute.class("field")], [
          label([], [text(update_helpers.i18n_t(model, i18n_text.TypeLabel))]),
          select(
            [
              attribute.value(model.member.member_create_type_id),
              event.on_input(fn(value) {
                pool_msg(MemberCreateTypeIdChanged(value))
              }),
            ],
            case model.member.member_task_types {
              Loaded(task_types) -> [
                option(
                  [attribute.value("")],
                  update_helpers.i18n_t(model, i18n_text.SelectType),
                ),
                ..list.map(task_types, fn(tt) {
                  option([attribute.value(int.to_string(tt.id))], tt.name)
                })
              ]
              _ -> [
                option(
                  [attribute.value("")],
                  update_helpers.i18n_t(model, i18n_text.LoadingEllipsis),
                ),
              ]
            },
          ),
        ]),
      ]),
      // Footer with actions
      div([attribute.class("dialog-footer")], [
        button(
          [
            attribute.class("btn-secondary"),
            event.on_click(pool_msg(MemberCreateDialogClosed)),
          ],
          [text(update_helpers.i18n_t(model, i18n_text.Cancel))],
        ),
        button(
          [
            attribute.class("btn-primary"),
            event.on_click(pool_msg(MemberCreateSubmitted)),
            attribute.disabled(model.member.member_create_in_flight),
          ],
          [
            text(case model.member.member_create_in_flight {
              True -> update_helpers.i18n_t(model, i18n_text.Creating)
              False -> update_helpers.i18n_t(model, i18n_text.Create)
            }),
          ],
        ),
      ]),
    ]),
  ])
}

// =============================================================================
// Task Details Dialog
// =============================================================================

/// Renders the task details modal with notes.
pub fn view_task_details(model: Model, task_id: Int) -> Element(Msg) {
  div([attribute.class("modal")], [
    div([attribute.class("modal-content")], [
      h3([], [text(update_helpers.i18n_t(model, i18n_text.Notes))]),
      button([event.on_click(pool_msg(MemberTaskDetailsClosed))], [
        text(update_helpers.i18n_t(model, i18n_text.Close)),
      ]),
      view_notes(model, task_id),
    ]),
  ])
}

/// Renders the notes section for a task.
fn view_notes(model: Model, _task_id: Int) -> Element(Msg) {
  let current_user_id = case model.core.user {
    opt.Some(u) -> u.id
    opt.None -> 0
  }

  div([], [
    case model.member.member_notes {
      NotAsked | Loading ->
        div([attribute.class("empty")], [
          text(update_helpers.i18n_t(model, i18n_text.LoadingEllipsis)),
        ])
      Failed(err) -> div([attribute.class("error")], [text(err.message)])
      Loaded(notes) ->
        div(
          [],
          list.map(notes, fn(n) {
            let task.TaskNote(
              user_id: user_id,
              content: content,
              created_at: created_at,
              ..,
            ) = n
            let author = case user_id == current_user_id {
              True -> update_helpers.i18n_t(model, i18n_text.You)
              False ->
                update_helpers.i18n_t(model, i18n_text.UserNumber(user_id))
            }

            div([attribute.class("note")], [
              p([], [text(author <> " @ " <> created_at)]),
              p([], [text(content)]),
            ])
          }),
        )
    },
    case model.member.member_note_error {
      opt.Some(err) -> div([attribute.class("error")], [text(err)])
      opt.None -> element.none()
    },
    div([attribute.class("field")], [
      label([], [text(update_helpers.i18n_t(model, i18n_text.AddNote))]),
      input([
        attribute.type_("text"),
        attribute.value(model.member.member_note_content),
        event.on_input(fn(value) { pool_msg(MemberNoteContentChanged(value)) }),
      ]),
    ]),
    button(
      [
        event.on_click(pool_msg(MemberNoteSubmitted)),
        attribute.disabled(model.member.member_note_in_flight),
      ],
      [
        text(case model.member.member_note_in_flight {
          True -> update_helpers.i18n_t(model, i18n_text.Adding)
          False -> update_helpers.i18n_t(model, i18n_text.Add)
        }),
      ],
    ),
  ])
}

// =============================================================================
// Position Edit Dialog
// =============================================================================

/// Renders the position edit modal.
pub fn view_position_edit(model: Model, _task_id: Int) -> Element(Msg) {
  div([attribute.class("modal")], [
    div([attribute.class("modal-content")], [
      h3([], [text(update_helpers.i18n_t(model, i18n_text.EditPosition))]),
      case model.member.member_position_edit_error {
        opt.Some(err) -> div([attribute.class("error")], [text(err)])
        opt.None -> element.none()
      },
      div([attribute.class("field")], [
        label([], [text(update_helpers.i18n_t(model, i18n_text.XLabel))]),
        input([
          attribute.type_("number"),
          attribute.value(model.member.member_position_edit_x),
          event.on_input(fn(value) {
            pool_msg(MemberPositionEditXChanged(value))
          }),
        ]),
      ]),
      div([attribute.class("field")], [
        label([], [text(update_helpers.i18n_t(model, i18n_text.YLabel))]),
        input([
          attribute.type_("number"),
          attribute.value(model.member.member_position_edit_y),
          event.on_input(fn(value) {
            pool_msg(MemberPositionEditYChanged(value))
          }),
        ]),
      ]),
      div([attribute.class("actions")], [
        button([event.on_click(pool_msg(MemberPositionEditClosed))], [
          text(update_helpers.i18n_t(model, i18n_text.Cancel)),
        ]),
        button(
          [
            event.on_click(pool_msg(MemberPositionEditSubmitted)),
            attribute.disabled(model.member.member_position_edit_in_flight),
          ],
          [
            text(case model.member.member_position_edit_in_flight {
              True -> update_helpers.i18n_t(model, i18n_text.Saving)
              False -> update_helpers.i18n_t(model, i18n_text.Save)
            }),
          ],
        ),
      ]),
    ]),
  ])
}
