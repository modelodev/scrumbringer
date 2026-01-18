import gleam/option
import gleeunit/should
import scrumbringer_client/api/core as api_core

pub fn csrf_headers_attached_only_for_mutations_test() {
  api_core.should_attach_csrf("GET") |> should.equal(False)
  api_core.should_attach_csrf("POST") |> should.equal(True)
  api_core.should_attach_csrf("put") |> should.equal(True)

  api_core.build_csrf_headers("GET", option.Some("t")) |> should.equal([])
  api_core.build_csrf_headers("POST", option.None) |> should.equal([])
  api_core.build_csrf_headers("POST", option.Some("t"))
  |> should.equal([#("X-CSRF", "t")])
}
