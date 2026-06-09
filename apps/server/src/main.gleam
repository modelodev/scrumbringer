//// Application entrypoint for ScrumBringer server.
////
//// Configures logging, reads environment variables, and starts the
//// HTTP server using Mist on the configured port.

import gleam/bit_array
import gleam/crypto
import gleam/erlang/charlist
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/result
import mist
import scrumbringer_server
import wisp
import wisp/wisp_mist

type StartupError {
  MissingDatabaseUrl
  InvalidDatabaseUrl
  DbPoolStartFailed
  HttpServerStartFailed
}

/// Starts the ScrumBringer server.
pub fn main() {
  wisp.configure_logger()

  case start() {
    Ok(_) -> Nil
    Error(error) -> io.println(startup_error_message(error))
  }
}

fn start() -> Result(Nil, StartupError) {
  let secret_key_base = secret_key_base()
  let port = port()

  use database_url <- result.try(database_url())
  use app <- result.try(
    scrumbringer_server.new_app(secret_key_base, database_url)
    |> result.map_error(app_startup_error),
  )
  use _ <- result.try(
    scrumbringer_server.handler(app)
    |> wisp_mist.handler(secret_key_base)
    |> mist.new
    |> mist.port(port)
    |> mist.start
    |> result.map_error(fn(_) { HttpServerStartFailed }),
  )

  process.sleep_forever()
  Ok(Nil)
}

fn app_startup_error(error: scrumbringer_server.StartupError) -> StartupError {
  case error {
    scrumbringer_server.InvalidDatabaseUrl -> InvalidDatabaseUrl
    scrumbringer_server.DbPoolStartFailed -> DbPoolStartFailed
  }
}

fn startup_error_message(error: StartupError) -> String {
  case error {
    MissingDatabaseUrl -> "DATABASE_URL is required to start the server"
    InvalidDatabaseUrl -> "DATABASE_URL is invalid"
    DbPoolStartFailed -> "Failed to start PostgreSQL pool"
    HttpServerStartFailed -> "Failed to start HTTP server"
  }
}

fn secret_key_base() -> String {
  case getenv("SB_SECRET_KEY_BASE", "") {
    "" ->
      crypto.strong_random_bytes(64)
      |> bit_array.base64_url_encode(False)
    value -> value
  }
}

fn port() -> Int {
  case getenv("SB_PORT", "8000") |> int.parse {
    Ok(port) -> port
    Error(_) -> 8000
  }
}

fn database_url() -> Result(String, StartupError) {
  case getenv("DATABASE_URL", "") {
    "" -> Error(MissingDatabaseUrl)
    url -> Ok(url)
  }
}

fn getenv(key: String, default: String) -> String {
  getenv_charlist(charlist.from_string(key), charlist.from_string(default))
  |> charlist.to_string
}

@external(erlang, "os", "getenv")
fn getenv_charlist(
  key: charlist.Charlist,
  default: charlist.Charlist,
) -> charlist.Charlist
