import gleam/int
import gleam/option.{None, Some}
import gleam/string
import lustre/element

import domain/api_error.{ApiError}
import domain/card.{Card, Pendiente}
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
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/client_state/selectors as state_selectors
import scrumbringer_client/client_state/ui as ui_state
import scrumbringer_client/features/milestones/access as milestone_access
import scrumbringer_client/features/milestones/view_config as milestones_view
import scrumbringer_client/i18n/locale as i18n_locale

fn assert_true(value: Bool) {
  let assert True = value
}

fn assert_false(value: Bool) {
  let assert False = value
}

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

fn milestone_callbacks() -> milestones_view.Callbacks(String) {
  milestones_view.Callbacks(
    on_create_milestone: "create-milestone",
    on_dialog_close: "dialog-close",
    on_activate_clicked: fn(id) { "activate:" <> int.to_string(id) },
    on_create_submitted: "create-submitted",
    on_edit_submitted: fn(id) { "edit-submitted:" <> int.to_string(id) },
    on_delete_submitted: fn(id) { "delete-submitted:" <> int.to_string(id) },
    on_name_changed: fn(value) { "name:" <> value },
    on_description_changed: fn(value) { "description:" <> value },
    on_search_change: fn(value) { "search:" <> value },
    on_toggle_completed: "toggle-completed",
    on_toggle_empty: "toggle-empty",
    on_view_kanban: "view-kanban",
    on_select: fn(id) { "select:" <> int.to_string(id) },
    on_summary_toggle: "summary-toggle",
    on_card_toggle: fn(id) { "card-toggle:" <> int.to_string(id) },
    on_quick_create_card: fn(id) { "quick-card:" <> int.to_string(id) },
    on_quick_create_task: fn(id) { "quick-task:" <> int.to_string(id) },
    on_activate_prompt: fn(id) { "activate-prompt:" <> int.to_string(id) },
    on_edit: fn(id) { "edit:" <> int.to_string(id) },
    on_delete: fn(id) { "delete:" <> int.to_string(id) },
    on_task_open: fn(id) { "task-open:" <> int.to_string(id) },
    on_task_claim: fn(id, version) {
      "claim:" <> int.to_string(id) <> ":" <> int.to_string(version)
    },
    on_card_drag_started: fn(card_id, milestone_id) {
      "card-drag:"
      <> int.to_string(card_id)
      <> ":"
      <> int.to_string(milestone_id)
    },
    on_task_drag_started: fn(task_id, milestone_id) {
      "task-drag:"
      <> int.to_string(task_id)
      <> ":"
      <> int.to_string(milestone_id)
    },
    on_drag_ended: "drag-ended",
    on_card_move: fn(card_id, milestone_id, destination_id) {
      "card-move:"
      <> int.to_string(card_id)
      <> ":"
      <> int.to_string(milestone_id)
      <> ":"
      <> int.to_string(destination_id)
    },
    on_task_move: fn(task_id, milestone_id, destination_id) {
      "task-move:"
      <> int.to_string(task_id)
      <> ":"
      <> int.to_string(milestone_id)
      <> ":"
      <> int.to_string(destination_id)
    },
    on_card_create_task: fn(card_id) {
      "card-create-task:" <> int.to_string(card_id)
    },
    on_card_edit: fn(card_id) { "card-edit:" <> int.to_string(card_id) },
    on_card_delete: fn(card_id) { "card-delete:" <> int.to_string(card_id) },
  )
}

