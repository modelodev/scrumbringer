import gleam/dict
import gleam/option as opt
import lustre/effect
import support/domain_fixtures

import domain/org.{type OrgUser, OrgUser}
import domain/org_role.{Admin}
import domain/remote.{Loading}
import scrumbringer_client/assignments_view_mode
import scrumbringer_client/client_state
import scrumbringer_client/features/admin/assignments_route
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/permissions

fn base_model() -> client_state.Model {
  client_state.update_core(client_state.default_model(), fn(core) {
    client_state.CoreModel(
      ..core,
      page: client_state.Admin,
      active_section: permissions.Team,
    )
  })
}

fn user(id: Int) -> OrgUser {
  OrgUser(..domain_fixtures.org_user(id, "ana@example.com"), org_role: Admin)
}

pub fn try_update_routes_assignment_messages_test() {
  let assert opt.Some(#(next, fx)) =
    assignments_route.try_update(
      base_model(),
      admin_messages.AssignmentsViewModeChanged(assignments_view_mode.ByUser),
    )

  let assert assignments_view_mode.ByUser = next.admin.assignments.view_mode
  let assert True = fx != effect.none()
}

pub fn try_update_ignores_non_assignment_messages_test() {
  let assert opt.None =
    assignments_route.try_update(
      base_model(),
      admin_messages.MemberAddDialogOpened,
    )
}

pub fn start_user_projects_fetch_applies_assignment_state_test() {
  let #(next, fx) =
    assignments_route.start_user_projects_fetch(base_model(), [
      user(7),
    ])

  let assert Ok(Loading) = dict.get(next.admin.assignments.user_projects, 7)
  let assert True = fx != effect.none()
}
