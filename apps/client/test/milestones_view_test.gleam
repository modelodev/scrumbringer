import gleam/dict
import gleam/int
import gleam/option.{None, Some}
import gleam/string
import gleeunit/should
import lustre/element

import domain/api_error.{ApiError}
import domain/card.{Card, Pendiente}
import domain/metrics.{
  MilestoneModalMetrics, ModalExecutionHealth, WorkflowBreakdown,
}
import domain/milestone.{
  type MilestoneProgress, type MilestoneState, Active, Completed, Milestone,
  MilestoneProgress, Ready,
}
import domain/org_role
import domain/remote
import domain/task.{type Task, Task}
import domain/task_state
import domain/task_type.{TaskTypeInline}
import domain/user.{User}
import scrumbringer_client/client_state
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/milestone_details_tab
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/client_state/ui as ui_state
import scrumbringer_client/features/milestones/view as milestones_view
import scrumbringer_client/i18n/locale as i18n_locale

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

fn with_cards(model: client_state.Model, cards) -> client_state.Model {
  client_state.update_member(model, fn(member) {
    let pool = member.pool
    member_state.MemberModel(
      ..member,
      pool: member_pool.Model(..pool, member_cards: remote.Loaded(cards)),
    )
  })
}

fn with_tasks(
  model: client_state.Model,
  tasks: List(Task),
) -> client_state.Model {
  client_state.update_member(model, fn(member) {
    let pool = member.pool
    member_state.MemberModel(
      ..member,
      pool: member_pool.Model(..pool, member_tasks: remote.Loaded(tasks)),
    )
  })
}

fn with_milestone_metrics(
  model: client_state.Model,
  metrics,
) -> client_state.Model {
  client_state.update_member(model, fn(member) {
    let pool = member.pool
    member_state.MemberModel(
      ..member,
      pool: member_pool.Model(..pool, member_milestone_metrics: metrics),
    )
  })
}

fn with_locale(
  model: client_state.Model,
  locale: i18n_locale.Locale,
) -> client_state.Model {
  client_state.update_ui(model, fn(ui) {
    ui_state.UiModel(..ui, locale: locale)
  })
}

fn sample_card(id: Int, milestone_id: Int) {
  Card(
    id: id,
    project_id: 1,
    milestone_id: Some(milestone_id),
    title: "Card " <> int.to_string(id),
    description: "",
    color: None,
    state: Pendiente,
    task_count: 3,
    completed_count: 1,
    created_by: 1,
    created_at: "2026-02-06T00:00:00Z",
    has_new_notes: False,
  )
}

fn sample_loose_task(id: Int, milestone_id: Int) -> Task {
  let state = task_state.Available
  Task(
    id: id,
    project_id: 1,
    type_id: 1,
    task_type: TaskTypeInline(id: 1, name: "Task", icon: "check"),
    ongoing_by: None,
    title: "Task " <> int.to_string(id),
    description: None,
    priority: 1,
    state: state,
    status: task_state.to_status(state),
    work_state: task_state.to_work_state(state),
    created_by: 1,
    created_at: "2026-02-06T00:00:00Z",
    version: 1,
    milestone_id: Some(milestone_id),
    card_id: None,
    card_title: None,
    card_color: None,
    has_new_notes: False,
    blocked_count: 0,
    dependencies: [],
  )
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

pub fn milestones_view_shows_create_button_for_managers_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_milestones(remote.Loaded([sample_progress(12, Ready)]))
    |> milestones_view.view
    |> element.to_document_string

  string.contains(html, "data-testid=\"milestones-create-button\"")
  |> should.be_true
  string.contains(html, "+ Create milestone") |> should.be_true
}

pub fn milestones_view_hides_create_button_for_non_managers_test() {
  let html =
    base_model()
    |> with_milestones(remote.Loaded([sample_progress(12, Ready)]))
    |> milestones_view.view
    |> element.to_document_string

  string.contains(html, "data-testid=\"milestones-create-button\"")
  |> should.be_false
}

