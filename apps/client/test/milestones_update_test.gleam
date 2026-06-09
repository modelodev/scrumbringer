import gleam/int
import gleam/option.{None, Some}
import lustre/effect

import domain/api_error.{ApiError}
import domain/card.{Card, Pendiente}
import domain/milestone.{
  type Milestone, type MilestoneProgress, type MilestoneState, Active, Milestone,
  MilestoneProgress, Ready,
}
import domain/remote.{Failed, Loaded, Loading}
import domain/task.{Task}
import domain/task_state
import domain/task_type.{TaskTypeInline}

import scrumbringer_client/client_state
import scrumbringer_client/client_state/admin as admin_state
import scrumbringer_client/client_state/admin/cards as admin_cards
import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/client_state/types as state_types
import scrumbringer_client/features/milestones/ids as milestone_ids
import scrumbringer_client/features/milestones/update as milestones_update
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/pool/update as pool_update
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/member_section
import scrumbringer_client/pool_prefs

fn assert_equal(actual: a, expected: a) {
  let assert True = actual == expected
}

fn assert_not_equal(actual: a, expected: a) {
  let assert False = actual == expected
}

fn test_context() -> pool_update.Context {
  pool_update.Context(member_refresh: fn(model) {
    #(
      client_state.update_member(model, fn(member) {
        let pool = member.pool
        member_state.MemberModel(
          ..member,
          pool: member_pool.Model(..pool, member_filters_q: "refreshed"),
        )
      }),
      effect.none(),
    )
  })
}

fn local_context(selected_project_id) -> milestones_update.Context(Nil) {
  milestones_update.Context(
    selected_project_id: selected_project_id,
    on_milestone_activated: fn(_milestone_id, _result) { Nil },
    on_milestone_created: fn(_result) { Nil },
    on_milestone_updated: fn(_result) { Nil },
    on_milestone_deleted: fn(_milestone_id, _result) { Nil },
    on_milestone_metrics_fetched: fn(_result) { Nil },
    on_milestone_card_moved: fn(_result) { Nil },
    on_milestone_task_moved: fn(_result) { Nil },
    name_required: "Name required",
    select_project_first: "Select project first",
  )
}

fn feedback_context() -> milestones_update.FeedbackContext(Nil) {
  milestones_update.FeedbackContext(
    milestone_activated: "Milestone activated",
    milestone_created: "Milestone created",
    milestone_updated: "Milestone updated",
    milestone_deleted: "Milestone deleted",
    milestone_activate_failed: "Could not activate milestone",
    milestone_create_failed: "Could not create milestone",
    milestone_update_failed: "Could not update milestone",
    milestone_delete_failed: "Could not delete milestone",
    milestone_already_active: "Another milestone is already active",
    milestone_activation_irreversible: "Activation cannot be undone",
    milestone_delete_not_allowed: "Milestone must be ready and empty",
    on_success_toast: fn(_message) { effect.from(fn(_dispatch) { Nil }) },
    on_error_toast: fn(_message) { effect.from(fn(_dispatch) { Nil }) },
  )
}

fn sample_progress(id: Int) -> MilestoneProgress {
  sample_progress_state(id, Ready)
}

fn sample_milestone(id: Int) -> Milestone {
  Milestone(
    id: id,
    project_id: 1,
    name: "Milestone " <> int.to_string(id),
    description: Some("Desc"),
    state: Ready,
    position: 1,
    created_by: 1,
    activated_at: None,
    completed_at: None,
    created_at: "2026-01-01T00:00:00Z",
  )
}

fn sample_progress_state(id: Int, state: MilestoneState) -> MilestoneProgress {
  MilestoneProgress(
    milestone: Milestone(
      id: id,
      project_id: 1,
      name: "Milestone " <> int.to_string(id),
      description: Some("Desc"),
      state: state,
      position: 1,
      created_by: 1,
      created_at: "2026-01-01T00:00:00Z",
      activated_at: None,
      completed_at: None,
    ),
    cards_total: 3,
    cards_completed: 1,
    tasks_total: 6,
    tasks_completed: 2,
  )
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
    created_at: "2026-01-01T00:00:00Z",
    has_new_notes: False,
  )
}

fn sample_task_in(id: Int, milestone_id: Int) {
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
    created_at: "2026-01-01T00:00:00Z",
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

fn sample_task(id: Int) {
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
    created_at: "2026-01-01T00:00:00Z",
    version: 1,
    milestone_id: Some(7),
    card_id: None,
    card_title: None,
    card_color: None,
    has_new_notes: False,
    blocked_count: 0,
    dependencies: [],
  )
}

