//// Pure state transitions for the task creation dialog.

import gleam/int
import gleam/option as opt

import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/tasks/create_form

pub fn open(model: member_pool.Model) -> member_pool.Model {
  member_pool.Model(
    ..model,
    member_create_dialog_mode: dialog_mode.DialogCreate,
    member_create_error: opt.None,
    member_create_card_id: opt.None,
    member_create_card_query: "",
  )
}

pub fn open_with_card(
  model: member_pool.Model,
  card_id: Int,
) -> member_pool.Model {
  member_pool.Model(
    ..model,
    member_create_dialog_mode: dialog_mode.DialogCreate,
    member_create_error: opt.None,
    member_create_card_id: opt.Some(card_id),
    member_create_card_query: "",
  )
}

pub fn open_for_context(
  model: member_pool.Model,
  card_id: opt.Option(Int),
) -> member_pool.Model {
  case card_id {
    opt.Some(card_id) -> open_with_card(model, card_id)
    opt.None -> open(model)
  }
}

pub fn close(model: member_pool.Model) -> member_pool.Model {
  member_pool.Model(
    ..model,
    member_create_dialog_mode: dialog_mode.DialogClosed,
    member_create_error: opt.None,
    member_create_card_id: opt.None,
    member_create_card_query: "",
  )
}

pub fn title_changed(
  model: member_pool.Model,
  value: String,
) -> member_pool.Model {
  member_pool.Model(..model, member_create_title: value)
}

pub fn description_changed(
  model: member_pool.Model,
  value: String,
) -> member_pool.Model {
  member_pool.Model(..model, member_create_description: value)
}

pub fn priority_changed(
  model: member_pool.Model,
  value: String,
) -> member_pool.Model {
  member_pool.Model(..model, member_create_priority: value)
}

pub fn type_id_changed(
  model: member_pool.Model,
  value: String,
) -> member_pool.Model {
  member_pool.Model(..model, member_create_type_id: value)
}

pub fn card_id_changed(
  model: member_pool.Model,
  value: String,
) -> member_pool.Model {
  member_pool.Model(
    ..model,
    member_create_card_id: parse_card_id(value),
    member_create_card_query: "",
    member_create_error: opt.None,
  )
}

pub fn card_query_changed(
  model: member_pool.Model,
  value: String,
) -> member_pool.Model {
  member_pool.Model(
    ..model,
    member_create_card_id: opt.None,
    member_create_card_query: value,
    member_create_error: opt.None,
  )
}

pub fn input(
  model: member_pool.Model,
  selected_project_id: opt.Option(Int),
) -> create_form.Input {
  create_form.Input(
    selected_project_id: selected_project_id,
    title: model.member_create_title,
    description: model.member_create_description,
    type_id: model.member_create_type_id,
    priority: model.member_create_priority,
    card_id: model.member_create_card_id,
  )
}

pub fn submit_invalid(
  model: member_pool.Model,
  message: String,
) -> member_pool.Model {
  member_pool.Model(..model, member_create_error: opt.Some(message))
}

pub fn submit_ready(model: member_pool.Model) -> member_pool.Model {
  member_pool.Model(
    ..model,
    member_create_in_flight: True,
    member_create_error: opt.None,
  )
}

pub fn created(model: member_pool.Model) -> member_pool.Model {
  member_pool.Model(
    ..model,
    member_create_in_flight: False,
    member_create_dialog_mode: dialog_mode.DialogClosed,
    member_create_title: "",
    member_create_description: "",
    member_create_priority: "3",
    member_create_type_id: "",
    member_create_card_id: opt.None,
    member_create_card_query: "",
  )
}

pub fn create_failed(
  model: member_pool.Model,
  message: String,
) -> member_pool.Model {
  member_pool.Model(
    ..model,
    member_create_in_flight: False,
    member_create_error: opt.Some(message),
  )
}

fn parse_card_id(value: String) -> opt.Option(Int) {
  case int.parse(value) {
    Ok(id) if id > 0 -> opt.Some(id)
    _ -> opt.None
  }
}
