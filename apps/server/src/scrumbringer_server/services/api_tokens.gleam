//// API token storage and verification.
////
//// Tokens are opaque high-entropy Bearer credentials. Only their SHA-256 hash
//// is persisted; the full token is returned once at creation time.

import gleam/bit_array
import gleam/crypto
import gleam/dynamic/decode
import gleam/http
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import pog
import scrumbringer_server/services/integration_users
import scrumbringer_server/services/persisted_field

pub const token_prefix = "sbt"

pub type Resource {
  Projects
  Tasks
  Cards
  Notes
  Milestones
}

pub type Access {
  Read
  Write
}

pub type Scope {
  Scope(resource: Resource, access: Access)
}

pub type ApiToken {
  ApiToken(
    id: Int,
    org_id: Int,
    integration_user_id: Int,
    project_id: Option(Int),
    name: String,
    public_id: String,
    scopes: List(Scope),
    created_at: String,
    last_used_at: Option(String),
    expires_at: Option(String),
    revoked_at: Option(String),
    expired: Bool,
  )
}

pub type CreatedToken {
  CreatedToken(token: ApiToken, bearer: String)
}

pub type VerifiedToken {
  VerifiedToken(
    token_id: Int,
    integration_user_id: Int,
    org_id: Int,
    project_id: Option(Int),
    scopes: List(Scope),
  )
}

pub type ApiTokenError {
  InvalidBearer
  InvalidScope(String)
  NameRequired
  EmptyScopes
  IntegrationUserRequired
  IntegrationUserNotFound
  IntegrationUnavailable
  ProjectNotFound
  ProjectAccessRequired
  InvalidExpiresAt
  TokenNotFound
  TokenExpired
  TokenRevoked
  DbError(pog.QueryError)
}

type TokenRow {
  TokenRow(
    id: Int,
    org_id: Int,
    integration_user_id: Int,
    project_id: Option(Int),
    name: String,
    public_id: String,
    token_hash: String,
    created_at: String,
    last_used_at: Option(String),
    expires_at: Option(String),
    revoked_at: Option(String),
    expired: Bool,
  )
}

pub fn create(
  db: pog.Connection,
  org_id: Int,
  integration_user_id: Int,
  project_id: Option(Int),
  created_by: Int,
  name: String,
  scopes: List(Scope),
  expires_at: Option(String),
) -> Result(CreatedToken, ApiTokenError) {
  use name <- result.try(validate_name(name))
  use scopes <- result.try(validate_scopes(scopes))
  use expires_at <- result.try(validate_expires_at(expires_at))
  use Nil <- result.try(ensure_integration_user(db, org_id, integration_user_id))
  use Nil <- result.try(ensure_project_access(
    db,
    org_id,
    integration_user_id,
    project_id,
  ))

  let public_id = random_token_part(12)
  let secret = random_token_part(32)
  let bearer = token_prefix <> "_" <> public_id <> "_" <> secret
  let hash = hash_token(bearer)

  pog.transaction(db, fn(tx) {
    use token_id <- result.try(insert_token(
      tx,
      org_id,
      integration_user_id,
      project_id,
      created_by,
      name,
      public_id,
      hash,
      expires_at,
    ))
    use Nil <- result.try(insert_scopes(tx, token_id, scopes))
    use token <- result.try(get(tx, token_id))

    Ok(CreatedToken(token: token, bearer: bearer))
  })
  |> result.map_error(transaction_error_to_api_token_error)
}

