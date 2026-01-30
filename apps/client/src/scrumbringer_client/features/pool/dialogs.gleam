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
import lustre/element/html.{button, div, form, input, option, select, span, text}
import lustre/event

import domain/card.{type Card}
import domain/task

import scrumbringer_client/client_state.{
  type Model, type Msg, Failed, Loaded, Loading, MemberCreateCardIdChanged,
  MemberCreateDescriptionChanged, MemberCreateDialogClosed,
  MemberCreatePriorityChanged, MemberCreateSubmitted, MemberCreateTitleChanged,
  MemberCreateTypeIdChanged, MemberNoteContentChanged, MemberNoteDialogClosed,
  MemberNoteDialogOpened, MemberNoteSubmitted, MemberPositionEditClosed,
  MemberPositionEditSubmitted, MemberPositionEditXChanged,
  MemberPositionEditYChanged, MemberTaskDetailTabClicked,
  MemberTaskDetailsClosed, NotAsked, pool_msg,
}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/card_section_header
import scrumbringer_client/ui/color_picker
import scrumbringer_client/ui/dialog
import scrumbringer_client/ui/error as ui_error
import scrumbringer_client/ui/form_field
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/modal_header
import scrumbringer_client/ui/note_dialog
import scrumbringer_client/ui/notes_list
import scrumbringer_client/ui/task_state
import scrumbringer_client/ui/task_tabs
import scrumbringer_client/ui/tooltips/types as notes_list_types
import scrumbringer_client/update_helpers
import scrumbringer_client/utils/card_queries

// =============================================================================
// Task Creation Dialog
// =============================================================================

/// Renders the task creation dialog.
/// Justification: large function kept intact to preserve cohesive UI logic.
pub fn view_create_dialog(model: Model) -> Element(Msg) {
  dialog.view(
    dialog.DialogConfig(
      title: update_helpers.i18n_t(model, i18n_text.NewTask),
      icon: opt.Some(icons.nav_icon(icons.ClipboardDoc, icons.Medium)),
      size: dialog.DialogMd,
      on_close: pool_msg(MemberCreateDialogClosed),
    ),
    True,
    model.member.member_create_error,
    [
      form(
        [
          event.on_submit(fn(_) { pool_msg(MemberCreateSubmitted) }),
          attribute.id("task-create-form"),
        ],
        [
          form_field.view(
            update_helpers.i18n_t(model, i18n_text.Title),
            input([
              attribute.type_("text"),
              attribute.attribute("maxlength", "56"),
              attribute.value(model.member.member_create_title),
              event.on_input(fn(value) {
                pool_msg(MemberCreateTitleChanged(value))
              }),
            ]),
          ),
          form_field.view(
            update_helpers.i18n_t(model, i18n_text.Description),
            input([
              attribute.type_("text"),
              attribute.value(model.member.member_create_description),
              event.on_input(fn(value) {
                pool_msg(MemberCreateDescriptionChanged(value))
              }),
            ]),
          ),
          form_field.view(
            update_helpers.i18n_t(model, i18n_text.Priority),
            input([
              attribute.type_("number"),
              attribute.value(model.member.member_create_priority),
              event.on_input(fn(value) {
                pool_msg(MemberCreatePriorityChanged(value))
              }),
            ]),
          ),
          form_field.view(
            update_helpers.i18n_t(model, i18n_text.TypeLabel),
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
          ),
          // Card selector (AC1-AC3, Story 4.12)
          view_card_selector(model),
        ],
      ),
    ],
    [
      dialog.cancel_button(model, pool_msg(MemberCreateDialogClosed)),
      button(
        [
          attribute.type_("submit"),
          attribute.form("task-create-form"),
          attribute.disabled(model.member.member_create_in_flight),
          attribute.class(case model.member.member_create_in_flight {
            True -> "btn-loading"
            False -> ""
          }),
        ],
        [
          text(case model.member.member_create_in_flight {
            True -> update_helpers.i18n_t(model, i18n_text.Creating)
            False -> update_helpers.i18n_t(model, i18n_text.Create)
          }),
        ],
      ),
    ],
  )
}

// =============================================================================
// Card Selector (Story 4.12)
// =============================================================================

