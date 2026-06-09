//// Pool feature update handlers for Scrumbringer client.
////
//// ## Mission
////
//// Handle pool-specific state transitions: filters, drag-and-drop,
//// keyboard shortcuts, and task positions.
////
//// ## Responsibilities
////
//// - Pool filter state changes (status, type, capability, search)
//// - Pool view mode and filter visibility toggling
//// - Keyboard shortcut handling for pool page
//// - Drag-and-drop start, move, and end events
//// - Task position editing (manual coordinate entry)
////
//// ## Non-responsibilities
////
//// - Task mutations (claim/release/complete - see features/tasks/update.gleam)
//// - Task creation (see features/tasks/update.gleam)
//// - View rendering (see features/pool/view.gleam)
////
//// ## Relations
////
//// - **client_state.gleam**: Provides client_state.Model, client_state.Msg types
//// - **client_update.gleam**: Delegates pool messages here
//// - **api/tasks/positions.gleam**: Provides position API functions

import gleam/option as opt
import lustre/effect

import domain/api_error.{type ApiError}
import domain/task
import domain/task_state
import scrumbringer_client/api/tasks/active as active_api
import scrumbringer_client/app/effects as app_effects
import scrumbringer_client/client_state
import scrumbringer_client/client_state/admin as admin_state
import scrumbringer_client/client_state/admin/cards as admin_cards
import scrumbringer_client/client_state/admin/metrics as admin_metrics
import scrumbringer_client/client_state/admin/rules as admin_rules
import scrumbringer_client/client_state/admin/task_templates as admin_task_templates
import scrumbringer_client/client_state/admin/workflows as admin_workflows
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/metrics as member_metrics
import scrumbringer_client/client_state/member/notes as member_notes
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/client_state/member/positions as member_positions
import scrumbringer_client/client_state/member/skills as member_skills
import scrumbringer_client/features/admin/cards as cards_workflow
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/features/admin/rule_metrics as rule_metrics_workflow
import scrumbringer_client/features/admin/task_templates as task_templates_workflow
import scrumbringer_client/features/admin/workflows as workflows_workflow
import scrumbringer_client/features/auth/helpers as auth_helpers
import scrumbringer_client/features/metrics/update as metrics_workflow
import scrumbringer_client/features/milestones/ids as milestone_ids
import scrumbringer_client/features/milestones/update as milestones_workflow
import scrumbringer_client/features/now_working/update as now_working_workflow
import scrumbringer_client/features/people/update as people_workflow
import scrumbringer_client/features/pool/available_tasks
import scrumbringer_client/features/pool/card_detail_update
import scrumbringer_client/features/pool/card_refresh
import scrumbringer_client/features/pool/drag_update
import scrumbringer_client/features/pool/filters as pool_filters
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/pool/position_update
import scrumbringer_client/features/pool/preferences as pool_preferences
import scrumbringer_client/features/pool/project_refresh
import scrumbringer_client/features/pool/shortcut_update
import scrumbringer_client/features/pool/task_created_feedback
import scrumbringer_client/features/pool/task_created_update
import scrumbringer_client/features/pool/view_mode_update
import scrumbringer_client/features/skills/update as skills_workflow
import scrumbringer_client/features/tasks/dependency_update as dependency_workflow
import scrumbringer_client/features/tasks/detail_update as task_detail_update
import scrumbringer_client/features/tasks/mutation_update as task_mutation_update
import scrumbringer_client/features/tasks/update as tasks_workflow
import scrumbringer_client/helpers/lookup as helpers_lookup
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/member_section
import scrumbringer_client/pool_prefs
import scrumbringer_client/router
import scrumbringer_client/theme

fn save_pool_filters_visible_effect(
  visible: Bool,
) -> effect.Effect(client_state.Msg) {
  effect.from(fn(_dispatch) {
    theme.local_storage_set(
      pool_prefs.filters_visible_storage_key,
      pool_prefs.encode_filters_visibility(pool_prefs.visibility_from_bool(
        visible,
      )),
    )
  })
}

fn save_pool_view_mode_effect(
  mode: pool_prefs.ViewMode,
) -> effect.Effect(client_state.Msg) {
  effect.from(fn(_dispatch) {
    theme.local_storage_set(
      pool_prefs.view_mode_storage_key,
      pool_prefs.encode_view_mode_storage(mode),
    )
  })
}

fn task_created_feedback_config(
  model: client_state.Model,
) -> task_created_feedback.Config {
  task_created_feedback.Config(
    locale: model.ui.locale,
    status_filter: model.member.pool.member_filters_status,
    work_filters: available_tasks.Config(
      tasks: model.member.pool.member_tasks,
      task_types: model.member.pool.member_task_types,
      my_capability_ids: model.member.skills.member_my_capability_ids,
      type_filter: model.member.pool.member_filters_type_id,
      capability_filter: model.member.pool.member_filters_capability_id,
      search_query: model.member.pool.member_filters_q,
      capability_scope: model.member.pool.member_capability_scope,
    ),
  )
}

fn task_created_update_context() -> task_created_update.Context(
  client_state.Msg,
) {
  task_created_update.Context(
    on_task_created_feedback: fn(task_id) {
      client_state.pool_msg(pool_messages.MemberTaskCreatedFeedback(task_id))
    },
    on_highlight_expired: fn(task_id) {
      client_state.pool_msg(pool_messages.MemberHighlightExpired(task_id))
    },
    on_toast: app_effects.toast_effect_with_action,
  )
}

fn task_created_effect(
  model: client_state.Model,
  task: task.Task,
) -> effect.Effect(client_state.Msg) {
  task_created_update.effects(
    task_created_feedback_config(model),
    task,
    task_created_update_context(),
  )
}

fn update_member_pool(
  model: client_state.Model,
  f: fn(member_pool.Model) -> member_pool.Model,
) -> client_state.Model {
  client_state.update_member(model, fn(member) {
    let pool = member.pool
    member_state.MemberModel(..member, pool: f(pool))
  })
}

fn update_member_positions(
  model: client_state.Model,
  f: fn(member_positions.Model) -> member_positions.Model,
) -> client_state.Model {
  client_state.update_member(model, fn(member) {
    let positions = member.positions
    member_state.MemberModel(..member, positions: f(positions))
  })
}

fn update_member_notes(
  model: client_state.Model,
  f: fn(member_notes.Model) -> member_notes.Model,
) -> client_state.Model {
  client_state.update_member(model, fn(member) {
    let notes = member.notes
    member_state.MemberModel(..member, notes: f(notes))
  })
}

fn pool_shortcut_model(model: client_state.Model) -> shortcut_update.Model {
  shortcut_update.Model(
    pool: model.member.pool,
    notes: model.member.notes,
    positions: model.member.positions,
  )
}

fn update_pool_shortcut_model(
  model: client_state.Model,
  local: shortcut_update.Model,
) -> client_state.Model {
  client_state.update_member(model, fn(member) {
    member_state.MemberModel(
      ..member,
      pool: local.pool,
      notes: local.notes,
      positions: local.positions,
    )
  })
}

fn pool_drag_model(model: client_state.Model) -> drag_update.Model {
  drag_update.Model(
    pool: model.member.pool,
    positions: model.member.positions,
    notes: model.member.notes,
  )
}

fn update_pool_drag_model(
  model: client_state.Model,
  local: drag_update.Model,
) -> client_state.Model {
  client_state.update_member(model, fn(member) {
    member_state.MemberModel(
      ..member,
      pool: local.pool,
      positions: local.positions,
      notes: local.notes,
    )
  })
}

fn pool_card_detail_model(model: client_state.Model) -> card_detail_update.Model {
  card_detail_update.Model(pool: model.member.pool, cards: model.admin.cards)
}

fn update_pool_card_detail_model(
  model: client_state.Model,
  local: card_detail_update.Model,
) -> client_state.Model {
  let model =
    client_state.update_member(model, fn(member) {
      member_state.MemberModel(..member, pool: local.pool)
    })

  client_state.update_admin(model, fn(admin) {
    admin_state.AdminModel(..admin, cards: local.cards)
  })
}

fn task_dependencies_model(
  model: client_state.Model,
) -> dependency_workflow.DependenciesModel {
  dependency_workflow.DependenciesModel(
    pool: model.member.pool,
    dependencies: model.member.dependencies,
  )
}

fn update_task_dependencies_model(
  model: client_state.Model,
  local: dependency_workflow.DependenciesModel,
) -> client_state.Model {
  client_state.update_member(model, fn(member) {
    member_state.MemberModel(
      ..member,
      pool: local.pool,
      dependencies: local.dependencies,
    )
  })
}

fn task_detail_model(
  model: client_state.Model,
) -> tasks_workflow.TaskDetailModel {
  tasks_workflow.TaskDetailModel(
    pool: model.member.pool,
    notes: model.member.notes,
    dependencies: model.member.dependencies,
  )
}

fn update_task_detail_model(
  model: client_state.Model,
  local: tasks_workflow.TaskDetailModel,
) -> client_state.Model {
  client_state.update_member(model, fn(member) {
    member_state.MemberModel(
      ..member,
      pool: local.pool,
      notes: local.notes,
      dependencies: local.dependencies,
    )
  })
}

fn update_member_skills(
  model: client_state.Model,
  f: fn(member_skills.Model) -> member_skills.Model,
) -> client_state.Model {
  client_state.update_member(model, fn(member) {
    let skills = member.skills
    member_state.MemberModel(..member, skills: f(skills))
  })
}

