import gleam/list
import gleam/option as opt
import gleam/string

import lustre/effect

import domain/api_error.{type ApiError, type ApiResult, ApiError}
import domain/card.{type Card}
import domain/milestone
import domain/remote.{Loaded}
import domain/task.{type Task}
import scrumbringer_client/api/cards as api_cards
import scrumbringer_client/api/milestones as api_milestones
import scrumbringer_client/api/tasks/operations as task_operations_api
import scrumbringer_client/app/effects as app_effects
import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/milestones/dialog_helpers
import scrumbringer_client/features/milestones/error_codes
import scrumbringer_client/features/milestones/ids as milestone_ids
import scrumbringer_client/features/milestones/refresh as milestone_refresh
import scrumbringer_client/features/pool/msg as pool_messages

pub type Context(parent_msg) {
  Context(
    selected_project_id: opt.Option(Int),
    on_milestone_activated: fn(Int, ApiResult(Nil)) -> parent_msg,
    on_milestone_created: fn(ApiResult(milestone.Milestone)) -> parent_msg,
    on_milestone_updated: fn(ApiResult(milestone.Milestone)) -> parent_msg,
    on_milestone_deleted: fn(Int, ApiResult(Nil)) -> parent_msg,
    on_milestone_card_moved: fn(ApiResult(Card)) -> parent_msg,
    on_milestone_task_moved: fn(ApiResult(Task)) -> parent_msg,
    name_required: String,
    select_project_first: String,
  )
}

pub type Success {
  MilestoneActivated
  MilestoneCreated
  MilestoneUpdated
  MilestoneDeleted
}

pub type Failure {
  MilestoneActivateFailed
  MilestoneCreateFailed
  MilestoneUpdateFailed
  MilestoneDeleteFailed
}

pub type FeedbackContext(parent_msg) {
  FeedbackContext(
    milestone_activated: String,
    milestone_created: String,
    milestone_updated: String,
    milestone_deleted: String,
    milestone_activate_failed: String,
    milestone_create_failed: String,
    milestone_update_failed: String,
    milestone_delete_failed: String,
    milestone_already_active: String,
    milestone_activation_irreversible: String,
    milestone_delete_not_allowed: String,
    on_success_toast: fn(String) -> effect.Effect(parent_msg),
    on_error_toast: fn(String) -> effect.Effect(parent_msg),
  )
}

pub type Update(parent_msg) {
  Update(
    member_pool.Model,
    effect.Effect(parent_msg),
    RefreshPolicy,
    RootPolicy,
  )
}

pub type RefreshPolicy {
  NoRefresh
  RefreshWithSuccess(Success)
}

pub type RootPolicy {
  NoRootPolicy
  OpenCardForMilestone(Int)
}

pub fn handle_milestone_activate_prompt_clicked(
  model: member_pool.Model,
  milestone_id: Int,
) -> #(member_pool.Model, effect.Effect(parent_msg)) {
  #(
    member_pool.Model(
      ..model,
      member_milestone_dialog: member_pool.MilestoneDialogActivate(milestone_id),
      member_milestone_dialog_in_flight: False,
      member_milestone_dialog_error: opt.None,
    ),
    effect.none(),
  )
}

pub fn handle_milestone_activate_clicked(
  model: member_pool.Model,
  milestone_id: Int,
  context: Context(parent_msg),
) -> #(member_pool.Model, effect.Effect(parent_msg)) {
  #(
    member_pool.Model(
      ..model,
      member_milestone_dialog: member_pool.MilestoneDialogActivate(milestone_id),
      member_milestone_activate_in_flight_id: opt.Some(milestone_id),
      member_milestone_dialog_in_flight: True,
    ),
    api_milestones.activate_milestone(milestone_id, fn(result) {
      context.on_milestone_activated(milestone_id, result)
    }),
  )
}

pub fn handle_milestone_activated_ok(
  model: member_pool.Model,
) -> #(member_pool.Model, effect.Effect(parent_msg)) {
  #(
    member_pool.Model(
      ..model,
      member_milestone_dialog: member_pool.MilestoneDialogClosed,
      member_milestone_activate_in_flight_id: opt.None,
      member_milestone_dialog_in_flight: False,
      member_milestone_dialog_error: opt.None,
    ),
    effect.none(),
  )
}