pub fn local_milestone_create_submit_requires_name_test() {
  let model =
    member_pool.Model(
      ..member_pool.default_model(),
      member_milestone_dialog: member_pool.MilestoneDialogCreate(
        name: "",
        description: "",
      ),
    )

  let #(next, fx) =
    milestones_update.handle_milestone_create_submitted(
      model,
      local_context(Some(8)),
    )

  next.member_milestone_dialog_error |> assert_equal(Some("Name required"))
  let assert True = fx == effect.none()
}

pub fn local_milestone_create_submit_requires_project_test() {
  let model =
    member_pool.Model(
      ..member_pool.default_model(),
      member_milestone_dialog: member_pool.MilestoneDialogCreate(
        name: "Release",
        description: "desc",
      ),
    )

  let #(next, fx) =
    milestones_update.handle_milestone_create_submitted(
      model,
      local_context(None),
    )

  next.member_milestone_dialog_error
  |> assert_equal(Some("Select project first"))
  let assert True = fx == effect.none()
}

pub fn local_milestone_create_submit_sets_in_flight_test() {
  let model =
    member_pool.Model(
      ..member_pool.default_model(),
      member_milestone_dialog: member_pool.MilestoneDialogCreate(
        name: " Release ",
        description: "desc",
      ),
    )

  let #(next, _fx) =
    milestones_update.handle_milestone_create_submitted(
      model,
      local_context(Some(8)),
    )

  next.member_milestone_dialog_in_flight |> assert_equal(True)
  next.member_milestone_dialog_error |> assert_equal(None)
}

pub fn local_milestone_edit_clicked_uses_loaded_milestone_test() {
  let model =
    member_pool.Model(
      ..member_pool.default_model(),
      member_milestones: Loaded([sample_progress(9)]),
    )

  let #(next, fx) = milestones_update.handle_milestone_edit_clicked(model, 9)

  next.member_milestone_dialog
  |> assert_equal(member_pool.MilestoneDialogEdit(
    id: 9,
    name: "Milestone 9",
    description: "Desc",
  ))
  let assert True = fx == effect.none()
}

pub fn local_milestone_deleted_ok_clears_matching_selection_test() {
  let model =
    member_pool.Model(
      ..member_pool.default_model(),
      member_milestone_dialog: member_pool.MilestoneDialogDelete(
        id: 9,
        name: "Milestone 9",
      ),
      member_milestone_dialog_in_flight: True,
      member_selected_milestone_id: Some(9),
    )

  let #(next, fx) = milestones_update.handle_milestone_deleted_ok(model, 9)

  next.member_milestone_dialog
  |> assert_equal(member_pool.MilestoneDialogClosed)
  next.member_selected_milestone_id |> assert_equal(None)
  let assert True = fx == effect.none()
}

pub fn milestone_success_effect_uses_feedback_context_test() {
  let fx =
    milestones_update.success_effect(
      milestones_update.MilestoneCreated,
      feedback_context(),
    )

  let assert True = fx != effect.none()
}

pub fn milestone_error_message_uses_known_code_label_test() {
  let message =
    milestones_update.error_message(
      ApiError(
        status: 409,
        code: "MILESTONE_ALREADY_ACTIVE",
        message: "backend",
      ),
      milestones_update.MilestoneActivateFailed,
      feedback_context(),
    )

  message |> assert_equal("Another milestone is already active")
}

pub fn milestone_error_message_uses_failure_fallback_when_backend_empty_test() {
  let message =
    milestones_update.error_message(
      ApiError(status: 500, code: "UNKNOWN", message: ""),
      milestones_update.MilestoneDeleteFailed,
      feedback_context(),
    )

  message |> assert_equal("Could not delete milestone")
}

pub fn milestone_error_effect_emits_feedback_test() {
  let fx =
    milestones_update.error_effect(
      ApiError(status: 500, code: "UNKNOWN", message: "Backend failed"),
      milestones_update.MilestoneUpdateFailed,
      feedback_context(),
    )

  let assert True = fx != effect.none()
}

pub fn milestone_activate_clicked_sets_in_flight_id_test() {
  let model = client_state.default_model()

  let #(next, _fx) =
    pool_update.update(
      model,
      pool_messages.MemberMilestoneActivateClicked(42),
      test_context(),
    )

  next.member.pool.member_milestone_activate_in_flight_id
  |> assert_equal(Some(42))
  next.member.pool.member_milestone_dialog_in_flight |> assert_equal(True)
}

