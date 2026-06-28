import domain/org.{type OrgUser}
import domain/project.{type Project, type ProjectMember}
import domain/project_role
import domain/remote.{Loaded}
import gleam/int
import gleam/option as opt
import gleam/string
import lustre/effect
import lustre/element
import support/domain_fixtures
import support/render_assertions

import scrumbringer_client/client_state
import scrumbringer_client/client_state/admin as admin_state
import scrumbringer_client/client_state/admin/capabilities as admin_capabilities
import scrumbringer_client/client_state/admin/members as admin_members
import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/features/admin/member_add
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/features/admin/search
import scrumbringer_client/features/admin/views/members
import scrumbringer_client/i18n/locale

fn sample_user(id: Int, email: String) -> OrgUser {
  domain_fixtures.org_user(id, email)
}

fn sample_project() -> Project {
  domain_fixtures.project(8, "Proyecto Alpha")
}

fn sample_member(user_id: Int) -> ProjectMember {
  domain_fixtures.project_member(user_id)
}

fn sample_capability(id: Int, name: String) {
  domain_fixtures.capability(id, name)
}

fn base_model() -> client_state.Model {
  client_state.default_model()
  |> client_state.update_core(fn(core) {
    client_state.CoreModel(..core, selected_project_id: opt.Some(8))
  })
}

fn with_members_state(
  model: client_state.Model,
  f: fn(admin_members.Model) -> admin_members.Model,
) -> client_state.Model {
  client_state.update_admin(model, fn(admin) {
    admin_state.AdminModel(..admin, members: f(admin.members))
  })
}

fn with_capabilities_state(
  model: client_state.Model,
  f: fn(admin_capabilities.Model) -> admin_capabilities.Model,
) -> client_state.Model {
  client_state.update_admin(model, fn(admin) {
    admin_state.AdminModel(..admin, capabilities: f(admin.capabilities))
  })
}

fn member_add_context(model: client_state.Model) -> member_add.Context(String) {
  member_add.Context(
    selected_project_id: model.core.selected_project_id,
    select_user_first: "Select a user first",
    on_member_added: fn(_) { "member-added" },
  )
}

fn member_add_feedback_context() -> member_add.FeedbackContext(String) {
  member_add.FeedbackContext(
    member_added: "Member added",
    on_success_toast: fn(_message) { effect.from(fn(_dispatch) { Nil }) },
  )
}

fn member_add_error_feedback_context() -> member_add.ErrorFeedbackContext(
  String,
) {
  member_add.ErrorFeedbackContext(
    not_permitted: "Not permitted",
    on_warning_toast: fn(_message) { effect.from(fn(_dispatch) { Nil }) },
  )
}

fn search_context() -> search.Context(String) {
  search.Context(on_search_results: fn(_token, _result) { "search-results" })
}

fn members_config(
  model: client_state.Model,
  selected_project: opt.Option(Project),
) -> members.Config(String) {
  members.Config(
    locale: locale.En,
    selected_project: selected_project,
    members: model.admin.members,
    capabilities: model.admin.capabilities,
    current_user_id: model.core.user |> opt.map(fn(user) { user.id }),
    is_org_admin: True,
    on_add_dialog_opened: "add-open",
    on_add_dialog_closed: "add-close",
    on_org_users_search_changed: fn(value) { "search-" <> value },
    on_member_add_user_selected: fn(id) { "select-user-" <> int.to_string(id) },
    on_member_add_role_changed: fn(role) {
      "role-" <> project_role.to_string(role)
    },
    on_member_add_submitted: "add-submit",
    on_member_remove_clicked: fn(id) { "remove-" <> int.to_string(id) },
    on_member_remove_confirmed: "remove-confirm",
    on_member_remove_cancelled: "remove-cancel",
    on_member_release_all_clicked: fn(id, count) {
      "release-" <> int.to_string(id) <> "-" <> int.to_string(count)
    },
    on_member_release_all_confirmed: "release-confirm",
    on_member_release_all_cancelled: "release-cancel",
    on_member_role_change_requested: fn(id, role) {
      "change-role-" <> int.to_string(id) <> "-" <> project_role.to_string(role)
    },
    on_member_capabilities_opened: fn(id) {
      "capabilities-" <> int.to_string(id)
    },
    on_member_capabilities_closed: "capabilities-close",
    on_member_capabilities_toggled: fn(id) {
      "toggle-capability-" <> int.to_string(id)
    },
    on_member_capabilities_save_clicked: "capabilities-save",
    on_invalid_role: "invalid-role",
  )
}

