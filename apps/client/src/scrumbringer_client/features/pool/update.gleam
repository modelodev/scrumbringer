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
//// - **client_state.gleam**: Provides Model, Msg types
//// - **client_update.gleam**: Delegates pool messages here
//// - **api/tasks.gleam**: Provides position API functions

import gleam/dict
import gleam/int
import gleam/option as opt

import lustre/effect.{type Effect}

import domain/api_error.{type ApiError}
import domain/task.{type TaskPosition, Task, TaskPosition}
import scrumbringer_client/api/tasks as api_tasks
import scrumbringer_client/app/effects as app_effects
import scrumbringer_client/client_ffi
import scrumbringer_client/client_state.{
  type Model, type Msg, type PoolDragState, MemberCanvasRectFetched, MemberDrag,
  MemberModel, MemberPoolLongPressCheck, MemberPoolMyTasksRectFetched,
  MemberPositionSaved, MemberTaskClaimed, PoolDragDragging, PoolDragIdle,
  PoolDragPendingRect, Rect, pool_msg, rect_contains_point, update_member,
}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/member_section
import scrumbringer_client/pool_prefs
import scrumbringer_client/theme
import scrumbringer_client/update_helpers

// =============================================================================
// Filter Handlers
// =============================================================================

/// Handle pool status filter change.
pub fn handle_pool_status_changed(
  model: Model,
  value: String,
  member_refresh: fn(Model) -> #(Model, Effect(Msg)),
) -> #(Model, Effect(Msg)) {
  let model =
    update_member(model, fn(member) {
      MemberModel(..member, member_filters_status: value)
    })
  member_refresh(model)
}

/// Handle pool type filter change.
pub fn handle_pool_type_changed(
  model: Model,
  value: String,
  member_refresh: fn(Model) -> #(Model, Effect(Msg)),
) -> #(Model, Effect(Msg)) {
  let model =
    update_member(model, fn(member) {
      MemberModel(..member, member_filters_type_id: value)
    })
  member_refresh(model)
}

/// Handle pool capability filter change.
pub fn handle_pool_capability_changed(
  model: Model,
  value: String,
  member_refresh: fn(Model) -> #(Model, Effect(Msg)),
) -> #(Model, Effect(Msg)) {
  let model =
    update_member(model, fn(member) {
      MemberModel(..member, member_filters_capability_id: value)
    })
  member_refresh(model)
}

/// Handle pool search input change (no refresh yet).
pub fn handle_pool_search_changed(
  model: Model,
  value: String,
) -> #(Model, Effect(Msg)) {
  #(
    update_member(model, fn(member) {
      MemberModel(..member, member_filters_q: value)
    }),
    effect.none(),
  )
}

/// Handle pool search debounced (triggers refresh).
pub fn handle_pool_search_debounced(
  model: Model,
  value: String,
  member_refresh: fn(Model) -> #(Model, Effect(Msg)),
) -> #(Model, Effect(Msg)) {
  let model =
    update_member(model, fn(member) {
      MemberModel(..member, member_filters_q: value)
    })
  member_refresh(model)
}

/// Clear all pool filters at once.
pub fn handle_clear_filters(
  model: Model,
  member_refresh: fn(Model) -> #(Model, Effect(Msg)),
) -> #(Model, Effect(Msg)) {
  let model =
    update_member(model, fn(member) {
      MemberModel(
        ..member,
        member_filters_type_id: "",
        member_filters_capability_id: "",
        member_filters_q: "",
        member_quick_my_caps: False,
      )
    })
  member_refresh(model)
}

// =============================================================================
// View Mode and Filter Visibility
// =============================================================================

/// Toggle the "my capabilities" quick filter.
pub fn handle_toggle_my_capabilities_quick(
  model: Model,
) -> #(Model, Effect(Msg)) {
  #(
    update_member(model, fn(member) {
      MemberModel(
        ..member,
        member_quick_my_caps: !model.member.member_quick_my_caps,
      )
    }),
    effect.none(),
  )
}

/// Toggle pool filters visibility.
pub fn handle_pool_filters_toggled(model: Model) -> #(Model, Effect(Msg)) {
  let next = !model.member.member_pool_filters_visible
  #(
    update_member(model, fn(member) {
      MemberModel(..member, member_pool_filters_visible: next)
    }),
    save_pool_filters_visible_effect(next),
  )
}

/// Set pool view mode (grid/list).
pub fn handle_pool_view_mode_set(
  model: Model,
  mode: pool_prefs.ViewMode,
) -> #(Model, Effect(Msg)) {
  #(
    update_member(model, fn(member) {
      MemberModel(..member, member_pool_view_mode: mode)
    }),
    save_pool_view_mode_effect(mode),
  )
}

