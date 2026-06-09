import scrumbringer_client/i18n/en as i18n_en
import scrumbringer_client/i18n/es as i18n_es
import scrumbringer_client/i18n/text as i18n_text

pub fn notes_labels_es_test() {
  let assert "Notas" = i18n_es.translate(i18n_text.Notes)
  let assert "Añadir nota" = i18n_es.translate(i18n_text.AddNote)
  let assert "Escribe una nota..." =
    i18n_es.translate(i18n_text.NotePlaceholder)
  let assert "Eliminar" = i18n_es.translate(i18n_text.Delete)
  let assert "Eliminar (como admin)" =
    i18n_es.translate(i18n_text.DeleteAsAdmin)
  let assert "notas nuevas" = i18n_es.translate(i18n_text.NotesPreviewNewNotes)
  let assert "desde hace" = i18n_es.translate(i18n_text.NotesPreviewTimeAgo)
  let assert "Última:" = i18n_es.translate(i18n_text.NotesPreviewLatest)
  let assert "notas en total" = i18n_es.translate(i18n_text.TabBadgeTotalNotes)
  let assert "nuevas para ti" = i18n_es.translate(i18n_text.TabBadgeNewNotes)
  let assert "Notas" = i18n_es.translate(i18n_text.TabNotes)
}

pub fn notes_labels_en_test() {
  let assert "Notes" = i18n_en.translate(i18n_text.Notes)
  let assert "Add note" = i18n_en.translate(i18n_text.AddNote)
  let assert "Write a note..." = i18n_en.translate(i18n_text.NotePlaceholder)
  let assert "Delete" = i18n_en.translate(i18n_text.Delete)
  let assert "Delete (as admin)" = i18n_en.translate(i18n_text.DeleteAsAdmin)
  let assert "new notes" = i18n_en.translate(i18n_text.NotesPreviewNewNotes)
  let assert "since" = i18n_en.translate(i18n_text.NotesPreviewTimeAgo)
  let assert "Latest:" = i18n_en.translate(i18n_text.NotesPreviewLatest)
  let assert "notes total" = i18n_en.translate(i18n_text.TabBadgeTotalNotes)
  let assert "new for you" = i18n_en.translate(i18n_text.TabBadgeNewNotes)
  let assert "Notes" = i18n_en.translate(i18n_text.TabNotes)
}
