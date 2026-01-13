import gleam/dynamic.{type Dynamic}
import gleam/erlang/atom
import gleam/erlang/process
import gleam/json
import gleam/result
import pog
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/capabilities
import scrumbringer_server/http/org_invites
import scrumbringer_server/http/projects
import wisp

pub type StartupError {
  InvalidDatabaseUrl
  DbPoolStartFailed
}

pub type App {
  App(db: pog.Connection, jwt_secret: BitArray)
}

pub fn new_app(
  jwt_secret: String,
  database_url: String,
) -> Result(App, StartupError) {
  use db <- result.try(start_db_pool(database_url))
  Ok(App(db: db, jwt_secret: <<jwt_secret:utf8>>))
}

pub fn handler(app: App) -> fn(wisp.Request) -> wisp.Response {
  fn(req) { handle_request(req, app) }
}

fn start_db_pool(database_url: String) -> Result(pog.Connection, StartupError) {
  let pool_name: process.Name(pog.Message) = db_pool_name()

  use _ <- result.try(
    ensure_all_started(atom.create("pgo"))
    |> result.replace_error(DbPoolStartFailed),
  )

  use config <- result.try(
    pog.url_config(pool_name, database_url)
    |> result.replace_error(InvalidDatabaseUrl),
  )

  case pog.start(pog.pool_size(config, 10)) {
    Ok(started) -> {
      use _ <- result.try(wait_for_db(started.data, 20))
      Ok(started.data)
    }

    Error(_) -> {
      // Pool may already be started; reuse it.
      let db = pog.named_connection(pool_name)
      use _ <- result.try(wait_for_db(db, 20))
      Ok(db)
    }
  }
}

fn wait_for_db(db: pog.Connection, attempts: Int) -> Result(Nil, StartupError) {
  case pog.query("select 1") |> pog.execute(db) {
    Ok(_) -> Ok(Nil)

    Error(_) ->
      case attempts {
        0 -> Error(DbPoolStartFailed)
        _ -> {
          process.sleep(50)
          wait_for_db(db, attempts - 1)
        }
      }
  }
}

fn handle_request(req: wisp.Request, app: App) -> wisp.Response {
  use <- wisp.rescue_crashes

  case wisp.path_segments(req) {
    ["api", "v1", "auth", "register"] ->
      auth.handle_register(req, auth_ctx(app))
    ["api", "v1", "auth", "login"] -> auth.handle_login(req, auth_ctx(app))
    ["api", "v1", "auth", "me"] -> auth.handle_me(req, auth_ctx(app))
    ["api", "v1", "auth", "logout"] -> auth.handle_logout(req, auth_ctx(app))
    ["api", "v1", "org", "invites"] ->
      org_invites.handle_create(req, auth_ctx(app))
    ["api", "v1", "projects"] -> projects.handle_projects(req, auth_ctx(app))
    ["api", "v1", "projects", project_id, "members"] ->
      projects.handle_members(req, auth_ctx(app), project_id)
    ["api", "v1", "projects", project_id, "members", user_id] ->
      projects.handle_member_remove(req, auth_ctx(app), project_id, user_id)
    ["api", "v1", "capabilities"] ->
      capabilities.handle_capabilities(req, auth_ctx(app))
    ["api", "v1", "me", "capabilities"] ->
      capabilities.handle_me_capabilities(req, auth_ctx(app))
    ["api", "v1", "health"] -> api.ok(json.object([#("ok", json.bool(True))]))
    _ -> wisp.not_found()
  }
}

fn auth_ctx(app: App) -> auth.Ctx {
  let App(db: db, jwt_secret: jwt_secret) = app
  auth.Ctx(db: db, jwt_secret: jwt_secret)
}

@external(erlang, "application", "ensure_all_started")
fn ensure_all_started(app: atom.Atom) -> Result(List(atom.Atom), Dynamic)

@external(erlang, "scrumbringer_server_ffi", "db_pool_name")
fn db_pool_name() -> process.Name(pog.Message)