pub fn handle_milestone_activated_error(
  model: member_pool.Model,
  message: String,
) -> #(member_pool.Model, effect.Effect(parent_msg)) {
  #(
    member_pool.Model(
      ..model,
      member_milestone_activate_in_flight_id: opt.None,
      member_milestone_dialog_in_flight: False,
      member_milestone_dialog_error: opt.Some(message),
    ),
    effect.none(),
  )
}

pub fn handle_milestone_edit_clicked(
  model: member_pool.Model,
  milestone_id: Int,
) -> #(member_pool.Model, effect.Effect(parent_msg)) {
  let dialog =
    dialog_helpers.find_milestone_dialog(
      model.member_milestones,
      milestone_id,
      fn(m) {
        member_pool.MilestoneDialogEdit(
          id: m.id,
          name: m.name,
          description: milestone_description_input(m.description),
        )
      },
    )
    |> milestone_dialog_or_closed

  #(open_milestone_dialog(model, dialog), effect.none())
}

pub fn handle_milestone_delete_clicked(
  model: member_pool.Model,
  milestone_id: Int,
) -> #(member_pool.Model, effect.Effect(parent_msg)) {
  let dialog =
    dialog_helpers.find_milestone_dialog(
      model.member_milestones,
      milestone_id,
      fn(m) { member_pool.MilestoneDialogDelete(id: m.id, name: m.name) },
    )
    |> milestone_dialog_or_closed

  #(open_milestone_dialog(model, dialog), effect.none())
}

pub fn handle_milestone_dialog_closed(
  model: member_pool.Model,
) -> #(member_pool.Model, effect.Effect(parent_msg)) {
  let focus_target = dialog_focus_target(model.member_milestone_dialog)

  #(
    member_pool.Model(
      ..model,
      member_milestone_dialog: member_pool.MilestoneDialogClosed,
      member_milestone_dialog_in_flight: False,
      member_milestone_dialog_error: opt.None,
    ),
    case focus_target {
      opt.Some(element_id) ->
        app_effects.focus_element_after_timeout(element_id, 0)
      opt.None -> effect.none()
    },
  )
}

pub fn handle_milestone_name_changed(
  model: member_pool.Model,
  name: String,
) -> #(member_pool.Model, effect.Effect(parent_msg)) {
  let next_dialog = case model.member_milestone_dialog {
    member_pool.MilestoneDialogCreate(description: description, ..) ->
      member_pool.MilestoneDialogCreate(name: name, description: description)
    member_pool.MilestoneDialogEdit(id: id, description: description, ..) ->
      member_pool.MilestoneDialogEdit(
        id: id,
        name: name,
        description: description,
      )
    other -> other
  }

  #(
    member_pool.Model(
      ..model,
      member_milestone_dialog: next_dialog,
      member_milestone_dialog_error: opt.None,
    ),
    effect.none(),
  )
}

pub fn handle_milestone_description_changed(
  model: member_pool.Model,
  description: String,
) -> #(member_pool.Model, effect.Effect(parent_msg)) {
  let next_dialog = case model.member_milestone_dialog {
    member_pool.MilestoneDialogCreate(name: name, ..) ->
      member_pool.MilestoneDialogCreate(name: name, description: description)
    member_pool.MilestoneDialogEdit(id: id, name: name, ..) ->
      member_pool.MilestoneDialogEdit(
        id: id,
        name: name,
        description: description,
      )
    other -> other
  }

  #(
    member_pool.Model(
      ..model,
      member_milestone_dialog: next_dialog,
      member_milestone_dialog_error: opt.None,
    ),
    effect.none(),
  )
}

pub fn handle_milestone_create_submitted(
  model: member_pool.Model,
  context: Context(parent_msg),
) -> #(member_pool.Model, effect.Effect(parent_msg)) {
  case model.member_milestone_dialog {
    member_pool.MilestoneDialogCreate(name: name, description: description) ->
      submit_milestone_create(model, name, description, context)
    _ -> #(model, effect.none())
  }
}

