//// Card Detail Show Component.
////
//// ## Mission
////
//// Lustre component model/update/view for displaying card details with tabs
//// for Summary, Work, Notes, and Activity.
////
//// ## Responsibilities
////
//// - Display card header with title, state, progress, description
//// - Tab navigation (Tasks/Notes/Activity)
//// - Display task list and expose typed messages to open main task dialog
//// - Manage notes: view, add, delete
//// - Expose typed messages to parent for actions (close, create-task)
////
//// ## Relations
////
//// - Parent: features/cards/view.gleam renders this component
//// - API: api/cards.gleam for getting card notes

import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/string

import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html.{div, span, text}
import lustre/event

import domain/card.{type Card, Closed, Draft}
import domain/note/entity.{type Note}
import domain/note/id as note_ids
import domain/task.{type Task, claimed_by}
import domain/task/state as task_state
import domain/user/id as user_ids

import domain/activity/entity as activity_entity
import domain/api_error.{type ApiError, type ApiResult}
import domain/remote.{type Remote, Failed, Loaded, Loading, NotAsked}
import scrumbringer_client/api/activity as api_activity
import scrumbringer_client/api/cards as api_cards
import scrumbringer_client/features/cards/policy as card_policy
import scrumbringer_client/features/cards/scoped_navigation
import scrumbringer_client/features/cards/show/hierarchy as show_hierarchy
import scrumbringer_client/features/cards/show/notes as show_notes
import scrumbringer_client/i18n/en as i18n_en
import scrumbringer_client/i18n/es as i18n_es
import scrumbringer_client/i18n/locale.{type Locale, En, Es}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/action_menu
import scrumbringer_client/ui/activity_feed
import scrumbringer_client/ui/button as ui_button
import scrumbringer_client/ui/card_section_header
import scrumbringer_client/ui/card_state
import scrumbringer_client/ui/card_state_badge
import scrumbringer_client/ui/detail_tabs
import scrumbringer_client/ui/empty_state
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/inspector_header
import scrumbringer_client/ui/inspector_shell
import scrumbringer_client/ui/note_dialog
import scrumbringer_client/ui/notes_list
import scrumbringer_client/ui/pinned_context
import scrumbringer_client/ui/show_tabs
import scrumbringer_client/ui/task_color
import scrumbringer_client/ui/task_item
import scrumbringer_client/ui/task_metric
import scrumbringer_client/ui/task_metric_chip
import scrumbringer_client/ui/task_status_indicator
import scrumbringer_client/ui/task_status_utils
import scrumbringer_client/ui/tooltips/types as notes_list_types

// =============================================================================
// Internal Types
// =============================================================================

/// Internal component model - encapsulated state.
pub type Model {
  Model(
    card_id: Option(Int),
    card: Option(Card),
    cards: List(Card),
    locale: Locale,
    current_user_id: Option(Int),
    project_id: Option(Int),
    can_manage_notes: Bool,
    can_manage_structure: Bool,
    can_execute_work: Bool,
    // AC21: Tab system
    active_tab: show_tabs.CardShowTab,
    notes: Remote(List(Note)),
    // Note dialog state
    note_dialog_open: Bool,
    note_content: String,
    note_in_flight: Bool,
    note_error: Option(String),
    note_pin_in_flight: Option(Int),
    activity: Remote(List(activity_entity.ActivityEvent)),
    activity_total: Int,
    activity_loading_more: Bool,
    tasks: Remote(List(Task)),
    activation_confirm_open: Bool,
  )
}

/// Internal messages - not exposed to parent.
pub type Msg {
  // From attributes/properties
  CardIdReceived(Int)
  CardReceived(Card)
  CardsReceived(List(Card))
  LocaleReceived(Locale)
  CurrentUserIdReceived(Int)
  ProjectIdReceived(Int)
  CanManageNotesReceived(Bool)
  CanManageStructureReceived(Bool)
  CanExecuteWorkReceived(Bool)
  NotesReceived(ApiResult(List(Note)))
  ActivityReceived(ApiResult(api_activity.ActivityPage))
  TasksReceived(List(Task))
  // AC21: Tab navigation
  TabClicked(show_tabs.CardShowTab)
  // Note dialog
  NoteDialogOpened
  NoteDialogClosed
  NoteContentChanged(String)
  NoteSubmitted
  NoteCreated(ApiResult(Note))
  NoteDeleteClicked(Int)
  NoteDeleted(Int, ApiResult(Nil))
  NotePinClicked(Int, Bool)
  NotePinned(Int, ApiResult(Note))
  ActivityMoreClicked
  // Card operations
  CreateCardClicked
  ActivateCardClicked
  ActivateCardCancelled
  ActivateCardConfirmed
  MoveRequested
  DeleteCardClicked
  // Actions that emit events to parent
  CreateTaskClicked
  CloseClicked
}

// =============================================================================
// Init
// =============================================================================

pub fn init_model() -> Model {
  Model(
    card_id: option.None,
    card: option.None,
    cards: [],
    locale: En,
    current_user_id: option.None,
    project_id: option.None,
    can_manage_notes: False,
    can_manage_structure: False,
    can_execute_work: False,
    active_tab: show_tabs.default_card_tab(),
    notes: NotAsked,
    note_dialog_open: False,
    note_content: "",
    note_in_flight: False,
    note_error: option.None,
    note_pin_in_flight: option.None,
    activity: NotAsked,
    activity_total: 0,
    activity_loading_more: False,
    tasks: NotAsked,
    activation_confirm_open: False,
  )
}

pub fn init(_: Nil) -> #(Model, Effect(Msg)) {
  #(init_model(), effect.none())
}