fn save_pool_filters_visible_effect(visible: Bool) -> Effect(Msg) {
  effect.from(fn(_dispatch) {
    theme.local_storage_set(
      pool_prefs.filters_visible_storage_key,
      pool_prefs.encode_filters_visibility(pool_prefs.visibility_from_bool(
        visible,
      )),
    )
  })
}

fn save_pool_view_mode_effect(mode: pool_prefs.ViewMode) -> Effect(Msg) {
  effect.from(fn(_dispatch) {
    theme.local_storage_set(
      pool_prefs.view_mode_storage_key,
      pool_prefs.encode_view_mode_storage(mode),
    )
  })
}

// =============================================================================
// Keyboard Shortcuts
// =============================================================================

/// Handle global keydown events for pool shortcuts.
pub fn handle_global_keydown(
  model: Model,
  event: pool_prefs.KeyEvent,
) -> #(Model, Effect(Msg)) {
  case is_pool_shortcut_target(model) {
    False -> #(model, effect.none())
    True -> handle_pool_shortcut_action(model, event)
  }
}

fn is_pool_shortcut_target(model: Model) -> Bool {
  model.core.page == client_state.Member
  && model.member.member_section == member_section.Pool
}

fn handle_pool_shortcut_action(
  model: Model,
  event: pool_prefs.KeyEvent,
) -> #(Model, Effect(Msg)) {
  case pool_prefs.shortcut_action(event) {
    pool_prefs.NoAction -> #(model, effect.none())
    pool_prefs.ToggleFilters -> toggle_filters_shortcut(model)
    pool_prefs.FocusSearch -> focus_search_shortcut(model)
    pool_prefs.OpenCreate -> open_create_shortcut(model)
    pool_prefs.CloseDialog -> close_dialog_shortcut(model)
  }
}

fn toggle_filters_shortcut(model: Model) -> #(Model, Effect(Msg)) {
  let next = !model.member.member_pool_filters_visible
  #(
    update_member(model, fn(member) {
      MemberModel(..member, member_pool_filters_visible: next)
    }),
    save_pool_filters_visible_effect(next),
  )
}

fn focus_search_shortcut(model: Model) -> #(Model, Effect(Msg)) {
  let should_show = !model.member.member_pool_filters_visible
  let model =
    update_member(model, fn(member) {
      MemberModel(..member, member_pool_filters_visible: True)
    })
  let show_fx = case should_show {
    True -> save_pool_filters_visible_effect(True)
    False -> effect.none()
  }

  #(
    model,
    effect.batch([
      show_fx,
      app_effects.focus_element_after_timeout("pool-filter-q", 0),
    ]),
  )
}

fn open_create_shortcut(model: Model) -> #(Model, Effect(Msg)) {
  case model.member.member_create_dialog_open {
    True -> #(model, effect.none())
    False -> #(
      update_member(model, fn(member) {
        MemberModel(..member, member_create_dialog_open: True)
      }),
      effect.none(),
    )
  }
}

fn close_dialog_shortcut(model: Model) -> #(Model, Effect(Msg)) {
  case
    model.member.member_create_dialog_open,
    opt.is_some(model.member.member_notes_task_id),
    opt.is_some(model.member.member_position_edit_task)
  {
    True, _, _ -> #(
      update_member(model, fn(member) {
        MemberModel(..member, member_create_dialog_open: False)
      }),
      effect.none(),
    )
    _, True, _ -> #(
      update_member(model, fn(member) {
        MemberModel(..member, member_notes_task_id: opt.None)
      }),
      effect.none(),
    )
    _, _, True -> #(
      update_member(model, fn(member) {
        MemberModel(
          ..member,
          member_position_edit_task: opt.None,
          member_position_edit_error: opt.None,
        )
      }),
      effect.none(),
    )
    _, _, _ -> #(model, effect.none())
  }
}

// =============================================================================
// Drag-and-Drop Handlers
// =============================================================================

/// Handle touch start on a task card (tap/long-press).
pub fn handle_pool_touch_started(
  model: Model,
  task_id: Int,
) -> #(Model, Effect(Msg)) {
  let model =
    update_member(model, fn(member) {
      MemberModel(
        ..member,
        member_pool_touch_task_id: opt.Some(task_id),
        member_pool_touch_longpress: opt.None,
      )
    })

  #(
    model,
    app_effects.schedule_timeout(450, fn() {
      pool_msg(MemberPoolLongPressCheck(task_id))
    }),
  )
}

