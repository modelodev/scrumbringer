import gleam/option as opt
import gleam/string

import lustre/attribute
import lustre/element
import lustre/element/html

import scrumbringer_client/ui/inspector_header
import scrumbringer_client/ui/inspector_shell

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

fn assert_not_contains(html: String, fragment: String) {
  let assert False = string.contains(html, fragment)
}

pub fn inspector_header_uses_single_actions_slot_test() {
  let html =
    inspector_header.view(inspector_header.Config(
      title: "P1 - Sprint Planning #1",
      title_id: "card-show-title",
      state_line: opt.Some("En curso"),
      context: opt.None,
      meta: opt.None,
      actions: opt.Some(
        html.div([attribute.class("inspector-action-bar")], [
          html.text("Actions"),
        ]),
      ),
      close_label: "Cerrar",
      on_close: "close",
      extra_class: "card-inspector-header",
    ))
    |> element.to_document_string

  assert_contains(html, "inspector-action-bar")
  assert_contains(html, "id=\"card-show-title\"")
  assert_contains(html, "tabindex=\"-1\"")
  assert_not_contains(html, "card-open-in-menu")
  assert_not_contains(html, "task-open-in-menu")
}

pub fn inspector_shell_uses_passive_dialog_contract_test() {
  let html =
    inspector_shell.view(
      inspector_shell.Config(
        root_class: "card-show",
        panel_class: "card-show-panel",
        title_id: "card-show-title",
        testid: "card-show",
      ),
      [html.div([], [html.text("Body")])],
    )
    |> element.to_document_string

  assert_contains(html, "role=\"dialog\"")
  assert_contains(html, "aria-modal=\"true\"")
  assert_contains(html, "aria-labelledby=\"card-show-title\"")
  assert_not_contains(html, "aria-keyshortcuts=\"Escape\"")
}