pub fn create_for_integration(
  db: pog.Connection,
  org_id: Int,
  integration: String,
  project_id: Option(Int),
  created_by: Int,
  name: String,
  scopes: List(Scope),
  expires_at: Option(String),
) -> Result(CreatedToken, ApiTokenError) {
  use name <- result.try(validate_name(name))
  use scopes <- result.try(validate_scopes(scopes))
  use expires_at <- result.try(validate_expires_at(expires_at))

  let integration = string.trim(integration)

  pog.transaction(db, fn(tx) {
    use integration_user <- result.try(
      integration_users.find_or_create(tx, org_id, integration)
      |> result.map_error(integration_user_error_to_api_token_error),
    )
    let integration_users.IntegrationUser(id: integration_user_id, ..) =
      integration_user

    use Nil <- result.try(ensure_project_exists(tx, org_id, project_id))
    use Nil <- result.try(ensure_project_manager_membership(
      tx,
      integration_user_id,
      project_id,
    ))

    let public_id = random_token_part(12)
    let secret = random_token_part(32)
    let bearer = token_prefix <> "_" <> public_id <> "_" <> secret
    let hash = hash_token(bearer)

    use token_id <- result.try(insert_token(
      tx,
      org_id,
      integration_user_id,
      project_id,
      created_by,
      name,
      public_id,
      hash,
      expires_at,
    ))
    use Nil <- result.try(insert_scopes(tx, token_id, scopes))
    use token <- result.try(get(tx, token_id))

    Ok(CreatedToken(token: token, bearer: bearer))
  })
  |> result.map_error(transaction_error_to_api_token_error)
}

pub fn verify_bearer(
  db: pog.Connection,
  bearer: String,
) -> Result(VerifiedToken, ApiTokenError) {
  use public_id <- result.try(public_id_from_bearer(bearer))
  use row <- result.try(find_by_public_id(db, public_id))
  use Nil <- result.try(validate_token_state(row))

  case
    crypto.secure_compare(<<row.token_hash:utf8>>, <<hash_token(bearer):utf8>>)
  {
    False -> Error(InvalidBearer)
    True -> {
      use scopes <- result.try(list_scopes(db, row.id))
      Ok(VerifiedToken(
        token_id: row.id,
        integration_user_id: row.integration_user_id,
        org_id: row.org_id,
        project_id: row.project_id,
        scopes: scopes,
      ))
    }
  }
}

pub fn list_for_org(
  db: pog.Connection,
  org_id: Int,
) -> Result(List(ApiToken), ApiTokenError) {
  use rows <- result.try(
    query_token_rows(
      db,
      "where t.org_id = $1 order by t.created_at desc, t.id desc",
      [pog.int(org_id)],
    ),
  )

  rows
  |> list.try_map(fn(row) { token_from_row(db, row) })
}

pub fn revoke(
  db: pog.Connection,
  org_id: Int,
  token_id: Int,
) -> Result(Nil, ApiTokenError) {
  use returned <- result.try(
    pog.query(
      "update api_tokens set revoked_at = coalesce(revoked_at, now()) where id = $1 and org_id = $2 returning 1",
    )
    |> pog.parameter(pog.int(token_id))
    |> pog.parameter(pog.int(org_id))
    |> pog.returning(persisted_field.int_decoder())
    |> pog.execute(db)
    |> result.map_error(DbError),
  )

  case returned.rows {
    [] -> Error(TokenNotFound)
    _ -> Ok(Nil)
  }
}

pub fn record_use(
  db: pog.Connection,
  token_id: Int,
) -> Result(Nil, ApiTokenError) {
  pog.query("update api_tokens set last_used_at = now() where id = $1")
  |> pog.parameter(pog.int(token_id))
  |> pog.execute(db)
  |> result.map(fn(_) { Nil })
  |> result.map_error(DbError)
}

pub fn record_audit(
  db: pog.Connection,
  token_id: Option(Int),
  ip: Option(String),
  method: http.Method,
  endpoint: String,
  status: Int,
) -> Result(Nil, ApiTokenError) {
  pog.query(
    "insert into api_token_audit_log (token_id, ip, method, endpoint, status) values ($1, $2, $3, $4, $5)",
  )
  |> pog.parameter(pog.nullable(pog.int, token_id))
  |> pog.parameter(pog.nullable(pog.text, ip))
  |> pog.parameter(pog.text(method_to_string(method)))
  |> pog.parameter(pog.text(endpoint))
  |> pog.parameter(pog.int(status))
  |> pog.execute(db)
  |> result.map(fn(_) { Nil })
  |> result.map_error(DbError)
}

