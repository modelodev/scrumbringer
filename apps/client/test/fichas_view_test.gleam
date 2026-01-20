//// Tests for fichas (cards) view components.
////
//// Verifies Story 3.4 acceptance criteria:
//// - AC1: Fichas section renders in member navigation
//// - AC4: Pool tasks show card identification (badge, border)
//// - AC5: My bar groups tasks by card

import gleam/list
import gleam/option
import gleeunit/should

import domain/card.{Cerrada, EnCurso, Pendiente}
import scrumbringer_client/ui/card_badge
import scrumbringer_client/ui/color_picker

// =============================================================================
// Card Badge Tests (AC4)
// =============================================================================

pub fn generate_initials_two_words_test() {
  let initials = card_badge.generate_initials("Hello World")
  initials |> should.equal("HW")
}

pub fn generate_initials_single_word_test() {
  let initials = card_badge.generate_initials("Hello")
  initials |> should.equal("HE")
}

pub fn generate_initials_three_words_test() {
  let initials = card_badge.generate_initials("Auth Login Flow")
  initials |> should.equal("AL")
}

pub fn generate_initials_single_char_test() {
  let initials = card_badge.generate_initials("X")
  initials |> should.equal("X")
}

pub fn generate_initials_empty_test() {
  // Empty string returns "??" fallback
  let initials = card_badge.generate_initials("")
  initials |> should.equal("??")
}

pub fn generate_initials_lowercase_test() {
  let initials = card_badge.generate_initials("test card")
  initials |> should.equal("TC")
}

// =============================================================================
// Color Picker Tests (AC2, AC7)
// =============================================================================

pub fn all_colors_has_8_colors_test() {
  let colors = color_picker.all_colors
  list.length(colors) |> should.equal(8)
}

pub fn color_to_string_gray_test() {
  color_picker.color_to_string(color_picker.Gray) |> should.equal("gray")
}

pub fn color_to_string_red_test() {
  color_picker.color_to_string(color_picker.Red) |> should.equal("red")
}

pub fn color_to_string_blue_test() {
  color_picker.color_to_string(color_picker.Blue) |> should.equal("blue")
}

pub fn string_to_color_gray_test() {
  color_picker.string_to_color("gray")
  |> should.equal(option.Some(color_picker.Gray))
}

pub fn string_to_color_red_test() {
  color_picker.string_to_color("red")
  |> should.equal(option.Some(color_picker.Red))
}

pub fn string_to_color_invalid_test() {
  color_picker.string_to_color("invalid")
  |> should.equal(option.None)
}

pub fn string_to_color_empty_test() {
  color_picker.string_to_color("")
  |> should.equal(option.None)
}

pub fn border_class_gray_test() {
  color_picker.border_class(option.Some(color_picker.Gray))
  |> should.equal("card-border-gray")
}

pub fn border_class_red_test() {
  color_picker.border_class(option.Some(color_picker.Red))
  |> should.equal("card-border-red")
}

pub fn border_class_none_test() {
  color_picker.border_class(option.None)
  |> should.equal("")
}

pub fn initials_class_blue_test() {
  color_picker.initials_class(option.Some(color_picker.Blue))
  |> should.equal("card-initials-blue")
}

pub fn initials_class_none_test() {
  color_picker.initials_class(option.None)
  |> should.equal("card-initials-none")
}

// =============================================================================
// Card State Derivation Tests
// =============================================================================

pub fn derive_state_no_tasks_pendiente_test() {
  card.derive_state(0, 0, 0) |> should.equal(Pendiente)
}

pub fn derive_state_all_completed_cerrada_test() {
  card.derive_state(3, 3, 0) |> should.equal(Cerrada)
}

pub fn derive_state_some_claimed_en_curso_test() {
  // 3 tasks, 1 completed, 1 available (means 1 claimed/ongoing)
  card.derive_state(3, 1, 1) |> should.equal(EnCurso)
}

pub fn derive_state_all_available_pendiente_test() {
  // 3 tasks, 0 completed, 3 available
  card.derive_state(3, 0, 3) |> should.equal(Pendiente)
}

pub fn derive_state_one_completed_en_curso_test() {
  // 5 tasks, 1 completed, 2 available (means 2 claimed/ongoing)
  card.derive_state(5, 1, 2) |> should.equal(EnCurso)
}

// =============================================================================
// Card State String Conversion Tests
// =============================================================================

pub fn state_to_string_pendiente_test() {
  card.state_to_string(Pendiente) |> should.equal("pendiente")
}

pub fn state_to_string_en_curso_test() {
  card.state_to_string(EnCurso) |> should.equal("en_curso")
}

pub fn state_to_string_cerrada_test() {
  card.state_to_string(Cerrada) |> should.equal("cerrada")
}

pub fn state_from_string_pendiente_test() {
  card.state_from_string("pendiente") |> should.equal(Pendiente)
}

pub fn state_from_string_en_curso_test() {
  card.state_from_string("en_curso") |> should.equal(EnCurso)
}

pub fn state_from_string_cerrada_test() {
  card.state_from_string("cerrada") |> should.equal(Cerrada)
}

pub fn state_from_string_invalid_defaults_pendiente_test() {
  card.state_from_string("invalid") |> should.equal(Pendiente)
}
