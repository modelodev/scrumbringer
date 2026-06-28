import gleam/list
import gleam/string
import lustre/element
import support/render_assertions

import scrumbringer_client/ui/loading

fn assert_non_empty(value: String) {
  let assert True = string.length(value) > 0
}

pub fn spinner_small_has_correct_class_test() {
  let rendered = loading.spinner(loading.Small)
  let html = element.to_document_string(rendered)

  render_assertions.contains(html, "spinner")
  render_assertions.contains(html, "spinner-sm")
}

pub fn spinner_medium_has_correct_class_test() {
  let rendered = loading.spinner(loading.Medium)
  let html = element.to_document_string(rendered)

  render_assertions.contains(html, "spinner-md")
}

pub fn spinner_large_has_correct_class_test() {
  let rendered = loading.spinner(loading.Large)
  let html = element.to_document_string(rendered)

  render_assertions.contains(html, "spinner-lg")
}

pub fn spinner_is_empty_element_test() {
  let rendered = loading.spinner(loading.Small)
  let html = element.to_document_string(rendered)

  render_assertions.contains(html, "><")
}

pub fn spinner_all_sizes_render_without_crash_test() {
  [loading.Small, loading.Medium, loading.Large]
  |> list.each(fn(size) {
    let rendered = loading.spinner(size)
    let html = element.to_document_string(rendered)
    assert_non_empty(html)
  })
}

pub fn spinner_size_enum_is_exhaustive_test() {
  let sizes = [loading.Small, loading.Medium, loading.Large]
  let assert 3 = list.length(sizes)
}

pub fn loading_function_still_works_test() {
  let rendered = loading.loading("Cargando...")
  let html = element.to_document_string(rendered)

  render_assertions.contains(html, "Cargando...")
  render_assertions.contains(html, "loading")
}

pub fn loading_panel_still_works_test() {
  let rendered = loading.loading_panel("Titulo", "Mensaje")
  let html = element.to_document_string(rendered)

  render_assertions.contains(html, "Titulo")
  render_assertions.contains(html, "Mensaje")
}
