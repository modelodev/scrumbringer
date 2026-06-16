//// Tests for org settings local update handlers.

import gleam/option as opt
import lustre/effect

import domain/api_error.{ApiError}
import domain/org.{type OrgUser, OrgUser}
import domain/org_role
import domain/remote.{Failed, Loaded}
import domain/user.{type User, User}
import scrumbringer_client/client_state/admin/members as admin_members
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/features/admin/org_settings

fn make_user(id: Int, role: org_role.OrgRole) -> User {
  User(
    id: id,
    email: "user@example.com",
    org_id: 1,
    org_role: role,
    created_at: "2024-01-01T00:00:00Z",
  )
}

fn make_org_user(id: Int, role: org_role.OrgRole) -> OrgUser {
  OrgUser(
    id: id,
    email: "user@example.com",
    org_role: role,
    created_at: "2024-01-01T00:00:00Z",
  )
}

fn context() -> org_settings.Context(String) {
  org_settings.Context(
    on_org_settings_saved: fn(_, _) { "saved" },
    on_org_settings_deleted: fn(_) { "deleted" },
  )
}

fn try_feedback_context() -> org_settings.FeedbackContext(String) {
  org_settings.FeedbackContext(
    role_updated: "Role updated",
    user_deleted: "User deleted",
    not_permitted: "Not permitted",
    on_success_toast: fn(_) { effect.from(fn(_dispatch) { Nil }) },
    on_warning_toast: fn(_) { effect.from(fn(_dispatch) { Nil }) },
  )
}

fn update(
  model: admin_members.Model,
  inner: admin_messages.Msg,
) -> org_settings.Update(String) {
  let assert opt.Some(update) =
    org_settings.try_update(model, inner, context(), try_feedback_context())
  update
}

pub fn current_user_after_saved_updates_matching_user_test() {
  let current_user = make_user(42, org_role.Member)
  let updated_org_user = make_org_user(42, org_role.Admin)

  let assert opt.Some(user) =
    org_settings.current_user_after_saved(
      opt.Some(current_user),
      updated_org_user,
    )
  let assert org_role.Admin = user.org_role
}

pub fn current_user_after_saved_keeps_different_user_test() {
  let current_user = make_user(42, org_role.Admin)
  let updated_org_user = make_org_user(99, org_role.Member)

  let assert opt.Some(user) =
    org_settings.current_user_after_saved(
      opt.Some(current_user),
      updated_org_user,
    )
  let assert 42 = user.id
  let assert org_role.Admin = user.org_role
}

pub fn current_user_after_saved_handles_none_user_test() {
  let updated_org_user = make_org_user(42, org_role.Admin)

  let assert opt.None =
    org_settings.current_user_after_saved(opt.None, updated_org_user)
}

pub fn saved_ok_updates_org_settings_users_list_test() {
  let existing_user = make_org_user(42, org_role.Member)
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      org_settings_users: Loaded([existing_user]),
    )
  let updated_org_user = make_org_user(42, org_role.Admin)

  let org_settings.Update(next, fx, _, _) =
    update(model, admin_messages.OrgSettingsSaved(42, Ok(updated_org_user)))

  let assert Loaded([user]) = next.org_settings_users
  let assert org_role.Admin = user.org_role
  let assert True = fx != effect.none()
}

pub fn saved_ok_updates_org_users_cache_test() {
  let existing_user = make_org_user(42, org_role.Member)
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      org_users_cache: Loaded([existing_user]),
    )
  let updated_org_user = make_org_user(42, org_role.Admin)

  let org_settings.Update(next, fx, _, _) =
    update(model, admin_messages.OrgSettingsSaved(42, Ok(updated_org_user)))

  let assert Loaded([user]) = next.org_users_cache
  let assert org_role.Admin = user.org_role
  let assert True = fx != effect.none()
}

pub fn saved_ok_clears_in_flight_and_error_state_test() {
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      org_settings_save_in_flight: True,
      org_settings_error: opt.Some("Previous error"),
      org_settings_error_user_id: opt.Some(42),
    )
  let updated_org_user = make_org_user(42, org_role.Admin)

  let org_settings.Update(next, fx, _, _) =
    update(model, admin_messages.OrgSettingsSaved(42, Ok(updated_org_user)))

  let assert False = next.org_settings_save_in_flight
  let assert opt.None = next.org_settings_error
  let assert opt.None = next.org_settings_error_user_id
  let assert True = fx != effect.none()
}