pub fn milestone_activate_prompt_opens_dialog_test() {
  let model = client_state.default_model()

  let #(next, _fx) =
    pool_update.update(
      model,
      pool_messages.MemberMilestoneActivatePromptClicked(42),
      test_context(),
    )

  next.member.pool.member_milestone_dialog
  |> assert_equal(member_pool.MilestoneDialogActivate(42))
}

pub fn milestone_dialog_closed_resets_dialog_state_test() {
  let model =
    client_state.default_model()
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_milestone_dialog: member_pool.MilestoneDialogActivate(42),
          member_milestone_dialog_in_flight: True,
          member_milestone_dialog_error: Some("boom"),
        ),
      )
    })

  let #(next, _fx) =
    pool_update.update(
      model,
      pool_messages.MemberMilestoneDialogClosed,
      test_context(),
    )

  next.member.pool.member_milestone_dialog
  |> assert_equal(member_pool.MilestoneDialogClosed)
  next.member.pool.member_milestone_dialog_in_flight |> assert_equal(False)
  next.member.pool.member_milestone_dialog_error |> assert_equal(None)
}

pub fn milestone_create_clicked_opens_create_dialog_test() {
  let model = client_state.default_model()

  let #(next, _fx) =
    pool_update.update(
      model,
      pool_messages.MemberMilestoneCreateClicked,
      test_context(),
    )

  next.member.pool.member_milestone_dialog
  |> assert_equal(member_pool.MilestoneDialogCreate(name: "", description: ""))
}

pub fn milestone_name_changed_updates_create_dialog_test() {
  let model =
    client_state.default_model()
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_milestone_dialog: member_pool.MilestoneDialogCreate(
            name: "old",
            description: "desc",
          ),
        ),
      )
    })

  let #(next, _fx) =
    pool_update.update(
      model,
      pool_messages.MemberMilestoneNameChanged("Release 2"),
      test_context(),
    )

  next.member.pool.member_milestone_dialog
  |> assert_equal(member_pool.MilestoneDialogCreate(
    name: "Release 2",
    description: "desc",
  ))
}

pub fn milestone_create_submitted_validates_required_name_test() {
  let model =
    client_state.default_model()
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

  let #(next, _fx) =
    pool_update.update(
      model,
      pool_messages.MemberMilestoneCreateSubmitted,
      test_context(),
    )

  next.member.pool.member_milestone_dialog_error
  |> assert_equal(Some(i18n.t(next.ui.locale, i18n_text.NameRequired)))
}

pub fn milestone_create_submitted_validates_required_name_when_trimmed_test() {
  let model =
    client_state.default_model()
    |> client_state.update_core(fn(core) {
      client_state.CoreModel(..core, selected_project_id: Some(8))
    })
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_milestone_dialog: member_pool.MilestoneDialogCreate(
            name: "   ",
            description: "",
          ),
        ),
      )
    })

  let #(next, _fx) =
    pool_update.update(
      model,
      pool_messages.MemberMilestoneCreateSubmitted,
      test_context(),
    )

  next.member.pool.member_milestone_dialog_error
  |> assert_equal(Some(i18n.t(next.ui.locale, i18n_text.NameRequired)))
}

pub fn milestone_create_submitted_requires_selected_project_test() {
  let model =
    client_state.default_model()
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_milestone_dialog: member_pool.MilestoneDialogCreate(
            name: "Release 2",
            description: "desc",
          ),
        ),
      )
    })

  let #(next, _fx) =
    pool_update.update(
      model,
      pool_messages.MemberMilestoneCreateSubmitted,
      test_context(),
    )

  next.member.pool.member_milestone_dialog_error
  |> assert_equal(Some(i18n.t(next.ui.locale, i18n_text.SelectProjectFirst)))
}

pub fn milestone_created_ok_opens_details_for_new_milestone_test() {
  let created = sample_progress(33).milestone

  let model =
    client_state.default_model()
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_milestone_dialog: member_pool.MilestoneDialogCreate(
            name: "Release 33",
            description: "desc",
          ),
          member_milestone_dialog_in_flight: True,
        ),
      )
    })

  let #(next, _fx) =
    pool_update.update(
      model,
      pool_messages.MemberMilestoneCreated(Ok(created)),
      test_context(),
    )

  next.member.pool.member_milestone_dialog
  |> assert_equal(member_pool.MilestoneDialogClosed)
  next.member.pool.member_selected_milestone_id |> assert_equal(Some(33))
}

