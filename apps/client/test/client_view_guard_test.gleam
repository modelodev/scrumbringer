import gleam/option as opt
import gleam/string
import gleeunit/should
import lustre/element

import scrumbringer_client/client_state.{type Model, Admin, CoreModel, default_model, update_core}
import scrumbringer_client/client_view

fn base_model() -> Model {
  default_model()
}

pub fn admin_page_without_user_shows_login_test() {
  let model =
    update_core(base_model(), fn(core) {
      CoreModel(..core, page: Admin, user: opt.None)
    })

  let html = client_view.view(model) |> element.to_document_string

  string.contains(html, "login-email") |> should.be_true
}