pub fn role_changed_triggers_save_when_role_diff_test() {
  let user = make_org_user(1, org_role.Member)
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      org_settings_users: Loaded([user]),
    )

  let org_settings.Update(next, fx, _, _) =
    update(model, admin_messages.OrgSettingsRoleChanged(1, org_role.Admin))

  let assert True = next.org_settings_save_in_flight
  let assert opt.None = next.org_settings_error
  let assert opt.None = next.org_settings_error_user_id
  let assert False = fx == effect.none()
}

pub fn role_changed_noop_when_role_is_same_test() {
  let user = make_org_user(1, org_role.Member)
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      org_settings_users: Loaded([user]),
    )

  let org_settings.Update(next, fx, _, _) =
    update(model, admin_messages.OrgSettingsRoleChanged(1, org_role.Member))

  let assert False = next.org_settings_save_in_flight
  let assert True = fx == effect.none()
}

pub fn role_changed_ignored_when_in_flight_test() {
  let user = make_org_user(1, org_role.Member)
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      org_settings_users: Loaded([user]),
      org_settings_save_in_flight: True,
    )

  let org_settings.Update(next, fx, _, _) =
    update(model, admin_messages.OrgSettingsRoleChanged(1, org_role.Admin))

  let assert True = next.org_settings_save_in_flight
  let assert True = fx == effect.none()
}

pub fn delete_clicked_uses_cache_or_fallback_test() {
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      org_users_cache: Loaded([make_org_user(9, org_role.Member)]),
    )

  let org_settings.Update(next, fx, _, _) =
    update(model, admin_messages.OrgSettingsDeleteClicked(9))

  let assert opt.Some(user) = next.org_settings_delete_confirm
  let assert 9 = user.id
  let assert opt.None = next.org_settings_delete_error
  let assert True = fx == effect.none()
}

pub fn delete_confirmed_sets_in_flight_test() {
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      org_settings_delete_confirm: opt.Some(make_org_user(9, org_role.Member)),
    )

  let org_settings.Update(next, fx, _, _) =
    update(model, admin_messages.OrgSettingsDeleteConfirmed)

  let assert True = next.org_settings_delete_in_flight
  let assert opt.None = next.org_settings_delete_error
  let assert False = fx == effect.none()
}

pub fn deleted_ok_removes_user_from_lists_test() {
  let removed = make_org_user(9, org_role.Member)
  let kept = make_org_user(10, org_role.Admin)
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      org_settings_users: Loaded([removed, kept]),
      org_users_cache: Loaded([removed, kept]),
      org_settings_delete_confirm: opt.Some(removed),
      org_settings_delete_in_flight: True,
      org_settings_delete_error: opt.Some("old error"),
    )

  let org_settings.Update(next, fx, _, _) =
    update(model, admin_messages.OrgSettingsDeleted(Ok(Nil)))

  let assert Loaded([settings_user]) = next.org_settings_users
  let assert 10 = settings_user.id
  let assert Loaded([cache_user]) = next.org_users_cache
  let assert 10 = cache_user.id
  let assert False = next.org_settings_delete_in_flight
  let assert opt.None = next.org_settings_delete_confirm
  let assert opt.None = next.org_settings_delete_error
  let assert True = fx != effect.none()
}

pub fn fetched_errors_store_failed_remote_test() {
  let err = ApiError(status: 500, code: "ERR", message: "failed")

  let org_settings.Update(next_cache, _, _, _) =
    update(
      admin_members.default_model(),
      admin_messages.OrgUsersCacheFetched(Error(err)),
    )
  let org_settings.Update(next_settings, _, _, _) =
    update(
      admin_members.default_model(),
      admin_messages.OrgSettingsUsersFetched(Error(err)),
    )

  let assert Failed(_) = next_cache.org_users_cache
  let assert Failed(_) = next_settings.org_settings_users
}

pub fn users_fetched_forbidden_error_emits_warning_feedback_test() {
  let err = ApiError(status: 403, code: "FORBIDDEN", message: "backend")

  let org_settings.Update(next, fx, _, _) =
    update(
      admin_members.default_model(),
      admin_messages.OrgSettingsUsersFetched(Error(err)),
    )

  let assert Failed(_) = next.org_settings_users
  let assert True = fx != effect.none()
}

pub fn saved_forbidden_error_clears_in_flight_and_emits_feedback_test() {
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      org_settings_save_in_flight: True,
    )

  let org_settings.Update(next, fx, _, _) =
    update(
      model,
      admin_messages.OrgSettingsSaved(
        42,
        Error(ApiError(status: 403, code: "FORBIDDEN", message: "backend")),
      ),
    )

  let assert False = next.org_settings_save_in_flight
  let assert opt.None = next.org_settings_error
  let assert True = fx != effect.none()
}