pub fn open(card_id: Int) -> #(Model, Effect(Msg)) {
  update(init_model(), CardIdReceived(card_id))
}

pub fn reset() -> Model {
  init_model()
}

pub fn hydrate(
  model: Model,
  card: Card,
  cards: List(Card),
  tasks: List(Task),
  locale: Locale,
  current_user_id: Option(Int),
  project_id: Option(Int),
  can_manage_notes: Bool,
  can_manage_structure: Bool,
  can_execute_work: Bool,
) -> Model {
  Model(
    ..model,
    card: option.Some(card),
    cards: cards,
    locale: locale,
    current_user_id: current_user_id,
    project_id: project_id,
    can_manage_notes: can_manage_notes,
    can_manage_structure: can_manage_structure,
    can_execute_work: can_execute_work,
    tasks: Loaded(tasks),
  )
}

// =============================================================================
// Update
// =============================================================================

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    CardIdReceived(id) -> #(
      Model(
        ..model,
        card_id: option.Some(id),
        notes: Loading,
        activity: Loading,
        activity_total: 0,
        activity_loading_more: False,
      ),
      effect.batch([fetch_notes(id), fetch_activity(id)]),
    )

    CardReceived(card) -> #(
      Model(..model, card: option.Some(card)),
      effect.none(),
    )

    CardsReceived(cards) -> #(Model(..model, cards: cards), effect.none())

    LocaleReceived(loc) -> #(Model(..model, locale: loc), effect.none())

    CurrentUserIdReceived(id) -> #(
      Model(..model, current_user_id: option.Some(id)),
      effect.none(),
    )

    ProjectIdReceived(id) -> #(
      Model(..model, project_id: option.Some(id)),
      effect.none(),
    )

    CanManageNotesReceived(can_manage) -> #(
      Model(..model, can_manage_notes: can_manage),
      effect.none(),
    )

    CanManageStructureReceived(can_manage) -> #(
      Model(..model, can_manage_structure: can_manage),
      effect.none(),
    )

    CanExecuteWorkReceived(can_execute) -> #(
      Model(..model, can_execute_work: can_execute),
      effect.none(),
    )

    NotesReceived(Ok(notes)) -> #(
      Model(..model, notes: Loaded(notes), note_error: option.None),
      effect.none(),
    )

    NotesReceived(Error(err)) -> #(
      Model(..model, notes: Failed(err), note_error: option.Some(err.message)),
      effect.none(),
    )

    ActivityReceived(Ok(page)) -> {
      let api_activity.ActivityPage(activity: events, pagination: pagination) =
        page
      let next_events = case model.activity_loading_more, model.activity {
        True, Loaded(current) -> list.append(current, events)
        _, _ -> events
      }
      #(
        Model(
          ..model,
          activity: Loaded(next_events),
          activity_total: pagination.total,
          activity_loading_more: False,
        ),
        effect.none(),
      )
    }

    ActivityReceived(Error(err)) -> #(
      card_activity_failed(model, err),
      effect.none(),
    )

    TasksReceived(tasks) -> #(
      Model(..model, tasks: Loaded(tasks)),
      effect.none(),
    )

    // AC21: Tab navigation
    TabClicked(tab) -> #(Model(..model, active_tab: tab), effect.none())

    ActivityMoreClicked -> load_more_activity(model)

    // Note dialog
    NoteDialogOpened -> #(
      Model(..model, note_dialog_open: True, note_error: option.None),
      effect.none(),
    )

    NoteDialogClosed -> #(
      Model(
        ..model,
        note_dialog_open: False,
        note_content: "",
        note_error: option.None,
      ),
      effect.none(),
    )

    NoteContentChanged(content) -> #(
      Model(..model, note_content: content, note_error: option.None),
      effect.none(),
    )

    NoteSubmitted -> handle_submit_note(model)

    NoteCreated(Ok(note)) -> #(
      Model(
        ..model,
        note_dialog_open: False,
        note_in_flight: False,
        note_content: "",
        note_error: option.None,
        notes: Loaded(show_notes.append(model.notes, note)),
      ),
      effect.none(),
    )

    NoteCreated(Error(err)) -> #(
      Model(
        ..model,
        note_in_flight: False,
        note_error: option.Some(err.message),
      ),
      effect.none(),
    )

    NoteDeleteClicked(note_id) -> handle_delete_note(model, note_id)

    NoteDeleted(note_id, Ok(_)) -> #(
      Model(
        ..model,
        note_error: option.None,
        notes: Loaded(show_notes.remove(model.notes, note_id)),
      ),
      effect.none(),
    )

    NoteDeleted(_note_id, Error(err)) -> #(
      Model(..model, note_error: option.Some(err.message)),
      effect.none(),
    )

    NotePinClicked(note_id, pinned) -> handle_pin_note(model, note_id, pinned)

    NotePinned(_note_id, Ok(note)) -> #(
      Model(
        ..model,
        note_pin_in_flight: option.None,
        note_error: option.None,
        notes: Loaded(show_notes.replace(model.notes, note)),
      ),
      effect.none(),
    )

    NotePinned(_note_id, Error(err)) -> #(
      Model(
        ..model,
        note_pin_in_flight: option.None,
        note_error: option.Some(err.message),
      ),
      effect.none(),
    )

    CreateCardClicked -> #(model, effect.none())

    ActivateCardClicked -> #(
      Model(..model, activation_confirm_open: True),
      effect.none(),
    )

    ActivateCardCancelled -> #(
      Model(..model, activation_confirm_open: False),
      effect.none(),
    )

    ActivateCardConfirmed -> #(
      Model(..model, activation_confirm_open: False),
      effect.none(),
    )

    MoveRequested -> #(model, effect.none())

    DeleteCardClicked -> #(model, effect.none())

    // Actions that emit events to parent
    CreateTaskClicked -> #(model, effect.none())

    CloseClicked -> #(model, effect.none())
  }
}

