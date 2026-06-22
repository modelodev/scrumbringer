//// Effectful drag, touch, hover, and highlight workflow for the pool.

import gleam/dict
import gleam/int
import gleam/option as opt

import lustre/effect.{type Effect}

import domain/api_error.{type ApiResult}
import domain/note/entity.{type Note}
import domain/task.{type TaskPosition}
import scrumbringer_client/api/tasks/notes as task_notes_api
import scrumbringer_client/api/tasks/positions as task_positions_api
import scrumbringer_client/app/effects as app_effects
import scrumbringer_client/client_ffi
import scrumbringer_client/client_state/member/notes as member_notes
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/client_state/member/positions as member_positions
import scrumbringer_client/features/pool/drag as pool_drag
import scrumbringer_client/features/pool/highlight as pool_highlight
import scrumbringer_client/features/pool/hover_notes as pool_hover_notes
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/pool/touch as pool_touch
import scrumbringer_client/features/tasks/mutation_update as task_mutation_update

pub type Model {
  Model(
    pool: member_pool.Model,
    positions: member_positions.Model,
    notes: member_notes.Model,
  )
}

pub type Context(parent_msg) {
  Context(
    task_mutation: task_mutation_update.MutationContext(parent_msg),
    on_canvas_rect_fetched: fn(Int, Int) -> parent_msg,
    on_drag_offset_resolved: fn(Int, Int, Int) -> parent_msg,
    on_my_tasks_rect_fetched: fn(Int, Int, Int, Int) -> parent_msg,
    on_hover_notes_fetched: fn(Int, ApiResult(List(Note))) -> parent_msg,
    on_long_press_check: fn(Int) -> parent_msg,
    on_position_saved: fn(ApiResult(TaskPosition)) -> parent_msg,
  )
}

pub fn try_update(
  model: Model,
  inner: pool_messages.Msg,
  context: Context(parent_msg),
) -> opt.Option(#(Model, Effect(parent_msg))) {
  case inner {
    pool_messages.MemberPoolMyTasksRectFetched(left, top, width, height) ->
      opt.Some(my_tasks_rect_fetched(model, left, top, width, height))
    pool_messages.MemberPoolDragToClaimArmed(armed) ->
      opt.Some(drag_to_claim_armed(model, armed))
    pool_messages.MemberPoolTouchStarted(task_id, client_x, client_y) ->
      opt.Some(touch_started(model, task_id, client_x, client_y, context))
    pool_messages.MemberPoolTouchEnded(task_id) ->
      opt.Some(touch_ended(model, task_id, context))
    pool_messages.MemberPoolLongPressCheck(task_id) ->
      opt.Some(long_press_check(model, task_id, context))
    pool_messages.MemberTaskHoverOpened(task_id) ->
      opt.Some(hover_opened(model, task_id, context))
    pool_messages.MemberTaskHoverClosed -> opt.Some(hover_closed(model))
    pool_messages.MemberTaskFocused(task_id) ->
      opt.Some(task_focused(model, task_id, context))
    pool_messages.MemberTaskBlurred -> opt.Some(task_blurred(model))
    pool_messages.MemberTaskCreatedFeedback(task_id) ->
      opt.Some(task_created_feedback(model, task_id))
    pool_messages.MemberHighlightExpired(task_id) ->
      opt.Some(highlight_expired(model, task_id))
    pool_messages.MemberTaskHoverNotesFetched(task_id, result) ->
      opt.Some(hover_notes_fetched(model, task_id, result))
    pool_messages.MemberCanvasRectFetched(left, top) ->
      opt.Some(canvas_rect_fetched(model, left, top))
    pool_messages.MemberDragStarted(task_id, client_x, client_y) ->
      opt.Some(drag_started(model, task_id, client_x, client_y, context))
    pool_messages.MemberDragOffsetResolved(task_id, offset_x, offset_y) ->
      opt.Some(drag_offset_resolved(model, task_id, offset_x, offset_y))
    pool_messages.MemberDragMoved(client_x, client_y) ->
      opt.Some(drag_moved(model, client_x, client_y))
    pool_messages.MemberDragEnded -> opt.Some(drag_ended(model, context))
    _ -> opt.None
  }
}

