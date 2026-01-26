//// TEA module for the accept-invite page.
////
//// Handles the flow of validating an invite token, collecting
//// a password, and registering the new user account.

import gleam/option
import gleam/string

import domain/api_error.{type ApiResult}
import domain/user.{type User}

/// Token validation and registration state.
pub type State {
  NoToken
  Validating
  Invalid(code: String, message: String)
  Ready(email: String)
  Registering(email: String)
  Done
}

/// Component model for the accept-invite form.
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
pub type Msg {
  TokenValidated(ApiResult(String))
  PasswordChanged(String)
  Submitted
  Registered(ApiResult(User))
  ErrorDismissed
}

/// Side effects to perform after an update.
pub type Action {
  NoOp
  ValidateToken(String)
  Register(token: String, password: String)
  Authed(User)
}

/// Initializes the model, triggering token validation if provided.
pub fn init(token: String) -> #(Model, Action) {
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

// Justification: nested case improves clarity for branching logic.
/// Handles messages and returns updated model with any actions.
pub fn update(model: Model, msg: Msg) -> #(Model, Action) {
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

    Registered(Ok(user)) -> #(Model(..model, state: Done), Authed(user))

    Registered(Error(err)) -> {
      case model.state {
        Registering(email) -> {
          let new_state = case err.code {
            "INVITE_INVALID" | "INVITE_USED" | "INVITE_REQUIRED" ->
              Invalid(code: err.code, message: err.message)
            _ -> Ready(email)
          }

          #(
            Model(
              ..model,
              state: new_state,
              submit_error: option.Some(err.message),
            ),
            NoOp,
          )
        }

        _ -> #(model, NoOp)
      }
    }

    ErrorDismissed -> #(Model(..model, submit_error: option.None), NoOp)
  }
}

fn handle_submitted(model: Model) -> #(Model, Effect) {
  case model.state {
    Ready(email) -> handle_ready_submit(model, email)
    _ -> #(model, NoOp)
  }
}

fn handle_ready_submit(model: Model, email: String) -> #(Model, Effect) {
  case string.length(model.password) < 12 {
    True -> #(
      Model(
        ..model,
        password_error: option.Some("Password must be at least 12 characters"),
      ),
      NoOp,
    )

    False -> #(
      Model(..model, state: Registering(email), submit_error: option.None),
      Register(token: model.token, password: model.password),
    )
  }
}