fn fetch_notes(card_id: Int) -> Effect(Msg) {
  api_cards.get_card_notes(card_id, NotesReceived)
}

fn fetch_activity(card_id: Int) -> Effect(Msg) {
  api_activity.list_card_activity(card_id, ActivityReceived)
}

fn load_more_activity(model: Model) -> #(Model, Effect(Msg)) {
  case model.activity_loading_more, model.card_id, model.activity {
    False, option.Some(card_id), Loaded(events) -> {
      let offset = list.length(events)
      #(
        Model(..model, activity_loading_more: True),
        api_activity.list_card_activity_page(
          card_id,
          30,
          offset,
          ActivityReceived,
        ),
      )
    }
    _, _, _ -> #(model, effect.none())
  }
}

fn card_activity_failed(model: Model, err: ApiError) -> Model {
  case model.activity_loading_more {
    True -> Model(..model, activity_loading_more: False)
    False -> Model(..model, activity: Failed(err), activity_loading_more: False)
  }
}

fn handle_submit_note(model: Model) -> #(Model, Effect(Msg)) {
  case model.note_in_flight {
    True -> #(model, effect.none())
    False -> validate_and_submit_note(model)
  }
}

fn validate_and_submit_note(model: Model) -> #(Model, Effect(Msg)) {
  let content = string.trim(model.note_content)

  case content == "" {
    True -> #(
      Model(
        ..model,
        note_error: option.Some(t(model.locale, i18n_text.ContentRequired)),
      ),
      effect.none(),
    )
    False -> submit_note(model, content)
  }
}

fn submit_note(model: Model, content: String) -> #(Model, Effect(Msg)) {
  case model.card_id {
    option.None -> #(model, effect.none())
    option.Some(card_id) -> #(
      Model(..model, note_in_flight: True, note_error: option.None),
      api_cards.create_card_note(card_id, content, NoteCreated),
    )
  }
}

fn handle_delete_note(model: Model, note_id: Int) -> #(Model, Effect(Msg)) {
  case model.card_id {
    option.None -> #(model, effect.none())
    option.Some(card_id) -> #(
      model,
      api_cards.delete_card_note(card_id, note_id, fn(result) {
        NoteDeleted(note_id, result)
      }),
    )
  }
}

fn handle_pin_note(
  model: Model,
  note_id: Int,
  pinned: Bool,
) -> #(Model, Effect(Msg)) {
  case model.note_pin_in_flight, model.card_id {
    option.Some(_), _ -> #(model, effect.none())
    _, option.None -> #(model, effect.none())
    option.None, option.Some(card_id) -> #(
      Model(
        ..model,
        note_pin_in_flight: option.Some(note_id),
        note_error: option.None,
      ),
      api_cards.set_card_note_pinned(card_id, note_id, pinned, fn(result) {
        NotePinned(note_id, result)
      }),
    )
  }
}

// =============================================================================
// View
// =============================================================================

pub fn view(model: Model) -> Element(Msg) {
  case model.card {
    option.None -> element.none()
    option.Some(card) -> view_modal(model, card)
  }
}

fn view_modal(model: Model, card: Card) -> Element(Msg) {
  let border_class = task_color.card_border_class(card.color)

  // AC21: Calculate notes count for tab display
  let notes_count = case model.notes {
    Loaded(notes_list) -> list.length(notes_list)
    _ -> 0
  }
  let tabs = card_tab_items(model, notes_count, card.has_new_notes)

  inspector_shell.view(
    inspector_shell.Config(
      root_class: "card-show",
      panel_class: "card-show-panel card-show-surface " <> border_class,
      title_id: "card-show-title",
      on_close: CloseClicked,
      testid: "card-show",
    ),
    [
      div(
        [
          attribute.class("card-show-header-block detail-header-block"),
        ],
        [
          view_card_header(model, card),
          detail_tabs.view(detail_tabs.Config(
            active_tab: model.active_tab,
            tabs: tabs,
            container_class: "card-show-tabs detail-tabs",
            tab_class: "card-tab card-show-tab detail-tab",
            on_tab_click: TabClicked,
          )),
        ],
      ),
      div([attribute.class("card-show-body")], [
        detail_tabs.panel(model.active_tab, tabs, case model.active_tab {
          show_tabs.CardWorkTab -> view_card_tasks_section(model, card)
          show_tabs.CardSummaryTab -> view_card_summary_section(model, card)
          show_tabs.CardNotesTab -> view_card_notes_section(model)
          show_tabs.CardActivityTab -> view_card_activity_section(model)
        }),
      ]),
      case model.note_dialog_open {
        True -> view_note_dialog(model)
        False -> element.none()
      },
      case model.activation_confirm_open {
        True -> view_activation_confirm_dialog(model, card)
        False -> element.none()
      },
    ],
  )
}

