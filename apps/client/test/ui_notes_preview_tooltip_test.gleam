//// Tests for notes preview tooltip (AC16).

import gleam/option.{None, Some}
import gleam/string
import gleeunit/should
import lustre/element

import scrumbringer_client/ui/tooltips/notes_preview_tooltip
import scrumbringer_client/ui/tooltips/types.{NotesPreviewData}

pub fn renders_count_and_time_test() {
  let config =
    notes_preview_tooltip.Config(
      data: NotesPreviewData(
        new_count: 2,
        time_ago: "3 horas",
        last_note_preview: None,
        last_note_author: None,
      ),
      labels: notes_preview_tooltip.Labels(
        new_notes: "notas nuevas",
        time_ago_prefix: "desde hace",
        latest: "Última:",
      ),
    )

  let html = notes_preview_tooltip.view(config) |> element.to_document_string

  string.contains(html, "2") |> should.be_true
  string.contains(html, "notas nuevas") |> should.be_true
  string.contains(html, "desde hace") |> should.be_true
  string.contains(html, "3 horas") |> should.be_true
}

pub fn shows_last_note_when_present_test() {
  let config =
    notes_preview_tooltip.Config(
      data: NotesPreviewData(
        new_count: 1,
        time_ago: "1 hora",
        last_note_preview: Some("Revisé los mockups..."),
        last_note_author: Some("María G."),
      ),
      labels: notes_preview_tooltip.Labels(
        new_notes: "nota nueva",
        time_ago_prefix: "desde hace",
        latest: "Última:",
      ),
    )

  let html = notes_preview_tooltip.view(config) |> element.to_document_string

  string.contains(html, "Última:") |> should.be_true
  string.contains(html, "Revisé los mockups...") |> should.be_true
  string.contains(html, "María G.") |> should.be_true
}

pub fn hides_last_note_when_none_test() {
  let config =
    notes_preview_tooltip.Config(
      data: NotesPreviewData(
        new_count: 3,
        time_ago: "2 días",
        last_note_preview: None,
        last_note_author: None,
      ),
      labels: notes_preview_tooltip.Labels(
        new_notes: "notas nuevas",
        time_ago_prefix: "desde hace",
        latest: "Última:",
      ),
    )

  let html = notes_preview_tooltip.view(config) |> element.to_document_string

  string.contains(html, "Última:") |> should.be_false
}
