//// Query parsing helpers shared by metrics HTTP handlers.

import gleam/result
import scrumbringer_server/http/api
import scrumbringer_server/http/query
import wisp

const default_window_days = 30

pub fn parse_window_days(
  req: wisp.Request,
  max_window_days: Int,
) -> Result(Int, wisp.Response) {
  query.bounded_int(
    wisp.get_query(req),
    "window_days",
    default_window_days,
    1,
    max_window_days,
  )
  |> result.map_error(fn(_) {
    api.error(422, "VALIDATION_ERROR", "Invalid window_days")
  })
}
