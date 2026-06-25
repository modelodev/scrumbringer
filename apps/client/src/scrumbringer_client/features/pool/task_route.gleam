//// Root-aware adapter for task-owned flows reachable from the pool.

import gleam/option as opt
import lustre/effect

import domain/api_error.{type ApiError}
import domain/task
import scrumbringer_client/api/tasks/active as active_api
import scrumbringer_client/app/effects as app_effects
import scrumbringer_client/client_state
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/notes as member_notes
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/pool/available_tasks
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/pool/root
import scrumbringer_client/features/pool/task_created_feedback
import scrumbringer_client/features/pool/task_created_update
import scrumbringer_client/features/route_support
import scrumbringer_client/features/tasks/create_update as task_create_update
import scrumbringer_client/features/tasks/dependency_update as dependency_workflow
import scrumbringer_client/features/tasks/mutation_update as task_mutation_update
import scrumbringer_client/features/tasks/notes_update as task_notes_update
import scrumbringer_client/features/tasks/show_permissions
import scrumbringer_client/features/tasks/show_state
import scrumbringer_client/features/tasks/show_update as task_show_update
import scrumbringer_client/helpers/lookup as helpers_lookup
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/text as i18n_text

pub fn try_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case try_dependencies_update(model, inner) {
    opt.Some(result) -> opt.Some(result)
    opt.None -> update_without_dependencies(model, inner, member_refresh)
  }
}

fn update_without_dependencies(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case try_notes_update(model, inner) {
    opt.Some(result) -> opt.Some(result)
    opt.None -> update_without_notes(model, inner, member_refresh)
  }
}

fn update_without_notes(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case try_task_create_update(model, inner, member_refresh) {
    opt.Some(result) -> opt.Some(result)
    opt.None -> update_without_task_create(model, inner, member_refresh)
  }
}

fn update_without_task_create(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case try_task_mutation_update(model, inner, member_refresh) {
    opt.Some(result) -> opt.Some(result)
    opt.None -> update_without_task_mutation(model, inner)
  }
}

fn update_without_task_mutation(
  model: client_state.Model,
  inner: client_state.PoolMsg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case try_show_update(model, inner) {
    opt.Some(result) -> opt.Some(result)
    opt.None -> opt.None
  }
}

fn try_dependencies_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case
    dependency_workflow.try_update(
      dependencies_model(model),
      inner,
      dependency_context(model),
      dependency_feedback_context(),
    )
  {
    opt.Some(update) -> opt.Some(apply_dependencies_update(model, update))
    opt.None -> opt.None
  }
}

fn apply_dependencies_update(
  model: client_state.Model,
  update: dependency_workflow.Update(client_state.Msg),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let dependency_workflow.Update(local, fx, auth_policy) = update

  route_support.apply_auth_check(
    model,
    route_support.auth_check_before(dependency_auth_error(auth_policy)),
    fn() { #(set_dependencies_model(model, local), fx) },
  )
}

fn dependency_auth_error(
  policy: dependency_workflow.AuthPolicy,
) -> opt.Option(ApiError) {
  case policy {
    dependency_workflow.NoAuthCheck -> opt.None
    dependency_workflow.CheckAuth(err) -> opt.Some(err)
  }
}

fn try_notes_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case
    task_notes_update.try_update(model.member.notes, inner, note_context(model))
  {
    opt.Some(update) -> opt.Some(apply_notes_update(model, update))
    opt.None -> opt.None
  }
}

fn apply_notes_update(
  model: client_state.Model,
  update: task_notes_update.Update(client_state.Msg),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let task_notes_update.Update(notes, fx, auth_policy) = update

  route_support.apply_auth_check(
    model,
    route_support.auth_check_before(note_auth_error(auth_policy)),
    fn() { #(set_member_notes(model, notes), fx) },
  )
}

fn note_auth_error(policy: task_notes_update.AuthPolicy) -> opt.Option(ApiError) {
  case policy {
    task_notes_update.NoAuthCheck -> opt.None
    task_notes_update.CheckAuth(err) -> opt.Some(err)
  }
}

fn try_task_create_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case
    task_create_update.try_update(
      model.member.pool,
      inner,
      task_create_context(model),
    )
  {
    opt.Some(update) ->
      opt.Some(apply_task_create_update(model, update, member_refresh))
    opt.None -> opt.None
  }
}

