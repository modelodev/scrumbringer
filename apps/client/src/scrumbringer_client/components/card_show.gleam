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
import lustre/element/html.{a, div, span, text}
import lustre/event

import domain/card.{type Card, Closed, Draft}
import domain/note/entity.{type Note}
import domain/note/id as note_ids
import domain/task.{type Task, claimed_by}
import domain/task_state
import domain/task_status.{Available, Done}
import domain/user/id as user_ids

import domain/activity/entity as activity_entity
import domain/api_error.{type ApiError, type ApiResult}
import domain/remote.{type Remote, Failed, Loaded, Loading, NotAsked}
import scrumbringer_client/api/activity as api_activity
import scrumbringer_client/api/cards as api_cards
import scrumbringer_client/features/cards/detail_policy
import scrumbringer_client/features/cards/scoped_navigation
import scrumbringer_client/i18n/en as i18n_en
import scrumbringer_client/i18n/es as i18n_es
import scrumbringer_client/i18n/locale.{type Locale, En, Es}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/action_menu
import scrumbringer_client/ui/activity_feed
import scrumbringer_client/ui/button as ui_button
import scrumbringer_client/ui/card_progress
import scrumbringer_client/ui/card_section_header
import scrumbringer_client/ui/card_state
import scrumbringer_client/ui/card_state_badge
import scrumbringer_client/ui/detail_tabs
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/modal_header
import scrumbringer_client/ui/note_dialog
import scrumbringer_client/ui/notes_list
import scrumbringer_client/ui/pinned_context
import scrumbringer_client/ui/show_tabs
import scrumbringer_client/ui/task_color
import scrumbringer_client/ui/task_item
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
    active_tab: show_tabs.CardSummaryTab,
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
        notes: Loaded(append_note(model.notes, note)),
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
        notes: Loaded(remove_note(model.notes, note_id)),
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
        notes: Loaded(replace_note(model.notes, note)),
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

fn append_note(notes: Remote(List(Note)), note: Note) -> List(Note) {
  case notes {
    Loaded(existing) -> list.append(existing, [note])
    _ -> [note]
  }
}

fn remove_note(notes: Remote(List(Note)), note_id: Int) -> List(Note) {
  case notes {
    Loaded(existing) ->
      list.filter(existing, fn(note) { note_ids.to_int(note.id) != note_id })
    _ -> []
  }
}

fn replace_note(notes: Remote(List(Note)), updated_note: Note) -> List(Note) {
  case notes {
    Loaded(existing) ->
      list.map(existing, fn(note) {
        case note.id == updated_note.id {
          True -> updated_note
          False -> note
        }
      })
    _ -> [updated_note]
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

  div([attribute.class("card-show")], [
    // Card Show panel
    div(
      [
        attribute.class("card-show-panel card-show-surface " <> border_class),
        attribute.attribute("role", "complementary"),
        attribute.attribute("aria-labelledby", "card-show-title"),
      ],
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
              container_class: "card-tabs card-show-tabs detail-tabs",
              tab_class: "card-tab card-show-tab detail-tab",
              on_tab_click: TabClicked,
            )),
          ],
        ),
        div([attribute.class("card-show-body card-show-body")], [
          detail_tabs.panel(model.active_tab, tabs, case model.active_tab {
            show_tabs.CardSummaryTab -> view_card_summary_section(model, card)
            show_tabs.CardWorkTab -> view_card_tasks_section(model, card)
            show_tabs.CardNotesTab -> view_card_notes_section(model)
            show_tabs.CardActivityTab -> view_card_activity_section(model)
          }),
        ]),
      ],
    ),
    // Note creation dialog (modal within modal)
    case model.note_dialog_open {
      True -> view_note_dialog(model)
      False -> element.none()
    },
    case model.activation_confirm_open {
      True -> view_activation_confirm_dialog(model, card)
      False -> element.none()
    },
  ])
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
              affected_card_count(card, model.cards),
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

fn affected_card_count(card: Card, cards: List(Card)) -> Int {
  1
  + list.length(
    list.filter(cards, fn(candidate) {
      is_descendant_of(candidate, card, cards)
    }),
  )
}

fn is_descendant_of(candidate: Card, ancestor: Card, cards: List(Card)) -> Bool {
  case candidate.parent_card_id {
    option.Some(parent_id) if parent_id == ancestor.id -> True
    option.Some(parent_id) ->
      case find_card_by_id(cards, parent_id) {
        option.Some(parent) -> is_descendant_of(parent, ancestor, cards)
        option.None -> False
      }
    option.None -> False
  }
}

fn find_card_by_id(cards: List(Card), card_id: Int) -> option.Option(Card) {
  case list.find(cards, fn(card) { card.id == card_id }) {
    Ok(card) -> option.Some(card)
    Error(_) -> option.None
  }
}

