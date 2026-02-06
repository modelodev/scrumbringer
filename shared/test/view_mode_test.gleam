import domain/view_mode.{Cards, List, People, Pool}
import gleeunit/should

// =============================================================================
// from_string tests
// =============================================================================

pub fn from_string_pool_test() {
  view_mode.from_string("pool")
  |> should.equal(Pool)
}

pub fn from_string_list_test() {
  view_mode.from_string("list")
  |> should.equal(List)
}

pub fn from_string_cards_test() {
  view_mode.from_string("cards")
  |> should.equal(Cards)
}

pub fn from_string_people_test() {
  view_mode.from_string("people")
  |> should.equal(People)
}

pub fn from_string_unknown_defaults_to_pool_test() {
  view_mode.from_string("unknown")
  |> should.equal(Pool)
}

pub fn from_string_empty_defaults_to_pool_test() {
  view_mode.from_string("")
  |> should.equal(Pool)
}

// =============================================================================
// to_string tests
// =============================================================================

pub fn to_string_pool_test() {
  view_mode.to_string(Pool)
  |> should.equal("pool")
}

pub fn to_string_list_test() {
  view_mode.to_string(List)
  |> should.equal("list")
}

pub fn to_string_cards_test() {
  view_mode.to_string(Cards)
  |> should.equal("cards")
}

pub fn to_string_people_test() {
  view_mode.to_string(People)
  |> should.equal("people")
}

// =============================================================================
// roundtrip tests
// =============================================================================

pub fn roundtrip_pool_test() {
  Pool
  |> view_mode.to_string
  |> view_mode.from_string
  |> should.equal(Pool)
}

pub fn roundtrip_list_test() {
  List
  |> view_mode.to_string
  |> view_mode.from_string
  |> should.equal(List)
}

pub fn roundtrip_cards_test() {
  Cards
  |> view_mode.to_string
  |> view_mode.from_string
  |> should.equal(Cards)
}

pub fn roundtrip_people_test() {
  People
  |> view_mode.to_string
  |> view_mode.from_string
  |> should.equal(People)
}

// =============================================================================
// supports_drag_drop tests
// =============================================================================

pub fn pool_supports_drag_drop_test() {
  view_mode.supports_drag_drop(Pool)
  |> should.be_true
}

pub fn list_does_not_support_drag_drop_test() {
  view_mode.supports_drag_drop(List)
  |> should.be_false
}

pub fn cards_supports_drag_drop_test() {
  view_mode.supports_drag_drop(Cards)
  |> should.be_true
}

pub fn people_does_not_support_drag_drop_test() {
  view_mode.supports_drag_drop(People)
  |> should.be_false
}

// =============================================================================
// label_key tests
// =============================================================================

pub fn label_key_pool_test() {
  view_mode.label_key(Pool)
  |> should.equal("ViewModePool")
}

pub fn label_key_list_test() {
  view_mode.label_key(List)
  |> should.equal("ViewModeList")
}

pub fn label_key_cards_test() {
  view_mode.label_key(Cards)
  |> should.equal("ViewModeCards")
}

pub fn label_key_people_test() {
  view_mode.label_key(People)
  |> should.equal("ViewModePeople")
}