fn apply_task_create_update(
  model: client_state.Model,
  update: task_create_update.Update(client_state.Msg),
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let task_create_update.Update(pool, fx, policy) = update

  apply_task_create_policy(model, policy, member_refresh, fn() {
    #(root.set_member_pool(model, pool), fx)
  })
}

fn apply_task_create_policy(
  model: client_state.Model,
  policy: task_create_update.Policy,
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
  apply_update: fn() -> #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case policy {
    task_create_update.NoPolicy -> apply_update()
    task_create_update.RefreshMemberAfterCreated(task) -> {
      let #(next, fx) = apply_update()
      let #(next, refresh_fx) = member_refresh(next)
      let post_create_fx = task_created_effect(next, task)
      #(next, effect.batch([fx, refresh_fx, post_create_fx]))
    }
    task_create_update.CheckAuthBefore(err) ->
      route_support.apply_auth_check(
        model,
        route_support.CheckAuthBefore(err),
        apply_update,
      )
  }
}

fn try_task_mutation_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case
    task_mutation_update.try_update(
      model.member.pool,
      inner,
      task_mutation_dispatch_context(model),
    )
  {
    opt.Some(update) ->
      opt.Some(apply_task_mutation_update(model, inner, update, member_refresh))
    opt.None -> opt.None
  }
}

fn apply_task_mutation_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  update: task_mutation_update.Update(client_state.Msg),
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let task_mutation_update.Update(pool, fx, policy) = update

  apply_task_mutation_policy(model, policy, member_refresh, fn() {
    let next = root.set_member_pool(model, pool)
    #(close_deleted_task_show_if_open(next, inner), fx)
  })
}

fn close_deleted_task_show_if_open(
  model: client_state.Model,
  inner: client_state.PoolMsg,
) -> client_state.Model {
  case inner, model.member.notes.member_notes_task_id {
    pool_messages.MemberTaskDeleted(deleted_task_id, Ok(_)),
      opt.Some(open_task_id)
      if deleted_task_id == open_task_id
    -> {
      let #(pool, notes, dependencies) =
        show_state.close(model.member.pool, model.member.notes)
      set_task_show_model(
        model,
        task_show_update.Model(
          pool: pool,
          notes: notes,
          dependencies: dependencies,
        ),
      )
    }
    _, _ -> model
  }
}

fn apply_task_mutation_policy(
  model: client_state.Model,
  policy: task_mutation_update.Policy,
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
  apply_update: fn() -> #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case policy {
    task_mutation_update.NoPolicy -> apply_update()
    task_mutation_update.RefreshMemberAfterSuccess -> {
      let #(next, fx) = apply_update()
      let #(next, refresh_fx) = member_refresh(next)
      #(next, effect.batch([fx, refresh_fx]))
    }
    task_mutation_update.RefreshMemberSilentlyAfterSuccess -> {
      let #(next, fx) = apply_update()
      let #(next, refresh_fx) =
        member_refresh_preserving_tasks(next, member_refresh)
      #(next, effect.batch([fx, refresh_fx]))
    }
    task_mutation_update.CheckAuthAfter(err) ->
      route_support.apply_auth_check(
        model,
        route_support.CheckAuthAfter(err),
        apply_update,
      )
  }
}

fn member_refresh_preserving_tasks(
  model: client_state.Model,
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let current_tasks = model.member.pool.member_tasks
  let #(next, fx) = member_refresh(model)
  let pool = next.member.pool

  #(
    root.set_member_pool(
      next,
      member_pool.Model(..pool, member_tasks: current_tasks),
    ),
    fx,
  )
}

fn try_show_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case
    task_show_update.try_update(
      task_show_model(model),
      inner,
      task_show_dispatch_context(model),
    )
  {
    opt.Some(update) -> opt.Some(apply_task_show_update(model, update))
    opt.None -> opt.None
  }
}

