import gleam/option.{None, Some}
import gleam/string
import gleeunit/should
import lustre/element

import scrumbringer_client/ui/task_hover_popup

pub fn task_hover_popup_hides_card_and_description_when_empty_test() {
  let html =
    task_hover_popup.view(task_hover_popup.TaskHoverConfig(
      card_label: "Tarjeta",
      card_title: None,
      age_label: "Antigüedad",
      age_value: "2d",
      description_label: "Descripción",
      description: "",
      blocked_label: None,
      blocked_items: [],
      blocked_hidden_note: None,
      notes_label: None,
      notes: [],
      open_label: "Abrir tarea",
      on_open: "msg",
    ))
    |> element.to_document_string

  string.contains(html, "Tarjeta") |> should.be_false
  string.contains(html, "Descripción") |> should.be_false
  string.contains(html, "Antigüedad") |> should.be_true
  string.contains(html, "Abrir tarea") |> should.be_true
}

pub fn task_hover_popup_renders_card_and_description_test() {
  let html =
    task_hover_popup.view(task_hover_popup.TaskHoverConfig(
      card_label: "Tarjeta",
      card_title: Some("Sprint Planning"),
      age_label: "Antigüedad",
      age_value: "29d",
      description_label: "Descripción",
      description: "Revisar cambios",
      blocked_label: None,
      blocked_items: [],
      blocked_hidden_note: None,
      notes_label: None,
      notes: [],
      open_label: "Abrir tarea",
      on_open: "msg",
    ))
    |> element.to_document_string

  string.contains(html, "Sprint Planning") |> should.be_true
  string.contains(html, "Revisar cambios") |> should.be_true
}
