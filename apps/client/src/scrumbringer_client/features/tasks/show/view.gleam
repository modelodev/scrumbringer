//// Task Show components for Scrumbringer client.
////
//// ## Mission
////
//// Render Task Show and its secondary dialogs for the pool view.
////
//// ## Responsibilities
////
//// - Task Show panel with notes, dependencies, activity, and action bar
////
//// ## Non-responsibilities
////
//// - Task creation dialog wiring (see features/pool/create_dialog_config.gleam)
//// - Position edit dialog wiring (see features/pool/position_edit_dialog_config.gleam)
//// - Task Show state management (see features/pool/update.gleam, features/tasks/show_update.gleam)
//// - Form validation (handled by update handlers)
////
//// ## Relations
////
//// - **features/pool/view.gleam**: Imports and renders this surface

import gleam/int
import gleam/list
import gleam/option as opt

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, text}

import domain/activity/entity.{type ActivityEvent}
import domain/card.{type Card}
import domain/note/entity as note_entity
import domain/note/id as note_ids
import domain/remote.{type Remote, Loaded}
import domain/task.{type Task, type TaskDependency}
import domain/task_type.{type TaskType}

import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/features/cards/scoped_navigation
import scrumbringer_client/features/hierarchy/scope_view
import scrumbringer_client/features/pool/task_dependencies
import scrumbringer_client/features/pool/task_notes
import scrumbringer_client/features/tasks/show/actions as task_show_actions
import scrumbringer_client/features/tasks/show/details as task_show_details
import scrumbringer_client/features/tasks/show/header as task_show_header
import scrumbringer_client/features/tasks/show_editor
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/action_menu
import scrumbringer_client/ui/activity_feed
import scrumbringer_client/ui/button
import scrumbringer_client/ui/inspector_actions
import scrumbringer_client/ui/inspector_shell
import scrumbringer_client/ui/pinned_context
import scrumbringer_client/ui/show_tabs
import scrumbringer_client/ui/tabs

pub type TaskShowConfig(msg) {
  TaskShowConfig(
    locale: Locale,
    task_id: Int,
    task: opt.Option(Task),
    parent_card: opt.Option(Card),
    current_user_id: opt.Option(Int),
    active_tab: show_tabs.TaskShowTab,
    dependencies: TaskDependenciesConfig(msg),
    editor: TaskEditorConfig(msg),
    notes: TaskNotesConfig(msg),
    activity: Remote(List(ActivityEvent)),
    activity_total: Int,
    activity_loading_more: Bool,
    on_activity_more: msg,
    actions: TaskActionsConfig(msg),
    on_close: msg,
    on_open_parent_card: fn(Int) -> msg,
    on_tab_clicked: fn(show_tabs.TaskShowTab) -> msg,
  )
}

pub type TaskDependenciesConfig(msg) {
  TaskDependenciesConfig(
    items: Remote(List(TaskDependency)),
    dialog_mode: dialog_mode.DialogMode,
    search_query: String,
    candidates: Remote(List(Task)),
    selected_task_id: opt.Option(Int),
    add_in_flight: Bool,
    add_error: opt.Option(String),
    remove_in_flight: opt.Option(Int),
    on_dialog_opened: msg,
    on_dialog_closed: msg,
    on_add_submitted: msg,
    on_search_changed: fn(String) -> msg,
    on_selected: fn(Int) -> msg,
    on_remove: fn(Int) -> msg,
  )
}

pub type TaskEditorConfig(msg) {
  TaskEditorConfig(
    editing: Bool,
    edit_title: String,
    edit_description: String,
    edit_priority: String,
    edit_type_id: String,
    edit_card_id: String,
    edit_card_query: String,
    edit_error: opt.Option(String),
    edit_in_flight: Bool,
    task_types: Remote(List(TaskType)),
    cards: List(Card),
    depth_names: List(scope_view.DepthName),
    parent_card_title: opt.Option(String),
    on_edit_started: msg,
    on_edit_cancelled: msg,
    on_edit_title_changed: fn(String) -> msg,
    on_edit_description_changed: fn(String) -> msg,
    on_edit_priority_changed: fn(String) -> msg,
    on_edit_type_id_changed: fn(String) -> msg,
    on_edit_card_id_changed: fn(String) -> msg,
    on_edit_card_query_changed: fn(String) -> msg,
    on_edit_submitted: msg,
  )
}

pub type TaskNotesConfig(msg) {
  TaskNotesConfig(
    can_manage: Bool,
    items: Remote(List(note_entity.Note)),
    dialog_mode: dialog_mode.DialogMode,
    content: String,
    error: opt.Option(String),
    in_flight: Bool,
    delete_in_flight: opt.Option(Int),
    pin_in_flight: opt.Option(Int),
    on_dialog_opened: msg,
    on_dialog_closed: msg,
    on_content_changed: fn(String) -> msg,
    on_submitted: msg,
    on_delete: fn(Int) -> msg,
    on_pin_toggle: fn(Int, Bool) -> msg,
  )
}