fn now_working_model(model: client_state.Model) -> now_working_workflow.Model {
  now_working_workflow.Model(
    now_working: model.member.now_working,
    metrics: model.member.metrics,
  )
}

fn update_now_working_model(
  model: client_state.Model,
  local: now_working_workflow.Model,
) -> client_state.Model {
  client_state.update_member(model, fn(member) {
    member_state.MemberModel(
      ..member,
      now_working: local.now_working,
      metrics: local.metrics,
    )
  })
}

fn now_working_context() -> now_working_workflow.Context(client_state.Msg) {
  now_working_workflow.Context(
    on_session_started: fn(result) {
      client_state.pool_msg(pool_messages.MemberWorkSessionStarted(result))
    },
    on_session_paused: fn(result) {
      client_state.pool_msg(pool_messages.MemberWorkSessionPaused(result))
    },
    on_session_heartbeated: fn(result) {
      client_state.pool_msg(pool_messages.MemberWorkSessionHeartbeated(result))
    },
    on_tick: fn() { client_state.pool_msg(pool_messages.NowWorkingTicked) },
    on_error_toast: app_effects.toast_error,
  )
}

fn rule_metrics_context() -> rule_metrics_workflow.Context(client_state.Msg) {
  rule_metrics_workflow.Context(
    on_rule_metrics_fetched: fn(result) {
      client_state.pool_msg(pool_messages.AdminRuleMetricsFetched(result))
    },
    on_workflow_details_fetched: fn(result) {
      client_state.pool_msg(
        pool_messages.AdminRuleMetricsWorkflowDetailsFetched(result),
      )
    },
    on_rule_details_fetched: fn(result) {
      client_state.pool_msg(pool_messages.AdminRuleMetricsRuleDetailsFetched(
        result,
      ))
    },
    on_executions_fetched: fn(result) {
      client_state.pool_msg(pool_messages.AdminRuleMetricsExecutionsFetched(
        result,
      ))
    },
  )
}

fn rules_context(
  model: client_state.Model,
) -> workflows_workflow.RulesContext(client_state.Msg) {
  workflows_workflow.RulesContext(
    selected_project_id: model.core.selected_project_id,
    on_rules_fetched: fn(result) {
      client_state.pool_msg(pool_messages.RulesFetched(result))
    },
    on_rule_metrics_fetched: fn(result) {
      client_state.pool_msg(pool_messages.RuleMetricsFetched(result))
    },
    on_task_types_fetched: fn(result) {
      client_state.admin_msg(admin_messages.TaskTypesFetched(result))
    },
  )
}

fn milestone_context(
  model: client_state.Model,
) -> milestones_workflow.Context(client_state.Msg) {
  milestones_workflow.Context(
    selected_project_id: model.core.selected_project_id,
    on_milestone_activated: fn(milestone_id, result) {
      client_state.pool_msg(pool_messages.MemberMilestoneActivated(
        milestone_id,
        result,
      ))
    },
    on_milestone_created: fn(result) {
      client_state.pool_msg(pool_messages.MemberMilestoneCreated(result))
    },
    on_milestone_updated: fn(result) {
      client_state.pool_msg(pool_messages.MemberMilestoneUpdated(result))
    },
    on_milestone_deleted: fn(milestone_id, result) {
      client_state.pool_msg(pool_messages.MemberMilestoneDeleted(
        milestone_id,
        result,
      ))
    },
    on_milestone_metrics_fetched: fn(result) {
      client_state.pool_msg(pool_messages.MemberMilestoneMetricsFetched(result))
    },
    on_milestone_card_moved: fn(result) {
      client_state.pool_msg(pool_messages.MemberMilestoneCardMoved(result))
    },
    on_milestone_task_moved: fn(result) {
      client_state.pool_msg(pool_messages.MemberMilestoneTaskMoved(result))
    },
    name_required: i18n.t(model.ui.locale, i18n_text.NameRequired),
    select_project_first: i18n.t(model.ui.locale, i18n_text.SelectProjectFirst),
  )
}

fn milestone_feedback_context(
  model: client_state.Model,
) -> milestones_workflow.FeedbackContext(client_state.Msg) {
  milestones_workflow.FeedbackContext(
    milestone_activated: i18n.t(model.ui.locale, i18n_text.MilestoneActivated),
    milestone_created: i18n.t(model.ui.locale, i18n_text.MilestoneCreated),
    milestone_updated: i18n.t(model.ui.locale, i18n_text.MilestoneUpdated),
    milestone_deleted: i18n.t(model.ui.locale, i18n_text.MilestoneDeleted),
    milestone_activate_failed: i18n.t(
      model.ui.locale,
      i18n_text.MilestoneActivateFailed,
    ),
    milestone_create_failed: i18n.t(
      model.ui.locale,
      i18n_text.MilestoneCreateFailed,
    ),
    milestone_update_failed: i18n.t(
      model.ui.locale,
      i18n_text.MilestoneUpdateFailed,
    ),
    milestone_delete_failed: i18n.t(
      model.ui.locale,
      i18n_text.MilestoneDeleteFailed,
    ),
    milestone_already_active: i18n.t(
      model.ui.locale,
      i18n_text.MilestoneAlreadyActive,
    ),
    milestone_activation_irreversible: i18n.t(
      model.ui.locale,
      i18n_text.MilestoneActivationIrreversible,
    ),
    milestone_delete_not_allowed: i18n.t(
      model.ui.locale,
      i18n_text.MilestoneDeleteNotAllowed,
    ),
    on_success_toast: app_effects.toast_success,
    on_error_toast: app_effects.toast_error,
  )
}

fn task_create_context(
  model: client_state.Model,
) -> tasks_workflow.CreateContext(client_state.Msg) {
  tasks_workflow.CreateContext(
    selected_project_id: model.core.selected_project_id,
    on_task_types_fetched: fn(project_id, result) {
      client_state.pool_msg(pool_messages.MemberTaskTypesFetched(
        project_id,
        result,
      ))
    },
    on_task_created: fn(result) {
      client_state.pool_msg(pool_messages.MemberTaskCreated(result))
    },
    select_project_first: i18n.t(model.ui.locale, i18n_text.SelectProjectFirst),
    title_required: i18n.t(model.ui.locale, i18n_text.TitleRequired),
    title_too_long_max_56: i18n.t(model.ui.locale, i18n_text.TitleTooLongMax56),
    type_required: i18n.t(model.ui.locale, i18n_text.TypeRequired),
    priority_must_be_1_to_5: i18n.t(
      model.ui.locale,
      i18n_text.PriorityMustBe1To5,
    ),
  )
}

fn selected_task_detail(model: client_state.Model) -> opt.Option(task.Task) {
  case model.member.notes.member_notes_task_id {
    opt.Some(task_id) ->
      helpers_lookup.find_task_by_id(model.member.pool.member_tasks, task_id)
    opt.None -> opt.None
  }
}

fn can_edit_selected_task(
  model: client_state.Model,
  current_task: task.Task,
) -> Bool {
  case model.core.user, task_state.claimed_by(current_task.state) {
    opt.Some(user), opt.Some(claimed_by) -> user.id == claimed_by
    opt.Some(_), opt.None -> True
    _, _ -> False
  }
}

fn task_detail_edit_context(
  model: client_state.Model,
) -> tasks_workflow.TaskDetailEditContext(client_state.Msg) {
  let maybe_task = selected_task_detail(model)
  let can_edit = case maybe_task {
    opt.Some(current_task) -> can_edit_selected_task(model, current_task)
    opt.None -> False
  }

  tasks_workflow.TaskDetailEditContext(
    current_task: maybe_task,
    can_edit: can_edit,
    on_task_updated: fn(result) {
      client_state.pool_msg(pool_messages.MemberTaskUpdated(result))
    },
    title_required: i18n.t(model.ui.locale, i18n_text.TitleRequired),
    title_too_long_max_56: i18n.t(model.ui.locale, i18n_text.TitleTooLongMax56),
  )
}

fn task_detail_update_success_context(
  model: client_state.Model,
) -> task_detail_update.SuccessContext(client_state.Msg) {
  task_detail_update.SuccessContext(
    task_updated: i18n.t(model.ui.locale, i18n_text.TaskUpdated),
    on_success_toast: app_effects.toast_success,
  )
}

fn task_detail_update_error_context() -> task_detail_update.ErrorContext(
  client_state.Msg,
) {
  task_detail_update.ErrorContext(
    on_warning_toast: app_effects.toast_warning,
    on_error_toast: app_effects.toast_error,
  )
}

fn task_detail_dispatch_context(
  model: client_state.Model,
) -> tasks_workflow.TaskDetailDispatchContext(client_state.Msg) {
  tasks_workflow.TaskDetailDispatchContext(
    open_context: task_detail_context(),
    edit_context: task_detail_edit_context(model),
    success_context: task_detail_update_success_context(model),
    error_context: task_detail_update_error_context(),
  )
}

fn note_context(
  model: client_state.Model,
) -> tasks_workflow.NoteContext(client_state.Msg) {
  tasks_workflow.NoteContext(
    content_required: i18n.t(model.ui.locale, i18n_text.ContentRequired),
    note_added: i18n.t(model.ui.locale, i18n_text.NoteAdded),
    on_note_added: fn(result) {
      client_state.pool_msg(pool_messages.MemberNoteAdded(result))
    },
    on_notes_fetched: fn(result) {
      client_state.pool_msg(pool_messages.MemberNotesFetched(result))
    },
    on_success_toast: app_effects.toast_success,
  )
}