fn submit_milestone_create(
  model: member_pool.Model,
  name: String,
  description: String,
  context: Context(parent_msg),
) -> #(member_pool.Model, effect.Effect(parent_msg)) {
  let normalized_name = string.trim(name)

  case name, context.selected_project_id, normalized_name {
    "", _, _ -> #(
      set_milestone_dialog_error(model, context.name_required),
      effect.none(),
    )
    _, opt.None, _ -> #(
      set_milestone_dialog_error(model, context.select_project_first),
      effect.none(),
    )
    _, opt.Some(_), "" -> #(
      set_milestone_dialog_error(model, context.name_required),
      effect.none(),
    )
    _, opt.Some(project_id), _ -> {
      let model =
        member_pool.Model(
          ..model,
          member_milestone_dialog_in_flight: True,
          member_milestone_dialog_error: opt.None,
        )

      #(
        model,
        api_milestones.create_milestone(
          project_id,
          normalized_name,
          description,
          context.on_milestone_created,
        ),
      )
    }
  }
}

pub fn handle_milestone_created_ok(
  model: member_pool.Model,
  created: milestone.Milestone,
) -> #(member_pool.Model, effect.Effect(parent_msg)) {
  #(
    member_pool.Model(
      ..model,
      member_milestone_dialog: member_pool.MilestoneDialogClosed,
      member_milestone_dialog_in_flight: False,
      member_milestone_dialog_error: opt.None,
      member_selected_milestone_id: opt.Some(created.id),
    ),
    effect.none(),
  )
}

pub fn handle_milestone_created_error(
  model: member_pool.Model,
  message: String,
) -> #(member_pool.Model, effect.Effect(parent_msg)) {
  #(
    member_pool.Model(
      ..model,
      member_milestone_dialog_in_flight: False,
      member_milestone_dialog_error: opt.Some(message),
    ),
    effect.none(),
  )
}

pub fn handle_milestone_edit_submitted(
  model: member_pool.Model,
  milestone_id: Int,
  context: Context(parent_msg),
) -> #(member_pool.Model, effect.Effect(parent_msg)) {
  case model.member_milestone_dialog {
    member_pool.MilestoneDialogEdit(name: name, description: description, ..) -> {
      let model =
        member_pool.Model(
          ..model,
          member_milestone_dialog_in_flight: True,
          member_milestone_dialog_error: opt.None,
        )

      #(
        model,
        api_milestones.update_milestone(
          milestone_id,
          name,
          description,
          context.on_milestone_updated,
        ),
      )
    }
    _ -> #(model, effect.none())
  }
}

pub fn handle_milestone_delete_submitted(
  model: member_pool.Model,
  milestone_id: Int,
  context: Context(parent_msg),
) -> #(member_pool.Model, effect.Effect(parent_msg)) {
  let model =
    member_pool.Model(
      ..model,
      member_milestone_dialog_in_flight: True,
      member_milestone_dialog_error: opt.None,
    )

  #(
    model,
    api_milestones.delete_milestone(milestone_id, fn(result) {
      context.on_milestone_deleted(milestone_id, result)
    }),
  )
}

pub fn handle_milestone_updated_ok(
  model: member_pool.Model,
) -> #(member_pool.Model, effect.Effect(parent_msg)) {
  #(
    member_pool.Model(
      ..model,
      member_milestone_dialog: member_pool.MilestoneDialogClosed,
      member_milestone_dialog_in_flight: False,
      member_milestone_dialog_error: opt.None,
    ),
    effect.none(),
  )
}

pub fn handle_milestone_updated_error(
  model: member_pool.Model,
  message: String,
) -> #(member_pool.Model, effect.Effect(parent_msg)) {
  #(
    member_pool.Model(
      ..model,
      member_milestone_dialog_in_flight: False,
      member_milestone_dialog_error: opt.Some(message),
    ),
    effect.none(),
  )
}

pub fn handle_milestone_deleted_ok(
  model: member_pool.Model,
  milestone_id: Int,
) -> #(member_pool.Model, effect.Effect(parent_msg)) {
  #(
    member_pool.Model(
      ..model,
      member_milestone_dialog: member_pool.MilestoneDialogClosed,
      member_milestone_dialog_in_flight: False,
      member_milestone_dialog_error: opt.None,
      member_selected_milestone_id: case model.member_selected_milestone_id {
        opt.Some(selected_id) if selected_id == milestone_id -> opt.None
        other -> other
      },
    ),
    effect.none(),
  )
}

pub fn handle_milestone_deleted_error(
  model: member_pool.Model,
  message: String,
) -> #(member_pool.Model, effect.Effect(parent_msg)) {
  #(
    member_pool.Model(
      ..model,
      member_milestone_dialog_in_flight: False,
      member_milestone_dialog_error: opt.Some(message),
    ),
    effect.none(),
  )
}

