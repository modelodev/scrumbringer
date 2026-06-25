//// Root-aware adapter for the pool view.

import gleam/dict
import gleam/list
import gleam/option as opt

import lustre/element.{type Element}

import domain/capability.{type Capability}
import domain/card.{type Card}
import domain/note/entity.{type Note}
import domain/remote.{unwrap}
import domain/task.{type Task, type WorkSession, Task}
import domain/task/state as task_state
import domain/user.{type User}

import scrumbringer_client/client_ffi
import scrumbringer_client/client_state/member/notes as notes_state
import scrumbringer_client/client_state/member/now_working as now_working_state
import scrumbringer_client/client_state/member/pool as member_pool_state
import scrumbringer_client/client_state/member/positions as positions_state
import scrumbringer_client/client_state/member/skills as skills_state
import scrumbringer_client/features/my_bar/view as my_bar_view
import scrumbringer_client/features/now_working/panel as now_working_panel
import scrumbringer_client/features/pool/available_tasks
import scrumbringer_client/features/pool/control_bar
import scrumbringer_client/features/pool/task_card
import scrumbringer_client/features/pool/task_row
import scrumbringer_client/features/pool/view as pool_view
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/pool_prefs
import scrumbringer_client/theme.{type Theme}
import scrumbringer_client/utils/card_queries

pub type Callbacks(msg) {
  Callbacks(
    on_drag_moved: fn(Int, Int) -> msg,
    on_drag_ended: msg,
    on_create_opened: msg,
    on_capability_scope_change: fn(String) -> msg,
    on_type_filter_change: fn(String) -> msg,
    on_capability_filter_change: fn(String) -> msg,
    on_search_change: fn(String) -> msg,
    on_visibility_change: fn(String) -> msg,
    on_view_mode_change: fn(pool_prefs.ViewMode) -> msg,
    on_now_working_pause: msg,
    on_now_working_start: fn(Int) -> msg,
    on_claim: fn(Int, Int) -> msg,
    on_release: fn(Int, Int) -> msg,
    on_close: fn(Int, Int) -> msg,
    on_open: fn(Int) -> msg,
    on_hover_opened: fn(Int) -> msg,
    on_hover_closed: msg,
    on_focused: fn(Int) -> msg,
    on_blurred: msg,
    on_drag_started: fn(Int, Int, Int) -> msg,
    on_touch_started: fn(Int, Int, Int) -> msg,
    on_touch_ended: fn(Int) -> msg,
  )
}

pub type Context(msg) {
  Context(
    locale: Locale,
    theme: Theme,
    has_active_projects: Bool,
    healthy_pool_limit: Int,
    current_user_id: opt.Option(Int),
    active_task_id: opt.Option(Int),
    now_working_sessions: List(WorkSession),
    cards: List(Card),
    capabilities: List(Capability),
    pool: member_pool_state.Model,
    now_working: now_working_state.Model,
    skills: skills_state.Model,
    notes: notes_state.Model,
    positions: positions_state.Model,
    callbacks: Callbacks(msg),
  )
}

pub fn view_pool_main(context: Context(msg), _user: User) -> Element(msg) {
  pool_view.view_pool_main(main_config(context))
}

pub fn view_right_panel(context: Context(msg), user: User) -> Element(msg) {
  pool_view.view_right_panel(right_panel_config(context, user))
}

pub fn view_pool_body(context: Context(msg), user: User) -> Element(msg) {
  pool_view.view_pool_body(pool_body_config(context, user))
}

pub fn view_pool_task_row(context: Context(msg), task: Task) -> Element(msg) {
  pool_view.view_pool_task_row(pool_task_row_config(context, task))
}

pub fn view_task_card(context: Context(msg), task: Task) -> Element(msg) {
  pool_view.view_task_card(pool_task_card_config(context, task))
}

fn pool_body_config(
  context: Context(msg),
  user: User,
) -> pool_view.BodyConfig(msg) {
  pool_view.BodyConfig(
    main_config: main_config(context),
    right_panel_config: right_panel_config(context, user),
    on_drag_moved: context.callbacks.on_drag_moved,
    on_drag_ended: context.callbacks.on_drag_ended,
  )
}

fn main_config(context: Context(msg)) -> pool_view.MainConfig(msg) {
  pool_view.MainConfig(
    locale: context.locale,
    has_active_projects: context.has_active_projects,
    on_create_opened: context.callbacks.on_create_opened,
    available_tasks: available_tasks_config(context),
    control_bar: control_bar_config(context),
    healthy_pool_limit: context.healthy_pool_limit,
    view_mode: context.pool.member_pool_view_mode,
    task_card_config: fn(task) { pool_task_card_config(context, task) },
    task_row_config: fn(task) { pool_task_row_config(context, task) },
  )
}

