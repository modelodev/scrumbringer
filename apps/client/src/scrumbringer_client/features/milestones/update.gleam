import gleam/dict
import gleam/option as opt

import lustre/effect

import domain/api_error.{type ApiError, ApiError}
import domain/milestone
import domain/remote.{Failed, Loaded}
import scrumbringer_client/api/milestones as api_milestones
import scrumbringer_client/app/effects as app_effects
import scrumbringer_client/client_state
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/milestones/dialog_helpers
import scrumbringer_client/features/milestones/error_codes
import scrumbringer_client/features/milestones/ids as milestone_ids
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/helpers/i18n as helpers_i18n
import scrumbringer_client/helpers/toast as helpers_toast
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/state/normalized_store

pub fn try_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case inner {
    pool_messages.MemberProjectMilestonesFetched(project_id, Ok(milestones)) -> {
      let next_store =
        normalized_store.upsert(
          model.member.pool.member_milestones_store,
          project_id,
          milestones,
          fn(progress) {
            let milestone.MilestoneProgress(
              milestone: milestone.Milestone(id: id, ..),
              ..,
            ) = progress
            id
          },
        )
        |> normalized_store.decrement_pending

      let next_milestones = case normalized_store.is_ready(next_store) {
        True -> Loaded(normalized_store.to_list(next_store))
        False -> model.member.pool.member_milestones
      }

      opt.Some(#(
        update_member_pool(model, fn(pool) {
          member_pool.Model(
            ..pool,
            member_milestones_store: next_store,
            member_milestones: next_milestones,
          )
        }),
        effect.none(),
      ))
    }

    pool_messages.MemberProjectMilestonesFetched(_project_id, Error(err)) -> {
      let next_store =
        model.member.pool.member_milestones_store
        |> normalized_store.decrement_pending

      let next_milestones = case model.member.pool.member_milestones {
        Loaded(_) -> model.member.pool.member_milestones
        _ -> Failed(err)
      }

      opt.Some(#(
        update_member_pool(model, fn(pool) {
          member_pool.Model(
            ..pool,
            member_milestones_store: next_store,
            member_milestones: next_milestones,
          )
        }),
        effect.none(),
      ))
    }

    pool_messages.MemberMilestonesShowCompletedToggled ->
      opt.Some(#(
        update_member_pool(model, fn(pool) {
          member_pool.Model(
            ..pool,
            member_milestones_show_completed: !pool.member_milestones_show_completed,
          )
        }),
        effect.none(),
      ))

    pool_messages.MemberMilestonesShowEmptyToggled ->
      opt.Some(#(
        update_member_pool(model, fn(pool) {
          member_pool.Model(
            ..pool,
            member_milestones_show_empty: !pool.member_milestones_show_empty,
          )
        }),
        effect.none(),
      ))

    pool_messages.MemberMilestoneRowToggled(milestone_id) -> {
      let expanded =
        dict.get(model.member.pool.member_milestones_expanded, milestone_id)
        |> opt.from_result
        |> opt.unwrap(False)

      let next =
        dict.insert(
          model.member.pool.member_milestones_expanded,
          milestone_id,
          !expanded,
        )

      opt.Some(#(
        update_member_pool(model, fn(pool) {
          member_pool.Model(..pool, member_milestones_expanded: next)
        }),
        effect.none(),
      ))
    }

    pool_messages.MemberMilestoneDetailsClicked(milestone_id) ->
      opt.Some(#(
        update_member_pool(model, fn(pool) {
          member_pool.Model(
            ..pool,
            member_milestone_dialog: member_pool.MilestoneDialogView(
              milestone_id,
            ),
            member_milestone_dialog_in_flight: False,
            member_milestone_dialog_error: opt.None,
          )
        }),
        effect.none(),
      ))

    pool_messages.MemberMilestoneActivatePromptClicked(milestone_id) ->
      opt.Some(#(
        update_member_pool(model, fn(pool) {
          member_pool.Model(
            ..pool,
            member_milestone_dialog: member_pool.MilestoneDialogActivate(
              milestone_id,
            ),
            member_milestone_dialog_in_flight: False,
            member_milestone_dialog_error: opt.None,
          )
        }),
        effect.none(),
      ))

    pool_messages.MemberMilestoneActivateClicked(milestone_id) -> {
      let next_model =
        update_member_pool(model, fn(pool) {
          member_pool.Model(
            ..pool,
            member_milestone_dialog: member_pool.MilestoneDialogActivate(
              milestone_id,
            ),
            member_milestone_activate_in_flight_id: opt.Some(milestone_id),
            member_milestone_dialog_in_flight: True,
          )
        })

      opt.Some(#(
        next_model,
        api_milestones.activate_milestone(milestone_id, fn(result) {
          client_state.pool_msg(pool_messages.MemberMilestoneActivated(
            milestone_id,
            result,
          ))
        }),
      ))
    }

    pool_messages.MemberMilestoneActivated(_milestone_id, Ok(_)) -> {
      let model =
        update_member_pool(model, fn(pool) {
          member_pool.Model(
            ..pool,
            member_milestone_dialog: member_pool.MilestoneDialogClosed,
            member_milestone_activate_in_flight_id: opt.None,
            member_milestone_dialog_in_flight: False,
            member_milestone_dialog_error: opt.None,
          )
        })

      let #(next, refresh_fx) = member_refresh(model)
      opt.Some(#(
        next,
        effect.batch([
          helpers_toast.toast_success(helpers_i18n.i18n_t(
            next,
            i18n_text.MilestoneActivated,
          )),
          refresh_fx,
        ]),
      ))
    }

    pool_messages.MemberMilestoneActivated(_milestone_id, Error(err)) -> {
      let message =
        milestone_error_message(model, err, i18n_text.MilestoneActivateFailed)

      let model =
        update_member_pool(model, fn(pool) {
          member_pool.Model(
            ..pool,
            member_milestone_activate_in_flight_id: opt.None,
            member_milestone_dialog_in_flight: False,
            member_milestone_dialog_error: opt.Some(message),
          )
        })

      opt.Some(#(model, helpers_toast.toast_error(message)))
    }

    pool_messages.MemberMilestoneEditClicked(milestone_id) -> {
      let dialog =
        dialog_helpers.find_milestone_dialog(
          model.member.pool.member_milestones,
          milestone_id,
          fn(m) {
            member_pool.MilestoneDialogEdit(
              id: m.id,
              name: m.name,
              description: m.description |> opt.unwrap(""),
            )
          },
        )
        |> opt.unwrap(member_pool.MilestoneDialogClosed)

      opt.Some(#(
        update_member_pool(model, fn(pool) {
          member_pool.Model(
            ..pool,
            member_milestone_dialog: dialog,
            member_milestone_dialog_in_flight: False,
            member_milestone_dialog_error: opt.None,
          )
        }),
        effect.none(),
      ))
    }

    pool_messages.MemberMilestoneDeleteClicked(milestone_id) -> {
      let dialog =
        dialog_helpers.find_milestone_dialog(
          model.member.pool.member_milestones,
          milestone_id,
          fn(m) { member_pool.MilestoneDialogDelete(id: m.id, name: m.name) },
        )
        |> opt.unwrap(member_pool.MilestoneDialogClosed)

      opt.Some(#(
        update_member_pool(model, fn(pool) {
          member_pool.Model(
            ..pool,
            member_milestone_dialog: dialog,
            member_milestone_dialog_in_flight: False,
            member_milestone_dialog_error: opt.None,
          )
        }),
        effect.none(),
      ))
    }

    pool_messages.MemberMilestoneDialogClosed -> {
      let focus_target =
        dialog_focus_target(model.member.pool.member_milestone_dialog)

      opt.Some(
        #(
          update_member_pool(model, fn(pool) {
            member_pool.Model(
              ..pool,
              member_milestone_dialog: member_pool.MilestoneDialogClosed,
              member_milestone_dialog_in_flight: False,
              member_milestone_dialog_error: opt.None,
            )
          }),
          case focus_target {
            opt.Some(element_id) ->
              app_effects.focus_element_after_timeout(element_id, 0)
            opt.None -> effect.none()
          },
        ),
      )
    }

    pool_messages.MemberMilestoneNameChanged(name) ->
      opt.Some(#(
        update_member_pool(model, fn(pool) {
          let next_dialog = case pool.member_milestone_dialog {
            member_pool.MilestoneDialogEdit(
              id: id,
              description: description,
              ..,
            ) ->
              member_pool.MilestoneDialogEdit(
                id: id,
                name: name,
                description: description,
              )
            other -> other
          }
          member_pool.Model(
            ..pool,
            member_milestone_dialog: next_dialog,
            member_milestone_dialog_error: opt.None,
          )
        }),
        effect.none(),
      ))

    pool_messages.MemberMilestoneDescriptionChanged(description) ->
      opt.Some(#(
        update_member_pool(model, fn(pool) {
          let next_dialog = case pool.member_milestone_dialog {
            member_pool.MilestoneDialogEdit(id: id, name: name, ..) ->
              member_pool.MilestoneDialogEdit(
                id: id,
                name: name,
                description: description,
              )
            other -> other
          }
          member_pool.Model(
            ..pool,
            member_milestone_dialog: next_dialog,
            member_milestone_dialog_error: opt.None,
          )
        }),
        effect.none(),
      ))

    pool_messages.MemberMilestoneEditSubmitted(milestone_id) -> {
      let payload = case model.member.pool.member_milestone_dialog {
        member_pool.MilestoneDialogEdit(
          name: name,
          description: description,
          ..,
        ) -> opt.Some(#(name, description))
        _ -> opt.None
      }

      case payload {
        opt.Some(#(name, description)) -> {
          let next_model =
            update_member_pool(model, fn(pool) {
              member_pool.Model(
                ..pool,
                member_milestone_dialog_in_flight: True,
                member_milestone_dialog_error: opt.None,
              )
            })

          opt.Some(#(
            next_model,
            api_milestones.update_milestone(
              milestone_id,
              name,
              description,
              fn(result) {
                client_state.pool_msg(pool_messages.MemberMilestoneUpdated(
                  result,
                ))
              },
            ),
          ))
        }
        opt.None -> opt.Some(#(model, effect.none()))
      }
    }

    pool_messages.MemberMilestoneDeleteSubmitted(milestone_id) -> {
      let next_model =
        update_member_pool(model, fn(pool) {
          member_pool.Model(
            ..pool,
            member_milestone_dialog_in_flight: True,
            member_milestone_dialog_error: opt.None,
          )
        })

      opt.Some(#(
        next_model,
        api_milestones.delete_milestone(milestone_id, fn(result) {
          client_state.pool_msg(pool_messages.MemberMilestoneDeleted(
            milestone_id,
            result,
          ))
        }),
      ))
    }

    pool_messages.MemberMilestoneUpdated(Ok(_)) -> {
      let model =
        update_member_pool(model, fn(pool) {
          member_pool.Model(
            ..pool,
            member_milestone_dialog: member_pool.MilestoneDialogClosed,
            member_milestone_dialog_in_flight: False,
            member_milestone_dialog_error: opt.None,
          )
        })

      let #(next, refresh_fx) = member_refresh(model)
      opt.Some(#(
        next,
        effect.batch([
          helpers_toast.toast_success(helpers_i18n.i18n_t(
            next,
            i18n_text.MilestoneUpdated,
          )),
          refresh_fx,
        ]),
      ))
    }

    pool_messages.MemberMilestoneUpdated(Error(err)) -> {
      let message =
        milestone_error_message(model, err, i18n_text.MilestoneUpdateFailed)

      opt.Some(#(
        update_member_pool(model, fn(pool) {
          member_pool.Model(
            ..pool,
            member_milestone_dialog_in_flight: False,
            member_milestone_dialog_error: opt.Some(message),
          )
        }),
        helpers_toast.toast_error(message),
      ))
    }

    pool_messages.MemberMilestoneDeleted(_milestone_id, Ok(_)) -> {
      let model =
        update_member_pool(model, fn(pool) {
          member_pool.Model(
            ..pool,
            member_milestone_dialog: member_pool.MilestoneDialogClosed,
            member_milestone_dialog_in_flight: False,
            member_milestone_dialog_error: opt.None,
          )
        })

      let #(next, refresh_fx) = member_refresh(model)
      opt.Some(#(
        next,
        effect.batch([
          helpers_toast.toast_success(helpers_i18n.i18n_t(
            next,
            i18n_text.MilestoneDeleted,
          )),
          refresh_fx,
        ]),
      ))
    }

    pool_messages.MemberMilestoneDeleted(_milestone_id, Error(err)) -> {
      let message =
        milestone_error_message(model, err, i18n_text.MilestoneDeleteFailed)

      opt.Some(#(
        update_member_pool(model, fn(pool) {
          member_pool.Model(
            ..pool,
            member_milestone_dialog_in_flight: False,
            member_milestone_dialog_error: opt.Some(message),
          )
        }),
        helpers_toast.toast_error(message),
      ))
    }

    _ -> opt.None
  }
}

fn update_member_pool(
  model: client_state.Model,
  f: fn(member_pool.Model) -> member_pool.Model,
) -> client_state.Model {
  client_state.update_member(model, fn(member) {
    member_state.MemberModel(..member, pool: f(member.pool))
  })
}

fn milestone_error_message(
  model: client_state.Model,
  err: ApiError,
  fallback: i18n_text.Text,
) -> String {
  let ApiError(code: code, message: message, ..) = err

  error_codes.to_user_message(model, code, message, fallback)
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
    member_pool.MilestoneDialogView(id: id) ->
      opt.Some(milestone_ids.details_button_id(id))
    member_pool.MilestoneDialogClosed -> opt.None
  }
}
