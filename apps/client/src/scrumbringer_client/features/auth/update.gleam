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
import scrumbringer_client/accept_invite
import scrumbringer_client/client_ffi
import scrumbringer_client/client_state.{
  type Model, type Msg, type Page, Admin, CoreModel, Login, Member, ToastShow,
  auth_msg, update_auth, update_core,
}
import scrumbringer_client/client_state/auth as auth_state
import scrumbringer_client/features/auth/msg as auth_messages
import scrumbringer_client/helpers/i18n as helpers_i18n
import scrumbringer_client/helpers/toast as helpers_toast
import scrumbringer_client/helpers/validation as helpers_validation
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/reset_password
import scrumbringer_client/token_flow
import scrumbringer_client/ui/toast

// =============================================================================
// Login Handlers
// =============================================================================

/// Handle login email input change.
pub fn handle_login_email_changed(
  model: Model,
  email: String,
) -> #(Model, Effect(Msg)) {
  #(
    update_auth(model, fn(auth) {
      auth_state.AuthModel(..auth, login_email: email)
    }),
    effect.none(),
  )
}

/// Handle login password input change.
pub fn handle_login_password_changed(
  model: Model,
  password: String,
) -> #(Model, Effect(Msg)) {
  #(
    update_auth(model, fn(auth) {
      auth_state.AuthModel(..auth, login_password: password)
    }),
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
          auth_state.AuthModel(
            ..auth,
            login_in_flight: True,
            login_error: opt.None,
          )
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
    helpers_validation.validate_required_string(
      model,
      raw_email,
      i18n_text.EmailAndPasswordRequired,
    )
  let password_result =
    helpers_validation.validate_required_string_raw(
      model,
      raw_password,
      i18n_text.EmailAndPasswordRequired,
    )

  case email_result, password_result {
    Ok(email), Ok(password) -> {
      let email = helpers_validation.non_empty_string_value(email)
      let password = helpers_validation.non_empty_string_value(password)
      let model =
        update_auth(model, fn(auth) {
          auth_state.AuthModel(
            ..auth,
            login_email: email,
            login_password: password,
          )
        })
      #(
        model,
        api_auth.login(email, password, fn(result) {
          auth_msg(auth_messages.LoginFinished(result))
        }),
      )
    }
    Error(err), _ -> #(
      update_auth(model, fn(auth) {
        auth_state.AuthModel(
          ..auth,
          login_in_flight: False,
          login_error: opt.Some(err),
        )
      }),
      effect.none(),
    )
    _, Error(err) -> #(
      update_auth(model, fn(auth) {
        auth_state.AuthModel(
          ..auth,
          login_in_flight: False,
          login_error: opt.Some(err),
        )
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
  // Default landing for all roles is member pool.
  let page = Member

  let model =
    update_auth(
      update_core(model, fn(core) {
        CoreModel(..core, page: page, user: opt.Some(user), auth_checked: True)
      }),
      fn(auth) {
        auth_state.AuthModel(..auth, login_in_flight: False, login_password: "")
      },
    )

  let #(model, boot) = bootstrap_fn(model)
  let #(model, hyd_fx) = hydrate_fn(model)

  // Story 4.8: Use new toast system with auto-dismiss
  let toast_message = helpers_i18n.i18n_t(model, i18n_text.LoggedIn)
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
    401 | 403 -> helpers_i18n.i18n_t(model, i18n_text.InvalidCredentials)
    _ -> err.message
  }

  #(
    update_auth(model, fn(auth) {
      auth_state.AuthModel(
        ..auth,
        login_in_flight: False,
        login_error: opt.Some(message),
      )
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
      auth_state.AuthModel(
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
      auth_state.AuthModel(
        ..auth,
        forgot_password_email: email,
        forgot_password_error: opt.None,
        forgot_password_copy_status: opt.None,
      )
    }),
    effect.none(),
  )
}

