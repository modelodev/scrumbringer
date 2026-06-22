import gleam/dict
import gleam/list
import gleam/option.{None, Some}

import lustre/effect

import domain/api_error.{type ApiResult}
import domain/note/entity.{type Note}
import domain/remote.{Loaded}
import domain/task.{
  type Task, type TaskDependency, type TaskPosition, Task, TaskDependency,
}
import domain/task_state
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/client_state/member/notes as member_notes
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/client_state/member/positions as member_positions
import scrumbringer_client/features/pool/drag
import scrumbringer_client/features/pool/drag_update
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/pool/touch
import scrumbringer_client/features/tasks/mutation_update as task_mutation_update

fn local_model() -> drag_update.Model {
  drag_update.Model(
    pool: member_pool.default_model(),
    positions: member_positions.default_model(),
    notes: member_notes.default_model(),
  )
}

fn context() -> drag_update.Context(Nil) {
  drag_update.Context(
    task_mutation: task_mutation_update.MutationContext(
      current_user_id: None,
      on_task_claimed: fn(_result: ApiResult(Task)) { Nil },
      on_task_released: fn(_result: ApiResult(Task)) { Nil },
      on_task_completed: fn(_result: ApiResult(Task)) { Nil },
      on_task_deleted: fn(_task_id: Int, _result: ApiResult(Nil)) { Nil },
    ),
    on_canvas_rect_fetched: fn(_left, _top) { Nil },
    on_drag_offset_resolved: fn(_task_id, _offset_x, _offset_y) { Nil },
    on_my_tasks_rect_fetched: fn(_left, _top, _width, _height) { Nil },
    on_hover_notes_fetched: fn(_task_id, _result: ApiResult(List(Note))) { Nil },
    on_long_press_check: fn(_task_id) { Nil },
    on_position_saved: fn(_result: ApiResult(TaskPosition)) { Nil },
  )
}

fn task(id: Int, dependencies: List(TaskDependency)) -> Task {
  let state = task_state.Available
  Task(
    id: id,
    project_id: 1,
    type_id: 1,
    task_type: TaskTypeInline(id: 1, name: "Bug", icon: "bug-ant"),
    ongoing_by: None,
    title: "Task",
    description: Some("Task description"),
    priority: 3,
    state: state,
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
    due_date: None,
    version: 1,
    parent_card_id: None,
    card_id: None,
    card_title: None,
    card_color: None,
    has_new_notes: False,
    blocked_count: list.length(dependencies),
    dependencies: dependencies,
    automation_origin: None,
  )
}

fn dependency(depends_on_task_id: Int) -> TaskDependency {
  TaskDependency(
    depends_on_task_id: depends_on_task_id,
    title: "Dependency",
    status: task_state.to_status(task_state.Available),
    claimed_by: None,
  )
}

