import gleam/http
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import pog
import scrumbringer_domain/org_role
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/sql
import wisp

const default_window_days = 30

const max_window_days = 365

pub fn handle_org_metrics_overview(
  req: wisp.Request,
  ctx: auth.Ctx,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) -> {
      case user.org_role {
        org_role.Admin -> overview_as_admin(req, ctx, user.org_id)
        _ -> api.error(403, "FORBIDDEN", "Forbidden")
      }
    }
  }
}

pub fn handle_org_metrics_project_tasks(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) -> {
      case user.org_role {
        org_role.Admin ->
          project_tasks_as_admin(req, ctx, user.org_id, project_id)
        _ -> api.error(403, "FORBIDDEN", "Forbidden")
      }
    }
  }
}

fn overview_as_admin(
  req: wisp.Request,
  ctx: auth.Ctx,
  org_id: Int,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case parse_window_days(req) {
    Error(resp) -> resp

    Ok(window_days) -> {
      let window_days_str = int.to_string(window_days)

      let totals = sql.metrics_org_overview(db, org_id, window_days_str)
      let buckets_claim =
        sql.metrics_time_to_first_claim_buckets(db, org_id, window_days_str)
      let p50 =
        sql.metrics_time_to_first_claim_p50_ms(db, org_id, window_days_str)
      let buckets_release =
        sql.metrics_release_rate_buckets(db, org_id, window_days_str)
      let by_project =
        sql.metrics_org_overview_by_project(db, org_id, window_days_str)

      case totals, buckets_claim, p50, buckets_release, by_project {
        Ok(pog.Returned(rows: [totals_row, ..], ..)),
          Ok(pog.Returned(rows: ttf_buckets, ..)),
          Ok(pog.Returned(rows: [p50_row, ..], ..)),
          Ok(pog.Returned(rows: rr_buckets, ..)),
          Ok(pog.Returned(rows: project_rows, ..))
        -> {
          let claimed = totals_row.claimed_count
          let released = totals_row.released_count
          let completed = totals_row.completed_count

          let release_rate_percent = percent(released, claimed)
          let pool_flow_ratio_percent = percent(completed, claimed)

          let time_to_first_claim_p50_ms = case p50_row.sample_size {
            0 -> None
            _ -> Some(p50_row.p50_ms)
          }

          api.ok(
            json.object([
              #(
                "overview",
                json.object([
                  #("window_days", json.int(window_days)),
                  #(
                    "totals",
                    json.object([
                      #("claimed_count", json.int(claimed)),
                      #("released_count", json.int(released)),
                      #("completed_count", json.int(completed)),
                    ]),
                  ),
                  #(
                    "release_rate_percent",
                    option_int_json(release_rate_percent),
                  ),
                  #(
                    "pool_flow_ratio_percent",
                    option_int_json(pool_flow_ratio_percent),
                  ),
                  #(
                    "time_to_first_claim_p50_ms",
                    option_int_json(time_to_first_claim_p50_ms),
                  ),
                  #(
                    "time_to_first_claim_sample_size",
                    json.int(p50_row.sample_size),
                  ),
                  #(
                    "time_to_first_claim_buckets",
                    json.array(ttf_buckets, of: fn(row) {
                      json.object([
                        #("bucket", json.string(row.bucket)),
                        #("count", json.int(row.count)),
                      ])
                    }),
                  ),
                  #(
                    "release_rate_buckets",
                    json.array(rr_buckets, of: fn(row) {
                      json.object([
                        #("bucket", json.string(row.bucket)),
                        #("count", json.int(row.count)),
                      ])
                    }),
                  ),
                  #(
                    "by_project",
                    json.array(project_rows, of: fn(row) {
                      let project_release_rate_percent =
                        percent(row.released_count, row.claimed_count)
                      let project_pool_flow_ratio_percent =
                        percent(row.completed_count, row.claimed_count)

                      json.object([
                        #("project_id", json.int(row.project_id)),
                        #("project_name", json.string(row.project_name)),
                        #("claimed_count", json.int(row.claimed_count)),
                        #("released_count", json.int(row.released_count)),
                        #("completed_count", json.int(row.completed_count)),
                        #(
                          "release_rate_percent",
                          option_int_json(project_release_rate_percent),
                        ),
                        #(
                          "pool_flow_ratio_percent",
                          option_int_json(project_pool_flow_ratio_percent),
                        ),
                      ])
                    }),
                  ),
                ]),
              ),
            ]),
          )
        }

        _, _, _, _, _ -> api.error(500, "INTERNAL", "Database error")
      }
    }
  }
}

