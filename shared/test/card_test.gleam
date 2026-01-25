import domain/card
import gleeunit/should

// =============================================================================
// State Derivation Tests
// =============================================================================

pub fn derive_state_pendiente_when_no_tasks_test() {
  // task_count=0, completed_count=0, available_count=0
  card.derive_state(0, 0, 0)
  |> should.equal(card.Pendiente)
}

pub fn derive_state_pendiente_when_all_tasks_available_test() {
  // task_count=3, completed_count=0, available_count=3
  card.derive_state(3, 0, 3)
  |> should.equal(card.Pendiente)
}

pub fn derive_state_en_curso_when_task_in_progress_test() {
  // 3 tasks: 1 completed, 1 available, 1 claimed (in progress)
  // task_count=3, completed_count=1, available_count=1
  card.derive_state(3, 1, 1)
  |> should.equal(card.EnCurso)
}

pub fn derive_state_en_curso_when_some_completed_and_some_available_test() {
  // 4 tasks: 2 completed, 2 available (no in-progress but work started)
  // task_count=4, completed_count=2, available_count=2
  card.derive_state(4, 2, 2)
  |> should.equal(card.EnCurso)
}

pub fn derive_state_cerrada_when_all_completed_test() {
  // task_count=3, completed_count=3, available_count=0
  card.derive_state(3, 3, 0)
  |> should.equal(card.Cerrada)
}

pub fn derive_state_cerrada_when_single_task_completed_test() {
  // task_count=1, completed_count=1, available_count=0
  card.derive_state(1, 1, 0)
  |> should.equal(card.Cerrada)
}

// =============================================================================
// State String Conversion Tests
// =============================================================================

pub fn state_to_string_test() {
  card.state_to_string(card.Pendiente)
  |> should.equal("pendiente")

  card.state_to_string(card.EnCurso)
  |> should.equal("en_curso")

  card.state_to_string(card.Cerrada)
  |> should.equal("cerrada")
}

pub fn state_from_string_test() {
  card.state_from_string("pendiente")
  |> should.equal(card.Pendiente)

  card.state_from_string("en_curso")
  |> should.equal(card.EnCurso)

  card.state_from_string("cerrada")
  |> should.equal(card.Cerrada)
}

pub fn state_from_string_unknown_defaults_to_pendiente_test() {
  card.state_from_string("invalid")
  |> should.equal(card.Pendiente)

  card.state_from_string("")
  |> should.equal(card.Pendiente)
}
