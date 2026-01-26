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
import mist
import scrumbringer_server
import wisp
import wisp/wisp_mist

// Justification: nested case improves clarity for branching logic.
/// Starts the ScrumBringer server.
pub fn main() {
  wisp.configure_logger()

  let secret_key_base = secret_key_base()
  let port = port()

  case database_url() {
    Error(_) -> io.println("DATABASE_URL is required to start the server")

    Ok(database_url) -> {
      case scrumbringer_server.new_app(secret_key_base, database_url) {
        Ok(app) -> {
          let assert Ok(_) =
            scrumbringer_server.handler(app)
            |> wisp_mist.handler(secret_key_base)
            |> mist.new
            |> mist.port(port)
            |> mist.start

          process.sleep_forever()
        }

        Error(scrumbringer_server.InvalidDatabaseUrl) ->
          io.println("DATABASE_URL is invalid")

        Error(scrumbringer_server.DbPoolStartFailed) ->
          io.println("Failed to start PostgreSQL pool")
      }
    }
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

fn database_url() -> Result(String, Nil) {
  case getenv("DATABASE_URL", "") {
    "" -> Error(Nil)
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
