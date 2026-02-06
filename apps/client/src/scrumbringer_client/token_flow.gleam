//// Generic TEA flow for token-based auth pages.
////
//// Handles validating tokens, collecting passwords, and submitting
//// actions for accept-invite and reset-password flows.

import gleam/option
import gleam/string

import domain/api_error.{type ApiError, type ApiResult}

/// Token validation and submission state.
pub type State {
  NoToken
  Validating
  Invalid(code: String, message: String)
  Ready(email: String)
  Submitting(email: String)
  Done
}

/// Component model for token-based forms.
pub type Model {
  Model(
    token: String,
    state: State,
    password: String,
    password_error: option.Option(String),
    submit_error: option.Option(String),
  )
}

/// Messages handled by this module.
pub type Msg(result) {
  TokenValidated(ApiResult(String))
  PasswordChanged(String)
  Submitted
  Completed(ApiResult(result))
  ErrorDismissed
}

/// Side effects to perform after an update.
pub type Action(result) {
  NoOp
  ValidateToken(String)
  Submit(token: String, password: String)
  Succeeded(result)
}

/// Initializes the model, triggering token validation if provided.
pub fn init(token: String) -> #(Model, Action(result)) {
  case token {
    "" -> #(
      Model(
        token: "",
        state: NoToken,
        password: "",
        password_error: option.None,
        submit_error: option.None,
      ),
      NoOp,
    )

    _ -> #(
      Model(
        token: token,
        state: Validating,
        password: "",
        password_error: option.None,
        submit_error: option.None,
      ),
      ValidateToken(token),
    )
  }
}

/// Handles messages and returns updated model with any actions.
pub fn update(
  model: Model,
  msg: Msg(result),
  submit_error_state: fn(String, ApiError) -> State,
) -> #(Model, Action(result)) {
  case msg {
    TokenValidated(Ok(email)) -> #(
      Model(
        ..model,
        state: Ready(email),
        submit_error: option.None,
        password_error: option.None,
      ),
      NoOp,
    )

    TokenValidated(Error(err)) -> #(
      Model(
        ..model,
        state: Invalid(code: err.code, message: err.message),
        submit_error: option.None,
        password_error: option.None,
      ),
      NoOp,
    )

    PasswordChanged(value) -> #(
      Model(
        ..model,
        password: value,
        password_error: option.None,
        submit_error: option.None,
      ),
      NoOp,
    )

    Submitted -> handle_submitted(model)

    Completed(Ok(result)) -> #(Model(..model, state: Done), Succeeded(result))

    Completed(Error(err)) ->
      handle_completed_error(model, err, submit_error_state)

    ErrorDismissed -> #(Model(..model, submit_error: option.None), NoOp)
  }
}

fn handle_submitted(model: Model) -> #(Model, Action(result)) {
  case model.state {
    Ready(email) -> handle_ready_submit(model, email)
    _ -> #(model, NoOp)
  }
}

fn handle_ready_submit(model: Model, email: String) -> #(Model, Action(result)) {
  case string.length(model.password) < 12 {
    True -> #(
      Model(
        ..model,
        password_error: option.Some("Password must be at least 12 characters"),
      ),
      NoOp,
    )

    False -> #(
      Model(..model, state: Submitting(email), submit_error: option.None),
      Submit(token: model.token, password: model.password),
    )
  }
}

fn handle_completed_error(
  model: Model,
  err: ApiError,
  submit_error_state: fn(String, ApiError) -> State,
) -> #(Model, Action(result)) {
  case model.state {
    Submitting(email) -> #(
      Model(
        ..model,
        state: submit_error_state(email, err),
        submit_error: option.Some(err.message),
      ),
      NoOp,
    )

    _ -> #(model, NoOp)
  }
}
