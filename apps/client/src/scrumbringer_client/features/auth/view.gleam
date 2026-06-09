//// Authentication views for login, invite acceptance, and password reset.
////
//// ## Mission
////
//// Renders all authentication-related UI components including login form,
//// invite acceptance flow, and password reset flow.
////
//// ## Responsibilities
////
//// - Login form with email/password fields
//// - Forgot password form and reset link display
//// - Accept invite form for new user registration
//// - Reset password form for existing users
////
//// ## Non-responsibilities
////
//// - Authentication state management (see client_state.gleam)
//// - API calls (see api/ modules)
//// - Navigation logic (see client_update.gleam)
////
//// ## Relations
////
//// - **client_view.gleam**: Main view dispatches to these functions
//// - **client_state/auth.gleam**: Provides AuthModel state
//// - **token_flow.gleam**: Provides accept invite sub-model types
//// - **token_flow.gleam**: Provides reset password sub-model types
////
//// ## Line Count Justification
////
//// This module exceeds 100 lines (~250) because it groups all auth-related
//// views which share common patterns (form fields, error display, submit buttons).
//// Splitting would fragment tightly related code without clear benefit.

import gleam/option as opt

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, form, h1, h2, input, p, text}
import lustre/event

import scrumbringer_client/accept_invite
import scrumbringer_client/client_state/auth.{type AuthModel}
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/reset_password
import scrumbringer_client/token_flow
import scrumbringer_client/ui/copyable_input
import scrumbringer_client/ui/error_notice
import scrumbringer_client/ui/form_field
import scrumbringer_client/ui/loading

pub type Config(msg) {
  Config(
    locale: Locale,
    auth: AuthModel,
    origin: String,
    on_login_email_changed: fn(String) -> msg,
    on_login_password_changed: fn(String) -> msg,
    on_login_submitted: msg,
    on_forgot_password_clicked: msg,
    on_forgot_password_email_changed: fn(String) -> msg,
    on_forgot_password_submitted: msg,
    on_forgot_password_copy_clicked: msg,
    on_forgot_password_dismissed: msg,
    on_accept_invite: fn(accept_invite.Msg) -> msg,
    on_reset_password: fn(reset_password.Msg) -> msg,
  )
}

/// Renders the login page with email/password form.
pub fn view_login(config: Config(msg)) -> Element(msg) {
  let auth = config.auth
  let t = fn(key) { i18n.t(config.locale, key) }

  let submit_label = case auth.login_in_flight {
    True -> t(i18n_text.LoggingIn)
    False -> t(i18n_text.LoginTitle)
  }

  // L01: Button class with loading state
  let btn_class = case auth.login_in_flight {
    True -> "btn-loading"
    False -> ""
  }

  div([attribute.class("page")], [
    h1([], [text(t(i18n_text.AppName))]),
    p([], [text(t(i18n_text.LoginSubtitle))]),
    // L03: Error banner with icon
    case auth.login_error {
      opt.Some(err) -> error_notice.view(err)
      opt.None -> element.none()
    },
    form([event.on_submit(fn(_) { config.on_login_submitted })], [
      form_field.view_required(
        t(i18n_text.EmailLabel),
        input([
          attribute.attribute("id", "login-email"),
          attribute.type_("email"),
          attribute.value(auth.login_email),
          event.on_input(fn(value) { config.on_login_email_changed(value) }),
          attribute.required(True),
          // L02: Autofocus on first field
          attribute.autofocus(True),
          attribute.attribute("aria-label", "Email address"),
        ]),
      ),
      form_field.view_required(
        t(i18n_text.PasswordLabel),
        input([
          attribute.attribute("id", "login-password"),
          attribute.type_("password"),
          attribute.value(auth.login_password),
          event.on_input(fn(value) { config.on_login_password_changed(value) }),
          attribute.required(True),
          attribute.attribute("aria-label", "Password"),
        ]),
      ),
      // L01: Submit button with loading class
      button(
        [
          attribute.type_("submit"),
          attribute.disabled(auth.login_in_flight),
          attribute.class(btn_class),
        ],
        [text(submit_label)],
      ),
    ]),
    button([event.on_click(config.on_forgot_password_clicked)], [
      text(t(i18n_text.ForgotPassword)),
    ]),
    case auth.forgot_password_open {
      True -> view_forgot_password(config)
      False -> element.none()
    },
  ])
}