pub fn handle_milestones_show_completed_toggled(
  model: member_pool.Model,
) -> #(member_pool.Model, effect.Effect(parent_msg)) {
  #(
    member_pool.Model(
      ..model,
      member_milestones_show_completed: !model.member_milestones_show_completed,
    ),
    effect.none(),
  )
}

pub fn handle_milestones_show_empty_toggled(
  model: member_pool.Model,
) -> #(member_pool.Model, effect.Effect(parent_msg)) {
  #(
    member_pool.Model(
      ..model,
      member_milestones_show_empty: !model.member_milestones_show_empty,
    ),
    effect.none(),
  )
}

pub fn handle_milestone_search_changed(
  model: member_pool.Model,
  query: String,
) -> #(member_pool.Model, effect.Effect(parent_msg)) {
  #(
    member_pool.Model(..model, member_milestones_search_query: query),
    effect.none(),
  )
}

pub fn handle_milestone_summary_toggled(
  model: member_pool.Model,
) -> #(member_pool.Model, effect.Effect(parent_msg)) {
  #(
    member_pool.Model(
      ..model,
      member_milestone_summary_expanded: !model.member_milestone_summary_expanded,
    ),
    effect.none(),
  )
}

pub fn handle_milestone_details_clicked(
  model: member_pool.Model,
  milestone_id: Int,
) -> #(member_pool.Model, effect.Effect(parent_msg)) {
  #(
    member_pool.Model(
      ..model,
      member_selected_milestone_id: opt.Some(milestone_id),
      member_milestone_dialog_in_flight: False,
      member_milestone_dialog_error: opt.None,
    ),
    effect.none(),
  )
}

pub fn handle_milestone_create_task_clicked(
  model: member_pool.Model,
  milestone_id: Int,
) -> #(member_pool.Model, effect.Effect(parent_msg)) {
  #(
    member_pool.Model(
      ..model,
      member_milestone_dialog: member_pool.MilestoneDialogClosed,
      member_milestone_dialog_in_flight: False,
      member_milestone_dialog_error: opt.None,
      member_create_dialog_mode: dialog_mode.DialogCreate,
      member_create_card_id: opt.None,
      member_create_milestone_id: opt.Some(milestone_id),
    ),
    effect.none(),
  )
}

pub fn handle_milestone_create_clicked(
  model: member_pool.Model,
) -> #(member_pool.Model, effect.Effect(parent_msg)) {
  #(
    member_pool.Model(
      ..model,
      member_milestone_dialog: member_pool.MilestoneDialogCreate(
        name: "",
        description: "",
      ),
      member_milestone_dialog_in_flight: False,
      member_milestone_dialog_error: opt.None,
    ),
    effect.none(),
  )
}

pub fn handle_milestone_card_drag_started(
  model: member_pool.Model,
  card_id: Int,
  from_milestone_id: Int,
) -> #(member_pool.Model, effect.Effect(parent_msg)) {
  #(
    member_pool.Model(
      ..model,
      member_milestone_drag_item: opt.Some(member_pool.MilestoneDragCard(
        card_id,
        from_milestone_id,
      )),
    ),
    effect.none(),
  )
}

pub fn handle_milestone_task_drag_started(
  model: member_pool.Model,
  task_id: Int,
  from_milestone_id: Int,
) -> #(member_pool.Model, effect.Effect(parent_msg)) {
  #(
    member_pool.Model(
      ..model,
      member_milestone_drag_item: opt.Some(member_pool.MilestoneDragTask(
        task_id,
        from_milestone_id,
      )),
    ),
    effect.none(),
  )
}

pub fn handle_milestone_drag_ended(
  model: member_pool.Model,
) -> #(member_pool.Model, effect.Effect(parent_msg)) {
  #(
    member_pool.Model(..model, member_milestone_drag_item: opt.None),
    effect.none(),
  )
}

fn open_milestone_dialog(
  model: member_pool.Model,
  dialog: member_pool.MilestoneDialog,
) -> member_pool.Model {
  member_pool.Model(
    ..model,
    member_milestone_dialog: dialog,
    member_milestone_dialog_in_flight: False,
    member_milestone_dialog_error: opt.None,
  )
}

fn set_milestone_dialog_error(
  model: member_pool.Model,
  message: String,
) -> member_pool.Model {
  member_pool.Model(..model, member_milestone_dialog_error: opt.Some(message))
}

