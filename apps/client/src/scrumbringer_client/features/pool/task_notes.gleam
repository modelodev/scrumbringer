//// Task detail notes tab.

import gleam/list
import gleam/option as opt

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, text}

import domain/org_role
import domain/remote.{type Remote, Failed, Loaded, Loading, NotAsked}
import domain/task.{type TaskNote, TaskNote}

import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/card_section_header
import scrumbringer_client/ui/error_notice
import scrumbringer_client/ui/note_dialog
import scrumbringer_client/ui/notes_list
import scrumbringer_client/ui/tooltips/types as notes_list_types

pub type Config(msg) {
  Config(
    locale: Locale,
    current_user_id: opt.Option(Int),
    notes: Remote(List(TaskNote)),
    dialog_mode: dialog_mode.DialogMode,
    note_content: String,
    note_error: opt.Option(String),
    note_in_flight: Bool,
    on_dialog_opened: msg,
    on_dialog_closed: msg,
    on_content_changed: fn(String) -> msg,
    on_submitted: msg,
    on_delete: fn(Int) -> msg,
  )
}

fn t(config: Config(msg), key: i18n_text.Text) -> String {
  i18n.t(config.locale, key)
}

pub fn view(config: Config(msg)) -> Element(msg) {
  div([attribute.class("task-notes-section detail-section")], [
    card_section_header.view_with_class(
      "card-section-header",
      card_section_header.Config(
        title: t(config, i18n_text.Notes),
        button_label: "+ " <> t(config, i18n_text.AddNote),
        button_disabled: False,
        on_button_click: config.on_dialog_opened,
      ),
    ),
    div([attribute.class("task-section-hint")], [
      text(t(config, i18n_text.TaskNotesHint)),
    ]),
    notes_content(config),
    case config.dialog_mode {
      dialog_mode.DialogCreate -> note_dialog(config)
      _ -> element.none()
    },
  ])
}

fn notes_content(config: Config(msg)) -> Element(msg) {
  case config.notes {
    NotAsked | Loading ->
      empty_state(config, i18n_text.Loading, i18n_text.LoadingEllipsis)

    Failed(err) -> error_notice.view(err.message)

    Loaded(notes) ->
      case notes {
        [] ->
          empty_state(
            config,
            i18n_text.NoNotesYet,
            i18n_text.TaskNotesEmptyHint,
          )
        _ ->
          notes_list.view(
            list.map(notes, fn(note) { task_note_to_view(config, note) }),
            t(config, i18n_text.Delete),
            t(config, i18n_text.DeleteAsAdmin),
            config.on_delete,
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

fn note_dialog(config: Config(msg)) -> Element(msg) {
  note_dialog.view(note_dialog.Config(
    title: t(config, i18n_text.AddNote),
    content: config.note_content,
    placeholder: t(config, i18n_text.NotePlaceholder),
    error: config.note_error,
    submit_label: t(config, i18n_text.AddNote),
    submit_disabled: config.note_in_flight || config.note_content == "",
    cancel_label: t(config, i18n_text.Cancel),
    on_content_change: config.on_content_changed,
    on_submit: config.on_submitted,
    on_close: config.on_dialog_closed,
  ))
}

fn task_note_to_view(config: Config(msg), note: TaskNote) -> notes_list.NoteView {
  let TaskNote(
    id: id,
    user_id: user_id,
    content: content,
    created_at: created_at,
    ..,
  ) = note

  let author = case config.current_user_id == opt.Some(user_id) {
    True -> t(config, i18n_text.You)
    False -> t(config, i18n_text.UserNumber(user_id))
  }

  notes_list.NoteView(
    id: id,
    author: author,
    created_at: created_at,
    content: content,
    can_delete: False,
    delete_context: notes_list_types.DeleteOwnNote,
    author_email: "",
    author_project_role: opt.None,
    author_org_role: org_role.Member,
  )
}
