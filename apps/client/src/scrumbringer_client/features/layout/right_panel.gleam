//// Right Panel - Activity and profile panel
////
//// Mission: Render the right panel with user activity (my tasks, my cards),
//// active task timer, preferences, and profile/logout controls.
////
//// Responsibilities:
//// - "My Tasks" section with claimed tasks
//// - "My Cards" section with user's card progress
//// - "My Metrics" section with personal stats
//// - Active task timer with controls
//// - Preferences section (theme, language)
//// - Profile info and logout button (always at bottom)
////
//// Non-responsibilities:
//// - Layout structure (handled by ThreePanelLayout)
//// - Timer logic (handled by parent)
//// - API calls (handled by parent)

import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, h4, label, option, select, span, text}
import lustre/event

import domain/task.{type Task}
import domain/user.{type User}
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/theme.{type Theme}
import scrumbringer_client/ui/card_progress
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/task_color
import scrumbringer_client/ui/task_type_icon

// =============================================================================
// Types
// =============================================================================

/// Active task info for timer display
pub type ActiveTaskInfo {
  ActiveTaskInfo(
    task_id: Int,
    task_title: String,
    task_type_icon: String,
    card_color: Option(String),
    elapsed_display: String,
    is_paused: Bool,
  )
}

/// Card with progress for my cards section
pub type MyCardProgress {
  MyCardProgress(
    card_id: Int,
    card_title: String,
    card_color: Option(String),
    completed: Int,
    total: Int,
  )
}

/// Configuration for the right panel
pub type RightPanelConfig(msg) {
  RightPanelConfig(
    locale: Locale,
    user: Option(User),
    my_tasks: List(Task),
    my_cards: List(MyCardProgress),
    active_tasks: List(ActiveTaskInfo),
    on_task_start: fn(Int) -> msg,
    on_task_pause: fn(Int) -> msg,
    on_task_complete: fn(Int) -> msg,
    on_task_release: fn(Int) -> msg,
    on_card_click: fn(Int) -> msg,
    on_logout: msg,
    // Drag-to-claim state for Pool view (Story 4.7)
    drag_armed: Bool,
    drag_over_my_tasks: Bool,
    // Preferences popup (Story 4.8 UX: moved from inline to popup)
    preferences_popup_open: Bool,
    on_preferences_toggle: msg,
    current_theme: Theme,
    on_theme_change: fn(String) -> msg,
    on_locale_change: fn(String) -> msg,
    // Disable actions while mutation in flight
    disable_actions: Bool,
  )
}

// =============================================================================
// View
// =============================================================================

/// Renders the right panel with all sections
pub fn view(config: RightPanelConfig(msg)) -> Element(msg) {
  div([attribute.class("right-panel-content")], [
    // Activity sections (top)
    div([attribute.class("right-panel-activity")], [
      // Active tasks section (supports multiple)
      view_active_tasks_section(config),
      // My Tasks section
      view_my_tasks(config),
      // My Cards section
      view_my_cards(config),
    ]),
    // Footer sections (bottom - pushed down with flex spacer)
    div([attribute.class("right-panel-footer")], [
      // Profile with preferences gear (Story 4.8 UX)
      view_profile(config),
    ]),
    // Preferences popup (Story 4.8 UX: moved from inline)
    view_preferences_popup(config),
  ])
}

// =============================================================================
// Active Tasks Section (supports multiple concurrent tasks)
// =============================================================================

fn view_active_tasks_section(config: RightPanelConfig(msg)) -> Element(msg) {
  case config.active_tasks {
    [] -> element.none()
    tasks -> {
      let task_count = list.length(tasks)
      let header_text = case task_count {
        1 -> i18n.t(config.locale, i18n_text.InProgress)
        n ->
          i18n.t(config.locale, i18n_text.InProgress)
          <> " ("
          <> int.to_string(n)
          <> ")"
      }

      div(
        [
          attribute.class("active-task-section"),
          attribute.attribute("data-testid", "active-task"),
        ],
        [
          h4([attribute.class("section-title section-title-with-icon")], [
            icons.nav_icon(icons.Play, icons.Small),
            text(header_text),
          ]),
          div(
            [attribute.class("active-tasks-list")],
            list.map(tasks, fn(active) { view_active_task_card(config, active) }),
          ),
        ],
      )
    }
  }
}