fn view_milestones(model: client_state.Model) {
  milestones_view.view(
    model.ui.locale,
    model.ui.theme,
    model.core.selected_project_id,
    model.member.pool,
    model.admin.members.org_users_cache,
    milestone_access.can_manage(
      model.core.user,
      state_selectors.selected_project(model),
    ),
    milestone_callbacks(),
  )
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

fn with_selected_milestone(
  model: client_state.Model,
  milestone_id: Int,
) -> client_state.Model {
  client_state.update_member(model, fn(member) {
    let pool = member.pool
    member_state.MemberModel(
      ..member,
      pool: member_pool.Model(
        ..pool,
        member_selected_milestone_id: Some(milestone_id),
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

fn with_summary_expanded(
  model: client_state.Model,
  expanded: Bool,
) -> client_state.Model {
  client_state.update_member(model, fn(member) {
    let pool = member.pool
    member_state.MemberModel(
      ..member,
      pool: member_pool.Model(
        ..pool,
        member_milestone_summary_expanded: expanded,
      ),
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

fn sample_card_task(id: Int, _milestone_id: Int, card_id: Int) -> Task {
  let state = task_state.Available
  Task(
    id: id,
    project_id: 1,
    type_id: 1,
    task_type: TaskTypeInline(id: 1, name: "Task", icon: "check"),
    ongoing_by: None,
    title: "Card task " <> int.to_string(id),
    description: None,
    priority: 1,
    state: state,
    status: task_state.to_status(state),
    work_state: task_state.to_work_state(state),
    created_by: 1,
    created_at: "2026-02-06T00:00:00Z",
    version: 1,
    milestone_id: None,
    card_id: Some(card_id),
    card_title: Some("Card " <> int.to_string(card_id)),
    card_color: None,
    has_new_notes: False,
    blocked_count: 0,
    dependencies: [],
  )
}

fn sample_blocked_card_task(id: Int, milestone_id: Int, card_id: Int) -> Task {
  let task = sample_card_task(id, milestone_id, card_id)
  Task(..task, blocked_count: 1)
}

pub fn milestones_view_loading_state_test() {
  let html =
    base_model()
    |> with_milestones(remote.Loading)
    |> view_milestones
    |> element.to_document_string

  string.contains(html, "milestones-loading") |> assert_true
}

pub fn milestones_view_error_state_test() {
  let html =
    base_model()
    |> with_milestones(
      remote.Failed(ApiError(status: 500, code: "E_M", message: "boom")),
    )
    |> view_milestones
    |> element.to_document_string

  string.contains(html, "Could not load milestones") |> assert_true
}

pub fn milestones_view_empty_state_test() {
  let html =
    base_model()
    |> with_milestones(remote.Loaded([]))
    |> view_milestones
    |> element.to_document_string

  string.contains(html, "No milestones yet") |> assert_true
  string.contains(html, "class=\"empty-state\"") |> assert_true
}

pub fn milestones_view_shows_create_button_for_managers_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_milestones(remote.Loaded([sample_progress(12, Ready)]))
    |> view_milestones
    |> element.to_document_string

  string.contains(html, "data-testid=\"milestones-create-button\"")
  |> assert_true
  string.contains(html, "btn-global-action") |> assert_true
  string.contains(html, "Create milestone") |> assert_true
}

pub fn milestones_view_hides_create_button_for_non_managers_test() {
  let html =
    base_model()
    |> with_milestones(remote.Loaded([sample_progress(12, Ready)]))
    |> view_milestones
    |> element.to_document_string

  string.contains(html, "data-testid=\"milestones-create-button\"")
  |> assert_false
}

pub fn milestones_view_empty_state_shows_create_first_cta_for_manager_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_milestones(remote.Loaded([]))
    |> view_milestones
    |> element.to_document_string

  string.contains(html, "data-testid=\"milestones-create-empty\"")
  |> assert_true
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
    |> view_milestones
    |> element.to_document_string

  string.contains(html, "milestone-create-form") |> assert_true
  string.contains(html, "Create milestone") |> assert_true
}

pub fn milestones_view_rows_include_stable_testids_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_milestones(remote.Loaded([sample_progress(12, Ready)]))
    |> view_milestones
    |> element.to_document_string

  string.contains(html, "data-testid=\"milestone-row:12\"") |> assert_true
  string.contains(html, "data-testid=\"milestone-detail-pane\"")
  |> assert_true
  string.contains(html, "data-testid=\"milestones-search\"")
  |> assert_true
}

pub fn milestones_view_hides_actions_for_non_managers_test() {
  let html =
    base_model()
    |> with_milestones(remote.Loaded([sample_progress(7, Ready)]))
    |> view_milestones
    |> element.to_document_string

  string.contains(html, "milestone-activate-button:7") |> assert_false
  string.contains(html, "milestone-edit-button:7") |> assert_false
  string.contains(html, "milestone-delete-button:7") |> assert_false
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
    |> with_selected_milestone(1)
    |> view_milestones
    |> element.to_document_string

  string.contains(html, "milestone-delete-button:1") |> assert_true
  string.contains(html, "milestone-delete-button:2") |> assert_false
  string.contains(html, "milestone-delete-button:3") |> assert_false
}

pub fn milestones_view_blocks_activate_when_another_active_exists_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_milestones(
      remote.Loaded([sample_progress(11, Ready), sample_progress(99, Active)]),
    )
    |> view_milestones
    |> element.to_document_string

  string.contains(html, "milestone-activate-button:11") |> assert_false
}

pub fn milestones_view_disables_activate_button_while_in_flight_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_milestones(remote.Loaded([sample_progress(22, Ready)]))
    |> with_selected_milestone(22)
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
    |> view_milestones
    |> element.to_document_string

  string.contains(html, "data-testid=\"milestone-activate-button:22\"")
  |> assert_true
  string.contains(html, "disabled") |> assert_true
}

pub fn milestones_view_renders_detail_progress_and_tabs_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_milestones(remote.Loaded([sample_progress(33, Ready)]))
    |> with_summary_expanded(True)
    |> view_milestones
    |> element.to_document_string

  string.contains(html, "milestone-detail-pane") |> assert_true
  string.contains(html, "Structure summary") |> assert_true
  string.contains(html, "View in Kanban") |> assert_true
}

pub fn milestones_view_marks_selected_row_with_aria_pressed_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_milestones(remote.Loaded([sample_progress(44, Ready)]))
    |> view_milestones
    |> element.to_document_string

  string.contains(html, "aria-pressed=\"true\"") |> assert_true
}

pub fn milestones_view_filter_toggles_present_and_default_unchecked_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_milestones(remote.Loaded([sample_progress(55, Ready)]))
    |> view_milestones
    |> element.to_document_string

  string.contains(html, "data-testid=\"milestones-filter-completed\"")
  |> assert_true
  string.contains(html, "data-testid=\"milestones-filter-empty\"")
  |> assert_true
  string.contains(html, "data-testid=\"milestones-filter-completed\" checked")
  |> assert_false
  string.contains(html, "data-testid=\"milestones-filter-empty\" checked")
  |> assert_false
}

pub fn milestones_view_hides_completed_section_when_filter_unchecked_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_milestones(
      remote.Loaded([sample_progress(71, Ready), sample_progress(72, Completed)]),
    )
    |> view_milestones
    |> element.to_document_string

  string.contains(html, "<h4 class=\"milestones-section-title\">Completed</h4>")
  |> assert_false
}

pub fn milestones_view_shows_completed_section_when_filter_checked_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_show_completed(True)
    |> with_milestones(
      remote.Loaded([sample_progress(81, Ready), sample_progress(82, Completed)]),
    )
    |> view_milestones
    |> element.to_document_string

  string.contains(html, "Completed") |> assert_true
}

