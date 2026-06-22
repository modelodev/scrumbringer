//// Authentication feature update handlers.
////
//// ## Mission
////
//// Handles auth-local state transitions for login, logout, password reset and
//// accept-invite flows.
////
//// ## Responsibilities
////
//// - Login form state and submission
//// - Forgot password local state
//// - Accept-invite and reset-password submodels
//// - API, DOM and clipboard effects at the auth boundary
////
//// ## Non-responsibilities
////
//// - User session assembly, page routing and toast presentation
//// - Root client model mutation

import gleam/option as opt
import gleam/string

import lustre/effect.{type Effect}

import domain/api_error.{type ApiError, type ApiResult}
import domain/user.{type User}
import scrumbringer_client/accept_invite
import scrumbringer_client/api/auth as api_auth
import scrumbringer_client/client_ffi
import scrumbringer_client/client_state/auth as auth_state
import scrumbringer_client/features/auth/msg as auth_messages
import scrumbringer_client/reset_password
import scrumbringer_client/token_flow

pub type Action {
  NoAction
  LoginSucceeded(User)
  LogoutSucceeded
  LogoutUnauthorized
  LogoutFailed
  AcceptInviteAuthed(User)
  PasswordResetDone
}

pub type Context(parent_msg) {
  Context(
    on_login_dom_values_read: fn(String, String) -> parent_msg,
    on_login_finished: fn(ApiResult(User)) -> parent_msg,
    on_forgot_password_finished: fn(ApiResult(api_auth.PasswordReset)) ->
      parent_msg,
    on_forgot_password_copy_finished: fn(Bool) -> parent_msg,
    on_logout_finished: fn(ApiResult(Nil)) -> parent_msg,
    on_accept_invite: fn(accept_invite.Msg) -> parent_msg,
    on_reset_password: fn(reset_password.Msg) -> parent_msg,
    email_and_password_required: String,
    email_required: String,
    invalid_credentials: String,
    copying: String,
    copied: String,
    copy_failed: String,
  )
}

// =============================================================================
// Login Handlers
// =============================================================================

fn handle_login_email_changed(
  model: auth_state.AuthModel,
  email: String,
) -> #(auth_state.AuthModel, Effect(parent_msg), Action) {
  #(auth_state.AuthModel(..model, login_email: email), effect.none(), NoAction)
}

fn handle_login_password_changed(
  model: auth_state.AuthModel,
  password: String,
) -> #(auth_state.AuthModel, Effect(parent_msg), Action) {
  #(
    auth_state.AuthModel(..model, login_password: password),
    effect.none(),
    NoAction,
  )
}

fn handle_login_submitted(
  model: auth_state.AuthModel,
  context: Context(parent_msg),
) -> #(auth_state.AuthModel, Effect(parent_msg), Action) {
  case model.login_in_flight {
    True -> #(model, effect.none(), NoAction)
    False -> #(
      auth_state.AuthModel(
        ..model,
        login_in_flight: True,
        login_error: opt.None,
      ),
      read_login_values_effect(context.on_login_dom_values_read),
      NoAction,
    )
  }
}

fn handle_login_dom_values_read(
  model: auth_state.AuthModel,
  raw_email: String,
  raw_password: String,
  context: Context(parent_msg),
) -> #(auth_state.AuthModel, Effect(parent_msg), Action) {
  let email = string.trim(raw_email)

  case email == "", raw_password == "" {
    True, _ ->
      login_validation_error(model, context.email_and_password_required)
    _, True ->
      login_validation_error(model, context.email_and_password_required)
    False, False -> {
      let model =
        auth_state.AuthModel(
          ..model,
          login_email: email,
          login_password: raw_password,
        )
      #(
        model,
        api_auth.login(email, raw_password, context.on_login_finished),
        NoAction,
      )
    }
  }
}

