import gleam/list
import gleam/string
import gleeunit/should
import lustre/element

import scrumbringer_client/ui/loading

pub fn spinner_small_has_correct_class_test() {
  let rendered = loading.spinner(loading.Small)
  let html = element.to_document_string(rendered)

  string.contains(html, "spinner") |> should.be_true
  string.contains(html, "spinner-sm") |> should.be_true
}

pub fn spinner_medium_has_correct_class_test() {
  let rendered = loading.spinner(loading.Medium)
  let html = element.to_document_string(rendered)

  string.contains(html, "spinner-md") |> should.be_true
}

pub fn spinner_large_has_correct_class_test() {
  let rendered = loading.spinner(loading.Large)
  let html = element.to_document_string(rendered)

  string.contains(html, "spinner-lg") |> should.be_true
}

pub fn spinner_is_empty_element_test() {
  let rendered = loading.spinner(loading.Small)
  let html = element.to_document_string(rendered)

  string.contains(html, "><") |> should.be_true
}

pub fn spinner_all_sizes_render_without_crash_test() {
  [loading.Small, loading.Medium, loading.Large]
  |> list.each(fn(size) {
    let rendered = loading.spinner(size)
    let html = element.to_document_string(rendered)
    string.length(html) |> should.not_equal(0)
  })
}

pub fn spinner_size_enum_is_exhaustive_test() {
  let sizes = [loading.Small, loading.Medium, loading.Large]
  list.length(sizes) |> should.equal(3)
}

pub fn loading_function_still_works_test() {
  let rendered = loading.loading("Cargando...")
  let html = element.to_document_string(rendered)

  string.contains(html, "Cargando...") |> should.be_true
  string.contains(html, "loading") |> should.be_true
}

pub fn loading_panel_still_works_test() {
  let rendered = loading.loading_panel("Titulo", "Mensaje")
  let html = element.to_document_string(rendered)

  string.contains(html, "Titulo") |> should.be_true
  string.contains(html, "Mensaje") |> should.be_true
}
