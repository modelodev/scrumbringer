import domain/view_mode.{Capabilities, Cards, People, Pool}
import gleam/list

// =============================================================================
// parse tests
// =============================================================================

pub fn parse_pool_test() {
  let assert Ok(Pool) = view_mode.parse("pool")
}

pub fn parse_legacy_tracking_rejects_value_test() {
  let legacy = "card_" <> "trees"
  let assert Error(view_mode.UnknownViewMode(_)) = view_mode.parse(legacy)
}

pub fn parse_cards_test() {
  let assert Ok(Cards) = view_mode.parse("cards")
}

pub fn parse_capabilities_test() {
  let assert Ok(Capabilities) = view_mode.parse("capabilities")
}

pub fn parse_people_test() {
  let assert Ok(People) = view_mode.parse("people")
}

pub fn parse_unknown_rejects_value_test() {
  let assert Error(view_mode.UnknownViewMode("unknown")) =
    view_mode.parse("unknown")
}

// =============================================================================
// to_string tests
// =============================================================================

pub fn to_string_pool_test() {
  let assert "pool" = view_mode.to_string(Pool)
}

pub fn to_string_cards_test() {
  let assert "cards" = view_mode.to_string(Cards)
}

pub fn to_string_capabilities_test() {
  let assert "capabilities" = view_mode.to_string(Capabilities)
}

pub fn to_string_people_test() {
  let assert "people" = view_mode.to_string(People)
}

pub fn to_string_never_emits_list_test() {
  [Pool, Cards, Capabilities, People]
  |> list.each(fn(mode) {
    let assert False = view_mode.to_string(mode) == "list"
  })
}

// =============================================================================
// roundtrip tests
// =============================================================================

pub fn roundtrip_pool_test() {
  let assert Ok(Pool) =
    Pool
    |> view_mode.to_string
    |> view_mode.parse
}

pub fn roundtrip_cards_test() {
  let assert Ok(Cards) =
    Cards
    |> view_mode.to_string
    |> view_mode.parse
}

pub fn roundtrip_capabilities_test() {
  let assert Ok(Capabilities) =
    Capabilities
    |> view_mode.to_string
    |> view_mode.parse
}

pub fn roundtrip_people_test() {
  let assert Ok(People) =
    People
    |> view_mode.to_string
    |> view_mode.parse
}

// =============================================================================
// supports_drag_drop tests
// =============================================================================

pub fn pool_supports_drag_drop_test() {
  let assert True = view_mode.supports_drag_drop(Pool)
}

pub fn cards_does_not_support_drag_drop_test() {
  let assert False = view_mode.supports_drag_drop(Cards)
}

pub fn people_does_not_support_drag_drop_test() {
  let assert False = view_mode.supports_drag_drop(People)
}

pub fn capabilities_does_not_support_drag_drop_test() {
  let assert False = view_mode.supports_drag_drop(Capabilities)
}

// =============================================================================
// label_key tests
// =============================================================================

pub fn label_key_pool_test() {
  let assert "ViewModePool" = view_mode.label_key(Pool)
}

pub fn label_key_cards_test() {
  let assert "ViewModeCards" = view_mode.label_key(Cards)
}

pub fn label_key_capabilities_test() {
  let assert "ViewModeCapabilities" = view_mode.label_key(Capabilities)
}

pub fn label_key_people_test() {
  let assert "ViewModePeople" = view_mode.label_key(People)
}
