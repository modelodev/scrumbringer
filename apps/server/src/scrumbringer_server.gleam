//// Main application module for the ScrumBringer server.
////
//// Handles database pool initialization and server lifecycle.
//// Routing is delegated to `web/router.gleam`.

import gleam/dynamic.{type Dynamic}
import gleam/erlang/atom
import gleam/erlang/process
import gleam/result
import pog
import scrumbringer_server/web/router
import wisp

/// Errors that can occur during server startup.
pub type StartupError {
  InvalidDatabaseUrl
  DbPoolStartFailed
}

/// Application state holding database connection and JWT secret.
pub type App {
  App(db: pog.Connection, jwt_secret: BitArray)
}

/// Creates a new App instance with database pool and JWT secret.
///
/// ## Example
///
/// ```gleam
/// new_app("secret", "postgres://localhost/scrumbringer")
/// // -> Ok(App(db: ..., jwt_secret: ...))
/// ```
pub fn new_app(
  jwt_secret: String,
  database_url: String,
) -> Result(App, StartupError) {
  use db <- result.try(start_db_pool(database_url))
  Ok(App(db: db, jwt_secret: <<jwt_secret:utf8>>))
}

/// Returns a request handler function for the given App.
///
/// ## Example
///
/// ```gleam
/// let handle = handler(app)
/// wisp.serve(handle, on: 8080)
/// ```
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
  let App(db: db, jwt_secret: jwt_secret) = app
  let ctx = router.RouterCtx(db: db, jwt_secret: jwt_secret)
  router.route(req, ctx)
}

@external(erlang, "application", "ensure_all_started")
fn ensure_all_started(app: atom.Atom) -> Result(List(atom.Atom), Dynamic)

@external(erlang, "scrumbringer_server_ffi", "db_pool_name")
fn db_pool_name() -> process.Name(pog.Message)
