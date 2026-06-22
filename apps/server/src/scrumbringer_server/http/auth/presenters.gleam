//// JSON presenters for auth endpoints.

import domain/org_role
import gleam/json
import scrumbringer_server/use_case/store_state.{type StoredUser}

pub fn user(user: StoredUser) -> json.Json {
  json.object([
    #("id", json.int(user.id)),
    #("email", json.string(user.email)),
    #("org_id", json.int(user.org_id)),
    #("org_role", json.string(org_role.to_string(user.org_role))),
    #("created_at", json.string(user.created_at)),
  ])
}

pub fn user_response(value: StoredUser) -> json.Json {
  json.object([#("user", user(value))])
}

pub fn token_email(email: String) -> json.Json {
  json.object([#("email", json.string(email))])
}
