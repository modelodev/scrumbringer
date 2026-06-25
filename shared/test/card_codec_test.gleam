import gleam/json
import gleam/option

import domain/card.{Card}
import domain/card/card_codec as codec

pub fn card_decoder_decodes_valid_color_test() {
  let body =
    "{\"id\":1,\"project_id\":2,\"parent_card_id\":null,\"title\":\"Discovery\",\"description\":\"Scope\",\"color\":\"blue\",\"state\":\"pendiente\",\"task_count\":3,\"completed_count\":1,\"created_by\":42,\"created_at\":\"2026-01-28T12:00:00Z\",\"has_new_notes\":true}"

  let assert Ok(Card(
    id: 1,
    project_id: 2,
    parent_card_id: option.None,
    title: "Discovery",
    description: "Scope",
    color: option.Some(card.Blue),
    state: card.Draft,
    task_count: 3,
    completed_count: 1,
    created_by: 42,
    created_at: "2026-01-28T12:00:00Z",
    due_date: option.None,
    has_new_notes: True,
  )) = json.parse(body, codec.card_decoder())
}

pub fn card_due_date_roundtrip_test() {
  let body =
    "{\"id\":1,\"project_id\":2,\"parent_card_id\":null,\"title\":\"Discovery\",\"description\":\"Scope\",\"color\":\"blue\",\"state\":\"en_curso\",\"task_count\":3,\"completed_count\":1,\"created_by\":42,\"created_at\":\"2026-01-28T12:00:00Z\",\"due_date\":\"2026-06-20\",\"has_new_notes\":true}"

  let assert Ok(Card(
    id: 1,
    project_id: 2,
    parent_card_id: option.None,
    title: "Discovery",
    description: "Scope",
    color: option.Some(card.Blue),
    state: card.Active,
    task_count: 3,
    completed_count: 1,
    created_by: 42,
    created_at: "2026-01-28T12:00:00Z",
    due_date: option.Some("2026-06-20"),
    has_new_notes: True,
  )) = json.parse(body, codec.card_decoder())
}

pub fn card_decoder_rejects_invalid_due_date_test() {
  let body =
    "{\"id\":1,\"project_id\":2,\"parent_card_id\":null,\"title\":\"Discovery\",\"description\":\"Scope\",\"color\":\"blue\",\"state\":\"en_curso\",\"task_count\":3,\"completed_count\":1,\"created_by\":42,\"created_at\":\"2026-01-28T12:00:00Z\",\"due_date\":\"2026-02-31\",\"has_new_notes\":true}"

  let assert Error(_) = json.parse(body, codec.card_decoder())
}

pub fn card_decoder_treats_empty_color_as_absent_test() {
  let body =
    "{\"id\":1,\"project_id\":2,\"parent_card_id\":null,\"title\":\"Discovery\",\"description\":\"Scope\",\"color\":\"\",\"state\":\"pendiente\",\"task_count\":3,\"completed_count\":1,\"created_by\":42,\"created_at\":\"2026-01-28T12:00:00Z\"}"

  let assert Ok(Card(color: option.None, has_new_notes: False, ..)) =
    json.parse(body, codec.card_decoder())
}

pub fn card_decoder_treats_null_color_as_absent_test() {
  let body =
    "{\"id\":1,\"project_id\":2,\"parent_card_id\":null,\"title\":\"Discovery\",\"description\":\"Scope\",\"color\":null,\"state\":\"pendiente\",\"task_count\":3,\"completed_count\":1,\"created_by\":42,\"created_at\":\"2026-01-28T12:00:00Z\"}"

  let assert Ok(Card(color: option.None, ..)) =
    json.parse(body, codec.card_decoder())
}

pub fn card_decoder_uses_parent_card_id_for_tree_parent_test() {
  let body =
    "{\"id\":1,\"project_id\":2,\"parent_card_id\":9,\"title\":\"Discovery\",\"description\":\"Scope\",\"color\":null,\"state\":\"pendiente\",\"task_count\":3,\"completed_count\":1,\"created_by\":42,\"created_at\":\"2026-01-28T12:00:00Z\"}"

  let assert Ok(Card(parent_card_id: option.Some(9), ..)) =
    json.parse(body, codec.card_decoder())
}

pub fn card_decoder_rejects_invalid_color_test() {
  let body =
    "{\"id\":1,\"project_id\":2,\"parent_card_id\":null,\"title\":\"Discovery\",\"description\":\"Scope\",\"color\":\"cyan\",\"state\":\"pendiente\",\"task_count\":3,\"completed_count\":1,\"created_by\":42,\"created_at\":\"2026-01-28T12:00:00Z\"}"

  let assert Error(_) = json.parse(body, codec.card_decoder())
}