fn view_activation_confirm_dialog(model: Model, card: Card) -> Element(Msg) {
  div([attribute.class("card-activation-dialog-shell")], [
    div(
      [
        attribute.class("modal-backdrop"),
        event.on_click(ActivateCardCancelled),
      ],
      [],
    ),
    div(
      [
        attribute.class("card-move-dialog"),
        attribute.attribute("role", "dialog"),
        attribute.attribute("aria-modal", "true"),
        attribute.attribute("aria-labelledby", "card-activation-dialog-title"),
        attribute.attribute("data-testid", "card-activation-dialog"),
      ],
      [
        div([attribute.class("card-move-dialog-header")], [
          span(
            [
              attribute.class("card-move-dialog-title"),
              attribute.id("card-activation-dialog-title"),
            ],
            [text(t(model.locale, i18n_text.HierarchyActivationTitle))],
          ),
          ui_button.icon(
            t(model.locale, i18n_text.Close),
            ActivateCardCancelled,
            icons.Close,
            ui_button.Ghost,
            ui_button.EntityAction,
          )
            |> ui_button.with_testid("card-activation-close")
            |> ui_button.view,
        ]),
        div([attribute.class("card-move-dialog-help")], [
          text(t(
            model.locale,
            i18n_text.HierarchyActivationBody(
              show_hierarchy.affected_card_count(card, model.cards),
              card.task_count,
            ),
          )),
        ]),
        div([attribute.class("card-move-dialog-help")], [
          text(t(model.locale, i18n_text.HierarchyActivationWarning)),
        ]),
        div([attribute.class("dialog-actions")], [
          ui_button.text(
            t(model.locale, i18n_text.Cancel),
            ActivateCardCancelled,
            ui_button.Secondary,
            ui_button.EntityAction,
          )
            |> ui_button.with_testid("card-activation-cancel")
            |> ui_button.view,
          ui_button.icon_text(
            t(model.locale, i18n_text.ActivateHierarchy),
            ActivateCardConfirmed,
            icons.Play,
            ui_button.Primary,
            ui_button.EntityAction,
          )
            |> ui_button.with_testid("card-activation-confirm")
            |> ui_button.view,
        ]),
      ],
    ),
  ])
}

fn view_card_header(model: Model, card: Card) -> Element(Msg) {
  let state_label = card_state.label(model.locale, card.state)
  let meta =
    div([attribute.class("detail-meta")], [
      div([attribute.class("detail-meta-group")], [
        card_state_badge.view(card.state, state_label, card_state_badge.Detail),
        due_date_chip(model, card),
      ]),
      div(
        [attribute.class("detail-meta-group")],
        card_header_metrics(model, card),
      ),
    ])

  inspector_header.view(inspector_header.Config(
    title: card.title,
    title_id: "card-show-title",
    state_line: option.Some(card_state_line(model, card)),
    context: option.Some(view_card_path(model, card)),
    meta: option.Some(meta),
    primary_action: option.Some(view_quick_create_action(
      model,
      card,
      action_policy(model, card),
    )),
    open_in: option.Some(view_open_in_menu(model, card)),
    secondary_actions: option.Some(view_secondary_action_menu(
      model,
      card,
      action_policy(model, card),
    )),
    close_label: t(model.locale, i18n_text.Close),
    on_close: CloseClicked,
    extra_class: "card-inspector-header",
  ))
}

fn card_header_metrics(model: Model, card: Card) -> List(Element(Msg)) {
  case card.task_count {
    0 -> []
    _ -> [
      card_task_metric(
        model.locale,
        task_metric.Total,
        card.task_count,
        "card-task-metric-total",
      ),
      card_task_metric(
        model.locale,
        task_metric.Closed,
        card.closed_count,
        "card-task-metric-closed",
      ),
      card_task_metric(
        model.locale,
        task_metric.Blocked,
        blocked_count(model),
        "card-task-metric-blocked",
      ),
    ]
  }
}

fn card_state_line(model: Model, card: Card) -> String {
  card_state.label(model.locale, card.state)
  <> " - "
  <> due_date_text(model, card)
  <> " - "
  <> card_work_progress_copy(model, card)
}

fn view_card_path(model: Model, card: Card) -> Element(Msg) {
  div(
    [
      attribute.class("card-header-path"),
      attribute.attribute("data-testid", "card-header-path"),
    ],
    show_hierarchy.path_labels(model.cards, card)
      |> list.index_map(fn(label, idx) {
        span([attribute.class(path_part_class(idx))], [
          text(path_part_text(label, idx)),
        ])
      }),
  )
}

fn path_part_class(index: Int) -> String {
  case index {
    0 -> "card-header-path-part"
    _ -> "card-header-path-part nested"
  }
}

fn path_part_text(label: String, index: Int) -> String {
  case index {
    0 -> label
    _ -> " > " <> label
  }
}

fn due_date_chip(model: Model, card: Card) -> Element(Msg) {
  case card.due_date {
    option.Some(date) ->
      span(
        [
          attribute.class("card-meta-chip card-meta-due"),
          attribute.attribute("data-testid", "card-header-due"),
        ],
        [
          icons.nav_icon(icons.Calendar, icons.Small),
          text(t(model.locale, i18n_text.TaskDueDateLabel) <> " " <> date),
        ],
      )
    option.None ->
      span(
        [
          attribute.class("card-meta-chip card-meta-due muted"),
          attribute.attribute("data-testid", "card-header-due"),
        ],
        [text(t(model.locale, i18n_text.NoDueDate))],
      )
  }
}

fn due_date_text(model: Model, card: Card) -> String {
  case card.due_date {
    option.Some(date) ->
      t(model.locale, i18n_text.TaskDueDateLabel) <> " " <> date
    option.None -> t(model.locale, i18n_text.NoDueDate)
  }
}

fn card_task_metric(
  locale: Locale,
  kind: task_metric.TaskMetricKind,
  value: Int,
  testid: String,
) -> Element(Msg) {
  task_metric_chip.view(task_metric_chip.Config(
    locale: locale,
    metric: task_metric.metric(kind, value),
    variant: task_metric_chip.Compact,
    extra_class: option.Some("card-task-metric"),
    testid: option.Some(testid),
  ))
}

