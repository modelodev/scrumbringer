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
//// - Task mutations (claim/release/complete - see features/tasks/mutation_update.gleam)
//// - Task creation (see features/tasks/create_update.gleam)
//// - View rendering (see features/pool/view.gleam)
////
//// ## Relations
////
//// - **client_state.gleam**: Provides client_state.Model, client_state.Msg types
//// - **client_update.gleam**: Delegates pool messages here
//// - **api/tasks/positions.gleam**: Provides position API functions

import gleam/option as opt
import lustre/effect

import domain/remote.{type Remote, Loaded}
import domain/task.{type Task}
import scrumbringer_client/app/effects as app_effects
import scrumbringer_client/client_state
import scrumbringer_client/client_state/admin as admin_state
import scrumbringer_client/client_state/admin/cards as admin_cards
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/features/now_working/update as now_working_workflow
import scrumbringer_client/features/pool/admin_route
import scrumbringer_client/features/pool/card_show_update
import scrumbringer_client/features/pool/drag_update
import scrumbringer_client/features/pool/filters_route
import scrumbringer_client/features/pool/metrics_route
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/pool/people_route
import scrumbringer_client/features/pool/plan_move_update
import scrumbringer_client/features/pool/positions_route
import scrumbringer_client/features/pool/preferences_effect
import scrumbringer_client/features/pool/refresh_update
import scrumbringer_client/features/pool/route_support
import scrumbringer_client/features/pool/rule_metrics_route
import scrumbringer_client/features/pool/shortcut_update
import scrumbringer_client/features/pool/skills_route
import scrumbringer_client/features/pool/task_route
import scrumbringer_client/features/pool/view_mode_route
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/utils/card_queries

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

fn pool_card_show_model(model: client_state.Model) -> card_show_update.Model {
  card_show_update.Model(pool: model.member.pool, cards: model.admin.cards)
}

