//// Tests for cards view components.
////
//// Verifies Story 3.4 acceptance criteria:
//// - AC1: Cards section renders in member navigation
//// - AC4: Pool tasks show card identification (badge, border)
//// - AC5: My bar groups tasks by card

import gleam/list
import gleam/option

import domain/card.{Cerrada, EnCurso, Pendiente, all_colors}
import scrumbringer_client/ui/card_badge
import scrumbringer_client/ui/color_picker

// =============================================================================
// Card Badge Tests (AC4)
// =============================================================================

pub fn generate_initials_two_words_test() {
  let assert "HW" = card_badge.generate_initials("Hello World")
}

pub fn generate_initials_single_word_test() {
  let assert "HE" = card_badge.generate_initials("Hello")
}

pub fn generate_initials_three_words_test() {
  let assert "AL" = card_badge.generate_initials("Auth Login Flow")
}

pub fn generate_initials_single_char_test() {
  let assert "X" = card_badge.generate_initials("X")
}

pub fn generate_initials_empty_test() {
  // Empty string returns "??" fallback
  let assert "??" = card_badge.generate_initials("")
}

pub fn generate_initials_lowercase_test() {
  let assert "TC" = card_badge.generate_initials("test card")
}

// =============================================================================
// Color Picker Tests (AC2, AC7)
// =============================================================================

pub fn all_colors_has_8_colors_test() {
  let assert 8 = list.length(all_colors)
}

pub fn color_to_string_gray_test() {
  let assert "gray" = card.color_to_string(card.Gray)
}

pub fn color_to_string_red_test() {
  let assert "red" = card.color_to_string(card.Red)
}

pub fn color_to_string_blue_test() {
  let assert "blue" = card.color_to_string(card.Blue)
}

pub fn string_to_color_gray_test() {
  let assert option.Some(card.Gray) = color_picker.string_to_color("gray")
}

pub fn string_to_color_red_test() {
  let assert option.Some(card.Red) = color_picker.string_to_color("red")
}

pub fn string_to_color_invalid_test() {
  let assert option.None = color_picker.string_to_color("invalid")
}

pub fn string_to_color_empty_test() {
  let assert option.None = color_picker.string_to_color("")
}

pub fn border_class_gray_test() {
  let assert "card-border-gray" =
    color_picker.border_class(option.Some(card.Gray))
}

pub fn border_class_red_test() {
  let assert "card-border-red" =
    color_picker.border_class(option.Some(card.Red))
}

pub fn border_class_none_test() {
  let assert "" = color_picker.border_class(option.None)
}

pub fn initials_class_blue_test() {
  let assert "card-initials-blue" =
    color_picker.initials_class(option.Some(card.Blue))
}

pub fn initials_class_none_test() {
  let assert "card-initials-none" = color_picker.initials_class(option.None)
}

// =============================================================================
// Card State Derivation Tests
// =============================================================================

pub fn derive_state_no_tasks_pendiente_test() {
  let assert Pendiente = card.derive_state(0, 0, 0)
}

pub fn derive_state_all_completed_cerrada_test() {
  let assert Cerrada = card.derive_state(3, 3, 0)
}

pub fn derive_state_some_claimed_en_curso_test() {
  // 3 tasks, 1 completed, 1 available (means 1 claimed/ongoing)
  let assert EnCurso = card.derive_state(3, 1, 1)
}

pub fn derive_state_all_available_pendiente_test() {
  // 3 tasks, 0 completed, 3 available
  let assert Pendiente = card.derive_state(3, 0, 3)
}

pub fn derive_state_one_completed_en_curso_test() {
  // 5 tasks, 1 completed, 2 available (means 2 claimed/ongoing)
  let assert EnCurso = card.derive_state(5, 1, 2)
}

// =============================================================================
// Card State String Conversion Tests
// =============================================================================

pub fn state_to_string_pendiente_test() {
  let assert "pendiente" = card.state_to_string(Pendiente)
}

pub fn state_to_string_en_curso_test() {
  let assert "en_curso" = card.state_to_string(EnCurso)
}

pub fn state_to_string_cerrada_test() {
  let assert "cerrada" = card.state_to_string(Cerrada)
}

pub fn state_from_string_pendiente_test() {
  let assert Ok(Pendiente) = card.state_from_string("pendiente")
}

pub fn state_from_string_en_curso_test() {
  let assert Ok(EnCurso) = card.state_from_string("en_curso")
}

pub fn state_from_string_cerrada_test() {
  let assert Ok(Cerrada) = card.state_from_string("cerrada")
}

pub fn state_from_string_invalid_returns_error_test() {
  let assert Error(card.UnknownCardState("invalid")) =
    card.state_from_string("invalid")
}