pub fn milestones_view_empty_state_shows_create_first_cta_for_manager_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_milestones(remote.Loaded([]))
    |> milestones_view.view
    |> element.to_document_string

  string.contains(html, "data-testid=\"milestones-create-empty\"")
  |> should.be_true
}

pub fn milestones_view_renders_create_dialog_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_milestones(remote.Loaded([sample_progress(12, Ready)]))
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_milestone_dialog: member_pool.MilestoneDialogCreate(
            name: "",
            description: "",
          ),
        ),
      )
    })
    |> milestones_view.view
    |> element.to_document_string

  string.contains(html, "milestone-create-form") |> should.be_true
  string.contains(html, "Create milestone") |> should.be_true
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

pub fn milestones_view_expanded_row_renders_milestone_cards_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_milestones(remote.Loaded([sample_progress(90, Ready)]))
    |> with_cards([sample_card(501, 90)])
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_milestones_expanded: dict.insert(dict.new(), 90, True),
        ),
      )
    })
    |> milestones_view.view
    |> element.to_document_string

  string.contains(html, "data-testid=\"milestone-card-row:90:501\"")
  |> should.be_true
}

pub fn milestones_view_expanded_row_renders_loose_tasks_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_milestones(remote.Loaded([sample_progress(91, Ready)]))
    |> with_tasks([sample_loose_task(601, 91)])
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_milestones_expanded: dict.insert(dict.new(), 91, True),
        ),
      )
    })
    |> milestones_view.view
    |> element.to_document_string

  string.contains(html, "data-testid=\"milestone-task-row:91:601\"")
  |> should.be_true
}

pub fn milestones_view_expanded_row_renders_quick_new_card_cta_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_milestones(remote.Loaded([sample_progress(92, Ready)]))
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_milestones_expanded: dict.insert(dict.new(), 92, True),
        ),
      )
    })
    |> milestones_view.view
    |> element.to_document_string

  string.contains(html, "data-testid=\"milestone-quick-new-card:92\"")
  |> should.be_true
  string.contains(html, "id=\"milestone-quick-create-card-button-92\"")
  |> should.be_true
  string.contains(html, "+ Card") |> should.be_true
}

pub fn milestones_view_expanded_row_renders_quick_new_task_cta_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_milestones(remote.Loaded([sample_progress(98, Ready)]))
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_milestones_expanded: dict.insert(dict.new(), 98, True),
        ),
      )
    })
    |> milestones_view.view
    |> element.to_document_string

  string.contains(html, "data-testid=\"milestone-quick-new-task:98\"")
  |> should.be_true
  string.contains(html, "id=\"milestone-quick-create-task-button-98\"")
  |> should.be_true
  string.contains(html, "+ Task") |> should.be_true
}

pub fn milestones_view_keeps_quick_new_card_entrypoint_available_for_mobile_strategy_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_milestones(remote.Loaded([sample_progress(99, Ready)]))
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_milestones_expanded: dict.insert(dict.new(), 99, True),
        ),
      )
    })
    |> milestones_view.view
    |> element.to_document_string

  // AC5: entrypoint should remain available even when layout adapts on small screens.
  string.contains(html, "data-testid=\"milestone-quick-new-card:99\"")
  |> should.be_true
}