/// Renders the card selector for task creation.
/// Shows all project cards with color indicators.
fn view_card_selector(model: Model) -> Element(Msg) {
  let cards = card_queries.get_project_cards(model)

  form_field.view(
    update_helpers.i18n_t(model, i18n_text.CardOptional),
    select(
      [
        attribute.value(card_id_to_string(model.member.member_create_card_id)),
        event.on_input(fn(value) { pool_msg(MemberCreateCardIdChanged(value)) }),
      ],
      [
        // "No card" option (AC2)
        option(
          [
            attribute.value(""),
            attribute.selected(opt.is_none(model.member.member_create_card_id)),
          ],
          update_helpers.i18n_t(model, i18n_text.NoCard),
        ),
        // Cards with color indicators (AC3, AC15)
        ..list.map(cards, fn(c) { view_card_option(model, c) })
      ],
    ),
  )
}

/// Render a card as a select option with color indicator prefix.
fn view_card_option(model: Model, c: Card) -> Element(Msg) {
  let color_indicator = case c.color {
    opt.Some(color_str) ->
      case color_picker.string_to_color(color_str) {
        opt.Some(color) -> color_picker.color_emoji(color) <> " "
        opt.None -> ""
      }
    opt.None -> ""
  }

  let is_selected = model.member.member_create_card_id == opt.Some(c.id)

  option(
    [attribute.value(int.to_string(c.id)), attribute.selected(is_selected)],
    color_indicator <> c.title,
  )
}

/// Convert Option(Int) card_id to string for select value.
fn card_id_to_string(card_id: opt.Option(Int)) -> String {
  case card_id {
    opt.Some(id) -> int.to_string(id)
    opt.None -> ""
  }
}

// =============================================================================
// Task Details Dialog (Story 5.4.1: Unified modal with tabs)
// =============================================================================

/// Renders the task details modal with header, tabs, and content.
/// AC1: Shows task title, type, priority, status
/// AC2: Tab system (DETALLES | NOTAS)
/// AC7: Backdrop click-to-close
/// AC8: Close button [×]
pub fn view_task_details(model: Model, task_id: Int) -> Element(Msg) {
  let task = find_task(model, task_id)

  div([attribute.class("task-detail-modal")], [
    // AC7: Backdrop that closes on click
    div(
      [
        attribute.class("modal-backdrop"),
        event.on_click(pool_msg(MemberTaskDetailsClosed)),
      ],
      [],
    ),
    div(
      [
        attribute.class("modal-content task-detail-content"),
        attribute.attribute("role", "dialog"),
        attribute.attribute("aria-modal", "true"),
        attribute.attribute("aria-labelledby", "task-detail-title"),
      ],
      [
        // AC1, AC8: Header with task info and close button
        view_task_header(model, task),
        // AC2: Tab system
        view_task_tabs(model),
        // Content based on active tab
        view_task_tab_content(model, task_id, task),
        // Footer
        div([attribute.class("modal-footer")], [
          button(
            [
              attribute.class("btn btn-secondary"),
              event.on_click(pool_msg(MemberTaskDetailsClosed)),
            ],
            [text(update_helpers.i18n_t(model, i18n_text.Close))],
          ),
        ]),
      ],
    ),
  ])
}

/// Find a task by ID from the model.
fn find_task(model: Model, task_id: Int) -> opt.Option(task.Task) {
  case model.member.member_tasks {
    Loaded(tasks) ->
      list.find(tasks, fn(t) { t.id == task_id }) |> opt.from_result
    NotAsked -> opt.None
    Loading -> opt.None
    Failed(_) -> opt.None
  }
}

/// Task header with title, type, priority, status (AC1)
fn view_task_header(model: Model, task: opt.Option(task.Task)) -> Element(Msg) {
  case task {
    opt.Some(t) ->
      modal_header.view_extended(modal_header.ExtendedConfig(
        title: t.title,
        title_element: modal_header.TitleH2,
        close_position: modal_header.CloseBeforeTitle,
        icon: opt.None,
        badges: [],
        meta: opt.Some(
          div([attribute.class("task-detail-meta")], [
            span([attribute.class("task-meta-type")], [
              icons.nav_icon(icons.TaskTypes, icons.Small),
              text(t.task_type.name),
            ]),
            span([attribute.class("task-meta-priority")], [
              icons.nav_icon(icons.Automation, icons.Small),
              text("P" <> int.to_string(t.priority)),
            ]),
            span([attribute.class("task-meta-status")], [
              text(task_state.label(model.ui.locale, t.status)),
            ]),
            view_assignee(model, t),
          ]),
        ),
        progress: opt.None,
        on_close: pool_msg(MemberTaskDetailsClosed),
        header_class: "task-detail-header",
        title_row_class: "task-detail-title-row",
        title_class: "task-detail-title",
        title_id: "task-detail-title",
        close_button_class: "modal-close btn-icon",
      ))
    opt.None ->
      modal_header.view_extended(modal_header.ExtendedConfig(
        title: update_helpers.i18n_t(model, i18n_text.LoadingEllipsis),
        title_element: modal_header.TitleH2,
        close_position: modal_header.CloseBeforeTitle,
        icon: opt.None,
        badges: [],
        meta: opt.None,
        progress: opt.None,
        on_close: pool_msg(MemberTaskDetailsClosed),
        header_class: "task-detail-header",
        title_row_class: "task-detail-title-row",
        title_class: "task-detail-title",
        title_id: "task-detail-title",
        close_button_class: "modal-close btn-icon",
      ))
  }
}