fn blocked_count(model: Model) -> Int {
  case model.tasks {
    Loaded(tasks) ->
      tasks
      |> list.filter(fn(task) { task.blocked_count > 0 })
      |> list.length
    _ -> 0
  }
}

fn view_open_in_menu(model: Model, card: Card) -> Element(Msg) {
  action_menu.view(
    t(model.locale, i18n_text.OpenIn),
    "card-open-in-trigger",
    "card-open-in-" <> int.to_string(card.id),
    option.Some(t(model.locale, i18n_text.OpenIn)),
    "card-open-in-menu",
    "card-open-in-trigger",
    "card-open-in-panel",
    "card-open-in-item",
    [
      action_menu.link_item(
        t(model.locale, i18n_text.ViewInPlan),
        "card-scope-plan",
        scoped_navigation.plan_url(card),
      ),
      action_menu.link_item(
        t(model.locale, i18n_text.ViewInKanban),
        "card-scope-kanban",
        scoped_navigation.kanban_url(card),
      ),
      action_menu.link_item(
        t(model.locale, i18n_text.ViewInCapabilities),
        "card-scope-capabilities",
        scoped_navigation.capabilities_url(card),
      ),
      action_menu.link_item(
        t(model.locale, i18n_text.ViewInPeople),
        "card-scope-people",
        scoped_navigation.people_url(card),
      ),
    ],
  )
}

fn view_quick_create_action(
  model: Model,
  card: Card,
  policy: card_policy.Policy,
) -> Element(Msg) {
  case card.state {
    Draft -> view_activate_card_action(model)
    _ ->
      case policy.structure {
        card_policy.CardGroup -> view_create_card_action(model, policy)
        card_policy.TaskGroup -> view_create_task_action(model, policy)
        card_policy.EmptyCard -> element.none()
      }
  }
}

fn view_activate_card_action(model: Model) -> Element(Msg) {
  case model.can_manage_structure {
    True ->
      ui_button.icon_text(
        t(model.locale, i18n_text.ActivateHierarchy),
        ActivateCardClicked,
        icons.Play,
        ui_button.Primary,
        ui_button.EntityAction,
      )
      |> ui_button.with_testid("card-primary-activate-action")
      |> ui_button.view
    False ->
      blocked_action(
        t(model.locale, i18n_text.ActivateHierarchy),
        ActivateCardClicked,
        icons.Play,
        "card-primary-activate-action",
        t(model.locale, i18n_text.ActivateHierarchyManagerOnly),
      )
  }
}

fn view_create_card_action(
  model: Model,
  policy: card_policy.Policy,
) -> Element(Msg) {
  case policy.can_create_card, policy.create_disabled_reason {
    True, _ ->
      ui_button.icon_text(
        t(model.locale, i18n_text.CardAddSubcard),
        CreateCardClicked,
        icons.Plus,
        ui_button.Secondary,
        ui_button.EntityAction,
      )
      |> ui_button.with_testid("card-create-card-action")
      |> ui_button.view
    False, option.Some(reason) ->
      blocked_action(
        t(model.locale, i18n_text.CardAddSubcard),
        CreateCardClicked,
        icons.Plus,
        "card-create-card-action",
        disabled_reason_label(model, reason),
      )
    False, option.None -> element.none()
  }
}

fn view_create_task_action(
  model: Model,
  policy: card_policy.Policy,
) -> Element(Msg) {
  case policy.can_create_task, policy.create_disabled_reason {
    True, _ ->
      ui_button.icon_text(
        t(model.locale, i18n_text.CardAddTask),
        CreateTaskClicked,
        icons.Plus,
        ui_button.Primary,
        ui_button.EntityAction,
      )
      |> ui_button.with_testid("card-create-task-action")
      |> ui_button.view
    False, option.Some(reason) ->
      blocked_action(
        t(model.locale, i18n_text.CardAddTask),
        CreateTaskClicked,
        icons.Plus,
        "card-create-task-action",
        disabled_reason_label(model, reason),
      )
    False, option.None -> element.none()
  }
}

fn view_secondary_action_menu(
  model: Model,
  card: Card,
  policy: card_policy.Policy,
) -> Element(Msg) {
  action_menu.view(
    "⋯",
    "card-secondary-actions-trigger",
    "card-secondary-actions-" <> int.to_string(card.id),
    option.Some(t(model.locale, i18n_text.HierarchyMoreActions)),
    "card-secondary-actions-menu",
    "card-secondary-actions-trigger",
    "card-secondary-actions-panel",
    "card-secondary-actions-item",
    list.flatten([
      activate_action_items(model, card),
      move_action_items(model, card),
      delete_action_items(model, policy),
    ]),
  )
}

fn activate_action_items(
  model: Model,
  card: Card,
) -> List(action_menu.Item(Msg)) {
  case card.state, model.can_manage_structure {
    Draft, _ -> []
    _, _ -> []
  }
}

fn move_action_items(model: Model, card: Card) -> List(action_menu.Item(Msg)) {
  case card.state == Closed {
    True -> []
    False -> [
      action_menu.item(
        t(model.locale, i18n_text.HierarchyMoveTo),
        "card-secondary-move-action",
        MoveRequested,
      ),
    ]
  }
}

fn delete_action_items(
  model: Model,
  policy: card_policy.Policy,
) -> List(action_menu.Item(Msg)) {
  case policy.can_delete, policy.delete_disabled_reason {
    True, _ -> [
      action_menu.item(
        t(model.locale, i18n_text.DeleteCard),
        "card-secondary-delete-action",
        DeleteCardClicked,
      ),
    ]
    False, option.Some(reason) -> [
      action_menu.disabled_item(
        t(model.locale, i18n_text.DeleteCard),
        "card-secondary-delete-action",
        disabled_reason_label(model, reason),
        DeleteCardClicked,
      ),
    ]
    False, option.None -> []
  }
}

