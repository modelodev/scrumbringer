import domain/api_error.{ApiError}
import domain/org.{type OrgUser}
import domain/project.{ProjectMember}
import domain/project_role
import gleam/option
import lustre/effect
import support/domain_fixtures

import scrumbringer_client/client_state/admin/members as admin_members
import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/features/admin/member_add
import scrumbringer_client/features/admin/msg as admin_messages

fn sample_user(id: Int, email: String) -> OrgUser {
  domain_fixtures.org_user(id, email)
}

fn context() -> member_add.Context(String) {
  member_add.Context(
    selected_project_id: option.Some(8),
    select_user_first: "Select a user first",
    on_member_added: fn(_) { "member-added" },
  )
}

fn feedback_context() -> member_add.FeedbackContext(String) {
  member_add.FeedbackContext(
    member_added: "Member added",
    on_success_toast: fn(_message) { effect.from(fn(_dispatch) { Nil }) },
  )
}

fn error_feedback_context() -> member_add.ErrorFeedbackContext(String) {
  member_add.ErrorFeedbackContext(
    not_permitted: "Not permitted",
    on_warning_toast: fn(_message) { effect.from(fn(_dispatch) { Nil }) },
  )
}

fn update(model: admin_members.Model, msg: admin_messages.Msg) {
  member_add.try_update(
    model,
    msg,
    context(),
    feedback_context(),
    error_feedback_context(),
  )
}

pub fn try_update_open_add_dialog_resets_selection_error_and_search_test() {
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      members_add_selected_user: option.Some(sample_user(9, "qa@example.com")),
      members_add_error: option.Some("old error"),
      org_users_search: admin_members.OrgUsersSearchLoading("qa", 2),
    )

  let assert option.Some(member_add.Update(
    next,
    fx,
    member_add.NoAuthCheck,
    member_add.NoRefresh,
  )) = update(model, admin_messages.MemberAddDialogOpened)

  let assert dialog_mode.DialogCreate = next.members_add_dialog_mode
  let assert option.None = next.members_add_selected_user
  let assert option.None = next.members_add_error
  let assert admin_members.OrgUsersSearchIdle("", 0) = next.org_users_search
  let assert True = fx == effect.none()
}

pub fn try_update_close_add_dialog_resets_selection_error_and_search_test() {
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      members_add_dialog_mode: dialog_mode.DialogCreate,
      members_add_selected_user: option.Some(sample_user(9, "qa@example.com")),
      members_add_error: option.Some("old error"),
      org_users_search: admin_members.OrgUsersSearchLoading("qa", 2),
    )

  let assert option.Some(member_add.Update(
    next,
    fx,
    member_add.NoAuthCheck,
    member_add.NoRefresh,
  )) = update(model, admin_messages.MemberAddDialogClosed)

  let assert dialog_mode.DialogClosed = next.members_add_dialog_mode
  let assert option.None = next.members_add_selected_user
  let assert option.None = next.members_add_error
  let assert admin_members.OrgUsersSearchIdle("", 0) = next.org_users_search
  let assert True = fx == effect.none()
}

pub fn try_update_role_change_updates_local_role_test() {
  let assert option.Some(member_add.Update(
    next,
    fx,
    member_add.NoAuthCheck,
    member_add.NoRefresh,
  )) =
    update(
      admin_members.default_model(),
      admin_messages.MemberAddRoleChanged(project_role.Manager),
    )

  let assert project_role.Manager = next.members_add_role
  let assert True = fx == effect.none()
}

pub fn try_update_user_selection_uses_loaded_search_results_test() {
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      org_users_search: admin_members.OrgUsersSearchLoaded("qa", 3, [
        sample_user(4, "pm@example.com"),
        sample_user(9, "qa@example.com"),
      ]),
    )

  let assert option.Some(member_add.Update(
    next,
    fx,
    member_add.NoAuthCheck,
    member_add.NoRefresh,
  )) = update(model, admin_messages.MemberAddUserSelected(9))

  let assert option.Some(user) = next.members_add_selected_user
  let assert 9 = user.id
  let assert True = fx == effect.none()
}

pub fn try_update_submit_without_selected_user_sets_local_error_test() {
  let assert option.Some(member_add.Update(
    next,
    fx,
    member_add.NoAuthCheck,
    member_add.NoRefresh,
  )) = update(admin_members.default_model(), admin_messages.MemberAddSubmitted)

  let assert False = next.members_add_in_flight
  let assert option.Some("Select a user first") = next.members_add_error
  let assert True = fx == effect.none()
}

pub fn try_update_successful_member_add_closes_dialog_and_clears_in_flight_test() {
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      members_add_dialog_mode: dialog_mode.DialogCreate,
      members_add_in_flight: True,
    )
  let member =
    ProjectMember(
      user_id: 9,
      role: project_role.Member,
      created_at: "2026-01-01T00:00:00Z",
      claimed_count: 0,
    )

  let assert option.Some(member_add.Update(
    next,
    fx,
    member_add.NoAuthCheck,
    member_add.RefreshSection,
  )) = update(model, admin_messages.MemberAdded(Ok(member)))

  let assert False = next.members_add_in_flight
  let assert dialog_mode.DialogClosed = next.members_add_dialog_mode
  let assert False = fx == effect.none()
}

pub fn try_update_failed_member_add_sets_local_error_test() {
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      members_add_in_flight: True,
    )
  let err = ApiError(status: 403, code: "FORBIDDEN", message: "backend")

  let assert option.Some(member_add.Update(
    next,
    fx,
    member_add.CheckAuth(auth_err),
    member_add.NoRefresh,
  )) = update(model, admin_messages.MemberAdded(Error(err)))

  let assert False = next.members_add_in_flight
  let assert option.Some("Not permitted") = next.members_add_error
  let assert True = auth_err == err
  let assert False = fx == effect.none()
}

pub fn try_update_dialog_opened_returns_local_update_test() {
  let assert option.Some(member_add.Update(
    next,
    fx,
    member_add.NoAuthCheck,
    member_add.NoRefresh,
  )) =
    update(admin_members.default_model(), admin_messages.MemberAddDialogOpened)

  let assert dialog_mode.DialogCreate = next.members_add_dialog_mode
  let assert True = fx == effect.none()
}

pub fn try_update_member_added_ok_requests_refresh_test() {
  let member =
    ProjectMember(
      user_id: 9,
      role: project_role.Member,
      created_at: "2026-01-01T00:00:00Z",
      claimed_count: 0,
    )

  let assert option.Some(member_add.Update(
    next,
    fx,
    member_add.NoAuthCheck,
    member_add.RefreshSection,
  )) =
    update(
      admin_members.default_model(),
      admin_messages.MemberAdded(Ok(member)),
    )

  let assert dialog_mode.DialogClosed = next.members_add_dialog_mode
  let assert False = fx == effect.none()
}

pub fn try_update_member_added_forbidden_returns_auth_policy_test() {
  let err = ApiError(status: 403, code: "FORBIDDEN", message: "backend")

  let assert option.Some(member_add.Update(
    next,
    fx,
    member_add.CheckAuth(auth_err),
    member_add.NoRefresh,
  )) =
    update(
      admin_members.default_model(),
      admin_messages.MemberAdded(Error(err)),
    )

  let assert option.Some("Not permitted") = next.members_add_error
  let assert True = auth_err == err
  let assert False = fx == effect.none()
}

pub fn try_update_ignores_non_member_add_messages_test() {
  let assert option.None =
    update(
      admin_members.default_model(),
      admin_messages.InviteCreateDialogOpened,
    )
}