pub fn milestones_view_hides_active_section_when_empty_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_milestones(remote.Loaded([sample_progress(91, Ready)]))
    |> view_milestones
    |> element.to_document_string

  string.contains(html, "<h4 class=\"milestones-section-title\">Active</h4>")
  |> assert_false
}

pub fn milestones_view_hides_ready_section_when_empty_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_show_completed(True)
    |> with_milestones(remote.Loaded([sample_progress(92, Active)]))
    |> view_milestones
    |> element.to_document_string

  string.contains(html, "<h4 class=\"milestones-section-title\">Ready</h4>")
  |> assert_false
}

pub fn milestones_view_activate_button_opens_prompt_dialog_contract_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_milestones(remote.Loaded([sample_progress(66, Ready)]))
    |> with_activate_dialog(66)
    |> view_milestones
    |> element.to_document_string

  string.contains(html, "Activate milestone") |> assert_true
  string.contains(html, "This action is irreversible") |> assert_true
  string.contains(html, "autofocus") |> assert_true
}

pub fn milestones_view_legacy_expand_state_does_not_change_selection_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_milestones(remote.Loaded([sample_progress(77, Ready)]))
    |> with_selected_milestone(77)
    |> view_milestones
    |> element.to_document_string

  string.contains(html, "milestone-detail-pane") |> assert_true
  string.contains(html, "data-testid=\"milestone-activate-button:77\"")
  |> assert_true
}

pub fn milestones_view_open_dialog_does_not_expand_row_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_milestones(remote.Loaded([sample_progress(88, Ready)]))
    |> with_activate_dialog(88)
    |> view_milestones
    |> element.to_document_string

  string.contains(html, "Activate milestone") |> assert_true
  string.contains(html, "data-testid=\"milestone-row-toggle") |> assert_false
}

pub fn milestones_view_expanded_row_renders_milestone_cards_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_milestones(remote.Loaded([sample_progress(90, Ready)]))
    |> with_cards([sample_card(501, 90)])
    |> with_selected_milestone(90)
    |> view_milestones
    |> element.to_document_string

  string.contains(html, "data-testid=\"milestone-card-row:90:501\"")
  |> assert_true
}

pub fn milestones_view_expanded_row_renders_loose_tasks_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_milestones(remote.Loaded([sample_progress(91, Ready)]))
    |> with_tasks([sample_loose_task(601, 91)])
    |> with_selected_milestone(91)
    |> view_milestones
    |> element.to_document_string

  string.contains(html, "data-testid=\"milestone-task-row:91:601\"")
  |> assert_true
}