fn login_validation_error(
  model: auth_state.AuthModel,
  message: String,
) -> #(auth_state.AuthModel, Effect(parent_msg), Action) {
  #(
    auth_state.AuthModel(
      ..model,
      login_in_flight: False,
      login_error: opt.Some(message),
    ),
    effect.none(),
    NoAction,
  )
}

fn handle_login_finished_ok(
  model: auth_state.AuthModel,
  user: User,
) -> #(auth_state.AuthModel, Effect(parent_msg), Action) {
  #(
    auth_state.AuthModel(..model, login_in_flight: False, login_password: ""),
    effect.none(),
    LoginSucceeded(user),
  )
}

fn handle_login_finished_error(
  model: auth_state.AuthModel,
  err: ApiError,
  context: Context(parent_msg),
) -> #(auth_state.AuthModel, Effect(parent_msg), Action) {
  let message = case err.status {
    401 | 403 -> context.invalid_credentials
    _ -> err.message
  }

  #(
    auth_state.AuthModel(
      ..model,
      login_in_flight: False,
      login_error: opt.Some(message),
    ),
    effect.none(),
    NoAction,
  )
}

// =============================================================================
// Forgot Password Handlers
// =============================================================================

fn handle_forgot_password_clicked(
  model: auth_state.AuthModel,
) -> #(auth_state.AuthModel, Effect(parent_msg), Action) {
  let open = !model.forgot_password_open

  #(
    auth_state.AuthModel(
      ..model,
      forgot_password_open: open,
      forgot_password_in_flight: False,
      forgot_password_result: opt.None,
      forgot_password_error: opt.None,
      forgot_password_copy_status: opt.None,
    ),
    effect.none(),
    NoAction,
  )
}

fn handle_forgot_password_email_changed(
  model: auth_state.AuthModel,
  email: String,
) -> #(auth_state.AuthModel, Effect(parent_msg), Action) {
  #(
    auth_state.AuthModel(
      ..model,
      forgot_password_email: email,
      forgot_password_error: opt.None,
      forgot_password_copy_status: opt.None,
    ),
    effect.none(),
    NoAction,
  )
}

fn handle_forgot_password_submitted(
  model: auth_state.AuthModel,
  context: Context(parent_msg),
) -> #(auth_state.AuthModel, Effect(parent_msg), Action) {
  case model.forgot_password_in_flight {
    True -> #(model, effect.none(), NoAction)

    False -> {
      let email = string.trim(model.forgot_password_email)
      case email == "" {
        True -> #(
          auth_state.AuthModel(
            ..model,
            forgot_password_error: opt.Some(context.email_required),
          ),
          effect.none(),
          NoAction,
        )

        False -> #(
          auth_state.AuthModel(
            ..model,
            forgot_password_in_flight: True,
            forgot_password_error: opt.None,
            forgot_password_result: opt.None,
            forgot_password_copy_status: opt.None,
          ),
          api_auth.request_password_reset(
            email,
            context.on_forgot_password_finished,
          ),
          NoAction,
        )
      }
    }
  }
}

fn handle_forgot_password_finished_ok(
  model: auth_state.AuthModel,
  reset: api_auth.PasswordReset,
) -> #(auth_state.AuthModel, Effect(parent_msg), Action) {
  #(
    auth_state.AuthModel(
      ..model,
      forgot_password_in_flight: False,
      forgot_password_result: opt.Some(reset),
      forgot_password_error: opt.None,
      forgot_password_copy_status: opt.None,
    ),
    effect.none(),
    NoAction,
  )
}

fn handle_forgot_password_finished_error(
  model: auth_state.AuthModel,
  err: ApiError,
) -> #(auth_state.AuthModel, Effect(parent_msg), Action) {
  #(
    auth_state.AuthModel(
      ..model,
      forgot_password_in_flight: False,
      forgot_password_error: opt.Some(err.message),
    ),
    effect.none(),
    NoAction,
  )
}