pub fn milestones_view_details_dialog_renders_progress_and_content_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_milestones(remote.Loaded([sample_progress(93, Ready)]))
    |> with_cards([sample_card(701, 93)])
    |> with_tasks([sample_loose_task(801, 93)])
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_milestone_dialog: member_pool.MilestoneDialogView(id: 93),
          member_milestone_details_tab: milestone_details_tab.MilestoneContentTab,
        ),
      )
    })
    |> milestones_view.view
    |> element.to_document_string

  string.contains(html, "data-testid=\"milestone-details-dialog\"")
  |> should.be_true
  string.contains(html, "data-testid=\"milestone-details-progress:93\"")
  |> should.be_true
  string.contains(html, "role=\"tablist\"") |> should.be_true
  string.contains(html, "data-testid=\"milestone-details-activate:93\"")
  |> should.be_false
  string.contains(html, "data-testid=\"milestone-details-new-card:93\"")
  |> should.be_false
  string.contains(html, "data-testid=\"milestone-details-new-task:93\"")
  |> should.be_false
  string.contains(html, "data-testid=\"milestone-card-row:93:701\"")
  |> should.be_true
  string.contains(html, "data-testid=\"milestone-task-row:93:801\"")
  |> should.be_true
}

pub fn milestones_view_ready_rows_show_move_actions_only_for_ready_destinations_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_milestones(
      remote.Loaded([
        sample_progress(94, Ready),
        sample_progress(95, Ready),
        sample_progress(96, Active),
      ]),
    )
    |> with_cards([sample_card(901, 94)])
    |> with_tasks([sample_loose_task(902, 94)])
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_milestones_expanded: dict.insert(dict.new(), 94, True),
        ),
      )
    })
    |> milestones_view.view
    |> element.to_document_string

  string.contains(html, "data-testid=\"milestone-move-card:94:901:95\"")
  |> should.be_true
  string.contains(html, "data-testid=\"milestone-move-task:94:902:95\"")
  |> should.be_true
  string.contains(html, "data-testid=\"milestone-move-menu-card:94:901\"")
  |> should.be_true
  string.contains(html, "data-testid=\"milestone-move-menu-task:94:902\"")
  |> should.be_true
  string.contains(html, "data-testid=\"milestone-move-card:94:901:94\"")
  |> should.be_false
  string.contains(html, "data-testid=\"milestone-move-task:94:902:94\"")
  |> should.be_false
  string.contains(html, "data-testid=\"milestone-move-card:94:901:96\"")
  |> should.be_false
  string.contains(html, "data-testid=\"milestone-move-task:94:902:96\"")
  |> should.be_false
}

pub fn milestones_view_hides_move_actions_for_non_managers_test() {
  let html =
    base_model()
    |> with_milestones(
      remote.Loaded([sample_progress(97, Ready), sample_progress(98, Ready)]),
    )
    |> with_cards([sample_card(903, 97)])
    |> with_tasks([sample_loose_task(904, 97)])
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_milestones_expanded: dict.insert(dict.new(), 97, True),
        ),
      )
    })
    |> milestones_view.view
    |> element.to_document_string

  string.contains(html, "data-testid=\"milestone-move-card:97:903:98\"")
  |> should.be_false
  string.contains(html, "data-testid=\"milestone-move-task:97:904:98\"")
  |> should.be_false
  string.contains(html, "data-testid=\"milestone-move-menu-card:97:903\"")
  |> should.be_false
  string.contains(html, "data-testid=\"milestone-move-menu-task:97:904\"")
  |> should.be_false
}

pub fn milestones_view_hides_move_actions_when_source_is_not_ready_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_milestones(
      remote.Loaded([sample_progress(99, Active), sample_progress(100, Ready)]),
    )
    |> with_cards([sample_card(905, 99)])
    |> with_tasks([sample_loose_task(906, 99)])
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_milestones_expanded: dict.insert(dict.new(), 99, True),
        ),
      )
    })
    |> milestones_view.view
    |> element.to_document_string

  string.contains(html, "data-testid=\"milestone-move-card:99:905:100\"")
  |> should.be_false
  string.contains(html, "data-testid=\"milestone-move-task:99:906:100\"")
  |> should.be_false
}

pub fn milestones_view_ready_rows_render_drop_targets_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_milestones(
      remote.Loaded([sample_progress(101, Ready), sample_progress(102, Active)]),
    )
    |> milestones_view.view
    |> element.to_document_string

  string.contains(html, "data-drop-target=\"101\"")
  |> should.be_true
  string.contains(html, "data-drop-target=\"102\"")
  |> should.be_false
}

