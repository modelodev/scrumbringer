import gleam/int
import gleam/option
import support/render_assertions

import scrumbringer_client/ui/pinned_context

pub fn pinned_context_hides_when_empty_test() {
  let html =
    pinned_context.view(config([]))
    |> render_assertions.html

  render_assertions.not_contains(html, "pinned-context")
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
    |> render_assertions.html

  render_assertions.contains(html, "Contexto fijado")
  render_assertions.contains(html, "First")
  render_assertions.contains(html, "Second")
  render_assertions.contains(html, "Third")
  render_assertions.not_contains(html, "Fourth")
  render_assertions.contains(html, "+1 en notas")
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
    |> render_assertions.html

  render_assertions.not_contains(html, "pinned-context-more")
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
