//// Notes preview tooltip for [!] indicator (AC16).

import gleam/int
import gleam/option.{Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, span, text}

import scrumbringer_client/ui/tooltips/types.{type NotesPreviewData}

pub type Labels {
  Labels(new_notes: String, time_ago_prefix: String, latest: String)
}

pub type Config(msg) {
  Config(data: NotesPreviewData, labels: Labels)
}

pub fn view(config: Config(msg)) -> Element(msg) {
  let Config(data: data, labels: labels) = config
  let types.NotesPreviewData(
    new_count: new_count,
    time_ago: time_ago,
    last_note_preview: last_note_preview,
    last_note_author: last_note_author,
  ) = data

  div([attribute.class("notes-preview-tooltip"), attribute.role("tooltip")], [
    div([attribute.class("notes-preview-header")], [
      span([attribute.class("notes-preview-count")], [
        text(int.to_string(new_count) <> " " <> labels.new_notes),
      ]),
    ]),
    div([attribute.class("notes-preview-time")], [
      text(labels.time_ago_prefix <> " " <> time_ago),
    ]),
    case last_note_preview, last_note_author {
      Some(preview), Some(author) ->
        div([attribute.class("notes-preview-last")], [
          span([attribute.class("notes-preview-label")], [text(labels.latest)]),
          span([attribute.class("notes-preview-content")], [
            text("\"" <> preview <> "\""),
          ]),
          span([attribute.class("notes-preview-author")], [
            text("— " <> author),
          ]),
        ])
      _, _ -> element.none()
    },
  ])
}
