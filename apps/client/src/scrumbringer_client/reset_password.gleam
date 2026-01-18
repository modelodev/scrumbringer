//// TEA module for the password reset page.
////
//// Handles the flow of validating a reset token, collecting
//// a new password, and updating the user's credentials.

import gleam/option
import gleam/string

import domain/api_error.{type ApiResult}

/// Token validation and password reset state.
pub type State {
  NoToken
  Validating
  Invalid(code: String, message: String)
  Ready(email: String)
  Consuming(email: String)
  Done
}

/// Component model for the reset-password form.
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
  Consumed(ApiResult(Nil))
  ErrorDismissed
}

/// Side effects to perform after an update.
pub type Action {
  NoOp
  ValidateToken(String)
  Consume(token: String, password: String)
  GoToLogin
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

    Submitted -> {
      case model.state {
        Ready(email) -> {
          case string.length(model.password) < 12 {
            True -> #(
              Model(
                ..model,
                password_error: option.Some(
                  "Password must be at least 12 characters",
                ),
              ),
              NoOp,
            )

            False -> #(
              Model(..model, state: Consuming(email), submit_error: option.None),
              Consume(token: model.token, password: model.password),
            )
          }
        }

        _ -> #(model, NoOp)
      }
    }

    Consumed(Ok(_)) -> #(Model(..model, state: Done), GoToLogin)

    Consumed(Error(err)) -> {
      case model.state {
        Consuming(email) -> {
          let new_state = case err.code {
            "RESET_TOKEN_INVALID" | "RESET_TOKEN_USED" ->
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