pub fn token_id_for_bearer_public_id(
  db: pog.Connection,
  bearer: String,
) -> Result(Option(Int), ApiTokenError) {
  case public_id_from_bearer(bearer) {
    Error(_) -> Ok(None)
    Ok(public_id) -> {
      let decoder = {
        use id <- decode.field(0, decode.int)
        decode.success(id)
      }

      use returned <- result.try(
        pog.query("select id from api_tokens where public_id = $1")
        |> pog.parameter(pog.text(public_id))
        |> pog.returning(decoder)
        |> pog.execute(db)
        |> result.map_error(DbError),
      )

      case returned.rows {
        [id, ..] -> Ok(Some(id))
        [] -> Ok(None)
      }
    }
  }
}

pub fn has_scope(token: VerifiedToken, required: Scope) -> Bool {
  list.contains(token.scopes, required)
}

pub fn parse_scope(value: String) -> Result(Scope, ApiTokenError) {
  case string.split(value, ":") {
    [resource, access] -> {
      use resource <- result.try(parse_resource(resource))
      use access <- result.try(parse_access(access))
      let scope = Scope(resource: resource, access: access)
      case is_supported_scope(scope) {
        True -> Ok(scope)
        False -> Error(InvalidScope(value))
      }
    }

    _ -> Error(InvalidScope(value))
  }
}

pub fn supported_scopes() -> List(Scope) {
  [
    Scope(Projects, Read),
    Scope(Tasks, Read),
    Scope(Tasks, Write),
    Scope(Cards, Read),
    Scope(Cards, Write),
    Scope(Notes, Read),
    Scope(Notes, Write),
    Scope(Milestones, Read),
    Scope(Milestones, Write),
  ]
}

pub fn supported_scope_strings() -> List(String) {
  supported_scopes()
  |> list.map(scope_to_string)
}

pub fn scope_to_string(scope: Scope) -> String {
  resource_to_string(scope.resource) <> ":" <> access_to_string(scope.access)
}

pub fn resource_to_string(resource: Resource) -> String {
  case resource {
    Projects -> "projects"
    Tasks -> "tasks"
    Cards -> "cards"
    Notes -> "notes"
    Milestones -> "milestones"
  }
}

pub fn access_to_string(access: Access) -> String {
  case access {
    Read -> "read"
    Write -> "write"
  }
}

pub fn public_id_from_bearer(bearer: String) -> Result(String, ApiTokenError) {
  case string.split(bearer, "_") {
    ["sbt", public_id, secret] if public_id != "" && secret != "" ->
      Ok(public_id)
    _ -> Error(InvalidBearer)
  }
}

pub fn hash_token(token: String) -> String {
  crypto.hash(crypto.Sha256, <<token:utf8>>)
  |> bit_array.base64_url_encode(False)
}

fn get(db: pog.Connection, token_id: Int) -> Result(ApiToken, ApiTokenError) {
  use row <- result.try(find_by_id(db, token_id))
  token_from_row(db, row)
}

fn token_from_row(
  db: pog.Connection,
  row: TokenRow,
) -> Result(ApiToken, ApiTokenError) {
  use scopes <- result.try(list_scopes(db, row.id))
  Ok(ApiToken(
    id: row.id,
    org_id: row.org_id,
    integration_user_id: row.integration_user_id,
    project_id: row.project_id,
    name: row.name,
    public_id: row.public_id,
    scopes: scopes,
    created_at: row.created_at,
    last_used_at: row.last_used_at,
    expires_at: row.expires_at,
    revoked_at: row.revoked_at,
    expired: row.expired,
  ))
}

fn validate_name(name: String) -> Result(String, ApiTokenError) {
  let trimmed = string.trim(name)
  case trimmed {
    "" -> Error(NameRequired)
    _ -> Ok(trimmed)
  }
}

fn validate_scopes(scopes: List(Scope)) -> Result(List(Scope), ApiTokenError) {
  case scopes {
    [] -> Error(EmptyScopes)
    _ ->
      scopes
      |> unique_scopes
      |> list.try_map(fn(scope) {
        case is_supported_scope(scope) {
          True -> Ok(scope)
          False -> Error(InvalidScope(scope_to_string(scope)))
        }
      })
  }
}