fn handle_forgot_password_copy_clicked(
  model: auth_state.AuthModel,
  context: Context(parent_msg),
) -> #(auth_state.AuthModel, Effect(parent_msg), Action) {
  case model.forgot_password_result {
    opt.None -> #(model, effect.none(), NoAction)

    opt.Some(reset) -> {
      let origin = client_ffi.location_origin()
      let text = origin <> reset.url_path

      #(
        auth_state.AuthModel(
          ..model,
          forgot_password_copy_status: opt.Some(context.copying),
        ),
        copy_to_clipboard(text, context.on_forgot_password_copy_finished),
        NoAction,
      )
    }
  }
}

fn handle_forgot_password_copy_finished(
  model: auth_state.AuthModel,
  ok: Bool,
  context: Context(parent_msg),
) -> #(auth_state.AuthModel, Effect(parent_msg), Action) {
  let message = case ok {
    True -> context.copied
    False -> context.copy_failed
  }

  #(
    auth_state.AuthModel(
      ..model,
      forgot_password_copy_status: opt.Some(message),
    ),
    effect.none(),
    NoAction,
  )
}

fn handle_forgot_password_dismissed(
  model: auth_state.AuthModel,
) -> #(auth_state.AuthModel, Effect(parent_msg), Action) {
  #(
    auth_state.AuthModel(
      ..model,
      forgot_password_error: opt.None,
      forgot_password_copy_status: opt.None,
      forgot_password_result: opt.None,
    ),
    effect.none(),
    NoAction,
  )
}

// =============================================================================
// Logout Handlers
// =============================================================================

fn handle_logout_clicked(
  model: auth_state.AuthModel,
  context: Context(parent_msg),
) -> #(auth_state.AuthModel, Effect(parent_msg), Action) {
  #(model, api_auth.logout(context.on_logout_finished), NoAction)
}

fn handle_logout_finished_ok(
  model: auth_state.AuthModel,
) -> #(auth_state.AuthModel, Effect(parent_msg), Action) {
  #(model, effect.none(), LogoutSucceeded)
}

fn handle_logout_finished_error(
  model: auth_state.AuthModel,
  err: ApiError,
) -> #(auth_state.AuthModel, Effect(parent_msg), Action) {
  case err.status == 401 {
    True -> #(model, effect.none(), LogoutUnauthorized)
    False -> #(model, effect.none(), LogoutFailed)
  }
}

// =============================================================================
// Accept Invite / Reset Password
// =============================================================================

pub fn accept_invite_effect(
  action: accept_invite.Action,
  context: Context(parent_msg),
) -> Effect(parent_msg) {
  case action {
    accept_invite.ValidateToken(token) ->
      api_auth.validate_invite_link_token(token, fn(result) {
        context.on_accept_invite(token_flow.TokenValidated(result))
      })
    _ -> effect.none()
  }
}

pub fn reset_password_effect(
  action: reset_password.Action,
  context: Context(parent_msg),
) -> Effect(parent_msg) {
  case action {
    reset_password.ValidateToken(token) ->
      api_auth.validate_password_reset_token(token, fn(result) {
        context.on_reset_password(token_flow.TokenValidated(result))
      })
    _ -> effect.none()
  }
}

fn handle_accept_invite_msg(
  model: auth_state.AuthModel,
  inner: accept_invite.Msg,
  context: Context(parent_msg),
) -> #(auth_state.AuthModel, Effect(parent_msg), Action) {
  let #(next_accept, action) = accept_invite.update(model.accept_invite, inner)
  let model = auth_state.AuthModel(..model, accept_invite: next_accept)

  case action {
    accept_invite.NoOp -> #(model, effect.none(), NoAction)
    accept_invite.ValidateToken(_) -> #(
      model,
      accept_invite_effect(action, context),
      NoAction,
    )
    accept_invite.Register(token: token, password: password) -> #(
      model,
      api_auth.register_with_invite_link(token, password, fn(result) {
        context.on_accept_invite(token_flow.Finished(result))
      }),
      NoAction,
    )
    accept_invite.Authed(user) -> #(
      model,
      effect.none(),
      AcceptInviteAuthed(user),
    )
  }
}

