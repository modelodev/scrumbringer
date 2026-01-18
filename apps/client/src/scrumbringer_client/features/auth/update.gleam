//// Authentication feature update handlers.
////
//// ## Mission
////
//// Handles login, logout, and password reset flows for the client.
////
//// ## Responsibilities
////
//// - Login form state and submission
//// - Forgot password flow
//// - Logout handling
////
//// ## Non-responsibilities
////
//// - User session management (see `client_state.gleam`)
//// - API calls (see `api/auth.gleam`)
////
//// ## Relations
////
//// - **client_update.gleam**: Dispatches auth messages to handlers here
//// - **features/auth/view.gleam**: Renders auth UI using model state
//// - **api/auth.gleam**: Provides API effects for auth operations

import gleam/option as opt
import gleam/string

import lustre/effect.{type Effect}

import domain/org_role
import domain/user.{type User}

// API modules
import scrumbringer_client/api/auth as api_auth
// Domain types
import domain/api_error.{type ApiError}
import scrumbringer_client/client_ffi
import scrumbringer_client/client_state.{
  type Model, type Msg, Admin, ForgotPasswordCopyFinished, ForgotPasswordFinished,
  Login, LoginDomValuesRead, LoginFinished, LogoutFinished, Member, Model,
}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/update_helpers

// =============================================================================
// Login Handlers
// =============================================================================

/// Handle login email input change.
pub fn handle_login_email_changed(model: Model, email: String) -> #(Model, Effect(Msg)) {
  #(Model(..model, login_email: email), effect.none())
}

/// Handle login password input change.
pub fn handle_login_password_changed(model: Model, password: String) -> #(Model, Effect(Msg)) {
  #(Model(..model, login_password: password), effect.none())
}

/// Handle login form submission.
pub fn handle_login_submitted(model: Model) -> #(Model, Effect(Msg)) {
  case model.login_in_flight {
    True -> #(model, effect.none())
    False -> {
      let model =
        Model(
          ..model,
          login_in_flight: True,
          login_error: opt.None,
          toast: opt.None,
        )
      #(model, read_login_values_effect())
    }
  }
}

/// Handle login DOM values read callback.
pub fn handle_login_dom_values_read(
  model: Model,
  raw_email: String,
  raw_password: String,
) -> #(Model, Effect(Msg)) {
  let email = string.trim(raw_email)
  let password = raw_password

  case email == "" || password == "" {
    True -> #(
      Model(
        ..model,
        login_in_flight: False,
        login_error: opt.Some(update_helpers.i18n_t(
          model,
          i18n_text.EmailAndPasswordRequired,
        )),
      ),
      effect.none(),
    )

    False -> {
      let model = Model(..model, login_email: email, login_password: password)
      #(model, api_auth.login(email, password, LoginFinished))
    }
  }
}

/// Handle successful login.
pub fn handle_login_finished_ok(
  model: Model,
  user: User,
  bootstrap_fn: fn(Model) -> #(Model, Effect(Msg)),
  hydrate_fn: fn(Model) -> #(Model, Effect(Msg)),
  replace_url_fn: fn(Model) -> Effect(Msg),
) -> #(Model, Effect(Msg)) {
  let page = case user.org_role {
    org_role.Admin -> Admin
    _ -> Member
  }

  let model =
    Model(
      ..model,
      page: page,
      user: opt.Some(user),
      auth_checked: True,
      login_in_flight: False,
      login_password: "",
      toast: opt.Some(update_helpers.i18n_t(model, i18n_text.LoggedIn)),
    )

  let #(model, boot) = bootstrap_fn(model)
  let #(model, hyd_fx) = hydrate_fn(model)
  #(
    model,
    effect.batch([boot, hyd_fx, replace_url_fn(model)]),
  )
}

/// Handle login error.
pub fn handle_login_finished_error(model: Model, err: ApiError) -> #(Model, Effect(Msg)) {
  let message = case err.status {
    401 | 403 -> update_helpers.i18n_t(model, i18n_text.InvalidCredentials)
    _ -> err.message
  }

  #(
    Model(..model, login_in_flight: False, login_error: opt.Some(message)),
    effect.none(),
  )
}

// =============================================================================
// Forgot Password Handlers
// =============================================================================

/// Handle forgot password toggle.
pub fn handle_forgot_password_clicked(model: Model) -> #(Model, Effect(Msg)) {
  let open = !model.forgot_password_open

  #(
    Model(
      ..model,
      forgot_password_open: open,
      forgot_password_in_flight: False,
      forgot_password_result: opt.None,
      forgot_password_error: opt.None,
      forgot_password_copy_status: opt.None,
      toast: opt.None,
    ),
    effect.none(),
  )
}

/// Handle forgot password email input change.
pub fn handle_forgot_password_email_changed(
  model: Model,
  email: String,
) -> #(Model, Effect(Msg)) {
  #(
    Model(
      ..model,
      forgot_password_email: email,
      forgot_password_error: opt.None,
      forgot_password_copy_status: opt.None,
    ),
    effect.none(),
  )
}