pub fn milestones_view_rows_are_draggable_only_when_move_is_possible_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_milestones(
      remote.Loaded([sample_progress(103, Ready), sample_progress(104, Ready)]),
    )
    |> with_cards([sample_card(907, 103)])
    |> with_tasks([sample_loose_task(908, 103)])
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_milestones_expanded: dict.insert(dict.new(), 103, True),
        ),
      )
    })
    |> milestones_view.view
    |> element.to_document_string

  string.contains(
    html,
    "data-testid=\"milestone-card-row:103:907\" draggable=\"true\"",
  )
  |> should.be_true
  string.contains(
    html,
    "data-testid=\"milestone-task-row:103:908\" draggable=\"true\"",
  )
  |> should.be_true
}

pub fn milestones_view_uses_es_i18n_labels_and_statuses_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_locale(i18n_locale.Es)
    |> with_milestones(remote.Loaded([sample_progress(120, Ready)]))
    |> with_cards([sample_card(920, 120)])
    |> with_tasks([sample_loose_task(921, 120)])
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_milestones_expanded: dict.insert(dict.new(), 120, True),
        ),
      )
    })
    |> milestones_view.view
    |> element.to_document_string

  string.contains(html, ">Tarjetas<") |> should.be_true
  string.contains(html, ">Tareas<") |> should.be_true
  string.contains(html, "disponible") |> should.be_true
}

pub fn milestones_view_uses_en_i18n_labels_and_statuses_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_locale(i18n_locale.En)
    |> with_milestones(remote.Loaded([sample_progress(121, Ready)]))
    |> with_cards([sample_card(930, 121)])
    |> with_tasks([sample_loose_task(931, 121)])
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_milestones_expanded: dict.insert(dict.new(), 121, True),
        ),
      )
    })
    |> milestones_view.view
    |> element.to_document_string

  string.contains(html, ">Cards<") |> should.be_true
  string.contains(html, ">Tasks<") |> should.be_true
  string.contains(html, "available") |> should.be_true
}

pub fn milestone_metrics_error_copy_i18n_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_locale(i18n_locale.Es)
    |> with_milestones(remote.Loaded([sample_progress(140, Ready)]))
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_milestone_dialog: member_pool.MilestoneDialogView(140),
          member_milestone_details_tab: milestone_details_tab.MilestoneMetricsTab,
        ),
      )
    })
    |> with_milestone_metrics(
      remote.Failed(ApiError(
        status: 409,
        code: "metrics_unavailable",
        message: "x",
      )),
    )
    |> milestones_view.view
    |> element.to_document_string

  string.contains(html, "No se pudieron cargar métricas") |> should.be_true
}

pub fn milestone_metrics_empty_copy_i18n_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_locale(i18n_locale.En)
    |> with_milestones(remote.Loaded([sample_progress(141, Ready)]))
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_milestone_dialog: member_pool.MilestoneDialogView(141),
          member_milestone_details_tab: milestone_details_tab.MilestoneMetricsTab,
        ),
      )
    })
    |> with_milestone_metrics(
      remote.Loaded(MilestoneModalMetrics(
        cards_total: 0,
        cards_completed: 0,
        cards_percent: 0,
        tasks_total: 0,
        tasks_completed: 0,
        tasks_percent: 0,
        tasks_available: 0,
        tasks_claimed: 0,
        tasks_ongoing: 0,
        health: ModalExecutionHealth(
          avg_rebotes: 0,
          avg_pool_lifetime_s: 0,
          avg_executors: 0,
        ),
        workflows: [WorkflowBreakdown(name: "none", count: 0)],
        most_activated: None,
      )),
    )
    |> milestones_view.view
    |> element.to_document_string

  string.contains(html, "Not enough data for metrics") |> should.be_true
}