fn unique_scopes(scopes: List(Scope)) -> List(Scope) {
  unique_scopes_loop(scopes, [])
}

fn unique_scopes_loop(scopes: List(Scope), kept: List(Scope)) -> List(Scope) {
  case scopes {
    [] -> list.reverse(kept)
    [scope, ..rest] ->
      case list.contains(kept, scope) {
        True -> unique_scopes_loop(rest, kept)
        False -> unique_scopes_loop(rest, [scope, ..kept])
      }
  }
}

fn validate_expires_at(
  expires_at: Option(String),
) -> Result(Option(Timestamp), ApiTokenError) {
  case expires_at {
    None -> Ok(None)
    Some(value) ->
      case timestamp.parse_rfc3339(value) {
        Ok(parsed) -> Ok(Some(parsed))
        Error(_) -> Error(InvalidExpiresAt)
      }
  }
}

fn ensure_integration_user(
  db: pog.Connection,
  org_id: Int,
  user_id: Int,
) -> Result(Nil, ApiTokenError) {
  let decoder = {
    use kind <- decode.field(0, decode.string)
    decode.success(kind)
  }

  use returned <- result.try(
    pog.query(
      "select user_kind from users where id = $1 and org_id = $2 and deleted_at is null",
    )
    |> pog.parameter(pog.int(user_id))
    |> pog.parameter(pog.int(org_id))
    |> pog.returning(decoder)
    |> pog.execute(db)
    |> result.map_error(DbError),
  )

  case returned.rows {
    [] -> Error(IntegrationUserNotFound)
    ["integration", ..] -> Ok(Nil)
    _ -> Error(IntegrationUserRequired)
  }
}

fn ensure_project_access(
  db: pog.Connection,
  org_id: Int,
  integration_user_id: Int,
  project_id: Option(Int),
) -> Result(Nil, ApiTokenError) {
  case project_id {
    None -> Ok(Nil)
    Some(project_id) ->
      ensure_integration_project_member(
        db,
        org_id,
        integration_user_id,
        project_id,
      )
  }
}

fn ensure_project_exists(
  db: pog.Connection,
  org_id: Int,
  project_id: Option(Int),
) -> Result(Nil, ApiTokenError) {
  case project_id {
    None -> Ok(Nil)
    Some(project_id) -> {
      let decoder = {
        use exists <- decode.field(0, decode.bool)
        decode.success(exists)
      }

      use returned <- result.try(
        pog.query(
          "select exists(select 1 from projects where id = $1 and org_id = $2)",
        )
        |> pog.parameter(pog.int(project_id))
        |> pog.parameter(pog.int(org_id))
        |> pog.returning(decoder)
        |> pog.execute(db)
        |> result.map_error(DbError),
      )

      case returned.rows {
        [True, ..] -> Ok(Nil)
        _ -> Error(ProjectNotFound)
      }
    }
  }
}

fn ensure_project_manager_membership(
  db: pog.Connection,
  integration_user_id: Int,
  project_id: Option(Int),
) -> Result(Nil, ApiTokenError) {
  case project_id {
    None -> Ok(Nil)
    Some(project_id) ->
      pog.query(
        "insert into project_members (project_id, user_id, role) values ($1, $2, 'manager') on conflict (project_id, user_id) do update set role = 'manager'",
      )
      |> pog.parameter(pog.int(project_id))
      |> pog.parameter(pog.int(integration_user_id))
      |> pog.execute(db)
      |> result.map(fn(_) { Nil })
      |> result.map_error(DbError)
  }
}

type ProjectAccessRow {
  ProjectAccessRow(project_exists: Bool, user_is_member: Bool)
}

