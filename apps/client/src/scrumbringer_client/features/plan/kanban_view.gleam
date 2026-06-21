//// Plan-specific Kanban surface.

import lustre/element.{type Element}

import scrumbringer_client/features/views/kanban_board

pub fn view(config: kanban_board.KanbanConfig(msg)) -> Element(msg) {
  kanban_board.view(
    kanban_board.KanbanConfig(
      ..config,
      surface_title: "Plan",
      surface_purpose: "Estructura de cards y trabajo preparado.",
      show_task_preview: False,
      allow_task_claim: False,
    ),
  )
}