pub fn org_users_search_exact_email_auto_selects_user_test() {
  let model =
    base_model()
    |> with_members_state(fn(members_state) {
      admin_members.Model(
        ..members_state,
        org_users_search: admin_members.OrgUsersSearchLoading(
          "qa@example.com",
          2,
        ),
      )
    })

  let users = [
    sample_user(3, "member@example.com"),
    sample_user(9, "qa@example.com"),
  ]

  let assert opt.Some(search.Update(next, _fx, search.NoAuthCheck)) =
    search.try_update(
      model.admin.members,
      admin_messages.OrgUsersSearchResults(2, Ok(users)),
      search_context(),
    )

  let assert opt.Some(user) = next.members_add_selected_user
  let assert 9 = user.id
  let assert "qa@example.com" = user.email
}

pub fn org_users_search_without_exact_match_clears_selection_test() {
  let model =
    base_model()
    |> with_members_state(fn(members_state) {
      admin_members.Model(
        ..members_state,
        members_add_selected_user: opt.Some(sample_user(9, "qa@example.com")),
        org_users_search: admin_members.OrgUsersSearchLoading(
          "qa@example.com",
          3,
        ),
      )
    })

  let users = [
    sample_user(3, "member@example.com"),
    sample_user(4, "pm@example.com"),
  ]

  let assert opt.Some(search.Update(next, _fx, search.NoAuthCheck)) =
    search.try_update(
      model.admin.members,
      admin_messages.OrgUsersSearchResults(3, Ok(users)),
      search_context(),
    )

  let assert opt.None = next.members_add_selected_user
}

pub fn submit_without_selected_user_keeps_add_disabled_state_test() {
  let model =
    base_model()
    |> with_members_state(fn(members_state) {
      admin_members.Model(..members_state, members_add_selected_user: opt.None)
    })

  let assert opt.Some(member_add.Update(
    next,
    fx,
    member_add.NoAuthCheck,
    member_add.NoRefresh,
  )) =
    member_add.try_update(
      model.admin.members,
      admin_messages.MemberAddSubmitted,
      member_add_context(model),
      member_add_feedback_context(),
      member_add_error_feedback_context(),
    )

  let assert False = next.members_add_in_flight
  let assert False = next.members_add_error == opt.None
  let assert True = fx == effect.none()
}

pub fn members_dialog_shows_selected_user_feedback_test() {
  let model =
    base_model()
    |> with_members_state(fn(members_state) {
      admin_members.Model(
        ..members_state,
        members_add_dialog_mode: dialog_mode.DialogCreate,
        members_add_selected_user: opt.Some(sample_user(9, "qa@example.com")),
      )
    })

  let rendered =
    members.view_members(members_config(model, opt.Some(sample_project())))
  let html = element.to_document_string(rendered)

  render_assertions.contains(html, "member-add-selected-user")
  render_assertions.contains(html, "qa@example.com")
  render_assertions.contains(html, "Add member")
  render_assertions.contains(html, "btn-primary")
  render_assertions.contains(html, "btn-entity-action")
  render_assertions.not_contains(html, "class=\"btn-primary\"")
}

pub fn members_dialog_search_result_uses_semantic_select_button_test() {
  let model =
    base_model()
    |> with_members_state(fn(members_state) {
      admin_members.Model(
        ..members_state,
        members_add_dialog_mode: dialog_mode.DialogCreate,
        org_users_search: admin_members.OrgUsersSearchLoaded(
          "qa@example.com",
          4,
          [sample_user(9, "qa@example.com")],
        ),
      )
    })

  let rendered =
    members.view_members(members_config(model, opt.Some(sample_project())))
  let html = element.to_document_string(rendered)

  render_assertions.contains(html, "qa@example.com")
  render_assertions.contains(html, "Select")
  render_assertions.contains(html, "btn-secondary")
  render_assertions.contains(html, "btn-entity-action")
  render_assertions.contains(html, "btn-xs")
  render_assertions.not_contains(html, "class=\"btn btn-secondary btn-xs\"")
}

