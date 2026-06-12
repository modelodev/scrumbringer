import domain/remote.{Loading}
import gleam/option as opt

import scrumbringer_client/client_state
import scrumbringer_client/client_update

fn base_member_model() -> client_state.Model {
  client_state.default_model()
  |> client_state.update_core(fn(core) {
    client_state.CoreModel(..core, page: client_state.Member)
  })
}

pub fn member_refresh_pool_fetches_org_users_cache_for_people_labels_test() {
  let model =
    base_member_model()
    |> client_state.update_core(fn(core) {
      client_state.CoreModel(..core, selected_project_id: opt.None)
    })

  let #(next, _fx) =
    client_update.update(model, client_state.ProjectSelected("2"))

  let assert Loading = next.admin.members.org_users_cache
}
