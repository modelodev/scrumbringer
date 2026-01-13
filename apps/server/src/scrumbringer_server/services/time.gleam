import birl
import gleam/erlang/atom

pub fn now_unix_seconds() -> Int {
  system_time(atom.create("second"))
}

@external(erlang, "erlang", "system_time")
fn system_time(unit: atom.Atom) -> Int

pub fn now_iso8601() -> String {
  birl.utc_now()
  |> birl.to_iso8601
}
