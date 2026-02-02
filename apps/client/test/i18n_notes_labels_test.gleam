import gleeunit/should

import scrumbringer_client/i18n/en as i18n_en
import scrumbringer_client/i18n/es as i18n_es
import scrumbringer_client/i18n/text as i18n_text

pub fn notes_labels_es_test() {
  i18n_es.translate(i18n_text.Notes) |> should.equal("Notas")
  i18n_es.translate(i18n_text.AddNote) |> should.equal("Añadir nota")
  i18n_es.translate(i18n_text.NotePlaceholder)
  |> should.equal("Escribe una nota...")
  i18n_es.translate(i18n_text.Delete) |> should.equal("Eliminar")
  i18n_es.translate(i18n_text.DeleteAsAdmin)
  |> should.equal("Eliminar (como admin)")
  i18n_es.translate(i18n_text.NotesPreviewNewNotes)
  |> should.equal("notas nuevas")
  i18n_es.translate(i18n_text.NotesPreviewTimeAgo)
  |> should.equal("desde hace")
  i18n_es.translate(i18n_text.NotesPreviewLatest)
  |> should.equal("Última:")
  i18n_es.translate(i18n_text.TabBadgeTotalNotes)
  |> should.equal("notas en total")
  i18n_es.translate(i18n_text.TabBadgeNewNotes)
  |> should.equal("nuevas para ti")
  i18n_es.translate(i18n_text.TabNotes) |> should.equal("Notas")
}

pub fn notes_labels_en_test() {
  i18n_en.translate(i18n_text.Notes) |> should.equal("Notes")
  i18n_en.translate(i18n_text.AddNote) |> should.equal("Add note")
  i18n_en.translate(i18n_text.NotePlaceholder)
  |> should.equal("Write a note...")
  i18n_en.translate(i18n_text.Delete) |> should.equal("Delete")
  i18n_en.translate(i18n_text.DeleteAsAdmin)
  |> should.equal("Delete (as admin)")
  i18n_en.translate(i18n_text.NotesPreviewNewNotes)
  |> should.equal("new notes")
  i18n_en.translate(i18n_text.NotesPreviewTimeAgo) |> should.equal("since")
  i18n_en.translate(i18n_text.NotesPreviewLatest)
  |> should.equal("Latest:")
  i18n_en.translate(i18n_text.TabBadgeTotalNotes)
  |> should.equal("notes total")
  i18n_en.translate(i18n_text.TabBadgeNewNotes)
  |> should.equal("new for you")
  i18n_en.translate(i18n_text.TabNotes) |> should.equal("Notes")
}