pub fn try_member_pool_update(
  model: member_pool.Model,
  inner: pool_messages.Msg,
  context: Context(parent_msg),
  feedback: FeedbackContext(parent_msg),
) -> opt.Option(Update(parent_msg)) {
  case inner {
    pool_messages.MemberProjectMilestonesFetched(project_id, Ok(milestones)) -> {
      let milestone_refresh.ProjectFetched(
        milestones_store: next_store,
        milestones: next_milestones,
        selected_milestone_id: next_selected,
      ) =
        milestone_refresh.project_fetched(
          model.member_milestones_store,
          model.member_milestones,
          model.member_selected_milestone_id,
          project_id,
          milestones,
        )

      opt.Some(Update(
        member_pool.Model(
          ..model,
          member_milestones_store: next_store,
          member_milestones: next_milestones,
          member_selected_milestone_id: next_selected,
        ),
        effect.none(),
        NoRefresh,
        NoRootPolicy,
      ))
    }

    pool_messages.MemberProjectMilestonesFetched(_project_id, Error(err)) -> {
      let #(next_store, next_milestones) =
        milestone_refresh.project_failed(
          model.member_milestones_store,
          model.member_milestones,
          err,
        )

      opt.Some(Update(
        member_pool.Model(
          ..model,
          member_milestones_store: next_store,
          member_milestones: next_milestones,
        ),
        effect.none(),
        NoRefresh,
        NoRootPolicy,
      ))
    }

    pool_messages.MemberMilestonesShowCompletedToggled ->
      try_local_transition(model, handle_milestones_show_completed_toggled)

    pool_messages.MemberMilestonesShowEmptyToggled ->
      try_local_transition(model, handle_milestones_show_empty_toggled)

    pool_messages.MemberMilestoneSearchChanged(query) ->
      try_local_transition(model, fn(pool) {
        handle_milestone_search_changed(pool, query)
      })

    pool_messages.MemberMilestoneSummaryToggled ->
      try_local_transition(model, handle_milestone_summary_toggled)

    pool_messages.MemberMilestoneDetailsClicked(milestone_id) -> {
      let #(next, local_fx) =
        handle_milestone_details_clicked(model, milestone_id)

      opt.Some(Update(next, local_fx, NoRefresh, NoRootPolicy))
    }

    pool_messages.MemberMilestoneCreateTaskClicked(milestone_id) ->
      try_local_transition(model, fn(pool) {
        handle_milestone_create_task_clicked(pool, milestone_id)
      })

    pool_messages.MemberMilestoneCreateCardClicked(milestone_id) ->
      opt.Some(Update(
        member_pool.Model(
          ..model,
          member_milestone_dialog: member_pool.MilestoneDialogClosed,
          member_milestone_dialog_in_flight: False,
          member_milestone_dialog_error: opt.None,
        ),
        effect.none(),
        NoRefresh,
        OpenCardForMilestone(milestone_id),
      ))

    pool_messages.MemberMilestoneCreateClicked ->
      try_local_transition(model, handle_milestone_create_clicked)

    pool_messages.MemberMilestoneCardDragStarted(card_id, from_milestone_id) ->
      try_local_transition(model, fn(pool) {
        handle_milestone_card_drag_started(pool, card_id, from_milestone_id)
      })

    pool_messages.MemberMilestoneTaskDragStarted(task_id, from_milestone_id) ->
      try_local_transition(model, fn(pool) {
        handle_milestone_task_drag_started(pool, task_id, from_milestone_id)
      })

    pool_messages.MemberMilestoneDragEnded ->
      try_local_transition(model, handle_milestone_drag_ended)

    pool_messages.MemberMilestoneActivatePromptClicked(milestone_id) ->
      try_local_transition(model, fn(pool) {
        handle_milestone_activate_prompt_clicked(pool, milestone_id)
      })

    pool_messages.MemberMilestoneActivateClicked(milestone_id) ->
      try_local_transition(model, fn(pool) {
        handle_milestone_activate_clicked(pool, milestone_id, context)
      })

    pool_messages.MemberMilestoneEditClicked(milestone_id) ->
      try_local_transition(model, fn(pool) {
        handle_milestone_edit_clicked(pool, milestone_id)
      })

    pool_messages.MemberMilestoneDeleteClicked(milestone_id) ->
      try_local_transition(model, fn(pool) {
        handle_milestone_delete_clicked(pool, milestone_id)
      })

    pool_messages.MemberMilestoneDialogClosed ->
      try_local_transition(model, handle_milestone_dialog_closed)

    pool_messages.MemberMilestoneNameChanged(name) ->
      try_local_transition(model, fn(pool) {
        handle_milestone_name_changed(pool, name)
      })

    pool_messages.MemberMilestoneDescriptionChanged(description) ->
      try_local_transition(model, fn(pool) {
        handle_milestone_description_changed(pool, description)
      })

    pool_messages.MemberMilestoneCreateSubmitted ->
      try_local_transition(model, fn(pool) {
        handle_milestone_create_submitted(pool, context)
      })

    pool_messages.MemberMilestoneEditSubmitted(milestone_id) ->
      try_local_transition(model, fn(pool) {
        handle_milestone_edit_submitted(pool, milestone_id, context)
      })

    pool_messages.MemberMilestoneDeleteSubmitted(milestone_id) ->
      try_local_transition(model, fn(pool) {
        handle_milestone_delete_submitted(pool, milestone_id, context)
      })

    pool_messages.MemberMilestoneDroppedOn(to_milestone_id) ->
      opt.Some(handle_milestone_dropped_on(model, to_milestone_id, context))

    pool_messages.MemberMilestoneCardMoveClicked(
      card_id,
      from_milestone_id,
      to_milestone_id,
    ) ->
      opt.Some(handle_milestone_card_move_clicked(
        model,
        card_id,
        from_milestone_id,
        to_milestone_id,
        context,
      ))

    pool_messages.MemberMilestoneTaskMoveClicked(
      task_id,
      from_milestone_id,
      to_milestone_id,
    ) ->
      opt.Some(handle_milestone_task_move_clicked(
        model,
        task_id,
        from_milestone_id,
        to_milestone_id,
        context,
      ))

    pool_messages.MemberMilestoneCardMoved(Ok(_))
    | pool_messages.MemberMilestoneTaskMoved(Ok(_)) ->
      opt.Some(Update(
        model,
        effect.none(),
        RefreshWithSuccess(MilestoneUpdated),
        NoRootPolicy,
      ))

    pool_messages.MemberMilestoneCardMoved(Error(err))
    | pool_messages.MemberMilestoneTaskMoved(Error(err)) ->
      opt.Some(Update(
        model,
        error_effect(err, MilestoneUpdateFailed, feedback),
        NoRefresh,
        NoRootPolicy,
      ))

    pool_messages.MemberMilestoneActivated(_milestone_id, Ok(_)) ->
      try_local_transition_with_refresh(
        model,
        handle_milestone_activated_ok,
        RefreshWithSuccess(MilestoneActivated),
      )

    pool_messages.MemberMilestoneActivated(_milestone_id, Error(err)) -> {
      let message = error_message(err, MilestoneActivateFailed, feedback)
      try_local_transition(model, fn(pool) {
        let #(next, local_fx) = handle_milestone_activated_error(pool, message)
        #(next, effect.batch([local_fx, feedback.on_error_toast(message)]))
      })
    }

    pool_messages.MemberMilestoneCreated(Ok(milestone)) -> {
      let #(next, local_fx) = handle_milestone_created_ok(model, milestone)
      opt.Some(Update(
        next,
        local_fx,
        RefreshWithSuccess(MilestoneCreated),
        NoRootPolicy,
      ))
    }

    pool_messages.MemberMilestoneCreated(Error(err)) -> {
      let message = error_message(err, MilestoneCreateFailed, feedback)
      try_local_transition(model, fn(pool) {
        let #(next, local_fx) = handle_milestone_created_error(pool, message)
        #(next, effect.batch([local_fx, feedback.on_error_toast(message)]))
      })
    }

    pool_messages.MemberMilestoneUpdated(Ok(_)) ->
      try_local_transition_with_refresh(
        model,
        handle_milestone_updated_ok,
        RefreshWithSuccess(MilestoneUpdated),
      )

    pool_messages.MemberMilestoneUpdated(Error(err)) -> {
      let message = error_message(err, MilestoneUpdateFailed, feedback)
      try_local_transition(model, fn(pool) {
        let #(next, local_fx) = handle_milestone_updated_error(pool, message)
        #(next, effect.batch([local_fx, feedback.on_error_toast(message)]))
      })
    }

    pool_messages.MemberMilestoneDeleted(milestone_id, Ok(_)) ->
      try_local_transition_with_refresh(
        model,
        fn(pool) { handle_milestone_deleted_ok(pool, milestone_id) },
        RefreshWithSuccess(MilestoneDeleted),
      )

    pool_messages.MemberMilestoneDeleted(_milestone_id, Error(err)) -> {
      let message = error_message(err, MilestoneDeleteFailed, feedback)
      try_local_transition(model, fn(pool) {
        let #(next, local_fx) = handle_milestone_deleted_error(pool, message)
        #(next, effect.batch([local_fx, feedback.on_error_toast(message)]))
      })
    }

    _ -> opt.None
  }
}

