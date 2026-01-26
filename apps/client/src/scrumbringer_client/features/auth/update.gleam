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

import lustre/effect.{type Effect}

import domain/org_role
import domain/user.{type User}

// API modules
import scrumbringer_client/api/auth as api_auth

// Domain types
import domain/api_error.{type ApiError}
import scrumbringer_client/client_ffi
import scrumbringer_client/client_state.{
  type AuthMsg, type Model, type Msg, Admin, AuthModel, CoreModel,
  ForgotPasswordClicked, ForgotPasswordCopyClicked, ForgotPasswordCopyFinished,
  ForgotPasswordDismissed, ForgotPasswordEmailChanged, ForgotPasswordFinished,
  ForgotPasswordSubmitted, Login, LoginDomValuesRead, LoginEmailChanged,
  LoginFinished, LoginPasswordChanged, LoginSubmitted, LogoutClicked,
  LogoutFinished, Member, ToastShow, auth_msg, update_auth, update_core,
}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/toast
import scrumbringer_client/update_helpers

// =============================================================================
// Login Handlers
// =============================================================================

/// Handle login email input change.
pub fn handle_login_email_changed(
  model: Model,
  email: String,
) -> #(Model, Effect(Msg)) {
  #(
    update_auth(model, fn(auth) { AuthModel(..auth, login_email: email) }),
    effect.none(),
  )
}

/// Handle login password input change.
pub fn handle_login_password_changed(
  model: Model,
  password: String,
) -> #(Model, Effect(Msg)) {
  #(
    update_auth(model, fn(auth) { AuthModel(..auth, login_password: password) }),
    effect.none(),
  )
}

/// Handle login form submission.
pub fn handle_login_submitted(model: Model) -> #(Model, Effect(Msg)) {
  case model.auth.login_in_flight {
    True -> #(model, effect.none())
    False -> {
      let model =
        update_auth(model, fn(auth) {
          AuthModel(..auth, login_in_flight: True, login_error: opt.None)
        })
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
  let email_result =
    update_helpers.validate_required_string(
      model,
      raw_email,
      i18n_text.EmailAndPasswordRequired,
    )
  let password_result =
    update_helpers.validate_required_string_raw(
      model,
      raw_password,
      i18n_text.EmailAndPasswordRequired,
    )

  case email_result, password_result {
    Ok(email), Ok(password) -> {
      let email = update_helpers.non_empty_string_value(email)
      let password = update_helpers.non_empty_string_value(password)
      let model =
        update_auth(model, fn(auth) {
          AuthModel(..auth, login_email: email, login_password: password)
        })
      #(
        model,
        api_auth.login(email, password, fn(result) {
          auth_msg(LoginFinished(result))
        }),
      )
    }
    Error(err), _ -> #(
      update_auth(model, fn(auth) {
        AuthModel(..auth, login_in_flight: False, login_error: opt.Some(err))
      }),
      effect.none(),
    )
    _, Error(err) -> #(
      update_auth(model, fn(auth) {
        AuthModel(..auth, login_in_flight: False, login_error: opt.Some(err))
      }),
      effect.none(),
    )
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
    update_auth(
      update_core(model, fn(core) {
        CoreModel(..core, page: page, user: opt.Some(user), auth_checked: True)
      }),
      fn(auth) { AuthModel(..auth, login_in_flight: False, login_password: "") },
    )

  let #(model, boot) = bootstrap_fn(model)
  let #(model, hyd_fx) = hydrate_fn(model)

  // Story 4.8: Use new toast system with auto-dismiss
  let toast_message = update_helpers.i18n_t(model, i18n_text.LoggedIn)
  let toast_effect =
    effect.from(fn(dispatch) {
      dispatch(ToastShow(toast_message, toast.Success))
    })

  #(model, effect.batch([boot, hyd_fx, replace_url_fn(model), toast_effect]))
}