pub fn milestones_view_detail_renders_quick_new_card_cta_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_milestones(remote.Loaded([sample_progress(92, Ready)]))
    |> with_selected_milestone(92)
    |> view_milestones
    |> element.to_document_string

  string.contains(html, "data-testid=\"milestone-quick-new-card:92\"")
  |> assert_true
  string.contains(html, "aria-label=\"New card\"") |> assert_true
}

pub fn milestones_view_detail_renders_quick_new_task_cta_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_milestones(remote.Loaded([sample_progress(98, Ready)]))
    |> with_selected_milestone(98)
    |> view_milestones
    |> element.to_document_string

  string.contains(html, "data-testid=\"milestone-quick-new-task:98\"")
  |> assert_true
  string.contains(html, "aria-label=\"New task\"") |> assert_true
}

pub fn milestones_view_keeps_quick_new_card_entrypoint_available_for_mobile_strategy_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_milestones(remote.Loaded([sample_progress(99, Ready)]))
    |> with_selected_milestone(99)
    |> view_milestones
    |> element.to_document_string

  // AC5: entrypoint should remain available even when layout adapts on small screens.
  string.contains(html, "data-testid=\"milestone-quick-new-card:99\"")
  |> assert_true
}

pub fn milestones_view_detail_pane_renders_progress_and_content_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_milestones(remote.Loaded([sample_progress(93, Ready)]))
    |> with_cards([sample_card(701, 93)])
    |> with_tasks([sample_loose_task(801, 93), sample_card_task(802, 93, 701)])
    |> with_selected_milestone(93)
    |> view_milestones
    |> element.to_document_string

  string.contains(html, "data-testid=\"milestone-detail-pane\"")
  |> assert_true
  string.contains(html, "data-testid=\"milestone-card-row:93:701\"")
  |> assert_true
  string.contains(html, "milestone-delivery-card") |> assert_true
  string.contains(html, "Card task 802") |> assert_false
  string.contains(html, "data-testid=\"milestone-task-row:93:801\"")
  |> assert_true
  string.contains(html, "tasks in cards") |> assert_false
}

pub fn milestones_view_detail_surfaces_phase4_structure_summary_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_milestones(remote.Loaded([sample_progress(150, Ready)]))
    |> with_cards([sample_card(960, 150)])
    |> with_tasks([
      sample_loose_task(961, 150),
      sample_blocked_card_task(962, 150, 960),
    ])
    |> with_selected_milestone(150)
    |> view_milestones
    |> element.to_document_string

  string.contains(html, "data-testid=\"milestone-structure-strip\"")
  |> assert_true
  string.contains(html, "3 cards") |> assert_true
  string.contains(html, "1 loose tasks") |> assert_true
  string.contains(html, "1 blocked tasks") |> assert_true
  string.contains(html, "milestone-card-status-chip") |> assert_true
  string.contains(html, "milestone-card-health-chip") |> assert_false
  string.contains(html, "Tasks without card") |> assert_true
  string.contains(html, "milestone-content-note") |> assert_false
}

pub fn milestones_view_planning_tab_surfaces_structure_actions_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_milestones(
      remote.Loaded([
        sample_progress(142, Ready),
        sample_progress(143, Ready),
      ]),
    )
    |> with_cards([sample_card(950, 142)])
    |> with_tasks([sample_loose_task(951, 142)])
    |> with_selected_milestone(142)
    |> with_summary_expanded(True)
    |> view_milestones
    |> element.to_document_string

  string.contains(html, "Structure summary") |> assert_true
  string.contains(html, "data-testid=\"milestone-quick-new-card:142\"")
  |> assert_true
  string.contains(html, "data-testid=\"milestone-move-card:142:950:143\"")
  |> assert_true
  string.contains(html, "Tasks without card") |> assert_true
  string.contains(html, "data-testid=\"milestone-task-row:142:951\"")
  |> assert_true
}

pub fn milestones_view_detail_shows_move_actions_only_for_ready_destinations_test() {
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
    |> with_selected_milestone(94)
    |> view_milestones
    |> element.to_document_string

  string.contains(html, "data-testid=\"milestone-move-card:94:901:95\"")
  |> assert_true
  string.contains(html, "data-testid=\"milestone-move-task:94:902:95\"")
  |> assert_true
  string.contains(html, "data-testid=\"milestone-move-menu-card:94:901\"")
  |> assert_true
  string.contains(html, "data-testid=\"milestone-move-menu-task:94:902\"")
  |> assert_true
  string.contains(html, "data-testid=\"milestone-move-card:94:901:94\"")
  |> assert_false
  string.contains(html, "data-testid=\"milestone-move-task:94:902:94\"")
  |> assert_false
  string.contains(html, "data-testid=\"milestone-move-card:94:901:96\"")
  |> assert_false
  string.contains(html, "data-testid=\"milestone-move-task:94:902:96\"")
  |> assert_false
  string.contains(html, "class=\"move-menu\"")
  |> assert_true
}

