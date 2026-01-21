//// Tests for org settings handlers.
////
//// Specifically tests the fix for:
//// - When admin changes their own role, model.user should be updated

import gleam/option as opt
import gleeunit/should
import lustre/effect

import domain/org.{type OrgUser, OrgUser}
import domain/org_role
import domain/user.{type User, User}
import scrumbringer_client/client_state.{type Model, Admin, Loaded, Model}
import scrumbringer_client/features/admin/org_settings
import scrumbringer_client/permissions

// =============================================================================
// Test Helpers
// =============================================================================

fn base_model() -> Model {
  Model(..client_state.default_model(), page: Admin)
}

fn make_user(id: Int, role: org_role.OrgRole) -> User {
  User(
    id: id,
    email: "user" <> "@example.com",
    org_id: 1,
    org_role: role,
    created_at: "2024-01-01T00:00:00Z",
  )
}

fn make_org_user(id: Int, role: String) -> OrgUser {
  OrgUser(
    id: id,
    email: "user" <> "@example.com",
    org_role: role,
    created_at: "2024-01-01T00:00:00Z",
  )
}

// =============================================================================
// handle_org_settings_saved_ok: Current User Role Update Tests
// =============================================================================

pub fn saved_ok_updates_current_user_role_to_admin_test() {
  // Setup: current user is member (id=42)
  let current_user = make_user(42, org_role.Member)
  let model =
    Model(
      ..base_model(),
      user: opt.Some(current_user),
      active_section: permissions.OrgSettings,
    )

  // Action: admin updates user 42's role to admin
  let updated_org_user = make_org_user(42, "admin")
  let #(next, _effect) = org_settings.handle_org_settings_saved_ok(model, updated_org_user)

  // Assert: model.user should now have Admin role
  case next.user {
    opt.Some(u) -> u.org_role |> should.equal(org_role.Admin)
    opt.None -> should.fail()
  }
}

pub fn saved_ok_updates_current_user_role_to_member_test() {
  // Setup: current user is admin (id=42)
  let current_user = make_user(42, org_role.Admin)
  let model =
    Model(
      ..base_model(),
      user: opt.Some(current_user),
      active_section: permissions.OrgSettings,
    )

  // Action: admin updates user 42's role to member
  let updated_org_user = make_org_user(42, "member")
  let #(next, _effect) = org_settings.handle_org_settings_saved_ok(model, updated_org_user)

  // Assert: model.user should now have Member role
  case next.user {
    opt.Some(u) -> u.org_role |> should.equal(org_role.Member)
    opt.None -> should.fail()
  }
}

pub fn saved_ok_does_not_change_user_when_different_id_test() {
  // Setup: current user is admin (id=42)
  let current_user = make_user(42, org_role.Admin)
  let model =
    Model(
      ..base_model(),
      user: opt.Some(current_user),
      active_section: permissions.OrgSettings,
    )

  // Action: admin updates a DIFFERENT user (id=99) to member
  let updated_org_user = make_org_user(99, "member")
  let #(next, _effect) = org_settings.handle_org_settings_saved_ok(model, updated_org_user)

  // Assert: model.user should remain unchanged (still Admin)
  case next.user {
    opt.Some(u) -> {
      u.id |> should.equal(42)
      u.org_role |> should.equal(org_role.Admin)
    }
    opt.None -> should.fail()
  }
}

pub fn saved_ok_handles_none_user_gracefully_test() {
  // Setup: no current user (edge case)
  let model =
    Model(
      ..base_model(),
      user: opt.None,
      active_section: permissions.OrgSettings,
    )

  // Action: update some user's role
  let updated_org_user = make_org_user(42, "admin")
  let #(next, _effect) = org_settings.handle_org_settings_saved_ok(model, updated_org_user)

  // Assert: model.user should remain None
  next.user |> should.equal(opt.None)
}