/// Assignee display
fn view_assignee(model: Model, t: task.Task) -> Element(Msg) {
  case t.claimed_by {
    opt.Some(_user_id) ->
      span([attribute.class("task-meta-assignee")], [
        icons.nav_icon(icons.UserCircle, icons.Small),
        text("Asignado"),
      ])
    opt.None ->
      span([attribute.class("task-meta-assignee muted")], [
        text(update_helpers.i18n_t(model, i18n_text.Unassigned)),
      ])
  }
}

/// Tab system for task detail (AC2)
fn view_task_tabs(model: Model) -> Element(Msg) {
  let notes_count = case model.member.member_notes {
    Loaded(notes) -> list.length(notes)
    NotAsked -> 0
    Loading -> 0
    Failed(_) -> 0
  }

  task_tabs.view(
    task_tabs.Config(
      active_tab: model.member.member_task_detail_tab,
      notes_count: notes_count,
      has_new_notes: False,
      labels: task_tabs.Labels(
        details: update_helpers.i18n_t(model, i18n_text.TabDetails),
        notes: update_helpers.i18n_t(model, i18n_text.TabNotes),
      ),
      on_tab_click: fn(tab) { pool_msg(MemberTaskDetailTabClicked(tab)) },
    ),
  )
}

/// Tab content based on active tab (AC3, AC4)
fn view_task_tab_content(
  model: Model,
  task_id: Int,
  task: opt.Option(task.Task),
) -> Element(Msg) {
  case model.member.member_task_detail_tab {
    task_tabs.DetailsTab -> view_task_details_tab(model, task)
    task_tabs.NotesTab -> view_notes(model, task_id)
  }
}

/// Details tab content (AC3)
fn view_task_details_tab(
  model: Model,
  task: opt.Option(task.Task),
) -> Element(Msg) {
  div([attribute.class("task-details-section")], [
    case task {
      opt.Some(t) ->
        div([], [
          // Card association
          case t.card_id {
            opt.Some(_) ->
              div([attribute.class("detail-row")], [
                span([attribute.class("detail-label")], [
                  text(update_helpers.i18n_t(model, i18n_text.CardOptional)),
                ]),
                span([attribute.class("detail-value")], [
                  text(t.card_title |> opt.unwrap("—")),
                ]),
              ])
            opt.None -> element.none()
          },
          // Description
          case t.description {
            opt.Some(desc) ->
              div([attribute.class("detail-row")], [
                span([attribute.class("detail-label")], [
                  text(update_helpers.i18n_t(model, i18n_text.Description)),
                ]),
                span([attribute.class("detail-value")], [text(desc)]),
              ])
            opt.None -> element.none()
          },
          // Actions
          div([attribute.class("task-detail-actions")], [
            button(
              [
                attribute.class("btn btn-primary"),
                attribute.disabled(opt.is_some(t.claimed_by)),
              ],
              [text(update_helpers.i18n_t(model, i18n_text.ClaimTask))],
            ),
          ]),
        ])
      opt.None ->
        div([attribute.class("loading")], [
          text(update_helpers.i18n_t(model, i18n_text.LoadingEllipsis)),
        ])
    },
  ])
}

