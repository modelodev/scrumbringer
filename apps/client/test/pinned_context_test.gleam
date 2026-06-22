import gleam/int
import gleam/option
import gleam/string
import lustre/element

import scrumbringer_client/ui/pinned_context

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

fn assert_not_contains(html: String, fragment: String) {
  let assert False = string.contains(html, fragment)
}

pub fn pinned_context_hides_when_empty_test() {
  let html =
    pinned_context.view(config([]))
    |> element.to_document_string

  assert_not_contains(html, "pinned-context")
}

pub fn pinned_context_limits_visible_notes_to_three_test() {
  let html =
    pinned_context.view(
      config([
        note(1, "First"),
        note(2, "Second"),
        note(3, "Third"),
        note(4, "Fourth"),
      ]),
    )
    |> element.to_document_string

  assert_contains(html, "Contexto fijado")
  assert_contains(html, "First")
  assert_contains(html, "Second")
  assert_contains(html, "Third")
  assert_not_contains(html, "Fourth")
  assert_contains(html, "+1 en notas")
}

pub fn pinned_context_does_not_show_more_button_at_three_notes_test() {
  let html =
    pinned_context.view(
      config([
        note(1, "First"),
        note(2, "Second"),
        note(3, "Third"),
      ]),
    )
    |> element.to_document_string

  assert_not_contains(html, "pinned-context-more")
}

fn config(
  notes: List(pinned_context.PinnedNote),
) -> pinned_context.Config(String) {
  pinned_context.Config(
    title: "Contexto fijado",
    notes: notes,
    open_notes_label: "Abrir notas",
    more_label: fn(count) { "+" <> int.to_string(count) <> " en notas" },
    on_open_notes: "notes",
  )
}

fn note(id: Int, content: String) -> pinned_context.PinnedNote {
  pinned_context.PinnedNote(id: id, content: content, url: option.None)
}
