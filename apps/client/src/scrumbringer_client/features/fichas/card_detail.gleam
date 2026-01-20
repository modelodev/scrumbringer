//// Card detail modal component for member views.
////
//// ## Mission
////
//// Display card information and its tasks, allowing members to view progress
//// and create new tasks belonging to the card.
////
//// ## Responsibilities
////
//// - Show card header with title, description, state, color badge
//// - Display task list with status indicators
//// - Provide "Add Task" inline form
//// - Created tasks automatically belong to the card
////
//// ## Relations
////
//// - **features/fichas/view.gleam**: Opens this modal when card clicked
//// - **client_state.gleam**: Provides Model, Msg types
//// - **api/cards.gleam**: Fetches card data
//// - **api/tasks.gleam**: Creates tasks with card_id

import gleam/int
import gleam/list
import gleam/option

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, input, label, span, text}
import lustre/event

import domain/card.{type Card, type CardState, Cerrada, EnCurso, Pendiente}
import domain/task.{type Task}
import domain/task_status.{Available, Completed}
import scrumbringer_client/client_state.{type Model, type Msg}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/color_picker
import scrumbringer_client/update_helpers

// =============================================================================
// View Functions
// =============================================================================

/// Main entry point for the card detail modal.
/// Shows card info header, task list, and optional add task form.
pub fn view_card_detail(
  model: Model,
  card: Card,
  tasks: List(Task),
  add_task_open: Bool,
) -> Element(Msg) {
  let color_opt = color_from_string(card.color)
  let border_class = color_picker.border_class(color_opt)

  div(
    [
      attribute.class("card-detail-modal"),
    ],
    [
      // Backdrop (clicking closes modal)
      div(
        [
          attribute.class("modal-backdrop"),
          event.on_click(client_state.CloseCardDetail),
        ],
        [],
      ),
      // Modal content
      div(
        [
          attribute.class("modal-content card-detail " <> border_class),
        ],
        [
          view_card_header(model, card),
          view_card_tasks_section(model, tasks, add_task_open),
        ],
      ),
    ],
  )
}

fn view_card_header(model: Model, card: Card) -> Element(Msg) {
  let state_class = state_to_class(card.state)
  let state_label = state_to_label(model, card.state)
  let progress_pct = case card.task_count {
    0 -> 0
    n -> card.completed_count * 100 / n
  }

  div(
    [attribute.class("card-detail-header")],
    [
      // Title row with close button
      div(
        [attribute.class("card-detail-title-row")],
        [
          span([attribute.class("card-detail-title")], [text(card.title)]),
          button(
            [
              attribute.class("btn-icon"),
              event.on_click(client_state.CloseCardDetail),
              attribute.attribute("aria-label", "Close"),
            ],
            [text("\u{2715}")],
          ),
        ],
      ),
      // State and progress
      div(
        [attribute.class("card-detail-meta")],
        [
          span([attribute.class("card-state-badge " <> state_class)], [
            text(state_label),
          ]),
          span([attribute.class("card-detail-progress-text")], [
            text(
              int.to_string(card.completed_count)
              <> "/"
              <> int.to_string(card.task_count)
              <> " "
              <> update_helpers.i18n_t(model, i18n_text.CardTasksCompleted),
            ),
          ]),
        ],
      ),
      // Progress bar
      div(
        [attribute.class("card-detail-progress-bar")],
        [
          div(
            [
              attribute.class("card-detail-progress-fill"),
              attribute.attribute(
                "style",
                "width: " <> int.to_string(progress_pct) <> "%",
              ),
            ],
            [],
          ),
        ],
      ),
      // Description
      case card.description {
        "" -> element.none()
        desc ->
          div([attribute.class("card-detail-description")], [text(desc)])
      },
    ],
  )
}

fn view_card_tasks_section(
  model: Model,
  tasks: List(Task),
  add_task_open: Bool,
) -> Element(Msg) {
  div(
    [attribute.class("card-detail-tasks-section")],
    [
      // Section header with Add button
      div(
        [attribute.class("card-detail-tasks-header")],
        [
          span([attribute.class("card-detail-tasks-title")], [
            text(update_helpers.i18n_t(model, i18n_text.CardTasks)),
          ]),
          button(
            [
              attribute.class("btn btn-sm btn-primary"),
              event.on_click(client_state.ToggleAddTaskForm),
            ],
            [text("+ " <> update_helpers.i18n_t(model, i18n_text.CardAddTask))],
          ),
        ],
      ),
      // Add task form (if open)
      case add_task_open {
        True -> view_add_task_form(model)
        False -> element.none()
      },
      // Task list
      case list.is_empty(tasks) {
        True -> view_empty_tasks(model)
        False -> view_task_list(model, tasks)
      },
    ],
  )
}