fn apply_task_show_update(
  model: client_state.Model,
  update: task_show_update.Update(client_state.Msg),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let task_show_update.Update(local, fx, auth_policy) = update

  route_support.apply_auth_check(
    model,
    route_support.auth_check_after(task_show_auth_error(auth_policy)),
    fn() { #(set_task_show_model(model, local), fx) },
  )
}

fn task_show_auth_error(
  policy: task_show_update.AuthPolicy,
) -> opt.Option(ApiError) {
  case policy {
    task_show_update.NoAuthCheck -> opt.None
    task_show_update.CheckAuthAfter(err) -> opt.Some(err)
  }
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

fn task_created_feedback_config(
  model: client_state.Model,
) -> task_created_feedback.Config {
  task_created_feedback.Config(
    locale: model.ui.locale,
    visibility: model.member.pool.member_pool_visibility,
    work_filters: available_tasks.Config(
      tasks: model.member.pool.member_tasks,
      task_types: model.member.pool.member_task_types,
      my_capability_ids: model.member.skills.member_my_capability_ids,
      type_filter: model.member.pool.member_filters_type_id,
      capability_filter: model.member.pool.member_filters_capability_id,
      search_query: model.member.pool.member_filters_q,
      capability_scope: model.member.pool.member_capability_scope,
      visibility: model.member.pool.member_pool_visibility,
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

fn task_create_context(
  model: client_state.Model,
) -> task_create_update.Context(client_state.Msg) {
  task_create_update.Context(
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
    card_has_child_cards: i18n.t(
      model.ui.locale,
      i18n_text.TaskCreateCardHasChildCards,
    ),
    parent_card_conflict: i18n.t(
      model.ui.locale,
      i18n_text.TaskCreateParentCardConflict,
    ),
  )
}

fn note_context(
  model: client_state.Model,
) -> task_notes_update.Context(client_state.Msg) {
  task_notes_update.Context(
    content_required: i18n.t(model.ui.locale, i18n_text.ContentRequired),
    note_added: i18n.t(model.ui.locale, i18n_text.NoteAdded),
    on_note_added: fn(result) {
      client_state.pool_msg(pool_messages.MemberNoteAdded(result))
    },
    on_note_deleted: fn(note_id, result) {
      client_state.pool_msg(pool_messages.MemberNoteDeleted(note_id, result))
    },
    on_note_pinned: fn(note_id, result) {
      client_state.pool_msg(pool_messages.MemberNotePinned(note_id, result))
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
    selected_task: selected_task_show(model),
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

fn task_show_dispatch_context(
  model: client_state.Model,
) -> task_show_update.DispatchContext(client_state.Msg) {
  task_show_update.DispatchContext(
    open_context: task_show_context(),
    edit_context: task_show_edit_context(model),
    success_context: task_show_update_success_context(model),
    error_context: task_show_update_error_context(),
  )
}

fn task_show_context() -> task_show_update.Context(client_state.Msg) {
  task_show_update.Context(
    on_notes_fetched: fn(result) {
      client_state.pool_msg(pool_messages.MemberNotesFetched(result))
    },
    on_dependencies_fetched: fn(result) {
      client_state.pool_msg(pool_messages.MemberDependenciesFetched(result))
    },
    on_activity_fetched: fn(result) {
      client_state.pool_msg(pool_messages.MemberActivityFetched(result))
    },
  )
}

fn task_show_edit_context(
  model: client_state.Model,
) -> task_show_update.EditContext(client_state.Msg) {
  let maybe_task = selected_task_show(model)
  let can_edit = case maybe_task {
    opt.Some(current_task) -> can_edit_selected_task(model, current_task)
    opt.None -> False
  }

  task_show_update.EditContext(
    current_task: maybe_task,
    can_edit: can_edit,
    on_task_updated: fn(result) {
      client_state.pool_msg(pool_messages.MemberTaskUpdated(result))
    },
    title_required: i18n.t(model.ui.locale, i18n_text.TitleRequired),
    title_too_long_max_56: i18n.t(model.ui.locale, i18n_text.TitleTooLongMax56),
    type_required: i18n.t(model.ui.locale, i18n_text.TypeRequired),
    priority_must_be_1_to_5: i18n.t(
      model.ui.locale,
      i18n_text.PriorityMustBe1To5,
    ),
  )
}

fn task_show_update_success_context(
  model: client_state.Model,
) -> task_show_update.SuccessContext(client_state.Msg) {
  task_show_update.SuccessContext(
    task_updated: i18n.t(model.ui.locale, i18n_text.TaskUpdated),
    on_success_toast: app_effects.toast_success,
  )
}

fn task_show_update_error_context() -> task_show_update.ErrorContext(
  client_state.Msg,
) {
  task_show_update.ErrorContext(
    on_warning_toast: app_effects.toast_warning,
    on_error_toast: app_effects.toast_error,
  )
}

fn task_mutation_dispatch_context(
  model: client_state.Model,
) -> task_mutation_update.DispatchContext(client_state.Msg) {
  task_mutation_update.DispatchContext(
    mutation_context: mutation_context(model),
    success_context: task_mutation_success_context(model),
    error_context: task_mutation_error_context(model),
  )
}

pub fn mutation_context(
  model: client_state.Model,
) -> task_mutation_update.MutationContext(client_state.Msg) {
  task_mutation_update.MutationContext(
    current_user_id: selected_user_id(model),
    on_task_claimed: fn(result) {
      client_state.pool_msg(pool_messages.MemberTaskClaimed(result))
    },
    on_task_released: fn(result) {
      client_state.pool_msg(pool_messages.MemberTaskReleased(result))
    },
    on_task_closed: fn(result) {
      client_state.pool_msg(pool_messages.MemberTaskClosed(result))
    },
    on_task_deleted: fn(task_id, result) {
      client_state.pool_msg(pool_messages.MemberTaskDeleted(task_id, result))
    },
  )
}

fn task_mutation_success_context(
  model: client_state.Model,
) -> task_mutation_update.Context(client_state.Msg) {
  task_mutation_update.Context(
    task_claimed: i18n.t(model.ui.locale, i18n_text.TaskClaimed),
    task_released: i18n.t(model.ui.locale, i18n_text.TaskReleased),
    task_closed: i18n.t(model.ui.locale, i18n_text.TaskDone),
    task_deleted: i18n.t(model.ui.locale, i18n_text.TaskDeleted),
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
      task_blocked_by_dependencies: i18n.t(
        model.ui.locale,
        i18n_text.TaskBlockedByDependencies,
      ),
      task_has_operational_history: i18n.t(
        model.ui.locale,
        i18n_text.TaskHasOperationalHistory,
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

fn refetch_work_sessions_effect() -> effect.Effect(client_state.Msg) {
  active_api.get_work_sessions(fn(result) {
    client_state.pool_msg(pool_messages.MemberWorkSessionsFetched(result))
  })
}

fn dependencies_model(
  model: client_state.Model,
) -> dependency_workflow.DependenciesModel {
  dependency_workflow.DependenciesModel(
    pool: model.member.pool,
    dependencies: model.member.dependencies,
  )
}

fn set_dependencies_model(
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

fn set_member_notes(
  model: client_state.Model,
  notes: member_notes.Model,
) -> client_state.Model {
  client_state.update_member(model, fn(member) {
    member_state.MemberModel(..member, notes: notes)
  })
}

fn task_show_model(model: client_state.Model) -> task_show_update.Model {
  task_show_update.Model(
    pool: model.member.pool,
    notes: model.member.notes,
    dependencies: model.member.dependencies,
  )
}

fn set_task_show_model(
  model: client_state.Model,
  local: task_show_update.Model,
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

fn selected_task_show(model: client_state.Model) -> opt.Option(task.Task) {
  case model.member.notes.member_notes_task_id {
    opt.Some(task_id) ->
      helpers_lookup.find_task_by_id_in_cache(
        model.member.pool.member_tasks,
        model.member.pool.member_tasks_by_project,
        task_id,
      )
    opt.None -> opt.None
  }
}

fn can_edit_selected_task(
  model: client_state.Model,
  current_task: task.Task,
) -> Bool {
  show_permissions.can_edit(selected_user_id(model), current_task)
}

fn selected_user_id(model: client_state.Model) -> opt.Option(Int) {
  model.core.user
  |> opt.map(fn(user) { user.id })
}