fn dependency_context(
  model: client_state.Model,
) -> dependency_workflow.DependencyContext(client_state.Msg) {
  dependency_workflow.DependencyContext(
    selected_task_id: model.member.notes.member_notes_task_id,
    selected_task: selected_task_detail(model),
    on_dependency_candidates_fetched: fn(result) {
      client_state.pool_msg(pool_messages.MemberDependencyCandidatesFetched(
        result,
      ))
    },
    on_dependency_added: fn(result) {
      client_state.pool_msg(pool_messages.MemberDependencyAdded(result))
    },
    on_dependency_removed: fn(depends_on_task_id, result) {
      client_state.pool_msg(pool_messages.MemberDependencyRemoved(
        depends_on_task_id,
        result,
      ))
    },
  )
}

fn dependency_feedback_context() -> dependency_workflow.DependencyFeedbackContext(
  client_state.Msg,
) {
  dependency_workflow.DependencyFeedbackContext(
    on_error_toast: app_effects.toast_error,
  )
}

fn pool_drag_context(
  model: client_state.Model,
) -> drag_update.Context(client_state.Msg) {
  drag_update.Context(
    task_mutation: task_mutation_context(model),
    on_canvas_rect_fetched: fn(left, top) {
      client_state.pool_msg(pool_messages.MemberCanvasRectFetched(left, top))
    },
    on_drag_offset_resolved: fn(task_id, offset_x, offset_y) {
      client_state.pool_msg(pool_messages.MemberDragOffsetResolved(
        task_id,
        offset_x,
        offset_y,
      ))
    },
    on_my_tasks_rect_fetched: fn(left, top, width, height) {
      client_state.pool_msg(pool_messages.MemberPoolMyTasksRectFetched(
        left,
        top,
        width,
        height,
      ))
    },
    on_hover_notes_fetched: fn(task_id, result) {
      client_state.pool_msg(pool_messages.MemberTaskHoverNotesFetched(
        task_id,
        result,
      ))
    },
    on_long_press_check: fn(task_id) {
      client_state.pool_msg(pool_messages.MemberPoolLongPressCheck(task_id))
    },
    on_position_saved: fn(result) {
      client_state.pool_msg(pool_messages.MemberPositionSaved(result))
    },
  )
}

fn position_update_context(
  model: client_state.Model,
) -> position_update.Context(client_state.Msg) {
  position_update.Context(
    selected_project_id: model.core.selected_project_id,
    invalid_xy: i18n.t(model.ui.locale, i18n_text.InvalidXY),
    on_position_saved: fn(result) {
      client_state.pool_msg(pool_messages.MemberPositionSaved(result))
    },
    on_positions_fetched: fn(result) {
      client_state.pool_msg(pool_messages.MemberPositionsFetched(result))
    },
    on_error_toast: app_effects.toast_error,
  )
}

fn card_detail_context() -> card_detail_update.Context(client_state.Msg) {
  card_detail_update.Context(
    on_card_marked: fn(_result) { client_state.NoOp },
    on_card_metrics_fetched: fn(result) {
      client_state.pool_msg(pool_messages.CardMetricsFetched(result))
    },
  )
}

fn skills_context(
  model: client_state.Model,
) -> skills_workflow.Context(client_state.Msg) {
  skills_workflow.Context(
    selected_project_id: model.core.selected_project_id,
    user_id: selected_user_id(model),
    on_my_capability_ids_fetched: fn(result) {
      client_state.pool_msg(pool_messages.MemberMyCapabilityIdsFetched(result))
    },
    on_my_capability_ids_saved: fn(result) {
      client_state.pool_msg(pool_messages.MemberMyCapabilityIdsSaved(result))
    },
    skills_saved: i18n.t(model.ui.locale, i18n_text.SkillsSaved),
    on_success_toast: app_effects.toast_success,
    on_error_toast: app_effects.toast_error,
  )
}

fn task_detail_context() -> tasks_workflow.TaskDetailContext(client_state.Msg) {
  tasks_workflow.TaskDetailContext(
    on_notes_fetched: fn(result) {
      client_state.pool_msg(pool_messages.MemberNotesFetched(result))
    },
    on_dependencies_fetched: fn(result) {
      client_state.pool_msg(pool_messages.MemberDependenciesFetched(result))
    },
    on_metrics_fetched: fn(result) {
      client_state.pool_msg(pool_messages.MemberTaskMetricsFetched(result))
    },
  )
}

fn task_mutation_context(
  model: client_state.Model,
) -> tasks_workflow.TaskMutationContext(client_state.Msg) {
  tasks_workflow.TaskMutationContext(
    current_user_id: selected_user_id(model),
    on_task_claimed: fn(result) {
      client_state.pool_msg(pool_messages.MemberTaskClaimed(result))
    },
    on_task_released: fn(result) {
      client_state.pool_msg(pool_messages.MemberTaskReleased(result))
    },
    on_task_completed: fn(result) {
      client_state.pool_msg(pool_messages.MemberTaskCompleted(result))
    },
  )
}

fn task_mutation_success_context(
  model: client_state.Model,
) -> task_mutation_update.Context(client_state.Msg) {
  task_mutation_update.Context(
    task_claimed: i18n.t(model.ui.locale, i18n_text.TaskClaimed),
    task_released: i18n.t(model.ui.locale, i18n_text.TaskReleased),
    task_completed: i18n.t(model.ui.locale, i18n_text.TaskCompleted),
    on_success_toast: app_effects.toast_success,
    on_work_sessions_refetch: refetch_work_sessions_effect,
  )
}

fn task_mutation_error_context(
  model: client_state.Model,
) -> task_mutation_update.ErrorContext(client_state.Msg) {
  task_mutation_update.ErrorContext(
    labels: task_mutation_update.ErrorLabels(
      task_not_found: i18n.t(model.ui.locale, i18n_text.TaskNotFound),
      task_already_claimed: i18n.t(
        model.ui.locale,
        i18n_text.TaskAlreadyClaimed,
      ),
      task_version_conflict: i18n.t(
        model.ui.locale,
        i18n_text.TaskVersionConflict,
      ),
      task_mutation_rolled_back: i18n.t(
        model.ui.locale,
        i18n_text.TaskMutationRolledBack,
      ),
    ),
    on_warning_toast: app_effects.toast_warning,
    on_error_toast: app_effects.toast_error,
  )
}

fn task_mutation_dispatch_context(
  model: client_state.Model,
) -> tasks_workflow.TaskMutationDispatchContext(client_state.Msg) {
  tasks_workflow.TaskMutationDispatchContext(
    mutation_context: task_mutation_context(model),
    success_context: task_mutation_success_context(model),
    error_context: task_mutation_error_context(model),
  )
}

fn card_crud_feedback_context(
  model: client_state.Model,
) -> cards_workflow.CrudFeedbackContext(client_state.Msg) {
  cards_workflow.CrudFeedbackContext(
    card_created: i18n.t(model.ui.locale, i18n_text.CardCreated),
    card_updated: i18n.t(model.ui.locale, i18n_text.CardUpdated),
    card_deleted: i18n.t(model.ui.locale, i18n_text.CardDeleted),
    on_success_toast: app_effects.toast_success,
  )
}

fn workflow_crud_feedback_context(
  model: client_state.Model,
) -> workflows_workflow.WorkflowFeedbackContext(client_state.Msg) {
  workflows_workflow.WorkflowFeedbackContext(
    workflow_created: i18n.t(model.ui.locale, i18n_text.WorkflowCreated),
    workflow_updated: i18n.t(model.ui.locale, i18n_text.WorkflowUpdated),
    workflow_deleted: i18n.t(model.ui.locale, i18n_text.WorkflowDeleted),
    on_success_toast: app_effects.toast_success,
  )
}

fn rule_crud_feedback_context(
  model: client_state.Model,
) -> workflows_workflow.RuleFeedbackContext(client_state.Msg) {
  workflows_workflow.RuleFeedbackContext(
    rule_created: i18n.t(model.ui.locale, i18n_text.RuleCreated),
    rule_updated: i18n.t(model.ui.locale, i18n_text.RuleUpdated),
    rule_deleted: i18n.t(model.ui.locale, i18n_text.RuleDeleted),
    on_success_toast: app_effects.toast_success,
  )
}

fn template_attachment_feedback_context(
  model: client_state.Model,
) -> workflows_workflow.TemplateAttachmentFeedbackContext(client_state.Msg) {
  workflows_workflow.TemplateAttachmentFeedbackContext(
    template_attached: i18n.t(model.ui.locale, i18n_text.TemplateAttached),
    template_detached: i18n.t(model.ui.locale, i18n_text.TemplateDetached),
    on_success_toast: app_effects.toast_success,
    on_error_toast: app_effects.toast_error,
  )
}

fn template_attachment_context(
  model: client_state.Model,
) -> workflows_workflow.TemplateAttachmentContext(client_state.Msg) {
  workflows_workflow.TemplateAttachmentContext(
    selected_project_id: model.core.selected_project_id,
    on_task_templates_fetched: fn(result) {
      client_state.pool_msg(pool_messages.TaskTemplatesProjectFetched(result))
    },
    on_attach_template_succeeded: fn(rule_id, templates) {
      client_state.pool_msg(pool_messages.AttachTemplateSucceeded(
        rule_id,
        templates,
      ))
    },
    on_attach_template_failed: fn(err) {
      client_state.pool_msg(pool_messages.AttachTemplateFailed(err))
    },
    on_template_detach_succeeded: fn(rule_id, template_id) {
      client_state.pool_msg(pool_messages.TemplateDetachSucceeded(
        rule_id,
        template_id,
      ))
    },
    on_template_detach_failed: fn(rule_id, template_id, err) {
      client_state.pool_msg(pool_messages.TemplateDetachFailed(
        rule_id,
        template_id,
        err,
      ))
    },
  )
}

