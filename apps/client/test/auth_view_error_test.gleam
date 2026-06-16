import gleam/option as opt
import gleam/string
import lustre/element
import scrumbringer_client/client_state/auth as auth_state
import scrumbringer_client/features/auth/view as auth_view
import scrumbringer_client/i18n/locale
import scrumbringer_client/token_flow

fn assert_contains(html: String, text: String) {
  let assert True = string.contains(html, text)
}

fn assert_not_contains(html: String, text: String) {
  let assert False = string.contains(html, text)
}

fn config(auth: auth_state.AuthModel) -> auth_view.Config(String) {
  auth_view.Config(
    locale: locale.En,
    auth: auth,
    origin: "https://scrumbringer.test",
    on_login_email_changed: fn(value) { "login-email:" <> value },
    on_login_password_changed: fn(value) { "login-password:" <> value },
    on_login_submitted: "login-submit",
    on_forgot_password_clicked: "forgot-open",
    on_forgot_password_email_changed: fn(value) { "forgot-email:" <> value },
    on_forgot_password_submitted: "forgot-submit",
    on_forgot_password_copy_clicked: "forgot-copy",
    on_forgot_password_dismissed: "forgot-dismiss",
    on_accept_invite: fn(_msg) { "accept-invite" },
    on_reset_password: fn(_msg) { "reset-password" },
  )
}

pub fn login_error_renders_error_banner_test() {
  let auth =
    auth_state.AuthModel(
      ..auth_state.default_model(),
      login_error: opt.Some("Bad creds"),
    )

  let html = auth_view.view_login(config(auth)) |> element.to_document_string

  assert_contains(html, "error-banner")
  assert_contains(html, "Bad creds")
}

pub fn login_in_flight_adds_loading_class_test() {
  let auth =
    auth_state.AuthModel(..auth_state.default_model(), login_in_flight: True)

  let html = auth_view.view_login(config(auth)) |> element.to_document_string

  assert_contains(html, "btn-loading")
  assert_contains(html, "btn-primary")
  assert_contains(html, "btn-global-action")
  assert_contains(html, "type=\"submit\"")
}

pub fn forgot_password_trigger_uses_semantic_button_test() {
  let auth = auth_state.default_model()

  let html = auth_view.view_login(config(auth)) |> element.to_document_string

  assert_contains(html, "Forgot password?")
  assert_contains(html, "auth-forgot")
  assert_contains(html, "btn-ghost")
  assert_contains(html, "btn-view-action")
  assert_contains(html, "type=\"button\"")
  assert_not_contains(html, "class=\"auth-forgot\"")
}

pub fn forgot_password_error_renders_error_block_test() {
  let auth =
    auth_state.AuthModel(
      ..auth_state.default_model(),
      forgot_password_open: True,
      forgot_password_error: opt.Some("Email not found"),
    )

  let html = auth_view.view_login(config(auth)) |> element.to_document_string

  assert_contains(html, "class=\"error\"")
  assert_contains(html, "Email not found")
}

pub fn forgot_password_submit_uses_semantic_button_test() {
  let auth =
    auth_state.AuthModel(
      ..auth_state.default_model(),
      forgot_password_open: True,
      forgot_password_in_flight: True,
    )

  let html = auth_view.view_login(config(auth)) |> element.to_document_string

  assert_contains(html, "Working")
  assert_contains(html, "btn-primary")
  assert_contains(html, "btn-global-action")
  assert_contains(html, "btn-loading")
  assert_contains(html, "type=\"submit\"")
}

pub fn accept_invite_submit_uses_semantic_button_test() {
  let auth =
    auth_state.AuthModel(
      ..auth_state.default_model(),
      accept_invite: token_flow.Model(
        token: "invite-token",
        state: token_flow.Ready("member@example.com"),
        password: "",
        password_error: opt.None,
        submit_error: opt.None,
      ),
    )

  let html =
    auth_view.view_accept_invite(config(auth)) |> element.to_document_string

  assert_contains(html, "Register")
  assert_contains(html, "btn-primary")
  assert_contains(html, "btn-global-action")
  assert_contains(html, "type=\"submit\"")
}

pub fn reset_password_submit_uses_semantic_button_test() {
  let auth =
    auth_state.AuthModel(
      ..auth_state.default_model(),
      reset_password: token_flow.Model(
        token: "reset-token",
        state: token_flow.Ready("member@example.com"),
        password: "",
        password_error: opt.None,
        submit_error: opt.None,
      ),
    )

  let html =
    auth_view.view_reset_password(config(auth)) |> element.to_document_string

  assert_contains(html, "Save new password")
  assert_contains(html, "btn-primary")
  assert_contains(html, "btn-global-action")
  assert_contains(html, "type=\"submit\"")
}
