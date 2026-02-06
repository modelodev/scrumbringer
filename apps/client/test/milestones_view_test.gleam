import gleam/dict
import gleam/int
import gleam/option.{None, Some}
import gleam/string
import gleeunit/should
import lustre/element

import domain/api_error.{ApiError}
import domain/milestone.{
  type MilestoneProgress, type MilestoneState, Active, Completed, Milestone,
  MilestoneProgress, Ready,
}
import domain/org_role
import domain/remote
import domain/user.{User}
import scrumbringer_client/client_state
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/milestones/view as milestones_view

fn sample_progress(id: Int, state: MilestoneState) -> MilestoneProgress {
  MilestoneProgress(
    milestone: Milestone(
      id: id,
      project_id: 1,
      name: "Milestone " <> int.to_string(id),
      description: Some("Description"),
      state: state,
      position: id,
      created_by: 1,
      created_at: "2026-02-06T00:00:00Z",
      activated_at: None,
      completed_at: None,
    ),
    cards_total: 3,
    cards_completed: 1,
    tasks_total: 4,
    tasks_completed: 2,
  )
}

fn base_model() -> client_state.Model {
  client_state.default_model()
}

fn with_milestones(
  model: client_state.Model,
  milestones: remote.Remote(List(MilestoneProgress)),
) -> client_state.Model {
  client_state.update_member(model, fn(member) {
    let pool = member.pool
    member_state.MemberModel(
      ..member,
      pool: member_pool.Model(..pool, member_milestones: milestones),
    )
  })
}

fn with_admin_user(model: client_state.Model) -> client_state.Model {
  client_state.update_core(model, fn(core) {
    client_state.CoreModel(
      ..core,
      user: Some(User(
        id: 1,
        email: "admin@example.com",
        org_id: 1,
        org_role: org_role.Admin,
        created_at: "",
      )),
    )
  })
}

fn with_activate_dialog(
  model: client_state.Model,
  milestone_id: Int,
) -> client_state.Model {
  client_state.update_member(model, fn(member) {
    let pool = member.pool
    member_state.MemberModel(
      ..member,
      pool: member_pool.Model(
        ..pool,
        member_milestone_dialog: member_pool.MilestoneDialogActivate(
          milestone_id,
        ),
      ),
    )
  })
}

fn with_show_completed(
  model: client_state.Model,
  show_completed: Bool,
) -> client_state.Model {
  client_state.update_member(model, fn(member) {
    let pool = member.pool
    member_state.MemberModel(
      ..member,
      pool: member_pool.Model(
        ..pool,
        member_milestones_show_completed: show_completed,
      ),
    )
  })
}

pub fn milestones_view_loading_state_test() {
  let html =
    base_model()
    |> with_milestones(remote.Loading)
    |> milestones_view.view
    |> element.to_document_string

  string.contains(html, "milestones-loading") |> should.be_true
}

pub fn milestones_view_error_state_test() {
  let html =
    base_model()
    |> with_milestones(
      remote.Failed(ApiError(status: 500, code: "E_M", message: "boom")),
    )
    |> milestones_view.view
    |> element.to_document_string

  string.contains(html, "Could not load milestones") |> should.be_true
}

pub fn milestones_view_empty_state_test() {
  let html =
    base_model()
    |> with_milestones(remote.Loaded([]))
    |> milestones_view.view
    |> element.to_document_string

  string.contains(html, "No milestones yet") |> should.be_true
}

pub fn milestones_view_rows_include_stable_testids_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_milestones(remote.Loaded([sample_progress(12, Ready)]))
    |> milestones_view.view
    |> element.to_document_string

  string.contains(html, "data-testid=\"milestone-row:12\"") |> should.be_true
  string.contains(html, "data-testid=\"milestone-activate-button:12\"")
  |> should.be_true
  string.contains(html, "data-testid=\"milestone-edit-button:12\"")
  |> should.be_true
  string.contains(html, "data-testid=\"milestone-delete-button:12\"")
  |> should.be_true
  string.contains(html, "id=\"milestone-activate-button-12\"")
  |> should.be_true
  string.contains(html, "id=\"milestone-edit-button-12\"") |> should.be_true
  string.contains(html, "id=\"milestone-delete-button-12\"")
  |> should.be_true
}

pub fn milestones_view_hides_actions_for_non_managers_test() {
  let html =
    base_model()
    |> with_milestones(remote.Loaded([sample_progress(7, Ready)]))
    |> milestones_view.view
    |> element.to_document_string

  string.contains(html, "milestone-activate-button:7") |> should.be_false
  string.contains(html, "milestone-edit-button:7") |> should.be_false
  string.contains(html, "milestone-delete-button:7") |> should.be_false
}