fn try_local_transition(
  model: member_pool.Model,
  transition: fn(member_pool.Model) ->
    #(member_pool.Model, effect.Effect(parent_msg)),
) -> opt.Option(Update(parent_msg)) {
  let #(next, fx) = transition(model)
  opt.Some(Update(next, fx, NoRefresh, NoRootPolicy))
}

fn try_local_transition_with_refresh(
  model: member_pool.Model,
  transition: fn(member_pool.Model) ->
    #(member_pool.Model, effect.Effect(parent_msg)),
  refresh_policy: RefreshPolicy,
) -> opt.Option(Update(parent_msg)) {
  let #(next, fx) = transition(model)
  opt.Some(Update(next, fx, refresh_policy, NoRootPolicy))
}

fn handle_milestone_dropped_on(
  model: member_pool.Model,
  to_milestone_id: Int,
  context: Context(parent_msg),
) -> Update(parent_msg) {
  let maybe_drag = model.member_milestone_drag_item
  let model = member_pool.Model(..model, member_milestone_drag_item: opt.None)

  case maybe_drag {
    opt.Some(member_pool.MilestoneDragCard(card_id, from_milestone_id)) ->
      update_moved_card(
        model,
        card_id,
        from_milestone_id,
        to_milestone_id,
        context,
      )

    opt.Some(member_pool.MilestoneDragTask(task_id, from_milestone_id)) ->
      case
        can_move_between_ready_milestones(
          model,
          from_milestone_id,
          to_milestone_id,
        )
      {
        True ->
          Update(
            model,
            task_operations_api.update_task_milestone(
              task_id,
              opt.Some(to_milestone_id),
              context.on_milestone_task_moved,
            ),
            NoRefresh,
            NoRootPolicy,
          )
        False -> Update(model, effect.none(), NoRefresh, NoRootPolicy)
      }

    opt.None -> Update(model, effect.none(), NoRefresh, NoRootPolicy)
  }
}