// Justification: nested case improves clarity for branching logic.
/// Handle forgot password form submission.
pub fn handle_forgot_password_submitted(model: Model) -> #(Model, Effect(Msg)) {
  case model.auth.forgot_password_in_flight {
    True -> #(model, effect.none())

    False -> {
      case
        helpers_validation.validate_required_string(
          model,
          model.auth.forgot_password_email,
          i18n_text.EmailRequired,
        )
      {
        Error(err) -> #(
          update_auth(model, fn(auth) {
            auth_state.AuthModel(..auth, forgot_password_error: opt.Some(err))
          }),
          effect.none(),
        )

        Ok(email) -> {
          let email = helpers_validation.non_empty_string_value(email)
          let model =
            update_auth(model, fn(auth) {
              auth_state.AuthModel(
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
              auth_msg(auth_messages.ForgotPasswordFinished(result))
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
      auth_state.AuthModel(
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
      auth_state.AuthModel(
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
          auth_state.AuthModel(
            ..auth,
            forgot_password_copy_status: opt.Some(helpers_i18n.i18n_t(
              model,
              i18n_text.Copying,
            )),
          )
        }),
        copy_to_clipboard(text, fn(ok) {
          auth_msg(auth_messages.ForgotPasswordCopyFinished(ok))
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
    True -> helpers_i18n.i18n_t(model, i18n_text.Copied)
    False -> helpers_i18n.i18n_t(model, i18n_text.CopyFailed)
  }

  #(
    update_auth(model, fn(auth) {
      auth_state.AuthModel(
        ..auth,
        forgot_password_copy_status: opt.Some(message),
      )
    }),
    effect.none(),
  )
}

/// Handle dismiss forgot password result.
pub fn handle_forgot_password_dismissed(model: Model) -> #(Model, Effect(Msg)) {
  #(
    update_auth(model, fn(auth) {
      auth_state.AuthModel(
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
  #(
    model,
    api_auth.logout(fn(result) {
      auth_msg(auth_messages.LogoutFinished(result))
    }),
  )
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
    helpers_toast.toast_success(helpers_i18n.i18n_t(model, i18n_text.LoggedOut))

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
      helpers_toast.toast_error(helpers_i18n.i18n_t(
        model,
        i18n_text.LogoutFailed,
      )),
    )
  }
}

// =============================================================================
// Accept Invite / Reset Password
// =============================================================================

pub fn accept_invite_effect(action: accept_invite.Action) -> Effect(Msg) {
  case action {
    accept_invite.ValidateToken(token) ->
      api_auth.validate_invite_link_token(token, fn(result) {
        auth_msg(auth_messages.AcceptInvite(token_flow.TokenValidated(result)))
      })
    _ -> effect.none()
  }
}

pub fn reset_password_effect(action: reset_password.Action) -> Effect(Msg) {
  case action {
    reset_password.ValidateToken(token) ->
      api_auth.validate_password_reset_token(token, fn(result) {
        auth_msg(auth_messages.ResetPassword(token_flow.TokenValidated(result)))
      })
    _ -> effect.none()
  }
}

fn handle_accept_invite_authed(
  model: Model,
  user: User,
  bootstrap_fn: fn(Model) -> #(Model, Effect(Msg)),
  hydrate_fn: fn(Model) -> #(Model, Effect(Msg)),
  replace_url_fn: fn(Model) -> Effect(Msg),
) -> #(Model, Effect(Msg)) {
  let page = page_for_org_role(user.org_role)

  let model =
    update_core(model, fn(core) {
      CoreModel(..core, page: page, user: opt.Some(user), auth_checked: True)
    })

  let toast_fx =
    helpers_toast.toast_success(helpers_i18n.i18n_t(model, i18n_text.Welcome))

  let #(model, boot) = bootstrap_fn(model)
  let #(model, hyd_fx) = hydrate_fn(model)
  #(
    model,
    effect.batch([
      boot,
      hyd_fx,
      replace_url_fn(model),
      toast_fx,
    ]),
  )
}

fn page_for_org_role(role: org_role.OrgRole) -> Page {
  case role {
    org_role.Admin -> Admin
    _ -> Member
  }
}

fn handle_accept_invite_msg(
  model: Model,
  inner: accept_invite.Msg,
  bootstrap_fn: fn(Model) -> #(Model, Effect(Msg)),
  hydrate_fn: fn(Model) -> #(Model, Effect(Msg)),
  replace_url_fn: fn(Model) -> Effect(Msg),
) -> #(Model, Effect(Msg)) {
  let #(next_accept, action) =
    accept_invite.update(model.auth.accept_invite, inner)
  let model =
    update_auth(model, fn(auth) {
      auth_state.AuthModel(..auth, accept_invite: next_accept)
    })

  case action {
    accept_invite.NoOp -> #(model, effect.none())
    accept_invite.ValidateToken(_) -> #(model, accept_invite_effect(action))
    accept_invite.Register(token: token, password: password) -> #(
      model,
      api_auth.register_with_invite_link(token, password, fn(result) {
        auth_msg(auth_messages.AcceptInvite(token_flow.Completed(result)))
      }),
    )
    accept_invite.Authed(user) ->
      handle_accept_invite_authed(
        model,
        user,
        bootstrap_fn,
        hydrate_fn,
        replace_url_fn,
      )
  }
}