fn disabled_reason_label(
  model: Model,
  reason: card_policy.DisabledReason,
) -> String {
  case reason {
    card_policy.ClosedCardCannotReceiveChildren ->
      t(model.locale, i18n_text.CardClosedCannotReceiveChildren)
    card_policy.CardHasOperationalHistory ->
      t(model.locale, i18n_text.CardHasOperationalHistory)
  }
}

fn blocked_action(
  label: String,
  msg: Msg,
  icon: icons.NavIcon,
  testid: String,
  reason: String,
) -> Element(Msg) {
  ui_button.icon_text(
    label,
    msg,
    icon,
    ui_button.Secondary,
    ui_button.EntityAction,
  )
  |> ui_button.with_blocked_reason(reason)
  |> ui_button.with_testid(testid)
  |> ui_button.with_class("card-show-action-blocked")
  |> ui_button.view
}

fn card_tab_items(
  model: Model,
  notes_count: Int,
  has_new_notes: Bool,
) -> List(detail_tabs.TabItem(show_tabs.CardShowTab)) {
  show_tabs.card_items(
    show_tabs.CardLabels(
      summary: t(model.locale, i18n_text.TabSummary),
      work: t(model.locale, i18n_text.TabWork),
      notes: t(model.locale, i18n_text.TabNotes),
      activity: t(model.locale, i18n_text.TabActivity),
    ),
    card_work_count(model),
    notes_count,
    has_new_notes,
  )
}

fn card_work_count(model: Model) -> Int {
  case model.tasks {
    Loaded(tasks) -> list.length(tasks)
    _ -> 0
  }
}

fn view_card_summary_section(model: Model, card: Card) -> Element(Msg) {
  div([attribute.class("card-summary-section detail-section")], [
    div([attribute.class("card-summary-block")], [
      span([attribute.class("detail-section-kicker")], [
        text(t(model.locale, i18n_text.MetricsProgress)),
      ]),
      div([attribute.class("card-summary-progress-line")], [
        text(card_work_breakdown_text(model, card)),
      ]),
      div([attribute.class("card-summary-progress-bar")], [
        div(
          [
            attribute.class("card-summary-progress-fill"),
            attribute.style(
              "width",
              int.to_string(card_progress_percent(card)) <> "%",
            ),
          ],
          [],
        ),
      ]),
    ]),
    case card.description {
      "" -> element.none()
      description ->
        div([attribute.class("card-summary-block card-summary-description")], [
          span([attribute.class("detail-section-kicker")], [
            text(t(model.locale, i18n_text.Description)),
          ]),
          div([attribute.class("card-summary-description-text")], [
            text(description),
          ]),
        ])
    },
    div([attribute.class("card-summary-block")], [
      span([attribute.class("detail-section-kicker")], [
        text(t(model.locale, i18n_text.PlanModeStructure)),
      ]),
      view_card_path(model, card),
      summary_item(
        t(model.locale, i18n_text.CardTasks),
        card_work_progress_copy(model, card),
      ),
    ]),
    pinned_context.view(pinned_context.Config(
      title: t(model.locale, i18n_text.PinnedContext),
      notes: card_pinned_notes(model),
      open_notes_label: t(model.locale, i18n_text.OpenNotes),
      more_label: fn(count) {
        t(model.locale, i18n_text.MorePinnedNotes(count))
      },
      on_open_notes: TabClicked(show_tabs.CardNotesTab),
    )),
  ])
}

fn view_empty_card_work_decision(
  model: Model,
  policy: card_policy.Policy,
) -> Element(Msg) {
  case policy.structure {
    card_policy.EmptyCard ->
      empty_state.no_tasks(
        t(model.locale, i18n_text.CardEmptyWorkTitle),
        t(model.locale, i18n_text.CardEmptyWorkBody),
      )
      |> empty_state.with_action(
        t(model.locale, i18n_text.CardAddTask),
        CreateTaskClicked,
      )
      |> empty_state.with_secondary_action(
        t(model.locale, i18n_text.CardAddSubcard),
        CreateCardClicked,
      )
      |> empty_state.with_class("card-empty-work-decision")
      |> empty_state.view
    _ -> element.none()
  }
}