/// Renders the forgot password form with email input and reset link display.
pub fn view_forgot_password(config: Config(msg)) -> Element(msg) {
  let auth = config.auth
  let t = fn(key) { i18n.t(config.locale, key) }

  let submit_label = case auth.forgot_password_in_flight {
    True -> t(i18n_text.Working)
    False -> t(i18n_text.GenerateResetLink)
  }

  let btn_class = case auth.forgot_password_in_flight {
    True -> "btn-loading"
    False -> ""
  }

  let link = case auth.forgot_password_result {
    opt.Some(reset) -> config.origin <> reset.url_path
    opt.None -> ""
  }

  div([attribute.class("section")], [
    p([], [text(t(i18n_text.NoEmailIntegrationNote))]),
    case auth.forgot_password_error {
      opt.Some(err) ->
        error_notice.view_dismissible(
          err,
          t(i18n_text.Dismiss),
          config.on_forgot_password_dismissed,
        )
      opt.None -> element.none()
    },
    form(
      [
        event.on_submit(fn(_) { config.on_forgot_password_submitted }),
      ],
      [
        form_field.view_required(
          t(i18n_text.EmailLabel),
          input([
            attribute.type_("email"),
            attribute.value(auth.forgot_password_email),
            event.on_input(fn(value) {
              config.on_forgot_password_email_changed(value)
            }),
            attribute.required(True),
          ]),
        ),
        button(
          [
            attribute.type_("submit"),
            attribute.disabled(auth.forgot_password_in_flight),
            attribute.class(btn_class),
          ],
          [text(submit_label)],
        ),
      ],
    ),
    case link == "" {
      True -> element.none()

      False ->
        copyable_input.view(
          t(i18n_text.ResetLink),
          link,
          config.on_forgot_password_copy_clicked,
          t(i18n_text.Copy),
          auth.forgot_password_copy_status,
        )
    },
  ])
}

/// Renders the accept invite page for new user registration.
pub fn view_accept_invite(config: Config(msg)) -> Element(msg) {
  let t = fn(key) { i18n.t(config.locale, key) }
  let token_flow.Model(
    state: state,
    password: password,
    password_error: password_error,
    submit_error: submit_error,
    ..,
  ) = config.auth.accept_invite

  let content = case state {
    token_flow.NoToken -> error_notice.view(t(i18n_text.MissingInviteToken))

    token_flow.Validating -> loading.loading(t(i18n_text.ValidatingInvite))

    token_flow.Invalid(code: _, message: message) -> error_notice.view(message)

    token_flow.Ready(email) ->
      view_accept_invite_form(config, email, password, False, password_error)

    token_flow.Submitting(email) ->
      view_accept_invite_form(config, email, password, True, password_error)

    token_flow.Done -> loading.loading(t(i18n_text.SignedIn))
  }

  div([attribute.class("page")], [
    h1([], [text(t(i18n_text.AppName))]),
    h2([], [text(t(i18n_text.AcceptInviteTitle))]),
    case submit_error {
      opt.Some(err) ->
        error_notice.view_dismissible(
          err,
          t(i18n_text.Dismiss),
          config.on_accept_invite(token_flow.ErrorDismissed),
        )
      opt.None -> element.none()
    },
    content,
  ])
}