fn view_active_task_card(
  config: RightPanelConfig(msg),
  active: ActiveTaskInfo,
) -> Element(msg) {
  let border_class = task_color.card_border_class(active.card_color)

  div([attribute.class("active-task-card " <> border_class)], [
    div([attribute.class("task-title-row")], [
      // Task type icon
      span([attribute.class("task-type-icon")], [
        task_type_icon.view(active.task_type_icon, 14, config.current_theme),
      ]),
      span([attribute.class("task-title")], [text(active.task_title)]),
    ]),
    div(
      [
        attribute.class("task-timer"),
        attribute.attribute("data-testid", "task-timer"),
      ],
      [text(active.elapsed_display)],
    ),
    div([attribute.class("task-actions")], [
      case active.is_paused {
        True ->
          button(
            [
              attribute.class("btn-xs btn-icon"),
              attribute.attribute("data-testid", "my-task-start-btn"),
              attribute.attribute(
                "title",
                i18n.t(config.locale, i18n_text.Resume),
              ),
              attribute.disabled(config.disable_actions),
              event.on_click(config.on_task_start(active.task_id)),
            ],
            [icons.nav_icon(icons.Play, icons.Small)],
          )
        False ->
          button(
            [
              attribute.class("btn-xs btn-icon"),
              attribute.attribute("data-testid", "task-pause-btn"),
              attribute.attribute(
                "title",
                i18n.t(config.locale, i18n_text.Pause),
              ),
              attribute.disabled(config.disable_actions),
              event.on_click(config.on_task_pause(active.task_id)),
            ],
            [icons.nav_icon(icons.Pause, icons.Small)],
          )
      },
      button(
        [
          attribute.class("btn-xs btn-icon"),
          attribute.attribute("data-testid", "task-complete-btn"),
          attribute.attribute(
            "title",
            i18n.t(config.locale, i18n_text.Complete),
          ),
          attribute.disabled(config.disable_actions),
          event.on_click(config.on_task_complete(active.task_id)),
        ],
        [icons.nav_icon(icons.Check, icons.Small)],
      ),
    ]),
  ])
}

// =============================================================================
// My Tasks Section (Story 4.12: Grouped by card with [+] buttons)
// =============================================================================

fn view_my_tasks(config: RightPanelConfig(msg)) -> Element(msg) {
  // Story 4.8 UX: Filter out ALL active tasks from list (avoid duplication)
  let active_task_ids = list.map(config.active_tasks, fn(a) { a.task_id })
  let filtered_tasks =
    list.filter(config.my_tasks, fn(task) {
      !list.contains(active_task_ids, task.id)
    })

  // Dropzone class for drag-to-claim visual feedback (Story 4.7)
  let dropzone_class = case config.drag_armed, config.drag_over_my_tasks {
    True, True -> "my-tasks-section pool-my-tasks-dropzone drop-over"
    True, False -> "my-tasks-section pool-my-tasks-dropzone drag-active"
    False, _ -> "my-tasks-section pool-my-tasks-dropzone"
  }

  let is_empty = list.is_empty(filtered_tasks)
  let section_class = case is_empty {
    True -> dropzone_class <> " section-collapsed"
    False -> dropzone_class
  }

  div(
    [
      attribute.attribute("id", "pool-my-tasks"),
      attribute.class(section_class),
      attribute.attribute("data-testid", "my-tasks"),
    ],
    [
      // Dropzone hint when dragging (Story 4.7)
      case config.drag_armed {
        True ->
          div([attribute.class("dropzone-hint")], [
            text(
              i18n.t(config.locale, i18n_text.Claim)
              <> ": "
              <> i18n.t(config.locale, i18n_text.MyTasks),
            ),
          ])
        False -> element.none()
      },
      // Story 4.8: Compact header with icon
      h4([attribute.class("section-title section-title-with-icon")], [
        icons.nav_icon(icons.ClipboardDoc, icons.Small),
        text(i18n.t(config.locale, i18n_text.MyTasks)),
        case is_empty {
          True ->
            span([attribute.class("section-empty-indicator")], [
              text(" (0)"),
            ])
          False ->
            span([attribute.class("section-count")], [
              text(" (" <> int.to_string(list.length(filtered_tasks)) <> ")"),
            ])
        },
      ]),
      // Simple flat task list
      case filtered_tasks {
        [] -> element.none()
        tasks ->
          div(
            [attribute.class("task-list")],
            list.map(tasks, fn(task) { view_my_task_item(config, task) }),
          )
      },
    ],
  )
}