fn handle_reset_password_msg(
  model: auth_state.AuthModel,
  inner: reset_password.Msg,
  context: Context(parent_msg),
) -> #(auth_state.AuthModel, Effect(parent_msg), Action) {
  let #(next_reset, action) = reset_password.update(model.reset_password, inner)

  let model = auth_state.AuthModel(..model, reset_password: next_reset)

  case action {
    reset_password.NoOp -> #(model, effect.none(), NoAction)
    reset_password.ValidateToken(_) -> #(
      model,
      reset_password_effect(action, context),
      NoAction,
    )
    reset_password.Consume(token: token, password: password) -> #(
      model,
      api_auth.consume_password_reset_token(token, password, fn(result) {
        context.on_reset_password(token_flow.Finished(result))
      }),
      NoAction,
    )
    reset_password.GoToLogin -> #(
      auth_state.AuthModel(..model, login_password: "", login_error: opt.None),
      effect.none(),
      PasswordResetDone,
    )
  }
}

// =============================================================================
// Auth Message Dispatcher
// =============================================================================

pub fn update(
  model: auth_state.AuthModel,
  msg: auth_messages.Msg,
  context: Context(parent_msg),
) -> #(auth_state.AuthModel, Effect(parent_msg), Action) {
  case msg {
    auth_messages.LoginEmailChanged(email) ->
      handle_login_email_changed(model, email)
    auth_messages.LoginPasswordChanged(password) ->
      handle_login_password_changed(model, password)
    auth_messages.LoginSubmitted -> handle_login_submitted(model, context)
    auth_messages.LoginDomValuesRead(raw_email, raw_password) ->
      handle_login_dom_values_read(model, raw_email, raw_password, context)
    auth_messages.LoginFinished(Ok(user)) ->
      handle_login_finished_ok(model, user)
    auth_messages.LoginFinished(Error(err)) ->
      handle_login_finished_error(model, err, context)
    auth_messages.ForgotPasswordClicked -> handle_forgot_password_clicked(model)
    auth_messages.ForgotPasswordEmailChanged(email) ->
      handle_forgot_password_email_changed(model, email)
    auth_messages.ForgotPasswordSubmitted ->
      handle_forgot_password_submitted(model, context)
    auth_messages.ForgotPasswordFinished(Ok(reset)) ->
      handle_forgot_password_finished_ok(model, reset)
    auth_messages.ForgotPasswordFinished(Error(err)) ->
      handle_forgot_password_finished_error(model, err)
    auth_messages.ForgotPasswordCopyClicked ->
      handle_forgot_password_copy_clicked(model, context)
    auth_messages.ForgotPasswordCopyFinished(ok) ->
      handle_forgot_password_copy_finished(model, ok, context)
    auth_messages.ForgotPasswordDismissed ->
      handle_forgot_password_dismissed(model)
    auth_messages.LogoutClicked -> handle_logout_clicked(model, context)
    auth_messages.LogoutFinished(Ok(_)) -> handle_logout_finished_ok(model)
    auth_messages.LogoutFinished(Error(err)) ->
      handle_logout_finished_error(model, err)
    auth_messages.AcceptInvite(inner) ->
      handle_accept_invite_msg(model, inner, context)
    auth_messages.ResetPassword(inner) ->
      handle_reset_password_msg(model, inner, context)
  }
}

// =============================================================================
// Effects
// =============================================================================

fn read_login_values_effect(
  callback: fn(String, String) -> parent_msg,
) -> Effect(parent_msg) {
  effect.from(fn(dispatch) {
    let email = client_ffi.input_value("login-email")
    let password = client_ffi.input_value("login-password")
    dispatch(callback(email, password))
    Nil
  })
}

fn copy_to_clipboard(
  text: String,
  callback: fn(Bool) -> parent_msg,
) -> Effect(parent_msg) {
  effect.from(fn(dispatch) {
    client_ffi.copy_to_clipboard(text, fn(ok) { dispatch(callback(ok)) })
    Nil
  })
}
