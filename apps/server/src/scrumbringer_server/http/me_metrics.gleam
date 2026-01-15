import gleam/http
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import pog
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/sql
import wisp

const default_window_days = 30

const max_window_days = 365

pub fn handle_me_metrics(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) -> {
      let auth.Ctx(db: db, ..) = ctx

      case parse_window_days(req) {
        Error(resp) -> resp

        Ok(window_days) ->
          case sql.metrics_my(db, user.id, int.to_string(window_days)) {
            Ok(pog.Returned(rows: [row, ..], ..)) ->
              api.ok(
                json.object([
                  #(
                    "metrics",
                    json.object([
                      #("window_days", json.int(window_days)),
                      #("claimed_count", json.int(row.claimed_count)),
                      #("released_count", json.int(row.released_count)),
                      #("completed_count", json.int(row.completed_count)),
                    ]),
                  ),
                ]),
              )

            Ok(pog.Returned(rows: [], ..)) ->
              api.ok(
                json.object([
                  #(
                    "metrics",
                    json.object([
                      #("window_days", json.int(window_days)),
                      #("claimed_count", json.int(0)),
                      #("released_count", json.int(0)),
                      #("completed_count", json.int(0)),
                    ]),
                  ),
                ]),
              )

            Error(_) -> api.error(500, "INTERNAL", "Database error")
          }
      }
    }
  }
}

fn parse_window_days(req: wisp.Request) -> Result(Int, wisp.Response) {
  let query = wisp.get_query(req)

  case single_query_value(query, "window_days") {
    Ok(None) -> Ok(default_window_days)

    Ok(Some(value)) ->
      case int.parse(value) {
        Ok(days) if days >= 1 && days <= max_window_days -> Ok(days)
        _ -> Error(api.error(422, "VALIDATION_ERROR", "Invalid window_days"))
      }

    Error(_) -> Error(api.error(422, "VALIDATION_ERROR", "Invalid window_days"))
  }
}

fn single_query_value(
  query: List(#(String, String)),
  key: String,
) -> Result(Option(String), Nil) {
  let values =
    query
    |> list.filter_map(fn(pair) {
      case pair.0 == key {
        True -> Ok(pair.1)
        False -> Error(Nil)
      }
    })

  case values {
    [] -> Ok(None)
    [value] -> Ok(Some(value))
    _ -> Error(Nil)
  }
}
