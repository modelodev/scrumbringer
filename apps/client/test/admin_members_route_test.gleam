import gleam/list
import gleam/option as opt
import lustre/effect

import domain/api_error.{ApiError}
import domain/project.{ProjectMember}
import domain/project_role
import domain/remote.{Loaded}
import scrumbringer_client/client_state
import scrumbringer_client/features/admin/members_route
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/permissions

fn base_model() -> client_state.Model {
  client_state.update_core(client_state.default_model(), fn(core) {
    client_state.CoreModel(
      ..core,
      page: client_state.Admin,
      active_section: permissions.Team,
      selected_project_id: opt.Some(3),
    )
  })
}

fn no_refresh(model: client_state.Model) {
  #(model, effect.none())
}

fn sample_member(user_id: Int) {
  ProjectMember(
    user_id: user_id,
    role: project_role.Member,
    created_at: "2026-01-01T00:00:00Z",
    claimed_count: 0,
  )
}

pub fn try_update_routes_member_list_messages_test() {
  let members = [sample_member(7), sample_member(8)]

  let assert opt.Some(#(next, fx)) =
    members_route.try_update(
      base_model(),
      admin_messages.MembersFetched(Ok(members)),
      no_refresh,
    )

  let assert Loaded(stored) = next.admin.members.members
  let assert [7, 8] = list.map(stored, fn(member) { member.user_id })
  let assert True = fx != effect.none()
}

pub fn try_update_handles_unauthorized_before_apply_test() {
  let err =
    ApiError(status: 401, code: "UNAUTHORIZED", message: "Sign in again")

  let assert opt.Some(#(next, fx)) =
    members_route.try_update(
      base_model(),
      admin_messages.MembersFetched(Error(err)),
      no_refresh,
    )

  let assert client_state.Login = next.core.page
  let assert opt.None = next.core.user
  let assert True = fx == effect.none()
}

pub fn try_update_ignores_non_member_messages_test() {
  let assert opt.None =
    members_route.try_update(
      base_model(),
      admin_messages.ProjectCreateDialogOpened,
      no_refresh,
    )
}
