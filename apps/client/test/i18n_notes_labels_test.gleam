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
  let assert "Notas" = i18n_es.translate(i18n_text.TabNotes)
}

pub fn notes_labels_en_test() {
  let assert "Notes" = i18n_en.translate(i18n_text.Notes)
  let assert "Add note" = i18n_en.translate(i18n_text.AddNote)
  let assert "Write a note..." = i18n_en.translate(i18n_text.NotePlaceholder)
  let assert "Delete" = i18n_en.translate(i18n_text.Delete)
  let assert "Delete (as admin)" = i18n_en.translate(i18n_text.DeleteAsAdmin)
  let assert "Notes" = i18n_en.translate(i18n_text.TabNotes)
}
