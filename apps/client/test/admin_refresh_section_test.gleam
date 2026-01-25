//// Admin section refresh behavior tests.

import gleam/option as opt
import gleeunit/should
import lustre/effect
import scrumbringer_client/client_state.{
  type Model, Admin, CoreModel, Loading, update_core,
}
import scrumbringer_client/client_update
import scrumbringer_client/permissions

fn base_model() -> Model {
  update_core(client_state.default_model(), fn(core) {
    CoreModel(..core, page: Admin, active_section: permissions.Invites)
  })
}

pub fn refresh_section_fetches_workflows_test() {
  let model =
    update_core(base_model(), fn(core) {
      CoreModel(
        ..core,
        active_section: permissions.Workflows,
        selected_project_id: opt.Some(1),
      )
    })

  let #(next, effects) = client_update.refresh_section_for_test(model)

  // Workflows are now project-scoped only
  next.admin.workflows_project |> should.equal(Loading)

  effects |> should.not_equal(effect.none())
}
