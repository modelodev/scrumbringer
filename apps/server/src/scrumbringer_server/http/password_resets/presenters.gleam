//// JSON presenters for password reset endpoints.

import gleam/json

pub fn reset(token: String, url_path: String) -> json.Json {
  json.object([
    #(
      "reset",
      json.object([
        #("token", json.string(token)),
        #("url_path", json.string(url_path)),
      ]),
    ),
  ])
}

pub fn token_email(email: String) -> json.Json {
  json.object([#("email", json.string(email))])
}