/// Handle touch end on a task card.
pub fn handle_pool_touch_ended(
  model: Model,
  task_id: Int,
) -> #(Model, Effect(Msg)) {
  case model.member.member_pool_touch_longpress {
    opt.Some(id) if id == task_id -> {
      let #(model, fx) = handle_drag_ended(model)
      let model =
        update_member(model, fn(member) {
          MemberModel(
            ..member,
            member_pool_touch_task_id: opt.None,
            member_pool_touch_longpress: opt.None,
          )
        })
      #(model, fx)
    }
    _ -> {
      let next_preview = case model.member.member_pool_preview_task_id {
        opt.Some(id) if id == task_id -> opt.None
        _ -> opt.Some(task_id)
      }
      #(
        update_member(model, fn(member) {
          MemberModel(
            ..member,
            member_pool_preview_task_id: next_preview,
            member_pool_touch_task_id: opt.None,
            member_pool_touch_longpress: opt.None,
          )
        }),
        effect.none(),
      )
    }
  }
}

/// Handle long-press check for touch drag.
pub fn handle_pool_long_press_check(
  model: Model,
  task_id: Int,
) -> #(Model, Effect(Msg)) {
  case model.member.member_pool_touch_task_id {
    opt.Some(id) if id == task_id -> {
      let #(model, fx) = handle_drag_started(model, task_id, 0, 0)
      let model =
        update_member(model, fn(member) {
          MemberModel(
            ..member,
            member_pool_touch_longpress: opt.Some(task_id),
            member_pool_preview_task_id: opt.None,
          )
        })
      #(model, fx)
    }
    _ -> #(model, effect.none())
  }
}

/// Handle drag-to-claim armed state change.
pub fn handle_pool_drag_to_claim_armed(
  model: Model,
  armed: Bool,
) -> #(Model, Effect(Msg)) {
  let next_drag = case armed, model.member.member_pool_drag {
    True, PoolDragDragging(rect: rect, ..) ->
      PoolDragDragging(over_my_tasks: False, rect: rect)
    True, PoolDragPendingRect -> PoolDragPendingRect
    True, PoolDragIdle -> PoolDragPendingRect
    False, _ -> PoolDragIdle
  }

  #(
    update_member(model, fn(member) {
      MemberModel(..member, member_pool_drag: next_drag)
    }),
    effect.none(),
  )
}

/// Handle my-tasks drop zone rect fetched.
pub fn handle_pool_my_tasks_rect_fetched(
  model: Model,
  left: Int,
  top: Int,
  width: Int,
  height: Int,
) -> #(Model, Effect(Msg)) {
  let rect = Rect(left: left, top: top, width: width, height: height)
  let next_drag = case model.member.member_pool_drag, model.member.member_drag {
    PoolDragDragging(over_my_tasks: over, ..), _ ->
      PoolDragDragging(over_my_tasks: over, rect: rect)
    PoolDragPendingRect, opt.Some(_) ->
      PoolDragDragging(over_my_tasks: False, rect: rect)
    PoolDragPendingRect, opt.None -> PoolDragIdle
    PoolDragIdle, _ -> PoolDragIdle
  }

  #(
    update_member(model, fn(member) {
      MemberModel(..member, member_pool_drag: next_drag)
    }),
    effect.none(),
  )
}

/// Handle canvas rect fetched.
pub fn handle_canvas_rect_fetched(
  model: Model,
  left: Int,
  top: Int,
) -> #(Model, Effect(Msg)) {
  #(
    update_member(model, fn(member) {
      MemberModel(..member, member_canvas_left: left, member_canvas_top: top)
    }),
    effect.none(),
  )
}

/// Handle drag start event.
pub fn handle_drag_started(
  model: Model,
  task_id: Int,
  offset_x: Int,
  offset_y: Int,
) -> #(Model, Effect(Msg)) {
  let model =
    update_member(model, fn(member) {
      MemberModel(
        ..member,
        member_drag: opt.Some(MemberDrag(
          task_id: task_id,
          offset_x: offset_x,
          offset_y: offset_y,
        )),
        member_pool_drag: PoolDragPendingRect,
      )
    })

  #(
    model,
    effect.from(fn(dispatch) {
      let #(left, top) = client_ffi.element_client_offset("member-canvas")
      dispatch(pool_msg(MemberCanvasRectFetched(left, top)))

      let #(dz_left, dz_top, dz_width, dz_height) =
        client_ffi.element_client_rect("pool-my-tasks")
      dispatch(
        pool_msg(MemberPoolMyTasksRectFetched(
          dz_left,
          dz_top,
          dz_width,
          dz_height,
        )),
      )
    }),
  )
}