pub fn drag_update_canvas_rect_updates_position_origin_test() {
  let assert Some(#(next, _fx)) =
    drag_update.try_update(
      local_model(),
      pool_messages.MemberCanvasRectFetched(10, 20),
      context(),
    )

  let assert 10 = next.positions.member_canvas_left
  let assert 20 = next.positions.member_canvas_top
}

pub fn drag_update_active_move_updates_position_and_pool_test() {
  let pool =
    member_pool.default_model()
    |> drag.start(7)
    |> drag.offset_resolved(7, 3, 4)
  let model =
    drag_update.Model(
      ..local_model(),
      pool: pool,
      positions: member_positions.Model(
        ..member_positions.default_model(),
        member_canvas_left: 10,
        member_canvas_top: 20,
      ),
    )

  let assert Some(#(next, _fx)) =
    drag_update.try_update(
      model,
      pool_messages.MemberDragMoved(40, 70),
      context(),
    )

  let assert Ok(#(27, 46)) =
    dict.get(next.positions.member_positions_by_task, 7)
  let assert Some(#(7, 3, 4)) = drag.active(next.pool)
}

pub fn drag_update_touch_end_without_longpress_opens_preview_test() {
  let model =
    drag_update.Model(..local_model(), pool: drag_update_local_touch_started(7))

  let assert Some(#(next, _fx)) =
    drag_update.try_update(
      model,
      pool_messages.MemberPoolTouchEnded(7),
      context(),
    )

  let assert Some(7) = next.pool.member_pool_preview_task_id
  let assert None = next.pool.member_pool_touch_task_id
}

pub fn drag_update_hover_open_sets_blocking_highlight_test() {
  let source = task(1, [dependency(2)])
  let model =
    drag_update.Model(
      ..local_model(),
      pool: member_pool.Model(
        ..member_pool.default_model(),
        member_tasks: Loaded([source]),
      ),
    )

  let assert Some(#(next, _fx)) =
    drag_update.try_update(
      model,
      pool_messages.MemberTaskHoverOpened(1),
      context(),
    )

  let assert member_pool.BlockingHighlight(1, [2], 1) =
    next.pool.member_highlight_state
}

pub fn drag_update_focus_and_blur_manage_blocking_highlight_test() {
  let source = task(1, [dependency(2)])
  let blocker = task(2, [])
  let model =
    drag_update.Model(
      ..local_model(),
      pool: member_pool.Model(
        ..member_pool.default_model(),
        member_tasks: Loaded([source, blocker]),
      ),
    )

  let assert Some(#(focused, _focus_fx)) =
    drag_update.try_update(model, pool_messages.MemberTaskFocused(1), context())
  let assert Some(#(blurred, _blur_fx)) =
    drag_update.try_update(focused, pool_messages.MemberTaskBlurred, context())

  let assert member_pool.BlockingHighlight(1, [2], 0) =
    focused.pool.member_highlight_state
  let assert member_pool.NoHighlight = blurred.pool.member_highlight_state
}

pub fn drag_update_highlight_expired_clears_matching_created_highlight_test() {
  let model =
    drag_update.Model(
      ..local_model(),
      pool: member_pool.Model(
        ..member_pool.default_model(),
        member_highlight_state: member_pool.CreatedHighlight(21),
      ),
    )

  let assert Some(#(next, _fx)) =
    drag_update.try_update(
      model,
      pool_messages.MemberHighlightExpired(21),
      context(),
    )

  let assert member_pool.NoHighlight = next.pool.member_highlight_state
}

pub fn drag_update_try_update_handles_drag_message_test() {
  let assert Some(#(next, _fx)) =
    drag_update.try_update(
      local_model(),
      pool_messages.MemberPoolDragToClaimArmed(True),
      context(),
    )

  let assert member_pool.PoolDragPendingRect = next.pool.member_pool_drag
}

pub fn drag_update_drop_to_claim_blocked_task_does_not_submit_test() {
  let blocked = task(7, [dependency(2)])
  let pool =
    member_pool.Model(
      ..member_pool.default_model(),
      member_tasks: Loaded([blocked]),
      member_drag: member_pool.DragActive(7, 0, 0),
      member_pool_drag: member_pool.PoolDragDragging(
        over_my_tasks: True,
        rect: member_pool.Rect(left: 0, top: 0, width: 100, height: 100),
      ),
    )
  let model = drag_update.Model(..local_model(), pool: pool)

  let assert Some(#(next, fx)) =
    drag_update.try_update(model, pool_messages.MemberDragEnded, context())

  let assert False = next.pool.member_task_mutation_in_flight
  let assert member_pool.DragIdle = next.pool.member_drag
  let assert member_pool.PoolDragIdle = next.pool.member_pool_drag
  let assert True = fx == effect.none()
}

pub fn drag_update_try_update_ignores_non_drag_message_test() {
  let assert None =
    drag_update.try_update(
      local_model(),
      pool_messages.MemberPoolVisibilityChanged("all-open"),
      context(),
    )
}

fn drag_update_local_touch_started(task_id: Int) -> member_pool.Model {
  touch.start(member_pool.default_model(), task_id, 12, 34)
}