pub fn milestone_create_then_create_card_from_details_sets_context_test() {
  let created = sample_progress(44).milestone

  let model =
    client_state.default_model()
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_milestone_dialog: member_pool.MilestoneDialogCreate(
            name: "Release 44",
            description: "desc",
          ),
          member_milestone_dialog_in_flight: True,
        ),
      )
    })

  let #(after_create, _fx_create) =
    pool_update.update(
      model,
      pool_messages.MemberMilestoneCreated(Ok(created)),
      test_context(),
    )

  let #(after_card_click, _fx_card) =
    pool_update.update(
      after_create,
      pool_messages.MemberMilestoneCreateCardClicked(44),
      test_context(),
    )

  after_card_click.member.pool.member_milestone_dialog
  |> assert_equal(member_pool.MilestoneDialogClosed)
  after_card_click.admin.cards.cards_dialog_mode
  |> assert_equal(Some(state_types.CardDialogCreate))
  after_card_click.admin.cards.cards_create_milestone_id
  |> assert_equal(Some(44))
}

pub fn milestone_created_error_sets_dialog_error_test() {
  let model =
    client_state.default_model()
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_milestone_dialog: member_pool.MilestoneDialogCreate(
            name: "Release",
            description: "desc",
          ),
          member_milestone_dialog_in_flight: True,
        ),
      )
    })

  let #(next, _fx) =
    pool_update.update(
      model,
      pool_messages.MemberMilestoneCreated(
        Error(ApiError(status: 500, code: "INTERNAL", message: "boom")),
      ),
      test_context(),
    )

  next.member.pool.member_milestone_dialog_in_flight |> assert_equal(False)
  next.member.pool.member_milestone_dialog_error |> assert_equal(Some("boom"))
}

pub fn milestone_activated_ok_clears_in_flight_and_refreshes_test() {
  let model =
    client_state.default_model()
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_milestone_activate_in_flight_id: Some(7),
        ),
      )
    })

  let #(next, _fx) =
    pool_update.update(
      model,
      pool_messages.MemberMilestoneActivated(7, Ok(Nil)),
      test_context(),
    )

  next.member.pool.member_milestone_activate_in_flight_id
  |> assert_equal(None)
  next.member.pool.member_filters_q |> assert_equal("refreshed")
}

pub fn milestone_task_moved_ok_refreshes_member_data_test() {
  let model = client_state.default_model()

  let #(next, _fx) =
    pool_update.update(
      model,
      pool_messages.MemberMilestoneTaskMoved(Ok(sample_task(777))),
      test_context(),
    )

  next.member.pool.member_filters_q |> assert_equal("refreshed")
}

pub fn milestone_card_drag_started_sets_drag_item_test() {
  let model = client_state.default_model()

  let #(next, _fx) =
    pool_update.update(
      model,
      pool_messages.MemberMilestoneCardDragStarted(401, 12),
      test_context(),
    )

  next.member.pool.member_milestone_drag_item
  |> assert_equal(Some(member_pool.MilestoneDragCard(401, 12)))
}

pub fn milestone_drag_ended_clears_drag_item_test() {
  let model =
    client_state.default_model()
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_milestone_drag_item: Some(member_pool.MilestoneDragTask(
            501,
            22,
          )),
        ),
      )
    })

  let #(next, _fx) =
    pool_update.update(
      model,
      pool_messages.MemberMilestoneDragEnded,
      test_context(),
    )

  next.member.pool.member_milestone_drag_item |> assert_equal(None)
}

pub fn milestone_edit_clicked_opens_edit_dialog_test() {
  let model =
    client_state.default_model()
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_milestones: Loaded([sample_progress(3)]),
        ),
      )
    })

  let #(next, _fx) =
    pool_update.update(
      model,
      pool_messages.MemberMilestoneEditClicked(3),
      test_context(),
    )

  next.member.pool.member_milestone_dialog
  |> assert_equal(member_pool.MilestoneDialogEdit(3, "Milestone 3", "Desc"))
}

pub fn milestone_delete_clicked_opens_delete_dialog_test() {
  let model =
    client_state.default_model()
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_milestones: Loaded([sample_progress(5)]),
        ),
      )
    })

  let #(next, _fx) =
    pool_update.update(
      model,
      pool_messages.MemberMilestoneDeleteClicked(5),
      test_context(),
    )

  next.member.pool.member_milestone_dialog
  |> assert_equal(member_pool.MilestoneDialogDelete(5, "Milestone 5"))
}

