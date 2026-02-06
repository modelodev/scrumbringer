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
//// - **api/tasks.gleam**: Provides position API functions

import gleam/dict
import gleam/int
import gleam/list
import gleam/option as opt
import gleam/string

import lustre/effect

import domain/api_error.{type ApiError, type ApiResult}
import domain/card
import domain/remote.{Failed, Loaded}
import domain/task
import domain/task_status
import scrumbringer_client/api/cards as api_cards
import scrumbringer_client/api/tasks as api_tasks
import scrumbringer_client/app/effects as app_effects
import scrumbringer_client/client_ffi
import scrumbringer_client/client_state
import scrumbringer_client/client_state/admin as admin_state
import scrumbringer_client/client_state/admin/cards as admin_cards
import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/notes as member_notes
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/client_state/member/positions as member_positions
import scrumbringer_client/client_state/member/skills as member_skills
import scrumbringer_client/client_state/types.{
  type PoolDragState, DragActive, DragIdle, DragPending, PoolDragDragging,
  PoolDragIdle, PoolDragPendingRect, Rect, rect_contains_point,
}
import scrumbringer_client/features/cards/update as cards_workflow
import scrumbringer_client/features/metrics/update as metrics_workflow
import scrumbringer_client/features/milestones/ids as milestone_ids
import scrumbringer_client/features/milestones/update as milestones_workflow
import scrumbringer_client/features/now_working/update as now_working_workflow
import scrumbringer_client/features/people/update as people_workflow
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/skills/update as skills_workflow
import scrumbringer_client/features/tasks/update as tasks_workflow
import scrumbringer_client/features/workflows/update as workflows_workflow
import scrumbringer_client/helpers/auth as helpers_auth
import scrumbringer_client/helpers/dicts as helpers_dicts
import scrumbringer_client/helpers/i18n as helpers_i18n
import scrumbringer_client/helpers/lookup as helpers_lookup
import scrumbringer_client/helpers/options as helpers_options
import scrumbringer_client/helpers/toast as helpers_toast
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/member_section
import scrumbringer_client/pool_prefs
import scrumbringer_client/router
import scrumbringer_client/state/normalized_store
import scrumbringer_client/theme
import scrumbringer_client/url_state

// =============================================================================
// Filter Handlers
// =============================================================================

/// Handle pool status filter change.
pub fn handle_pool_status_changed(
  model: client_state.Model,
  value: String,
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let next_status = case string.trim(value) {
    "" -> opt.None
    _ ->
      case task_status.parse_task_status(value) {
        Ok(status) -> opt.Some(status)
        Error(_) -> opt.None
      }
  }
  let model =
    update_member_pool(model, fn(pool) {
      member_pool.Model(..pool, member_filters_status: next_status)
    })
  member_refresh(model)
}

/// Handle pool type filter change.
pub fn handle_pool_type_changed(
  model: client_state.Model,
  value: String,
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let next_type_id = helpers_options.empty_to_int_opt(value)
  let model =
    update_member_pool(model, fn(pool) {
      member_pool.Model(..pool, member_filters_type_id: next_type_id)
    })
  member_refresh(model)
}

/// Handle pool capability filter change.
pub fn handle_pool_capability_changed(
  model: client_state.Model,
  value: String,
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let next_capability_id = helpers_options.empty_to_int_opt(value)
  let model =
    update_member_pool(model, fn(pool) {
      member_pool.Model(
        ..pool,
        member_filters_capability_id: next_capability_id,
      )
    })
  member_refresh(model)
}

/// Handle pool search input change (no refresh yet).
pub fn handle_pool_search_changed(
  model: client_state.Model,
  value: String,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  #(
    update_member_pool(model, fn(pool) {
      member_pool.Model(..pool, member_filters_q: value)
    }),
    effect.none(),
  )
}

/// Handle pool search debounced (triggers refresh).
pub fn handle_pool_search_debounced(
  model: client_state.Model,
  value: String,
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let model =
    update_member_pool(model, fn(pool) {
      member_pool.Model(..pool, member_filters_q: value)
    })
  member_refresh(model)
}

/// Clear all pool filters at once.
pub fn handle_clear_filters(
  model: client_state.Model,
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let model =
    update_member_pool(model, fn(pool) {
      member_pool.Model(
        ..pool,
        member_filters_status: opt.None,
        member_filters_type_id: opt.None,
        member_filters_capability_id: opt.None,
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
  model: client_state.Model,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  #(
    update_member_pool(model, fn(pool) {
      member_pool.Model(
        ..pool,
        member_quick_my_caps: !model.member.pool.member_quick_my_caps,
      )
    }),
    effect.none(),
  )
}

/// Toggle pool filters visibility.
pub fn handle_pool_filters_toggled(
  model: client_state.Model,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let next = !model.member.pool.member_pool_filters_visible
  #(
    update_member_pool(model, fn(pool) {
      member_pool.Model(..pool, member_pool_filters_visible: next)
    }),
    save_pool_filters_visible_effect(next),
  )
}

/// Set pool view mode (grid/list).
pub fn handle_pool_view_mode_set(
  model: client_state.Model,
  mode: pool_prefs.ViewMode,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  #(
    update_member_pool(model, fn(pool) {
      member_pool.Model(..pool, member_pool_view_mode: mode)
    }),
    save_pool_view_mode_effect(mode),
  )
}

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

// =============================================================================
// Keyboard Shortcuts
// =============================================================================

/// Handle global keydown events for pool shortcuts.
pub fn handle_global_keydown(
  model: client_state.Model,
  event: pool_prefs.KeyEvent,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case is_pool_shortcut_target(model) {
    False -> #(model, effect.none())
    True -> handle_pool_shortcut_action(model, event)
  }
}

fn is_pool_shortcut_target(model: client_state.Model) -> Bool {
  model.core.page == client_state.Member
  && model.member.pool.member_section == member_section.Pool
}

fn handle_pool_shortcut_action(
  model: client_state.Model,
  event: pool_prefs.KeyEvent,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case pool_prefs.shortcut_action(event) {
    pool_prefs.NoAction -> #(model, effect.none())
    pool_prefs.ToggleFilters -> toggle_filters_shortcut(model)
    pool_prefs.FocusSearch -> focus_search_shortcut(model)
    pool_prefs.OpenCreate -> open_create_shortcut(model)
    pool_prefs.CloseDialog -> close_dialog_shortcut(model)
  }
}

fn toggle_filters_shortcut(
  model: client_state.Model,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let next = !model.member.pool.member_pool_filters_visible
  #(
    update_member_pool(model, fn(pool) {
      member_pool.Model(..pool, member_pool_filters_visible: next)
    }),
    save_pool_filters_visible_effect(next),
  )
}

