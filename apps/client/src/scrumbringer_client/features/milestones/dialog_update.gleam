//// Milestone dialog workflow for member-pool updates.

import gleam/option as opt
import gleam/string

import lustre/effect

import domain/milestone
import scrumbringer_client/api/milestones as api_milestones
import scrumbringer_client/app/effects as app_effects
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/milestones/dialog_helpers
import scrumbringer_client/features/milestones/ids as milestone_ids
import scrumbringer_client/features/milestones/update as milestone_update
import scrumbringer_client/features/pool/msg as pool_messages

pub fn try_update(
  model: member_pool.Model,
  inner: pool_messages.Msg,
  context: milestone_update.Context(parent_msg),
  feedback: milestone_update.FeedbackContext(parent_msg),
) -> opt.Option(milestone_update.Update(parent_msg)) {
  case inner {
    pool_messages.MemberMilestoneCreateClicked ->
      try_local_transition(model, handle_milestone_create_clicked)

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

    pool_messages.MemberMilestoneActivated(_milestone_id, Ok(_)) ->
      try_local_transition_with_refresh(
        model,
        handle_milestone_activated_ok,
        milestone_update.RefreshWithSuccess(milestone_update.MilestoneActivated),
      )

    pool_messages.MemberMilestoneActivated(_milestone_id, Error(err)) -> {
      let message =
        milestone_update.error_message(
          err,
          milestone_update.MilestoneActivateFailed,
          feedback,
        )
      try_local_transition(model, fn(pool) {
        let #(next, local_fx) = handle_milestone_activated_error(pool, message)
        #(next, effect.batch([local_fx, feedback.on_error_toast(message)]))
      })
    }

    pool_messages.MemberMilestoneCreated(Ok(milestone)) -> {
      let #(next, local_fx) = handle_milestone_created_ok(model, milestone)
      opt.Some(milestone_update.Update(
        next,
        local_fx,
        milestone_update.RefreshWithSuccess(milestone_update.MilestoneCreated),
        milestone_update.NoRootPolicy,
      ))
    }

    pool_messages.MemberMilestoneCreated(Error(err)) -> {
      let message =
        milestone_update.error_message(
          err,
          milestone_update.MilestoneCreateFailed,
          feedback,
        )
      try_local_transition(model, fn(pool) {
        let #(next, local_fx) = handle_milestone_created_error(pool, message)
        #(next, effect.batch([local_fx, feedback.on_error_toast(message)]))
      })
    }

    pool_messages.MemberMilestoneUpdated(Ok(_)) ->
      try_local_transition_with_refresh(
        model,
        handle_milestone_updated_ok,
        milestone_update.RefreshWithSuccess(milestone_update.MilestoneUpdated),
      )

    pool_messages.MemberMilestoneUpdated(Error(err)) -> {
      let message =
        milestone_update.error_message(
          err,
          milestone_update.MilestoneUpdateFailed,
          feedback,
        )
      try_local_transition(model, fn(pool) {
        let #(next, local_fx) = handle_milestone_updated_error(pool, message)
        #(next, effect.batch([local_fx, feedback.on_error_toast(message)]))
      })
    }

    pool_messages.MemberMilestoneDeleted(milestone_id, Ok(_)) ->
      try_local_transition_with_refresh(
        model,
        fn(pool) { handle_milestone_deleted_ok(pool, milestone_id) },
        milestone_update.RefreshWithSuccess(milestone_update.MilestoneDeleted),
      )

    pool_messages.MemberMilestoneDeleted(_milestone_id, Error(err)) -> {
      let message =
        milestone_update.error_message(
          err,
          milestone_update.MilestoneDeleteFailed,
          feedback,
        )
      try_local_transition(model, fn(pool) {
        let #(next, local_fx) = handle_milestone_deleted_error(pool, message)
        #(next, effect.batch([local_fx, feedback.on_error_toast(message)]))
      })
    }

    _ -> opt.None
  }
}

fn handle_milestone_activate_prompt_clicked(
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

fn handle_milestone_activate_clicked(
  model: member_pool.Model,
  milestone_id: Int,
  context: milestone_update.Context(parent_msg),
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

fn handle_milestone_activated_ok(
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

fn handle_milestone_activated_error(
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

fn handle_milestone_edit_clicked(
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

fn handle_milestone_delete_clicked(
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

fn handle_milestone_name_changed(
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

fn handle_milestone_description_changed(
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

fn handle_milestone_create_submitted(
  model: member_pool.Model,
  context: milestone_update.Context(parent_msg),
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
  context: milestone_update.Context(parent_msg),
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

fn handle_milestone_created_ok(
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

fn handle_milestone_created_error(
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

fn handle_milestone_edit_submitted(
  model: member_pool.Model,
  milestone_id: Int,
  context: milestone_update.Context(parent_msg),
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

fn handle_milestone_delete_submitted(
  model: member_pool.Model,
  milestone_id: Int,
  context: milestone_update.Context(parent_msg),
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

fn handle_milestone_updated_ok(
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

fn handle_milestone_updated_error(
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

fn handle_milestone_deleted_ok(
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

fn handle_milestone_deleted_error(
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

fn handle_milestone_create_clicked(
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

fn try_local_transition(
  model: member_pool.Model,
  transition: fn(member_pool.Model) ->
    #(member_pool.Model, effect.Effect(parent_msg)),
) -> opt.Option(milestone_update.Update(parent_msg)) {
  let #(next, fx) = transition(model)
  opt.Some(milestone_update.Update(
    next,
    fx,
    milestone_update.NoRefresh,
    milestone_update.NoRootPolicy,
  ))
}

fn try_local_transition_with_refresh(
  model: member_pool.Model,
  transition: fn(member_pool.Model) ->
    #(member_pool.Model, effect.Effect(parent_msg)),
  refresh_policy: milestone_update.RefreshPolicy,
) -> opt.Option(milestone_update.Update(parent_msg)) {
  let #(next, fx) = transition(model)
  opt.Some(milestone_update.Update(
    next,
    fx,
    refresh_policy,
    milestone_update.NoRootPolicy,
  ))
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