fn project_tasks_as_admin(
  req: wisp.Request,
  ctx: auth.Ctx,
  org_id: Int,
  project_id_raw: String,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case int.parse(project_id_raw) {
    Error(_) -> api.error(404, "NOT_FOUND", "Not found")

    Ok(project_id) -> {
      case sql.projects_org_id(db, project_id) {
        Ok(pog.Returned(rows: [row, ..], ..)) ->
          case row.org_id == org_id {
            False -> api.error(404, "NOT_FOUND", "Not found")

            True ->
              case parse_window_days(req) {
                Error(resp) -> resp

                Ok(window_days) ->
                  case
                    sql.metrics_project_tasks(
                      db,
                      project_id,
                      int.to_string(window_days),
                    )
                  {
                    Ok(pog.Returned(rows: rows, ..)) ->
                      api.ok(
                        json.object([
                          #("window_days", json.int(window_days)),
                          #("project_id", json.int(project_id)),
                          #("tasks", json.array(rows, of: project_task_json)),
                        ]),
                      )

                    Error(_) -> api.error(500, "INTERNAL", "Database error")
                  }
              }
          }

        Ok(pog.Returned(rows: [], ..)) ->
          api.error(404, "NOT_FOUND", "Not found")
        Error(_) -> api.error(500, "INTERNAL", "Database error")
      }
    }
  }
}

fn project_task_json(row: sql.MetricsProjectTasksRow) -> json.Json {
  let claimed_by = case row.claimed_by {
    0 -> None
    other -> Some(other)
  }

  let claimed_at = empty_string_to_option(row.claimed_at)
  let completed_at = empty_string_to_option(row.completed_at)
  let first_claim_at = empty_string_to_option(row.first_claim_at)

  json.object([
    #("id", json.int(row.id)),
    #("project_id", json.int(row.project_id)),
    #("type_id", json.int(row.type_id)),
    #("title", json.string(row.title)),
    #("description", json.string(row.description)),
    #("priority", json.int(row.priority)),
    #("status", json.string(row.status)),
    #("created_by", json.int(row.created_by)),
    #("claimed_by", option_int_json(claimed_by)),
    #("claimed_at", option_string_json(claimed_at)),
    #("completed_at", option_string_json(completed_at)),
    #("created_at", json.string(row.created_at)),
    #("version", json.int(row.version)),
    #("claim_count", json.int(row.claim_count)),
    #("release_count", json.int(row.release_count)),
    #("complete_count", json.int(row.complete_count)),
    #("first_claim_at", option_string_json(first_claim_at)),
  ])
}

fn empty_string_to_option(value: String) -> Option(String) {
  case value {
    "" -> None
    other -> Some(other)
  }
}

fn percent(numerator: Int, denominator: Int) -> Option(Int) {
  case denominator {
    0 -> None
    _ -> Some(numerator * 100 / denominator)
  }
}

fn option_int_json(value: Option(Int)) -> json.Json {
  case value {
    None -> json.null()
    Some(v) -> json.int(v)
  }
}

fn option_string_json(value: Option(String)) -> json.Json {
  case value {
    None -> json.null()
    Some(v) -> json.string(v)
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
