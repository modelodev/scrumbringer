import domain/org.{type OrgUser}
import domain/remote.{type Remote, unwrap}
import lustre/element.{type Element}

import scrumbringer_client/client_state/member/pool as pool_state
import scrumbringer_client/features/milestones/view as milestone_view
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/theme.{type Theme}

pub type Callbacks(msg) {
  Callbacks(
    on_create_milestone: msg,
    on_dialog_close: msg,
    on_activate_clicked: fn(Int) -> msg,
    on_create_submitted: msg,
    on_edit_submitted: fn(Int) -> msg,
    on_delete_submitted: fn(Int) -> msg,
    on_name_changed: fn(String) -> msg,
    on_description_changed: fn(String) -> msg,
    on_search_change: fn(String) -> msg,
    on_toggle_completed: msg,
    on_toggle_empty: msg,
    on_view_kanban: msg,
    on_select: fn(Int) -> msg,
    on_summary_toggle: msg,
    on_card_toggle: fn(Int) -> msg,
    on_quick_create_card: fn(Int) -> msg,
    on_quick_create_task: fn(Int) -> msg,
    on_activate_prompt: fn(Int) -> msg,
    on_edit: fn(Int) -> msg,
    on_delete: fn(Int) -> msg,
    on_task_open: fn(Int) -> msg,
    on_task_claim: fn(Int, Int) -> msg,
    on_card_drag_started: fn(Int, Int) -> msg,
    on_task_drag_started: fn(Int, Int) -> msg,
    on_drag_ended: msg,
    on_card_move: fn(Int, Int, Int) -> msg,
    on_task_move: fn(Int, Int, Int) -> msg,
    on_card_create_task: fn(Int) -> msg,
    on_card_edit: fn(Int) -> msg,
    on_card_delete: fn(Int) -> msg,
  )
}

pub fn view(
  locale: Locale,
  theme: Theme,
  selected_project_id,
  pool: pool_state.Model,
  org_users_cache: Remote(List(OrgUser)),
  can_manage: Bool,
  callbacks: Callbacks(msg),
) -> Element(msg) {
  milestone_view.view(from_state(
    locale,
    theme,
    selected_project_id,
    pool,
    org_users_cache,
    can_manage,
    callbacks,
  ))
}

pub fn from_state(
  locale: Locale,
  theme: Theme,
  selected_project_id,
  pool: pool_state.Model,
  org_users_cache: Remote(List(OrgUser)),
  can_manage: Bool,
  callbacks: Callbacks(msg),
) -> milestone_view.Config(msg) {
  milestone_view.Config(
    locale: locale,
    theme: theme,
    milestones: pool.member_milestones,
    selected_project_id: selected_project_id,
    search_query: pool.member_milestones_search_query,
    show_completed: pool.member_milestones_show_completed,
    show_empty: pool.member_milestones_show_empty,
    selected_milestone_id: pool.member_selected_milestone_id,
    summary_expanded: pool.member_milestone_summary_expanded,
    expanded_cards: pool.member_milestone_expanded_cards,
    dialog: pool.member_milestone_dialog,
    dialog_in_flight: pool.member_milestone_dialog_in_flight,
    dialog_error: pool.member_milestone_dialog_error,
    activation_in_flight_id: pool.member_milestone_activate_in_flight_id,
    cards: unwrap(pool.member_cards, []),
    tasks: unwrap(pool.member_tasks, []),
    org_users: unwrap(org_users_cache, []),
    can_manage: can_manage,
    on_create_milestone: callbacks.on_create_milestone,
    on_dialog_close: callbacks.on_dialog_close,
    on_activate_clicked: callbacks.on_activate_clicked,
    on_create_submitted: callbacks.on_create_submitted,
    on_edit_submitted: callbacks.on_edit_submitted,
    on_delete_submitted: callbacks.on_delete_submitted,
    on_name_changed: callbacks.on_name_changed,
    on_description_changed: callbacks.on_description_changed,
    on_search_change: callbacks.on_search_change,
    on_toggle_completed: callbacks.on_toggle_completed,
    on_toggle_empty: callbacks.on_toggle_empty,
    on_view_kanban: callbacks.on_view_kanban,
    on_select: callbacks.on_select,
    on_summary_toggle: callbacks.on_summary_toggle,
    on_card_toggle: callbacks.on_card_toggle,
    on_quick_create_card: callbacks.on_quick_create_card,
    on_quick_create_task: callbacks.on_quick_create_task,
    on_activate_prompt: callbacks.on_activate_prompt,
    on_edit: callbacks.on_edit,
    on_delete: callbacks.on_delete,
    on_task_open: callbacks.on_task_open,
    on_task_claim: callbacks.on_task_claim,
    on_card_drag_started: callbacks.on_card_drag_started,
    on_task_drag_started: callbacks.on_task_drag_started,
    on_drag_ended: callbacks.on_drag_ended,
    on_card_move: callbacks.on_card_move,
    on_task_move: callbacks.on_task_move,
    on_card_create_task: callbacks.on_card_create_task,
    on_card_edit: callbacks.on_card_edit,
    on_card_delete: callbacks.on_card_delete,
  )
}