/// Handle login error.
pub fn handle_login_finished_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  let message = case err.status {
    401 | 403 -> update_helpers.i18n_t(model, i18n_text.InvalidCredentials)
    _ -> err.message
  }

  #(
    update_auth(model, fn(auth) {
      AuthModel(..auth, login_in_flight: False, login_error: opt.Some(message))
    }),
    effect.none(),
  )
}

// =============================================================================
// Forgot Password Handlers
// =============================================================================

/// Handle forgot password toggle.
pub fn handle_forgot_password_clicked(model: Model) -> #(Model, Effect(Msg)) {
  let open = !model.auth.forgot_password_open

  #(
    update_auth(model, fn(auth) {
      AuthModel(
        ..auth,
        forgot_password_open: open,
        forgot_password_in_flight: False,
        forgot_password_result: opt.None,
        forgot_password_error: opt.None,
        forgot_password_copy_status: opt.None,
      )
    }),
    effect.none(),
  )
}

/// Handle forgot password email input change.
pub fn handle_forgot_password_email_changed(
  model: Model,
  email: String,
) -> #(Model, Effect(Msg)) {
  #(
    update_auth(model, fn(auth) {
      AuthModel(
        ..auth,
        forgot_password_email: email,
        forgot_password_error: opt.None,
        forgot_password_copy_status: opt.None,
      )
    }),
    effect.none(),
  )
}

/// Handle forgot password form submission.
pub fn handle_forgot_password_submitted(model: Model) -> #(Model, Effect(Msg)) {
  case model.auth.forgot_password_in_flight {
    True -> #(model, effect.none())

    False -> {
      case
        update_helpers.validate_required_string(
          model,
          model.auth.forgot_password_email,
          i18n_text.EmailRequired,
        )
      {
        Error(err) -> #(
          update_auth(model, fn(auth) {
            AuthModel(..auth, forgot_password_error: opt.Some(err))
          }),
          effect.none(),
        )

        Ok(email) -> {
          let email = update_helpers.non_empty_string_value(email)
          let model =
            update_auth(model, fn(auth) {
              AuthModel(
                ..auth,
                forgot_password_in_flight: True,
                forgot_password_error: opt.None,
                forgot_password_result: opt.None,
                forgot_password_copy_status: opt.None,
              )
            })

          #(
            model,
            api_auth.request_password_reset(email, fn(result) {
              auth_msg(ForgotPasswordFinished(result))
            }),
          )
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
    update_auth(model, fn(auth) {
      AuthModel(
        ..auth,
        forgot_password_in_flight: False,
        forgot_password_result: opt.Some(reset),
        forgot_password_error: opt.None,
        forgot_password_copy_status: opt.None,
      )
    }),
    effect.none(),
  )
}

/// Handle password reset request error.
pub fn handle_forgot_password_finished_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  #(
    update_auth(model, fn(auth) {
      AuthModel(
        ..auth,
        forgot_password_in_flight: False,
        forgot_password_error: opt.Some(err.message),
      )
    }),
    effect.none(),
  )
}

/// Handle copy reset link click.
pub fn handle_forgot_password_copy_clicked(
  model: Model,
) -> #(Model, Effect(Msg)) {
  case model.auth.forgot_password_result {
    opt.None -> #(model, effect.none())

    opt.Some(reset) -> {
      let origin = client_ffi.location_origin()
      let text = origin <> reset.url_path

      #(
        update_auth(model, fn(auth) {
          AuthModel(
            ..auth,
            forgot_password_copy_status: opt.Some(update_helpers.i18n_t(
              model,
              i18n_text.Copying,
            )),
          )
        }),
        copy_to_clipboard(text, fn(ok) {
          auth_msg(ForgotPasswordCopyFinished(ok))
        }),
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
    update_auth(model, fn(auth) {
      AuthModel(..auth, forgot_password_copy_status: opt.Some(message))
    }),
    effect.none(),
  )
}

/// Handle dismiss forgot password result.
pub fn handle_forgot_password_dismissed(model: Model) -> #(Model, Effect(Msg)) {
  #(
    update_auth(model, fn(auth) {
      AuthModel(
        ..auth,
        forgot_password_error: opt.None,
        forgot_password_copy_status: opt.None,
        forgot_password_result: opt.None,
      )
    }),
    effect.none(),
  )
}

