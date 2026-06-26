//// Expansion state for capability board task previews.

import gleam/dict.{type Dict}
import gleam/int
import gleam/option as opt

pub type Key =
  String

pub type State =
  Dict(Key, Bool)

pub fn new() -> State {
  dict.new()
}

pub fn from_list(items: List(#(Key, Bool))) -> State {
  dict.from_list(items)
}

pub fn key(card_id: Int, column_key: String) -> Key {
  int.to_string(card_id) <> "-" <> column_key
}

pub fn is_expanded(state: State, key: Key) -> Bool {
  dict.get(state, key)
  |> opt.from_result
  |> opt.unwrap(False)
}

pub fn toggle(state: State, key: Key) -> State {
  dict.insert(state, key, !is_expanded(state, key))
}