fn handle_milestone_card_move_clicked(
  model: member_pool.Model,
  card_id: Int,
  from_milestone_id: Int,
  to_milestone_id: Int,
  context: Context(parent_msg),
) -> Update(parent_msg) {
  update_moved_card(model, card_id, from_milestone_id, to_milestone_id, context)
}

fn update_moved_card(
  model: member_pool.Model,
  card_id: Int,
  from_milestone_id: Int,
  to_milestone_id: Int,
  context: Context(parent_msg),
) -> Update(parent_msg) {
  case
    can_move_between_ready_milestones(model, from_milestone_id, to_milestone_id),
    card_in_milestone(model, card_id, from_milestone_id)
  {
    True, opt.Some(card) ->
      Update(
        model,
        api_cards.update_card(
          card.id,
          card.title,
          card.description,
          card.color,
          opt.Some(to_milestone_id),
          context.on_milestone_card_moved,
        ),
        NoRefresh,
        NoRootPolicy,
      )
    _, _ -> Update(model, effect.none(), NoRefresh, NoRootPolicy)
  }
}

fn handle_milestone_task_move_clicked(
  model: member_pool.Model,
  task_id: Int,
  from_milestone_id: Int,
  to_milestone_id: Int,
  context: Context(parent_msg),
) -> Update(parent_msg) {
  case
    can_move_between_ready_milestones(model, from_milestone_id, to_milestone_id)
    && task_in_milestone(model, task_id, from_milestone_id)
  {
    True ->
      Update(
        model,
        task_operations_api.update_task_milestone(
          task_id,
          opt.Some(to_milestone_id),
          context.on_milestone_task_moved,
        ),
        NoRefresh,
        NoRootPolicy,
      )
    False -> Update(model, effect.none(), NoRefresh, NoRootPolicy)
  }
}

