import domain/api_error.{ApiError}
import domain/org.{type OrgUser, OrgUser}
import domain/org_role
import domain/project.{ProjectMember}
import domain/project_role
import gleam/option
import lustre/effect

import scrumbringer_client/client_state/admin/members as admin_members
import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/client_state/types as state_types
import scrumbringer_client/features/admin/member_add
import scrumbringer_client/features/admin/msg as admin_messages

fn sample_user(id: Int, email: String) -> OrgUser {
  OrgUser(
    id: id,
    email: email,
    org_role: org_role.Member,
    created_at: "2026-01-01T00:00:00Z",
  )
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

pub fn open_add_dialog_resets_selection_error_and_search_test() {
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      members_add_selected_user: option.Some(sample_user(9, "qa@example.com")),
      members_add_error: option.Some("old error"),
      org_users_search: state_types.OrgUsersSearchLoading("qa", 2),
    )

  let #(next, fx) = member_add.handle_member_add_dialog_opened(model)

  let assert dialog_mode.DialogCreate = next.members_add_dialog_mode
  let assert option.None = next.members_add_selected_user
  let assert option.None = next.members_add_error
  let assert state_types.OrgUsersSearchIdle("", 0) = next.org_users_search
  let assert True = fx == effect.none()
}

pub fn close_add_dialog_resets_selection_error_and_search_test() {
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      members_add_dialog_mode: dialog_mode.DialogCreate,
      members_add_selected_user: option.Some(sample_user(9, "qa@example.com")),
      members_add_error: option.Some("old error"),
      org_users_search: state_types.OrgUsersSearchLoading("qa", 2),
    )

  let #(next, fx) = member_add.handle_member_add_dialog_closed(model)

  let assert dialog_mode.DialogClosed = next.members_add_dialog_mode
  let assert option.None = next.members_add_selected_user
  let assert option.None = next.members_add_error
  let assert state_types.OrgUsersSearchIdle("", 0) = next.org_users_search
  let assert True = fx == effect.none()
}

pub fn role_change_updates_local_role_test() {
  let #(next, fx) =
    member_add.handle_member_add_role_changed(
      admin_members.default_model(),
      project_role.Manager,
    )

  let assert project_role.Manager = next.members_add_role
  let assert True = fx == effect.none()
}

pub fn user_selection_uses_loaded_search_results_test() {
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      org_users_search: state_types.OrgUsersSearchLoaded("qa", 3, [
        sample_user(4, "pm@example.com"),
        sample_user(9, "qa@example.com"),
      ]),
    )

  let #(next, fx) = member_add.handle_member_add_user_selected(model, 9)

  let assert option.Some(user) = next.members_add_selected_user
  let assert 9 = user.id
  let assert True = fx == effect.none()
}

pub fn submit_without_selected_user_sets_local_error_test() {
  let #(next, fx) =
    member_add.handle_member_add_submitted(
      admin_members.default_model(),
      context(),
    )

  let assert False = next.members_add_in_flight
  let assert option.Some("Select a user first") = next.members_add_error
  let assert True = fx == effect.none()
}

pub fn successful_member_add_closes_dialog_and_clears_in_flight_test() {
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      members_add_dialog_mode: dialog_mode.DialogCreate,
      members_add_in_flight: True,
    )

  let #(next, fx) = member_add.handle_member_added_ok(model, feedback_context())

  let assert False = next.members_add_in_flight
  let assert dialog_mode.DialogClosed = next.members_add_dialog_mode
  let assert False = fx == effect.none()
}

pub fn failed_member_add_sets_local_error_test() {
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      members_add_in_flight: True,
    )

  let #(next, fx) = member_add.handle_member_added_error(model, "Not permitted")

  let assert False = next.members_add_in_flight
  let assert option.Some("Not permitted") = next.members_add_error
  let assert True = fx == effect.none()
}

pub fn try_update_dialog_opened_returns_local_update_test() {
  let assert option.Some(member_add.Update(
    next,
    fx,
    member_add.NoAuthCheck,
    member_add.NoRefresh,
  )) =
    member_add.try_update(
      admin_members.default_model(),
      admin_messages.MemberAddDialogOpened,
      context(),
      feedback_context(),
      error_feedback_context(),
    )

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
    member_add.try_update(
      admin_members.default_model(),
      admin_messages.MemberAdded(Ok(member)),
      context(),
      feedback_context(),
      error_feedback_context(),
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
    member_add.try_update(
      admin_members.default_model(),
      admin_messages.MemberAdded(Error(err)),
      context(),
      feedback_context(),
      error_feedback_context(),
    )

  let assert option.Some("Not permitted") = next.members_add_error
  let assert True = auth_err == err
  let assert False = fx == effect.none()
}

pub fn try_update_ignores_non_member_add_messages_test() {
  let assert option.None =
    member_add.try_update(
      admin_members.default_model(),
      admin_messages.InviteCreateDialogOpened,
      context(),
      feedback_context(),
      error_feedback_context(),
    )
}
