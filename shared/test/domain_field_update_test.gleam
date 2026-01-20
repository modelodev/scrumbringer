import domain/field_update.{type FieldUpdate, Set, Unchanged}
import gleam/option.{None, Some}
import gleeunit/should

// =============================================================================
// Constructor tests
// =============================================================================

pub fn unchanged_constructor_test() {
  field_update.unchanged()
  |> should.equal(Unchanged)
}

pub fn set_constructor_test() {
  field_update.set("hello")
  |> should.equal(Set("hello"))
}

// =============================================================================
// Conversion tests
// =============================================================================

pub fn to_option_unchanged_returns_none_test() {
  Unchanged
  |> field_update.to_option
  |> should.equal(None)
}

pub fn to_option_set_returns_some_test() {
  Set(42)
  |> field_update.to_option
  |> should.equal(Some(42))
}

pub fn from_option_none_returns_unchanged_test() {
  None
  |> field_update.from_option
  |> should.equal(Unchanged)
}

pub fn from_option_some_returns_set_test() {
  Some("value")
  |> field_update.from_option
  |> should.equal(Set("value"))
}

pub fn from_sentinel_with_sentinel_returns_unchanged_test() {
  field_update.from_sentinel("__unset__", "__unset__")
  |> should.equal(Unchanged)
}

pub fn from_sentinel_with_value_returns_set_test() {
  field_update.from_sentinel("hello", "__unset__")
  |> should.equal(Set("hello"))
}

pub fn to_sentinel_unchanged_returns_sentinel_test() {
  Unchanged
  |> field_update.to_sentinel("__unset__")
  |> should.equal("__unset__")
}

pub fn to_sentinel_set_returns_value_test() {
  Set("hello")
  |> field_update.to_sentinel("__unset__")
  |> should.equal("hello")
}

// =============================================================================
// Predicate tests
// =============================================================================

pub fn is_unchanged_returns_true_for_unchanged_test() {
  Unchanged
  |> field_update.is_unchanged
  |> should.be_true
}

pub fn is_unchanged_returns_false_for_set_test() {
  Set(1)
  |> field_update.is_unchanged
  |> should.be_false
}

pub fn is_set_returns_true_for_set_test() {
  Set("x")
  |> field_update.is_set
  |> should.be_true
}

pub fn is_set_returns_false_for_unchanged_test() {
  Unchanged
  |> field_update.is_set
  |> should.be_false
}

// =============================================================================
// Transformation tests
// =============================================================================

pub fn map_unchanged_returns_unchanged_test() {
  let field: FieldUpdate(Int) = Unchanged
  field
  |> field_update.map(fn(x) { x * 2 })
  |> should.equal(Unchanged)
}

pub fn map_set_applies_function_test() {
  Set(5)
  |> field_update.map(fn(x) { x * 2 })
  |> should.equal(Set(10))
}

pub fn unwrap_unchanged_returns_default_test() {
  Unchanged
  |> field_update.unwrap("default")
  |> should.equal("default")
}

pub fn unwrap_set_returns_value_test() {
  Set("actual")
  |> field_update.unwrap("default")
  |> should.equal("actual")
}