/// Renders the notes section for a task.
/// Story 5.4 UX: Dialog-based note creation (unified with card notes pattern).
fn view_notes(model: Model, _task_id: Int) -> Element(Msg) {
  let current_user_id = case model.core.user {
    opt.Some(u) -> u.id
    opt.None -> 0
  }

  div([attribute.class("task-notes-section")], [
    // Header with button (using shared component)
    card_section_header.view_with_class(
      "task-notes-header",
      card_section_header.Config(
        title: update_helpers.i18n_t(model, i18n_text.Notes),
        button_label: "+ " <> update_helpers.i18n_t(model, i18n_text.AddNote),
        button_disabled: False,
        on_button_click: pool_msg(MemberNoteDialogOpened),
      ),
    ),
    // Notes list
    case model.member.member_notes {
      NotAsked | Loading ->
        div([attribute.class("empty")], [
          text(update_helpers.i18n_t(model, i18n_text.LoadingEllipsis)),
        ])
      Failed(err) -> ui_error.error(err)
      Loaded(notes) ->
        notes_list.view(
          list.map(notes, fn(n) { task_note_to_view(model, n, current_user_id) }),
          update_helpers.i18n_t(model, i18n_text.Delete),
          update_helpers.i18n_t(model, i18n_text.DeleteAsAdmin),
          fn(_id) { pool_msg(MemberTaskDetailsClosed) },
        )
    },
    // Dialog overlay (conditional)
    case model.member.member_note_dialog_open {
      True -> view_note_dialog(model)
      False -> element.none()
    },
  ])
}

/// Dialog for creating a note - uses shared note_dialog component (Story 5.4.2).
fn view_note_dialog(model: Model) -> Element(Msg) {
  note_dialog.view(note_dialog.Config(
    title: update_helpers.i18n_t(model, i18n_text.AddNote),
    content: model.member.member_note_content,
    placeholder: update_helpers.i18n_t(model, i18n_text.NotePlaceholder),
    error: model.member.member_note_error,
    submit_label: update_helpers.i18n_t(model, i18n_text.AddNote),
    submit_disabled: model.member.member_note_in_flight
      || model.member.member_note_content == "",
    cancel_label: update_helpers.i18n_t(model, i18n_text.Cancel),
    on_content_change: fn(v) { pool_msg(MemberNoteContentChanged(v)) },
    on_submit: pool_msg(MemberNoteSubmitted),
    on_close: pool_msg(MemberNoteDialogClosed),
  ))
}

// =============================================================================
// Position Edit Dialog (Story 5.4.2: Migrated to ui/dialog)
// =============================================================================

/// Renders the position edit modal using ui/dialog.gleam.
pub fn view_position_edit(model: Model, _task_id: Int) -> Element(Msg) {
  let is_loading = model.member.member_position_edit_in_flight

  dialog.view(
    dialog.DialogConfig(
      title: update_helpers.i18n_t(model, i18n_text.EditPosition),
      icon: opt.None,
      size: dialog.DialogSm,
      on_close: pool_msg(MemberPositionEditClosed),
    ),
    True,
    model.member.member_position_edit_error,
    // Content: form fields
    [
      form_field.view(
        update_helpers.i18n_t(model, i18n_text.XLabel),
        input([
          attribute.type_("number"),
          attribute.value(model.member.member_position_edit_x),
          event.on_input(fn(value) {
            pool_msg(MemberPositionEditXChanged(value))
          }),
        ]),
      ),
      form_field.view(
        update_helpers.i18n_t(model, i18n_text.YLabel),
        input([
          attribute.type_("number"),
          attribute.value(model.member.member_position_edit_y),
          event.on_input(fn(value) {
            pool_msg(MemberPositionEditYChanged(value))
          }),
        ]),
      ),
    ],
    // Footer: buttons (using on_click for non-form submit)
    [
      dialog.cancel_button(model, pool_msg(MemberPositionEditClosed)),
      button(
        [
          attribute.type_("button"),
          attribute.disabled(is_loading),
          attribute.class(case is_loading {
            True -> "btn-loading"
            False -> ""
          }),
          event.on_click(pool_msg(MemberPositionEditSubmitted)),
        ],
        [
          text(case is_loading {
            True -> update_helpers.i18n_t(model, i18n_text.Saving)
            False -> update_helpers.i18n_t(model, i18n_text.Save)
          }),
        ],
      ),
    ],
  )
}

// =============================================================================
// Task Note Conversion (Story 5.4: AC1-AC3)
// =============================================================================

/// Converts a TaskNote to NoteView for rendering with link detection.
fn task_note_to_view(
  model: Model,
  note: task.TaskNote,
  current_user_id: Int,
) -> notes_list.NoteView {
  let task.TaskNote(
    id: id,
    user_id: user_id,
    content: content,
    created_at: created_at,
    ..,
  ) = note

  let author = case user_id == current_user_id {
    True -> update_helpers.i18n_t(model, i18n_text.You)
    False -> update_helpers.i18n_t(model, i18n_text.UserNumber(user_id))
  }

  notes_list.NoteView(
    id: id,
    author: author,
    created_at: created_at,
    content: content,
    can_delete: False,
    delete_context: notes_list_types.DeleteOwnNote,
    author_email: "",
    author_role: "",
  )
}