pub type TaskActionsConfig(msg) {
  TaskActionsConfig(
    disable_actions: Bool,
    on_claim: fn(Int, Int) -> msg,
    on_start_work: fn(Int) -> msg,
    on_release: fn(Int, Int) -> msg,
    on_task_close: fn(Int, Int) -> msg,
    on_delete: fn(Int) -> msg,
  )
}

pub fn view_task_show(config: TaskShowConfig(msg)) -> Element(msg) {
  inspector_shell.detail(
    inspector_shell.Config(
      root_class: "task-show task-show-panel",
      panel_class: "task-show-content",
      title_id: "task-show-title",
      testid: "task-show",
    ),
    "task-show-header-block",
    "task-show-body",
    view_task_header(config),
    view_task_show_tabs(config),
    view_task_tab_content(config),
    [],
  )
}

fn view_task_header(config: TaskShowConfig(msg)) -> Element(msg) {
  task_show_header.view(task_show_header.Config(
    locale: config.locale,
    task: config.task,
    parent_card_title: config.editor.parent_card_title,
    current_user_id: config.current_user_id,
    dependencies: config.dependencies.items,
    actions: opt.Some(view_task_inspector_actions(config)),
    on_close: config.on_close,
  ))
}

fn view_task_inspector_actions(config: TaskShowConfig(msg)) -> Element(msg) {
  inspector_actions.view(inspector_actions.Config(
    id: "task-" <> int.to_string(config.task_id),
    primary: opt.Some(view_task_primary_action(config)),
    open_in_label: i18n.t(config.locale, i18n_text.OpenIn),
    open_in_items: task_open_in_items(config),
    more_label: i18n.t(config.locale, i18n_text.HierarchyMoreActions),
    more_items: task_secondary_action_items(config),
    extra_class: "task-inspector-actions",
  ))
}

fn task_open_in_items(
  config: TaskShowConfig(msg),
) -> List(action_menu.Item(msg)) {
  case config.parent_card {
    opt.Some(card) -> [
      action_menu.item(
        i18n.t(config.locale, i18n_text.OpenCard),
        "task-open-parent-card",
        config.on_open_parent_card(card.id),
      ),
      action_menu.link_item(
        i18n.t(config.locale, i18n_text.ViewInPlan),
        "task-open-plan",
        scoped_navigation.plan_url(card),
      ),
    ]
    opt.None -> []
  }
}

fn view_task_primary_action(config: TaskShowConfig(msg)) -> Element(msg) {
  case config.editor.editing {
    True -> view_edit_primary_actions(config)
    False ->
      case
        task_show_actions.primary_action(
          config.task,
          config.current_user_id,
          config.actions.disable_actions,
        )
      {
        task_show_actions.ClaimTask(id, version) ->
          button.text(
            i18n.t(config.locale, i18n_text.ClaimTask),
            config.actions.on_claim(id, version),
            button.Primary,
            button.EntityAction,
          )
          |> button.with_testid("task-inspector-primary-claim")
          |> button.view
        task_show_actions.StartWork(id) ->
          button.text(
            i18n.t(config.locale, i18n_text.TaskNextActionStart),
            config.actions.on_start_work(id),
            button.Primary,
            button.EntityAction,
          )
          |> button.with_testid("task-inspector-primary-start")
          |> button.view
        task_show_actions.CloseTask(id, version) ->
          button.text(
            i18n.t(config.locale, i18n_text.TaskNextActionClose),
            config.actions.on_task_close(id, version),
            button.Primary,
            button.EntityAction,
          )
          |> button.with_testid("task-inspector-primary-close")
          |> button.view
        task_show_actions.NoPrimaryAction(reason) ->
          div(
            [
              attribute.class("task-inspector-no-primary"),
              attribute.attribute("data-testid", "task-inspector-no-primary"),
            ],
            [text(no_primary_reason_label(config.locale, reason))],
          )
      }
  }
}

fn view_edit_primary_actions(config: TaskShowConfig(msg)) -> Element(msg) {
  div([attribute.class("task-inspector-edit-actions")], [
    button.text(
      i18n.t(config.locale, i18n_text.Cancel),
      config.editor.on_edit_cancelled,
      button.Secondary,
      button.EntityAction,
    )
      |> button.with_disabled(config.editor.edit_in_flight)
      |> button.view,
    button.text(
      i18n.t(config.locale, i18n_text.Save),
      config.editor.on_edit_submitted,
      button.Primary,
      button.EntityAction,
    )
      |> button.with_disabled(
        config.editor.edit_in_flight || !edit_dirty(config),
      )
      |> button.with_class("task-show-save")
      |> button.view,
  ])
}