fn task_template_crud_feedback_context(
  model: client_state.Model,
) -> task_templates_workflow.FeedbackContext(client_state.Msg) {
  task_templates_workflow.FeedbackContext(
    task_template_created: i18n.t(
      model.ui.locale,
      i18n_text.TaskTemplateCreated,
    ),
    task_template_updated: i18n.t(
      model.ui.locale,
      i18n_text.TaskTemplateUpdated,
    ),
    task_template_deleted: i18n.t(
      model.ui.locale,
      i18n_text.TaskTemplateDeleted,
    ),
    on_success_toast: app_effects.toast_success,
  )
}

fn refetch_work_sessions_effect() -> effect.Effect(client_state.Msg) {
  active_api.get_work_sessions(fn(result) {
    client_state.pool_msg(pool_messages.MemberWorkSessionsFetched(result))
  })
}

fn update_member_metrics(
  model: client_state.Model,
  f: fn(member_metrics.Model) -> member_metrics.Model,
) -> client_state.Model {
  client_state.update_member(model, fn(member) {
    let metrics = member.metrics
    member_state.MemberModel(..member, metrics: f(metrics))
  })
}

fn update_admin_metrics(
  model: client_state.Model,
  f: fn(admin_metrics.Model) -> admin_metrics.Model,
) -> client_state.Model {
  client_state.update_admin(model, fn(admin) {
    let metrics = admin.metrics
    admin_state.AdminModel(..admin, metrics: f(metrics))
  })
}

fn update_admin_cards(
  model: client_state.Model,
  f: fn(admin_cards.Model) -> admin_cards.Model,
) -> client_state.Model {
  client_state.update_admin(model, fn(admin) {
    let cards = admin.cards
    admin_state.AdminModel(..admin, cards: f(cards))
  })
}

fn update_admin_rules(
  model: client_state.Model,
  f: fn(admin_rules.Model) -> admin_rules.Model,
) -> client_state.Model {
  client_state.update_admin(model, fn(admin) {
    let rules = admin.rules
    admin_state.AdminModel(..admin, rules: f(rules))
  })
}

fn update_admin_task_templates(
  model: client_state.Model,
  f: fn(admin_task_templates.Model) -> admin_task_templates.Model,
) -> client_state.Model {
  client_state.update_admin(model, fn(admin) {
    let task_templates = admin.task_templates
    admin_state.AdminModel(..admin, task_templates: f(task_templates))
  })
}

fn template_attachment_model(
  model: client_state.Model,
) -> workflows_workflow.TemplateAttachmentModel {
  workflows_workflow.TemplateAttachmentModel(
    rules: model.admin.rules,
    task_templates: model.admin.task_templates,
  )
}

fn update_template_attachment_model(
  model: client_state.Model,
  local: workflows_workflow.TemplateAttachmentModel,
) -> client_state.Model {
  let workflows_workflow.TemplateAttachmentModel(
    rules: rules,
    task_templates: task_templates,
  ) = local

  client_state.update_admin(model, fn(admin) {
    admin_state.AdminModel(
      ..admin,
      rules: rules,
      task_templates: task_templates,
    )
  })
}

fn update_admin_workflows(
  model: client_state.Model,
  f: fn(admin_workflows.Model) -> admin_workflows.Model,
) -> client_state.Model {
  client_state.update_admin(model, fn(admin) {
    let workflows = admin.workflows
    admin_state.AdminModel(..admin, workflows: f(workflows))
  })
}

fn selected_user_id(model: client_state.Model) -> opt.Option(Int) {
  model.core.user
  |> opt.map(fn(user) { user.id })
}

fn apply_auth_check_before(
  model: client_state.Model,
  auth_error: opt.Option(ApiError),
  apply_update: fn() -> #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case auth_error {
    opt.None -> apply_update()
    opt.Some(err) -> auth_helpers.handle_401_or(model, err, apply_update)
  }
}

fn apply_auth_check_after(
  auth_error: opt.Option(ApiError),
  apply_update: fn() -> #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case auth_error {
    opt.None -> apply_update()
    opt.Some(err) -> {
      let #(next, fx) = apply_update()
      auth_helpers.handle_401_or(next, err, fn() { #(next, fx) })
    }
  }
}

// =============================================================================
// Dispatch
// =============================================================================

/// Provides pool update context.
pub type Context {
  Context(
    member_refresh: fn(client_state.Model) ->
      #(client_state.Model, effect.Effect(client_state.Msg)),
  )
}

/// Dispatch pool messages to feature handlers.
///
pub fn update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  ctx: Context,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let Context(member_refresh: member_refresh) = ctx

  case try_milestones_update(model, inner, member_refresh) {
    opt.Some(result) -> result
    opt.None -> update_without_milestones(model, inner, member_refresh)
  }
}

fn try_milestones_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case
    milestones_workflow.try_member_pool_update(
      model.member.pool,
      inner,
      milestone_context(model),
      milestone_feedback_context(model),
    )
  {
    opt.Some(update) ->
      opt.Some(apply_milestones_update(
        model,
        update,
        milestone_feedback_context(model),
        member_refresh,
      ))
    opt.None -> opt.None
  }
}

fn apply_milestones_update(
  model: client_state.Model,
  update: milestones_workflow.Update(client_state.Msg),
  feedback: milestones_workflow.FeedbackContext(client_state.Msg),
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let milestones_workflow.Update(pool, local_fx, refresh_policy, root_policy) =
    update
  let model = update_member_pool(model, fn(_) { pool })

  let #(model, fx) =
    apply_milestone_refresh_policy(
      model,
      local_fx,
      refresh_policy,
      feedback,
      member_refresh,
    )

  apply_milestone_root_policy(model, fx, root_policy)
}

fn apply_milestone_refresh_policy(
  model: client_state.Model,
  local_fx: effect.Effect(client_state.Msg),
  refresh_policy: milestones_workflow.RefreshPolicy,
  feedback: milestones_workflow.FeedbackContext(client_state.Msg),
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case refresh_policy {
    milestones_workflow.NoRefresh -> #(model, local_fx)
    milestones_workflow.RefreshWithSuccess(success) -> {
      let #(next, refresh_fx) = member_refresh(model)
      #(
        next,
        effect.batch([
          local_fx,
          milestones_workflow.success_effect(success, feedback),
          refresh_fx,
        ]),
      )
    }
  }
}

fn apply_milestone_root_policy(
  model: client_state.Model,
  fx: effect.Effect(client_state.Msg),
  policy: milestones_workflow.RootPolicy,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case policy {
    milestones_workflow.NoRootPolicy -> #(model, fx)
    milestones_workflow.OpenCardForMilestone(milestone_id) -> {
      let #(cards, card_fx) =
        cards_workflow.handle_open_card_dialog_for_milestone(
          model.admin.cards,
          milestone_id,
        )
      let next = update_admin_cards(model, fn(_) { cards })

      #(next, effect.batch([fx, card_fx]))
    }
  }
}

fn update_without_milestones(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case try_pool_shortcut_update(model, inner) {
    opt.Some(result) -> result
    opt.None -> update_without_shortcuts(model, inner, member_refresh)
  }
}

fn try_pool_shortcut_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case
    shortcut_update.try_update(
      pool_shortcut_model(model),
      inner,
      pool_shortcut_context(model),
    )
  {
    opt.Some(update) -> opt.Some(apply_pool_shortcut_update(model, update))
    opt.None -> opt.None
  }
}

fn apply_pool_shortcut_update(
  model: client_state.Model,
  update: shortcut_update.Update(client_state.Msg),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let shortcut_update.Update(local, fx) = update
  #(update_pool_shortcut_model(model, local), fx)
}

fn pool_shortcut_context(model: client_state.Model) -> shortcut_update.Context {
  shortcut_update.Context(
    is_pool_shortcut_target: model.core.page == client_state.Member
    && model.member.pool.member_section == member_section.Pool,
  )
}

fn update_without_shortcuts(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case try_pool_drag_update(model, inner) {
    opt.Some(result) -> result
    opt.None -> update_without_drag(model, inner, member_refresh)
  }
}