pub fn members_dialog_add_submit_uses_semantic_loading_button_test() {
  let model =
    base_model()
    |> with_members_state(fn(members_state) {
      admin_members.Model(
        ..members_state,
        members_add_dialog_mode: dialog_mode.DialogCreate,
        members_add_selected_user: opt.Some(sample_user(9, "qa@example.com")),
        members_add_in_flight: True,
      )
    })

  let rendered =
    members.view_members(members_config(model, opt.Some(sample_project())))
  let html = element.to_document_string(rendered)

  render_assertions.contains(html, "Working")
  render_assertions.contains(html, "btn-primary")
  render_assertions.contains(html, "btn-entity-action")
  render_assertions.contains(html, "btn-loading")
  render_assertions.not_contains(html, "class=\"btn-loading\"")
}

pub fn members_remove_dialog_uses_typed_danger_confirm_button_test() {
  let model =
    base_model()
    |> with_members_state(fn(members_state) {
      admin_members.Model(
        ..members_state,
        members_remove_confirm: opt.Some(sample_user(9, "qa@example.com")),
        members_remove_in_flight: True,
      )
    })

  let rendered =
    members.view_members(members_config(model, opt.Some(sample_project())))
  let html = element.to_document_string(rendered)

  render_assertions.contains(html, "Remove")
  render_assertions.contains(html, "btn-danger")
  render_assertions.contains(html, "btn-entity-action")
  render_assertions.contains(html, "btn-loading")
  render_assertions.not_contains(html, "class=\"btn-danger btn-loading\"")
}

pub fn members_release_all_dialog_uses_typed_primary_confirm_button_test() {
  let model =
    base_model()
    |> with_members_state(fn(members_state) {
      admin_members.Model(
        ..members_state,
        members_release_confirm: opt.Some(admin_members.ReleaseAllTarget(
          user: sample_user(9, "qa@example.com"),
          claimed_count: 3,
        )),
        members_release_in_flight: opt.Some(9),
      )
    })

  let rendered =
    members.view_members(members_config(model, opt.Some(sample_project())))
  let html = element.to_document_string(rendered)

  render_assertions.contains(html, "Release")
  render_assertions.contains(html, "btn-primary")
  render_assertions.contains(html, "btn-entity-action")
  render_assertions.contains(html, "btn-loading")
  render_assertions.not_contains(html, "class=\"btn-primary btn-loading\"")
}

pub fn members_capabilities_save_uses_semantic_loading_button_test() {
  let model =
    base_model()
    |> with_members_state(fn(members_state) {
      admin_members.Model(
        ..members_state,
        org_users_cache: Loaded([sample_user(9, "qa@example.com")]),
      )
    })
    |> with_capabilities_state(fn(capabilities_state) {
      admin_capabilities.Model(
        ..capabilities_state,
        capabilities: Loaded([sample_capability(1, "Backend")]),
        member_capabilities_dialog_user_id: opt.Some(9),
        member_capabilities_saving: True,
      )
    })

  let rendered =
    members.view_members(members_config(model, opt.Some(sample_project())))
  let html = element.to_document_string(rendered)

  render_assertions.contains(html, "Saving")
  render_assertions.contains(html, "btn-primary")
  render_assertions.contains(html, "btn-entity-action")
  render_assertions.contains(html, "btn-loading")
  render_assertions.not_contains(html, "class=\"btn-primary btn-loading\"")
}

pub fn members_dialog_shows_no_results_feedback_for_full_email_test() {
  let model =
    base_model()
    |> with_members_state(fn(members_state) {
      admin_members.Model(
        ..members_state,
        members_add_dialog_mode: dialog_mode.DialogCreate,
        org_users_search: admin_members.OrgUsersSearchLoaded(
          "qa@example.com",
          4,
          [],
        ),
      )
    })

  let rendered =
    members.view_members(members_config(model, opt.Some(sample_project())))
  let html = element.to_document_string(rendered)

  let has_no_results =
    string.contains(html, "Sin resultados")
    || string.contains(html, "No results")

  let assert True = has_no_results
}

pub fn members_dialog_filters_out_existing_project_members_from_search_results_test() {
  let model =
    base_model()
    |> with_members_state(fn(members_state) {
      admin_members.Model(
        ..members_state,
        members_add_dialog_mode: dialog_mode.DialogCreate,
        members: Loaded([sample_member(9)]),
        org_users_search: admin_members.OrgUsersSearchLoaded(
          "qa@example.com",
          5,
          [
            sample_user(9, "qa@example.com"),
          ],
        ),
      )
    })

  let rendered =
    members.view_members(members_config(model, opt.Some(sample_project())))
  let html = element.to_document_string(rendered)

  let has_no_results =
    string.contains(html, "Sin resultados")
    || string.contains(html, "No results")

  let assert True = has_no_results
  render_assertions.not_contains(html, "Seleccionar")
}