fn task_secondary_action_items(
  config: TaskShowConfig(msg),
) -> List(action_menu.Item(msg)) {
  case config.task {
    opt.None -> []
    opt.Some(task) -> secondary_action_items(config, task)
  }
}

fn secondary_action_items(
  config: TaskShowConfig(msg),
  task: Task,
) -> List(action_menu.Item(msg)) {
  let release_items = case
    task_show_actions.can_release(task, config.current_user_id)
  {
    True -> [
      action_menu.item(
        i18n.t(config.locale, i18n_text.TaskNextActionRelease),
        "task-show-secondary-release",
        config.actions.on_release(task.id, task.version),
      ),
    ]
    False -> []
  }

  list.append(release_items, [
    action_menu.disabled_item(
      i18n.t(config.locale, i18n_text.Delete),
      "task-show-secondary-delete",
      i18n.t(config.locale, i18n_text.TaskHasOperationalHistory),
      config.actions.on_delete(task.id),
    ),
  ])
}

fn no_primary_reason_label(
  locale: Locale,
  reason: task_show_actions.NoPrimaryReason,
) -> String {
  case reason {
    task_show_actions.LoadingTask -> i18n.t(locale, i18n_text.LoadingEllipsis)
    task_show_actions.ActionsDisabled -> i18n.t(locale, i18n_text.Working)
    task_show_actions.BlockedByDependencies ->
      i18n.t(locale, i18n_text.TaskBlockedByDependencies)
    task_show_actions.ClaimedByAnotherUser ->
      i18n.t(locale, i18n_text.TaskAlreadyClaimed)
    task_show_actions.ClosedTask -> i18n.t(locale, i18n_text.TaskNextActionOpen)
    task_show_actions.NoCurrentUser ->
      i18n.t(locale, i18n_text.GoToPoolToClaimTasks)
  }
}

fn view_task_show_tabs(config: TaskShowConfig(msg)) -> Element(msg) {
  tabs.view(
    tabs.config(
      active: config.active_tab,
      tabs: task_tab_items(config),
      container_class: "task-show-tabs detail-tabs",
      tab_class: "task-tab task-show-tab detail-tab",
      on_click: config.on_tab_clicked,
    )
    |> tabs.with_testid("entity-tabs"),
  )
}

fn view_task_tab_content(config: TaskShowConfig(msg)) -> Element(msg) {
  let panel = case config.active_tab {
    show_tabs.TaskDetailsTab -> view_task_details_tab(config)
    show_tabs.TaskDependenciesTab -> view_dependencies(config)
    show_tabs.TaskNotesTab -> view_notes(config)
    show_tabs.TaskActivityTab -> view_task_activity(config)
  }

  tabs.panel(config.active_tab, task_tab_items(config), panel)
}

fn task_tab_items(
  config: TaskShowConfig(msg),
) -> List(tabs.TabItem(show_tabs.TaskShowTab)) {
  show_tabs.task_items(
    show_tabs.TaskLabels(
      details: i18n.t(config.locale, i18n_text.TabDetails),
      dependencies: i18n.t(config.locale, i18n_text.TabBlockers),
      notes: i18n.t(config.locale, i18n_text.TabNotes),
      activity: i18n.t(config.locale, i18n_text.TabActivity),
    ),
    notes_count(config.notes.items),
    False,
  )
}

fn notes_count(notes: Remote(List(note_entity.Note))) -> Int {
  case notes {
    Loaded(notes) -> list.length(notes)
    _ -> 0
  }
}

fn view_task_activity(config: TaskShowConfig(msg)) -> Element(msg) {
  div([attribute.class("task-activity-panel")], [
    activity_feed.view(activity_feed.Config(
      events: config.activity,
      loading_label: i18n.t(config.locale, i18n_text.ActivityLoading),
      empty_label: i18n.t(config.locale, i18n_text.ActivityEmpty),
      error_label: i18n.t(config.locale, i18n_text.ActivityLoadFailed),
      load_more: task_activity_load_more(config),
    )),
  ])
}

fn task_activity_load_more(
  config: TaskShowConfig(msg),
) -> opt.Option(activity_feed.LoadMore(msg)) {
  case config.activity {
    Loaded(events) -> {
      let loaded_count = list.length(events)
      case loaded_count < config.activity_total {
        True ->
          opt.Some(activity_feed.LoadMore(
            label: i18n.t(
              config.locale,
              i18n_text.ActivityLoadMore(config.activity_total - loaded_count),
            ),
            in_flight: config.activity_loading_more,
            on_click: config.on_activity_more,
          ))
        False -> opt.None
      }
    }
    _ -> opt.None
  }
}