fn control_bar_config(context: Context(msg)) -> control_bar.Config(msg) {
  control_bar.Config(
    locale: context.locale,
    task_types: unwrap(context.pool.member_task_types, []),
    capabilities: context.capabilities,
    capability_scope: context.pool.member_capability_scope,
    type_filter: context.pool.member_filters_type_id,
    capability_filter: context.pool.member_filters_capability_id,
    search_query: context.pool.member_filters_q,
    visibility: context.pool.member_pool_visibility,
    view_mode: context.pool.member_pool_view_mode,
    on_capability_scope_change: context.callbacks.on_capability_scope_change,
    on_type_filter_change: context.callbacks.on_type_filter_change,
    on_capability_filter_change: context.callbacks.on_capability_filter_change,
    on_search_change: context.callbacks.on_search_change,
    on_visibility_change: context.callbacks.on_visibility_change,
    on_view_mode_change: context.callbacks.on_view_mode_change,
  )
}

fn right_panel_config(
  context: Context(msg),
  user: User,
) -> pool_view.RightPanelConfig(msg) {
  let #(drag_armed, drag_over) = case context.pool.member_pool_drag {
    member_pool_state.PoolDragDragging(over_my_tasks: over, ..) -> #(True, over)
    member_pool_state.PoolDragPendingRect -> #(True, False)
    member_pool_state.PoolDragIdle -> #(False, False)
  }

  pool_view.RightPanelConfig(
    locale: context.locale,
    now_working_config: now_working_config(context),
    drag_armed: drag_armed,
    drag_over: drag_over,
    claimed_tasks: claimed_tasks(context, user),
    task_row_config: my_bar_task_row_config(context, user),
  )
}

fn now_working_config(context: Context(msg)) -> now_working_panel.Config(msg) {
  now_working_panel.Config(
    locale: context.locale,
    sessions: context.now_working_sessions,
    tasks: context.pool.member_tasks,
    server_offset_ms: context.now_working.now_working_server_offset_ms,
    error: context.now_working.member_now_working_error,
    disable_actions: context.pool.member_task_mutation_in_flight
      || context.now_working.member_now_working_in_flight,
    on_pause: context.callbacks.on_now_working_pause,
    on_close: context.callbacks.on_close,
  )
}

fn available_tasks_config(context: Context(msg)) -> available_tasks.Config {
  available_tasks.Config(
    tasks: context.pool.member_tasks,
    task_types: context.pool.member_task_types,
    my_capability_ids: context.skills.member_my_capability_ids,
    type_filter: context.pool.member_filters_type_id,
    capability_filter: context.pool.member_filters_capability_id,
    search_query: context.pool.member_filters_q,
    capability_scope: context.pool.member_capability_scope,
    visibility: context.pool.member_pool_visibility,
  )
}

fn pool_task_row_config(
  context: Context(msg),
  task: Task,
) -> task_row.Config(msg) {
  let Task(id: id, version: version, ..) = task
  let #(_card_title_opt, resolved_color) =
    card_queries.resolve_task_card_info(context.cards, task)

  task_row.Config(
    locale: context.locale,
    theme: context.theme,
    task: task,
    card_color: resolved_color,
    highlight_class: task_highlight_classes(context, id),
    disable_actions: context.pool.member_task_mutation_in_flight,
    on_claim: context.callbacks.on_claim(id, version),
    on_open: context.callbacks.on_open(id),
  )
}

fn pool_task_card_config(
  context: Context(msg),
  task: Task,
) -> task_card.Config(msg) {
  let Task(id: id, created_at: created_at, version: version, ..) = task
  let #(resolved_card_title, resolved_card_color) =
    card_queries.resolve_task_card_info(context.cards, task)
  let #(x, y) = task_position(context, id)

  task_card.Config(
    locale: context.locale,
    theme: context.theme,
    task: task,
    current_user_id: context.current_user_id,
    card_title: resolved_card_title,
    card_color: resolved_card_color,
    x: x,
    y: y,
    age_days: age_in_days(created_at),
    project_today: client_ffi.date_today(),
    highlight_class: task_highlight_classes(context, id),
    touch_preview: context.pool.member_pool_preview_task_id == opt.Some(id),
    disable_actions: context.pool.member_task_mutation_in_flight,
    hidden_blocked_count: hidden_blocked_count(context, id),
    notes: hover_notes_for_task(context, id),
    on_claim: context.callbacks.on_claim(id, version),
    on_release: context.callbacks.on_release(id, version),
    on_close: context.callbacks.on_close(id, version),
    on_open: context.callbacks.on_open(id),
    on_hover_opened: context.callbacks.on_hover_opened(id),
    on_hover_closed: context.callbacks.on_hover_closed,
    on_focused: context.callbacks.on_focused(id),
    on_blurred: context.callbacks.on_blurred,
    on_drag_started: fn(x, y) { context.callbacks.on_drag_started(id, x, y) },
    on_touch_started: fn(x, y) { context.callbacks.on_touch_started(id, x, y) },
    on_touch_ended: context.callbacks.on_touch_ended(id),
  )
}

