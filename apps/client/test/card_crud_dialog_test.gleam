//// Tests for card_crud_dialog Lustre component.
////
//// Tests Model construction, Msg type constructors, and DialogMode type.

import gleeunit/should

import scrumbringer_client/components/card_crud_dialog.{
  type CardColor, type DialogMode, type Model, type Msg, Blue, CreateColorChanged,
  CreateColorToggle, CreateDescriptionChanged, CreateResult, CreateSubmitted,
  CreateTitleChanged, DeleteCancelled, DeleteConfirmed, DeleteResult,
  EditCancelled, EditColorChanged, EditColorToggle, EditDescriptionChanged,
  EditResult, EditSubmitted, EditTitleChanged, Gray, Green, LocaleReceived,
  ModeCreate, ModeDelete, ModeEdit, ModeReceived, Model, Orange, Pink,
  ProjectIdReceived, Purple, Red, Yellow,
}
import scrumbringer_client/i18n/locale.{En, Es}
import gleam/option

// =============================================================================
// Model Tests
// =============================================================================

pub fn model_default_values_test() {
  // Test that default model has expected initial values
  let model =
    Model(
      locale: En,
      project_id: option.None,
      mode: option.None,
      create_title: "",
      create_description: "",
      create_color: option.None,
      create_color_open: False,
      create_in_flight: False,
      create_error: option.None,
      edit_title: "",
      edit_description: "",
      edit_color: option.None,
      edit_color_open: False,
      edit_in_flight: False,
      edit_error: option.None,
      delete_in_flight: False,
      delete_error: option.None,
    )

  model.locale |> should.equal(En)
  model.project_id |> should.equal(option.None)
  model.mode |> should.equal(option.None)
  model.create_title |> should.equal("")
  model.create_in_flight |> should.equal(False)
}

pub fn model_with_spanish_locale_test() {
  let model =
    Model(
      locale: Es,
      project_id: option.Some(42),
      mode: option.Some(ModeCreate),
      create_title: "Mi Ficha",
      create_description: "Descripción",
      create_color: option.Some("blue"),
      create_color_open: True,
      create_in_flight: False,
      create_error: option.None,
      edit_title: "",
      edit_description: "",
      edit_color: option.None,
      edit_color_open: False,
      edit_in_flight: False,
      edit_error: option.None,
      delete_in_flight: False,
      delete_error: option.None,
    )

  model.locale |> should.equal(Es)
  model.project_id |> should.equal(option.Some(42))
  model.create_title |> should.equal("Mi Ficha")
  model.create_color |> should.equal(option.Some("blue"))
  model.create_color_open |> should.equal(True)
}

// =============================================================================
// DialogMode Type Tests
// =============================================================================

pub fn dialog_mode_create_test() {
  let mode = ModeCreate
  case mode {
    ModeCreate -> should.be_true(True)
    _ -> should.fail()
  }
}

pub fn dialog_mode_edit_test() {
  let card = make_test_card()
  let mode = ModeEdit(card)
  case mode {
    ModeEdit(c) -> c.id |> should.equal(1)
    _ -> should.fail()
  }
}

pub fn dialog_mode_delete_test() {
  let card = make_test_card()
  let mode = ModeDelete(card)
  case mode {
    ModeDelete(c) -> c.title |> should.equal("Test Card")
    _ -> should.fail()
  }
}

// =============================================================================
// Msg Type Tests
// =============================================================================

pub fn msg_locale_received_test() {
  let msg = LocaleReceived(Es)
  case msg {
    LocaleReceived(loc) -> loc |> should.equal(Es)
    _ -> should.fail()
  }
}

pub fn msg_project_id_received_test() {
  let msg = ProjectIdReceived(123)
  case msg {
    ProjectIdReceived(id) -> id |> should.equal(123)
    _ -> should.fail()
  }
}

pub fn msg_mode_received_test() {
  let msg = ModeReceived(ModeCreate)
  case msg {
    ModeReceived(mode) ->
      case mode {
        ModeCreate -> should.be_true(True)
        _ -> should.fail()
      }
    _ -> should.fail()
  }
}

pub fn msg_create_title_changed_test() {
  let msg = CreateTitleChanged("New Title")
  case msg {
    CreateTitleChanged(title) -> title |> should.equal("New Title")
    _ -> should.fail()
  }
}

pub fn msg_create_description_changed_test() {
  let msg = CreateDescriptionChanged("New Description")
  case msg {
    CreateDescriptionChanged(desc) -> desc |> should.equal("New Description")
    _ -> should.fail()
  }
}

pub fn msg_create_color_toggle_test() {
  let msg = CreateColorToggle
  case msg {
    CreateColorToggle -> should.be_true(True)
    _ -> should.fail()
  }
}

pub fn msg_create_color_changed_test() {
  let msg = CreateColorChanged(option.Some("red"))
  case msg {
    CreateColorChanged(color) -> color |> should.equal(option.Some("red"))
    _ -> should.fail()
  }
}

pub fn msg_create_submitted_test() {
  let msg = CreateSubmitted
  case msg {
    CreateSubmitted -> should.be_true(True)
    _ -> should.fail()
  }
}

pub fn msg_edit_title_changed_test() {
  let msg = EditTitleChanged("Updated Title")
  case msg {
    EditTitleChanged(title) -> title |> should.equal("Updated Title")
    _ -> should.fail()
  }
}

pub fn msg_edit_cancelled_test() {
  let msg = EditCancelled
  case msg {
    EditCancelled -> should.be_true(True)
    _ -> should.fail()
  }
}

pub fn msg_delete_confirmed_test() {
  let msg = DeleteConfirmed
  case msg {
    DeleteConfirmed -> should.be_true(True)
    _ -> should.fail()
  }
}

pub fn msg_delete_cancelled_test() {
  let msg = DeleteCancelled
  case msg {
    DeleteCancelled -> should.be_true(True)
    _ -> should.fail()
  }
}

// =============================================================================
// CardColor Type Tests
// =============================================================================

pub fn card_color_all_variants_test() {
  // Test all color variants exist and can be constructed
  let colors = [Gray, Red, Orange, Yellow, Green, Blue, Purple, Pink]
  colors
  |> should.not_equal([])
}

pub fn card_color_gray_test() {
  let color: CardColor = Gray
  case color {
    Gray -> should.be_true(True)
    _ -> should.fail()
  }
}

pub fn card_color_red_test() {
  let color: CardColor = Red
  case color {
    Red -> should.be_true(True)
    _ -> should.fail()
  }
}

pub fn card_color_blue_test() {
  let color: CardColor = Blue
  case color {
    Blue -> should.be_true(True)
    _ -> should.fail()
  }
}

// =============================================================================
// Helpers
// =============================================================================

import domain/card.{type Card, Card, Pendiente}

fn make_test_card() -> Card {
  Card(
    id: 1,
    project_id: 10,
    title: "Test Card",
    description: "Test Description",
    color: option.Some("blue"),
    state: Pendiente,
    task_count: 5,
    completed_count: 2,
    created_by: 1,
    created_at: "2026-01-20T00:00:00Z",
  )
}
