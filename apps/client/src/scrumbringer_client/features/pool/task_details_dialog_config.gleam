import gleam/list
import gleam/option as opt
import lustre/element.{type Element}

import domain/card.{type Card}
import domain/remote.{Failed, Loaded, Loading, NotAsked}
import domain/task.{type Task}

import scrumbringer_client/client_state/member/dependencies as dependencies_state
import scrumbringer_client/client_state/member/notes as notes_state
import scrumbringer_client/client_state/member/pool as pool_state
import scrumbringer_client/features/pool/dialogs
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/ui/task_tabs
import scrumbringer_client/utils/card_queries

pub type Callbacks(msg) {
  Callbacks(
    on_close: msg,
    on_tab_clicked: fn(task_tabs.Tab) -> msg,
    on_dependency_dialog_opened: msg,
    on_dependency_dialog_closed: msg,
    on_dependency_add_submitted: msg,
    on_dependency_search_changed: fn(String) -> msg,
    on_dependency_selected: fn(Int) -> msg,
    on_dependency_remove: fn(Int) -> msg,
    on_edit_started: msg,
    on_edit_cancelled: msg,
    on_edit_title_changed: fn(String) -> msg,
    on_edit_description_changed: fn(String) -> msg,
    on_edit_submitted: msg,
    on_note_dialog_opened: msg,
    on_note_dialog_closed: msg,
    on_note_content_changed: fn(String) -> msg,
    on_note_submitted: msg,
    on_note_delete: fn(Int) -> msg,
    on_claim: fn(Int, Int) -> msg,
    on_release: fn(Int, Int) -> msg,
    on_complete: fn(Int, Int) -> msg,
  )
}

pub fn view(
  locale: Locale,
  pool: pool_state.Model,
  dependencies: dependencies_state.Model,
  notes: notes_state.Model,
  current_user_id: opt.Option(Int),
  cards: List(Card),
  task_id: Int,
  callbacks: Callbacks(msg),
) -> Element(msg) {
  dialogs.view_task_details(from_state(
    locale,
    pool,
    dependencies,
    notes,
    current_user_id,
    cards,
    task_id,
    callbacks,
  ))
}

pub fn from_state(
  locale: Locale,
  pool: pool_state.Model,
  dependencies: dependencies_state.Model,
  notes: notes_state.Model,
  current_user_id: opt.Option(Int),
  cards: List(Card),
  task_id: Int,
  callbacks: Callbacks(msg),
) -> dialogs.TaskDetailsConfig(msg) {
  let task = find_task(pool, task_id)

  dialogs.TaskDetailsConfig(
    locale: locale,
    task_id: task_id,
    task: task,
    current_user_id: current_user_id,
    active_tab: pool.member_task_detail_tab,
    notes: notes.member_notes,
    metrics: pool.member_task_detail_metrics,
    dependencies: dependencies.member_dependencies,
    dependency_dialog_mode: dependencies.member_dependency_dialog_mode,
    dependency_search_query: dependencies.member_dependency_search_query,
    dependency_candidates: dependencies.member_dependency_candidates,
    dependency_selected_task_id: dependencies.member_dependency_selected_task_id,
    dependency_add_in_flight: dependencies.member_dependency_add_in_flight,
    dependency_add_error: dependencies.member_dependency_add_error,
    dependency_remove_in_flight: dependencies.member_dependency_remove_in_flight,
    editing: pool.member_task_detail_editing,
    edit_title: pool.member_task_detail_edit_title,
    edit_description: pool.member_task_detail_edit_description,
    edit_error: pool.member_task_detail_edit_error,
    edit_in_flight: pool.member_task_detail_edit_in_flight,
    parent_card_title: parent_card_title(cards, task),
    note_dialog_mode: notes.member_note_dialog_mode,
    note_content: notes.member_note_content,
    note_error: notes.member_note_error,
    note_in_flight: notes.member_note_in_flight,
    disable_actions: pool.member_task_mutation_in_flight
      || pool.member_task_detail_editing
      || pool.member_task_detail_edit_in_flight,
    on_close: callbacks.on_close,
    on_tab_clicked: callbacks.on_tab_clicked,
    on_dependency_dialog_opened: callbacks.on_dependency_dialog_opened,
    on_dependency_dialog_closed: callbacks.on_dependency_dialog_closed,
    on_dependency_add_submitted: callbacks.on_dependency_add_submitted,
    on_dependency_search_changed: callbacks.on_dependency_search_changed,
    on_dependency_selected: callbacks.on_dependency_selected,
    on_dependency_remove: callbacks.on_dependency_remove,
    on_edit_started: callbacks.on_edit_started,
    on_edit_cancelled: callbacks.on_edit_cancelled,
    on_edit_title_changed: callbacks.on_edit_title_changed,
    on_edit_description_changed: callbacks.on_edit_description_changed,
    on_edit_submitted: callbacks.on_edit_submitted,
    on_note_dialog_opened: callbacks.on_note_dialog_opened,
    on_note_dialog_closed: callbacks.on_note_dialog_closed,
    on_note_content_changed: callbacks.on_note_content_changed,
    on_note_submitted: callbacks.on_note_submitted,
    on_note_delete: callbacks.on_note_delete,
    on_claim: callbacks.on_claim,
    on_release: callbacks.on_release,
    on_complete: callbacks.on_complete,
  )
}

fn find_task(pool: pool_state.Model, task_id: Int) -> opt.Option(Task) {
  case pool.member_tasks {
    Loaded(tasks) ->
      list.find(tasks, fn(task) { task.id == task_id }) |> opt.from_result
    NotAsked | Loading | Failed(_) -> opt.None
  }
}

fn parent_card_title(
  cards: List(Card),
  task: opt.Option(Task),
) -> opt.Option(String) {
  case task {
    opt.Some(current_task) -> {
      let #(title, _color) =
        card_queries.resolve_task_card_info(cards, current_task)
      title
    }
    opt.None -> opt.None
  }
}
