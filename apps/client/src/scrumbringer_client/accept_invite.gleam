import gleam/option
import gleam/string

import scrumbringer_client/api
import scrumbringer_domain/user.{type User}

pub type State {
  NoToken
  Validating
  Invalid(code: String, message: String)
  Ready(email: String)
  Registering(email: String)
  Done
}

pub type Model {
  Model(
    token: String,
    state: State,
    password: String,
    password_error: option.Option(String),
    submit_error: option.Option(String),
  )
}

pub type Msg {
  TokenValidated(api.ApiResult(String))
  PasswordChanged(String)
  Submitted
  Registered(api.ApiResult(User))
  ErrorDismissed
}

pub type Action {
  NoOp
  ValidateToken(String)
  Register(token: String, password: String)
  Authed(User)
}

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
              Model(
                ..model,
                state: Registering(email),
                submit_error: option.None,
              ),
              Register(token: model.token, password: model.password),
            )
          }
        }

        _ -> #(model, NoOp)
      }
    }

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