fn ensure_integration_project_member(
  db: pog.Connection,
  org_id: Int,
  integration_user_id: Int,
  project_id: Int,
) -> Result(Nil, ApiTokenError) {
  let decoder = {
    use project_exists <- decode.field(0, decode.bool)
    use user_is_member <- decode.field(1, decode.bool)
    decode.success(ProjectAccessRow(project_exists:, user_is_member:))
  }

  use returned <- result.try(
    pog.query(
      "\nselect\n  exists(select 1 from projects where id = $1 and org_id = $2) as project_exists,\n  exists(select 1 from project_members where project_id = $1 and user_id = $3) as user_is_member\n",
    )
    |> pog.parameter(pog.int(project_id))
    |> pog.parameter(pog.int(org_id))
    |> pog.parameter(pog.int(integration_user_id))
    |> pog.returning(decoder)
    |> pog.execute(db)
    |> result.map_error(DbError),
  )

  use access <- result.try(
    persisted_field.query_row(returned.rows)
    |> result.map_error(fn(_) { ProjectNotFound }),
  )

  case access {
    ProjectAccessRow(project_exists: False, ..) -> Error(ProjectNotFound)
    ProjectAccessRow(user_is_member: False, ..) -> Error(ProjectAccessRequired)
    ProjectAccessRow(project_exists: True, user_is_member: True) -> Ok(Nil)
  }
}

fn insert_token(
  db: pog.Connection,
  org_id: Int,
  integration_user_id: Int,
  project_id: Option(Int),
  created_by: Int,
  name: String,
  public_id: String,
  token_hash: String,
  expires_at: Option(Timestamp),
) -> Result(Int, ApiTokenError) {
  use returned <- result.try(
    pog.query(
      "insert into api_tokens (org_id, integration_user_id, project_id, created_by, name, public_id, token_hash, expires_at) values ($1, $2, $3, $4, $5, $6, $7, $8) returning id",
    )
    |> pog.parameter(pog.int(org_id))
    |> pog.parameter(pog.int(integration_user_id))
    |> pog.parameter(pog.nullable(pog.int, project_id))
    |> pog.parameter(pog.int(created_by))
    |> pog.parameter(pog.text(name))
    |> pog.parameter(pog.text(public_id))
    |> pog.parameter(pog.text(token_hash))
    |> pog.parameter(pog.nullable(pog.timestamp, expires_at))
    |> pog.returning(persisted_field.int_decoder())
    |> pog.execute(db)
    |> result.map_error(DbError),
  )

  persisted_field.query_row(returned.rows)
  |> result.map_error(fn(_) { TokenNotFound })
}

fn insert_scopes(
  db: pog.Connection,
  token_id: Int,
  scopes: List(Scope),
) -> Result(Nil, ApiTokenError) {
  scopes
  |> list.try_each(fn(scope) {
    pog.query("insert into api_token_scopes (token_id, scope) values ($1, $2)")
    |> pog.parameter(pog.int(token_id))
    |> pog.parameter(pog.text(scope_to_string(scope)))
    |> pog.execute(db)
    |> result.map(fn(_) { Nil })
    |> result.map_error(DbError)
  })
}

fn find_by_id(
  db: pog.Connection,
  token_id: Int,
) -> Result(TokenRow, ApiTokenError) {
  use rows <- result.try(
    query_token_rows(db, "where t.id = $1", [
      pog.int(token_id),
    ]),
  )
  one_token_row(rows)
}

fn find_by_public_id(
  db: pog.Connection,
  public_id: String,
) -> Result(TokenRow, ApiTokenError) {
  use rows <- result.try(
    query_token_rows(db, "where t.public_id = $1", [
      pog.text(public_id),
    ]),
  )
  one_token_row(rows)
}

fn one_token_row(rows: List(TokenRow)) -> Result(TokenRow, ApiTokenError) {
  case rows {
    [row, ..] -> Ok(row)
    [] -> Error(InvalidBearer)
  }
}