pub fn milestone_activate_error_maps_backend_code_test() {
  let model = client_state.default_model()

  let #(next, _fx) =
    pool_update.update(
      model,
      pool_messages.MemberMilestoneActivated(
        7,
        Error(ApiError(
          status: 409,
          code: "MILESTONE_ALREADY_ACTIVE",
          message: "Another milestone is already active",
        )),
      ),
      test_context(),
    )

  let expected = i18n.t(next.ui.locale, i18n_text.MilestoneAlreadyActive)

  next.member.pool.member_milestone_dialog_error |> assert_equal(Some(expected))
}

pub fn milestone_card_move_clicked_ignores_non_ready_destination_test() {
  let model =
    client_state.default_model()
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_milestones: Loaded([
            sample_progress_state(1, Ready),
            sample_progress_state(2, Active),
          ]),
          member_cards: Loaded([sample_card(10, 1)]),
        ),
      )
    })

  let #(next, _fx) =
    pool_update.update(
      model,
      pool_messages.MemberMilestoneCardMoveClicked(10, 1, 2),
      test_context(),
    )

  next.member.pool.member_filters_q |> assert_equal("")
}

pub fn milestone_task_move_clicked_ignores_task_outside_source_milestone_test() {
  let model =
    client_state.default_model()
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_milestones: Loaded([
            sample_progress_state(1, Ready),
            sample_progress_state(2, Ready),
          ]),
          member_tasks: Loaded([sample_task_in(30, 2)]),
        ),
      )
    })

  let #(next, _fx) =
    pool_update.update(
      model,
      pool_messages.MemberMilestoneTaskMoveClicked(30, 1, 2),
      test_context(),
    )

  next.member.pool.member_filters_q |> assert_equal("")
}

pub fn milestone_delete_error_maps_backend_code_test() {
  let model = client_state.default_model()

  let #(next, _fx) =
    pool_update.update(
      model,
      pool_messages.MemberMilestoneDeleted(
        7,
        Error(ApiError(
          status: 409,
          code: "MILESTONE_DELETE_NOT_ALLOWED",
          message: "Milestone must be ready and empty",
        )),
      ),
      test_context(),
    )

  let expected = i18n.t(next.ui.locale, i18n_text.MilestoneDeleteNotAllowed)

  next.member.pool.member_milestone_dialog_error |> assert_equal(Some(expected))
}

pub fn milestone_member_pool_update_toggles_filter_locally_test() {
  let pool = client_state.default_model().member.pool

  let assert Some(milestones_update.Update(next, fx, policy, root_policy)) =
    milestones_update.try_member_pool_update(
      pool,
      pool_messages.MemberMilestonesShowCompletedToggled,
      local_context(Some(1)),
      feedback_context(),
    )

  next.member_milestones_show_completed |> assert_equal(True)
  let assert True = fx == effect.none()
  policy |> assert_equal(milestones_update.NoRefresh)
  root_policy |> assert_equal(milestones_update.NoRootPolicy)
}

pub fn milestone_member_pool_update_details_fetches_metrics_test() {
  let pool = client_state.default_model().member.pool

  let assert Some(milestones_update.Update(next, fx, policy, root_policy)) =
    milestones_update.try_member_pool_update(
      pool,
      pool_messages.MemberMilestoneDetailsClicked(77),
      local_context(Some(1)),
      feedback_context(),
    )

  next.member_selected_milestone_id |> assert_equal(Some(77))
  next.member_milestone_dialog
  |> assert_equal(member_pool.MilestoneDialogClosed)
  next.member_milestone_metrics |> assert_equal(Loading)
  let assert True = fx != effect.none()
  policy |> assert_equal(milestones_update.NoRefresh)
  root_policy |> assert_equal(milestones_update.NoRootPolicy)
}

pub fn milestone_member_pool_update_metrics_error_sets_failed_test() {
  let pool = client_state.default_model().member.pool
  let err = ApiError(status: 500, code: "SERVER_ERROR", message: "boom")

  let assert Some(milestones_update.Update(next, fx, policy, root_policy)) =
    milestones_update.try_member_pool_update(
      pool,
      pool_messages.MemberMilestoneMetricsFetched(Error(err)),
      local_context(Some(1)),
      feedback_context(),
    )

  next.member_milestone_metrics |> assert_equal(Failed(err))
  let assert True = fx == effect.none()
  policy |> assert_equal(milestones_update.NoRefresh)
  root_policy |> assert_equal(milestones_update.NoRootPolicy)
}

