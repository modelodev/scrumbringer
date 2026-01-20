//// Card domain types for ScrumBringer.
////
//// Defines card (ficha) structures used for grouping related tasks.
//// Card state is derived from its tasks, not stored.
////
//// ## Usage
////
//// ```gleam
//// import shared/domain/card.{type Card, type CardState}
////
//// let card = Card(id: 1, project_id: 10, title: "OAuth", ...)
//// ```

import gleam/option.{type Option}

// =============================================================================
// Types
// =============================================================================

/// Card state derived from task status counts.
///
/// - Pendiente: No tasks, or all tasks are available
/// - EnCurso: Some tasks are claimed or completed (progress)
/// - Cerrada: All tasks are completed
pub type CardState {
  Pendiente
  EnCurso
  Cerrada
}

/// A card (ficha) that groups related tasks.
///
/// ## Example
///
/// ```gleam
/// Card(
///   id: 1,
///   project_id: 10,
///   title: "OAuth Implementation",
///   description: "Login with Google and GitHub",
///   color: Some("blue"),
///   state: EnCurso,
///   task_count: 3,
///   completed_count: 1,
///   created_by: 42,
///   created_at: "2026-01-18T10:00:00Z",
/// )
/// ```
pub type Card {
  Card(
    id: Int,
    project_id: Int,
    title: String,
    description: String,
    color: Option(String),
    state: CardState,
    task_count: Int,
    completed_count: Int,
    created_by: Int,
    created_at: String,
  )
}

// =============================================================================
// State Derivation
// =============================================================================

/// Derive card state from task counts.
///
/// ## Rules
///
/// 1. task_count = 0 → Pendiente
/// 2. task_count > 0 AND task_count = completed_count → Cerrada
/// 3. available_count < task_count → EnCurso (some progress)
/// 4. else → Pendiente (all available)
///
/// ## Example
///
/// ```gleam
/// derive_state(3, 1, 2) // EnCurso (1 completed, some progress)
/// derive_state(3, 3, 0) // Cerrada (all completed)
/// derive_state(0, 0, 0) // Pendiente (no tasks)
/// ```
pub fn derive_state(
  task_count: Int,
  completed_count: Int,
  available_count: Int,
) -> CardState {
  case task_count {
    0 -> Pendiente
    _ -> {
      case task_count == completed_count {
        True -> Cerrada
        False -> {
          // If any task is NOT available (claimed or completed), there's progress
          case available_count < task_count {
            True -> EnCurso
            False -> Pendiente
          }
        }
      }
    }
  }
}

/// Convert CardState to string for API.
pub fn state_to_string(state: CardState) -> String {
  case state {
    Pendiente -> "pendiente"
    EnCurso -> "en_curso"
    Cerrada -> "cerrada"
  }
}

/// Parse CardState from API string.
pub fn state_from_string(s: String) -> CardState {
  case s {
    "en_curso" -> EnCurso
    "cerrada" -> Cerrada
    _ -> Pendiente
  }
}
