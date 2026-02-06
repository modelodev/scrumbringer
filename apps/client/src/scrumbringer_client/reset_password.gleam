//// TEA module for the password reset page.
////
//// Handles the flow of validating a reset token, collecting
//// a new password, and updating the user's credentials.

import domain/api_error.{type ApiError}
import scrumbringer_client/token_flow

/// Token validation and password reset state.
pub type State =
  token_flow.State

/// Component model for the reset-password form.
pub type Model =
  token_flow.Model

/// Messages handled by this module.
pub type Msg =
  token_flow.Msg(Nil)

/// Side effects to perform after an update.
pub type Action {
  NoOp
  ValidateToken(String)
  Consume(token: String, password: String)
  GoToLogin
}

/// Initializes the model, triggering token validation if provided.
pub fn init(token: String) -> #(Model, Action) {
  let #(model, action) = token_flow.init(token)
  #(model, map_action(action))
}

/// Handles messages and returns updated model with any actions.
pub fn update(model: Model, msg: Msg) -> #(Model, Action) {
  let #(next, action) = token_flow.update(model, msg, submit_error_state)
  #(next, map_action(action))
}

fn map_action(action: token_flow.Action(Nil)) -> Action {
  case action {
    token_flow.NoOp -> NoOp
    token_flow.ValidateToken(token) -> ValidateToken(token)
    token_flow.Submit(token: token, password: password) ->
      Consume(token: token, password: password)
    token_flow.Succeeded(_) -> GoToLogin
  }
}

fn submit_error_state(email: String, err: ApiError) -> token_flow.State {
  case err.code {
    "RESET_TOKEN_INVALID" | "RESET_TOKEN_USED" ->
      token_flow.Invalid(code: err.code, message: err.message)
    _ -> token_flow.Ready(email)
  }
}