pub fn milestone_member_pool_update_created_ok_requests_refresh_test() {
  let pool = client_state.default_model().member.pool

  let assert Some(milestones_update.Update(next, fx, policy, root_policy)) =
    milestones_update.try_member_pool_update(
      pool,
      pool_messages.MemberMilestoneCreated(Ok(sample_milestone(33))),
      local_context(Some(1)),
      feedback_context(),
    )

  next.member_selected_milestone_id |> assert_equal(Some(33))
  next.member_milestone_metrics |> assert_equal(Loading)
  let assert True = fx != effect.none()
  policy
  |> assert_equal(milestones_update.RefreshWithSuccess(
    milestones_update.MilestoneCreated,
  ))
  root_policy |> assert_equal(milestones_update.NoRootPolicy)
}

pub fn milestone_member_pool_update_update_error_stays_local_test() {
  let pool = client_state.default_model().member.pool
  let err = ApiError(status: 500, code: "SERVER_ERROR", message: "boom")

  let assert Some(milestones_update.Update(next, fx, policy, root_policy)) =
    milestones_update.try_member_pool_update(
      pool,
      pool_messages.MemberMilestoneUpdated(Error(err)),
      local_context(Some(1)),
      feedback_context(),
    )

  next.member_milestone_dialog_error |> assert_equal(Some("boom"))
  let assert True = fx != effect.none()
  policy |> assert_equal(milestones_update.NoRefresh)
  root_policy |> assert_equal(milestones_update.NoRootPolicy)
}

pub fn milestone_member_pool_update_card_move_uses_local_pool_test() {
  let pool =
    member_pool.Model(
      ..client_state.default_model().member.pool,
      member_milestones: Loaded([sample_progress(10), sample_progress(20)]),
      member_cards: Loaded([sample_card(30, 10)]),
    )

  let assert Some(milestones_update.Update(next, fx, policy, root_policy)) =
    milestones_update.try_member_pool_update(
      pool,
      pool_messages.MemberMilestoneCardMoveClicked(30, 10, 20),
      local_context(Some(1)),
      feedback_context(),
    )

  next.member_cards |> assert_equal(pool.member_cards)
  let assert True = fx != effect.none()
  policy |> assert_equal(milestones_update.NoRefresh)
  root_policy |> assert_equal(milestones_update.NoRootPolicy)
}

pub fn milestone_member_pool_update_drop_task_clears_drag_item_test() {
  let pool =
    member_pool.Model(
      ..client_state.default_model().member.pool,
      member_milestones: Loaded([sample_progress(10), sample_progress(20)]),
      member_tasks: Loaded([sample_task_in(40, 10)]),
      member_milestone_drag_item: Some(member_pool.MilestoneDragTask(40, 10)),
    )

  let assert Some(milestones_update.Update(next, fx, policy, root_policy)) =
    milestones_update.try_member_pool_update(
      pool,
      pool_messages.MemberMilestoneDroppedOn(20),
      local_context(Some(1)),
      feedback_context(),
    )

  next.member_milestone_drag_item |> assert_equal(None)
  let assert True = fx != effect.none()
  policy |> assert_equal(milestones_update.NoRefresh)
  root_policy |> assert_equal(milestones_update.NoRootPolicy)
}

pub fn milestone_member_pool_update_create_card_requests_root_policy_test() {
  let pool =
    member_pool.Model(
      ..client_state.default_model().member.pool,
      member_milestone_dialog: member_pool.MilestoneDialogEdit(
        id: 89,
        name: "M",
        description: "",
      ),
      member_milestone_dialog_in_flight: True,
      member_milestone_dialog_error: Some("stale"),
    )

  let assert Some(milestones_update.Update(next, fx, policy, root_policy)) =
    milestones_update.try_member_pool_update(
      pool,
      pool_messages.MemberMilestoneCreateCardClicked(89),
      local_context(Some(1)),
      feedback_context(),
    )

  next.member_milestone_dialog
  |> assert_equal(member_pool.MilestoneDialogClosed)
  next.member_milestone_dialog_in_flight |> assert_equal(False)
  next.member_milestone_dialog_error |> assert_equal(None)
  let assert True = fx == effect.none()
  policy |> assert_equal(milestones_update.NoRefresh)
  root_policy
  |> assert_equal(milestones_update.OpenCardForMilestone(89))
}

pub fn milestone_member_pool_update_ignores_unrelated_message_test() {
  let pool = client_state.default_model().member.pool

  milestones_update.try_member_pool_update(
    pool,
    pool_messages.GlobalKeyDown(pool_prefs.KeyEvent(
      key: "Escape",
      ctrl: False,
      meta: False,
      shift: False,
      is_editing: False,
      modal_open: False,
    )),
    local_context(Some(1)),
    feedback_context(),
  )
  |> assert_equal(None)
}

