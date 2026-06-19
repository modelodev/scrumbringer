//// Card domain types for ScrumBringer.
////
//// Defines card (ficha) structures used for grouping related tasks.
//// Card state is derived from its tasks, not stored.
////
//// ## Usage
////
//// ```gleam
//// import shared/domain/card.{type Card, type CardPhase}
////
//// let card = Card(id: 1, project_id: 10, title: "OAuth", ...)
//// ```

import domain/org_role.{type OrgRole}
import domain/project_role.{type ProjectRole}
import gleam/option.{type Option, None, Some}

// =============================================================================
// Types
// =============================================================================

/// Card state derived from task status counts.
///
/// - Draft: No tasks, or all tasks are available
/// - Active: Some tasks are claimed or completed (progress)
/// - Closed: All tasks are completed
pub type CardPhase {
  Draft
  Active
  Closed
}

/// Error returned when an external card state cannot be parsed.
pub type CardPhaseParseError {
  UnknownCardPhase(String)
}

/// Available card colors.
pub type CardColor {
  Gray
  Red
  Orange
  Yellow
  Green
  Blue
  Purple
  Pink
}

/// Error returned when an external card color cannot be parsed.
pub type CardColorParseError {
  UnknownCardColor(String)
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
///   color: Some(Blue),
///   state: Active,
///   task_count: 3,
///   completed_count: 1,
///   created_by: 42,
///   created_at: "2026-01-18T10:00:00Z",
///   due_date: None,
///   has_new_notes: True,
/// )
/// ```
pub type Card {
  Card(
    id: Int,
    project_id: Int,
    parent_card_id: Option(Int),
    title: String,
    description: String,
    color: Option(CardColor),
    state: CardPhase,
    task_count: Int,
    completed_count: Int,
    created_by: Int,
    created_at: String,
    due_date: Option(String),
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
///   author_project_role: Some(Manager),
///   author_org_role: Admin,
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
    author_project_role: Option(ProjectRole),
    author_org_role: OrgRole,
  )
}

// =============================================================================
// State Derivation
// =============================================================================

/// Derive card state from task counts.
///
/// ## Rules
///
/// 1. task_count = 0 → Draft
/// 2. task_count > 0 AND task_count = completed_count → Closed
/// 3. available_count < task_count → Active (some progress)
/// 4. else → Draft (all available)
///
/// ## Example
///
/// ```gleam
/// derive_state(3, 1, 2) // Active (1 completed, some progress)
/// derive_state(3, 3, 0) // Closed (all completed)
/// derive_state(0, 0, 0) // Draft (no tasks)
/// ```
pub fn derive_state(
  task_count: Int,
  completed_count: Int,
  available_count: Int,
) -> CardPhase {
  // If any task is NOT available (claimed or completed), there's progress.
  case
    task_count == 0,
    task_count == completed_count,
    available_count < task_count
  {
    True, _, _ -> Draft
    False, True, _ -> Closed
    False, False, True -> Active
    False, False, False -> Draft
  }
}

/// Convert CardPhase to string for API.
pub fn state_to_string(state: CardPhase) -> String {
  case state {
    Draft -> "pendiente"
    Active -> "en_curso"
    Closed -> "cerrada"
  }
}

/// Parse CardPhase from API string.
pub fn parse_state(s: String) -> Result(CardPhase, CardPhaseParseError) {
  case s {
    "pendiente" -> Ok(Draft)
    "en_curso" -> Ok(Active)
    "cerrada" -> Ok(Closed)
    other -> Error(UnknownCardPhase(other))
  }
}

/// Parse CardPhase from an external string.
///
/// This function is intentionally strict. Unknown external values must be
/// handled at the boundary instead of being silently normalised.
pub fn state_from_string(s: String) -> Result(CardPhase, CardPhaseParseError) {
  parse_state(s)
}

/// All available card colors in display order.
pub const all_colors = [Gray, Red, Orange, Yellow, Green, Blue, Purple, Pink]

/// Convert CardColor to its external string representation.
pub fn color_to_string(color: CardColor) -> String {
  case color {
    Gray -> "gray"
    Red -> "red"
    Orange -> "orange"
    Yellow -> "yellow"
    Green -> "green"
    Blue -> "blue"
    Purple -> "purple"
    Pink -> "pink"
  }
}

/// Convert an optional CardColor to its external string representation.
///
/// Empty string is the wire/storage representation for an absent color.
pub fn optional_color_to_string(color: Option(CardColor)) -> String {
  case color {
    None -> ""
    Some(value) -> color_to_string(value)
  }
}

/// Parse CardColor from an external string.
pub fn parse_color(s: String) -> Result(CardColor, CardColorParseError) {
  case s {
    "gray" -> Ok(Gray)
    "red" -> Ok(Red)
    "orange" -> Ok(Orange)
    "yellow" -> Ok(Yellow)
    "green" -> Ok(Green)
    "blue" -> Ok(Blue)
    "purple" -> Ok(Purple)
    "pink" -> Ok(Pink)
    other -> Error(UnknownCardColor(other))
  }
}

/// Parse an optional CardColor from its external string representation.
///
/// Empty string represents absence. Any other value must be a valid CardColor.
pub fn parse_optional_color(
  s: String,
) -> Result(Option(CardColor), CardColorParseError) {
  case s {
    "" -> Ok(None)
    value -> {
      case parse_color(value) {
        Ok(color) -> Ok(Some(color))
        Error(error) -> Error(error)
      }
    }
  }
}

/// Parse CardColor from an external string.
///
/// This function is intentionally strict. Unknown external values must be
/// handled at the boundary instead of being silently normalised.
pub fn color_from_string(s: String) -> Result(CardColor, CardColorParseError) {
  parse_color(s)
}