fn try_pool_drag_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case
    drag_update.try_update(
      pool_drag_model(model),
      inner,
      pool_drag_context(model),
    )
  {
    opt.Some(#(local, fx)) ->
      opt.Some(#(update_pool_drag_model(model, local), fx))
    opt.None -> opt.None
  }
}

fn update_without_drag(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case try_pool_card_detail_update(model, inner) {
    opt.Some(result) -> result
    opt.None -> update_without_card_detail(model, inner, member_refresh)
  }
}

fn try_pool_card_detail_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case
    card_detail_update.try_update(
      pool_card_detail_model(model),
      inner,
      card_detail_context(),
    )
  {
    opt.Some(#(local, fx)) ->
      opt.Some(#(update_pool_card_detail_model(model, local), fx))
    opt.None -> opt.None
  }
}

fn update_without_card_detail(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case try_pool_project_refresh_update(model, inner) {
    opt.Some(result) -> result
    opt.None -> update_without_project_refresh(model, inner, member_refresh)
  }
}

fn try_pool_project_refresh_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case project_refresh.try_update(model.member.pool, inner) {
    opt.Some(update) ->
      opt.Some(apply_pool_project_refresh_update(model, update))
    opt.None -> opt.None
  }
}

fn apply_pool_project_refresh_update(
  model: client_state.Model,
  update: project_refresh.Update,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let project_refresh.Update(pool, auth_policy) = update

  apply_auth_check_before(model, project_refresh_auth_error(auth_policy), fn() {
    #(update_member_pool(model, fn(_) { pool }), effect.none())
  })
}

fn project_refresh_auth_error(
  policy: project_refresh.AuthPolicy,
) -> opt.Option(ApiError) {
  case policy {
    project_refresh.NoAuthCheck -> opt.None
    project_refresh.CheckAuth(err) -> opt.Some(err)
  }
}

fn update_without_project_refresh(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case try_pool_card_refresh_update(model, inner) {
    opt.Some(result) -> result
    opt.None -> update_without_card_refresh(model, inner, member_refresh)
  }
}

fn try_pool_card_refresh_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case card_refresh.try_update(model.member.pool, inner) {
    opt.Some(pool) ->
      opt.Some(#(update_member_pool(model, fn(_) { pool }), effect.none()))
    opt.None -> opt.None
  }
}

fn update_without_card_refresh(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case try_pool_admin_cards_update(model, inner) {
    opt.Some(result) -> result
    opt.None -> update_without_admin_cards(model, inner, member_refresh)
  }
}

fn try_pool_admin_cards_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case
    cards_workflow.try_update(
      model.admin.cards,
      inner,
      card_crud_feedback_context(model),
    )
  {
    opt.Some(update) -> opt.Some(apply_pool_admin_cards_update(model, update))
    opt.None -> opt.None
  }
}

fn apply_pool_admin_cards_update(
  model: client_state.Model,
  update: cards_workflow.Update(client_state.Msg),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let cards_workflow.Update(cards, fx, auth_policy, focus_policy) = update

  apply_auth_check_before(model, cards_auth_error(auth_policy), fn() {
    #(
      update_admin_cards(model, fn(_) { cards }),
      apply_admin_cards_focus_policy(model, focus_policy, fx),
    )
  })
}

fn cards_auth_error(policy: cards_workflow.AuthPolicy) -> opt.Option(ApiError) {
  case policy {
    cards_workflow.NoAuthCheck -> opt.None
    cards_workflow.CheckAuth(err) -> opt.Some(err)
  }
}

fn apply_admin_cards_focus_policy(
  model: client_state.Model,
  focus_policy: cards_workflow.FocusPolicy,
  fx: effect.Effect(client_state.Msg),
) -> effect.Effect(client_state.Msg) {
  case focus_policy {
    cards_workflow.NoFocusAfterUpdate -> fx
    cards_workflow.FocusAfterClose ->
      case close_card_dialog_focus_target(model) {
        opt.Some(element_id) ->
          effect.batch([
            fx,
            app_effects.focus_element_after_timeout(element_id, 0),
          ])
        opt.None -> fx
      }
  }
}

fn update_without_admin_cards(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case try_pool_workflows_update(model, inner) {
    opt.Some(result) -> result
    opt.None -> update_without_workflows(model, inner, member_refresh)
  }
}

fn try_pool_workflows_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case
    workflows_workflow.try_workflows_update(
      model.admin.workflows,
      inner,
      workflow_crud_feedback_context(model),
    )
  {
    opt.Some(update) -> opt.Some(apply_pool_workflows_update(model, update))
    opt.None -> opt.None
  }
}

fn apply_pool_workflows_update(
  model: client_state.Model,
  update: workflows_workflow.WorkflowUpdate(client_state.Msg),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let workflows_workflow.WorkflowUpdate(workflows, fx, auth_policy) = update

  apply_auth_check_before(model, workflow_auth_error(auth_policy), fn() {
    #(update_admin_workflows(model, fn(_) { workflows }), fx)
  })
}

fn workflow_auth_error(
  policy: workflows_workflow.WorkflowAuthPolicy,
) -> opt.Option(ApiError) {
  case policy {
    workflows_workflow.NoWorkflowAuthCheck -> opt.None
    workflows_workflow.CheckWorkflowAuth(err) -> opt.Some(err)
  }
}

fn update_without_workflows(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case try_pool_rules_update(model, inner) {
    opt.Some(result) -> result
    opt.None -> update_without_rules(model, inner, member_refresh)
  }
}

fn try_pool_rules_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case
    workflows_workflow.try_rules_update(
      model.admin.rules,
      inner,
      rules_context(model),
      rule_crud_feedback_context(model),
    )
  {
    opt.Some(update) -> opt.Some(apply_pool_rules_update(model, update))
    opt.None -> opt.None
  }
}

fn apply_pool_rules_update(
  model: client_state.Model,
  update: workflows_workflow.RulesUpdate(client_state.Msg),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let workflows_workflow.RulesUpdate(rules, fx, auth_policy) = update

  apply_auth_check_before(model, rules_auth_error(auth_policy), fn() {
    #(update_admin_rules(model, fn(_) { rules }), fx)
  })
}

fn rules_auth_error(
  policy: workflows_workflow.RulesAuthPolicy,
) -> opt.Option(ApiError) {
  case policy {
    workflows_workflow.NoRulesAuthCheck -> opt.None
    workflows_workflow.CheckRulesAuth(err) -> opt.Some(err)
  }
}

fn update_without_rules(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case try_pool_template_attachment_update(model, inner) {
    opt.Some(result) -> result
    opt.None -> update_without_template_attachment(model, inner, member_refresh)
  }
}

fn try_pool_template_attachment_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case
    workflows_workflow.try_template_attachment_update(
      template_attachment_model(model),
      inner,
      template_attachment_context(model),
      template_attachment_feedback_context(model),
    )
  {
    opt.Some(update) ->
      opt.Some(apply_pool_template_attachment_update(model, update))
    opt.None -> opt.None
  }
}

fn apply_pool_template_attachment_update(
  model: client_state.Model,
  update: workflows_workflow.TemplateAttachmentUpdate(client_state.Msg),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let workflows_workflow.TemplateAttachmentUpdate(local, fx, auth_policy) =
    update

  apply_auth_check_before(
    model,
    template_attachment_auth_error(auth_policy),
    fn() { #(update_template_attachment_model(model, local), fx) },
  )
}

fn template_attachment_auth_error(
  policy: workflows_workflow.TemplateAttachmentAuthPolicy,
) -> opt.Option(ApiError) {
  case policy {
    workflows_workflow.NoTemplateAttachmentAuthCheck -> opt.None
    workflows_workflow.CheckTemplateAttachmentAuth(err) -> opt.Some(err)
  }
}

fn update_without_template_attachment(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case try_pool_task_templates_update(model, inner) {
    opt.Some(result) -> result
    opt.None -> update_without_task_templates(model, inner, member_refresh)
  }
}

fn try_pool_task_templates_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case
    task_templates_workflow.try_update(
      model.admin.task_templates,
      inner,
      task_template_crud_feedback_context(model),
    )
  {
    opt.Some(update) ->
      opt.Some(apply_pool_task_templates_update(model, update))
    opt.None -> opt.None
  }
}

fn apply_pool_task_templates_update(
  model: client_state.Model,
  update: task_templates_workflow.Update(client_state.Msg),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let task_templates_workflow.Update(task_templates, fx, auth_policy) = update

  apply_auth_check_before(model, task_templates_auth_error(auth_policy), fn() {
    #(update_admin_task_templates(model, fn(_) { task_templates }), fx)
  })
}

fn task_templates_auth_error(
  policy: task_templates_workflow.AuthPolicy,
) -> opt.Option(ApiError) {
  case policy {
    task_templates_workflow.NoAuthCheck -> opt.None
    task_templates_workflow.CheckAuth(err) -> opt.Some(err)
  }
}

fn update_without_task_templates(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case try_pool_filters_update(model, inner, member_refresh) {
    opt.Some(result) -> result
    opt.None -> update_without_filters(model, inner, member_refresh)
  }
}

fn try_pool_filters_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case pool_filters.try_update(model.member.pool, inner) {
    opt.Some(#(pool, should_refresh)) -> {
      let next = update_member_pool(model, fn(_) { pool })
      case should_refresh {
        True -> opt.Some(member_refresh(next))
        False -> opt.Some(#(next, effect.none()))
      }
    }
    opt.None -> opt.None
  }
}

fn update_without_filters(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case try_pool_preferences_update(model, inner) {
    opt.Some(result) -> result
    opt.None -> update_without_preferences(model, inner, member_refresh)
  }
}

fn try_pool_preferences_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case pool_preferences.try_update(model.member.pool, inner) {
    opt.Some(#(pool, persistence)) ->
      opt.Some(#(
        update_member_pool(model, fn(_) { pool }),
        pool_preferences_persistence_effect(persistence),
      ))
    opt.None -> opt.None
  }
}

fn pool_preferences_persistence_effect(
  persistence: pool_preferences.Persistence,
) -> effect.Effect(client_state.Msg) {
  case persistence {
    pool_preferences.NoPersistence -> effect.none()
    pool_preferences.SaveFiltersVisible(visible) ->
      save_pool_filters_visible_effect(visible)
    pool_preferences.SaveViewMode(mode) -> save_pool_view_mode_effect(mode)
  }
}

fn update_without_preferences(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case try_pool_people_update(model, inner) {
    opt.Some(result) -> result
    opt.None -> update_without_people(model, inner, member_refresh)
  }
}

