import gleam/option as opt
import gleam/string
import gleeunit/should
import lustre/element
import scrumbringer_client/client_state.{type Model, AuthModel, default_model, update_auth}
import scrumbringer_client/features/auth/view as auth_view

fn base_model() -> Model {
  default_model()
}

pub fn login_error_renders_error_banner_test() {
  let model =
    update_auth(base_model(), fn(auth) {
      AuthModel(..auth, login_error: opt.Some("Bad creds"))
    })

  let html = auth_view.view_login(model) |> element.to_document_string

  string.contains(html, "error-banner") |> should.be_true
  string.contains(html, "Bad creds") |> should.be_true
}

pub fn login_in_flight_adds_loading_class_test() {
  let model =
    update_auth(base_model(), fn(auth) {
      AuthModel(..auth, login_in_flight: True)
    })

  let html = auth_view.view_login(model) |> element.to_document_string

  string.contains(html, "btn-loading") |> should.be_true
}

pub fn forgot_password_error_renders_error_block_test() {
  let model =
    update_auth(base_model(), fn(auth) {
      AuthModel(
        ..auth,
        forgot_password_open: True,
        forgot_password_error: opt.Some("Email not found"),
      )
    })

  let html = auth_view.view_login(model) |> element.to_document_string

  string.contains(html, "class=\"error\"") |> should.be_true
  string.contains(html, "Email not found") |> should.be_true
}