pub fn milestones_view_delete_button_only_for_ready_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_milestones(
      remote.Loaded([
        sample_progress(1, Ready),
        sample_progress(2, Active),
        sample_progress(3, Completed),
      ]),
    )
    |> milestones_view.view
    |> element.to_document_string

  string.contains(html, "milestone-delete-button:1") |> should.be_true
  string.contains(html, "milestone-delete-button:2") |> should.be_false
  string.contains(html, "milestone-delete-button:3") |> should.be_false
}

pub fn milestones_view_blocks_activate_when_another_active_exists_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_milestones(
      remote.Loaded([sample_progress(11, Ready), sample_progress(99, Active)]),
    )
    |> milestones_view.view
    |> element.to_document_string

  string.contains(html, "milestone-activate-button:11") |> should.be_false
}

pub fn milestones_view_disables_activate_button_while_in_flight_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_milestones(remote.Loaded([sample_progress(22, Ready)]))
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_milestone_activate_in_flight_id: Some(22),
        ),
      )
    })
    |> milestones_view.view
    |> element.to_document_string

  string.contains(html, "data-testid=\"milestone-activate-button:22\" disabled")
  |> should.be_true
}

pub fn milestones_view_renders_toggle_and_progress_testids_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_milestones(remote.Loaded([sample_progress(33, Ready)]))
    |> milestones_view.view
    |> element.to_document_string

  string.contains(html, "data-testid=\"milestone-toggle:33\"")
  |> should.be_true
  string.contains(html, "data-testid=\"milestone-progress:33\"")
  |> should.be_true
}

pub fn milestones_view_renders_accessibility_controls_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_milestones(remote.Loaded([sample_progress(44, Ready)]))
    |> milestones_view.view
    |> element.to_document_string

  string.contains(html, "aria-controls=\"milestone-details-44\"")
  |> should.be_true
  string.contains(html, "aria-labelledby=\"milestone-details-button-44\"")
  |> should.be_true
  string.contains(html, "aria-expanded=\"false\"") |> should.be_true
}

pub fn milestones_view_filter_toggles_present_and_default_unchecked_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_milestones(remote.Loaded([sample_progress(55, Ready)]))
    |> milestones_view.view
    |> element.to_document_string

  string.contains(html, "data-testid=\"milestones-filter-completed\"")
  |> should.be_true
  string.contains(html, "data-testid=\"milestones-filter-empty\"")
  |> should.be_true
  string.contains(html, "data-testid=\"milestones-filter-completed\" checked")
  |> should.be_false
  string.contains(html, "data-testid=\"milestones-filter-empty\" checked")
  |> should.be_false
}

pub fn milestones_view_hides_completed_section_when_filter_unchecked_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_milestones(
      remote.Loaded([sample_progress(71, Ready), sample_progress(72, Completed)]),
    )
    |> milestones_view.view
    |> element.to_document_string

  string.contains(html, "Completed") |> should.be_false
}

pub fn milestones_view_shows_completed_section_when_filter_checked_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_show_completed(True)
    |> with_milestones(
      remote.Loaded([sample_progress(81, Ready), sample_progress(82, Completed)]),
    )
    |> milestones_view.view
    |> element.to_document_string

  string.contains(html, "Completed") |> should.be_true
}

pub fn milestones_view_hides_active_section_when_empty_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_milestones(remote.Loaded([sample_progress(91, Ready)]))
    |> milestones_view.view
    |> element.to_document_string

  string.contains(html, "<h4 class=\"milestones-section-title\">Active</h4>")
  |> should.be_false
}

pub fn milestones_view_hides_ready_section_when_empty_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_show_completed(True)
    |> with_milestones(remote.Loaded([sample_progress(92, Active)]))
    |> milestones_view.view
    |> element.to_document_string

  string.contains(html, "<h4 class=\"milestones-section-title\">Ready</h4>")
  |> should.be_false
}

pub fn milestones_view_activate_button_opens_prompt_dialog_contract_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_milestones(remote.Loaded([sample_progress(66, Ready)]))
    |> with_activate_dialog(66)
    |> milestones_view.view
    |> element.to_document_string

  string.contains(html, "Activate milestone") |> should.be_true
  string.contains(html, "This action is irreversible") |> should.be_true
  string.contains(html, "autofocus") |> should.be_true
}

pub fn milestones_view_expand_state_does_not_open_dialog_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_milestones(remote.Loaded([sample_progress(77, Ready)]))
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_milestones_expanded: dict.insert(dict.new(), 77, True),
        ),
      )
    })
    |> milestones_view.view
    |> element.to_document_string

  string.contains(html, "aria-expanded=\"true\"") |> should.be_true
  string.contains(html, "Activate milestone") |> should.be_false
}

pub fn milestones_view_open_dialog_does_not_expand_row_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_milestones(remote.Loaded([sample_progress(88, Ready)]))
    |> with_activate_dialog(88)
    |> milestones_view.view
    |> element.to_document_string

  string.contains(html, "Activate milestone") |> should.be_true
  string.contains(html, "aria-expanded=\"true\"") |> should.be_false
}