fn try_pool_people_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case people_workflow.try_update(model.member.pool, inner) {
    opt.Some(#(pool, fx)) ->
      opt.Some(#(update_member_pool(model, fn(_) { pool }), fx))
    opt.None -> opt.None
  }
}

fn update_without_people(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case try_pool_metrics_update(model, inner) {
    opt.Some(result) -> result
    opt.None -> update_without_metrics(model, inner, member_refresh)
  }
}

fn try_pool_metrics_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case
    metrics_workflow.try_update(
      model.member.metrics,
      model.admin.metrics,
      inner,
    )
  {
    opt.Some(update) -> opt.Some(apply_pool_metrics_update(model, update))
    opt.None -> opt.None
  }
}

fn apply_pool_metrics_update(
  model: client_state.Model,
  update: metrics_workflow.Update(client_state.Msg),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case update {
    metrics_workflow.MemberUpdate(metrics, fx, auth_policy) ->
      apply_auth_check_before(model, metrics_auth_error(auth_policy), fn() {
        #(update_member_metrics(model, fn(_) { metrics }), fx)
      })
    metrics_workflow.AdminUpdate(metrics, fx, auth_policy) ->
      apply_auth_check_before(model, metrics_auth_error(auth_policy), fn() {
        #(update_admin_metrics(model, fn(_) { metrics }), fx)
      })
  }
}

fn metrics_auth_error(
  policy: metrics_workflow.AuthPolicy,
) -> opt.Option(ApiError) {
  case policy {
    metrics_workflow.NoAuthCheck -> opt.None
    metrics_workflow.CheckAuth(err) -> opt.Some(err)
  }
}

fn update_without_metrics(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case try_pool_rule_metrics_update(model, inner) {
    opt.Some(result) -> result
    opt.None -> update_without_rule_metrics(model, inner, member_refresh)
  }
}

fn try_pool_rule_metrics_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case
    rule_metrics_workflow.try_update(
      model.admin.metrics,
      inner,
      rule_metrics_context(),
    )
  {
    opt.Some(update) -> opt.Some(apply_pool_rule_metrics_update(model, update))
    opt.None -> opt.None
  }
}

fn apply_pool_rule_metrics_update(
  model: client_state.Model,
  update: rule_metrics_workflow.Update(client_state.Msg),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let rule_metrics_workflow.Update(metrics, fx, auth_policy) = update

  apply_auth_check_before(model, rule_metrics_auth_error(auth_policy), fn() {
    #(update_admin_metrics(model, fn(_) { metrics }), fx)
  })
}

fn rule_metrics_auth_error(
  policy: rule_metrics_workflow.AuthPolicy,
) -> opt.Option(ApiError) {
  case policy {
    rule_metrics_workflow.NoAuthCheck -> opt.None
    rule_metrics_workflow.CheckAuth(err) -> opt.Some(err)
  }
}

fn update_without_rule_metrics(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case try_pool_skills_update(model, inner) {
    opt.Some(result) -> result
    opt.None -> update_without_skills(model, inner, member_refresh)
  }
}

fn try_pool_skills_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case
    skills_workflow.try_update(
      model.member.skills,
      inner,
      skills_context(model),
    )
  {
    opt.Some(update) -> opt.Some(apply_pool_skills_update(model, update))
    opt.None -> opt.None
  }
}

fn apply_pool_skills_update(
  model: client_state.Model,
  update: skills_workflow.Update(client_state.Msg),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let skills_workflow.Update(skills, fx, auth_policy) = update

  apply_auth_check_before(model, skills_auth_error(auth_policy), fn() {
    #(update_member_skills(model, fn(_) { skills }), fx)
  })
}

fn skills_auth_error(policy: skills_workflow.AuthPolicy) -> opt.Option(ApiError) {
  case policy {
    skills_workflow.NoAuthCheck -> opt.None
    skills_workflow.CheckAuth(err) -> opt.Some(err)
  }
}

fn update_without_skills(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case try_pool_now_working_update(model, inner) {
    opt.Some(result) -> result
    opt.None -> update_without_now_working(model, inner, member_refresh)
  }
}

fn try_pool_now_working_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case
    now_working_workflow.try_update(
      now_working_model(model),
      inner,
      now_working_context(),
    )
  {
    opt.Some(update) -> opt.Some(apply_pool_now_working_update(model, update))
    opt.None -> opt.None
  }
}

fn apply_pool_now_working_update(
  model: client_state.Model,
  update: now_working_workflow.Update(client_state.Msg),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let now_working_workflow.Update(local, fx, auth_policy) = update

  apply_now_working_auth_policy(model, auth_policy, fn() {
    #(update_now_working_model(model, local), fx)
  })
}

fn apply_now_working_auth_policy(
  model: client_state.Model,
  auth_policy: now_working_workflow.AuthPolicy,
  apply_update: fn() -> #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case auth_policy {
    now_working_workflow.NoAuthCheck -> apply_update()
    now_working_workflow.CheckAuthBefore(err) ->
      apply_auth_check_before(model, opt.Some(err), apply_update)
    now_working_workflow.CheckAuthAfter(err) ->
      apply_auth_check_after(opt.Some(err), apply_update)
  }
}

fn update_without_now_working(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case try_pool_positions_update(model, inner) {
    opt.Some(result) -> result
    opt.None -> update_without_positions(model, inner, member_refresh)
  }
}

fn try_pool_positions_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case
    position_update.try_update(
      model.member.positions,
      inner,
      position_update_context(model),
    )
  {
    opt.Some(update) -> opt.Some(apply_pool_positions_update(model, update))
    opt.None -> opt.None
  }
}

fn apply_pool_positions_update(
  model: client_state.Model,
  update: position_update.Update(client_state.Msg),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let position_update.Update(positions, fx, auth_policy) = update

  apply_auth_check_before(model, position_auth_error(auth_policy), fn() {
    #(update_member_positions(model, fn(_) { positions }), fx)
  })
}

fn position_auth_error(
  policy: position_update.AuthPolicy,
) -> opt.Option(ApiError) {
  case policy {
    position_update.NoAuthCheck -> opt.None
    position_update.CheckAuth(err) -> opt.Some(err)
  }
}

fn update_without_positions(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case try_pool_dependencies_update(model, inner) {
    opt.Some(result) -> result
    opt.None -> update_without_dependencies(model, inner, member_refresh)
  }
}

fn try_pool_dependencies_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case
    dependency_workflow.try_update(
      task_dependencies_model(model),
      inner,
      dependency_context(model),
      dependency_feedback_context(),
    )
  {
    opt.Some(update) -> opt.Some(apply_pool_dependencies_update(model, update))
    opt.None -> opt.None
  }
}

fn apply_pool_dependencies_update(
  model: client_state.Model,
  update: dependency_workflow.Update(client_state.Msg),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let dependency_workflow.Update(local, fx, auth_policy) = update

  apply_auth_check_before(model, dependency_auth_error(auth_policy), fn() {
    #(update_task_dependencies_model(model, local), fx)
  })
}

fn dependency_auth_error(
  policy: dependency_workflow.AuthPolicy,
) -> opt.Option(ApiError) {
  case policy {
    dependency_workflow.NoAuthCheck -> opt.None
    dependency_workflow.CheckAuth(err) -> opt.Some(err)
  }
}

fn update_without_dependencies(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case try_pool_notes_update(model, inner) {
    opt.Some(result) -> result
    opt.None -> update_without_notes(model, inner, member_refresh)
  }
}

fn try_pool_notes_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case
    tasks_workflow.try_note_update(
      model.member.notes,
      inner,
      note_context(model),
    )
  {
    opt.Some(update) -> opt.Some(apply_pool_notes_update(model, update))
    opt.None -> opt.None
  }
}

fn apply_pool_notes_update(
  model: client_state.Model,
  update: tasks_workflow.NoteUpdate(client_state.Msg),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let tasks_workflow.NoteUpdate(notes, fx, auth_policy) = update

  apply_auth_check_before(model, tasks_auth_error(auth_policy), fn() {
    #(update_member_notes(model, fn(_) { notes }), fx)
  })
}

fn tasks_auth_error(policy: tasks_workflow.AuthPolicy) -> opt.Option(ApiError) {
  case policy {
    tasks_workflow.NoAuthCheck -> opt.None
    tasks_workflow.CheckAuth(err) -> opt.Some(err)
  }
}

fn update_without_notes(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case try_pool_task_create_update(model, inner, member_refresh) {
    opt.Some(result) -> result
    opt.None -> update_without_task_create(model, inner, member_refresh)
  }
}

fn try_pool_task_create_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case
    tasks_workflow.try_task_create_update(
      model.member.pool,
      inner,
      task_create_context(model),
    )
  {
    opt.Some(update) ->
      opt.Some(apply_pool_task_create_update(model, update, member_refresh))
    opt.None -> opt.None
  }
}

fn apply_pool_task_create_update(
  model: client_state.Model,
  update: tasks_workflow.TaskCreateUpdate(client_state.Msg),
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let tasks_workflow.TaskCreateUpdate(pool, fx, policy) = update

  apply_task_create_policy(model, policy, member_refresh, fn() {
    #(update_member_pool(model, fn(_) { pool }), fx)
  })
}

fn apply_task_create_policy(
  model: client_state.Model,
  policy: tasks_workflow.TaskCreatePolicy,
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
  apply_update: fn() -> #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case policy {
    tasks_workflow.NoTaskCreatePolicy -> apply_update()
    tasks_workflow.RefreshMemberAfterTaskCreated(task) -> {
      let #(next, fx) = apply_update()
      let #(next, refresh_fx) = member_refresh(next)
      let post_create_fx = task_created_effect(next, task)
      #(next, effect.batch([fx, refresh_fx, post_create_fx]))
    }
    tasks_workflow.CheckTaskCreateAuthBefore(err) ->
      apply_auth_check_before(model, opt.Some(err), apply_update)
  }
}

