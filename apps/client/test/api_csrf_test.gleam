import gleam/option
import gleeunit/should
import scrumbringer_client/api

pub fn csrf_headers_attached_only_for_mutations_test() {
  api.should_attach_csrf("GET") |> should.equal(False)
  api.should_attach_csrf("POST") |> should.equal(True)
  api.should_attach_csrf("put") |> should.equal(True)

  api.build_csrf_headers("GET", option.Some("t")) |> should.equal([])
  api.build_csrf_headers("POST", option.None) |> should.equal([])
  api.build_csrf_headers("POST", option.Some("t"))
  |> should.equal([#("X-CSRF", "t")])
}
