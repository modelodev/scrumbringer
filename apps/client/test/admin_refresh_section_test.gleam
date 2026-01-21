//// Admin section refresh behavior tests.

import gleam/option as opt
import gleeunit/should
import lustre/effect
import scrumbringer_client/client_state.{type Model, Admin, Loading, Model}
import scrumbringer_client/client_update
import scrumbringer_client/permissions

fn base_model() -> Model {
  Model(
    ..client_state.default_model(),
    page: Admin,
    active_section: permissions.Invites,
  )
}

pub fn refresh_section_fetches_workflows_test() {
  let model =
    Model(
      ..base_model(),
      active_section: permissions.Workflows,
      selected_project_id: opt.Some(1),
    )

  let #(next, effects) = client_update.refresh_section_for_test(model)

  // Workflows are now project-scoped only
  next.workflows_project |> should.equal(Loading)

  effects |> should.not_equal(effect.none())
}
