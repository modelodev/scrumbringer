import gleam/option as opt
import lustre/element.{type Element}

import domain/activity/entity.{type ActivityEvent}
import domain/card.{type Card}
import domain/remote.{type Remote}
import domain/task.{type Task}

import scrumbringer_client/client_state/member/dependencies as dependencies_state
import scrumbringer_client/client_state/member/notes as notes_state
import scrumbringer_client/client_state/member/pool as pool_state
import scrumbringer_client/features/pool/dialogs
import scrumbringer_client/helpers/lookup as helpers_lookup
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/ui/show_tabs
import scrumbringer_client/utils/card_queries

pub type Callbacks(msg) {
  Callbacks(
    on_close: msg,
    on_tab_clicked: fn(show_tabs.TaskShowTab) -> msg,
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
    on_edit_priority_changed: fn(String) -> msg,
    on_edit_type_id_changed: fn(String) -> msg,
    on_edit_card_id_changed: fn(String) -> msg,
    on_edit_submitted: msg,
    on_note_dialog_opened: msg,
    on_note_dialog_closed: msg,
    on_note_content_changed: fn(String) -> msg,
    on_note_submitted: msg,
    on_note_delete: fn(Int) -> msg,
    on_note_pin_toggle: fn(Int, Bool) -> msg,
    on_claim: fn(Int, Int) -> msg,
    on_release: fn(Int, Int) -> msg,
    on_complete: fn(Int, Int) -> msg,
    on_delete: fn(Int) -> msg,
  )
}

pub fn view(
  locale: Locale,
  pool: pool_state.Model,
  dependencies: dependencies_state.Model,
  notes: notes_state.Model,
  current_user_id: opt.Option(Int),
  can_manage_notes: Bool,
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
    can_manage_notes,
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
  can_manage_notes: Bool,
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
    dependencies: dependencies_config(dependencies, callbacks),
    editor: editor_config(pool, cards, task, callbacks),
    notes: notes_config(notes, can_manage_notes, callbacks),
    activity: activity_config(notes),
    actions: actions_config(pool, callbacks),
    on_close: callbacks.on_close,
    on_tab_clicked: callbacks.on_tab_clicked,
  )
}

fn activity_config(notes: notes_state.Model) -> Remote(List(ActivityEvent)) {
  notes.member_activity
}

fn dependencies_config(
  dependencies: dependencies_state.Model,
  callbacks: Callbacks(msg),
) -> dialogs.TaskDependenciesConfig(msg) {
  dialogs.TaskDependenciesConfig(
    items: dependencies.member_dependencies,
    dialog_mode: dependencies.member_dependency_dialog_mode,
    search_query: dependencies.member_dependency_search_query,
    candidates: dependencies.member_dependency_candidates,
    selected_task_id: dependencies.member_dependency_selected_task_id,
    add_in_flight: dependencies.member_dependency_add_in_flight,
    add_error: dependencies.member_dependency_add_error,
    remove_in_flight: dependencies.member_dependency_remove_in_flight,
    on_dialog_opened: callbacks.on_dependency_dialog_opened,
    on_dialog_closed: callbacks.on_dependency_dialog_closed,
    on_add_submitted: callbacks.on_dependency_add_submitted,
    on_search_changed: callbacks.on_dependency_search_changed,
    on_selected: callbacks.on_dependency_selected,
    on_remove: callbacks.on_dependency_remove,
  )
}

fn editor_config(
  pool: pool_state.Model,
  cards: List(Card),
  task: opt.Option(Task),
  callbacks: Callbacks(msg),
) -> dialogs.TaskEditorConfig(msg) {
  dialogs.TaskEditorConfig(
    editing: pool.member_task_detail_editing,
    edit_title: pool.member_task_detail_edit_title,
    edit_description: pool.member_task_detail_edit_description,
    edit_priority: pool.member_task_detail_edit_priority,
    edit_type_id: pool.member_task_detail_edit_type_id,
    edit_card_id: pool.member_task_detail_edit_card_id,
    edit_error: pool.member_task_detail_edit_error,
    edit_in_flight: pool.member_task_detail_edit_in_flight,
    task_types: pool.member_task_types,
    cards: cards,
    parent_card_title: parent_card_title(cards, task),
    on_edit_started: callbacks.on_edit_started,
    on_edit_cancelled: callbacks.on_edit_cancelled,
    on_edit_title_changed: callbacks.on_edit_title_changed,
    on_edit_description_changed: callbacks.on_edit_description_changed,
    on_edit_priority_changed: callbacks.on_edit_priority_changed,
    on_edit_type_id_changed: callbacks.on_edit_type_id_changed,
    on_edit_card_id_changed: callbacks.on_edit_card_id_changed,
    on_edit_submitted: callbacks.on_edit_submitted,
  )
}

fn notes_config(
  notes: notes_state.Model,
  can_manage_notes: Bool,
  callbacks: Callbacks(msg),
) -> dialogs.TaskNotesConfig(msg) {
  dialogs.TaskNotesConfig(
    can_manage: can_manage_notes,
    items: notes.member_notes,
    dialog_mode: notes.member_note_dialog_mode,
    content: notes.member_note_content,
    error: notes.member_note_error,
    in_flight: notes.member_note_in_flight,
    delete_in_flight: notes.member_note_delete_in_flight,
    pin_in_flight: notes.member_note_pin_in_flight,
    on_dialog_opened: callbacks.on_note_dialog_opened,
    on_dialog_closed: callbacks.on_note_dialog_closed,
    on_content_changed: callbacks.on_note_content_changed,
    on_submitted: callbacks.on_note_submitted,
    on_delete: callbacks.on_note_delete,
    on_pin_toggle: callbacks.on_note_pin_toggle,
  )
}

fn actions_config(
  pool: pool_state.Model,
  callbacks: Callbacks(msg),
) -> dialogs.TaskActionsConfig(msg) {
  dialogs.TaskActionsConfig(
    disable_actions: pool.member_task_mutation_in_flight
      || pool.member_task_detail_editing
      || pool.member_task_detail_edit_in_flight,
    on_claim: callbacks.on_claim,
    on_release: callbacks.on_release,
    on_complete: callbacks.on_complete,
    on_delete: callbacks.on_delete,
  )
}

fn find_task(pool: pool_state.Model, task_id: Int) -> opt.Option(Task) {
  helpers_lookup.find_task_by_id_in_cache(
    pool.member_tasks,
    pool.member_tasks_by_project,
    task_id,
  )
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
