import gleam/option.{None, Some}
import support/render_assertions

import scrumbringer_client/ui/task_hover_popup

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
    |> render_assertions.html

  render_assertions.not_contains(html, "Tarjeta")
  render_assertions.not_contains(html, "Descripción")
  render_assertions.contains(html, "Estado")
  render_assertions.contains(html, "Disponible")
  render_assertions.contains(html, "Siguiente acción")
  render_assertions.contains(html, "Reclamar a Mis tareas")
  render_assertions.contains(html, "Antigüedad")
  render_assertions.contains(html, "Abrir tarea")
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
    |> render_assertions.html

  render_assertions.contains(html, "Sprint Planning")
  render_assertions.contains(html, "Revisar cambios")
}