// =============================================================================
// Logout Handlers
// =============================================================================

/// Handle logout click.
pub fn handle_logout_clicked(model: Model) -> #(Model, Effect(Msg)) {
  #(model, api_auth.logout(fn(result) { auth_msg(LogoutFinished(result)) }))
}

/// Handle successful logout.
pub fn handle_logout_finished_ok(
  model: Model,
  replace_url_fn: fn(Model) -> Effect(Msg),
) -> #(Model, Effect(Msg)) {
  let model =
    update_core(model, fn(core) {
      CoreModel(..core, page: Login, user: opt.None, auth_checked: False)
    })
  let toast_fx =
    update_helpers.toast_success(update_helpers.i18n_t(
      model,
      i18n_text.LoggedOut,
    ))

  #(model, effect.batch([replace_url_fn(model), toast_fx]))
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
        update_core(model, fn(core) {
          CoreModel(..core, page: Login, user: opt.None, auth_checked: False)
        })
      #(model, replace_url_fn(model))
    }

    False -> #(
      model,
      update_helpers.toast_error(update_helpers.i18n_t(
        model,
        i18n_text.LogoutFailed,
      )),
    )
  }
}

// =============================================================================
// Auth Message Dispatcher
// =============================================================================

pub fn update(
  model: Model,
  msg: AuthMsg,
  bootstrap_fn: fn(Model) -> #(Model, Effect(Msg)),
  hydrate_fn: fn(Model) -> #(Model, Effect(Msg)),
  replace_url_fn: fn(Model) -> Effect(Msg),
) -> #(Model, Effect(Msg)) {
  case msg {
    LoginEmailChanged(email) -> handle_login_email_changed(model, email)
    LoginPasswordChanged(password) ->
      handle_login_password_changed(model, password)
    LoginSubmitted -> handle_login_submitted(model)
    LoginDomValuesRead(raw_email, raw_password) ->
      handle_login_dom_values_read(model, raw_email, raw_password)
    LoginFinished(Ok(user)) ->
      handle_login_finished_ok(
        model,
        user,
        bootstrap_fn,
        hydrate_fn,
        replace_url_fn,
      )
    LoginFinished(Error(err)) -> handle_login_finished_error(model, err)
    ForgotPasswordClicked -> handle_forgot_password_clicked(model)
    ForgotPasswordEmailChanged(email) ->
      handle_forgot_password_email_changed(model, email)
    ForgotPasswordSubmitted -> handle_forgot_password_submitted(model)
    ForgotPasswordFinished(Ok(reset)) ->
      handle_forgot_password_finished_ok(model, reset)
    ForgotPasswordFinished(Error(err)) ->
      handle_forgot_password_finished_error(model, err)
    ForgotPasswordCopyClicked -> handle_forgot_password_copy_clicked(model)
    ForgotPasswordCopyFinished(ok) ->
      handle_forgot_password_copy_finished(model, ok)
    ForgotPasswordDismissed -> handle_forgot_password_dismissed(model)
    LogoutClicked -> handle_logout_clicked(model)
    LogoutFinished(Ok(_)) -> handle_logout_finished_ok(model, replace_url_fn)
    LogoutFinished(Error(err)) ->
      handle_logout_finished_error(model, err, replace_url_fn)
  }
}

// =============================================================================
// Effects
// =============================================================================

fn read_login_values_effect() -> Effect(Msg) {
  effect.from(fn(dispatch) {
    let email = client_ffi.input_value("login-email")
    let password = client_ffi.input_value("login-password")
    dispatch(auth_msg(LoginDomValuesRead(email, password)))
    Nil
  })
}

fn copy_to_clipboard(text: String, callback: fn(Bool) -> Msg) -> Effect(Msg) {
  effect.from(fn(dispatch) {
    client_ffi.copy_to_clipboard(text, fn(ok) { dispatch(callback(ok)) })
    Nil
  })
}