fn update_without_task_create(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case try_pool_task_mutation_update(model, inner, member_refresh) {
    opt.Some(result) -> result
    opt.None -> update_without_task_mutation(model, inner)
  }
}

fn try_pool_task_mutation_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case
    tasks_workflow.try_task_mutation_update(
      model.member.pool,
      inner,
      task_mutation_dispatch_context(model),
    )
  {
    opt.Some(update) ->
      opt.Some(apply_pool_task_mutation_update(model, update, member_refresh))
    opt.None -> opt.None
  }
}

fn apply_pool_task_mutation_update(
  model: client_state.Model,
  update: tasks_workflow.TaskMutationUpdate(client_state.Msg),
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let tasks_workflow.TaskMutationUpdate(pool, fx, policy) = update

  apply_task_mutation_policy(policy, member_refresh, fn() {
    #(update_member_pool(model, fn(_) { pool }), fx)
  })
}

fn apply_task_mutation_policy(
  policy: tasks_workflow.TaskMutationPolicy,
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
  apply_update: fn() -> #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case policy {
    tasks_workflow.NoTaskMutationPolicy -> apply_update()
    tasks_workflow.RefreshMemberAfterTaskMutationSuccess -> {
      let #(next, fx) = apply_update()
      let #(next, refresh_fx) = member_refresh(next)
      #(next, effect.batch([fx, refresh_fx]))
    }
    tasks_workflow.CheckTaskMutationAuthAfter(err) ->
      apply_auth_check_after(opt.Some(err), apply_update)
  }
}

fn update_without_task_mutation(
  model: client_state.Model,
  inner: client_state.PoolMsg,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case try_pool_task_detail_update(model, inner) {
    opt.Some(result) -> result
    opt.None -> update_without_task_detail(model, inner)
  }
}

fn try_pool_task_detail_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case
    tasks_workflow.try_task_detail_update(
      task_detail_model(model),
      inner,
      task_detail_dispatch_context(model),
    )
  {
    opt.Some(update) -> opt.Some(apply_pool_task_detail_update(model, update))
    opt.None -> opt.None
  }
}

fn apply_pool_task_detail_update(
  model: client_state.Model,
  update: tasks_workflow.TaskDetailUpdate(client_state.Msg),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let tasks_workflow.TaskDetailUpdate(local, fx, auth_policy) = update

  apply_auth_check_after(task_detail_auth_error(auth_policy), fn() {
    #(update_task_detail_model(model, local), fx)
  })
}

fn task_detail_auth_error(
  policy: tasks_workflow.TaskDetailAuthPolicy,
) -> opt.Option(ApiError) {
  case policy {
    tasks_workflow.NoTaskDetailAuthCheck -> opt.None
    tasks_workflow.CheckTaskDetailAuthAfter(err) -> opt.Some(err)
  }
}

fn update_without_task_detail(
  model: client_state.Model,
  inner: client_state.PoolMsg,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case try_pool_view_mode_update(model, inner) {
    opt.Some(result) -> result
    opt.None -> update_without_view_mode(model, inner)
  }
}

fn try_pool_view_mode_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case
    view_mode_update.try_update(
      model.member.pool,
      inner,
      view_mode_context(model),
    )
  {
    opt.Some(update) -> opt.Some(apply_pool_view_mode_update(model, update))
    opt.None -> opt.None
  }
}

fn view_mode_context(model: client_state.Model) -> view_mode_update.Context {
  view_mode_update.Context(
    selected_project_id: model.core.selected_project_id,
    member_section: model.member.pool.member_section,
  )
}

fn apply_pool_view_mode_update(
  model: client_state.Model,
  update: view_mode_update.Update,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let view_mode_update.Update(pool, route_policy) = update
  let model = update_member_pool(model, fn(_) { pool })

  #(model, apply_view_mode_route_policy(route_policy))
}

fn apply_view_mode_route_policy(
  route_policy: view_mode_update.RoutePolicy,
) -> effect.Effect(client_state.Msg) {
  case route_policy {
    view_mode_update.NoRouteChange -> effect.none()
    view_mode_update.ReplaceMemberRoute(section, state) ->
      router.replace(router.Member(section, state))
  }
}