pub fn saved_ok_ignores_invalid_role_string_test() {
  // Setup: current user is member (id=42)
  let current_user = make_user(42, org_role.Member)
  let model =
    Model(
      ..base_model(),
      user: opt.Some(current_user),
      active_section: permissions.OrgSettings,
    )

  // Action: update with invalid role string (shouldn't happen, but defensive)
  let updated_org_user = make_org_user(42, "invalid_role")
  let #(next, _effect) = org_settings.handle_org_settings_saved_ok(model, updated_org_user)

  // Assert: model.user should remain unchanged (still Member)
  case next.user {
    opt.Some(u) -> u.org_role |> should.equal(org_role.Member)
    opt.None -> should.fail()
  }
}

// =============================================================================
// handle_org_settings_saved_ok: List Update Tests
// =============================================================================

pub fn saved_ok_updates_org_settings_users_list_test() {
  // Setup: org_settings_users has user 42 as member
  let existing_user = make_org_user(42, "member")
  let model =
    Model(
      ..base_model(),
      org_settings_users: Loaded([existing_user]),
    )

  // Action: update user 42 to admin
  let updated_org_user = make_org_user(42, "admin")
  let #(next, _effect) = org_settings.handle_org_settings_saved_ok(model, updated_org_user)

  // Assert: org_settings_users should have updated role
  case next.org_settings_users {
    Loaded([u]) -> u.org_role |> should.equal("admin")
    _ -> should.fail()
  }
}

pub fn saved_ok_updates_org_users_cache_test() {
  // Setup: org_users_cache has user 42 as member
  let existing_user = make_org_user(42, "member")
  let model =
    Model(
      ..base_model(),
      org_users_cache: Loaded([existing_user]),
    )

  // Action: update user 42 to admin
  let updated_org_user = make_org_user(42, "admin")
  let #(next, _effect) = org_settings.handle_org_settings_saved_ok(model, updated_org_user)

  // Assert: org_users_cache should have updated role
  case next.org_users_cache {
    Loaded([u]) -> u.org_role |> should.equal("admin")
    _ -> should.fail()
  }
}

pub fn saved_ok_clears_in_flight_and_error_state_test() {
  // Setup: in-flight state with error
  let model =
    Model(
      ..base_model(),
      org_settings_save_in_flight: True,
      org_settings_error: opt.Some("Previous error"),
      org_settings_error_user_id: opt.Some(42),
    )

  // Action: successful save
  let updated_org_user = make_org_user(42, "admin")
  let #(next, _effect) = org_settings.handle_org_settings_saved_ok(model, updated_org_user)

  // Assert: in-flight and error state should be cleared
  next.org_settings_save_in_flight |> should.be_false
  next.org_settings_error |> should.equal(opt.None)
  next.org_settings_error_user_id |> should.equal(opt.None)
}

pub fn saved_ok_returns_no_effect_test() {
  let model = base_model()
  let updated_org_user = make_org_user(42, "admin")
  let #(_next, fx) = org_settings.handle_org_settings_saved_ok(model, updated_org_user)

  // Assert: should return effect.none()
  fx |> should.equal(effect.none())
}

// =============================================================================
// Story 4.3: Pending Org Role Changes Tests
// =============================================================================

import gleam/dict

pub fn has_pending_changes_empty_test() {
  let model = base_model()

  dict.size(model.org_settings_role_drafts)
  |> should.equal(0)
}

pub fn has_pending_changes_after_role_change_test() {
  let model = base_model()

  // Change user 1's role to admin
  let #(updated_model, _effect) =
    org_settings.handle_org_settings_role_changed(model, 1, "admin")

  dict.size(updated_model.org_settings_role_drafts)
  |> should.equal(1)

  dict.get(updated_model.org_settings_role_drafts, 1)
  |> should.equal(Ok("admin"))
}

pub fn has_pending_changes_multiple_users_test() {
  let model = base_model()

  // Change multiple users' roles
  let #(model1, _) = org_settings.handle_org_settings_role_changed(model, 1, "admin")
  let #(model2, _) = org_settings.handle_org_settings_role_changed(model1, 2, "member")
  let #(model3, _) = org_settings.handle_org_settings_role_changed(model2, 3, "admin")

  dict.size(model3.org_settings_role_drafts)
  |> should.equal(3)
}

