import domain/org_role
import gleam/json
import scrumbringer_server/services/integration_users.{
  type IntegrationUser, IntegrationUser,
}

pub fn integration_users_response(users: List(IntegrationUser)) -> json.Json {
  json.object([#("integration_users", json.array(users, of: integration_user))])
}

pub fn integration_user_response(user: IntegrationUser) -> json.Json {
  json.object([#("integration_user", integration_user(user))])
}

pub fn integration_user(user: IntegrationUser) -> json.Json {
  let IntegrationUser(
    id: id,
    email: email,
    org_role: role,
    created_at: created_at,
    active_token_count: active_token_count,
  ) = user

  json.object([
    #("id", json.int(id)),
    #("email", json.string(email)),
    #("org_role", json.string(org_role.to_string(role))),
    #("created_at", json.string(created_at)),
    #("active_token_count", json.int(active_token_count)),
  ])
}
