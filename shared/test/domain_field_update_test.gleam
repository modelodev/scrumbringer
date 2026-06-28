import domain/field_update.{type FieldUpdate, Set, Unchanged}
import gleam/option.{None, Some}

// =============================================================================
// Constructor tests
// =============================================================================

pub fn unchanged_constructor_test() {
  let assert Unchanged = field_update.unchanged()
}

pub fn set_constructor_test() {
  let assert Set("hello") = field_update.set("hello")
}

// =============================================================================
// Conversion tests
// =============================================================================

pub fn to_option_unchanged_returns_none_test() {
  let assert None =
    Unchanged
    |> field_update.to_option
}

pub fn to_option_set_returns_some_test() {
  let assert Some(42) =
    Set(42)
    |> field_update.to_option
}

pub fn from_option_none_returns_unchanged_test() {
  let assert Unchanged =
    None
    |> field_update.from_option
}

pub fn from_option_some_returns_set_test() {
  let assert Set("value") =
    Some("value")
    |> field_update.from_option
}

pub fn from_sentinel_with_sentinel_returns_unchanged_test() {
  let assert Unchanged = field_update.from_sentinel("__unset__", "__unset__")
}

pub fn from_sentinel_with_value_returns_set_test() {
  let assert Set("hello") = field_update.from_sentinel("hello", "__unset__")
}

pub fn to_sentinel_unchanged_returns_sentinel_test() {
  let assert "__unset__" =
    Unchanged
    |> field_update.to_sentinel("__unset__")
}

pub fn to_sentinel_set_returns_value_test() {
  let assert "hello" =
    Set("hello")
    |> field_update.to_sentinel("__unset__")
}

// =============================================================================
// Transformation tests
// =============================================================================

pub fn map_unchanged_returns_unchanged_test() {
  let field: FieldUpdate(Int) = Unchanged
  let assert Unchanged =
    field
    |> field_update.map(fn(x) { x * 2 })
}

pub fn map_set_applies_function_test() {
  let assert Set(10) =
    Set(5)
    |> field_update.map(fn(x) { x * 2 })
}

pub fn unwrap_unchanged_returns_default_test() {
  let assert "default" =
    Unchanged
    |> field_update.unwrap("default")
}

pub fn unwrap_set_returns_value_test() {
  let assert "actual" =
    Set("actual")
    |> field_update.unwrap("default")
}
