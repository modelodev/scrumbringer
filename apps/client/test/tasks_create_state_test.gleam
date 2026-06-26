import gleam/option.{None, Some}

import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/tasks/create_state

pub fn create_state_open_resets_dialog_context_test() {
  let model =
    member_pool.Model(
      ..member_pool.default_model(),
      member_create_error: Some("boom"),
      member_create_card_id: Some(7),
    )

  let next = create_state.open(model)

  let assert dialog_mode.DialogCreate = next.member_create_dialog_mode
  let assert None = next.member_create_error
  let assert None = next.member_create_card_id
}

pub fn create_state_open_with_card_keeps_card_context_test() {
  let next = create_state.open_with_card(member_pool.default_model(), 42)

  let assert dialog_mode.DialogCreate = next.member_create_dialog_mode
  let assert Some(42) = next.member_create_card_id
  let assert None = next.member_create_error
}

pub fn create_state_open_for_context_uses_optional_card_test() {
  let dirty =
    member_pool.Model(
      ..member_pool.default_model(),
      member_create_error: Some("boom"),
      member_create_card_id: Some(7),
      member_create_card_query: "old query",
    )

  let global = create_state.open_for_context(dirty, None)
  let assert dialog_mode.DialogCreate = global.member_create_dialog_mode
  let assert None = global.member_create_error
  let assert None = global.member_create_card_id
  let assert "" = global.member_create_card_query

  let contextual = create_state.open_for_context(dirty, Some(42))
  let assert dialog_mode.DialogCreate = contextual.member_create_dialog_mode
  let assert None = contextual.member_create_error
  let assert Some(42) = contextual.member_create_card_id
  let assert "" = contextual.member_create_card_query
}

pub fn create_state_field_changes_update_only_form_fields_test() {
  let model =
    member_pool.Model(
      ..member_pool.default_model(),
      member_create_card_id: Some(7),
    )
    |> create_state.title_changed("Ship task")
    |> create_state.description_changed("Useful detail")
    |> create_state.priority_changed("5")
    |> create_state.type_id_changed("8")

  let assert "Ship task" = model.member_create_title
  let assert "Useful detail" = model.member_create_description
  let assert "5" = model.member_create_priority
  let assert "8" = model.member_create_type_id
  let assert Some(7) = model.member_create_card_id
}

pub fn create_state_input_reads_form_and_selected_project_test() {
  let model =
    member_pool.Model(
      ..member_pool.default_model(),
      member_create_title: " Ship task ",
      member_create_description: " Useful detail ",
      member_create_priority: "5",
      member_create_type_id: "8",
      member_create_card_id: Some(7),
    )

  let input = create_state.input(model, Some(1))

  let assert Some(1) = input.selected_project_id
  let assert " Ship task " = input.title
  let assert " Useful detail " = input.description
  let assert "5" = input.priority
  let assert "8" = input.type_id
  let assert Some(7) = input.card_id
}

pub fn create_state_submit_and_result_transitions_test() {
  let ready =
    member_pool.default_model()
    |> create_state.submit_invalid("Title required")
    |> create_state.submit_ready

  let assert True = ready.member_create_in_flight
  let assert None = ready.member_create_error

  let failed = create_state.create_failed(ready, "boom")
  let assert False = failed.member_create_in_flight
  let assert Some("boom") = failed.member_create_error

  let created =
    member_pool.Model(
      ..failed,
      member_create_dialog_mode: dialog_mode.DialogCreate,
      member_create_title: "Ship task",
      member_create_description: "Useful detail",
      member_create_priority: "5",
      member_create_type_id: "8",
      member_create_card_id: Some(7),
      member_create_in_flight: True,
    )
    |> create_state.created

  let assert dialog_mode.DialogClosed = created.member_create_dialog_mode
  let assert False = created.member_create_in_flight
  let assert "" = created.member_create_title
  let assert "" = created.member_create_description
  let assert "3" = created.member_create_priority
  let assert "" = created.member_create_type_id
  let assert None = created.member_create_card_id
}