fn touch_started(
  model: Model,
  task_id: Int,
  client_x: Int,
  client_y: Int,
  context: Context(parent_msg),
) -> #(Model, Effect(parent_msg)) {
  let #(model, hover_fx) = ensure_hover_notes(model, task_id, context)
  let model =
    Model(
      ..model,
      pool: pool_touch.start(model.pool, task_id, client_x, client_y),
    )

  #(
    model,
    effect.batch([
      hover_fx,
      app_effects.schedule_timeout(450, fn() {
        context.on_long_press_check(task_id)
      }),
    ]),
  )
}

fn hover_opened(
  model: Model,
  task_id: Int,
  context: Context(parent_msg),
) -> #(Model, Effect(parent_msg)) {
  let #(next, fx) = ensure_hover_notes(model, task_id, context)
  #(open_blocker_highlight(next, task_id), fx)
}

fn hover_closed(model: Model) -> #(Model, Effect(parent_msg)) {
  #(Model(..model, pool: pool_highlight.clear(model.pool)), effect.none())
}

fn task_focused(
  model: Model,
  task_id: Int,
  context: Context(parent_msg),
) -> #(Model, Effect(parent_msg)) {
  let #(next, fx) = ensure_hover_notes(model, task_id, context)
  #(open_blocker_highlight(next, task_id), fx)
}

fn task_blurred(model: Model) -> #(Model, Effect(parent_msg)) {
  hover_closed(model)
}

fn task_created_feedback(
  model: Model,
  task_id: Int,
) -> #(Model, Effect(parent_msg)) {
  #(
    Model(..model, pool: pool_highlight.created(model.pool, task_id)),
    effect.none(),
  )
}

fn highlight_expired(model: Model, task_id: Int) -> #(Model, Effect(parent_msg)) {
  #(
    Model(..model, pool: pool_highlight.expire(model.pool, task_id)),
    effect.none(),
  )
}

fn open_blocker_highlight(model: Model, task_id: Int) -> Model {
  Model(..model, pool: pool_highlight.blocking_for_task(model.pool, task_id))
}

fn touch_ended(
  model: Model,
  task_id: Int,
  context: Context(parent_msg),
) -> #(Model, Effect(parent_msg)) {
  case pool_touch.is_longpress_for(model.pool, task_id) {
    True -> {
      let #(model, fx) = drag_ended(model, context)
      let model = Model(..model, pool: pool_touch.clear(model.pool))
      #(model, fx)
    }
    False -> #(
      Model(..model, pool: pool_touch.end_preview(model.pool, task_id)),
      effect.none(),
    )
  }
}

fn long_press_check(
  model: Model,
  task_id: Int,
  context: Context(parent_msg),
) -> #(Model, Effect(parent_msg)) {
  case pool_touch.is_pending_for(model.pool, task_id) {
    True -> {
      let #(model, fx) =
        drag_started(
          model,
          task_id,
          pool_touch.client_x(model.pool),
          pool_touch.client_y(model.pool),
          context,
        )
      let model =
        Model(..model, pool: pool_touch.mark_longpress(model.pool, task_id))
      #(model, fx)
    }
    False -> #(model, effect.none())
  }
}

fn drag_to_claim_armed(
  model: Model,
  armed: Bool,
) -> #(Model, Effect(parent_msg)) {
  #(
    Model(..model, pool: pool_drag.drag_to_claim_armed(model.pool, armed)),
    effect.none(),
  )
}

fn my_tasks_rect_fetched(
  model: Model,
  left: Int,
  top: Int,
  width: Int,
  height: Int,
) -> #(Model, Effect(parent_msg)) {
  #(
    Model(
      ..model,
      pool: pool_drag.my_tasks_rect_fetched(
        model.pool,
        left,
        top,
        width,
        height,
      ),
    ),
    effect.none(),
  )
}

fn canvas_rect_fetched(
  model: Model,
  left: Int,
  top: Int,
) -> #(Model, Effect(parent_msg)) {
  #(
    Model(
      ..model,
      positions: member_positions.Model(
        ..model.positions,
        member_canvas_left: left,
        member_canvas_top: top,
      ),
    ),
    effect.none(),
  )
}

fn drag_started(
  model: Model,
  task_id: Int,
  client_x: Int,
  client_y: Int,
  context: Context(parent_msg),
) -> #(Model, Effect(parent_msg)) {
  let model = Model(..model, pool: pool_drag.start(model.pool, task_id))

  #(
    model,
    effect.from(fn(dispatch) {
      let #(left, top) = client_ffi.element_client_offset("member-canvas")
      dispatch(context.on_canvas_rect_fetched(left, top))

      let #(card_left, card_top, _width, _height) =
        client_ffi.element_client_rect("task-card-" <> int.to_string(task_id))
      let offset_x = client_x - card_left
      let offset_y = client_y - card_top
      dispatch(context.on_drag_offset_resolved(task_id, offset_x, offset_y))

      let #(dz_left, dz_top, dz_width, dz_height) =
        client_ffi.element_client_rect("pool-my-tasks")
      dispatch(context.on_my_tasks_rect_fetched(
        dz_left,
        dz_top,
        dz_width,
        dz_height,
      ))
    }),
  )
}

