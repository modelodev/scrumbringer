import gleam/string
import gleeunit/should
import lustre/element
import scrumbringer_client/i18n/locale
import scrumbringer_client/theme
import scrumbringer_client/ui/empty_state
import scrumbringer_client/ui/error_banner
import scrumbringer_client/ui/layout
import scrumbringer_client/ui/status_block
import scrumbringer_client/ui/icons

pub fn empty_state_view_renders_title_description_and_action_test() {
  let state =
    empty_state.new(icons.Search, "No results", "Try again")
    |> empty_state.with_action("Retry", "msg")

  let html =
    empty_state.view(state)
    |> element.to_document_string

  string.contains(html, "No results") |> should.be_true
  string.contains(html, "Try again") |> should.be_true
  string.contains(html, "Retry") |> should.be_true
}

pub fn empty_state_simple_renders_description_test() {
  let html =
    empty_state.simple(icons.Hand, "Nothing here")
    |> element.to_document_string

  string.contains(html, "Nothing here") |> should.be_true
}

pub fn status_block_renders_empty_and_error_text_test() {
  let empty_html =
    status_block.empty_text("No data")
    |> element.to_document_string

  let error_html =
    status_block.error_text("Boom")
    |> element.to_document_string

  string.contains(empty_html, "No data") |> should.be_true
  string.contains(error_html, "Boom") |> should.be_true
}

pub fn error_banner_renders_message_test() {
  let html = error_banner.view("Oops") |> element.to_document_string
  string.contains(html, "Oops") |> should.be_true
  string.contains(html, "error-banner") |> should.be_true
}

pub fn layout_theme_switch_renders_options_test() {
  let html =
    layout.theme_switch(locale.En, theme.Default, fn(_s) { "msg" })
    |> element.to_document_string

  string.contains(html, "default") |> should.be_true
  string.contains(html, "dark") |> should.be_true
}

pub fn layout_locale_switch_renders_options_test() {
  let html =
    layout.locale_switch(locale.En, fn(_s) { "msg" })
    |> element.to_document_string

  string.contains(html, "es") |> should.be_true
  string.contains(html, "en") |> should.be_true
}
