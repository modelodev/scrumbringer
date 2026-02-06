//// TEA module for the accept-invite page.
////
//// Handles the flow of validating an invite token, collecting
//// a password, and registering the new user account.

import domain/api_error.{type ApiError}
import domain/user.{type User}
import scrumbringer_client/token_flow

/// Token validation and registration state.
pub type State =
  token_flow.State

/// Component model for the accept-invite form.
pub type Model =
  token_flow.Model

/// Messages handled by this module.
pub type Msg =
  token_flow.Msg(User)

/// Side effects to perform after an update.
pub type Action {
  NoOp
  ValidateToken(String)
  Register(token: String, password: String)
  Authed(User)
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

fn map_action(action: token_flow.Action(User)) -> Action {
  case action {
    token_flow.NoOp -> NoOp
    token_flow.ValidateToken(token) -> ValidateToken(token)
    token_flow.Submit(token: token, password: password) ->
      Register(token: token, password: password)
    token_flow.Succeeded(user) -> Authed(user)
  }
}

fn submit_error_state(email: String, err: ApiError) -> token_flow.State {
  case err.code {
    "INVITE_INVALID" | "INVITE_USED" | "INVITE_REQUIRED" ->
      token_flow.Invalid(code: err.code, message: err.message)
    _ -> token_flow.Ready(email)
  }
}