fn focus_search_shortcut(
  model: client_state.Model,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let should_show = !model.member.pool.member_pool_filters_visible
  let model =
    update_member_pool(model, fn(pool) {
      member_pool.Model(..pool, member_pool_filters_visible: True)
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

fn open_create_shortcut(
  model: client_state.Model,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case model.member.pool.member_create_dialog_mode {
    dialog_mode.DialogCreate -> #(model, effect.none())
    _ -> #(
      update_member_pool(model, fn(pool) {
        member_pool.Model(
          ..pool,
          member_create_dialog_mode: dialog_mode.DialogCreate,
        )
      }),
      effect.none(),
    )
  }
}

fn close_dialog_shortcut(
  model: client_state.Model,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case
    model.member.pool.member_create_dialog_mode,
    model.member.pool.member_milestone_dialog,
    opt.is_some(model.member.notes.member_notes_task_id),
    opt.is_some(model.member.positions.member_position_edit_task)
  {
    dialog_mode.DialogCreate, _, _, _ -> #(
      update_member_pool(model, fn(pool) {
        member_pool.Model(
          ..pool,
          member_create_dialog_mode: dialog_mode.DialogClosed,
        )
      }),
      effect.none(),
    )
    _, member_pool.MilestoneDialogActivate(id), _, _ -> #(
      update_member_pool(model, fn(pool) {
        member_pool.Model(
          ..pool,
          member_milestone_dialog: member_pool.MilestoneDialogClosed,
          member_milestone_dialog_in_flight: False,
          member_milestone_dialog_error: opt.None,
        )
      }),
      app_effects.focus_element_after_timeout(
        milestone_ids.activate_button_id(id),
        0,
      ),
    )
    _, member_pool.MilestoneDialogEdit(id: id, ..), _, _ -> #(
      update_member_pool(model, fn(pool) {
        member_pool.Model(
          ..pool,
          member_milestone_dialog: member_pool.MilestoneDialogClosed,
          member_milestone_dialog_in_flight: False,
          member_milestone_dialog_error: opt.None,
        )
      }),
      app_effects.focus_element_after_timeout(
        milestone_ids.edit_button_id(id),
        0,
      ),
    )
    _, member_pool.MilestoneDialogDelete(id: id, ..), _, _ -> #(
      update_member_pool(model, fn(pool) {
        member_pool.Model(
          ..pool,
          member_milestone_dialog: member_pool.MilestoneDialogClosed,
          member_milestone_dialog_in_flight: False,
          member_milestone_dialog_error: opt.None,
        )
      }),
      app_effects.focus_element_after_timeout(
        milestone_ids.delete_button_id(id),
        0,
      ),
    )
    _, member_pool.MilestoneDialogView(id: id), _, _ -> #(
      update_member_pool(model, fn(pool) {
        member_pool.Model(
          ..pool,
          member_milestone_dialog: member_pool.MilestoneDialogClosed,
          member_milestone_dialog_in_flight: False,
          member_milestone_dialog_error: opt.None,
        )
      }),
      app_effects.focus_element_after_timeout(
        milestone_ids.details_button_id(id),
        0,
      ),
    )
    _, _, True, _ -> #(
      update_member_notes(model, fn(notes) {
        member_notes.Model(..notes, member_notes_task_id: opt.None)
      }),
      effect.none(),
    )
    _, _, _, True -> #(
      update_member_positions(model, fn(positions) {
        member_positions.Model(
          ..positions,
          member_position_edit_task: opt.None,
          member_position_edit_error: opt.None,
        )
      }),
      effect.none(),
    )
    _, _, _, _ -> #(model, effect.none())
  }
}

// =============================================================================
// Drag-and-Drop Handlers
// =============================================================================

/// Handle touch start on a task card (tap/long-press).
pub fn handle_pool_touch_started(
  model: client_state.Model,
  task_id: Int,
  client_x: Int,
  client_y: Int,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let #(model, hover_fx) = ensure_hover_notes(model, task_id)
  let model =
    update_member_pool(model, fn(pool) {
      member_pool.Model(
        ..pool,
        member_pool_touch_task_id: opt.Some(task_id),
        member_pool_touch_longpress: opt.None,
        member_pool_touch_client_x: client_x,
        member_pool_touch_client_y: client_y,
      )
    })

  #(
    model,
    effect.batch([
      hover_fx,
      app_effects.schedule_timeout(450, fn() {
        client_state.pool_msg(pool_messages.MemberPoolLongPressCheck(task_id))
      }),
    ]),
  )
}

pub fn handle_task_hover_opened(
  model: client_state.Model,
  task_id: Int,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let #(next, fx) = ensure_hover_notes(model, task_id)
  #(open_blocker_highlight(next, task_id), fx)
}

pub fn handle_task_hover_closed(
  model: client_state.Model,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  #(
    update_member_pool(model, fn(pool) {
      member_pool.Model(..pool, member_highlight_state: member_pool.NoHighlight)
    }),
    effect.none(),
  )
}

pub fn handle_task_focused(
  model: client_state.Model,
  task_id: Int,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let #(next, fx) = ensure_hover_notes(model, task_id)
  #(open_blocker_highlight(next, task_id), fx)
}

pub fn handle_task_blurred(
  model: client_state.Model,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  handle_task_hover_closed(model)
}

pub fn handle_task_created_feedback(
  model: client_state.Model,
  task_id: Int,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  #(
    update_member_pool(model, fn(pool) {
      member_pool.Model(
        ..pool,
        member_highlight_state: member_pool.CreatedHighlight(task_id),
      )
    }),
    effect.none(),
  )
}

pub fn handle_highlight_expired(
  model: client_state.Model,
  task_id: Int,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let next_highlight = case model.member.pool.member_highlight_state {
    member_pool.CreatedHighlight(id) if id == task_id -> member_pool.NoHighlight
    state -> state
  }

  #(
    update_member_pool(model, fn(pool) {
      member_pool.Model(..pool, member_highlight_state: next_highlight)
    }),
    effect.none(),
  )
}

fn open_blocker_highlight(
  model: client_state.Model,
  task_id: Int,
) -> client_state.Model {
  let next_state = case
    helpers_lookup.find_task_by_id(model.member.pool.member_tasks, task_id)
  {
    opt.Some(task.Task(dependencies: dependencies, ..)) -> {
      let blocker_ids =
        dependencies
        |> list.filter(fn(dep) { dep.status != task_status.Completed })
        |> list.map(fn(dep) { dep.depends_on_task_id })

      case blocker_ids {
        [] -> member_pool.NoHighlight
        _ -> {
          let total_blockers = list.length(blocker_ids)
          let visible_blockers =
            visible_blockers_count(model.member.pool.member_tasks, blocker_ids)
          let hidden_count = case total_blockers - visible_blockers {
            n if n < 0 -> 0
            n -> n
          }

          member_pool.BlockingHighlight(task_id, blocker_ids, hidden_count)
        }
      }
    }
    opt.None -> member_pool.NoHighlight
  }

  update_member_pool(model, fn(pool) {
    member_pool.Model(..pool, member_highlight_state: next_state)
  })
}

fn visible_blockers_count(tasks_remote, blocker_ids: List(Int)) -> Int {
  case tasks_remote {
    Loaded(tasks) ->
      blocker_ids
      |> list.filter(fn(blocker_id) {
        list.any(tasks, fn(t) {
          let task.Task(id: task_id, ..) = t
          task_id == blocker_id
        })
      })
      |> list.length
    _ -> 0
  }
}

/// Handle touch end on a task card.
pub fn handle_pool_touch_ended(
  model: client_state.Model,
  task_id: Int,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case model.member.pool.member_pool_touch_longpress {
    opt.Some(id) if id == task_id -> {
      let #(model, fx) = handle_drag_ended(model)
      let model =
        update_member_pool(model, fn(pool) {
          member_pool.Model(
            ..pool,
            member_pool_touch_task_id: opt.None,
            member_pool_touch_longpress: opt.None,
            member_pool_touch_client_x: 0,
            member_pool_touch_client_y: 0,
          )
        })
      #(model, fx)
    }
    _ -> {
      let next_preview = case model.member.pool.member_pool_preview_task_id {
        opt.Some(id) if id == task_id -> opt.None
        _ -> opt.Some(task_id)
      }
      #(
        update_member_pool(model, fn(pool) {
          member_pool.Model(
            ..pool,
            member_pool_preview_task_id: next_preview,
            member_pool_touch_task_id: opt.None,
            member_pool_touch_longpress: opt.None,
            member_pool_touch_client_x: 0,
            member_pool_touch_client_y: 0,
          )
        }),
        effect.none(),
      )
    }
  }
}