fn query_token_rows(
  db: pog.Connection,
  where_clause: String,
  params: List(pog.Value),
) -> Result(List(TokenRow), ApiTokenError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use org_id <- decode.field(1, decode.int)
    use integration_user_id <- decode.field(2, decode.int)
    use project_id <- decode.field(3, decode.optional(decode.int))
    use name <- decode.field(4, decode.string)
    use public_id <- decode.field(5, decode.string)
    use token_hash <- decode.field(6, decode.string)
    use created_at <- decode.field(7, decode.string)
    use last_used_at <- decode.field(8, decode.optional(decode.string))
    use expires_at <- decode.field(9, decode.optional(decode.string))
    use revoked_at <- decode.field(10, decode.optional(decode.string))
    use expired <- decode.field(11, decode.bool)
    decode.success(TokenRow(
      id:,
      org_id:,
      integration_user_id:,
      project_id:,
      name:,
      public_id:,
      token_hash:,
      created_at:,
      last_used_at:,
      expires_at:,
      revoked_at:,
      expired:,
    ))
  }

  let query =
    pog.query(
      "\nselect\n  t.id,\n  t.org_id,\n  t.integration_user_id,\n  t.project_id,\n  t.name,\n  t.public_id,\n  t.token_hash,\n  to_char(t.created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at,\n  to_char(t.last_used_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as last_used_at,\n  to_char(t.expires_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as expires_at,\n  to_char(t.revoked_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as revoked_at,\n  (t.expires_at is not null and t.expires_at <= now()) as expired\nfrom api_tokens t\n"
      <> where_clause
      <> "\n",
    )

  let query =
    params
    |> list.fold(query, fn(query, param) { pog.parameter(query, param) })

  query
  |> pog.returning(decoder)
  |> pog.execute(db)
  |> result.map(fn(returned) { returned.rows })
  |> result.map_error(DbError)
}

fn list_scopes(
  db: pog.Connection,
  token_id: Int,
) -> Result(List(Scope), ApiTokenError) {
  let decoder = {
    use scope <- decode.field(0, decode.string)
    decode.success(scope)
  }

  use returned <- result.try(
    pog.query(
      "select scope from api_token_scopes where token_id = $1 order by scope",
    )
    |> pog.parameter(pog.int(token_id))
    |> pog.returning(decoder)
    |> pog.execute(db)
    |> result.map_error(DbError),
  )

  returned.rows
  |> list.try_map(parse_scope)
}

fn validate_token_state(row: TokenRow) -> Result(Nil, ApiTokenError) {
  case row.revoked_at {
    Some(_) -> Error(TokenRevoked)
    None ->
      case row.expired {
        True -> Error(TokenExpired)
        False -> Ok(Nil)
      }
  }
}

fn parse_resource(value: String) -> Result(Resource, ApiTokenError) {
  case value {
    "projects" -> Ok(Projects)
    "tasks" -> Ok(Tasks)
    "cards" -> Ok(Cards)
    "notes" -> Ok(Notes)
    "milestones" -> Ok(Milestones)
    other -> Error(InvalidScope(other))
  }
}

fn parse_access(value: String) -> Result(Access, ApiTokenError) {
  case value {
    "read" -> Ok(Read)
    "write" -> Ok(Write)
    other -> Error(InvalidScope(other))
  }
}

fn is_supported_scope(scope: Scope) -> Bool {
  list.contains(supported_scopes(), scope)
}

fn integration_user_error_to_api_token_error(
  error: integration_users.IntegrationUserError,
) -> ApiTokenError {
  case error {
    integration_users.EmailRequired -> IntegrationUserRequired
    integration_users.EmailTaken -> IntegrationUnavailable
    integration_users.NotFound -> IntegrationUserNotFound
    integration_users.InvalidPersistedRole(_) -> IntegrationUnavailable
    integration_users.DbError(error) -> DbError(error)
  }
}

fn random_token_part(bytes: Int) -> String {
  crypto.strong_random_bytes(bytes)
  |> bit_array.base64_url_encode(False)
  |> string.replace("_", "-")
}

fn method_to_string(method: http.Method) -> String {
  case method {
    http.Get -> "GET"
    http.Post -> "POST"
    http.Put -> "PUT"
    http.Patch -> "PATCH"
    http.Delete -> "DELETE"
    http.Head -> "HEAD"
    http.Options -> "OPTIONS"
    http.Connect -> "CONNECT"
    http.Trace -> "TRACE"
    http.Other(value) -> value
  }
}

fn transaction_error_to_api_token_error(
  error: pog.TransactionError(ApiTokenError),
) -> ApiTokenError {
  case error {
    pog.TransactionRolledBack(err) -> err
    pog.TransactionQueryError(err) -> DbError(err)
  }
}