fn my_bar_task_row_config(
  context: Context(msg),
  user: User,
) -> my_bar_view.TaskRowConfig(msg) {
  my_bar_view.TaskRowConfig(
    locale: context.locale,
    theme: context.theme,
    user_id: user.id,
    active_task_id: context.active_task_id,
    disable_actions: context.pool.member_task_mutation_in_flight
      || context.now_working.member_now_working_in_flight,
    task_card_info: fn(task) {
      card_queries.resolve_task_card_info(context.cards, task)
    },
    on_claim: context.callbacks.on_claim,
    on_start: context.callbacks.on_now_working_start,
    on_pause: context.callbacks.on_now_working_pause,
    on_release: context.callbacks.on_release,
    on_close: context.callbacks.on_close,
    on_task_open: context.callbacks.on_open,
  )
}

fn claimed_tasks(context: Context(msg), user: User) -> List(Task) {
  context.pool.member_tasks
  |> unwrap([])
  |> list.filter(fn(t) {
    case t.state {
      task_state.Claimed(claimed_by: claimed_by, mode: task_state.Taken, ..) ->
        claimed_by == user.id
      _ -> False
    }
  })
  |> list.sort(by: my_bar_view.compare_member_bar_tasks)
}

fn task_highlight_classes(context: Context(msg), task_id: Int) -> String {
  case context.pool.member_highlight_state {
    member_pool_state.NoHighlight -> ""
    member_pool_state.CreatedHighlight(created_task_id) ->
      case task_id == created_task_id {
        True -> " is-highlight-source highlight-info"
        False -> ""
      }
    member_pool_state.BlockingHighlight(
      source_task_id: source_task_id,
      blocker_ids: blocker_ids,
      ..,
    ) -> {
      case task_id == source_task_id {
        True -> " is-highlight-source highlight-warning"
        False ->
          case list.contains(blocker_ids, task_id) {
            True -> " is-highlight-target highlight-warning"
            False -> " is-highlight-dimmed"
          }
      }
    }
  }
}

fn highlighted_hidden_count_for_source(
  context: Context(msg),
  task_id: Int,
) -> opt.Option(Int) {
  case context.pool.member_highlight_state {
    member_pool_state.BlockingHighlight(
      source_task_id: source_task_id,
      hidden_count: hidden_count,
      ..,
    )
      if source_task_id == task_id
    -> opt.Some(hidden_count)
    _ -> opt.None
  }
}

fn hover_notes_for_task(context: Context(msg), task_id: Int) -> List(Note) {
  case dict.get(context.notes.member_hover_notes_cache, task_id) {
    Ok(notes) -> notes
    Error(_) -> []
  }
}

fn hidden_blocked_count(context: Context(msg), task_id: Int) -> opt.Option(Int) {
  case highlighted_hidden_count_for_source(context, task_id) {
    opt.Some(hidden_count) if hidden_count > 0 -> opt.Some(hidden_count)
    _ -> opt.None
  }
}

fn task_position(context: Context(msg), task_id: Int) -> #(Int, Int) {
  case dict.get(context.positions.member_positions_by_task, task_id) {
    Ok(xy) -> xy
    Error(_) -> initial_task_position(unpositioned_task_index(context, task_id))
  }
}

fn unpositioned_task_index(context: Context(msg), task_id: Int) -> Int {
  let tasks =
    context.pool.member_tasks
    |> unwrap([])
    |> list.filter(fn(task) {
      let Task(id: id, ..) = task
      case dict.get(context.positions.member_positions_by_task, id) {
        Ok(_) -> False
        Error(_) -> True
      }
    })

  case
    list.index_map(tasks, fn(task, index) {
      let Task(id: id, ..) = task
      #(id, index)
    })
    |> list.find(fn(pair) {
      let #(id, _) = pair
      id == task_id
    })
  {
    Ok(#(_, index)) -> index
    Error(_) -> 0
  }
}

fn initial_task_position(index: Int) -> #(Int, Int) {
  let card_size = 128
  let gap = 32
  let columns = 5
  let padding = 12
  let initial_x = padding + { { index % columns } * { card_size + gap } }
  let initial_y = padding + { { index / columns } * { card_size + gap } }
  #(initial_x, initial_y)
}

fn age_in_days(created_at: String) -> Int {
  client_ffi.days_since_iso(created_at)
}