fn view_accept_invite_form(
  config: Config(msg),
  email: String,
  password: String,
  in_flight: Bool,
  password_error: opt.Option(String),
) -> Element(msg) {
  let t = fn(key) { i18n.t(config.locale, key) }

  let submit_label = case in_flight {
    True -> t(i18n_text.Registering)
    False -> t(i18n_text.Register)
  }

  form(
    [
      event.on_submit(fn(_) { config.on_accept_invite(token_flow.Submitted) }),
    ],
    [
      form_field.view(
        t(i18n_text.EmailLabel),
        input([
          attribute.type_("email"),
          attribute.value(email),
          attribute.disabled(True),
        ]),
      ),
      form_field.with_error(
        t(i18n_text.PasswordLabel),
        input([
          attribute.type_("password"),
          attribute.value(password),
          event.on_input(fn(value) {
            config.on_accept_invite(token_flow.PasswordChanged(value))
          }),
          attribute.required(True),
        ]),
        password_error,
      ),
      p([], [
        text(t(i18n_text.MinimumPasswordLength)),
      ]),
      button(
        [
          attribute.type_("submit"),
          attribute.disabled(in_flight),
          attribute.class(case in_flight {
            True -> "btn-loading"
            False -> ""
          }),
        ],
        [text(submit_label)],
      ),
    ],
  )
}

/// Renders the reset password page for existing users.
pub fn view_reset_password(config: Config(msg)) -> Element(msg) {
  let t = fn(key) { i18n.t(config.locale, key) }
  let token_flow.Model(
    state: state,
    password: password,
    password_error: password_error,
    submit_error: submit_error,
    ..,
  ) = config.auth.reset_password

  let content = case state {
    token_flow.NoToken -> error_notice.view(t(i18n_text.MissingResetToken))

    token_flow.Validating -> loading.loading(t(i18n_text.ValidatingResetToken))

    token_flow.Invalid(code: _, message: message) -> error_notice.view(message)

    token_flow.Ready(email) ->
      view_reset_password_form(config, email, password, False, password_error)

    token_flow.Submitting(email) ->
      view_reset_password_form(config, email, password, True, password_error)

    token_flow.Done -> loading.loading(t(i18n_text.PasswordUpdated))
  }

  div([attribute.class("page")], [
    h1([], [text(t(i18n_text.AppName))]),
    h2([], [text(t(i18n_text.ResetPasswordTitle))]),
    case submit_error {
      opt.Some(err) ->
        error_notice.view_dismissible(
          err,
          t(i18n_text.Dismiss),
          config.on_reset_password(token_flow.ErrorDismissed),
        )
      opt.None -> element.none()
    },
    content,
  ])
}

fn view_reset_password_form(
  config: Config(msg),
  email: String,
  password: String,
  in_flight: Bool,
  password_error: opt.Option(String),
) -> Element(msg) {
  let t = fn(key) { i18n.t(config.locale, key) }

  let submit_label = case in_flight {
    True -> t(i18n_text.Saving)
    False -> t(i18n_text.SaveNewPassword)
  }

  form(
    [
      event.on_submit(fn(_) { config.on_reset_password(token_flow.Submitted) }),
    ],
    [
      form_field.view(
        t(i18n_text.EmailLabel),
        input([
          attribute.type_("email"),
          attribute.value(email),
          attribute.disabled(True),
        ]),
      ),
      form_field.with_error(
        t(i18n_text.NewPasswordLabel),
        input([
          attribute.type_("password"),
          attribute.value(password),
          event.on_input(fn(value) {
            config.on_reset_password(token_flow.PasswordChanged(value))
          }),
          attribute.required(True),
        ]),
        password_error,
      ),
      p([], [
        text(t(i18n_text.MinimumPasswordLength)),
      ]),
      button(
        [
          attribute.type_("submit"),
          attribute.disabled(in_flight),
          attribute.class(case in_flight {
            True -> "btn-loading"
            False -> ""
          }),
        ],
        [text(submit_label)],
      ),
    ],
  )
}