/// Handle forgot password form submission.
pub fn handle_forgot_password_submitted(model: Model) -> #(Model, Effect(Msg)) {
  case model.forgot_password_in_flight {
    True -> #(model, effect.none())

    False -> {
      let email = string.trim(model.forgot_password_email)

      case email == "" {
        True -> #(
          Model(
            ..model,
            forgot_password_error: opt.Some(update_helpers.i18n_t(
              model,
              i18n_text.EmailRequired,
            )),
          ),
          effect.none(),
        )

        False -> {
          let model =
            Model(
              ..model,
              forgot_password_in_flight: True,
              forgot_password_error: opt.None,
              forgot_password_result: opt.None,
              forgot_password_copy_status: opt.None,
            )

          #(model, api_auth.request_password_reset(email, ForgotPasswordFinished))
        }
      }
    }
  }
}

/// Handle successful password reset request.
pub fn handle_forgot_password_finished_ok(
  model: Model,
  reset: api_auth.PasswordReset,
) -> #(Model, Effect(Msg)) {
  #(
    Model(
      ..model,
      forgot_password_in_flight: False,
      forgot_password_result: opt.Some(reset),
      forgot_password_error: opt.None,
      forgot_password_copy_status: opt.None,
    ),
    effect.none(),
  )
}

/// Handle password reset request error.
pub fn handle_forgot_password_finished_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  #(
    Model(
      ..model,
      forgot_password_in_flight: False,
      forgot_password_error: opt.Some(err.message),
    ),
    effect.none(),
  )
}

/// Handle copy reset link click.
pub fn handle_forgot_password_copy_clicked(model: Model) -> #(Model, Effect(Msg)) {
  case model.forgot_password_result {
    opt.None -> #(model, effect.none())

    opt.Some(reset) -> {
      let origin = client_ffi.location_origin()
      let text = origin <> reset.url_path

      #(
        Model(
          ..model,
          forgot_password_copy_status: opt.Some(update_helpers.i18n_t(
            model,
            i18n_text.Copying,
          )),
        ),
        copy_to_clipboard(text, ForgotPasswordCopyFinished),
      )
    }
  }
}

/// Handle copy finished callback.
pub fn handle_forgot_password_copy_finished(
  model: Model,
  ok: Bool,
) -> #(Model, Effect(Msg)) {
  let message = case ok {
    True -> update_helpers.i18n_t(model, i18n_text.Copied)
    False -> update_helpers.i18n_t(model, i18n_text.CopyFailed)
  }

  #(
    Model(..model, forgot_password_copy_status: opt.Some(message)),
    effect.none(),
  )
}

/// Handle dismiss forgot password result.
pub fn handle_forgot_password_dismissed(model: Model) -> #(Model, Effect(Msg)) {
  #(
    Model(
      ..model,
      forgot_password_error: opt.None,
      forgot_password_copy_status: opt.None,
      forgot_password_result: opt.None,
    ),
    effect.none(),
  )
}

// =============================================================================
// Logout Handlers
// =============================================================================

/// Handle logout click.
pub fn handle_logout_clicked(model: Model) -> #(Model, Effect(Msg)) {
  #(Model(..model, toast: opt.None), api_auth.logout(LogoutFinished))
}

/// Handle successful logout.
pub fn handle_logout_finished_ok(
  model: Model,
  replace_url_fn: fn(Model) -> Effect(Msg),
) -> #(Model, Effect(Msg)) {
  let model =
    Model(
      ..model,
      page: Login,
      user: opt.None,
      auth_checked: False,
      toast: opt.Some(update_helpers.i18n_t(model, i18n_text.LoggedOut)),
    )

  #(model, replace_url_fn(model))
}

/// Handle logout error.
pub fn handle_logout_finished_error(
  model: Model,
  err: ApiError,
  replace_url_fn: fn(Model) -> Effect(Msg),
) -> #(Model, Effect(Msg)) {
  case err.status == 401 {
    True -> {
      let model =
        Model(..model, page: Login, user: opt.None, auth_checked: False)
      #(model, replace_url_fn(model))
    }

    False -> #(
      Model(
        ..model,
        toast: opt.Some(update_helpers.i18n_t(model, i18n_text.LogoutFailed)),
      ),
      effect.none(),
    )
  }
}

// =============================================================================
// Effects
// =============================================================================

fn read_login_values_effect() -> Effect(Msg) {
  effect.from(fn(dispatch) {
    let email = client_ffi.input_value("login-email")
    let password = client_ffi.input_value("login-password")
    dispatch(LoginDomValuesRead(email, password))
    Nil
  })
}

fn copy_to_clipboard(text: String, callback: fn(Bool) -> Msg) -> Effect(Msg) {
  effect.from(fn(dispatch) {
    client_ffi.copy_to_clipboard(text, fn(ok) { dispatch(callback(ok)) })
    Nil
  })
}
