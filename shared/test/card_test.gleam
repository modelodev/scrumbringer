import domain/card
import gleam/option.{None, Some}

// =============================================================================
// State Derivation Tests
// =============================================================================

pub fn derive_state_pendiente_when_no_tasks_test() {
  let assert card.Draft = card.derive_state(0, 0, 0)
}

pub fn derive_state_pendiente_when_all_tasks_available_test() {
  let assert card.Draft = card.derive_state(3, 0, 3)
}

pub fn derive_state_en_curso_when_task_in_progress_test() {
  let assert card.Active = card.derive_state(3, 1, 1)
}

pub fn derive_state_en_curso_when_some_completed_and_some_available_test() {
  let assert card.Active = card.derive_state(4, 2, 2)
}

pub fn derive_state_cerrada_when_all_completed_test() {
  let assert card.Closed = card.derive_state(3, 3, 0)
}

pub fn derive_state_cerrada_when_single_task_completed_test() {
  let assert card.Closed = card.derive_state(1, 1, 0)
}

// =============================================================================
// State String Conversion Tests
// =============================================================================

pub fn state_to_string_test() {
  let assert "pendiente" = card.state_to_string(card.Draft)
  let assert "en_curso" = card.state_to_string(card.Active)
  let assert "cerrada" = card.state_to_string(card.Closed)
}

pub fn parse_state_test() {
  let assert Ok(card.Draft) = card.parse_state("pendiente")
  let assert Ok(card.Active) = card.parse_state("en_curso")
  let assert Ok(card.Closed) = card.parse_state("cerrada")
}

pub fn parse_state_rejects_unknown_values_test() {
  let assert Error(card.UnknownCardPhase("invalid")) =
    card.parse_state("invalid")
  let assert Error(card.UnknownCardPhase("")) = card.parse_state("")
}

pub fn state_from_string_rejects_unknown_values_test() {
  let assert Error(card.UnknownCardPhase("invalid")) =
    card.state_from_string("invalid")
  let assert Error(card.UnknownCardPhase("")) = card.state_from_string("")
}

// =============================================================================
// Color String Conversion Tests
// =============================================================================

pub fn color_to_string_test() {
  let assert "gray" = card.color_to_string(card.Gray)
  let assert "red" = card.color_to_string(card.Red)
  let assert "orange" = card.color_to_string(card.Orange)
  let assert "yellow" = card.color_to_string(card.Yellow)
  let assert "green" = card.color_to_string(card.Green)
  let assert "blue" = card.color_to_string(card.Blue)
  let assert "purple" = card.color_to_string(card.Purple)
  let assert "pink" = card.color_to_string(card.Pink)
}

pub fn optional_color_to_string_test() {
  let assert "" = card.optional_color_to_string(None)
  let assert "blue" = card.optional_color_to_string(Some(card.Blue))
}

pub fn parse_color_test() {
  let assert Ok(card.Gray) = card.parse_color("gray")
  let assert Ok(card.Red) = card.parse_color("red")
  let assert Ok(card.Orange) = card.parse_color("orange")
  let assert Ok(card.Yellow) = card.parse_color("yellow")
  let assert Ok(card.Green) = card.parse_color("green")
  let assert Ok(card.Blue) = card.parse_color("blue")
  let assert Ok(card.Purple) = card.parse_color("purple")
  let assert Ok(card.Pink) = card.parse_color("pink")
}

pub fn parse_optional_color_test() {
  let assert Ok(None) = card.parse_optional_color("")
  let assert Ok(Some(card.Blue)) = card.parse_optional_color("blue")
}

pub fn parse_color_rejects_unknown_values_test() {
  let assert Error(card.UnknownCardColor("cyan")) = card.parse_color("cyan")
  let assert Error(card.UnknownCardColor("")) = card.parse_color("")
}

pub fn parse_optional_color_rejects_unknown_values_test() {
  let assert Error(card.UnknownCardColor("cyan")) =
    card.parse_optional_color("cyan")
}

pub fn color_from_string_rejects_unknown_values_test() {
  let assert Error(card.UnknownCardColor("cyan")) =
    card.color_from_string("cyan")
  let assert Error(card.UnknownCardColor("")) = card.color_from_string("")
}