pub fn milestone_filters_toggle_flags_test() {
  let model = client_state.default_model()

  let #(next_a, _fx_a) =
    pool_update.update(
      model,
      pool_messages.MemberMilestonesShowCompletedToggled,
      test_context(),
    )

  next_a.member.pool.member_milestones_show_completed |> assert_equal(True)

  let #(next_b, _fx_b) =
    pool_update.update(
      next_a,
      pool_messages.MemberMilestonesShowEmptyToggled,
      test_context(),
    )

  next_b.member.pool.member_milestones_show_empty |> assert_equal(True)
}

pub fn milestone_details_click_selects_milestone_test() {
  let model = client_state.default_model()

  let #(next, _fx) =
    pool_update.update(
      model,
      pool_messages.MemberMilestoneDetailsClicked(77),
      test_context(),
    )

  next.member.pool.member_milestone_dialog
  |> assert_equal(member_pool.MilestoneDialogClosed)
  next.member.pool.member_selected_milestone_id |> assert_equal(Some(77))
}

pub fn milestone_create_task_click_opens_task_dialog_with_milestone_test() {
  let model =
    client_state.default_model()
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(..pool, member_selected_milestone_id: Some(88)),
      )
    })

  let #(next, _fx) =
    pool_update.update(
      model,
      pool_messages.MemberMilestoneCreateTaskClicked(88),
      test_context(),
    )

  next.member.pool.member_milestone_dialog
  |> assert_equal(member_pool.MilestoneDialogClosed)
  next.member.pool.member_create_dialog_mode
  |> assert_equal(dialog_mode.DialogCreate)
  next.member.pool.member_create_milestone_id |> assert_equal(Some(88))
  next.member.pool.member_create_card_id |> assert_equal(None)
}

pub fn milestone_create_card_click_opens_card_dialog_with_milestone_test() {
  let model =
    client_state.default_model()
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(..pool, member_selected_milestone_id: Some(89)),
      )
    })

  let #(next, _fx) =
    pool_update.update(
      model,
      pool_messages.MemberMilestoneCreateCardClicked(89),
      test_context(),
    )

  next.member.pool.member_milestone_dialog
  |> assert_equal(member_pool.MilestoneDialogClosed)
  next.admin.cards.cards_dialog_mode
  |> assert_equal(Some(state_types.CardDialogCreate))
  next.admin.cards.cards_create_milestone_id |> assert_equal(Some(89))
}

pub fn milestone_create_card_close_dialog_preserves_milestones_context_test() {
  let model =
    client_state.default_model()
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_section: member_section.Pool,
          member_selected_milestone_id: Some(89),
        ),
      )
    })

  let #(after_open, _fx_open) =
    pool_update.update(
      model,
      pool_messages.MemberMilestoneCreateCardClicked(89),
      test_context(),
    )

  let #(after_close, fx_close) =
    pool_update.update(
      after_open,
      pool_messages.CloseCardDialog,
      test_context(),
    )

  after_close.admin.cards.cards_dialog_mode |> assert_equal(None)
  after_close.admin.cards.cards_create_milestone_id |> assert_equal(None)
  after_close.member.pool.member_section |> assert_equal(member_section.Pool)
  after_close.member.pool.member_milestone_dialog
  |> assert_equal(member_pool.MilestoneDialogClosed)
  fx_close |> assert_not_equal(effect.none())
}

pub fn close_card_dialog_without_milestone_context_has_no_focus_effect_test() {
  let model = client_state.default_model()

  let #(opened, _fx_open) =
    pool_update.update(
      model,
      pool_messages.OpenCardDialog(state_types.CardDialogCreate),
      test_context(),
    )

  let #(closed, fx_close) =
    pool_update.update(opened, pool_messages.CloseCardDialog, test_context())

  closed.admin.cards.cards_dialog_mode |> assert_equal(None)
  closed.admin.cards.cards_create_milestone_id |> assert_equal(None)
  fx_close |> assert_equal(effect.none())
}

pub fn close_card_dialog_focus_target_resolves_to_quick_create_button_test() {
  let model =
    client_state.default_model()
    |> client_state.update_admin(fn(admin) {
      let cards = admin.cards
      admin_state.AdminModel(
        ..admin,
        cards: admin_cards.Model(..cards, cards_create_milestone_id: Some(89)),
      )
    })

  pool_update.close_card_dialog_focus_target_for_test(model)
  |> assert_equal(Some(milestone_ids.quick_create_card_button_id(89)))
}