/// Handle drag move event.
pub fn handle_drag_moved(
  model: Model,
  client_x: Int,
  client_y: Int,
) -> #(Model, Effect(Msg)) {
  case model.member.member_drag {
    opt.None -> #(model, effect.none())

    opt.Some(drag) -> {
      let MemberDrag(task_id: task_id, offset_x: ox, offset_y: oy) = drag

      let x = client_x - model.member.member_canvas_left - ox
      let y = client_y - model.member.member_canvas_top - oy

      let over_my_tasks =
        pool_drag_over_my_tasks(
          model.member.member_pool_drag,
          client_x,
          client_y,
        )
      let next_drag =
        next_pool_drag_state(model.member.member_pool_drag, over_my_tasks)

      #(
        update_member(model, fn(member) {
          MemberModel(
            ..member,
            member_positions_by_task: dict.insert(
              model.member.member_positions_by_task,
              task_id,
              #(x, y),
            ),
            member_pool_drag: next_drag,
          )
        }),
        effect.none(),
      )
    }
  }
}

/// Handle drag end event.
pub fn handle_drag_ended(model: Model) -> #(Model, Effect(Msg)) {
  case model.member.member_drag {
    opt.None -> #(model, effect.none())

    opt.Some(drag) -> {
      let MemberDrag(task_id: task_id, ..) = drag
      handle_drag_end_for_task(model, task_id)
    }
  }
}

fn pool_drag_over_my_tasks(
  drag_state: PoolDragState,
  client_x: Int,
  client_y: Int,
) -> Bool {
  case drag_state {
    PoolDragDragging(rect: rect, ..) ->
      rect_contains_point(rect, client_x, client_y)
    _ -> False
  }
}

fn next_pool_drag_state(
  drag_state: PoolDragState,
  over_my_tasks: Bool,
) -> PoolDragState {
  case drag_state {
    PoolDragDragging(rect: rect, ..) ->
      PoolDragDragging(over_my_tasks: over_my_tasks, rect: rect)
    PoolDragPendingRect -> PoolDragPendingRect
    PoolDragIdle -> PoolDragIdle
  }
}

fn handle_drag_end_for_task(model: Model, task_id: Int) -> #(Model, Effect(Msg)) {
  let over_my_tasks = is_over_my_tasks(model.member.member_pool_drag)
  let model = clear_pool_drag_state(model)

  case over_my_tasks {
    True -> handle_claim_drop(model, task_id)
    False -> handle_position_drop(model, task_id)
  }
}

fn is_over_my_tasks(drag_state: PoolDragState) -> Bool {
  case drag_state {
    PoolDragDragging(over_my_tasks: over, ..) -> over
    _ -> False
  }
}

fn clear_pool_drag_state(model: Model) -> Model {
  update_member(model, fn(member) {
    MemberModel(..member, member_drag: opt.None, member_pool_drag: PoolDragIdle)
  })
}

fn handle_claim_drop(model: Model, task_id: Int) -> #(Model, Effect(Msg)) {
  case
    update_helpers.find_task_by_id(model.member.member_tasks, task_id),
    model.member.member_task_mutation_in_flight
  {
    opt.Some(Task(version: version, ..)), False -> #(
      update_member(model, fn(member) {
        MemberModel(..member, member_task_mutation_in_flight: True)
      }),
      api_tasks.claim_task(task_id, version, fn(result) {
        pool_msg(MemberTaskClaimed(result))
      }),
    )
    opt.Some(_), True -> #(model, effect.none())
    opt.None, _ -> #(model, effect.none())
  }
}

fn handle_position_drop(model: Model, task_id: Int) -> #(Model, Effect(Msg)) {
  let #(x, y) =
    position_for_task(model.member.member_positions_by_task, task_id)
  #(
    model,
    api_tasks.upsert_me_task_position(task_id, x, y, fn(result) {
      pool_msg(MemberPositionSaved(result))
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

// =============================================================================
// Position Edit Handlers
// =============================================================================

/// Open position edit dialog for a task.
pub fn handle_position_edit_opened(
  model: Model,
  task_id: Int,
) -> #(Model, Effect(Msg)) {
  let #(x, y) = case dict.get(model.member.member_positions_by_task, task_id) {
    Ok(xy) -> xy
    Error(_) -> #(0, 0)
  }

  #(
    update_member(model, fn(member) {
      MemberModel(
        ..member,
        member_position_edit_task: opt.Some(task_id),
        member_position_edit_x: int.to_string(x),
        member_position_edit_y: int.to_string(y),
        member_position_edit_error: opt.None,
      )
    }),
    effect.none(),
  )
}

