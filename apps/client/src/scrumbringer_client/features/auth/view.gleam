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
//// - **client_state.gleam**: Provides Model and Msg types
//// - **accept_invite.gleam**: Provides accept invite sub-model types
//// - **reset_password.gleam**: Provides reset password sub-model types
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
import scrumbringer_client/client_ffi
import scrumbringer_client/client_state.{
  type Model, type Msg, AcceptInviteMsg, ForgotPasswordClicked,
  ForgotPasswordCopyClicked, ForgotPasswordDismissed, ForgotPasswordEmailChanged,
  ForgotPasswordSubmitted, LoginEmailChanged, LoginPasswordChanged,
  LoginSubmitted, ResetPasswordMsg, auth_msg,
}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/reset_password
import scrumbringer_client/ui/attrs
import scrumbringer_client/ui/copyable_input
import scrumbringer_client/ui/error_notice
import scrumbringer_client/ui/form_field
import scrumbringer_client/ui/loading
import scrumbringer_client/update_helpers

/// Renders the login page with email/password form.
pub fn view_login(model: Model) -> Element(Msg) {
  let submit_label = case model.auth.login_in_flight {
    True -> update_helpers.i18n_t(model, i18n_text.LoggingIn)
    False -> update_helpers.i18n_t(model, i18n_text.LoginTitle)
  }

  // L01: Button class with loading state
  let btn_class = case model.auth.login_in_flight {
    True -> "btn-loading"
    False -> ""
  }

  div([attribute.class("page")], [
    h1([], [text(update_helpers.i18n_t(model, i18n_text.AppName))]),
    p([], [text(update_helpers.i18n_t(model, i18n_text.LoginSubtitle))]),
    // L03: Error banner with icon
    case model.auth.login_error {
      opt.Some(err) -> error_notice.view(err)
      opt.None -> element.none()
    },
    form([event.on_submit(fn(_) { auth_msg(LoginSubmitted) })], [
      form_field.view(
        update_helpers.i18n_t(model, i18n_text.EmailLabel),
        input([
          attribute.attribute("id", "login-email"),
          attribute.type_("email"),
          attribute.value(model.auth.login_email),
          event.on_input(fn(value) { auth_msg(LoginEmailChanged(value)) }),
          attribute.required(True),
          // L02: Autofocus on first field
          attribute.autofocus(True),
          attribute.attribute("aria-label", "Email address"),
        ]),
      ),
      form_field.view(
        update_helpers.i18n_t(model, i18n_text.PasswordLabel),
        input([
          attribute.attribute("id", "login-password"),
          attribute.type_("password"),
          attribute.value(model.auth.login_password),
          event.on_input(fn(value) { auth_msg(LoginPasswordChanged(value)) }),
          attribute.required(True),
          attribute.attribute("aria-label", "Password"),
        ]),
      ),
      // L01: Submit button with loading class
      button(
        [
          attribute.type_("submit"),
          attribute.disabled(model.auth.login_in_flight),
          attribute.class(btn_class),
        ],
        [text(submit_label)],
      ),
    ]),
    button([event.on_click(auth_msg(ForgotPasswordClicked))], [
      text(update_helpers.i18n_t(model, i18n_text.ForgotPassword)),
    ]),
    case model.auth.forgot_password_open {
      True -> view_forgot_password(model)
      False -> element.none()
    },
  ])
}

// Justification: nested case improves clarity for branching logic.
/// Renders the forgot password form with email input and reset link display.
pub fn view_forgot_password(model: Model) -> Element(Msg) {
  let submit_label = case model.auth.forgot_password_in_flight {
    True -> update_helpers.i18n_t(model, i18n_text.Working)
    False -> update_helpers.i18n_t(model, i18n_text.GenerateResetLink)
  }

  let origin = client_ffi.location_origin()

  let link = case model.auth.forgot_password_result {
    opt.Some(reset) -> origin <> reset.url_path
    opt.None -> ""
  }

  div([attrs.section()], [
    p([], [text(update_helpers.i18n_t(model, i18n_text.NoEmailIntegrationNote))]),
    case model.auth.forgot_password_error {
      opt.Some(err) ->
        error_notice.view_dismissible(
          err,
          update_helpers.i18n_t(model, i18n_text.Dismiss),
          auth_msg(ForgotPasswordDismissed),
        )
      opt.None -> element.none()
    },
    form([event.on_submit(fn(_) { auth_msg(ForgotPasswordSubmitted) })], [
      form_field.view(
        update_helpers.i18n_t(model, i18n_text.EmailLabel),
        input([
          attribute.type_("email"),
          attribute.value(model.auth.forgot_password_email),
          event.on_input(fn(value) {
            auth_msg(ForgotPasswordEmailChanged(value))
          }),
          attribute.required(True),
        ]),
      ),
      button(
        [
          attribute.type_("submit"),
          attribute.disabled(model.auth.forgot_password_in_flight),
        ],
        [text(submit_label)],
      ),
    ]),
    case link == "" {
      True -> element.none()

      False ->
        copyable_input.view(
          update_helpers.i18n_t(model, i18n_text.ResetLink),
          link,
          auth_msg(ForgotPasswordCopyClicked),
          update_helpers.i18n_t(model, i18n_text.Copy),
          model.auth.forgot_password_copy_status,
        )
    },
  ])
}

