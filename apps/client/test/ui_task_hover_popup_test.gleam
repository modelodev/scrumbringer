import gleam/option.{None, Some}
import gleam/string
import lustre/element

import scrumbringer_client/ui/task_hover_popup

fn assert_contains(text: String, fragment: String) {
  let assert True = string.contains(text, fragment)
}

fn assert_not_contains(text: String, fragment: String) {
  let assert False = string.contains(text, fragment)
}

pub fn task_hover_popup_hides_card_and_description_when_empty_test() {
  let html =
    task_hover_popup.view(task_hover_popup.TaskHoverConfig(
      card_label: "Tarjeta",
      card_title: None,
      status_label: "Estado",
      status_value: "Disponible",
      status_hint: "Lista para reclamar",
      next_action_label: "Siguiente acción",
      next_action_value: "Reclamar a Mis tareas",
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

  assert_not_contains(html, "Tarjeta")
  assert_not_contains(html, "Descripción")
  assert_contains(html, "Estado")
  assert_contains(html, "Disponible")
  assert_contains(html, "Siguiente acción")
  assert_contains(html, "Reclamar a Mis tareas")
  assert_contains(html, "Antigüedad")
  assert_contains(html, "Abrir tarea")
}

pub fn task_hover_popup_renders_card_and_description_test() {
  let html =
    task_hover_popup.view(task_hover_popup.TaskHoverConfig(
      card_label: "Tarjeta",
      card_title: Some("Sprint Planning"),
      status_label: "Estado",
      status_value: "Reclamada",
      status_hint: "Lista para empezar",
      next_action_label: "Siguiente acción",
      next_action_value: "Empezar a trabajar",
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

  assert_contains(html, "Sprint Planning")
  assert_contains(html, "Revisar cambios")
}