/// Renders the dependencies section for a task.
fn view_dependencies(config: TaskShowConfig(msg)) -> Element(msg) {
  task_dependencies.view(task_dependencies.Config(
    locale: config.locale,
    task_id: config.task_id,
    task: config.task,
    dependencies: config.dependencies.items,
    dialog_mode: config.dependencies.dialog_mode,
    search_query: config.dependencies.search_query,
    candidates: config.dependencies.candidates,
    selected_task_id: config.dependencies.selected_task_id,
    add_in_flight: config.dependencies.add_in_flight,
    add_error: config.dependencies.add_error,
    remove_in_flight: config.dependencies.remove_in_flight,
    on_dialog_opened: config.dependencies.on_dialog_opened,
    on_dialog_closed: config.dependencies.on_dialog_closed,
    on_add_submitted: config.dependencies.on_add_submitted,
    on_search_changed: config.dependencies.on_search_changed,
    on_selected: config.dependencies.on_selected,
    on_remove: config.dependencies.on_remove,
  ))
}

fn view_task_details_tab(config: TaskShowConfig(msg)) -> Element(msg) {
  task_show_details.view(details_config(config))
}

fn details_config(config: TaskShowConfig(msg)) -> task_show_details.Config(msg) {
  task_show_details.Config(
    locale: config.locale,
    task: config.task,
    dependencies: config.dependencies.items,
    parent_card_title: config.editor.parent_card_title,
    pinned_notes: pinned_task_notes(config.notes.items),
    on_open_notes: config.on_tab_clicked(show_tabs.TaskNotesTab),
    editor: editor_config(config),
  )
}

fn pinned_task_notes(
  notes: Remote(List(note_entity.Note)),
) -> List(pinned_context.PinnedNote) {
  case notes {
    Loaded(items) ->
      items
      |> list.filter(fn(note) { note.pinned })
      |> list.map(fn(note) {
        pinned_context.PinnedNote(
          id: note_ids.to_int(note.id),
          content: note.content,
          url: note.url,
        )
      })
    _ -> []
  }
}

fn editor_config(config: TaskShowConfig(msg)) -> show_editor.Config(msg) {
  show_editor.Config(
    locale: config.locale,
    current_user_id: config.current_user_id,
    editing: config.editor.editing,
    edit_title: config.editor.edit_title,
    edit_description: config.editor.edit_description,
    edit_priority: config.editor.edit_priority,
    edit_type_id: config.editor.edit_type_id,
    edit_card_id: config.editor.edit_card_id,
    edit_card_query: config.editor.edit_card_query,
    edit_error: config.editor.edit_error,
    edit_in_flight: config.editor.edit_in_flight,
    task_types: config.editor.task_types,
    cards: config.editor.cards,
    depth_names: config.editor.depth_names,
    on_edit_started: config.editor.on_edit_started,
    on_edit_cancelled: config.editor.on_edit_cancelled,
    on_title_changed: config.editor.on_edit_title_changed,
    on_description_changed: config.editor.on_edit_description_changed,
    on_priority_changed: config.editor.on_edit_priority_changed,
    on_type_id_changed: config.editor.on_edit_type_id_changed,
    on_card_id_changed: config.editor.on_edit_card_id_changed,
    on_card_query_changed: config.editor.on_edit_card_query_changed,
    on_submitted: config.editor.on_edit_submitted,
  )
}

fn view_notes(config: TaskShowConfig(msg)) -> Element(msg) {
  task_notes.view(task_notes.Config(
    locale: config.locale,
    current_user_id: config.current_user_id,
    can_manage_notes: config.notes.can_manage,
    notes: config.notes.items,
    dialog_mode: config.notes.dialog_mode,
    note_content: config.notes.content,
    note_error: config.notes.error,
    note_in_flight: config.notes.in_flight,
    delete_in_flight: config.notes.delete_in_flight,
    pin_in_flight: config.notes.pin_in_flight,
    on_dialog_opened: config.notes.on_dialog_opened,
    on_dialog_closed: config.notes.on_dialog_closed,
    on_content_changed: config.notes.on_content_changed,
    on_submitted: config.notes.on_submitted,
    on_delete: config.notes.on_delete,
    on_pin_toggle: config.notes.on_pin_toggle,
  ))
}

fn edit_dirty(config: TaskShowConfig(msg)) -> Bool {
  case config.task {
    opt.Some(task) -> task_show_details.is_dirty(details_config(config), task)
    opt.None -> False
  }
}