fn view_card_header(model: Model, card: Card) -> Element(Msg) {
  let state_label = card_state.label(model.locale, card.state)
  let meta =
    div([attribute.class("detail-meta")], [
      div([attribute.class("detail-meta-group")], [
        card_state_badge.view(card.state, state_label, card_state_badge.Detail),
        due_date_chip(model, card),
      ]),
      div([attribute.class("detail-meta-group")], [
        card_health_chip(
          "card-health-total",
          int.to_string(card.task_count),
          t(model.locale, i18n_text.CardTasks),
          "",
        ),
        card_health_chip(
          "card-health-done",
          int.to_string(card.completed_count),
          t(model.locale, i18n_text.CardTasksDone),
          "done",
        ),
        card_health_chip(
          "card-health-blocked",
          int.to_string(blocked_count(model)),
          t(model.locale, i18n_text.PoolBlockedCount),
          "blocked",
        ),
      ]),
      card_progress.view(
        card.completed_count,
        card.task_count,
        card_progress.Default,
      ),
    ])

  div([attribute.class("detail-header")], [
    modal_header.view_extended_with_close_label(
      modal_header.ExtendedConfig(
        title: card.title,
        title_element: modal_header.TitleSpan,
        close_position: modal_header.CloseBeforeTitle,
        icon: option.None,
        badges: [],
        meta: option.Some(meta),
        progress: option.None,
        on_close: CloseClicked,
        header_class: "detail-header",
        title_row_class: "detail-title-row",
        title_class: "detail-title",
        title_id: "card-show-title",
        close_button_class: "modal-close btn-icon",
      ),
      t(model.locale, i18n_text.Close),
    ),
    view_card_path(model, card),
    case card.description {
      "" -> element.none()
      desc -> div([attribute.class("card-show-description")], [text(desc)])
    },
    view_scoped_navigation(model, card),
    view_card_action_bar(model, card),
  ])
}