fn update_pool_card_show_model(
  model: client_state.Model,
  local: card_show_update.Model,
) -> client_state.Model {
  let model =
    client_state.update_member(model, fn(member) {
      member_state.MemberModel(..member, pool: local.pool)
    })

  client_state.update_admin(model, fn(admin) {
    admin_state.AdminModel(..admin, cards: local.cards)
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

fn pool_drag_context(
  model: client_state.Model,
) -> drag_update.Context(client_state.Msg) {
  drag_update.Context(
    task_mutation: task_route.mutation_context(model),
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

fn card_detail_context(
  model: client_state.Model,
) -> card_show_update.Context(client_state.Msg) {
  card_show_update.Context(
    on_card_marked: fn(_result) { client_state.NoOp },
    on_card_show_msg: fn(msg) {
      client_state.pool_msg(pool_messages.CardShowMsg(msg))
    },
    on_card_activated: fn(result) {
      client_state.pool_msg(pool_messages.CardActivated(result))
    },
    on_create_task: fn(card_id) {
      client_state.pool_msg(pool_messages.MemberCreateDialogOpenedWithCard(
        card_id,
      ))
    },
    on_create_card: fn(card_id) {
      client_state.pool_msg(
        pool_messages.OpenCardDialog(
          admin_cards.CardDialogCreate(opt.Some(card_id)),
        ),
      )
    },
    on_activate_card: fn(card_id) {
      client_state.pool_msg(pool_messages.CardActivateRequested(card_id))
    },
    on_move_card: fn(card_id) {
      client_state.pool_msg(pool_messages.MemberPlanMoveRequested(card_id))
    },
    on_delete_card: fn(card_id) {
      client_state.pool_msg(
        pool_messages.OpenCardDialog(admin_cards.CardDialogDelete(card_id)),
      )
    },
    on_close: client_state.pool_msg(pool_messages.CloseCardShow),
    on_success_toast: app_effects.toast_success,
    on_error_toast: app_effects.toast_error,
    hierarchy_activated: i18n.t(model.ui.locale, i18n_text.HierarchyActivated),
    hierarchy_pool_impact: fn(pool_impact) {
      i18n.t(
        model.ui.locale,
        i18n_text.HierarchyActivationPoolImpact(pool_impact),
      )
    },
    hierarchy_pool_saturated: fn(pool_open_after, healthy_pool_limit) {
      i18n.t(
        model.ui.locale,
        i18n_text.HierarchyActivationPoolSaturated(
          pool_open_after,
          healthy_pool_limit,
        ),
      )
    },
    hierarchy_activate_failed: i18n.t(
      model.ui.locale,
      i18n_text.HierarchyActivateFailed,
    ),
  )
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
    is_pool_shortcut_target: model.core.page == client_state.Member,
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
  case try_pool_card_show_update(model, inner, member_refresh) {
    opt.Some(result) -> result
    opt.None -> update_without_card_detail(model, inner, member_refresh)
  }
}

fn try_pool_card_show_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case
    card_show_update.try_update(
      pool_card_show_model(model),
      inner,
      card_detail_context(model),
    )
  {
    opt.Some(#(local, fx)) -> {
      let updated = update_pool_card_show_model(model, local)
      opt.Some(apply_card_detail_refresh(updated, inner, fx, member_refresh))
    }
    opt.None -> opt.None
  }
}

fn apply_card_detail_refresh(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  fx: effect.Effect(client_state.Msg),
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case inner {
    pool_messages.CardActivated(Ok(_)) -> {
      let #(refreshed, refresh_fx) = member_refresh(model)
      #(refreshed, effect.batch([fx, refresh_fx]))
    }
    _ -> #(model, fx)
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
  refresh_update.try_project_update(model, inner)
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
  refresh_update.try_card_update(model, inner)
}

fn update_without_card_refresh(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case admin_route.try_update(model, inner, close_card_dialog_focus_target) {
    opt.Some(result) -> result
    opt.None -> update_without_task_templates(model, inner, member_refresh)
  }
}

fn update_without_task_templates(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case try_pool_plan_move_update(model, inner, member_refresh) {
    opt.Some(result) -> result
    opt.None -> update_without_plan_move(model, inner, member_refresh)
  }
}

fn try_pool_plan_move_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case
    plan_move_update.try_update(
      model.member.pool,
      inner,
      plan_move_context(model),
    )
  {
    opt.Some(#(pool, fx)) -> {
      let updated =
        client_state.update_member(model, fn(member) {
          member_state.MemberModel(..member, pool: pool)
        })
      opt.Some(apply_plan_move_refresh(updated, inner, fx, member_refresh))
    }
    opt.None -> opt.None
  }
}

fn apply_plan_move_refresh(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  fx: effect.Effect(client_state.Msg),
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case inner {
    pool_messages.MemberPlanCardMoved(Ok(_)) -> {
      let #(refreshed, refresh_fx) = member_refresh(model)
      #(refreshed, effect.batch([fx, refresh_fx]))
    }
    _ -> #(model, fx)
  }
}

fn plan_move_context(
  model: client_state.Model,
) -> plan_move_update.Context(client_state.Msg) {
  plan_move_update.Context(
    cards: card_queries.get_project_cards(
      model.member.pool.member_cards_store,
      model.admin.cards.cards,
      model.core.selected_project_id,
    ),
    tasks: model.member.pool.member_tasks
      |> task_list_or_empty,
    on_card_moved: fn(result) {
      client_state.pool_msg(pool_messages.MemberPlanCardMoved(result))
    },
    on_success_toast: app_effects.toast_success,
    on_error_toast: app_effects.toast_error,
  )
}

fn task_list_or_empty(tasks: Remote(List(Task))) -> List(Task) {
  case tasks {
    Loaded(values) -> values
    _ -> []
  }
}

fn update_without_plan_move(
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
  filters_route.try_update(model, inner, member_refresh)
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
  preferences_effect.try_update(model, inner)
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
  people_route.try_update(model, inner)
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
  metrics_route.try_update(model, inner)
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
  rule_metrics_route.try_update(model, inner)
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
  skills_route.try_update(model, inner)
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
      route_support.apply_auth_check_before(model, opt.Some(err), apply_update)
    now_working_workflow.CheckAuthAfter(err) ->
      route_support.apply_auth_check_after(opt.Some(err), apply_update)
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
  positions_route.try_update(model, inner)
}

fn update_without_positions(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case task_route.try_update(model, inner, member_refresh) {
    opt.Some(result) -> result
    opt.None -> update_without_task_route(model, inner)
  }
}

fn update_without_task_route(
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
  view_mode_route.try_update(model, inner)
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
    pool_messages.MemberPoolVisibilityChanged(_)
    | pool_messages.MemberPoolTypeChanged(_)
    | pool_messages.MemberPoolCapabilityChanged(_)
    | pool_messages.MemberPoolCapabilityScopeChanged(_)
    | pool_messages.MemberClearFilters
    | pool_messages.MemberPoolSearchChanged(_)
    | pool_messages.MemberPoolSearchDebounced(_)
    | pool_messages.MemberPlanScopeKindChanged(_)
    | pool_messages.MemberPlanModeChanged(_)
    | pool_messages.MemberPlanCapabilityModeChanged(_)
    | pool_messages.MemberPlanScopeDepthChanged(_)
    | pool_messages.MemberPlanScopeCardChanged(_)
    | pool_messages.MemberPlanScopeCardSearchChanged(_)
    | pool_messages.MemberPlanClosedToggled(_)
    | pool_messages.MemberPlanStatusChanged(_)
    | pool_messages.MemberPlanSortChanged(_)
    | pool_messages.MemberPlanCardToggled(_) -> #(model, effect.none())

    // Handled by plan_move_update.try_update before this dispatch.
    pool_messages.MemberPlanMoveRequested(_)
    | pool_messages.MemberPlanMoveCancelled
    | pool_messages.MemberPlanMoveDestinationSearchChanged(_)
    | pool_messages.MemberPlanMoveDestinationSelected(_)
    | pool_messages.MemberPlanMoveDragStarted(_)
    | pool_messages.MemberPlanMoveDragEntered(_)
    | pool_messages.MemberPlanMoveDroppedOn(_)
    | pool_messages.MemberPlanMoveDragEnded
    | pool_messages.MemberPlanCardMoved(_) -> #(model, effect.none())

    // Handled by pool_preferences.try_update before this dispatch.
    pool_messages.MemberPoolViewModeSet(_)
    | pool_messages.MemberListHideDoneToggled
    | pool_messages.MemberListCardToggled(_) -> #(model, effect.none())

    // Handled by people_workflow.try_update before this dispatch.
    pool_messages.MemberPeopleRosterFetched(_)
    | pool_messages.MemberPeopleRowToggled(_)
    | pool_messages.MemberPeopleSearchChanged(_)
    | pool_messages.MemberPeopleFilterChanged(_)
    | pool_messages.MemberPeopleSortChanged(_) -> #(model, effect.none())

    // Handled by project_refresh.try_update before this dispatch.
    pool_messages.MemberProjectTasksFetched(_, _)
    | pool_messages.MemberTaskTypesFetched(_, _) -> #(model, effect.none())

    // Handled by task_route.try_update before this dispatch.
    pool_messages.MemberCreateDialogOpened
    | pool_messages.MemberCreateDialogOpenedWithCard(_)
    | pool_messages.MemberCreateDialogClosed
    | pool_messages.MemberCreateTitleChanged(_)
    | pool_messages.MemberCreateDescriptionChanged(_)
    | pool_messages.MemberCreatePriorityChanged(_)
    | pool_messages.MemberCreateTypeIdChanged(_)
    | pool_messages.MemberCreateTypeOptionsRetryClicked
    | pool_messages.MemberCreateSubmitted
    | pool_messages.MemberTaskCreated(_) -> #(model, effect.none())

    // Handled by task_route.try_update before this dispatch.
    pool_messages.MemberClaimClicked(_, _)
    | pool_messages.MemberReleaseClicked(_, _)
    | pool_messages.MemberCompleteClicked(_, _)
    | pool_messages.MemberDeleteTaskClicked(_)
    | pool_messages.MemberTaskClaimed(_)
    | pool_messages.MemberTaskReleased(_)
    | pool_messages.MemberTaskDone(_)
    | pool_messages.MemberTaskDeleted(_, _) -> #(model, effect.none())

    // Handled by now_working_workflow.try_update before this dispatch.
    pool_messages.MemberNowWorkingStartClicked(_)
    | pool_messages.MemberNowWorkingPauseClicked
    | pool_messages.MemberWorkSessionsFetched(_)
    | pool_messages.MemberWorkSessionStarted(_)
    | pool_messages.MemberWorkSessionPaused(_)
    | pool_messages.MemberWorkSessionHeartbeated(_)
    | pool_messages.NowWorkingTicked -> #(model, effect.none())

    // Handled by metrics_route.try_update before this dispatch.
    pool_messages.MemberMetricsFetched(_)
    | pool_messages.AdminMetricsOverviewFetched(_)
    | pool_messages.AdminMetricsProjectTasksFetched(_)
    | pool_messages.AdminMetricsUsersFetched(_) -> #(model, effect.none())

    // Handled by rule_metrics_route.try_update before this dispatch.
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

    // Handled by skills_route.try_update before this dispatch.
    pool_messages.MemberMyCapabilityIdsFetched(_)
    | pool_messages.MemberProjectCapabilitiesFetched(_)
    | pool_messages.MemberToggleCapability(_)
    | pool_messages.MemberSaveCapabilitiesClicked
    | pool_messages.MemberMyCapabilityIdsSaved(_) -> #(model, effect.none())

    // Handled by positions_route.try_update before this dispatch.
    pool_messages.MemberPositionsFetched(_)
    | pool_messages.MemberPositionEditOpened(_)
    | pool_messages.MemberPositionEditClosed
    | pool_messages.MemberPositionEditXChanged(_)
    | pool_messages.MemberPositionEditYChanged(_)
    | pool_messages.MemberPositionEditSubmitted
    | pool_messages.MemberPositionSaved(_) -> #(model, effect.none())

    // Handled by task_route.try_update before this dispatch.
    pool_messages.MemberTaskDetailsOpened(_)
    | pool_messages.MemberTaskDetailsClosed
    | pool_messages.MemberTaskDetailTabClicked(_)
    | pool_messages.MemberTaskDetailEditStarted
    | pool_messages.MemberTaskDetailEditCancelled
    | pool_messages.MemberTaskDetailEditTitleChanged(_)
    | pool_messages.MemberTaskDetailEditDescriptionChanged(_)
    | pool_messages.MemberTaskDetailEditPriorityChanged(_)
    | pool_messages.MemberTaskDetailEditTypeIdChanged(_)
    | pool_messages.MemberTaskDetailEditCardIdChanged(_)
    | pool_messages.MemberTaskDetailEditSubmitted
    | pool_messages.MemberTaskUpdated(_) -> #(model, effect.none())

    // Handled by task_route.try_update before this dispatch.
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

    // Handled by task_route.try_update before this dispatch.
    pool_messages.MemberNotesFetched(_)
    | pool_messages.MemberNoteContentChanged(_)
    | pool_messages.MemberNoteDialogOpened
    | pool_messages.MemberNoteDialogClosed
    | pool_messages.MemberNoteSubmitted
    | pool_messages.MemberNoteAdded(_)
    | pool_messages.MemberNoteDeleteClicked(_)
    | pool_messages.MemberNoteDeleted(_, _)
    | pool_messages.MemberNotePinClicked(_, _)
    | pool_messages.MemberNotePinned(_, _)
    | pool_messages.MemberActivityMoreClicked
    | pool_messages.MemberActivityFetched(_) -> #(model, effect.none())

    // Handled by cards_workflow.try_update before this dispatch.
    pool_messages.CardsFetched(_)
    | pool_messages.OpenCardDialog(_)
    | pool_messages.CloseCardDialog
    | pool_messages.CardCrudCreated(_)
    | pool_messages.CardCrudUpdated(_)
    | pool_messages.CardCrudDeleted(_)
    | pool_messages.CardsShowEmptyToggled
    | pool_messages.CardsShowDoneToggled
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

    // Handled by card_show_update.try_update before this dispatch.
    pool_messages.OpenCardShow(_)
    | pool_messages.CloseCardShow
    | pool_messages.CardShowMsg(_)
    | pool_messages.CardActivateRequested(_)
    | pool_messages.CardActivated(_) -> #(model, effect.none())

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
  _model: client_state.Model,
) -> opt.Option(String) {
  opt.None
}

/// Test helper: exposes close-card-dialog focus target resolution.
pub fn close_card_dialog_focus_target_for_test(
  model: client_state.Model,
) -> opt.Option(String) {
  close_card_dialog_focus_target(model)
}
