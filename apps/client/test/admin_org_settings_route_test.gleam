import gleam/dict
import gleam/option as opt
import lustre/effect

import domain/api_error.{ApiError}
import domain/org.{type OrgUser, OrgUser}
import domain/org_role
import domain/remote.{Loaded, Loading}
import domain/user.{User}
import scrumbringer_client/client_state
import scrumbringer_client/client_state/admin as admin_state
import scrumbringer_client/client_state/admin/members as admin_members
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/features/admin/org_settings_route
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

fn org_user(id: Int, role: org_role.OrgRole) -> OrgUser {
  OrgUser(
    id: id,
    email: "ana@example.com",
    org_role: role,
    created_at: "2026-01-01T00:00:00Z",
  )
}

pub fn try_update_routes_cache_fetch_and_starts_assignments_fetch_test() {
  let user = org_user(7, org_role.Admin)

  let assert opt.Some(#(next, fx)) =
    org_settings_route.try_update(
      base_model(),
      admin_messages.OrgUsersCacheFetched(Ok([user])),
    )

  let assert Loaded([stored]) = next.admin.members.org_users_cache
  let assert 7 = stored.id
  let assert Ok(Loading) = dict.get(next.admin.assignments.user_projects, 7)
  let assert True = fx != effect.none()
}

pub fn try_update_updates_current_user_after_saved_test() {
  let current =
    User(
      id: 7,
      email: "ana@example.com",
      org_id: 1,
      org_role: org_role.Admin,
      created_at: "2026-01-01T00:00:00Z",
    )
  let updated = org_user(7, org_role.Member)
  let model =
    base_model()
    |> client_state.update_core(fn(core) {
      client_state.CoreModel(..core, user: opt.Some(current))
    })
    |> client_state.update_admin(fn(admin) {
      let members =
        admin_members.Model(
          ..admin.members,
          org_settings_users: Loaded([org_user(7, org_role.Admin)]),
        )
      admin_state.AdminModel(..admin, members: members)
    })

  let assert opt.Some(#(next, fx)) =
    org_settings_route.try_update(
      model,
      admin_messages.OrgSettingsSaved(7, Ok(updated)),
    )

  let assert opt.Some(next_user) = next.core.user
  let assert org_role.Member = next_user.org_role
  let assert True = fx != effect.none()
}

pub fn try_update_handles_unauthorized_before_apply_test() {
  let err =
    ApiError(status: 401, code: "UNAUTHORIZED", message: "Sign in again")

  let assert opt.Some(#(next, fx)) =
    org_settings_route.try_update(
      base_model(),
      admin_messages.OrgUsersCacheFetched(Error(err)),
    )

  let assert client_state.Login = next.core.page
  let assert opt.None = next.core.user
  let assert True = fx == effect.none()
}

pub fn try_update_ignores_non_org_settings_messages_test() {
  let assert opt.None =
    org_settings_route.try_update(
      base_model(),
      admin_messages.MemberAddDialogOpened,
    )
}