fn handle_reset_password_msg(
  model: Model,
  inner: reset_password.Msg,
  replace_url_fn: fn(Model) -> Effect(Msg),
) -> #(Model, Effect(Msg)) {
  let #(next_reset, action) =
    reset_password.update(model.auth.reset_password, inner)

  let model =
    update_auth(model, fn(auth) {
      auth_state.AuthModel(..auth, reset_password: next_reset)
    })

  case action {
    reset_password.NoOp -> #(model, effect.none())
    reset_password.ValidateToken(_) -> #(model, reset_password_effect(action))
    reset_password.Consume(token: token, password: password) -> #(
      model,
      api_auth.consume_password_reset_token(token, password, fn(result) {
        auth_msg(auth_messages.ResetPassword(token_flow.Completed(result)))
      }),
    )
    reset_password.GoToLogin -> {
      let model =
        update_auth(
          update_core(model, fn(core) { CoreModel(..core, page: Login) }),
          fn(auth) {
            auth_state.AuthModel(
              ..auth,
              login_password: "",
              login_error: opt.None,
            )
          },
        )
      let toast_fx =
        helpers_toast.toast_success(helpers_i18n.i18n_t(
          model,
          i18n_text.PasswordUpdated,
        ))

      #(model, effect.batch([replace_url_fn(model), toast_fx]))
    }
  }
}

// =============================================================================
// Auth Message Dispatcher
// =============================================================================

/// Updates the model for a message.
///
/// Example:
///   update(...)
pub fn update(
  model: Model,
  msg: auth_messages.Msg,
  bootstrap_fn: fn(Model) -> #(Model, Effect(Msg)),
  hydrate_fn: fn(Model) -> #(Model, Effect(Msg)),
  replace_url_fn: fn(Model) -> Effect(Msg),
) -> #(Model, Effect(Msg)) {
  case msg {
    auth_messages.LoginEmailChanged(email) ->
      handle_login_email_changed(model, email)
    auth_messages.LoginPasswordChanged(password) ->
      handle_login_password_changed(model, password)
    auth_messages.LoginSubmitted -> handle_login_submitted(model)
    auth_messages.LoginDomValuesRead(raw_email, raw_password) ->
      handle_login_dom_values_read(model, raw_email, raw_password)
    auth_messages.LoginFinished(Ok(user)) ->
      handle_login_finished_ok(
        model,
        user,
        bootstrap_fn,
        hydrate_fn,
        replace_url_fn,
      )
    auth_messages.LoginFinished(Error(err)) ->
      handle_login_finished_error(model, err)
    auth_messages.ForgotPasswordClicked -> handle_forgot_password_clicked(model)
    auth_messages.ForgotPasswordEmailChanged(email) ->
      handle_forgot_password_email_changed(model, email)
    auth_messages.ForgotPasswordSubmitted ->
      handle_forgot_password_submitted(model)
    auth_messages.ForgotPasswordFinished(Ok(reset)) ->
      handle_forgot_password_finished_ok(model, reset)
    auth_messages.ForgotPasswordFinished(Error(err)) ->
      handle_forgot_password_finished_error(model, err)
    auth_messages.ForgotPasswordCopyClicked ->
      handle_forgot_password_copy_clicked(model)
    auth_messages.ForgotPasswordCopyFinished(ok) ->
      handle_forgot_password_copy_finished(model, ok)
    auth_messages.ForgotPasswordDismissed ->
      handle_forgot_password_dismissed(model)
    auth_messages.LogoutClicked -> handle_logout_clicked(model)
    auth_messages.LogoutFinished(Ok(_)) ->
      handle_logout_finished_ok(model, replace_url_fn)
    auth_messages.LogoutFinished(Error(err)) ->
      handle_logout_finished_error(model, err, replace_url_fn)
    auth_messages.AcceptInvite(inner) ->
      handle_accept_invite_msg(
        model,
        inner,
        bootstrap_fn,
        hydrate_fn,
        replace_url_fn,
      )
    auth_messages.ResetPassword(inner) ->
      handle_reset_password_msg(model, inner, replace_url_fn)
  }
}

// =============================================================================
// Effects
// =============================================================================

fn read_login_values_effect() -> Effect(Msg) {
  effect.from(fn(dispatch) {
    let email = client_ffi.input_value("login-email")
    let password = client_ffi.input_value("login-password")
    dispatch(auth_msg(auth_messages.LoginDomValuesRead(email, password)))
    Nil
  })
}

fn copy_to_clipboard(text: String, callback: fn(Bool) -> Msg) -> Effect(Msg) {
  effect.from(fn(dispatch) {
    client_ffi.copy_to_clipboard(text, fn(ok) { dispatch(callback(ok)) })
    Nil
  })
}
