import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None}
import gleam/result
import scrumbringer_server/services/api_tokens as token_service

pub type CreateApiTokenPayload {
  CreateApiTokenPayload(
    name: String,
    integration: String,
    project_id: Option(Int),
    scopes: List(token_service.Scope),
    expires_at: Option(String),
  )
}

pub type DecodeError {
  InvalidJson
  InvalidScope(String)
}

pub fn decode_create(
  data: Dynamic,
) -> Result(CreateApiTokenPayload, DecodeError) {
  let decoder = {
    use name <- decode.field("name", decode.string)
    use integration <- decode.field("integration", decode.string)
    use project_id <- decode.optional_field(
      "project_id",
      None,
      decode.optional(decode.int),
    )
    use scopes <- decode.field("scopes", decode.list(decode.string))
    use expires_at <- decode.optional_field(
      "expires_at",
      None,
      decode.optional(decode.string),
    )
    decode.success(#(name, integration, project_id, scopes, expires_at))
  }

  use raw <- result.try(
    decode.run(data, decoder)
    |> result.map_error(fn(_) { InvalidJson }),
  )
  let #(name, integration, project_id, raw_scopes, expires_at) = raw
  use scopes <- result.try(
    raw_scopes
    |> list.try_map(fn(scope) {
      token_service.parse_scope(scope)
      |> result.map_error(fn(_) { InvalidScope(scope) })
    }),
  )

  Ok(CreateApiTokenPayload(
    name: name,
    integration: integration,
    project_id: project_id,
    scopes: scopes,
    expires_at: expires_at,
  ))
}