fn view_my_task_item(config: RightPanelConfig(msg), task: Task) -> Element(msg) {
  let border_class = task_color.card_border_class(task.card_color)

  div([attribute.class("task-item " <> border_class)], [
    div([attribute.class("task-title-row")], [
      // Task type icon
      span([attribute.class("task-type-icon")], [
        task_type_icon.view(task.task_type.icon, 14, config.current_theme),
      ]),
      span([attribute.class("task-title")], [text(task.title)]),
    ]),
    div([attribute.class("task-actions")], [
      // Start button (icon)
      button(
        [
          attribute.class("btn-xs btn-icon"),
          attribute.attribute("data-testid", "my-task-start-btn"),
          attribute.attribute("title", i18n.t(config.locale, i18n_text.Start)),
          attribute.disabled(config.disable_actions),
          event.on_click(config.on_task_start(task.id)),
        ],
        [icons.nav_icon(icons.Play, icons.Small)],
      ),
      // Release button (icon)
      button(
        [
          attribute.class("btn-xs btn-icon"),
          attribute.attribute("data-testid", "my-task-release-btn"),
          attribute.attribute("title", i18n.t(config.locale, i18n_text.Release)),
          attribute.disabled(config.disable_actions),
          event.on_click(config.on_task_release(task.id)),
        ],
        [icons.nav_icon(icons.Return, icons.Small)],
      ),
    ]),
  ])
}

// =============================================================================
// My Cards Section
// =============================================================================

fn view_my_cards(config: RightPanelConfig(msg)) -> Element(msg) {
  let is_empty = list.is_empty(config.my_cards)
  let section_class = case is_empty {
    True -> "my-cards-section section-collapsed"
    False -> "my-cards-section"
  }

  div(
    [
      attribute.class(section_class),
      attribute.attribute("data-testid", "my-cards"),
    ],
    [
      // Story 4.8: Compact header with icon
      h4([attribute.class("section-title section-title-with-icon")], [
        icons.nav_icon(icons.Cards, icons.Small),
        text(i18n.t(config.locale, i18n_text.MyCards)),
        case is_empty {
          True ->
            span([attribute.class("section-empty-indicator")], [
              text(" (0)"),
            ])
          False ->
            span([attribute.class("section-count")], [
              text(" (" <> int.to_string(list.length(config.my_cards)) <> ")"),
            ])
        },
      ]),
      // Hide empty state content when collapsed
      case config.my_cards {
        [] -> element.none()
        cards ->
          div(
            [attribute.class("my-cards-list")],
            list.map(cards, fn(card) { view_my_card_item(config, card) }),
          )
      },
    ],
  )
}

fn view_my_card_item(
  config: RightPanelConfig(msg),
  card: MyCardProgress,
) -> Element(msg) {
  let border_class = task_color.card_border_class(card.card_color)

  button(
    [
      attribute.class("my-card-item " <> border_class),
      attribute.attribute("data-testid", "my-card-item"),
      event.on_click(config.on_card_click(card.card_id)),
    ],
    [
      span([attribute.class("card-title")], [text(card.card_title)]),
      card_progress.view(card.completed, card.total, card_progress.Compact),
    ],
  )
}