pub fn role_change_overwrites_previous_test() {
  let model = base_model()

  // Change user 1's role to admin
  let #(model1, _) = org_settings.handle_org_settings_role_changed(model, 1, "admin")

  // Change user 1's role again to member
  let #(model2, _) = org_settings.handle_org_settings_role_changed(model1, 1, "member")

  // Should still have only 1 pending change
  dict.size(model2.org_settings_role_drafts)
  |> should.equal(1)

  // And it should be the latest value
  dict.get(model2.org_settings_role_drafts, 1)
  |> should.equal(Ok("member"))
}

// =============================================================================
// Story 4.3: Save All Org Role Changes Tests
// =============================================================================

pub fn save_all_when_no_pending_changes_test() {
  let model = base_model()

  let #(updated_model, _effect) =
    org_settings.handle_org_settings_save_all_clicked(model)

  // Should not start in-flight when no pending changes
  updated_model.org_settings_save_in_flight
  |> should.equal(False)
}

pub fn save_all_with_pending_changes_starts_in_flight_test() {
  let model = base_model()

  // Add a pending change
  let #(model_with_change, _) =
    org_settings.handle_org_settings_role_changed(model, 1, "admin")

  let #(updated_model, _effect) =
    org_settings.handle_org_settings_save_all_clicked(model_with_change)

  // Should start in-flight
  updated_model.org_settings_save_in_flight
  |> should.equal(True)
}

pub fn save_all_already_in_flight_does_nothing_test() {
  let model =
    Model(
      ..base_model(),
      org_settings_save_in_flight: True,
      org_settings_role_drafts: dict.from_list([#(1, "admin")]),
    )

  let #(updated_model, _effect) =
    org_settings.handle_org_settings_save_all_clicked(model)

  // Should remain unchanged
  updated_model.org_settings_save_in_flight
  |> should.equal(True)
}

pub fn saved_ok_removes_from_drafts_test() {
  let user = make_org_user(1, "admin")
  let model =
    Model(
      ..base_model(),
      org_settings_users: Loaded([user]),
      org_settings_role_drafts: dict.from_list([#(1, "admin")]),
      org_settings_save_in_flight: True,
    )

  let #(updated_model, _effect) =
    org_settings.handle_org_settings_saved_ok(model, user)

  // Pending change should be removed
  dict.size(updated_model.org_settings_role_drafts)
  |> should.equal(0)

  // In-flight should be cleared
  updated_model.org_settings_save_in_flight
  |> should.equal(False)
}

pub fn saved_ok_continues_with_remaining_changes_test() {
  let user1 = make_org_user(1, "admin")
  let user2 = make_org_user(2, "member")
  let model =
    Model(
      ..base_model(),
      org_settings_users: Loaded([user1, user2]),
      org_settings_role_drafts: dict.from_list([#(1, "admin"), #(2, "admin")]),
      org_settings_save_in_flight: True,
    )

  // Save user 1 successfully
  let #(updated_model, _effect) =
    org_settings.handle_org_settings_saved_ok(model, user1)

  // User 1's change removed, user 2's change remains
  dict.size(updated_model.org_settings_role_drafts)
  |> should.equal(1)

  dict.get(updated_model.org_settings_role_drafts, 2)
  |> should.equal(Ok("admin"))

  // Still in-flight for next save
  updated_model.org_settings_save_in_flight
  |> should.equal(True)
}

pub fn saved_ok_shows_toast_when_done_test() {
  let user = make_org_user(1, "admin")
  let model =
    Model(
      ..base_model(),
      org_settings_users: Loaded([user]),
      org_settings_role_drafts: dict.from_list([#(1, "admin")]),
      org_settings_save_in_flight: True,
      toast: opt.None,
    )

  let #(updated_model, _effect) =
    org_settings.handle_org_settings_saved_ok(model, user)

  // Toast should be shown
  case updated_model.toast {
    opt.Some(_) -> True
    opt.None -> False
  }
  |> should.equal(True)
}
