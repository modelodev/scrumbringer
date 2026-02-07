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
///   has_new_notes: True,
/// )
/// ```
pub type Card {
  Card(
    id: Int,
    project_id: Int,
    milestone_id: Option(Int),
    title: String,
    description: String,
    color: Option(String),
    state: CardState,
    task_count: Int,
    completed_count: Int,
    created_by: Int,
    created_at: String,
    has_new_notes: Bool,
  )
}

/// A note attached to a card.
///
/// ## Example
///
/// ```gleam
/// CardNote(
///   id: 1,
///   card_id: 10,
///   user_id: 42,
///   content: "Scope agreed with PM",
///   created_at: "2026-01-28T12:00:00Z",
///   author_email: "user@example.com",
///   author_project_role: Some("manager"),
///   author_org_role: "admin",
/// )
/// ```
pub type CardNote {
  CardNote(
    id: Int,
    card_id: Int,
    user_id: Int,
    content: String,
    created_at: String,
    author_email: String,
    author_project_role: Option(String),
    author_org_role: String,
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
  // If any task is NOT available (claimed or completed), there's progress.
  case
    task_count == 0,
    task_count == completed_count,
    available_count < task_count
  {
    True, _, _ -> Pendiente
    False, True, _ -> Cerrada
    False, False, True -> EnCurso
    False, False, False -> Pendiente
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