/// Close position edit dialog.
pub fn handle_position_edit_closed(model: Model) -> #(Model, Effect(Msg)) {
  #(
    update_member(model, fn(member) {
      MemberModel(
        ..member,
        member_position_edit_task: opt.None,
        member_position_edit_error: opt.None,
      )
    }),
    effect.none(),
  )
}

/// Handle position X field change.
pub fn handle_position_edit_x_changed(
  model: Model,
  value: String,
) -> #(Model, Effect(Msg)) {
  #(
    update_member(model, fn(member) {
      MemberModel(..member, member_position_edit_x: value)
    }),
    effect.none(),
  )
}

/// Handle position Y field change.
pub fn handle_position_edit_y_changed(
  model: Model,
  value: String,
) -> #(Model, Effect(Msg)) {
  #(
    update_member(model, fn(member) {
      MemberModel(..member, member_position_edit_y: value)
    }),
    effect.none(),
  )
}

// Justification: nested case improves clarity for branching logic.
/// Handle position edit form submission.
pub fn handle_position_edit_submitted(model: Model) -> #(Model, Effect(Msg)) {
  case model.member.member_position_edit_in_flight {
    True -> #(model, effect.none())
    False ->
      case model.member.member_position_edit_task {
        opt.None -> #(model, effect.none())
        opt.Some(task_id) -> submit_position_edit(model, task_id)
      }
  }
}

fn submit_position_edit(model: Model, task_id: Int) -> #(Model, Effect(Msg)) {
  case
    int.parse(model.member.member_position_edit_x),
    int.parse(model.member.member_position_edit_y)
  {
    Ok(x), Ok(y) -> submit_position_edit_valid(model, task_id, x, y)
    _, _ -> submit_position_edit_invalid(model)
  }
}

fn submit_position_edit_valid(
  model: Model,
  task_id: Int,
  x: Int,
  y: Int,
) -> #(Model, Effect(Msg)) {
  let model =
    update_member(model, fn(member) {
      MemberModel(
        ..member,
        member_position_edit_in_flight: True,
        member_position_edit_error: opt.None,
      )
    })

  #(
    model,
    api_tasks.upsert_me_task_position(task_id, x, y, fn(result) {
      pool_msg(MemberPositionSaved(result))
    }),
  )
}

fn submit_position_edit_invalid(model: Model) -> #(Model, Effect(Msg)) {
  #(
    update_member(model, fn(member) {
      MemberModel(
        ..member,
        member_position_edit_error: opt.Some(update_helpers.i18n_t(
          model,
          i18n_text.InvalidXY,
        )),
      )
    }),
    effect.none(),
  )
}

/// Handle position saved response (success).
pub fn handle_position_saved_ok(
  model: Model,
  pos: TaskPosition,
) -> #(Model, Effect(Msg)) {
  let TaskPosition(task_id: task_id, x: x, y: y, ..) = pos

  #(
    update_member(model, fn(member) {
      MemberModel(
        ..member,
        member_position_edit_in_flight: False,
        member_position_edit_task: opt.None,
        member_positions_by_task: dict.insert(
          model.member.member_positions_by_task,
          task_id,
          #(x, y),
        ),
      )
    }),
    effect.none(),
  )
}

/// Handle position saved response (error).
pub fn handle_position_saved_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  update_helpers.handle_401_or(model, err, fn() {
    #(
      update_member(model, fn(member) {
        MemberModel(
          ..member,
          member_position_edit_in_flight: False,
          member_position_edit_error: opt.Some(err.message),
        )
      }),
      effect.batch([
        api_tasks.list_me_task_positions(
          model.core.selected_project_id,
          fn(result) { pool_msg(client_state.MemberPositionsFetched(result)) },
        ),
        update_helpers.toast_error(err.message),
      ]),
    )
  })
}

/// Handle positions fetched response (success).
pub fn handle_positions_fetched_ok(
  model: Model,
  positions: List(TaskPosition),
) -> #(Model, Effect(Msg)) {
  #(
    update_member(model, fn(member) {
      MemberModel(
        ..member,
        member_positions_by_task: update_helpers.positions_to_dict(positions),
      )
    }),
    effect.none(),
  )
}

/// Handle positions fetched response (error).
pub fn handle_positions_fetched_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  update_helpers.handle_401_or(model, err, fn() { #(model, effect.none()) })
}
