import gleam/option

import lustre/effect

import domain/api_error.{ApiError}
import domain/org.{type OrgUser, OrgUser}
import domain/org_role
import domain/remote
import scrumbringer_client/client_state/admin/members as admin_members
import scrumbringer_client/features/admin/member_remove
import scrumbringer_client/features/admin/msg as admin_messages

fn user(id: Int, email: String) -> OrgUser {
  OrgUser(
    id: id,
    email: email,
    org_role: org_role.Member,
    created_at: "2026-01-01T00:00:00Z",
  )
}

fn context(selected_project_id) -> member_remove.Context(String) {
  member_remove.Context(
    selected_project_id: selected_project_id,
    on_member_removed: fn(_result) { "member-removed" },
  )
}

fn feedback_context() -> member_remove.FeedbackContext(String) {
  member_remove.FeedbackContext(
    member_removed: "Member removed",
    on_success_toast: fn(_message) { effect.from(fn(_dispatch) { Nil }) },
  )
}

fn error_feedback_context() -> member_remove.ErrorFeedbackContext(String) {
  member_remove.ErrorFeedbackContext(
    not_permitted: "Not permitted",
    on_warning_toast: fn(_message) { effect.from(fn(_dispatch) { Nil }) },
  )
}

fn update(model: admin_members.Model, msg: admin_messages.Msg) {
  update_with_context(model, msg, context(option.Some(3)))
}

fn update_with_context(
  model: admin_members.Model,
  msg: admin_messages.Msg,
  context: member_remove.Context(String),
) {
  member_remove.try_update(
    model,
    msg,
    context,
    feedback_context(),
    error_feedback_context(),
  )
}

pub fn try_update_remove_clicked_uses_cached_org_user_test() {
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      org_users_cache: remote.Loaded([user(7, "member@example.com")]),
      members_remove_error: option.Some("old"),
    )

  let assert option.Some(member_remove.Update(
    next,
    fx,
    member_remove.NoAuthCheck,
    member_remove.NoRefresh,
  )) = update(model, admin_messages.MemberRemoveClicked(7))

  let assert option.Some(selected) = next.members_remove_confirm
  let assert "member@example.com" = selected.email
  let assert option.None = next.members_remove_error
  let assert True = fx == effect.none()
}

pub fn try_update_remove_clicked_uses_fallback_when_user_missing_test() {
  let assert option.Some(member_remove.Update(
    next,
    fx,
    member_remove.NoAuthCheck,
    member_remove.NoRefresh,
  )) =
    update(admin_members.default_model(), admin_messages.MemberRemoveClicked(9))

  let assert option.Some(selected) = next.members_remove_confirm
  let assert "User #9" = selected.email
  let assert True = fx == effect.none()
}

pub fn try_update_remove_cancelled_clears_dialog_and_error_test() {
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      members_remove_confirm: option.Some(user(7, "member@example.com")),
      members_remove_error: option.Some("old"),
    )

  let assert option.Some(member_remove.Update(
    next,
    fx,
    member_remove.NoAuthCheck,
    member_remove.NoRefresh,
  )) = update(model, admin_messages.MemberRemoveCancelled)

  let assert option.None = next.members_remove_confirm
  let assert option.None = next.members_remove_error
  let assert True = fx == effect.none()
}

pub fn try_update_remove_confirmed_ignores_missing_project_test() {
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      members_remove_confirm: option.Some(user(7, "member@example.com")),
    )

  let assert option.Some(member_remove.Update(
    next,
    fx,
    member_remove.NoAuthCheck,
    member_remove.NoRefresh,
  )) =
    update_with_context(
      model,
      admin_messages.MemberRemoveConfirmed,
      context(option.None),
    )

  let assert False = next.members_remove_in_flight
  let assert True = fx == effect.none()
}

pub fn try_update_remove_confirmed_sets_in_flight_when_valid_test() {
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      members_remove_confirm: option.Some(user(7, "member@example.com")),
      members_remove_error: option.Some("old"),
    )

  let assert option.Some(member_remove.Update(
    next,
    fx,
    member_remove.NoAuthCheck,
    member_remove.NoRefresh,
  )) = update(model, admin_messages.MemberRemoveConfirmed)

  let assert True = next.members_remove_in_flight
  let assert option.None = next.members_remove_error
  let assert False = fx == effect.none()
}

pub fn try_update_removed_ok_closes_dialog_test() {
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      members_remove_confirm: option.Some(user(7, "member@example.com")),
      members_remove_in_flight: True,
      members_remove_error: option.Some("old"),
    )

  let assert option.Some(member_remove.Update(
    next,
    fx,
    member_remove.NoAuthCheck,
    member_remove.RefreshSection,
  )) = update(model, admin_messages.MemberRemoved(Ok(Nil)))

  let assert False = next.members_remove_in_flight
  let assert option.None = next.members_remove_confirm
  let assert option.None = next.members_remove_error
  let assert False = fx == effect.none()
}

pub fn try_update_removed_error_sets_message_test() {
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      members_remove_in_flight: True,
    )
  let err = ApiError(status: 403, code: "FORBIDDEN", message: "backend")

  let assert option.Some(member_remove.Update(
    next,
    fx,
    member_remove.CheckAuth(auth_err),
    member_remove.NoRefresh,
  )) = update(model, admin_messages.MemberRemoved(Error(err)))

  let assert False = next.members_remove_in_flight
  let assert option.Some("Not permitted") = next.members_remove_error
  let assert True = auth_err == err
  let assert False = fx == effect.none()
}

pub fn try_update_remove_clicked_returns_local_update_test() {
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      org_users_cache: remote.Loaded([user(7, "member@example.com")]),
    )

  let assert option.Some(member_remove.Update(
    next,
    fx,
    member_remove.NoAuthCheck,
    member_remove.NoRefresh,
  )) = update(model, admin_messages.MemberRemoveClicked(7))

  let assert option.Some(selected) = next.members_remove_confirm
  let assert 7 = selected.id
  let assert True = fx == effect.none()
}

pub fn try_update_member_removed_ok_requests_refresh_test() {
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      members_remove_confirm: option.Some(user(7, "member@example.com")),
      members_remove_in_flight: True,
    )

  let assert option.Some(member_remove.Update(
    next,
    fx,
    member_remove.NoAuthCheck,
    member_remove.RefreshSection,
  )) = update(model, admin_messages.MemberRemoved(Ok(Nil)))

  let assert False = next.members_remove_in_flight
  let assert option.None = next.members_remove_confirm
  let assert False = fx == effect.none()
}

pub fn try_update_member_removed_forbidden_returns_auth_policy_test() {
  let err = ApiError(status: 403, code: "FORBIDDEN", message: "backend")
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      members_remove_in_flight: True,
    )

  let assert option.Some(member_remove.Update(
    next,
    fx,
    member_remove.CheckAuth(auth_err),
    member_remove.NoRefresh,
  )) = update(model, admin_messages.MemberRemoved(Error(err)))

  let assert option.Some("Not permitted") = next.members_remove_error
  let assert True = auth_err == err
  let assert False = fx == effect.none()
}

pub fn try_update_ignores_non_member_remove_messages_test() {
  let assert option.None =
    update(
      admin_members.default_model(),
      admin_messages.InviteCreateDialogOpened,
    )
}
