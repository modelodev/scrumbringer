import domain/api_error.{ApiError}
import domain/project.{ProjectMember}
import domain/project_role.{type ProjectRole, Manager, Member}
import domain/remote.{Loaded, NotAsked}
import gleam/option
import lustre/effect

import scrumbringer_client/api/projects as api_projects
import scrumbringer_client/client_state/admin/members as admin_members
import scrumbringer_client/features/admin/member_role
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/ui/toast

fn sample_member(user_id: Int, role: ProjectRole) {
  ProjectMember(
    user_id: user_id,
    role: role,
    created_at: "2026-01-01T00:00:00Z",
    claimed_count: 0,
  )
}

fn context() -> member_role.Context(String) {
  member_role.Context(
    selected_project_id: option.Some(3),
    on_member_role_changed: fn(_) { "role-changed" },
  )
}

fn no_project_context() -> member_role.Context(String) {
  member_role.Context(
    selected_project_id: option.None,
    on_member_role_changed: fn(_) { "role-changed" },
  )
}

fn feedback_context() -> member_role.FeedbackContext(String) {
  member_role.FeedbackContext(
    role_updated: "Role updated",
    cannot_demote_last_manager: "Cannot demote last manager",
    on_success_toast: fn(_) { effect.from(fn(_dispatch) { Nil }) },
    on_warning_toast: fn(_) { effect.from(fn(_dispatch) { Nil }) },
    on_error_toast: fn(_) { effect.from(fn(_dispatch) { Nil }) },
  )
}

fn update(model: admin_members.Model, msg: admin_messages.Msg) {
  update_with_context(model, msg, context())
}

fn update_with_context(
  model: admin_members.Model,
  msg: admin_messages.Msg,
  context: member_role.Context(String),
) {
  member_role.try_update(model, msg, context, feedback_context())
}

pub fn input_value_parses_known_project_roles_test() {
  let assert Ok(Manager) = member_role.input_value("manager")
  let assert Ok(Member) = member_role.input_value("member")
}

pub fn input_value_rejects_unknown_project_roles_test() {
  let assert Error(_) = member_role.input_value("admin")
}

pub fn changed_input_value_rejects_invalid_or_unchanged_values_test() {
  let assert Ok(Manager) = member_role.changed_input_value("manager", Member)
  let assert Error(_) = member_role.changed_input_value("member", Member)
  let assert Error(_) = member_role.changed_input_value("owner", Member)
}

pub fn try_update_role_change_request_without_project_is_noop_test() {
  let assert option.Some(member_role.Update(next, fx, member_role.NoAuthCheck)) =
    update_with_context(
      admin_members.default_model(),
      admin_messages.MemberRoleChangeRequested(9, Manager),
      no_project_context(),
    )

  let assert NotAsked = next.members
  let assert True = fx == effect.none()
}

pub fn try_update_role_change_success_updates_only_matching_member_test() {
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      members: Loaded([
        sample_member(9, Member),
        sample_member(10, Manager),
      ]),
    )
  let result =
    api_projects.RoleChangeResult(
      user_id: 9,
      email: "qa@example.com",
      role: Manager,
      previous_role: Member,
    )

  let assert option.Some(member_role.Update(next, fx, member_role.NoAuthCheck)) =
    update(model, admin_messages.MemberRoleChanged(Ok(result)))

  let assert Loaded(members) = next.members
  let assert [updated, untouched] = members
  let assert Manager = updated.role
  let assert Manager = untouched.role
  let assert True = fx != effect.none()
}

pub fn role_change_422_error_is_last_manager_warning_test() {
  let #(message, variant) =
    member_role.error_feedback(
      ApiError(status: 422, code: "LAST_MANAGER", message: "backend"),
      "Cannot demote last manager",
    )

  let assert "Cannot demote last manager" = message
  let assert toast.Warning = variant
}

pub fn role_change_generic_error_uses_backend_error_test() {
  let #(message, variant) =
    member_role.error_feedback(
      ApiError(status: 500, code: "ERR", message: "boom"),
      "Cannot demote last manager",
    )

  let assert "boom" = message
  let assert toast.Error = variant
}

pub fn try_update_role_change_request_returns_local_update_test() {
  let assert option.Some(member_role.Update(next, _fx, member_role.NoAuthCheck)) =
    update(
      admin_members.default_model(),
      admin_messages.MemberRoleChangeRequested(9, Manager),
    )

  let assert NotAsked = next.members
}

pub fn try_update_role_changed_ok_updates_matching_member_test() {
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      members: Loaded([
        sample_member(9, Member),
        sample_member(10, Manager),
      ]),
    )
  let result =
    api_projects.RoleChangeResult(
      user_id: 9,
      email: "qa@example.com",
      role: Manager,
      previous_role: Member,
    )

  let assert option.Some(member_role.Update(next, fx, member_role.NoAuthCheck)) =
    update(model, admin_messages.MemberRoleChanged(Ok(result)))

  let assert Loaded([updated, _]) = next.members
  let assert Manager = updated.role
  let assert True = fx != effect.none()
}

pub fn try_update_role_changed_error_returns_auth_policy_test() {
  let err = ApiError(status: 422, code: "LAST_MANAGER", message: "backend")

  let assert option.Some(member_role.Update(
    next,
    fx,
    member_role.CheckAuth(auth_err),
  )) =
    update(
      admin_members.default_model(),
      admin_messages.MemberRoleChanged(Error(err)),
    )

  let assert NotAsked = next.members
  let assert True = auth_err == err
  let assert True = fx != effect.none()
}

pub fn try_update_ignores_non_member_role_messages_test() {
  let assert option.None =
    update(
      admin_members.default_model(),
      admin_messages.InviteCreateDialogOpened,
    )
}