/// Handle long-press check for touch drag.
pub fn handle_pool_long_press_check(
  model: client_state.Model,
  task_id: Int,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case model.member.pool.member_pool_touch_task_id {
    opt.Some(id) if id == task_id -> {
      let #(model, fx) =
        handle_drag_started(
          model,
          task_id,
          model.member.pool.member_pool_touch_client_x,
          model.member.pool.member_pool_touch_client_y,
        )
      let model =
        update_member_pool(model, fn(pool) {
          member_pool.Model(
            ..pool,
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
  model: client_state.Model,
  armed: Bool,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let next_drag = case armed, model.member.pool.member_pool_drag {
    True, PoolDragDragging(rect: rect, ..) ->
      PoolDragDragging(over_my_tasks: False, rect: rect)
    True, PoolDragPendingRect -> PoolDragPendingRect
    True, PoolDragIdle -> PoolDragPendingRect
    False, _ -> PoolDragIdle
  }

  #(
    update_member_pool(model, fn(pool) {
      member_pool.Model(..pool, member_pool_drag: next_drag)
    }),
    effect.none(),
  )
}

/// Handle my-tasks drop zone rect fetched.
pub fn handle_pool_my_tasks_rect_fetched(
  model: client_state.Model,
  left: Int,
  top: Int,
  width: Int,
  height: Int,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let rect = Rect(left: left, top: top, width: width, height: height)
  let next_drag = case
    model.member.pool.member_pool_drag,
    model.member.pool.member_drag
  {
    PoolDragDragging(over_my_tasks: over, ..), _ ->
      PoolDragDragging(over_my_tasks: over, rect: rect)
    PoolDragPendingRect, DragIdle -> PoolDragIdle
    PoolDragPendingRect, _ -> PoolDragDragging(over_my_tasks: False, rect: rect)
    PoolDragIdle, _ -> PoolDragIdle
  }

  #(
    update_member_pool(model, fn(pool) {
      member_pool.Model(..pool, member_pool_drag: next_drag)
    }),
    effect.none(),
  )
}

/// Handle canvas rect fetched.
pub fn handle_canvas_rect_fetched(
  model: client_state.Model,
  left: Int,
  top: Int,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  #(
    update_member_positions(model, fn(positions) {
      member_positions.Model(
        ..positions,
        member_canvas_left: left,
        member_canvas_top: top,
      )
    }),
    effect.none(),
  )
}

/// Handle drag start event.
pub fn handle_drag_started(
  model: client_state.Model,
  task_id: Int,
  client_x: Int,
  client_y: Int,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let model =
    update_member_pool(model, fn(pool) {
      member_pool.Model(
        ..pool,
        member_drag: DragPending(task_id),
        member_pool_drag: PoolDragPendingRect,
      )
    })

  #(
    model,
    effect.from(fn(dispatch) {
      let #(left, top) = client_ffi.element_client_offset("member-canvas")
      dispatch(
        client_state.pool_msg(pool_messages.MemberCanvasRectFetched(left, top)),
      )

      let #(card_left, card_top, _width, _height) =
        client_ffi.element_client_rect("task-card-" <> int.to_string(task_id))
      let offset_x = client_x - card_left
      let offset_y = client_y - card_top
      dispatch(
        client_state.pool_msg(pool_messages.MemberDragOffsetResolved(
          task_id,
          offset_x,
          offset_y,
        )),
      )

      let #(dz_left, dz_top, dz_width, dz_height) =
        client_ffi.element_client_rect("pool-my-tasks")
      dispatch(
        client_state.pool_msg(pool_messages.MemberPoolMyTasksRectFetched(
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
  model: client_state.Model,
  client_x: Int,
  client_y: Int,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case model.member.pool.member_drag {
    DragIdle -> #(model, effect.none())
    DragPending(_) -> #(
      update_member_pool(model, fn(pool) {
        member_pool.Model(
          ..pool,
          member_pool_drag: next_pool_drag_state(
            model.member.pool.member_pool_drag,
            pool_drag_over_my_tasks(
              model.member.pool.member_pool_drag,
              client_x,
              client_y,
            ),
          ),
        )
      }),
      effect.none(),
    )
    DragActive(task_id, ox, oy) -> {
      let over_my_tasks =
        pool_drag_over_my_tasks(
          model.member.pool.member_pool_drag,
          client_x,
          client_y,
        )
      let next_drag =
        next_pool_drag_state(model.member.pool.member_pool_drag, over_my_tasks)

      let x = client_x - model.member.positions.member_canvas_left - ox
      let y = client_y - model.member.positions.member_canvas_top - oy

      #(
        client_state.update_member(model, fn(member) {
          let pool = member.pool
          let positions = member.positions

          member_state.MemberModel(
            ..member,
            positions: member_positions.Model(
              ..positions,
              member_positions_by_task: dict.insert(
                positions.member_positions_by_task,
                task_id,
                #(x, y),
              ),
            ),
            pool: member_pool.Model(..pool, member_pool_drag: next_drag),
          )
        }),
        effect.none(),
      )
    }
  }
}

pub fn handle_drag_offset_resolved(
  model: client_state.Model,
  task_id: Int,
  offset_x: Int,
  offset_y: Int,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let updated = case model.member.pool.member_drag {
    DragPending(drag_task_id) ->
      case drag_task_id == task_id {
        True -> DragActive(task_id, offset_x, offset_y)
        False -> model.member.pool.member_drag
      }
    DragActive(_, _, _) -> model.member.pool.member_drag
    DragIdle -> DragIdle
  }

  #(
    update_member_pool(model, fn(pool) {
      member_pool.Model(..pool, member_drag: updated)
    }),
    effect.none(),
  )
}

pub fn handle_task_hover_notes_fetched(
  model: client_state.Model,
  task_id: Int,
  result: ApiResult(List(task.TaskNote)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let model =
    update_member_notes(model, fn(notes) {
      member_notes.Model(
        ..notes,
        member_hover_notes_pending: dict.delete(
          model.member.notes.member_hover_notes_pending,
          task_id,
        ),
      )
    })

  case result {
    Ok(notes) -> {
      let trimmed = take_last_notes(notes, 2)
      #(
        update_member_notes(model, fn(notes) {
          member_notes.Model(
            ..notes,
            member_hover_notes_cache: dict.insert(
              model.member.notes.member_hover_notes_cache,
              task_id,
              trimmed,
            ),
          )
        }),
        effect.none(),
      )
    }
    Error(_err) -> #(model, effect.none())
  }
}

fn ensure_hover_notes(
  model: client_state.Model,
  task_id: Int,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let cached = dict.get(model.member.notes.member_hover_notes_cache, task_id)
  let pending = dict.get(model.member.notes.member_hover_notes_pending, task_id)

  case cached, pending {
    Ok(_), _ -> #(model, effect.none())
    _, Ok(_) -> #(model, effect.none())
    _, _ -> {
      let model =
        update_member_notes(model, fn(notes) {
          member_notes.Model(
            ..notes,
            member_hover_notes_pending: dict.insert(
              model.member.notes.member_hover_notes_pending,
              task_id,
              True,
            ),
          )
        })

      let notes_fx =
        api_tasks.list_task_notes(task_id, fn(result) {
          client_state.pool_msg(pool_messages.MemberTaskHoverNotesFetched(
            task_id,
            result,
          ))
        })

      #(model, notes_fx)
    }
  }
}

fn take_last_notes(
  notes: List(task.TaskNote),
  count: Int,
) -> List(task.TaskNote) {
  let total = list.length(notes)
  case total <= count {
    True -> notes
    False -> list.drop(notes, total - count)
  }
}

/// Handle drag end event.
pub fn handle_drag_ended(
  model: client_state.Model,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case model.member.pool.member_drag {
    DragIdle -> #(model, effect.none())
    DragPending(task_id) -> handle_drag_end_for_task(model, task_id)
    DragActive(task_id, _, _) -> handle_drag_end_for_task(model, task_id)
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

fn handle_drag_end_for_task(
  model: client_state.Model,
  task_id: Int,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let over_my_tasks = is_over_my_tasks(model.member.pool.member_pool_drag)
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

fn clear_pool_drag_state(model: client_state.Model) -> client_state.Model {
  update_member_pool(model, fn(pool) {
    member_pool.Model(
      ..pool,
      member_drag: DragIdle,
      member_pool_drag: PoolDragIdle,
    )
  })
}

fn handle_claim_drop(
  model: client_state.Model,
  task_id: Int,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case
    helpers_lookup.find_task_by_id(model.member.pool.member_tasks, task_id),
    model.member.pool.member_task_mutation_in_flight
  {
    opt.Some(task.Task(version: version, ..)), False -> #(
      update_member_pool(model, fn(pool) {
        member_pool.Model(..pool, member_task_mutation_in_flight: True)
      }),
      api_tasks.claim_task(task_id, version, fn(result) {
        client_state.pool_msg(pool_messages.MemberTaskClaimed(result))
      }),
    )
    opt.Some(_), True -> #(model, effect.none())
    opt.None, _ -> #(model, effect.none())
  }
}

fn handle_position_drop(
  model: client_state.Model,
  task_id: Int,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let #(x, y) =
    position_for_task(model.member.positions.member_positions_by_task, task_id)
  #(
    model,
    api_tasks.upsert_me_task_position(task_id, x, y, fn(result) {
      client_state.pool_msg(pool_messages.MemberPositionSaved(result))
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
  model: client_state.Model,
  task_id: Int,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let #(x, y) = case
    dict.get(model.member.positions.member_positions_by_task, task_id)
  {
    Ok(xy) -> xy
    Error(_) -> #(0, 0)
  }

  #(
    update_member_positions(model, fn(positions) {
      member_positions.Model(
        ..positions,
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
pub fn handle_position_edit_closed(
  model: client_state.Model,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  #(
    update_member_positions(model, fn(positions) {
      member_positions.Model(
        ..positions,
        member_position_edit_task: opt.None,
        member_position_edit_error: opt.None,
      )
    }),
    effect.none(),
  )
}

/// Handle position X field change.
pub fn handle_position_edit_x_changed(
  model: client_state.Model,
  value: String,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  #(
    update_member_positions(model, fn(positions) {
      member_positions.Model(..positions, member_position_edit_x: value)
    }),
    effect.none(),
  )
}

/// Handle position Y field change.
pub fn handle_position_edit_y_changed(
  model: client_state.Model,
  value: String,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  #(
    update_member_positions(model, fn(positions) {
      member_positions.Model(..positions, member_position_edit_y: value)
    }),
    effect.none(),
  )
}

// Justification: nested case improves clarity for branching logic.
/// Handle position edit form submission.
pub fn handle_position_edit_submitted(
  model: client_state.Model,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case model.member.positions.member_position_edit_in_flight {
    True -> #(model, effect.none())
    False ->
      case model.member.positions.member_position_edit_task {
        opt.None -> #(model, effect.none())
        opt.Some(task_id) -> submit_position_edit(model, task_id)
      }
  }
}

fn submit_position_edit(
  model: client_state.Model,
  task_id: Int,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case
    int.parse(model.member.positions.member_position_edit_x),
    int.parse(model.member.positions.member_position_edit_y)
  {
    Ok(x), Ok(y) -> submit_position_edit_valid(model, task_id, x, y)
    _, _ -> submit_position_edit_invalid(model)
  }
}

fn submit_position_edit_valid(
  model: client_state.Model,
  task_id: Int,
  x: Int,
  y: Int,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let model =
    update_member_positions(model, fn(positions) {
      member_positions.Model(
        ..positions,
        member_position_edit_in_flight: True,
        member_position_edit_error: opt.None,
      )
    })

  #(
    model,
    api_tasks.upsert_me_task_position(task_id, x, y, fn(result) {
      client_state.pool_msg(pool_messages.MemberPositionSaved(result))
    }),
  )
}

fn submit_position_edit_invalid(
  model: client_state.Model,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  #(
    update_member_positions(model, fn(positions) {
      member_positions.Model(
        ..positions,
        member_position_edit_error: opt.Some(helpers_i18n.i18n_t(
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
  model: client_state.Model,
  pos: task.TaskPosition,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let task.TaskPosition(task_id: task_id, x: x, y: y, ..) = pos

  #(
    update_member_positions(model, fn(positions) {
      member_positions.Model(
        ..positions,
        member_position_edit_in_flight: False,
        member_position_edit_task: opt.None,
        member_positions_by_task: dict.insert(
          positions.member_positions_by_task,
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
  model: client_state.Model,
  err: ApiError,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  helpers_auth.handle_401_or(model, err, fn() {
    #(
      update_member_positions(model, fn(positions) {
        member_positions.Model(
          ..positions,
          member_position_edit_in_flight: False,
          member_position_edit_error: opt.Some(err.message),
        )
      }),
      effect.batch([
        api_tasks.list_me_task_positions(
          model.core.selected_project_id,
          fn(result) {
            client_state.pool_msg(pool_messages.MemberPositionsFetched(result))
          },
        ),
        helpers_toast.toast_error(err.message),
      ]),
    )
  })
}

/// Handle positions fetched response (success).
pub fn handle_positions_fetched_ok(
  model: client_state.Model,
  positions: List(task.TaskPosition),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  #(
    update_member_positions(model, fn(positions_state) {
      member_positions.Model(
        ..positions_state,
        member_positions_by_task: helpers_dicts.positions_to_dict(positions),
      )
    }),
    effect.none(),
  )
}

/// Handle positions fetched response (error).
pub fn handle_positions_fetched_error(
  model: client_state.Model,
  err: ApiError,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  helpers_auth.handle_401_or(model, err, fn() { #(model, effect.none()) })
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
/// Justification: large function kept intact to preserve cohesive UI logic.
pub fn update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  ctx: Context,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let Context(member_refresh: member_refresh) = ctx

  case milestones_workflow.try_update(model, inner, member_refresh) {
    opt.Some(result) -> result
    opt.None -> update_without_milestones(model, inner, member_refresh)
  }
}

fn update_without_milestones(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case inner {
    pool_messages.MemberPoolMyTasksRectFetched(left, top, width, height) ->
      handle_pool_my_tasks_rect_fetched(model, left, top, width, height)
    pool_messages.MemberPoolDragToClaimArmed(armed) ->
      handle_pool_drag_to_claim_armed(model, armed)
    pool_messages.MemberPoolStatusChanged(v) ->
      handle_pool_status_changed(model, v, member_refresh)
    pool_messages.MemberPoolTypeChanged(v) ->
      handle_pool_type_changed(model, v, member_refresh)
    pool_messages.MemberPoolCapabilityChanged(v) ->
      handle_pool_capability_changed(model, v, member_refresh)

    pool_messages.MemberToggleMyCapabilitiesQuick ->
      handle_toggle_my_capabilities_quick(model)
    pool_messages.MemberPoolFiltersToggled -> handle_pool_filters_toggled(model)
    pool_messages.MemberClearFilters ->
      handle_clear_filters(model, member_refresh)
    pool_messages.MemberPoolViewModeSet(mode) ->
      handle_pool_view_mode_set(model, mode)
    pool_messages.MemberPoolTouchStarted(task_id, client_x, client_y) ->
      handle_pool_touch_started(model, task_id, client_x, client_y)
    pool_messages.MemberPoolTouchEnded(task_id) ->
      handle_pool_touch_ended(model, task_id)
    pool_messages.MemberPoolLongPressCheck(task_id) ->
      handle_pool_long_press_check(model, task_id)
    pool_messages.MemberTaskHoverOpened(task_id) ->
      handle_task_hover_opened(model, task_id)
    pool_messages.MemberTaskHoverClosed -> handle_task_hover_closed(model)
    pool_messages.MemberTaskFocused(task_id) ->
      handle_task_focused(model, task_id)
    pool_messages.MemberTaskBlurred -> handle_task_blurred(model)
    pool_messages.MemberTaskCreatedFeedback(task_id) ->
      handle_task_created_feedback(model, task_id)
    pool_messages.MemberHighlightExpired(task_id) ->
      handle_highlight_expired(model, task_id)
    pool_messages.MemberTaskHoverNotesFetched(task_id, result) ->
      handle_task_hover_notes_fetched(model, task_id, result)
    pool_messages.MemberListHideCompletedToggled -> #(
      client_state.update_member(model, fn(member) {
        let pool = member.pool
        member_state.MemberModel(
          ..member,
          pool: member_pool.Model(
            ..pool,
            member_list_hide_completed: !model.member.pool.member_list_hide_completed,
          ),
        )
      }),
      effect.none(),
    )
    // Story 4.8 UX: Collapse/expand card groups in Lista view
    pool_messages.MemberListCardToggled(card_id) -> {
      let current =
        dict.get(model.member.pool.member_list_expanded_cards, card_id)
        |> opt.from_result
        |> opt.unwrap(True)
      let new_cards =
        dict.insert(
          model.member.pool.member_list_expanded_cards,
          card_id,
          !current,
        )
      #(
        client_state.update_member(model, fn(member) {
          let pool = member.pool
          member_state.MemberModel(
            ..member,
            pool: member_pool.Model(
              ..pool,
              member_list_expanded_cards: new_cards,
            ),
          )
        }),
        effect.none(),
      )
    }
    pool_messages.ViewModeChanged(mode) -> {
      let new_model =
        client_state.update_member(model, fn(member) {
          let pool = member.pool
          member_state.MemberModel(
            ..member,
            pool: member_pool.Model(..pool, view_mode: mode),
          )
        })
      let state = case model.core.selected_project_id {
        opt.Some(project_id) ->
          url_state.with_project(url_state.empty(), project_id)
        opt.None -> url_state.empty()
      }
      let state = url_state.with_view(state, mode)
      let route = router.Member(model.member.pool.member_section, state)
      #(new_model, router.replace(route))
    }
    pool_messages.GlobalKeyDown(event) -> handle_global_keydown(model, event)

    pool_messages.MemberPoolSearchChanged(v) ->
      handle_pool_search_changed(model, v)
    pool_messages.MemberPoolSearchDebounced(v) ->
      handle_pool_search_debounced(model, v, member_refresh)

    pool_messages.MemberProjectTasksFetched(project_id, Ok(tasks)) -> {
      let tasks_by_project =
        dict.insert(
          model.member.pool.member_tasks_by_project,
          project_id,
          tasks,
        )
      let pending = model.member.pool.member_tasks_pending - 1

      let model =
        client_state.update_member(model, fn(member) {
          let pool = member.pool
          member_state.MemberModel(
            ..member,
            pool: member_pool.Model(
              ..pool,
              member_tasks_by_project: tasks_by_project,
              member_tasks_pending: pending,
            ),
          )
        })

      case pending <= 0 {
        True -> #(
          client_state.update_member(model, fn(member) {
            let pool = member.pool
            member_state.MemberModel(
              ..member,
              pool: member_pool.Model(
                ..pool,
                member_tasks: Loaded(helpers_dicts.flatten_tasks(
                  tasks_by_project,
                )),
              ),
            )
          }),
          effect.none(),
        )
        False -> #(model, effect.none())
      }
    }

    pool_messages.MemberPeopleRosterFetched(Ok(members)) ->
      people_workflow.handle_roster_fetched_ok(model, members)

    pool_messages.MemberPeopleRosterFetched(Error(err)) ->
      people_workflow.handle_roster_fetched_error(model, err)

    pool_messages.MemberPeopleRowToggled(user_id) ->
      people_workflow.handle_row_toggled(model, user_id)

    pool_messages.MemberProjectTasksFetched(_project_id, Error(err)) -> {
      case err.status {
        401 -> #(
          client_state.update_member(
            client_state.update_core(model, fn(core) {
              client_state.CoreModel(
                ..core,
                page: client_state.Login,
                user: opt.None,
              )
            }),
            fn(member) {
              let pool = member.pool
              member_state.MemberModel(
                ..member,
                pool: member_pool.Model(
                  ..pool,
                  member_drag: DragIdle,
                  member_pool_drag: PoolDragIdle,
                ),
              )
            },
          ),
          effect.none(),
        )
        _ -> #(
          client_state.update_member(model, fn(member) {
            let pool = member.pool
            member_state.MemberModel(
              ..member,
              pool: member_pool.Model(
                ..pool,
                member_tasks: Failed(err),
                member_tasks_pending: 0,
              ),
            )
          }),
          effect.none(),
        )
      }
    }

    pool_messages.MemberTaskTypesFetched(project_id, Ok(task_types)) -> {
      let task_types_by_project =
        dict.insert(
          model.member.pool.member_task_types_by_project,
          project_id,
          task_types,
        )
      let pending = model.member.pool.member_task_types_pending - 1

      let model =
        client_state.update_member(model, fn(member) {
          let pool = member.pool
          member_state.MemberModel(
            ..member,
            pool: member_pool.Model(
              ..pool,
              member_task_types_by_project: task_types_by_project,
              member_task_types_pending: pending,
            ),
          )
        })

      case pending <= 0 {
        True -> #(
          client_state.update_member(model, fn(member) {
            let pool = member.pool
            member_state.MemberModel(
              ..member,
              pool: member_pool.Model(
                ..pool,
                member_task_types: Loaded(helpers_dicts.flatten_task_types(
                  task_types_by_project,
                )),
              ),
            )
          }),
          effect.none(),
        )
        False -> #(model, effect.none())
      }
    }

    pool_messages.MemberTaskTypesFetched(_project_id, Error(err)) -> {
      case err.status {
        401 -> #(
          client_state.update_member(
            client_state.update_core(model, fn(core) {
              client_state.CoreModel(
                ..core,
                page: client_state.Login,
                user: opt.None,
              )
            }),
            fn(member) {
              let pool = member.pool
              member_state.MemberModel(
                ..member,
                pool: member_pool.Model(
                  ..pool,
                  member_drag: DragIdle,
                  member_pool_drag: PoolDragIdle,
                ),
              )
            },
          ),
          effect.none(),
        )
        _ -> #(
          client_state.update_member(model, fn(member) {
            let pool = member.pool
            member_state.MemberModel(
              ..member,
              pool: member_pool.Model(
                ..pool,
                member_task_types: Failed(err),
                member_task_types_pending: 0,
              ),
            )
          }),
          effect.none(),
        )
      }
    }

    pool_messages.MemberCanvasRectFetched(left, top) ->
      handle_canvas_rect_fetched(model, left, top)
    pool_messages.MemberDragStarted(task_id, client_x, client_y) ->
      handle_drag_started(model, task_id, client_x, client_y)
    pool_messages.MemberDragOffsetResolved(task_id, offset_x, offset_y) ->
      handle_drag_offset_resolved(model, task_id, offset_x, offset_y)
    pool_messages.MemberDragMoved(client_x, client_y) ->
      handle_drag_moved(model, client_x, client_y)
    pool_messages.MemberDragEnded -> handle_drag_ended(model)

    pool_messages.MemberCreateDialogOpened ->
      tasks_workflow.handle_create_dialog_opened(model)
    pool_messages.MemberCreateDialogOpenedWithCard(card_id) ->
      tasks_workflow.handle_create_dialog_opened_with_card(model, card_id)
    pool_messages.MemberCreateDialogClosed ->
      tasks_workflow.handle_create_dialog_closed(model)
    pool_messages.MemberCreateTitleChanged(v) ->
      tasks_workflow.handle_create_title_changed(model, v)
    pool_messages.MemberCreateDescriptionChanged(v) ->
      tasks_workflow.handle_create_description_changed(model, v)
    pool_messages.MemberCreatePriorityChanged(v) ->
      tasks_workflow.handle_create_priority_changed(model, v)
    pool_messages.MemberCreateTypeIdChanged(v) ->
      tasks_workflow.handle_create_type_id_changed(model, v)
    pool_messages.MemberCreateCardIdChanged(v) ->
      tasks_workflow.handle_create_card_id_changed(model, v)

    pool_messages.MemberCreateSubmitted ->
      tasks_workflow.handle_create_submitted(model, member_refresh)

    pool_messages.MemberTaskCreated(Ok(task)) ->
      tasks_workflow.handle_task_created_ok(model, task, member_refresh)
    pool_messages.MemberTaskCreated(Error(err)) ->
      tasks_workflow.handle_task_created_error(model, err)

    pool_messages.MemberClaimClicked(task_id, version) ->
      tasks_workflow.handle_claim_clicked(model, task_id, version)
    pool_messages.MemberReleaseClicked(task_id, version) ->
      tasks_workflow.handle_release_clicked(model, task_id, version)
    pool_messages.MemberCompleteClicked(task_id, version) ->
      tasks_workflow.handle_complete_clicked(model, task_id, version)

    pool_messages.MemberBlockedClaimCancelled ->
      tasks_workflow.handle_blocked_claim_cancelled(model)
    pool_messages.MemberBlockedClaimConfirmed ->
      tasks_workflow.handle_blocked_claim_confirmed(model)

    pool_messages.MemberTaskClaimed(Ok(_)) ->
      tasks_workflow.handle_task_claimed_ok(model, member_refresh)
    pool_messages.MemberTaskReleased(Ok(_)) ->
      tasks_workflow.handle_task_released_ok(model, member_refresh)
    pool_messages.MemberTaskCompleted(Ok(_)) ->
      tasks_workflow.handle_task_completed_ok(model, member_refresh)

    pool_messages.MemberTaskClaimed(Error(err)) ->
      tasks_workflow.handle_mutation_error(model, err, member_refresh)
    pool_messages.MemberTaskReleased(Error(err)) ->
      tasks_workflow.handle_mutation_error(model, err, member_refresh)
    pool_messages.MemberTaskCompleted(Error(err)) ->
      tasks_workflow.handle_mutation_error(model, err, member_refresh)

    pool_messages.MemberNowWorkingStartClicked(task_id) ->
      now_working_workflow.handle_start_clicked(model, task_id)
    pool_messages.MemberNowWorkingPauseClicked ->
      now_working_workflow.handle_pause_clicked(model)

    // Work sessions (multi-session) - delegate to workflow
    pool_messages.MemberWorkSessionsFetched(Ok(payload)) ->
      now_working_workflow.handle_sessions_fetched_ok(model, payload)
    pool_messages.MemberWorkSessionsFetched(Error(err)) ->
      now_working_workflow.handle_sessions_fetched_error(model, err)

    pool_messages.MemberWorkSessionStarted(Ok(payload)) ->
      now_working_workflow.handle_session_started_ok(model, payload)
    pool_messages.MemberWorkSessionStarted(Error(err)) ->
      now_working_workflow.handle_session_started_error(model, err)

    pool_messages.MemberWorkSessionPaused(Ok(payload)) ->
      now_working_workflow.handle_session_paused_ok(model, payload)
    pool_messages.MemberWorkSessionPaused(Error(err)) ->
      now_working_workflow.handle_session_paused_error(model, err)

    pool_messages.MemberWorkSessionHeartbeated(Ok(payload)) ->
      now_working_workflow.handle_session_heartbeated_ok(model, payload)
    pool_messages.MemberWorkSessionHeartbeated(Error(err)) ->
      now_working_workflow.handle_session_heartbeated_error(model, err)

    pool_messages.MemberMetricsFetched(Ok(metrics)) ->
      metrics_workflow.handle_member_metrics_fetched_ok(model, metrics)
    pool_messages.MemberMetricsFetched(Error(err)) ->
      metrics_workflow.handle_member_metrics_fetched_error(model, err)

    pool_messages.AdminMetricsOverviewFetched(Ok(overview)) ->
      metrics_workflow.handle_admin_overview_fetched_ok(model, overview)
    pool_messages.AdminMetricsOverviewFetched(Error(err)) ->
      metrics_workflow.handle_admin_overview_fetched_error(model, err)

    pool_messages.AdminMetricsProjectTasksFetched(Ok(payload)) ->
      metrics_workflow.handle_admin_project_tasks_fetched_ok(model, payload)
    pool_messages.AdminMetricsProjectTasksFetched(Error(err)) ->
      metrics_workflow.handle_admin_project_tasks_fetched_error(model, err)

    pool_messages.AdminMetricsUsersFetched(Ok(users)) ->
      metrics_workflow.handle_admin_users_fetched_ok(model, users)
    pool_messages.AdminMetricsUsersFetched(Error(err)) ->
      metrics_workflow.handle_admin_users_fetched_error(model, err)

    // Rule metrics tab
    pool_messages.AdminRuleMetricsFetched(Ok(metrics)) ->
      workflows_workflow.handle_rule_metrics_tab_fetched_ok(model, metrics)
    pool_messages.AdminRuleMetricsFetched(Error(err)) ->
      workflows_workflow.handle_rule_metrics_tab_fetched_error(model, err)
    pool_messages.AdminRuleMetricsFromChanged(from) ->
      workflows_workflow.handle_rule_metrics_tab_from_changed(model, from)
    pool_messages.AdminRuleMetricsToChanged(to) ->
      workflows_workflow.handle_rule_metrics_tab_to_changed(model, to)
    pool_messages.AdminRuleMetricsFromChangedAndRefresh(from) ->
      workflows_workflow.handle_rule_metrics_tab_from_changed_and_refresh(
        model,
        from,
      )
    pool_messages.AdminRuleMetricsToChangedAndRefresh(to) ->
      workflows_workflow.handle_rule_metrics_tab_to_changed_and_refresh(
        model,
        to,
      )
    pool_messages.AdminRuleMetricsRefreshClicked ->
      workflows_workflow.handle_rule_metrics_tab_refresh_clicked(model)
    pool_messages.AdminRuleMetricsQuickRangeClicked(from, to) ->
      workflows_workflow.handle_rule_metrics_tab_quick_range_clicked(
        model,
        from,
        to,
      )
    // Rule metrics drill-down
    pool_messages.AdminRuleMetricsWorkflowExpanded(workflow_id) ->
      workflows_workflow.handle_rule_metrics_workflow_expanded(
        model,
        workflow_id,
      )
    pool_messages.AdminRuleMetricsWorkflowDetailsFetched(Ok(details)) ->
      workflows_workflow.handle_rule_metrics_workflow_details_fetched_ok(
        model,
        details,
      )
    pool_messages.AdminRuleMetricsWorkflowDetailsFetched(Error(err)) ->
      workflows_workflow.handle_rule_metrics_workflow_details_fetched_error(
        model,
        err,
      )
    pool_messages.AdminRuleMetricsDrilldownClicked(rule_id) ->
      workflows_workflow.handle_rule_metrics_drilldown_clicked(model, rule_id)
    pool_messages.AdminRuleMetricsDrilldownClosed ->
      workflows_workflow.handle_rule_metrics_drilldown_closed(model)
    pool_messages.AdminRuleMetricsRuleDetailsFetched(Ok(details)) ->
      workflows_workflow.handle_rule_metrics_rule_details_fetched_ok(
        model,
        details,
      )
    pool_messages.AdminRuleMetricsRuleDetailsFetched(Error(err)) ->
      workflows_workflow.handle_rule_metrics_rule_details_fetched_error(
        model,
        err,
      )
    pool_messages.AdminRuleMetricsExecutionsFetched(Ok(response)) ->
      workflows_workflow.handle_rule_metrics_executions_fetched_ok(
        model,
        response,
      )
    pool_messages.AdminRuleMetricsExecutionsFetched(Error(err)) ->
      workflows_workflow.handle_rule_metrics_executions_fetched_error(
        model,
        err,
      )
    pool_messages.AdminRuleMetricsExecPageChanged(offset) ->
      workflows_workflow.handle_rule_metrics_exec_page_changed(model, offset)

    pool_messages.NowWorkingTicked -> now_working_workflow.handle_ticked(model)

    pool_messages.MemberMyCapabilityIdsFetched(Ok(ids)) ->
      skills_workflow.handle_my_capability_ids_fetched_ok(model, ids)
    pool_messages.MemberMyCapabilityIdsFetched(Error(err)) ->
      skills_workflow.handle_my_capability_ids_fetched_error(model, err)

    pool_messages.MemberProjectCapabilitiesFetched(Ok(capabilities)) ->
      client_state.update_member(model, fn(member) {
        let skills = member.skills
        member_state.MemberModel(
          ..member,
          skills: member_skills.Model(
            ..skills,
            member_capabilities: Loaded(capabilities),
          ),
        )
      })
      |> fn(next) { #(next, effect.none()) }
    pool_messages.MemberProjectCapabilitiesFetched(Error(err)) ->
      client_state.update_member(model, fn(member) {
        let skills = member.skills
        member_state.MemberModel(
          ..member,
          skills: member_skills.Model(
            ..skills,
            member_capabilities: Failed(err),
          ),
        )
      })
      |> fn(next) { #(next, effect.none()) }

    pool_messages.MemberToggleCapability(id) ->
      skills_workflow.handle_toggle_capability(model, id)
    pool_messages.MemberSaveCapabilitiesClicked ->
      skills_workflow.handle_save_capabilities_clicked(model)

    pool_messages.MemberMyCapabilityIdsSaved(Ok(ids)) ->
      skills_workflow.handle_save_capabilities_ok(model, ids)
    pool_messages.MemberMyCapabilityIdsSaved(Error(err)) ->
      skills_workflow.handle_save_capabilities_error(model, err)

    pool_messages.MemberPositionsFetched(Ok(positions)) ->
      handle_positions_fetched_ok(model, positions)
    pool_messages.MemberPositionsFetched(Error(err)) ->
      handle_positions_fetched_error(model, err)

    pool_messages.MemberPositionEditOpened(task_id) ->
      handle_position_edit_opened(model, task_id)
    pool_messages.MemberPositionEditClosed -> handle_position_edit_closed(model)
    pool_messages.MemberPositionEditXChanged(v) ->
      handle_position_edit_x_changed(model, v)
    pool_messages.MemberPositionEditYChanged(v) ->
      handle_position_edit_y_changed(model, v)
    pool_messages.MemberPositionEditSubmitted ->
      handle_position_edit_submitted(model)

    pool_messages.MemberPositionSaved(Ok(pos)) ->
      handle_position_saved_ok(model, pos)
    pool_messages.MemberPositionSaved(Error(err)) ->
      handle_position_saved_error(model, err)

    pool_messages.MemberTaskDetailsOpened(task_id) ->
      tasks_workflow.handle_task_details_opened(model, task_id)
    pool_messages.MemberTaskDetailsClosed ->
      tasks_workflow.handle_task_details_closed(model)

    pool_messages.MemberTaskDetailTabClicked(tab) ->
      tasks_workflow.handle_task_detail_tab_clicked(model, tab)

    pool_messages.MemberDependenciesFetched(Ok(deps)) ->
      tasks_workflow.handle_dependencies_fetched_ok(model, deps)
    pool_messages.MemberDependenciesFetched(Error(err)) ->
      tasks_workflow.handle_dependencies_fetched_error(model, err)

    pool_messages.MemberDependencyDialogOpened ->
      tasks_workflow.handle_dependency_dialog_opened(model)
    pool_messages.MemberDependencyDialogClosed ->
      tasks_workflow.handle_dependency_dialog_closed(model)
    pool_messages.MemberDependencySearchChanged(value) ->
      tasks_workflow.handle_dependency_search_changed(model, value)
    pool_messages.MemberDependencyCandidatesFetched(Ok(tasks)) ->
      tasks_workflow.handle_dependency_candidates_fetched_ok(model, tasks)
    pool_messages.MemberDependencyCandidatesFetched(Error(err)) ->
      tasks_workflow.handle_dependency_candidates_fetched_error(model, err)
    pool_messages.MemberDependencySelected(task_id) ->
      tasks_workflow.handle_dependency_selected(model, task_id)
    pool_messages.MemberDependencyAddSubmitted ->
      tasks_workflow.handle_dependency_add_submitted(model)
    pool_messages.MemberDependencyAdded(Ok(dep)) ->
      tasks_workflow.handle_dependency_added_ok(model, dep)
    pool_messages.MemberDependencyAdded(Error(err)) ->
      tasks_workflow.handle_dependency_added_error(model, err)
    pool_messages.MemberDependencyRemoveClicked(depends_on_task_id) ->
      tasks_workflow.handle_dependency_remove_clicked(model, depends_on_task_id)
    pool_messages.MemberDependencyRemoved(depends_on_task_id, Ok(_)) ->
      tasks_workflow.handle_dependency_removed_ok(model, depends_on_task_id)
    pool_messages.MemberDependencyRemoved(_depends_on_task_id, Error(err)) ->
      tasks_workflow.handle_dependency_removed_error(model, err)

    pool_messages.MemberNotesFetched(Ok(notes)) ->
      tasks_workflow.handle_notes_fetched_ok(model, notes)
    pool_messages.MemberNotesFetched(Error(err)) ->
      tasks_workflow.handle_notes_fetched_error(model, err)

    pool_messages.MemberNoteContentChanged(v) ->
      tasks_workflow.handle_note_content_changed(model, v)
    pool_messages.MemberNoteDialogOpened ->
      tasks_workflow.handle_note_dialog_opened(model)
    pool_messages.MemberNoteDialogClosed ->
      tasks_workflow.handle_note_dialog_closed(model)
    pool_messages.MemberNoteSubmitted ->
      tasks_workflow.handle_note_submitted(model)

    pool_messages.MemberNoteAdded(Ok(note)) ->
      tasks_workflow.handle_note_added_ok(model, note)
    pool_messages.MemberNoteAdded(Error(err)) ->
      tasks_workflow.handle_note_added_error(model, err)

    // Cards (Fichas) handlers - list loading and dialog mode
    pool_messages.CardsFetched(Ok(cards)) ->
      cards_workflow.handle_cards_fetched_ok(model, cards)
    pool_messages.CardsFetched(Error(err)) ->
      cards_workflow.handle_cards_fetched_error(model, err)

    pool_messages.MemberProjectCardsFetched(project_id, Ok(cards)) -> {
      let next_store =
        normalized_store.upsert(
          model.member.pool.member_cards_store,
          project_id,
          cards,
          fn(card_item) {
            let card.Card(id: id, ..) = card_item
            id
          },
        )
        |> normalized_store.decrement_pending

      let next_cards = case normalized_store.is_ready(next_store) {
        True -> Loaded(normalized_store.to_list(next_store))
        False -> model.member.pool.member_cards
      }

      client_state.update_member(model, fn(member) {
        let pool = member.pool
        member_state.MemberModel(
          ..member,
          pool: member_pool.Model(
            ..pool,
            member_cards_store: next_store,
            member_cards: next_cards,
          ),
        )
      })
      |> fn(next) { #(next, effect.none()) }
    }
    pool_messages.MemberProjectCardsFetched(_project_id, Error(err)) -> {
      let next_store =
        model.member.pool.member_cards_store
        |> normalized_store.decrement_pending

      let next_cards = case model.member.pool.member_cards {
        Loaded(_) -> model.member.pool.member_cards
        _ -> Failed(err)
      }

      client_state.update_member(model, fn(member) {
        let pool = member.pool
        member_state.MemberModel(
          ..member,
          pool: member_pool.Model(
            ..pool,
            member_cards_store: next_store,
            member_cards: next_cards,
          ),
        )
      })
      |> fn(next) { #(next, effect.none()) }
    }

    pool_messages.MemberProjectMilestonesFetched(_, _)
    | pool_messages.MemberMilestonesShowCompletedToggled
    | pool_messages.MemberMilestonesShowEmptyToggled
    | pool_messages.MemberMilestoneRowToggled(_)
    | pool_messages.MemberMilestoneDetailsClicked(_)
    | pool_messages.MemberMilestoneActivatePromptClicked(_)
    | pool_messages.MemberMilestoneActivateClicked(_)
    | pool_messages.MemberMilestoneActivated(_, _)
    | pool_messages.MemberMilestoneEditClicked(_)
    | pool_messages.MemberMilestoneDeleteClicked(_)
    | pool_messages.MemberMilestoneDialogClosed
    | pool_messages.MemberMilestoneNameChanged(_)
    | pool_messages.MemberMilestoneDescriptionChanged(_)
    | pool_messages.MemberMilestoneEditSubmitted(_)
    | pool_messages.MemberMilestoneDeleteSubmitted(_)
    | pool_messages.MemberMilestoneUpdated(_)
    | pool_messages.MemberMilestoneDeleted(_, _) -> #(model, effect.none())

    pool_messages.OpenCardDialog(mode) ->
      cards_workflow.handle_open_card_dialog(model, mode)
    pool_messages.CloseCardDialog ->
      cards_workflow.handle_close_card_dialog(model)
    // Cards (Fichas) - component events
    pool_messages.CardCrudCreated(card) ->
      cards_workflow.handle_card_crud_created(model, card)
    pool_messages.CardCrudUpdated(card) ->
      cards_workflow.handle_card_crud_updated(model, card)
    pool_messages.CardCrudDeleted(card_id) ->
      cards_workflow.handle_card_crud_deleted(model, card_id)
    // Cards - filter changes (Story 4.9 AC7-8, UX improvements)
    pool_messages.CardsShowEmptyToggled -> #(
      client_state.update_admin(model, fn(admin) {
        let cards = admin.cards
        admin_state.AdminModel(
          ..admin,
          cards: admin_cards.Model(
            ..cards,
            cards_show_empty: !model.admin.cards.cards_show_empty,
          ),
        )
      }),
      effect.none(),
    )
    pool_messages.CardsShowCompletedToggled -> #(
      client_state.update_admin(model, fn(admin) {
        let cards = admin.cards
        admin_state.AdminModel(
          ..admin,
          cards: admin_cards.Model(
            ..cards,
            cards_show_completed: !model.admin.cards.cards_show_completed,
          ),
        )
      }),
      effect.none(),
    )
    pool_messages.CardsStateFilterChanged(state_str) -> {
      let filter = case state_str {
        "" -> opt.None
        "pendiente" -> opt.Some(card.Pendiente)
        "en_curso" -> opt.Some(card.EnCurso)
        "cerrada" -> opt.Some(card.Cerrada)
        _ -> opt.None
      }
      #(
        client_state.update_admin(model, fn(admin) {
          let cards = admin.cards
          admin_state.AdminModel(
            ..admin,
            cards: admin_cards.Model(..cards, cards_state_filter: filter),
          )
        }),
        effect.none(),
      )
    }
    pool_messages.CardsSearchChanged(query) -> #(
      client_state.update_admin(model, fn(admin) {
        let cards = admin.cards
        admin_state.AdminModel(
          ..admin,
          cards: admin_cards.Model(..cards, cards_search: query),
        )
      }),
      effect.none(),
    )

    // Card detail (member view) handlers - component manages internal state
    pool_messages.OpenCardDetail(card_id) -> {
      let model =
        client_state.update_member(model, fn(member) {
          let pool = member.pool
          member_state.MemberModel(
            ..member,
            pool: member_pool.Model(..pool, card_detail_open: opt.Some(card_id)),
          )
        })
        |> clear_card_new_notes(card_id)

      let fx = api_cards.mark_card_view(card_id, fn(_res) { client_state.NoOp })

      #(model, fx)
    }
    pool_messages.CloseCardDetail -> #(
      client_state.update_member(model, fn(member) {
        let pool = member.pool
        member_state.MemberModel(
          ..member,
          pool: member_pool.Model(..pool, card_detail_open: opt.None),
        )
      }),
      effect.none(),
    )

    // Workflows handlers
    pool_messages.WorkflowsProjectFetched(Ok(workflows)) ->
      workflows_workflow.handle_workflows_project_fetched_ok(model, workflows)
    pool_messages.WorkflowsProjectFetched(Error(err)) ->
      workflows_workflow.handle_workflows_project_fetched_error(model, err)
    // Workflow dialog control (component pattern)
    pool_messages.OpenWorkflowDialog(mode) ->
      workflows_workflow.handle_open_workflow_dialog(model, mode)
    pool_messages.CloseWorkflowDialog ->
      workflows_workflow.handle_close_workflow_dialog(model)
    // Workflow component events
    pool_messages.WorkflowCrudCreated(workflow) ->
      workflows_workflow.handle_workflow_crud_created(model, workflow)
    pool_messages.WorkflowCrudUpdated(workflow) ->
      workflows_workflow.handle_workflow_crud_updated(model, workflow)
    pool_messages.WorkflowCrudDeleted(workflow_id) ->
      workflows_workflow.handle_workflow_crud_deleted(model, workflow_id)

    pool_messages.WorkflowRulesClicked(workflow_id) ->
      workflows_workflow.handle_workflow_rules_clicked(model, workflow_id)

    // Rules handlers
    pool_messages.RulesFetched(Ok(rules)) ->
      workflows_workflow.handle_rules_fetched_ok(model, rules)
    pool_messages.RulesFetched(Error(err)) ->
      workflows_workflow.handle_rules_fetched_error(model, err)
    pool_messages.RulesBackClicked ->
      workflows_workflow.handle_rules_back_clicked(model)
    pool_messages.RuleMetricsFetched(Ok(metrics)) ->
      workflows_workflow.handle_rule_metrics_fetched_ok(model, metrics)
    pool_messages.RuleMetricsFetched(Error(err)) ->
      workflows_workflow.handle_rule_metrics_fetched_error(model, err)

    // Rules - dialog mode control (component pattern)
    pool_messages.OpenRuleDialog(mode) ->
      workflows_workflow.handle_open_rule_dialog(model, mode)
    pool_messages.CloseRuleDialog ->
      workflows_workflow.handle_close_rule_dialog(model)

    // Rules - component events (rule-crud-dialog emits these)
    pool_messages.RuleCrudCreated(rule) ->
      workflows_workflow.handle_rule_crud_created(model, rule)
    pool_messages.RuleCrudUpdated(rule) ->
      workflows_workflow.handle_rule_crud_updated(model, rule)
    pool_messages.RuleCrudDeleted(rule_id) ->
      workflows_workflow.handle_rule_crud_deleted(model, rule_id)

    // Rule templates handlers
    pool_messages.RuleTemplatesClicked(_rule_id) -> #(model, effect.none())
    pool_messages.RuleTemplatesFetched(Ok(templates)) ->
      workflows_workflow.handle_rule_templates_fetched_ok(model, templates)
    pool_messages.RuleTemplatesFetched(Error(err)) ->
      workflows_workflow.handle_rule_templates_fetched_error(model, err)
    pool_messages.RuleAttachTemplateSelected(template_id) ->
      workflows_workflow.handle_rule_attach_template_selected(
        model,
        template_id,
      )
    pool_messages.RuleAttachTemplateSubmitted -> #(model, effect.none())
    pool_messages.RuleTemplateAttached(Ok(templates)) ->
      workflows_workflow.handle_rule_template_attached_ok(model, templates)
    pool_messages.RuleTemplateAttached(Error(err)) ->
      workflows_workflow.handle_rule_template_attached_error(model, err)
    pool_messages.RuleTemplateDetachClicked(_template_id) -> #(
      model,
      effect.none(),
    )
    pool_messages.RuleTemplateDetached(Ok(_)) -> #(model, effect.none())
    pool_messages.RuleTemplateDetached(Error(err)) ->
      workflows_workflow.handle_rule_template_detached_error(model, err)

    // Story 4.10: Rule template attachment UI handlers
    pool_messages.RuleExpandToggled(rule_id) ->
      workflows_workflow.handle_rule_expand_toggled(model, rule_id)
    pool_messages.AttachTemplateModalOpened(rule_id) ->
      workflows_workflow.handle_attach_template_modal_opened(model, rule_id)
    pool_messages.AttachTemplateModalClosed ->
      workflows_workflow.handle_attach_template_modal_closed(model)
    pool_messages.AttachTemplateSelected(template_id) ->
      workflows_workflow.handle_attach_template_selected(model, template_id)
    pool_messages.AttachTemplateSubmitted ->
      workflows_workflow.handle_attach_template_submitted(model)
    pool_messages.AttachTemplateSucceeded(rule_id, templates) ->
      workflows_workflow.handle_attach_template_succeeded(
        model,
        rule_id,
        templates,
      )
    pool_messages.AttachTemplateFailed(err) ->
      workflows_workflow.handle_attach_template_failed(model, err)
    pool_messages.TemplateDetachClicked(rule_id, template_id) ->
      workflows_workflow.handle_template_detach_clicked(
        model,
        rule_id,
        template_id,
      )
    pool_messages.TemplateDetachSucceeded(rule_id, template_id) ->
      workflows_workflow.handle_template_detach_succeeded(
        model,
        rule_id,
        template_id,
      )
    pool_messages.TemplateDetachFailed(rule_id, template_id, err) ->
      workflows_workflow.handle_template_detach_failed(
        model,
        rule_id,
        template_id,
        err,
      )

    // Task templates handlers
    pool_messages.TaskTemplatesProjectFetched(Ok(templates)) ->
      workflows_workflow.handle_task_templates_project_fetched_ok(
        model,
        templates,
      )
    pool_messages.TaskTemplatesProjectFetched(Error(err)) ->
      workflows_workflow.handle_task_templates_project_fetched_error(model, err)

    // Task templates - dialog mode control (component pattern)
    pool_messages.OpenTaskTemplateDialog(mode) ->
      workflows_workflow.handle_open_task_template_dialog(model, mode)
    pool_messages.CloseTaskTemplateDialog ->
      workflows_workflow.handle_close_task_template_dialog(model)

    // Task templates - component events
    pool_messages.TaskTemplateCrudCreated(template) ->
      workflows_workflow.handle_task_template_crud_created(model, template)
    pool_messages.TaskTemplateCrudUpdated(template) ->
      workflows_workflow.handle_task_template_crud_updated(model, template)
    pool_messages.TaskTemplateCrudDeleted(template_id) ->
      workflows_workflow.handle_task_template_crud_deleted(model, template_id)
  }
}

fn clear_card_new_notes(
  model: client_state.Model,
  card_id: Int,
) -> client_state.Model {
  client_state.update_admin(model, fn(admin) {
    let cards_state = admin.cards

    case cards_state.cards {
      Loaded(cards) ->
        admin_state.AdminModel(
          ..admin,
          cards: admin_cards.Model(
            ..cards_state,
            cards: Loaded(
              list.map(cards, fn(card_item) {
                case card_item.id == card_id {
                  True -> card.Card(..card_item, has_new_notes: False)
                  False -> card_item
                }
              }),
            ),
          ),
        )
      _ -> admin
    }
  })
}
