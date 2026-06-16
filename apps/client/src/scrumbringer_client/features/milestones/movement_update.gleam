//// Milestone card/task movement workflow for member-pool updates.

import gleam/list
import gleam/option as opt

import lustre/effect

import domain/api_error.{type ApiResult}
import domain/card.{type Card}
import domain/milestone
import domain/remote.{Loaded}
import domain/task.{type Task}
import scrumbringer_client/api/cards as api_cards
import scrumbringer_client/api/tasks/operations as task_operations_api
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/milestones/update as milestone_update
import scrumbringer_client/features/pool/msg as pool_messages

pub type Context(parent_msg) {
  Context(
    on_milestone_card_moved: fn(ApiResult(Card)) -> parent_msg,
    on_milestone_task_moved: fn(ApiResult(Task)) -> parent_msg,
  )
}

pub fn try_update(
  model: member_pool.Model,
  inner: pool_messages.Msg,
  context: Context(parent_msg),
  feedback: milestone_update.FeedbackContext(parent_msg),
) -> opt.Option(milestone_update.Update(parent_msg)) {
  case inner {
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
      opt.Some(milestone_update.Update(
        model,
        effect.none(),
        milestone_update.RefreshWithSuccess(milestone_update.MilestoneUpdated),
        milestone_update.NoRootPolicy,
      ))

    pool_messages.MemberMilestoneCardMoved(Error(err))
    | pool_messages.MemberMilestoneTaskMoved(Error(err)) ->
      opt.Some(milestone_update.Update(
        model,
        milestone_update.error_effect(
          err,
          milestone_update.MilestoneUpdateFailed,
          feedback,
        ),
        milestone_update.NoRefresh,
        milestone_update.NoRootPolicy,
      ))

    _ -> opt.None
  }
}

fn handle_milestone_card_drag_started(
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

fn handle_milestone_task_drag_started(
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

fn handle_milestone_drag_ended(
  model: member_pool.Model,
) -> #(member_pool.Model, effect.Effect(parent_msg)) {
  #(
    member_pool.Model(..model, member_milestone_drag_item: opt.None),
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

fn handle_milestone_dropped_on(
  model: member_pool.Model,
  to_milestone_id: Int,
  context: Context(parent_msg),
) -> milestone_update.Update(parent_msg) {
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
          milestone_update.Update(
            model,
            task_operations_api.update_task_milestone(
              task_id,
              opt.Some(to_milestone_id),
              context.on_milestone_task_moved,
            ),
            milestone_update.NoRefresh,
            milestone_update.NoRootPolicy,
          )
        False ->
          milestone_update.Update(
            model,
            effect.none(),
            milestone_update.NoRefresh,
            milestone_update.NoRootPolicy,
          )
      }

    opt.None ->
      milestone_update.Update(
        model,
        effect.none(),
        milestone_update.NoRefresh,
        milestone_update.NoRootPolicy,
      )
  }
}

fn handle_milestone_card_move_clicked(
  model: member_pool.Model,
  card_id: Int,
  from_milestone_id: Int,
  to_milestone_id: Int,
  context: Context(parent_msg),
) -> milestone_update.Update(parent_msg) {
  update_moved_card(model, card_id, from_milestone_id, to_milestone_id, context)
}

fn update_moved_card(
  model: member_pool.Model,
  card_id: Int,
  from_milestone_id: Int,
  to_milestone_id: Int,
  context: Context(parent_msg),
) -> milestone_update.Update(parent_msg) {
  case
    can_move_between_ready_milestones(model, from_milestone_id, to_milestone_id),
    card_in_milestone(model, card_id, from_milestone_id)
  {
    True, opt.Some(card) ->
      milestone_update.Update(
        model,
        api_cards.update_card(
          card.id,
          card.title,
          card.description,
          card.color,
          opt.Some(to_milestone_id),
          context.on_milestone_card_moved,
        ),
        milestone_update.NoRefresh,
        milestone_update.NoRootPolicy,
      )
    _, _ ->
      milestone_update.Update(
        model,
        effect.none(),
        milestone_update.NoRefresh,
        milestone_update.NoRootPolicy,
      )
  }
}

fn handle_milestone_task_move_clicked(
  model: member_pool.Model,
  task_id: Int,
  from_milestone_id: Int,
  to_milestone_id: Int,
  context: Context(parent_msg),
) -> milestone_update.Update(parent_msg) {
  case
    can_move_between_ready_milestones(model, from_milestone_id, to_milestone_id)
    && task_in_milestone(model, task_id, from_milestone_id)
  {
    True ->
      milestone_update.Update(
        model,
        task_operations_api.update_task_milestone(
          task_id,
          opt.Some(to_milestone_id),
          context.on_milestone_task_moved,
        ),
        milestone_update.NoRefresh,
        milestone_update.NoRootPolicy,
      )
    False ->
      milestone_update.Update(
        model,
        effect.none(),
        milestone_update.NoRefresh,
        milestone_update.NoRootPolicy,
      )
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