fn view_add_task_form(model: Model) -> Element(Msg) {
  div(
    [attribute.class("card-add-task-form")],
    [
      div(
        [attribute.class("form-group")],
        [
          label([attribute.for("task-title")], [
            text(update_helpers.i18n_t(model, i18n_text.Title)),
          ]),
          input([
            attribute.type_("text"),
            attribute.id("task-title"),
            attribute.class("form-input"),
            attribute.placeholder(
              update_helpers.i18n_t(model, i18n_text.TaskTitlePlaceholder),
            ),
            attribute.value(model.card_add_task_title),
            event.on_input(client_state.CardAddTaskTitleInput),
          ]),
        ],
      ),
      div(
        [attribute.class("form-row")],
        [
          // Task type selector (placeholder)
          div(
            [attribute.class("form-group form-group-half")],
            [
              label([], [
                text(update_helpers.i18n_t(model, i18n_text.TaskType)),
              ]),
              // For now, use a simple text showing default type
              span([attribute.class("form-static")], [text("Feature")]),
            ],
          ),
          // Priority selector (placeholder)
          div(
            [attribute.class("form-group form-group-half")],
            [
              label([], [
                text(update_helpers.i18n_t(model, i18n_text.Priority)),
              ]),
              view_priority_dots(model.card_add_task_priority),
            ],
          ),
        ],
      ),
      div(
        [attribute.class("form-actions")],
        [
          button(
            [
              attribute.class("btn btn-secondary"),
              event.on_click(client_state.CancelAddTask),
            ],
            [text(update_helpers.i18n_t(model, i18n_text.Cancel))],
          ),
          button(
            [
              attribute.class("btn btn-primary"),
              event.on_click(client_state.SubmitAddTask),
              attribute.disabled(model.card_add_task_title == ""),
            ],
            [text(update_helpers.i18n_t(model, i18n_text.Create))],
          ),
        ],
      ),
    ],
  )
}

fn view_priority_dots(priority: Int) -> Element(Msg) {
  div(
    [attribute.class("priority-dots")],
    list.range(1, 5)
      |> list.map(fn(p) {
        let active_class = case p <= priority {
          True -> " active"
          False -> ""
        }
        button(
          [
            attribute.class("priority-dot" <> active_class),
            event.on_click(client_state.CardAddTaskPrioritySelect(p)),
            attribute.attribute("aria-label", "Priority " <> int.to_string(p)),
          ],
          [],
        )
      }),
  )
}

fn view_empty_tasks(model: Model) -> Element(Msg) {
  div(
    [attribute.class("card-tasks-empty")],
    [
      span([attribute.class("card-tasks-empty-text")], [
        text(update_helpers.i18n_t(model, i18n_text.CardTasksEmpty)),
      ]),
    ],
  )
}

fn view_task_list(_model: Model, tasks: List(Task)) -> Element(Msg) {
  div(
    [attribute.class("card-task-list")],
    list.map(tasks, view_task_item),
  )
}

fn view_task_item(task: Task) -> Element(Msg) {
  let status_icon = case task.status {
    Completed -> "\u{2705}"
    // green checkmark
    task_status.Claimed(_) -> "\u{1F7E1}"
    // yellow circle
    Available -> "\u{26AA}"
    // white circle
  }

  let claimed_text = case task.claimed_by {
    option.Some(_id) -> " (claimed)"
    option.None -> ""
  }

  div(
    [attribute.class("card-task-item")],
    [
      span([attribute.class("card-task-status")], [text(status_icon)]),
      span([attribute.class("card-task-title")], [text(task.title)]),
      span([attribute.class("card-task-info")], [text(claimed_text)]),
    ],
  )
}

// =============================================================================
// Helper Functions
// =============================================================================

fn state_to_class(state: CardState) -> String {
  case state {
    Pendiente -> "card-state-pendiente"
    EnCurso -> "card-state-en_curso"
    Cerrada -> "card-state-cerrada"
  }
}

fn state_to_label(model: Model, state: CardState) -> String {
  case state {
    Pendiente -> update_helpers.i18n_t(model, i18n_text.CardStatePendiente)
    EnCurso -> update_helpers.i18n_t(model, i18n_text.CardStateEnCurso)
    Cerrada -> update_helpers.i18n_t(model, i18n_text.CardStateCerrada)
  }
}

/// Convert string color from Card to color_picker.CardColor option.
fn color_from_string(
  color: option.Option(String),
) -> option.Option(color_picker.CardColor) {
  case color {
    option.None -> option.None
    option.Some(c) -> color_picker.string_to_color(c)
  }
}