fn card_pinned_notes(model: Model) -> List(pinned_context.PinnedNote) {
  case model.notes {
    Loaded(notes) ->
      notes
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

fn summary_item(label: String, value: String) -> Element(Msg) {
  div([attribute.class("detail-summary-item")], [
    span([attribute.class("detail-summary-label")], [text(label)]),
    span([attribute.class("detail-summary-value")], [text(value)]),
  ])
}

fn card_progress_percent(card: Card) -> Int {
  case card.task_count <= 0 {
    True -> 0
    False -> card.closed_count * 100 / card.task_count
  }
}

fn card_work_breakdown_text(model: Model, card: Card) -> String {
  card_work_progress_copy(model, card)
  <> " - "
  <> int.to_string(blocked_count(model))
  <> " "
  <> t(model.locale, i18n_text.PoolVisibilityBlocked)
}

fn card_work_progress_copy(model: Model, card: Card) -> String {
  case card.task_count {
    0 -> t(model.locale, i18n_text.CardTasksEmpty)
    total ->
      int.to_string(card.closed_count)
      <> " "
      <> t(model.locale, i18n_text.CardTasksClosed)
      <> " - "
      <> int.to_string(total)
      <> " "
      <> t(model.locale, i18n_text.CardTasks)
  }
}

fn view_card_activity_section(model: Model) -> Element(Msg) {
  div([attribute.class("card-activity-panel")], [
    activity_feed.view(activity_feed.Config(
      events: model.activity,
      loading_label: t(model.locale, i18n_text.ActivityLoading),
      empty_label: t(model.locale, i18n_text.ActivityEmpty),
      error_label: t(model.locale, i18n_text.ActivityLoadFailed),
      load_more: card_activity_load_more(model),
    )),
  ])
}

fn card_activity_load_more(model: Model) -> Option(activity_feed.LoadMore(Msg)) {
  case model.activity {
    Loaded(events) -> {
      let loaded_count = list.length(events)
      case loaded_count < model.activity_total {
        True ->
          option.Some(activity_feed.LoadMore(
            label: t(
              model.locale,
              i18n_text.ActivityLoadMore(model.activity_total - loaded_count),
            ),
            in_flight: model.activity_loading_more,
            on_click: ActivityMoreClicked,
          ))
        False -> option.None
      }
    }
    _ -> option.None
  }
}

fn view_card_notes_section(model: Model) -> Element(Msg) {
  let notes = case model.notes {
    Loaded(list) -> list
    _ -> []
  }
  let count_label =
    t(model.locale, i18n_text.Notes)
    <> " ("
    <> int.to_string(list.length(notes))
    <> ")"

  div([attribute.class("card-show-notes-section detail-section")], [
    // Shared section header component (consistent with Tasks tab)
    // Button opens dialog instead of submitting directly
    card_section_header.view(card_section_header.Config(
      title: count_label,
      button_label: "+ " <> t(model.locale, i18n_text.AddNote),
      button_disabled: False,
      on_button_click: NoteDialogOpened,
    )),
    case model.notes {
      Loading ->
        div([attribute.class("card-notes-loading")], [
          text(t(model.locale, i18n_text.LoadingEllipsis)),
        ])
      Failed(err) ->
        div([attribute.class("card-notes-error")], [text(err.message)])
      _ ->
        notes_list.view(
          // Reverse to show newest first (descending chronological order)
          list.map(list.reverse(notes), fn(note) { note_to_view(model, note) }),
          t(model.locale, i18n_text.Delete),
          t(model.locale, i18n_text.DeleteAsAdmin),
          t(model.locale, i18n_text.PinNote),
          t(model.locale, i18n_text.UnpinNote),
          NoteDeleteClicked,
          NotePinClicked,
        )
    },
  ])
}

/// Note creation dialog - uses shared note_dialog component (Story 5.4.2).
fn view_note_dialog(model: Model) -> Element(Msg) {
  note_dialog.view(note_dialog.Config(
    title: t(model.locale, i18n_text.AddNote),
    content: model.note_content,
    placeholder: t(model.locale, i18n_text.NotePlaceholder),
    error: model.note_error,
    submit_label: t(model.locale, i18n_text.AddNote),
    submit_disabled: model.note_in_flight || model.note_content == "",
    cancel_label: t(model.locale, i18n_text.Cancel),
    close_label: t(model.locale, i18n_text.Close),
    on_content_change: NoteContentChanged,
    on_submit: NoteSubmitted,
    on_close: NoteDialogClosed,
  ))
}

fn note_to_view(model: Model, note: Note) -> notes_list.NoteView {
  let id = note_ids.to_int(note.id)
  let user_id = user_ids.to_int(note.user_id)
  let is_own_note = note_belongs_to_current_user(model.current_user_id, user_id)
  let author_label = case is_own_note {
    True -> t(model.locale, i18n_text.You)
    False -> t(model.locale, i18n_text.UserNumber(user_id))
  }
  let can_delete = model.can_manage_notes || is_own_note
  let delete_context = case is_own_note {
    True -> notes_list_types.DeleteOwnNote
    False -> notes_list_types.DeleteAsAdmin
  }

  notes_list.NoteView(
    id: id,
    author: author_label,
    created_at: note.created_at,
    content: note.content,
    url: note.url,
    pinned: note.pinned,
    can_pin: can_delete,
    pin_in_flight: model.note_pin_in_flight == option.Some(id),
    pin_disabled_reason: case can_delete {
      True -> option.None
      False -> option.Some(t(model.locale, i18n_text.CannotPinNote))
    },
    can_delete: can_delete,
    delete_context: delete_context,
    author_email: note.author_email,
    author_project_role: note.author_project_role,
    author_org_role: note.author_org_role,
  )
}

fn note_belongs_to_current_user(
  current_user_id: Option(Int),
  note_user_id: Int,
) -> Bool {
  case current_user_id {
    option.Some(user_id) -> user_id == note_user_id
    option.None -> False
  }
}

fn view_card_tasks_section(model: Model, card: Card) -> Element(Msg) {
  let tasks = case model.tasks {
    Loaded(task_list) -> task_list
    _ -> []
  }
  let policy = action_policy(model, card)

  div([attribute.class("card-show-tasks-section detail-section")], [
    view_tasks_header(model, policy),
    case model.tasks {
      Loading ->
        empty_state.notice_with_class(
          "arrow-path",
          t(model.locale, i18n_text.LoadingEllipsis),
          empty_state.Loading,
          "card-work-state",
        )
      Failed(_) ->
        empty_state.notice_with_class(
          "exclamation-triangle",
          t(model.locale, i18n_text.ErrorLoadingTasks),
          empty_state.Error,
          "card-work-state",
        )
      _ ->
        case list.is_empty(tasks) {
          True -> view_empty_card_work_decision(model, policy)
          False -> view_task_list(model, tasks)
        }
    },
  ])
}

fn view_tasks_header(model: Model, policy: card_policy.Policy) -> Element(Msg) {
  case policy.can_create_task, policy.create_disabled_reason {
    True, _ ->
      card_section_header.view(card_section_header.Config(
        title: t(model.locale, i18n_text.CardTasks),
        button_label: "+ " <> t(model.locale, i18n_text.CardAddTask),
        button_disabled: False,
        on_button_click: CreateTaskClicked,
      ))
    False, option.Some(_reason) ->
      card_section_header.view(card_section_header.Config(
        title: t(model.locale, i18n_text.CardTasks),
        button_label: "+ " <> t(model.locale, i18n_text.CardAddTask),
        button_disabled: True,
        on_button_click: CreateTaskClicked,
      ))
    False, option.None ->
      div([attribute.class("card-section-header")], [
        span([attribute.class("card-section-title")], [
          text(t(model.locale, i18n_text.CardTasks)),
        ]),
      ])
  }
}

fn view_task_list(model: Model, tasks: List(Task)) -> Element(Msg) {
  div([attribute.class("card-work-list")], [
    view_task_group(
      model,
      t(model.locale, i18n_text.MetricsAvailable),
      list.filter(tasks, is_available_unblocked),
    ),
    view_task_group(
      model,
      t(model.locale, i18n_text.PoolVisibilityBlocked),
      list.filter(tasks, is_blocked),
    ),
    view_task_group(
      model,
      t(model.locale, i18n_text.MetricsClaimed),
      list.filter(tasks, is_claimed_taken),
    ),
    view_task_group(
      model,
      t(model.locale, i18n_text.MetricsOngoing),
      list.filter(tasks, is_ongoing),
    ),
    view_task_group(
      model,
      t(model.locale, i18n_text.Closed),
      list.filter(tasks, is_closed),
    ),
  ])
}

fn view_task_group(
  model: Model,
  label: String,
  tasks: List(Task),
) -> Element(Msg) {
  div([attribute.class("card-work-group")], [
    div([attribute.class("card-work-group-header")], [
      span([attribute.class("card-work-group-title")], [text(label)]),
      span([attribute.class("card-work-group-count")], [
        text(int.to_string(list.length(tasks))),
      ]),
    ]),
    case tasks {
      [] ->
        div([attribute.class("card-work-group-empty")], [
          text(t(model.locale, i18n_text.CardTasksEmpty)),
        ])
      _ ->
        div(
          [attribute.class("card-work-group-list")],
          list.map(tasks, fn(task) { view_task_item(model.locale, task) }),
        )
    },
  ])
}

fn view_task_item(locale: Locale, task: Task) -> Element(Msg) {
  task_item.view(
    task_item.Config(
      container_class: "card-task-item detail-item-row",
      content_class: "card-task-content",
      leading: option.Some(view_task_status(locale, task)),
      on_click: option.None,
      content_title: option.None,
      content_label: option.None,
      icon: option.None,
      icon_class: option.None,
      title: task.title,
      title_class: option.Some("card-task-title"),
      secondary: view_task_secondary(locale, task),
      actions: task_item.no_actions(),
      reserve_actions_slot: False,
      action_slot_class: option.None,
      content_testid: option.None,
      testid: option.None,
    ),
    task_item.Div,
  )
}

fn view_task_secondary(locale: Locale, task: Task) -> Element(Msg) {
  let status_label =
    task_status_utils.label(locale, task_state.to_status(task.state))
  let owner = case claimed_by(task) {
    option.Some(user_id) ->
      " - " <> t(locale, i18n_text.ClaimedBy) <> " #" <> int.to_string(user_id)
    option.None -> ""
  }

  span([attribute.class("card-work-task-secondary")], [
    text(status_label <> owner),
  ])
}

fn is_available_unblocked(task: Task) -> Bool {
  case task.state, task.blocked_count {
    task_state.Available, 0 -> True
    _, _ -> False
  }
}

fn is_blocked(task: Task) -> Bool {
  task.blocked_count > 0
}

fn is_claimed_taken(task: Task) -> Bool {
  case task.state, task.blocked_count {
    task_state.Claimed(mode: task_state.Taken, ..), 0 -> True
    _, _ -> False
  }
}

fn is_ongoing(task: Task) -> Bool {
  case task.state, task.blocked_count {
    task_state.Claimed(mode: task_state.Ongoing, ..), 0 -> True
    _, _ -> False
  }
}

fn is_closed(task: Task) -> Bool {
  case task.state {
    task_state.Closed(..) -> True
    _ -> False
  }
}

fn view_task_status(locale: Locale, task: Task) -> Element(Msg) {
  task_status_indicator.view(task_status_indicator.Config(
    locale: locale,
    status: task_state.to_status(task.state),
    variant: task_status_indicator.InlineCompact,
    label: option.None,
    title: option.None,
    extra_class: option.Some("card-task-status-indicator"),
    testid: option.None,
  ))
}

fn action_policy(model: Model, card: Card) -> card_policy.Policy {
  let tasks = case model.tasks {
    Loaded(task_list) -> task_list
    _ -> []
  }

  card_policy.policy_for(
    card,
    card_policy.direct_child_cards(card, model.cards),
    tasks,
    model.can_manage_structure,
    model.can_execute_work,
  )
}

// =============================================================================
// Helper Functions
// =============================================================================

/// Internal i18n helper - maps locale + key to translated text.
fn t(loc: Locale, key: i18n_text.Text) -> String {
  case loc {
    En -> i18n_en.translate(key)
    Es -> i18n_es.translate(key)
  }
}
