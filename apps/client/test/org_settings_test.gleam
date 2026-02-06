//// Tests for org settings handlers.
////
//// Specifically tests the fix for:
//// - When admin changes their own role, model.user should be updated

import gleam/option as opt
import gleeunit/should
import lustre/effect

import domain/org.{type OrgUser, OrgUser}
import domain/org_role
import domain/remote.{Loaded}
import domain/user.{type User, User}
import scrumbringer_client/client_state.{
  type Model, Admin, CoreModel, update_admin, update_core, update_ui,
}
import scrumbringer_client/client_state/admin.{AdminModel}
import scrumbringer_client/client_state/admin/members as admin_members
import scrumbringer_client/client_state/ui as ui_state
import scrumbringer_client/features/admin/org_settings
import scrumbringer_client/permissions
import scrumbringer_client/ui/toast

// =============================================================================
// Test Helpers
// =============================================================================

fn base_model() -> Model {
  update_core(client_state.default_model(), fn(core) {
    CoreModel(..core, page: Admin)
  })
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

fn make_org_user(id: Int, role: org_role.OrgRole) -> OrgUser {
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
    update_core(base_model(), fn(core) {
      CoreModel(
        ..core,
        user: opt.Some(current_user),
        active_section: permissions.OrgSettings,
      )
    })

  // Action: admin updates user 42's role to admin
  let updated_org_user = make_org_user(42, org_role.Admin)
  let #(next, _effect) =
    org_settings.handle_org_settings_saved_ok(model, updated_org_user)

  // Assert: model.user should now have Admin role
  case next.core.user {
    opt.Some(u) -> u.org_role |> should.equal(org_role.Admin)
    opt.None -> should.fail()
  }
}

pub fn saved_ok_updates_current_user_role_to_member_test() {
  // Setup: current user is admin (id=42)
  let current_user = make_user(42, org_role.Admin)
  let model =
    update_core(base_model(), fn(core) {
      CoreModel(
        ..core,
        user: opt.Some(current_user),
        active_section: permissions.OrgSettings,
      )
    })

  // Action: admin updates user 42's role to member
  let updated_org_user = make_org_user(42, org_role.Member)
  let #(next, _effect) =
    org_settings.handle_org_settings_saved_ok(model, updated_org_user)

  // Assert: model.user should now have Member role
  case next.core.user {
    opt.Some(u) -> u.org_role |> should.equal(org_role.Member)
    opt.None -> should.fail()
  }
}

pub fn saved_ok_does_not_change_user_when_different_id_test() {
  // Setup: current user is admin (id=42)
  let current_user = make_user(42, org_role.Admin)
  let model =
    update_core(base_model(), fn(core) {
      CoreModel(
        ..core,
        user: opt.Some(current_user),
        active_section: permissions.OrgSettings,
      )
    })

  // Action: admin updates a DIFFERENT user (id=99) to member
  let updated_org_user = make_org_user(99, org_role.Member)
  let #(next, _effect) =
    org_settings.handle_org_settings_saved_ok(model, updated_org_user)

  // Assert: model.user should remain unchanged (still Admin)
  case next.core.user {
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
    update_core(base_model(), fn(core) {
      CoreModel(..core, user: opt.None, active_section: permissions.OrgSettings)
    })

  // Action: update some user's role
  let updated_org_user = make_org_user(42, org_role.Admin)
  let #(next, _effect) =
    org_settings.handle_org_settings_saved_ok(model, updated_org_user)

  // Assert: model.user should remain None
  next.core.user |> should.equal(opt.None)
}

pub fn saved_ok_ignores_invalid_role_string_test() {
  // Setup: current user is member (id=42)
  let current_user = make_user(42, org_role.Member)
  let model =
    update_core(base_model(), fn(core) {
      CoreModel(
        ..core,
        user: opt.Some(current_user),
        active_section: permissions.OrgSettings,
      )
    })

  // Action: update with invalid role string (shouldn't happen, but defensive)
  let updated_org_user = make_org_user(42, org_role.Member)
  let #(next, _effect) =
    org_settings.handle_org_settings_saved_ok(model, updated_org_user)

  // Assert: model.user should remain unchanged (still Member)
  case next.core.user {
    opt.Some(u) -> u.org_role |> should.equal(org_role.Member)
    opt.None -> should.fail()
  }
}

// =============================================================================
// handle_org_settings_saved_ok: List Update Tests
// =============================================================================

pub fn saved_ok_updates_org_settings_users_list_test() {
  // Setup: org_settings_users has user 42 as member
  let existing_user = make_org_user(42, org_role.Member)
  let model =
    update_admin(base_model(), fn(admin) {
      AdminModel(
        ..admin,
        members: admin_members.Model(
          ..admin.members,
          org_settings_users: Loaded([existing_user]),
        ),
      )
    })

  // Action: update user 42 to admin
  let updated_org_user = make_org_user(42, org_role.Admin)
  let #(next, _effect) =
    org_settings.handle_org_settings_saved_ok(model, updated_org_user)

  // Assert: org_settings_users should have updated role
  case next.admin.members.org_settings_users {
    Loaded([u]) -> u.org_role |> should.equal(org_role.Admin)
    _ -> should.fail()
  }
}

pub fn saved_ok_updates_org_users_cache_test() {
  // Setup: org_users_cache has user 42 as member
  let existing_user = make_org_user(42, org_role.Member)
  let model =
    update_admin(base_model(), fn(admin) {
      AdminModel(
        ..admin,
        members: admin_members.Model(
          ..admin.members,
          org_users_cache: Loaded([existing_user]),
        ),
      )
    })

  // Action: update user 42 to admin
  let updated_org_user = make_org_user(42, org_role.Admin)
  let #(next, _effect) =
    org_settings.handle_org_settings_saved_ok(model, updated_org_user)

  // Assert: org_users_cache should have updated role
  case next.admin.members.org_users_cache {
    Loaded([u]) -> u.org_role |> should.equal(org_role.Admin)
    _ -> should.fail()
  }
}

pub fn saved_ok_clears_in_flight_and_error_state_test() {
  // Setup: in-flight state with error
  let model =
    update_admin(base_model(), fn(admin) {
      AdminModel(
        ..admin,
        members: admin_members.Model(
          ..admin.members,
          org_settings_save_in_flight: True,
          org_settings_error: opt.Some("Previous error"),
          org_settings_error_user_id: opt.Some(42),
        ),
      )
    })

  // Action: successful save
  let updated_org_user = make_org_user(42, org_role.Admin)
  let #(next, _effect) =
    org_settings.handle_org_settings_saved_ok(model, updated_org_user)

  // Assert: in-flight and error state should be cleared
  next.admin.members.org_settings_save_in_flight |> should.be_false
  next.admin.members.org_settings_error |> should.equal(opt.None)
  next.admin.members.org_settings_error_user_id |> should.equal(opt.None)
}

pub fn saved_ok_returns_no_effect_test() {
  let model = base_model()
  let updated_org_user = make_org_user(42, org_role.Admin)
  let #(_next, fx) =
    org_settings.handle_org_settings_saved_ok(model, updated_org_user)

  // Assert: should return a toast effect (not none)
  should.be_false(fx == effect.none())
}

// =============================================================================
// Auto-save Org Role Changes Tests
// =============================================================================

pub fn role_changed_triggers_save_when_role_diff_test() {
  let user = make_org_user(1, org_role.Member)
  let model =
    update_admin(base_model(), fn(admin) {
      AdminModel(
        ..admin,
        members: admin_members.Model(
          ..admin.members,
          org_settings_users: Loaded([user]),
        ),
      )
    })

  let #(updated_model, fx) =
    org_settings.handle_org_settings_role_changed(model, 1, org_role.Admin)

  updated_model.admin.members.org_settings_save_in_flight
  |> should.equal(True)
  updated_model.admin.members.org_settings_error |> should.equal(opt.None)
  updated_model.admin.members.org_settings_error_user_id
  |> should.equal(opt.None)
  should.be_false(fx == effect.none())
}

pub fn role_changed_noop_when_role_is_same_test() {
  let user = make_org_user(1, org_role.Member)
  let model =
    update_admin(base_model(), fn(admin) {
      AdminModel(
        ..admin,
        members: admin_members.Model(
          ..admin.members,
          org_settings_users: Loaded([user]),
        ),
      )
    })

  let #(updated_model, fx) =
    org_settings.handle_org_settings_role_changed(model, 1, org_role.Member)

  updated_model.admin.members.org_settings_save_in_flight
  |> should.equal(False)
  fx |> should.equal(effect.none())
}

pub fn role_changed_ignored_when_in_flight_test() {
  let user = make_org_user(1, org_role.Member)
  let model =
    update_admin(base_model(), fn(admin) {
      AdminModel(
        ..admin,
        members: admin_members.Model(
          ..admin.members,
          org_settings_users: Loaded([user]),
          org_settings_save_in_flight: True,
        ),
      )
    })

  let #(updated_model, fx) =
    org_settings.handle_org_settings_role_changed(model, 1, org_role.Admin)

  updated_model.admin.members.org_settings_save_in_flight
  |> should.equal(True)
  fx |> should.equal(effect.none())
}

pub fn saved_ok_shows_toast_test() {
  let user = make_org_user(1, org_role.Admin)
  let model =
    update_ui(
      update_admin(base_model(), fn(admin) {
        AdminModel(
          ..admin,
          members: admin_members.Model(
            ..admin.members,
            org_settings_users: Loaded([user]),
            org_settings_save_in_flight: True,
          ),
        )
      }),
      fn(ui) { ui_state.UiModel(..ui, toast_state: toast.init()) },
    )

  let #(_updated_model, fx) =
    org_settings.handle_org_settings_saved_ok(model, user)

  should.be_false(fx == effect.none())
}
