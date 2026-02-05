//// Workflows feature views.
////
//// Delegates to admin views (Phase 1 modularization).

import gleam/option as opt
import lustre/element.{type Element}

import domain/project.{type Project}
import scrumbringer_client/client_state.{type Model, type Msg}
import scrumbringer_client/features/admin/view as admin_view

/// Workflows management view (admin section).
pub fn view_workflows(
  model: Model,
  selected_project: opt.Option(Project),
) -> Element(Msg) {
  admin_view.view_workflows(model, selected_project)
}

/// Task templates management view (admin section).
pub fn view_task_templates(
  model: Model,
  selected_project: opt.Option(Project),
) -> Element(Msg) {
  admin_view.view_task_templates(model, selected_project)
}

/// Rule metrics view (admin section).
pub fn view_rule_metrics(model: Model) -> Element(Msg) {
  admin_view.view_rule_metrics(model)
}