fn card_in_milestone(
  model: member_pool.Model,
  card_id: Int,
  milestone_id: Int,
) -> opt.Option(Card) {
  case model.member_cards {
    Loaded(cards) ->
      list.find(cards, fn(card) {
        card.id == card_id && card.milestone_id == opt.Some(milestone_id)
      })
      |> opt.from_result
    _ -> opt.None
  }
}

fn task_in_milestone(
  model: member_pool.Model,
  task_id: Int,
  milestone_id: Int,
) -> Bool {
  case model.member_tasks {
    Loaded(tasks) ->
      tasks
      |> list.any(fn(task) {
        task.id == task_id && task.milestone_id == opt.Some(milestone_id)
      })
    _ -> False
  }
}

fn can_move_between_ready_milestones(
  model: member_pool.Model,
  from_milestone_id: Int,
  to_milestone_id: Int,
) -> Bool {
  from_milestone_id != to_milestone_id
  && is_ready_milestone(model, from_milestone_id)
  && is_ready_milestone(model, to_milestone_id)
}

fn is_ready_milestone(model: member_pool.Model, milestone_id: Int) -> Bool {
  case model.member_milestones {
    Loaded(items) ->
      items
      |> list.any(fn(progress) {
        progress.milestone.id == milestone_id
        && progress.milestone.state == milestone.Ready
      })
    _ -> False
  }
}

pub fn success_effect(
  success: Success,
  feedback: FeedbackContext(parent_msg),
) -> effect.Effect(parent_msg) {
  let message = case success {
    MilestoneActivated -> feedback.milestone_activated
    MilestoneCreated -> feedback.milestone_created
    MilestoneUpdated -> feedback.milestone_updated
    MilestoneDeleted -> feedback.milestone_deleted
  }

  feedback.on_success_toast(message)
}

pub fn error_effect(
  err: ApiError,
  failure: Failure,
  feedback: FeedbackContext(parent_msg),
) -> effect.Effect(parent_msg) {
  feedback.on_error_toast(error_message(err, failure, feedback))
}

pub fn error_message(
  err: ApiError,
  failure: Failure,
  feedback: FeedbackContext(parent_msg),
) -> String {
  let ApiError(code: code, message: message, ..) = err

  case error_codes.decode_error_code(code) {
    error_codes.MilestoneAlreadyActive -> feedback.milestone_already_active
    error_codes.MilestoneActivationIrreversible ->
      feedback.milestone_activation_irreversible
    error_codes.MilestoneDeleteNotAllowed ->
      feedback.milestone_delete_not_allowed
    error_codes.UnknownMilestoneErrorCode ->
      case message {
        "" -> fallback_error_message(failure, feedback)
        _ -> message
      }
  }
}

fn fallback_error_message(
  failure: Failure,
  feedback: FeedbackContext(parent_msg),
) -> String {
  case failure {
    MilestoneActivateFailed -> feedback.milestone_activate_failed
    MilestoneCreateFailed -> feedback.milestone_create_failed
    MilestoneUpdateFailed -> feedback.milestone_update_failed
    MilestoneDeleteFailed -> feedback.milestone_delete_failed
  }
}

fn milestone_description_input(description: opt.Option(String)) -> String {
  case description {
    opt.None -> ""
    opt.Some(text) -> text
  }
}

fn milestone_dialog_or_closed(
  dialog: opt.Option(member_pool.MilestoneDialog),
) -> member_pool.MilestoneDialog {
  case dialog {
    opt.None -> member_pool.MilestoneDialogClosed
    opt.Some(value) -> value
  }
}

fn dialog_focus_target(
  dialog: member_pool.MilestoneDialog,
) -> opt.Option(String) {
  case dialog {
    member_pool.MilestoneDialogActivate(id) ->
      opt.Some(milestone_ids.activate_button_id(id))
    member_pool.MilestoneDialogEdit(id: id, ..) ->
      opt.Some(milestone_ids.edit_button_id(id))
    member_pool.MilestoneDialogDelete(id: id, ..) ->
      opt.Some(milestone_ids.delete_button_id(id))
    member_pool.MilestoneDialogCreate(..) ->
      opt.Some(milestone_ids.create_button_id())
    member_pool.MilestoneDialogClosed -> opt.None
  }
}