pub fn saved_generic_error_sets_inline_error_without_feedback_test() {
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      org_settings_save_in_flight: True,
    )

  let org_settings.Update(next, fx, _, _) =
    update(
      model,
      admin_messages.OrgSettingsSaved(
        42,
        Error(ApiError(status: 500, code: "ERR", message: "Boom")),
      ),
    )

  let assert False = next.org_settings_save_in_flight
  let assert opt.Some(42) = next.org_settings_error_user_id
  let assert opt.Some("Boom") = next.org_settings_error
  let assert True = fx == effect.none()
}

pub fn deleted_forbidden_error_sets_local_message_and_feedback_test() {
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      org_settings_delete_in_flight: True,
    )

  let org_settings.Update(next, fx, _, _) =
    update(
      model,
      admin_messages.OrgSettingsDeleted(
        Error(ApiError(status: 403, code: "FORBIDDEN", message: "backend")),
      ),
    )

  let assert False = next.org_settings_delete_in_flight
  let assert opt.Some("Not permitted") = next.org_settings_delete_error
  let assert True = fx != effect.none()
}

pub fn deleted_generic_error_sets_local_message_without_feedback_test() {
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      org_settings_delete_in_flight: True,
    )

  let org_settings.Update(next, fx, _, _) =
    update(
      model,
      admin_messages.OrgSettingsDeleted(
        Error(ApiError(status: 500, code: "ERR", message: "Boom")),
      ),
    )

  let assert False = next.org_settings_delete_in_flight
  let assert opt.Some("Boom") = next.org_settings_delete_error
  let assert True = fx == effect.none()
}

pub fn try_update_org_users_cache_ok_requests_assignments_fetch_test() {
  let users = [make_org_user(42, org_role.Member)]

  let assert opt.Some(org_settings.Update(
    next,
    fx,
    org_settings.NoAuthCheck,
    org_settings.StartAssignmentsFetch(policy_users),
  )) =
    org_settings.try_update(
      admin_members.default_model(),
      admin_messages.OrgUsersCacheFetched(Ok(users)),
      context(),
      try_feedback_context(),
    )

  let assert Loaded([user]) = next.org_users_cache
  let assert 42 = user.id
  let assert True = policy_users == users
  let assert True = fx == effect.none()
}

pub fn try_update_org_users_cache_error_returns_auth_policy_test() {
  let err = ApiError(status: 401, code: "UNAUTHORIZED", message: "auth")

  let assert opt.Some(org_settings.Update(
    next,
    fx,
    org_settings.CheckAuth(auth_err),
    org_settings.NoRootPolicy,
  )) =
    org_settings.try_update(
      admin_members.default_model(),
      admin_messages.OrgUsersCacheFetched(Error(err)),
      context(),
      try_feedback_context(),
    )

  let assert Failed(_) = next.org_users_cache
  let assert True = auth_err == err
  let assert True = fx == effect.none()
}

pub fn try_update_org_settings_saved_ok_requests_current_user_update_test() {
  let updated = make_org_user(42, org_role.Admin)

  let assert opt.Some(org_settings.Update(
    next,
    fx,
    org_settings.NoAuthCheck,
    org_settings.UpdateCurrentUser(policy_user),
  )) =
    org_settings.try_update(
      admin_members.default_model(),
      admin_messages.OrgSettingsSaved(42, Ok(updated)),
      context(),
      try_feedback_context(),
    )

  let assert False = next.org_settings_save_in_flight
  let assert True = policy_user == updated
  let assert True = fx != effect.none()
}

pub fn try_update_org_settings_deleted_error_returns_auth_policy_test() {
  let err = ApiError(status: 403, code: "FORBIDDEN", message: "backend")
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      org_settings_delete_in_flight: True,
    )

  let assert opt.Some(org_settings.Update(
    next,
    fx,
    org_settings.CheckAuth(auth_err),
    org_settings.NoRootPolicy,
  )) =
    org_settings.try_update(
      model,
      admin_messages.OrgSettingsDeleted(Error(err)),
      context(),
      try_feedback_context(),
    )

  let assert False = next.org_settings_delete_in_flight
  let assert opt.Some("Not permitted") = next.org_settings_delete_error
  let assert True = auth_err == err
  let assert True = fx != effect.none()
}

pub fn try_update_ignores_non_org_settings_messages_test() {
  let assert opt.None =
    org_settings.try_update(
      admin_members.default_model(),
      admin_messages.InviteCreateDialogOpened,
      context(),
      try_feedback_context(),
    )
}
