//// Plan-specific Kanban surface.

import lustre/element.{type Element}

import scrumbringer_client/features/views/kanban_board

pub fn view(config: kanban_board.KanbanConfig(msg)) -> Element(msg) {
  kanban_board.view(
    kanban_board.KanbanConfig(
      ..config,
      surface_title: "Kanban",
      surface_purpose: "Cards activas agrupadas por estado inferido del trabajo.",
      purpose: kanban_board.PlanKanban,
    ),
  )
}
