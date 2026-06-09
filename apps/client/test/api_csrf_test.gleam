import gleam/option
import scrumbringer_client/api/core as api_core

pub fn csrf_headers_attached_only_for_mutations_test() {
  let assert False = api_core.should_attach_csrf(api_core.Get)
  let assert True = api_core.should_attach_csrf(api_core.Post)
  let assert True = api_core.should_attach_csrf(api_core.Put)

  let assert [] = api_core.build_csrf_headers(api_core.Get, option.Some("t"))
  let assert [] = api_core.build_csrf_headers(api_core.Post, option.None)
  let assert [#("X-CSRF", "t")] =
    api_core.build_csrf_headers(api_core.Post, option.Some("t"))
}