fn view_card_path(model: Model, card: Card) -> Element(Msg) {
  div(
    [
      attribute.class("card-header-path"),
      attribute.attribute("data-testid", "card-header-path"),
    ],
    path_labels(model.cards, card)
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

fn path_labels(cards: List(Card), card: Card) -> List(String) {
  card_path(cards, card)
  |> list.map(fn(path_card) { path_card.title })
}

fn card_path(cards: List(Card), card: Card) -> List(Card) {
  collect_path(cards, card, [])
}

fn collect_path(
  cards: List(Card),
  card: Card,
  collected: List(Card),
) -> List(Card) {
  let next = [card, ..collected]

  case card.parent_card_id {
    option.Some(parent_id) ->
      case find_card_by_id(cards, parent_id) {
        option.Some(parent) -> collect_path(cards, parent, next)
        option.None -> next
      }
    option.None -> next
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

fn card_health_chip(
  testid: String,
  value: String,
  label: String,
  tone: String,
) -> Element(Msg) {
  span(
    [
      attribute.class("card-health-chip " <> tone),
      attribute.attribute("data-testid", testid),
    ],
    [
      span([attribute.class("card-health-value")], [text(value)]),
      span([attribute.class("card-health-label")], [text(label)]),
    ],
  )
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

fn view_scoped_navigation(model: Model, card: Card) -> Element(Msg) {
  div([attribute.class("card-scoped-navigation")], [
    span([attribute.class("card-scoped-navigation-label")], [
      text(t(model.locale, i18n_text.OpenIn)),
    ]),
    scoped_navigation_link(
      t(model.locale, i18n_text.ViewInPlan),
      scoped_navigation.plan_url(card),
      "card-scope-plan",
    ),
    scoped_navigation_link(
      t(model.locale, i18n_text.ViewInKanban),
      scoped_navigation.kanban_url(card),
      "card-scope-kanban",
    ),
    scoped_navigation_link(
      t(model.locale, i18n_text.ViewInCapabilities),
      scoped_navigation.capabilities_url(card),
      "card-scope-capabilities",
    ),
    scoped_navigation_link(
      t(model.locale, i18n_text.ViewInPeople),
      scoped_navigation.people_url(card),
      "card-scope-people",
    ),
  ])
}

fn scoped_navigation_link(
  label: String,
  href: String,
  testid: String,
) -> Element(Msg) {
  a(
    [
      attribute.href(href),
      attribute.class("card-scoped-navigation-link"),
      attribute.attribute("data-testid", testid),
    ],
    [text(label)],
  )
}

fn view_card_action_bar(model: Model, card: Card) -> Element(Msg) {
  let policy = action_policy(model, card)

  div([attribute.class("card-show-actions")], [
    view_create_card_action(model, policy),
    view_create_task_action(model, policy),
    view_secondary_action_menu(model, card, policy),
  ])
}

fn view_create_card_action(
  model: Model,
  policy: detail_policy.Policy,
) -> Element(Msg) {
  case policy.can_create_card, policy.create_disabled_reason {
    True, _ ->
      ui_button.icon_text(
        t(model.locale, i18n_text.NewCard),
        CreateCardClicked,
        icons.Plus,
        ui_button.Secondary,
        ui_button.EntityAction,
      )
      |> ui_button.with_testid("card-create-card-action")
      |> ui_button.view
    False, option.Some(reason) ->
      blocked_action(
        t(model.locale, i18n_text.NewCard),
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
  policy: detail_policy.Policy,
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
  policy: detail_policy.Policy,
) -> Element(Msg) {
  action_menu.view(
    "...",
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
    Draft, True -> [
      action_menu.item(
        t(model.locale, i18n_text.ActivateHierarchy),
        "card-secondary-activate-action",
        ActivateCardClicked,
      ),
    ]
    Draft, False -> [
      action_menu.disabled_item(
        t(model.locale, i18n_text.ActivateHierarchy),
        "card-secondary-activate-action",
        t(model.locale, i18n_text.ActivateHierarchyManagerOnly),
        ActivateCardClicked,
      ),
    ]
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
  policy: detail_policy.Policy,
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
  reason: detail_policy.DisabledReason,
) -> String {
  case reason {
    detail_policy.ClosedCardCannotReceiveChildren ->
      t(model.locale, i18n_text.CardClosedCannotReceiveChildren)
    detail_policy.CardHasOperationalHistory ->
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
    notes_count,
    has_new_notes,
  )
}

fn view_card_summary_section(model: Model, card: Card) -> Element(Msg) {
  div([attribute.class("card-summary-section detail-section")], [
    div([attribute.class("detail-summary-grid")], [
      summary_item(
        t(model.locale, i18n_text.CardTasks),
        int.to_string(card.task_count),
      ),
      summary_item(
        t(model.locale, i18n_text.MetricsTasksDone),
        int.to_string(card.completed_count),
      ),
      summary_item(
        t(model.locale, i18n_text.MetricsProgress),
        progress_text(card),
      ),
    ]),
    case card.description {
      "" -> element.none()
      description ->
        div([attribute.class("card-summary-description")], [text(description)])
    },
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

fn progress_text(card: Card) -> String {
  case card.task_count <= 0 {
    True -> "0%"
    False -> int.to_string(card.completed_count * 100 / card.task_count) <> "%"
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
    // Task list content
    case model.tasks {
      Loading ->
        div([attribute.class("card-tasks-loading")], [
          text(t(model.locale, i18n_text.LoadingEllipsis)),
        ])
      Failed(_) ->
        div([attribute.class("card-tasks-error")], [
          text(t(model.locale, i18n_text.ErrorLoadingTasks)),
        ])
      _ ->
        case list.is_empty(tasks) {
          True -> view_empty_tasks(model)
          False -> view_task_list(tasks)
        }
    },
  ])
}

fn view_tasks_header(model: Model, policy: detail_policy.Policy) -> Element(Msg) {
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

fn view_empty_tasks(model: Model) -> Element(Msg) {
  div([attribute.class("card-tasks-empty")], [
    span([attribute.class("card-tasks-empty-text")], [
      text(t(model.locale, i18n_text.CardTasksEmpty)),
    ]),
  ])
}

fn view_task_list(tasks: List(Task)) -> Element(Msg) {
  div([attribute.class("card-task-list")], list.map(tasks, view_task_item))
}

fn view_task_item(task: Task) -> Element(Msg) {
  task_item.view(
    task_item.Config(
      container_class: "card-task-item detail-item-row",
      content_class: "card-task-content",
      leading: option.Some(view_task_status(task)),
      on_click: option.None,
      content_title: option.None,
      content_label: option.None,
      icon: option.None,
      icon_class: option.None,
      title: task.title,
      title_class: option.Some("card-task-title"),
      secondary: view_task_claim_status(task),
      actions: task_item.no_actions(),
      reserve_actions_slot: False,
      action_slot_class: option.None,
      testid: option.None,
    ),
    task_item.Div,
  )
}

fn view_task_status(task: Task) -> Element(Msg) {
  let status_icon = case task_state.to_status(task.state) {
    Done -> "\u{2705}"
    task_status.Claimed(_) -> "\u{1F7E1}"
    Available -> "\u{26AA}"
  }

  span([attribute.class("card-task-status")], [text(status_icon)])
}

fn view_task_claim_status(task: Task) -> Element(Msg) {
  let claimed_text = case claimed_by(task) {
    option.Some(_id) -> " (claimed)"
    option.None -> ""
  }

  span([attribute.class("card-task-info")], [text(claimed_text)])
}

fn action_policy(model: Model, card: Card) -> detail_policy.Policy {
  let tasks = case model.tasks {
    Loaded(task_list) -> task_list
    _ -> []
  }

  detail_policy.policy_for(
    card,
    detail_policy.direct_child_cards(card, model.cards),
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