fn drag_moved(
  model: Model,
  client_x: Int,
  client_y: Int,
) -> #(Model, Effect(parent_msg)) {
  case pool_drag.active(model.pool), pool_drag.is_pending(model.pool) {
    opt.Some(#(task_id, ox, oy)), _ -> {
      let x = client_x - model.positions.member_canvas_left - ox
      let y = client_y - model.positions.member_canvas_top - oy
      #(
        Model(
          ..model,
          positions: member_positions.Model(
            ..model.positions,
            member_positions_by_task: dict.insert(
              model.positions.member_positions_by_task,
              task_id,
              #(x, y),
            ),
          ),
          pool: pool_drag.move(model.pool, client_x, client_y),
        ),
        effect.none(),
      )
    }
    opt.None, True -> #(
      Model(..model, pool: pool_drag.move(model.pool, client_x, client_y)),
      effect.none(),
    )
    opt.None, False -> #(model, effect.none())
  }
}

fn drag_offset_resolved(
  model: Model,
  task_id: Int,
  offset_x: Int,
  offset_y: Int,
) -> #(Model, Effect(parent_msg)) {
  #(
    Model(
      ..model,
      pool: pool_drag.offset_resolved(model.pool, task_id, offset_x, offset_y),
    ),
    effect.none(),
  )
}

fn hover_notes_fetched(
  model: Model,
  task_id: Int,
  result: ApiResult(List(Note)),
) -> #(Model, Effect(parent_msg)) {
  #(
    Model(
      ..model,
      notes: pool_hover_notes.fetched(model.notes, task_id, result),
    ),
    effect.none(),
  )
}

fn ensure_hover_notes(
  model: Model,
  task_id: Int,
  context: Context(parent_msg),
) -> #(Model, Effect(parent_msg)) {
  let #(notes, should_fetch) =
    pool_hover_notes.ensure_fetch(model.notes, task_id)

  case should_fetch {
    False -> #(model, effect.none())
    True -> {
      let model = Model(..model, notes: notes)
      let notes_fx =
        task_notes_api.list_task_notes(task_id, fn(result) {
          context.on_hover_notes_fetched(task_id, result)
        })

      #(model, notes_fx)
    }
  }
}

fn drag_ended(
  model: Model,
  context: Context(parent_msg),
) -> #(Model, Effect(parent_msg)) {
  case pool_drag.task_id(model.pool) {
    opt.Some(task_id) -> drag_end_for_task(model, task_id, context)
    opt.None -> #(model, effect.none())
  }
}

fn drag_end_for_task(
  model: Model,
  task_id: Int,
  context: Context(parent_msg),
) -> #(Model, Effect(parent_msg)) {
  let over_my_tasks = pool_drag.is_over_my_tasks(model.pool)
  let model = Model(..model, pool: pool_drag.clear(model.pool))

  case over_my_tasks {
    True -> claim_drop(model, task_id, context)
    False -> position_drop(model, task_id, context)
  }
}

fn claim_drop(
  model: Model,
  task_id: Int,
  context: Context(parent_msg),
) -> #(Model, Effect(parent_msg)) {
  let #(pool, fx) =
    task_mutation_update.handle_claim_dropped(
      model.pool,
      task_id,
      context.task_mutation,
    )
  #(Model(..model, pool: pool), fx)
}

fn position_drop(
  model: Model,
  task_id: Int,
  context: Context(parent_msg),
) -> #(Model, Effect(parent_msg)) {
  let #(x, y) =
    position_for_task(model.positions.member_positions_by_task, task_id)
  #(
    model,
    task_positions_api.upsert_me_task_position(task_id, x, y, fn(result) {
      context.on_position_saved(result)
    }),
  )
}

fn position_for_task(
  positions: dict.Dict(Int, #(Int, Int)),
  task_id: Int,
) -> #(Int, Int) {
  case dict.get(positions, task_id) {
    Ok(xy) -> xy
    Error(_) -> #(0, 0)
  }
}