// =============================================================================
// Preferences Popup (Story 4.8 UX: moved from inline section)
// =============================================================================

// Justification: nested case improves clarity for branching logic.
fn view_preferences_popup(config: RightPanelConfig(msg)) -> Element(msg) {
  case config.preferences_popup_open {
    False -> element.none()
    True -> {
      let current_theme = theme.serialize(config.current_theme)
      let current_locale = locale.serialize(config.locale)

      div(
        [
          attribute.class("preferences-popup-overlay"),
          event.on_click(config.on_preferences_toggle),
        ],
        [
          div(
            [
              attribute.class("preferences-popup"),
              attribute.attribute("data-testid", "preferences-popup"),
            ],
            [
              h4([attribute.class("popup-title")], [
                icons.nav_icon(icons.Cog, icons.Small),
                text(i18n.t(config.locale, i18n_text.Preferences)),
              ]),
              div([attribute.class("preferences-popup-content")], [
                // Theme selector
                label([attribute.class("preference-item")], [
                  span([attribute.class("preference-icon")], [
                    case config.current_theme {
                      theme.Dark -> icons.nav_icon(icons.Moon, icons.Small)
                      theme.Default -> icons.nav_icon(icons.Sun, icons.Small)
                    },
                  ]),
                  select(
                    [
                      attribute.class("preference-select"),
                      attribute.value(current_theme),
                      attribute.attribute("data-testid", "theme-selector"),
                      event.on_input(config.on_theme_change),
                    ],
                    [
                      option(
                        [attribute.value("default")],
                        i18n.t(config.locale, i18n_text.ThemeDefault),
                      ),
                      option(
                        [attribute.value("dark")],
                        i18n.t(config.locale, i18n_text.ThemeDark),
                      ),
                    ],
                  ),
                ]),
                // Language selector
                label([attribute.class("preference-item")], [
                  span([attribute.class("preference-icon")], [
                    icons.nav_icon(icons.Globe, icons.Small),
                  ]),
                  select(
                    [
                      attribute.class("preference-select"),
                      attribute.value(current_locale),
                      attribute.attribute("data-testid", "locale-selector"),
                      event.on_input(config.on_locale_change),
                    ],
                    [
                      option([attribute.value("es")], "Español"),
                      option([attribute.value("en")], "English"),
                    ],
                  ),
                ]),
              ]),
            ],
          ),
        ],
      )
    }
  }
}

// =============================================================================
// Profile Section (Story 4.8 UX: compact with gear icon for preferences)
// =============================================================================

fn view_profile(config: RightPanelConfig(msg)) -> Element(msg) {
  div([attribute.class("profile-section")], [
    case config.user {
      Some(user) ->
        div([attribute.class("user-info")], [
          icons.nav_icon(icons.UserCircle, icons.Small),
          span([attribute.class("user-email")], [text(user.email)]),
        ])
      None -> element.none()
    },
    div([attribute.class("profile-actions")], [
      // Preferences gear icon (Story 4.8 UX: opens popup)
      button(
        [
          attribute.class("btn-icon-only"),
          attribute.attribute("data-testid", "preferences-btn"),
          attribute.attribute(
            "title",
            i18n.t(config.locale, i18n_text.Preferences),
          ),
          event.on_click(config.on_preferences_toggle),
        ],
        [icons.nav_icon(icons.Cog, icons.Small)],
      ),
      // Logout button (icon only)
      button(
        [
          attribute.class("btn-icon-only btn-logout"),
          attribute.attribute("data-testid", "logout-btn"),
          attribute.attribute("title", i18n.t(config.locale, i18n_text.Logout)),
          event.on_click(config.on_logout),
        ],
        [icons.nav_icon(icons.Logout, icons.Small)],
      ),
    ]),
  ])
}