/// Renders the accept invite page for new user registration.
pub fn view_accept_invite(model: Model) -> Element(Msg) {
  let accept_invite.Model(
    state: state,
    password: password,
    password_error: password_error,
    submit_error: submit_error,
    ..,
  ) = model.auth.accept_invite

  let content = case state {
    accept_invite.NoToken ->
      error_notice.view(update_helpers.i18n_t(
        model,
        i18n_text.MissingInviteToken,
      ))

    accept_invite.Validating ->
      loading.loading(update_helpers.i18n_t(model, i18n_text.ValidatingInvite))

    accept_invite.Invalid(code: _, message: message) ->
      error_notice.view(message)

    accept_invite.Ready(email) ->
      view_accept_invite_form(model, email, password, False, password_error)

    accept_invite.Registering(email) ->
      view_accept_invite_form(model, email, password, True, password_error)

    accept_invite.Done ->
      loading.loading(update_helpers.i18n_t(model, i18n_text.SignedIn))
  }

  div([attribute.class("page")], [
    h1([], [text(update_helpers.i18n_t(model, i18n_text.AppName))]),
    h2([], [text(update_helpers.i18n_t(model, i18n_text.AcceptInviteTitle))]),
    case submit_error {
      opt.Some(err) ->
        error_notice.view_dismissible(
          err,
          update_helpers.i18n_t(model, i18n_text.Dismiss),
          AcceptInviteMsg(accept_invite.ErrorDismissed),
        )
      opt.None -> element.none()
    },
    content,
  ])
}

fn view_accept_invite_form(
  model: Model,
  email: String,
  password: String,
  in_flight: Bool,
  password_error: opt.Option(String),
) -> Element(Msg) {
  let submit_label = case in_flight {
    True -> update_helpers.i18n_t(model, i18n_text.Registering)
    False -> update_helpers.i18n_t(model, i18n_text.Register)
  }

  form([event.on_submit(fn(_) { AcceptInviteMsg(accept_invite.Submitted) })], [
    form_field.view(
      update_helpers.i18n_t(model, i18n_text.EmailLabel),
      input([
        attribute.type_("email"),
        attribute.value(email),
        attribute.disabled(True),
      ]),
    ),
    div([], [
      form_field.view(
        update_helpers.i18n_t(model, i18n_text.PasswordLabel),
        input([
          attribute.type_("password"),
          attribute.value(password),
          event.on_input(fn(value) {
            AcceptInviteMsg(accept_invite.PasswordChanged(value))
          }),
          attribute.required(True),
        ]),
      ),
      case password_error {
        opt.Some(err) -> error_notice.view(err)
        opt.None -> element.none()
      },
      p([], [
        text(update_helpers.i18n_t(model, i18n_text.MinimumPasswordLength)),
      ]),
    ]),
    button([attribute.type_("submit"), attribute.disabled(in_flight)], [
      text(submit_label),
    ]),
  ])
}

/// Renders the reset password page for existing users.
pub fn view_reset_password(model: Model) -> Element(Msg) {
  let reset_password.Model(
    state: state,
    password: password,
    password_error: password_error,
    submit_error: submit_error,
    ..,
  ) = model.auth.reset_password

  let content = case state {
    reset_password.NoToken ->
      error_notice.view(update_helpers.i18n_t(
        model,
        i18n_text.MissingResetToken,
      ))

    reset_password.Validating ->
      loading.loading(update_helpers.i18n_t(
        model,
        i18n_text.ValidatingResetToken,
      ))

    reset_password.Invalid(code: _, message: message) ->
      error_notice.view(message)

    reset_password.Ready(email) ->
      view_reset_password_form(model, email, password, False, password_error)

    reset_password.Consuming(email) ->
      view_reset_password_form(model, email, password, True, password_error)

    reset_password.Done ->
      loading.loading(update_helpers.i18n_t(model, i18n_text.PasswordUpdated))
  }

  div([attribute.class("page")], [
    h1([], [text(update_helpers.i18n_t(model, i18n_text.AppName))]),
    h2([], [text(update_helpers.i18n_t(model, i18n_text.ResetPasswordTitle))]),
    case submit_error {
      opt.Some(err) ->
        error_notice.view_dismissible(
          err,
          update_helpers.i18n_t(model, i18n_text.Dismiss),
          ResetPasswordMsg(reset_password.ErrorDismissed),
        )
      opt.None -> element.none()
    },
    content,
  ])
}

fn view_reset_password_form(
  model: Model,
  email: String,
  password: String,
  in_flight: Bool,
  password_error: opt.Option(String),
) -> Element(Msg) {
  let submit_label = case in_flight {
    True -> update_helpers.i18n_t(model, i18n_text.Saving)
    False -> update_helpers.i18n_t(model, i18n_text.SaveNewPassword)
  }

  form([event.on_submit(fn(_) { ResetPasswordMsg(reset_password.Submitted) })], [
    form_field.view(
      update_helpers.i18n_t(model, i18n_text.EmailLabel),
      input([
        attribute.type_("email"),
        attribute.value(email),
        attribute.disabled(True),
      ]),
    ),
    div([], [
      form_field.view(
        update_helpers.i18n_t(model, i18n_text.NewPasswordLabel),
        input([
          attribute.type_("password"),
          attribute.value(password),
          event.on_input(fn(value) {
            ResetPasswordMsg(reset_password.PasswordChanged(value))
          }),
          attribute.required(True),
        ]),
      ),
      case password_error {
        opt.Some(err) -> error_notice.view(err)
        opt.None -> element.none()
      },
      p([], [
        text(update_helpers.i18n_t(model, i18n_text.MinimumPasswordLength)),
      ]),
    ]),
    button([attribute.type_("submit"), attribute.disabled(in_flight)], [
      text(submit_label),
    ]),
  ])
}
