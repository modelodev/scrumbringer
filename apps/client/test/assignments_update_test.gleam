import gleeunit/should

import scrumbringer_client/assignments_view_mode
import scrumbringer_client/client_state
import scrumbringer_client/features/assignments/update as assignments_update

pub fn view_mode_change_preserves_search_test() {
  let model =
    client_state.default_model()
    |> client_state.update_admin(fn(admin) {
      client_state.AdminModel(
        ..admin,
        assignments: client_state.AssignmentsModel(
          ..admin.assignments,
          search_input: "alpha",
          search_query: "alpha",
        ),
      )
    })

  let #(next, _fx) =
    assignments_update.handle_assignments_view_mode_changed(
      model,
      assignments_view_mode.ByUser,
    )

  let client_state.AssignmentsModel(
    view_mode: view_mode,
    search_input: search_input,
    search_query: search_query,
    ..,
  ) = next.admin.assignments

  view_mode |> should.equal(assignments_view_mode.ByUser)
  search_input |> should.equal("alpha")
  search_query |> should.equal("alpha")
}