fn update_without_view_mode(
  model: client_state.Model,
  inner: client_state.PoolMsg,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case inner {
    // Handled by shortcut_update.try_update before this dispatch.
    pool_messages.GlobalKeyDown(_) -> #(model, effect.none())

    // Handled by view_mode_update.try_update before this dispatch.
    pool_messages.ViewModeChanged(_) -> #(model, effect.none())

    // Handled by pool_filters.try_update before this dispatch.
    pool_messages.MemberPoolStatusChanged(_)
    | pool_messages.MemberPoolTypeChanged(_)
    | pool_messages.MemberPoolCapabilityChanged(_)
    | pool_messages.MemberPoolCapabilityScopeChanged(_)
    | pool_messages.MemberClearFilters
    | pool_messages.MemberPoolSearchChanged(_)
    | pool_messages.MemberPoolSearchDebounced(_) -> #(model, effect.none())

    // Handled by pool_preferences.try_update before this dispatch.
    pool_messages.MemberPoolFiltersToggled
    | pool_messages.MemberPoolViewModeSet(_)
    | pool_messages.MemberListHideCompletedToggled
    | pool_messages.MemberListCardToggled(_) -> #(model, effect.none())

    // Handled by people_workflow.try_update before this dispatch.
    pool_messages.MemberPeopleRosterFetched(_)
    | pool_messages.MemberPeopleRowToggled(_) -> #(model, effect.none())

    // Handled by project_refresh.try_update before this dispatch.
    pool_messages.MemberProjectTasksFetched(_, _)
    | pool_messages.MemberTaskTypesFetched(_, _) -> #(model, effect.none())

    // Handled by tasks_workflow.try_task_create_update before this dispatch.
    pool_messages.MemberCreateDialogOpened
    | pool_messages.MemberCreateDialogOpenedWithCard(_)
    | pool_messages.MemberCreateDialogClosed
    | pool_messages.MemberCreateTitleChanged(_)
    | pool_messages.MemberCreateDescriptionChanged(_)
    | pool_messages.MemberCreatePriorityChanged(_)
    | pool_messages.MemberCreateTypeIdChanged(_)
    | pool_messages.MemberCreateCardIdChanged(_)
    | pool_messages.MemberCreateTypeOptionsRetryClicked
    | pool_messages.MemberCreateSubmitted
    | pool_messages.MemberTaskCreated(_) -> #(model, effect.none())

    // Handled by tasks_workflow.try_task_mutation_update before this dispatch.
    pool_messages.MemberClaimClicked(_, _)
    | pool_messages.MemberReleaseClicked(_, _)
    | pool_messages.MemberCompleteClicked(_, _)
    | pool_messages.MemberBlockedClaimCancelled
    | pool_messages.MemberBlockedClaimConfirmed
    | pool_messages.MemberTaskClaimed(_)
    | pool_messages.MemberTaskReleased(_)
    | pool_messages.MemberTaskCompleted(_) -> #(model, effect.none())

    // Handled by now_working_workflow.try_update before this dispatch.
    pool_messages.MemberNowWorkingStartClicked(_)
    | pool_messages.MemberNowWorkingPauseClicked
    | pool_messages.MemberWorkSessionsFetched(_)
    | pool_messages.MemberWorkSessionStarted(_)
    | pool_messages.MemberWorkSessionPaused(_)
    | pool_messages.MemberWorkSessionHeartbeated(_)
    | pool_messages.NowWorkingTicked -> #(model, effect.none())

    // Handled by metrics_workflow.try_update before this dispatch.
    pool_messages.MemberMetricsFetched(_)
    | pool_messages.AdminMetricsOverviewFetched(_)
    | pool_messages.AdminMetricsProjectTasksFetched(_)
    | pool_messages.AdminMetricsUsersFetched(_) -> #(model, effect.none())

    // Handled by rule_metrics_workflow.try_update before this dispatch.
    pool_messages.AdminRuleMetricsFetched(_)
    | pool_messages.AdminRuleMetricsFromChanged(_)
    | pool_messages.AdminRuleMetricsToChanged(_)
    | pool_messages.AdminRuleMetricsFromChangedAndRefresh(_)
    | pool_messages.AdminRuleMetricsToChangedAndRefresh(_)
    | pool_messages.AdminRuleMetricsRefreshClicked
    | pool_messages.AdminRuleMetricsQuickRangeClicked(_, _)
    | pool_messages.AdminRuleMetricsWorkflowExpanded(_)
    | pool_messages.AdminRuleMetricsWorkflowDetailsFetched(_)
    | pool_messages.AdminRuleMetricsDrilldownClicked(_)
    | pool_messages.AdminRuleMetricsDrilldownClosed
    | pool_messages.AdminRuleMetricsRuleDetailsFetched(_)
    | pool_messages.AdminRuleMetricsExecutionsFetched(_)
    | pool_messages.AdminRuleMetricsExecPageChanged(_) -> #(
      model,
      effect.none(),
    )

    // Handled by skills_workflow.try_update before this dispatch.
    pool_messages.MemberMyCapabilityIdsFetched(_)
    | pool_messages.MemberProjectCapabilitiesFetched(_)
    | pool_messages.MemberToggleCapability(_)
    | pool_messages.MemberSaveCapabilitiesClicked
    | pool_messages.MemberMyCapabilityIdsSaved(_) -> #(model, effect.none())

    // Handled by position_update.try_update before this dispatch.
    pool_messages.MemberPositionsFetched(_)
    | pool_messages.MemberPositionEditOpened(_)
    | pool_messages.MemberPositionEditClosed
    | pool_messages.MemberPositionEditXChanged(_)
    | pool_messages.MemberPositionEditYChanged(_)
    | pool_messages.MemberPositionEditSubmitted
    | pool_messages.MemberPositionSaved(_) -> #(model, effect.none())

    // Handled by tasks_workflow.try_task_detail_update before this dispatch.
    pool_messages.MemberTaskDetailsOpened(_)
    | pool_messages.MemberTaskDetailsClosed
    | pool_messages.MemberTaskDetailTabClicked(_)
    | pool_messages.MemberTaskDetailEditStarted
    | pool_messages.MemberTaskDetailEditCancelled
    | pool_messages.MemberTaskDetailEditTitleChanged(_)
    | pool_messages.MemberTaskDetailEditDescriptionChanged(_)
    | pool_messages.MemberTaskDetailEditSubmitted
    | pool_messages.MemberTaskUpdated(_)
    | pool_messages.MemberTaskMetricsFetched(_) -> #(model, effect.none())

    // Handled by dependency_workflow.try_update before this dispatch.
    pool_messages.MemberDependenciesFetched(_)
    | pool_messages.MemberDependencyDialogOpened
    | pool_messages.MemberDependencyDialogClosed
    | pool_messages.MemberDependencySearchChanged(_)
    | pool_messages.MemberDependencyCandidatesFetched(_)
    | pool_messages.MemberDependencySelected(_)
    | pool_messages.MemberDependencyAddSubmitted
    | pool_messages.MemberDependencyAdded(_)
    | pool_messages.MemberDependencyRemoveClicked(_)
    | pool_messages.MemberDependencyRemoved(_, _) -> #(model, effect.none())

    // Handled by tasks_workflow.try_note_update before this dispatch.
    pool_messages.MemberNotesFetched(_)
    | pool_messages.MemberNoteContentChanged(_)
    | pool_messages.MemberNoteDialogOpened
    | pool_messages.MemberNoteDialogClosed
    | pool_messages.MemberNoteSubmitted
    | pool_messages.MemberNoteAdded(_) -> #(model, effect.none())

    // Handled by cards_workflow.try_update before this dispatch.
    pool_messages.CardsFetched(_)
    | pool_messages.OpenCardDialog(_)
    | pool_messages.CloseCardDialog
    | pool_messages.CardCrudCreated(_)
    | pool_messages.CardCrudUpdated(_)
    | pool_messages.CardCrudDeleted(_)
    | pool_messages.CardsShowEmptyToggled
    | pool_messages.CardsShowCompletedToggled
    | pool_messages.CardsStateFilterChanged(_)
    | pool_messages.CardsSearchChanged(_) -> #(model, effect.none())

    // Handled by card_refresh.try_update before this dispatch.
    pool_messages.MemberProjectCardsFetched(_, _) -> #(model, effect.none())

    // Handled by drag_update.try_update before this dispatch.
    pool_messages.MemberPoolMyTasksRectFetched(_, _, _, _)
    | pool_messages.MemberPoolDragToClaimArmed(_)
    | pool_messages.MemberPoolTouchStarted(_, _, _)
    | pool_messages.MemberPoolTouchEnded(_)
    | pool_messages.MemberPoolLongPressCheck(_)
    | pool_messages.MemberTaskHoverOpened(_)
    | pool_messages.MemberTaskHoverClosed
    | pool_messages.MemberTaskFocused(_)
    | pool_messages.MemberTaskBlurred
    | pool_messages.MemberTaskCreatedFeedback(_)
    | pool_messages.MemberHighlightExpired(_)
    | pool_messages.MemberTaskHoverNotesFetched(_, _)
    | pool_messages.MemberCanvasRectFetched(_, _)
    | pool_messages.MemberDragStarted(_, _, _)
    | pool_messages.MemberDragOffsetResolved(_, _, _)
    | pool_messages.MemberDragMoved(_, _)
    | pool_messages.MemberDragEnded -> #(model, effect.none())

    pool_messages.MemberProjectMilestonesFetched(_, _)
    | pool_messages.MemberMilestonesShowCompletedToggled
    | pool_messages.MemberMilestonesShowEmptyToggled
    | pool_messages.MemberMilestoneSearchChanged(_)
    | pool_messages.MemberMilestoneSummaryToggled
    | pool_messages.MemberMilestoneDetailsClicked(_)
    | pool_messages.MemberMilestoneCreateTaskClicked(_)
    | pool_messages.MemberMilestoneCreateCardClicked(_)
    | pool_messages.MemberMilestoneCardDragStarted(_, _)
    | pool_messages.MemberMilestoneTaskDragStarted(_, _)
    | pool_messages.MemberMilestoneDroppedOn(_)
    | pool_messages.MemberMilestoneDragEnded
    | pool_messages.MemberMilestoneCardMoveClicked(_, _, _)
    | pool_messages.MemberMilestoneTaskMoveClicked(_, _, _)
    | pool_messages.MemberMilestoneCardMoved(_)
    | pool_messages.MemberMilestoneTaskMoved(_)
    | pool_messages.MemberMilestoneCreateClicked
    | pool_messages.MemberMilestoneActivatePromptClicked(_)
    | pool_messages.MemberMilestoneActivateClicked(_)
    | pool_messages.MemberMilestoneActivated(_, _)
    | pool_messages.MemberMilestoneEditClicked(_)
    | pool_messages.MemberMilestoneDeleteClicked(_)
    | pool_messages.MemberMilestoneDialogClosed
    | pool_messages.MemberMilestoneNameChanged(_)
    | pool_messages.MemberMilestoneDescriptionChanged(_)
    | pool_messages.MemberMilestoneCreateSubmitted
    | pool_messages.MemberMilestoneCreated(_)
    | pool_messages.MemberMilestoneEditSubmitted(_)
    | pool_messages.MemberMilestoneDeleteSubmitted(_)
    | pool_messages.MemberMilestoneUpdated(_)
    | pool_messages.MemberMilestoneDeleted(_, _) -> #(model, effect.none())

    // Handled by card_detail_update.try_update before this dispatch.
    pool_messages.OpenCardDetail(_)
    | pool_messages.CloseCardDetail
    | pool_messages.CardMetricsFetched(_) -> #(model, effect.none())

    // Handled by milestones workflow before this dispatch.
    pool_messages.MemberMilestoneMetricsFetched(_) -> #(model, effect.none())

    // Handled by workflows_workflow.try_workflows_update before this dispatch.
    pool_messages.WorkflowsProjectFetched(_)
    | pool_messages.OpenWorkflowDialog(_)
    | pool_messages.CloseWorkflowDialog
    | pool_messages.WorkflowCrudCreated(_)
    | pool_messages.WorkflowCrudUpdated(_)
    | pool_messages.WorkflowCrudDeleted(_) -> #(model, effect.none())

    // Handled by workflows_workflow.try_rules_update before this dispatch.
    pool_messages.WorkflowRulesClicked(_)
    | pool_messages.RulesFetched(_)
    | pool_messages.RulesBackClicked
    | pool_messages.RuleMetricsFetched(_)
    | pool_messages.OpenRuleDialog(_)
    | pool_messages.CloseRuleDialog
    | pool_messages.RuleCrudCreated(_)
    | pool_messages.RuleCrudUpdated(_)
    | pool_messages.RuleCrudDeleted(_) -> #(model, effect.none())

    // Handled by workflows_workflow.try_template_attachment_update before this dispatch.
    pool_messages.RuleExpandToggled(_)
    | pool_messages.AttachTemplateModalOpened(_)
    | pool_messages.AttachTemplateModalClosed
    | pool_messages.AttachTemplateSelected(_)
    | pool_messages.AttachTemplateSubmitted
    | pool_messages.AttachTemplateSucceeded(_, _)
    | pool_messages.AttachTemplateFailed(_)
    | pool_messages.TemplateDetachClicked(_, _)
    | pool_messages.TemplateDetachSucceeded(_, _)
    | pool_messages.TemplateDetachFailed(_, _, _) -> #(model, effect.none())

    // Handled by task_templates_workflow.try_update before this dispatch.
    pool_messages.TaskTemplatesProjectFetched(_)
    | pool_messages.OpenTaskTemplateDialog(_)
    | pool_messages.CloseTaskTemplateDialog
    | pool_messages.TaskTemplateCrudCreated(_)
    | pool_messages.TaskTemplateCrudUpdated(_)
    | pool_messages.TaskTemplateCrudDeleted(_) -> #(model, effect.none())
  }
}

fn close_card_dialog_focus_target(
  model: client_state.Model,
) -> opt.Option(String) {
  case
    model.member.pool.member_section,
    model.admin.cards.cards_create_milestone_id
  {
    member_section.Pool, opt.Some(milestone_id) ->
      opt.Some(milestone_ids.quick_create_card_button_id(milestone_id))
    _, _ -> opt.None
  }
}

/// Test helper: exposes close-card-dialog focus target resolution.
pub fn close_card_dialog_focus_target_for_test(
  model: client_state.Model,
) -> opt.Option(String) {
  close_card_dialog_focus_target(model)
}