pub fn global_create_task_from_milestones_opens_pool_create_without_milestone_test() {
  let model =
    client_state.default_model()
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_section: member_section.Pool,
          member_create_milestone_id: Some(77),
        ),
      )
    })

  let #(next, _fx) =
    pool_update.update(
      model,
      pool_messages.MemberCreateDialogOpened,
      test_context(),
    )

  next.member.pool.member_create_dialog_mode
  |> assert_equal(dialog_mode.DialogCreate)
  next.member.pool.member_create_milestone_id |> assert_equal(None)
  next.member.pool.member_create_card_id |> assert_equal(None)
}

pub fn global_create_card_from_milestones_opens_pool_create_without_milestone_test() {
  let model = client_state.default_model()

  let #(after_milestone_create, _fx_a) =
    pool_update.update(
      model,
      pool_messages.MemberMilestoneCreateCardClicked(91),
      test_context(),
    )

  after_milestone_create.admin.cards.cards_create_milestone_id
  |> assert_equal(Some(91))

  let #(next, _fx) =
    pool_update.update(
      after_milestone_create,
      pool_messages.OpenCardDialog(state_types.CardDialogCreate),
      test_context(),
    )

  next.admin.cards.cards_dialog_mode
  |> assert_equal(Some(state_types.CardDialogCreate))
  next.admin.cards.cards_create_milestone_id |> assert_equal(None)
}

fn model_with_milestone_dialog(
  dialog: member_pool.MilestoneDialog,
) -> client_state.Model {
  client_state.default_model()
  |> client_state.update_core(fn(core) {
    client_state.CoreModel(..core, page: client_state.Member)
  })
  |> client_state.update_member(fn(member) {
    let pool = member.pool
    member_state.MemberModel(
      ..member,
      pool: member_pool.Model(
        ..pool,
        member_section: member_section.Pool,
        member_milestone_dialog: dialog,
        member_milestone_dialog_in_flight: True,
        member_milestone_dialog_error: Some("boom"),
      ),
    )
  })
}

fn press_escape_on_pool(model: client_state.Model) -> client_state.Model {
  let #(next, _fx) =
    pool_update.update(
      model,
      pool_messages.GlobalKeyDown(pool_prefs.KeyEvent(
        key: "Escape",
        ctrl: False,
        meta: False,
        shift: False,
        is_editing: False,
        modal_open: False,
      )),
      test_context(),
    )

  next
}

fn assert_milestone_dialog_closed(model: client_state.Model) {
  model.member.pool.member_milestone_dialog
  |> assert_equal(member_pool.MilestoneDialogClosed)
  model.member.pool.member_milestone_dialog_in_flight |> assert_equal(False)
  model.member.pool.member_milestone_dialog_error |> assert_equal(None)
}

pub fn milestone_escape_shortcut_closes_activate_dialog_test() {
  let next =
    model_with_milestone_dialog(member_pool.MilestoneDialogActivate(42))
    |> press_escape_on_pool

  assert_milestone_dialog_closed(next)
}

pub fn milestone_escape_shortcut_closes_edit_dialog_test() {
  let next =
    model_with_milestone_dialog(member_pool.MilestoneDialogEdit(
      id: 42,
      name: "Milestone",
      description: "Desc",
    ))
    |> press_escape_on_pool

  assert_milestone_dialog_closed(next)
}

pub fn milestone_escape_shortcut_closes_delete_dialog_test() {
  let next =
    model_with_milestone_dialog(member_pool.MilestoneDialogDelete(
      42,
      "Milestone",
    ))
    |> press_escape_on_pool

  assert_milestone_dialog_closed(next)
}

pub fn milestone_escape_shortcut_keeps_create_dialog_open_test() {
  let model =
    client_state.default_model()
    |> client_state.update_core(fn(core) {
      client_state.CoreModel(..core, page: client_state.Member)
    })
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_section: member_section.Pool,
          member_milestone_dialog: member_pool.MilestoneDialogCreate(
            "New milestone",
            "Desc",
          ),
          member_milestone_dialog_in_flight: True,
          member_milestone_dialog_error: Some("boom"),
        ),
      )
    })

  let next = press_escape_on_pool(model)

  next.member.pool.member_milestone_dialog
  |> assert_equal(member_pool.MilestoneDialogCreate("New milestone", "Desc"))
  next.member.pool.member_milestone_dialog_in_flight |> assert_equal(True)
  next.member.pool.member_milestone_dialog_error |> assert_equal(Some("boom"))
}
