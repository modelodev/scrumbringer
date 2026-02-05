//// Task Types feature views.
////
//// Delegates to admin views (Phase 1 modularization).

import gleam/option as opt
import lustre/element.{type Element}

import domain/project.{type Project}
import scrumbringer_client/client_state.{type Model, type Msg}
import scrumbringer_client/features/admin/view as admin_view

/// Task types management view (admin section).
pub fn view(model: Model, selected_project: opt.Option(Project)) -> Element(Msg) {
  admin_view.view_task_types(model, selected_project)
}