pub fn milestones_view_uses_header_action_cluster_layout_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_milestones(remote.Loaded([sample_progress(122, Ready)]))
    |> with_selected_milestone(122)
    |> view_milestones
    |> element.to_document_string

  string.contains(html, "class=\"milestone-detail-actions\"")
  |> assert_true
}

pub fn milestones_view_hides_move_actions_for_non_managers_test() {
  let html =
    base_model()
    |> with_milestones(
      remote.Loaded([sample_progress(97, Ready), sample_progress(98, Ready)]),
    )
    |> with_cards([sample_card(903, 97)])
    |> with_tasks([sample_loose_task(904, 97)])
    |> with_selected_milestone(97)
    |> view_milestones
    |> element.to_document_string

  string.contains(html, "data-testid=\"milestone-move-card:97:903:98\"")
  |> assert_false
  string.contains(html, "data-testid=\"milestone-move-task:97:904:98\"")
  |> assert_false
  string.contains(html, "data-testid=\"milestone-move-menu-card:97:903\"")
  |> assert_false
  string.contains(html, "data-testid=\"milestone-move-menu-task:97:904\"")
  |> assert_false
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
    |> with_selected_milestone(99)
    |> view_milestones
    |> element.to_document_string

  string.contains(html, "data-testid=\"milestone-move-card:99:905:100\"")
  |> assert_false
  string.contains(html, "data-testid=\"milestone-move-task:99:906:100\"")
  |> assert_false
}

pub fn milestones_view_ready_rows_render_as_selectable_master_items_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_milestones(
      remote.Loaded([sample_progress(101, Ready), sample_progress(102, Active)]),
    )
    |> view_milestones
    |> element.to_document_string

  string.contains(html, "data-testid=\"milestone-row:101\"") |> assert_true
  string.contains(html, "data-testid=\"milestone-row:102\"") |> assert_true
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
    |> with_selected_milestone(103)
    |> view_milestones
    |> element.to_document_string

  string.contains(
    html,
    "data-testid=\"milestone-card-row:103:907\" draggable=\"true\"",
  )
  |> assert_true
  string.contains(
    html,
    "data-testid=\"milestone-task-row:103:908\" draggable=\"true\"",
  )
  |> assert_true
}

pub fn milestones_view_uses_es_i18n_labels_and_statuses_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_locale(i18n_locale.Es)
    |> with_milestones(remote.Loaded([sample_progress(120, Ready)]))
    |> with_cards([sample_card(920, 120)])
    |> with_tasks([sample_loose_task(921, 120)])
    |> with_selected_milestone(120)
    |> view_milestones
    |> element.to_document_string

  string.contains(html, ">Tarjetas<") |> assert_true
  string.contains(html, ">Tareas sin card<") |> assert_true
  string.contains(html, "disponible") |> assert_true
}

pub fn milestones_view_uses_en_i18n_labels_and_statuses_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_locale(i18n_locale.En)
    |> with_milestones(remote.Loaded([sample_progress(121, Ready)]))
    |> with_cards([sample_card(930, 121)])
    |> with_tasks([sample_loose_task(931, 121)])
    |> with_selected_milestone(121)
    |> view_milestones
    |> element.to_document_string

  string.contains(html, ">Cards<") |> assert_true
  string.contains(html, ">Tasks without card<") |> assert_true
  string.contains(html, "available") |> assert_true
}

pub fn milestones_view_structure_complete_copy_i18n_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_locale(i18n_locale.Es)
    |> with_milestones(remote.Loaded([sample_progress(140, Ready)]))
    |> with_selected_milestone(140)
    |> with_summary_expanded(True)
    |> view_milestones
    |> element.to_document_string

  string.contains(html, "Estructura completa") |> assert_true
}

pub fn milestones_view_delivery_plan_omits_modal_metrics_test() {
  let html =
    base_model()
    |> with_admin_user
    |> with_locale(i18n_locale.En)
    |> with_milestones(remote.Loaded([sample_progress(141, Ready)]))
    |> with_selected_milestone(141)
    |> with_summary_expanded(True)
    |> view_milestones
    |> element.to_document_string

  string.contains(html, "Metrics") |> assert_false
  string.contains(html, "Structure complete") |> assert_true
}
