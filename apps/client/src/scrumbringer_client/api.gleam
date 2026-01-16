import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import gleam/string

import lustre/effect.{type Effect}

import scrumbringer_domain/org_role
import scrumbringer_domain/user.{type User, User}

pub type ApiError {
  ApiError(status: Int, code: String, message: String)
}

pub type ApiResult(a) =
  Result(a, ApiError)

pub type Project {
  Project(id: Int, name: String, my_role: String)
}

pub type ProjectMember {
  ProjectMember(user_id: Int, role: String, created_at: String)
}

pub type Capability {
  Capability(id: Int, name: String)
}

pub type TaskType {
  TaskType(
    id: Int,
    name: String,
    icon: String,
    capability_id: option.Option(Int),
  )
}

pub type OrgInvite {
  OrgInvite(code: String, created_at: String, expires_at: String)
}

pub type InviteLink {
  InviteLink(
    email: String,
    token: String,
    url_path: String,
    state: String,
    created_at: String,
    used_at: option.Option(String),
    invalidated_at: option.Option(String),
  )
}

pub type OrgUser {
  OrgUser(id: Int, email: String, org_role: String, created_at: String)
}

// Make invalid states unrepresentable:
// - Ongoing implies Claimed
// - Available/Completed are mutually exclusive with Claimed
pub type TaskStatus {
  Available
  Claimed(ClaimedState)
  Completed
}

pub type ClaimedState {
  Taken
  Ongoing
}

pub fn parse_task_status(value: String) -> Result(TaskStatus, String) {
  case value {
    "available" -> Ok(Available)
    "claimed" -> Ok(Claimed(Taken))
    "ongoing" -> Ok(Claimed(Ongoing))
    "completed" -> Ok(Completed)
    _ -> Error("Unknown task status: " <> value)
  }
}

pub fn task_status_to_string(status: TaskStatus) -> String {
  case status {
    Available -> "available"
    Claimed(Taken) -> "claimed"
    Claimed(Ongoing) -> "ongoing"
    Completed -> "completed"
  }
}

pub type TaskTypeInline {
  TaskTypeInline(id: Int, name: String, icon: String)
}

pub type WorkState {
  WorkAvailable
  WorkClaimed
  WorkOngoing
  WorkCompleted
}

pub type OngoingBy {
  OngoingBy(user_id: Int)
}

pub type Task {
  Task(
    id: Int,
    project_id: Int,
    type_id: Int,
    task_type: TaskTypeInline,
    ongoing_by: option.Option(OngoingBy),
    title: String,
    description: option.Option(String),
    priority: Int,
    status: TaskStatus,
    work_state: WorkState,
    created_by: Int,
    claimed_by: option.Option(Int),
    claimed_at: option.Option(String),
    completed_at: option.Option(String),
    created_at: String,
    version: Int,
  )
}

pub type TaskNote {
  TaskNote(
    id: Int,
    task_id: Int,
    user_id: Int,
    content: String,
    created_at: String,
  )
}

pub type TaskPosition {
  TaskPosition(task_id: Int, user_id: Int, x: Int, y: Int, updated_at: String)
}

pub type ActiveTask {
  ActiveTask(
    task_id: Int,
    project_id: Int,
    started_at: String,
    accumulated_s: Int,
  )
}

pub type ActiveTaskPayload {
  ActiveTaskPayload(active_task: option.Option(ActiveTask), as_of: String)
}

pub type MyMetrics {
  MyMetrics(
    window_days: Int,
    claimed_count: Int,
    released_count: Int,
    completed_count: Int,
  )
}

pub type OrgMetricsBucket {
  OrgMetricsBucket(bucket: String, count: Int)
}

pub type OrgMetricsProjectOverview {
  OrgMetricsProjectOverview(
    project_id: Int,
    project_name: String,
    claimed_count: Int,
    released_count: Int,
    completed_count: Int,
    release_rate_percent: option.Option(Int),
    pool_flow_ratio_percent: option.Option(Int),
  )
}

pub type OrgMetricsOverview {
  OrgMetricsOverview(
    window_days: Int,
    claimed_count: Int,
    released_count: Int,
    completed_count: Int,
    release_rate_percent: option.Option(Int),
    pool_flow_ratio_percent: option.Option(Int),
    time_to_first_claim_p50_ms: option.Option(Int),
    time_to_first_claim_sample_size: Int,
    time_to_first_claim_buckets: List(OrgMetricsBucket),
    release_rate_buckets: List(OrgMetricsBucket),
    by_project: List(OrgMetricsProjectOverview),
  )
}

pub type MetricsProjectTask {
  MetricsProjectTask(
    task: Task,
    claim_count: Int,
    release_count: Int,
    complete_count: Int,
    first_claim_at: option.Option(String),
  )
}

pub type OrgMetricsProjectTasksPayload {
  OrgMetricsProjectTasksPayload(
    window_days: Int,
    project_id: Int,
    tasks: List(MetricsProjectTask),
  )
}

pub fn should_attach_csrf(method: String) -> Bool {
  case string.uppercase(method) {
    "POST" | "PUT" | "PATCH" | "DELETE" -> True
    _ -> False
  }
}

pub fn build_csrf_headers(
  method: String,
  csrf: option.Option(String),
) -> List(#(String, String)) {
  case should_attach_csrf(method), csrf {
    True, option.Some(token) -> [#("X-CSRF", token)]
    _, _ -> []
  }
}

@external(javascript, "./fetch.ffi.mjs", "read_cookie")
fn read_cookie_ffi(_name: String) -> String {
  ""
}

fn read_cookie(name: String) -> option.Option(String) {
  case read_cookie_ffi(name) {
    "" -> option.None
    value -> option.Some(value)
  }
}

@external(javascript, "./fetch.ffi.mjs", "send")
fn send(
  _method: String,
  _url: String,
  _headers: List(#(String, String)),
  _body: option.Option(String),
  _callback: fn(#(Int, String)) -> Nil,
) -> Nil {
  Nil
}

@external(javascript, "./fetch.ffi.mjs", "encode_uri_component")
fn encode_uri_component(_value: String) -> String {
  ""
}

fn envelope(payload: decode.Decoder(a)) -> decode.Decoder(a) {
  decode.field("data", payload, decode.success)
}

fn api_error_decoder(status: Int) -> decode.Decoder(ApiError) {
  let error_inner = {
    use code <- decode.field("code", decode.string)
    use message <- decode.field("message", decode.string)
    decode.success(#(code, message))
  }

  decode.field("error", error_inner, fn(inner) {
    let #(code, message) = inner
    decode.success(ApiError(status: status, code: code, message: message))
  })
}

fn decode_success(
  status: Int,
  text: String,
  decoder: decode.Decoder(a),
) -> ApiResult(a) {
  json.parse(from: text, using: envelope(decoder))
  |> result.map_error(fn(_) {
    ApiError(
      status: status,
      code: "DECODE_ERROR",
      message: "Failed to decode response",
    )
  })
}

fn decode_failure(status: Int, text: String) -> ApiError {
  case json.parse(from: text, using: api_error_decoder(status)) {
    Ok(err) -> err
    Error(_) ->
      ApiError(status: status, code: "HTTP_ERROR", message: "Request failed")
  }
}

fn request(
  method: String,
  url: String,
  body: option.Option(json.Json),
  decoder: decode.Decoder(a),
  to_msg: fn(ApiResult(a)) -> msg,
) -> Effect(msg) {
  effect.from(fn(dispatch) {
    let csrf = read_cookie("sb_csrf")

    let base_headers = [#("Accept", "application/json")]

    let headers = case body {
      option.Some(_) -> [#("Content-Type", "application/json"), ..base_headers]
      option.None -> base_headers
    }

    let headers = list.append(headers, build_csrf_headers(method, csrf))

    let body_string = option.map(body, json.to_string)

    send(method, url, headers, body_string, fn(result) {
      let #(status, text) = result

      let msg = case status >= 200 && status < 300 {
        True -> {
          case status == 204 || string.length(text) == 0 {
            True ->
              to_msg(
                Error(ApiError(
                  status: status,
                  code: "EMPTY",
                  message: "Empty response",
                )),
              )
            False -> decode_success(status, text, decoder) |> to_msg
          }
        }

        False -> to_msg(Error(decode_failure(status, text)))
      }

      dispatch(msg)
    })
  })
}

fn request_nil(
  method: String,
  url: String,
  body: option.Option(json.Json),
  to_msg: fn(ApiResult(Nil)) -> msg,
) -> Effect(msg) {
  effect.from(fn(dispatch) {
    let csrf = read_cookie("sb_csrf")

    let base_headers = [#("Accept", "application/json")]

    let headers = case body {
      option.Some(_) -> [#("Content-Type", "application/json"), ..base_headers]
      option.None -> base_headers
    }

    let headers = list.append(headers, build_csrf_headers(method, csrf))

    let body_string = option.map(body, json.to_string)

    send(method, url, headers, body_string, fn(result) {
      let #(status, text) = result

      let msg = case status >= 200 && status < 300 {
        True -> to_msg(Ok(Nil))
        False -> to_msg(Error(decode_failure(status, text)))
      }

      dispatch(msg)
    })
  })
}

fn user_decoder() -> decode.Decoder(User) {
  use id <- decode.field("id", decode.int)
  use email <- decode.field("email", decode.string)
  use org_id <- decode.field("org_id", decode.int)
  use org_role_str <- decode.field("org_role", decode.string)
  use created_at <- decode.field("created_at", decode.string)

  case org_role.parse(org_role_str) {
    Ok(role) ->
      decode.success(User(
        id: id,
        email: email,
        org_id: org_id,
        org_role: role,
        created_at: created_at,
      ))
    Error(_) ->
      decode.failure(
        User(
          id: 0,
          email: "",
          org_id: 0,
          org_role: org_role.Member,
          created_at: "",
        ),
        expected: "OrgRole",
      )
  }
}

pub fn user_payload_decoder() -> decode.Decoder(User) {
  decode.field("user", user_decoder(), decode.success)
}

fn project_decoder() -> decode.Decoder(Project) {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  use my_role <- decode.field("my_role", decode.string)
  decode.success(Project(id: id, name: name, my_role: my_role))
}

fn project_member_decoder() -> decode.Decoder(ProjectMember) {
  use user_id <- decode.field("user_id", decode.int)
  use role <- decode.field("role", decode.string)
  use created_at <- decode.field("created_at", decode.string)
  decode.success(ProjectMember(
    user_id: user_id,
    role: role,
    created_at: created_at,
  ))
}

fn capability_decoder() -> decode.Decoder(Capability) {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  decode.success(Capability(id: id, name: name))
}

fn task_type_decoder() -> decode.Decoder(TaskType) {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  use icon <- decode.field("icon", decode.string)

  use capability_id <- decode.optional_field(
    "capability_id",
    option.None,
    decode.optional(decode.int),
  )

  decode.success(TaskType(
    id: id,
    name: name,
    icon: icon,
    capability_id: capability_id,
  ))
}

fn invite_decoder() -> decode.Decoder(OrgInvite) {
  use code <- decode.field("code", decode.string)
  use created_at <- decode.field("created_at", decode.string)
  use expires_at <- decode.field("expires_at", decode.string)
  decode.success(OrgInvite(
    code: code,
    created_at: created_at,
    expires_at: expires_at,
  ))
}

fn invite_link_decoder() -> decode.Decoder(InviteLink) {
  use email <- decode.field("email", decode.string)
  use token <- decode.field("token", decode.string)
  use url_path <- decode.field("url_path", decode.string)
  use state <- decode.field("state", decode.string)
  use created_at <- decode.field("created_at", decode.string)

  use used_at <- decode.optional_field(
    "used_at",
    option.None,
    decode.optional(decode.string),
  )

  use invalidated_at <- decode.optional_field(
    "invalidated_at",
    option.None,
    decode.optional(decode.string),
  )

  decode.success(InviteLink(
    email: email,
    token: token,
    url_path: url_path,
    state: state,
    created_at: created_at,
    used_at: used_at,
    invalidated_at: invalidated_at,
  ))
}

pub fn invite_link_payload_decoder() -> decode.Decoder(InviteLink) {
  decode.field("invite_link", invite_link_decoder(), decode.success)
}

pub fn invite_links_payload_decoder() -> decode.Decoder(List(InviteLink)) {
  decode.field(
    "invite_links",
    decode.list(invite_link_decoder()),
    decode.success,
  )
}

fn active_task_decoder() -> decode.Decoder(ActiveTask) {
  use task_id <- decode.field("task_id", decode.int)
  use project_id <- decode.field("project_id", decode.int)
  use started_at <- decode.field("started_at", decode.string)
  use accumulated <- decode.optional_field(
    "accumulated_s",
    option.None,
    decode.optional(decode.int),
  )

  let accumulated_s = case accumulated {
    option.Some(v) -> v
    option.None -> 0
  }

  decode.success(ActiveTask(
    task_id: task_id,
    project_id: project_id,
    started_at: started_at,
    accumulated_s: accumulated_s,
  ))
}

pub fn active_task_payload_decoder() -> decode.Decoder(ActiveTaskPayload) {
  let payload = {
    use active_task <- decode.field(
      "active_task",
      decode.optional(active_task_decoder()),
    )
    use as_of <- decode.field("as_of", decode.string)
    decode.success(ActiveTaskPayload(active_task: active_task, as_of: as_of))
  }

  payload
}

fn my_metrics_decoder() -> decode.Decoder(MyMetrics) {
  use window_days <- decode.field("window_days", decode.int)
  use claimed_count <- decode.field("claimed_count", decode.int)
  use released_count <- decode.field("released_count", decode.int)
  use completed_count <- decode.field("completed_count", decode.int)

  decode.success(MyMetrics(
    window_days: window_days,
    claimed_count: claimed_count,
    released_count: released_count,
    completed_count: completed_count,
  ))
}

fn org_metrics_bucket_decoder() -> decode.Decoder(OrgMetricsBucket) {
  use bucket <- decode.field("bucket", decode.string)
  use count <- decode.field("count", decode.int)
  decode.success(OrgMetricsBucket(bucket: bucket, count: count))
}

fn org_metrics_project_overview_decoder() -> decode.Decoder(
  OrgMetricsProjectOverview,
) {
  use project_id <- decode.field("project_id", decode.int)
  use project_name <- decode.field("project_name", decode.string)
  use claimed_count <- decode.field("claimed_count", decode.int)
  use released_count <- decode.field("released_count", decode.int)
  use completed_count <- decode.field("completed_count", decode.int)
  use release_rate_percent <- decode.optional_field(
    "release_rate_percent",
    option.None,
    decode.optional(decode.int),
  )
  use pool_flow_ratio_percent <- decode.optional_field(
    "pool_flow_ratio_percent",
    option.None,
    decode.optional(decode.int),
  )

  decode.success(OrgMetricsProjectOverview(
    project_id: project_id,
    project_name: project_name,
    claimed_count: claimed_count,
    released_count: released_count,
    completed_count: completed_count,
    release_rate_percent: release_rate_percent,
    pool_flow_ratio_percent: pool_flow_ratio_percent,
  ))
}

fn org_metrics_overview_decoder() -> decode.Decoder(OrgMetricsOverview) {
  let totals_decoder = {
    use claimed_count <- decode.field("claimed_count", decode.int)
    use released_count <- decode.field("released_count", decode.int)
    use completed_count <- decode.field("completed_count", decode.int)
    decode.success(#(claimed_count, released_count, completed_count))
  }

  use window_days <- decode.field("window_days", decode.int)
  use totals <- decode.field("totals", totals_decoder)
  use release_rate_percent <- decode.optional_field(
    "release_rate_percent",
    option.None,
    decode.optional(decode.int),
  )
  use pool_flow_ratio_percent <- decode.optional_field(
    "pool_flow_ratio_percent",
    option.None,
    decode.optional(decode.int),
  )
  use time_to_first_claim_p50_ms <- decode.optional_field(
    "time_to_first_claim_p50_ms",
    option.None,
    decode.optional(decode.int),
  )
  use time_to_first_claim_sample_size <- decode.field(
    "time_to_first_claim_sample_size",
    decode.int,
  )
  use time_to_first_claim_buckets <- decode.field(
    "time_to_first_claim_buckets",
    decode.list(org_metrics_bucket_decoder()),
  )
  use release_rate_buckets <- decode.field(
    "release_rate_buckets",
    decode.list(org_metrics_bucket_decoder()),
  )
  use by_project <- decode.field(
    "by_project",
    decode.list(org_metrics_project_overview_decoder()),
  )

  let #(claimed_count, released_count, completed_count) = totals

  decode.success(OrgMetricsOverview(
    window_days: window_days,
    claimed_count: claimed_count,
    released_count: released_count,
    completed_count: completed_count,
    release_rate_percent: release_rate_percent,
    pool_flow_ratio_percent: pool_flow_ratio_percent,
    time_to_first_claim_p50_ms: time_to_first_claim_p50_ms,
    time_to_first_claim_sample_size: time_to_first_claim_sample_size,
    time_to_first_claim_buckets: time_to_first_claim_buckets,
    release_rate_buckets: release_rate_buckets,
    by_project: by_project,
  ))
}

fn metrics_project_task_decoder() -> decode.Decoder(MetricsProjectTask) {
  use id <- decode.field("id", decode.int)
  use project_id <- decode.field("project_id", decode.int)
  use type_id <- decode.field("type_id", decode.int)
  use title <- decode.field("title", decode.string)

  use description <- decode.optional_field(
    "description",
    option.None,
    decode.optional(decode.string),
  )

  use priority <- decode.field("priority", decode.int)
  use status_raw <- decode.field("status", decode.string)

  let status = case parse_task_status(status_raw) {
    Ok(s) -> s
    Error(_) -> Available
  }

  use created_by <- decode.field("created_by", decode.int)

  use claimed_by <- decode.optional_field(
    "claimed_by",
    option.None,
    decode.optional(decode.int),
  )

  use claimed_at <- decode.optional_field(
    "claimed_at",
    option.None,
    decode.optional(decode.string),
  )

  use completed_at <- decode.optional_field(
    "completed_at",
    option.None,
    decode.optional(decode.string),
  )

  use created_at <- decode.field("created_at", decode.string)
  use version <- decode.field("version", decode.int)

  use claim_count <- decode.field("claim_count", decode.int)
  use release_count <- decode.field("release_count", decode.int)
  use complete_count <- decode.field("complete_count", decode.int)
  use first_claim_at <- decode.optional_field(
    "first_claim_at",
    option.None,
    decode.optional(decode.string),
  )

  use task_type <- decode.field("task_type", task_type_inline_decoder())
  use ongoing_by <- decode.optional_field(
    "ongoing_by",
    option.None,
    decode.optional(ongoing_by_decoder()),
  )
  use work_state <- decode.field("work_state", work_state_decoder())

  let task =
    Task(
      id: id,
      project_id: project_id,
      type_id: type_id,
      task_type: task_type,
      ongoing_by: ongoing_by,
      title: title,
      description: description,
      priority: priority,
      status: status,
      work_state: work_state,
      created_by: created_by,
      claimed_by: claimed_by,
      claimed_at: claimed_at,
      completed_at: completed_at,
      created_at: created_at,
      version: version,
    )

  decode.success(MetricsProjectTask(
    task: task,
    claim_count: claim_count,
    release_count: release_count,
    complete_count: complete_count,
    first_claim_at: first_claim_at,
  ))
}

fn org_metrics_project_tasks_payload_decoder() -> decode.Decoder(
  OrgMetricsProjectTasksPayload,
) {
  use window_days <- decode.field("window_days", decode.int)
  use project_id <- decode.field("project_id", decode.int)
  use tasks <- decode.field(
    "tasks",
    decode.list(metrics_project_task_decoder()),
  )

  decode.success(OrgMetricsProjectTasksPayload(
    window_days: window_days,
    project_id: project_id,
    tasks: tasks,
  ))
}

fn org_user_decoder() -> decode.Decoder(OrgUser) {
  use id <- decode.field("id", decode.int)
  use email <- decode.field("email", decode.string)
  use role <- decode.field("org_role", decode.string)
  use created_at <- decode.field("created_at", decode.string)
  decode.success(OrgUser(
    id: id,
    email: email,
    org_role: role,
    created_at: created_at,
  ))
}

fn task_type_inline_decoder() -> decode.Decoder(TaskTypeInline) {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  use icon <- decode.field("icon", decode.string)
  decode.success(TaskTypeInline(id: id, name: name, icon: icon))
}

fn ongoing_by_decoder() -> decode.Decoder(OngoingBy) {
  use user_id <- decode.field("user_id", decode.int)
  decode.success(OngoingBy(user_id: user_id))
}

fn work_state_decoder() -> decode.Decoder(WorkState) {
  decode.string
  |> decode.map(fn(raw) {
    case raw {
      "available" -> WorkAvailable
      "claimed" -> WorkClaimed
      "ongoing" -> WorkOngoing
      "completed" -> WorkCompleted
      _ -> WorkClaimed
    }
  })
}

pub fn task_decoder() -> decode.Decoder(Task) {
  use id <- decode.field("id", decode.int)
  use project_id <- decode.field("project_id", decode.int)
  use type_id <- decode.field("type_id", decode.int)

  use task_type <- decode.field("task_type", task_type_inline_decoder())

  use ongoing_by <- decode.optional_field(
    "ongoing_by",
    option.None,
    decode.optional(ongoing_by_decoder()),
  )

  use title <- decode.field("title", decode.string)

  use description <- decode.optional_field(
    "description",
    option.None,
    decode.optional(decode.string),
  )

  use priority <- decode.field("priority", decode.int)

  use status_raw <- decode.field("status", decode.string)
  let status = case parse_task_status(status_raw) {
    Ok(s) -> s
    Error(_) -> Available
  }

  use work_state <- decode.field("work_state", work_state_decoder())

  use created_by <- decode.field("created_by", decode.int)

  use claimed_by <- decode.optional_field(
    "claimed_by",
    option.None,
    decode.optional(decode.int),
  )

  use claimed_at <- decode.optional_field(
    "claimed_at",
    option.None,
    decode.optional(decode.string),
  )

  use completed_at <- decode.optional_field(
    "completed_at",
    option.None,
    decode.optional(decode.string),
  )

  use created_at <- decode.field("created_at", decode.string)
  use version <- decode.field("version", decode.int)

  decode.success(Task(
    id: id,
    project_id: project_id,
    type_id: type_id,
    task_type: task_type,
    ongoing_by: ongoing_by,
    title: title,
    description: description,
    priority: priority,
    status: status,
    work_state: work_state,
    created_by: created_by,
    claimed_by: claimed_by,
    claimed_at: claimed_at,
    completed_at: completed_at,
    created_at: created_at,
    version: version,
  ))
}

fn note_decoder() -> decode.Decoder(TaskNote) {
  use id <- decode.field("id", decode.int)
  use task_id <- decode.field("task_id", decode.int)
  use user_id <- decode.field("user_id", decode.int)
  use content <- decode.field("content", decode.string)
  use created_at <- decode.field("created_at", decode.string)

  decode.success(TaskNote(
    id: id,
    task_id: task_id,
    user_id: user_id,
    content: content,
    created_at: created_at,
  ))
}

fn position_decoder() -> decode.Decoder(TaskPosition) {
  use task_id <- decode.field("task_id", decode.int)
  use user_id <- decode.field("user_id", decode.int)
  use x <- decode.field("x", decode.int)
  use y <- decode.field("y", decode.int)
  use updated_at <- decode.field("updated_at", decode.string)

  decode.success(TaskPosition(
    task_id: task_id,
    user_id: user_id,
    x: x,
    y: y,
    updated_at: updated_at,
  ))
}

pub fn fetch_me(to_msg: fn(ApiResult(User)) -> msg) -> Effect(msg) {
  request("GET", "/api/v1/auth/me", option.None, user_payload_decoder(), to_msg)
}

pub fn validate_invite_link_token(
  token: String,
  to_msg: fn(ApiResult(String)) -> msg,
) -> Effect(msg) {
  let decoder = decode.field("email", decode.string, decode.success)

  request(
    "GET",
    "/api/v1/auth/invite-links/" <> encode_uri_component(token),
    option.None,
    decoder,
    to_msg,
  )
}

pub fn register_with_invite_link(
  invite_token: String,
  password: String,
  to_msg: fn(ApiResult(User)) -> msg,
) -> Effect(msg) {
  let body =
    json.object([
      #("password", json.string(password)),
      #("invite_token", json.string(invite_token)),
    ])

  request(
    "POST",
    "/api/v1/auth/register",
    option.Some(body),
    user_payload_decoder(),
    to_msg,
  )
}

pub type PasswordReset {
  PasswordReset(token: String, url_path: String)
}

pub fn request_password_reset(
  email: String,
  to_msg: fn(ApiResult(PasswordReset)) -> msg,
) -> Effect(msg) {
  let body = json.object([#("email", json.string(string.trim(email)))])

  let decoder = {
    use token <- decode.field("token", decode.string)
    use url_path <- decode.field("url_path", decode.string)
    decode.success(PasswordReset(token: token, url_path: url_path))
  }

  let envelope_decoder = decode.field("reset", decoder, decode.success)

  request(
    "POST",
    "/api/v1/auth/password-resets",
    option.Some(body),
    envelope_decoder,
    to_msg,
  )
}

pub fn validate_password_reset_token(
  token: String,
  to_msg: fn(ApiResult(String)) -> msg,
) -> Effect(msg) {
  let decoder = decode.field("email", decode.string, decode.success)

  request(
    "GET",
    "/api/v1/auth/password-resets/" <> encode_uri_component(token),
    option.None,
    decoder,
    to_msg,
  )
}

pub fn consume_password_reset_token(
  token: String,
  password: String,
  to_msg: fn(ApiResult(Nil)) -> msg,
) -> Effect(msg) {
  let body =
    json.object([
      #("token", json.string(token)),
      #("password", json.string(password)),
    ])

  request_nil(
    "POST",
    "/api/v1/auth/password-resets/consume",
    option.Some(body),
    to_msg,
  )
}

pub fn login(
  email: String,
  password: String,
  to_msg: fn(ApiResult(User)) -> msg,
) -> Effect(msg) {
  let body =
    json.object([
      #("email", json.string(email)),
      #("password", json.string(password)),
    ])
  request(
    "POST",
    "/api/v1/auth/login",
    option.Some(body),
    user_payload_decoder(),
    to_msg,
  )
}

pub fn logout(to_msg: fn(ApiResult(Nil)) -> msg) -> Effect(msg) {
  request_nil("POST", "/api/v1/auth/logout", option.None, to_msg)
}

pub fn list_projects(to_msg: fn(ApiResult(List(Project))) -> msg) -> Effect(msg) {
  let decoder =
    decode.field("projects", decode.list(project_decoder()), decode.success)
  request("GET", "/api/v1/projects", option.None, decoder, to_msg)
}

pub fn create_project(
  name: String,
  to_msg: fn(ApiResult(Project)) -> msg,
) -> Effect(msg) {
  let body = json.object([#("name", json.string(name))])
  let decoder = decode.field("project", project_decoder(), decode.success)
  request("POST", "/api/v1/projects", option.Some(body), decoder, to_msg)
}

pub fn create_invite(
  expires_in_hours: option.Option(Int),
  to_msg: fn(ApiResult(OrgInvite)) -> msg,
) -> Effect(msg) {
  let body =
    json.object(case expires_in_hours {
      option.Some(hours) -> [#("expires_in_hours", json.int(hours))]
      option.None -> []
    })

  let decoder = decode.field("invite", invite_decoder(), decode.success)
  request("POST", "/api/v1/org/invites", option.Some(body), decoder, to_msg)
}

pub fn list_invite_links(
  to_msg: fn(ApiResult(List(InviteLink))) -> msg,
) -> Effect(msg) {
  request(
    "GET",
    "/api/v1/org/invite-links",
    option.None,
    invite_links_payload_decoder(),
    to_msg,
  )
}

pub fn create_invite_link(
  email: String,
  to_msg: fn(ApiResult(InviteLink)) -> msg,
) -> Effect(msg) {
  let body = json.object([#("email", json.string(string.trim(email)))])
  request(
    "POST",
    "/api/v1/org/invite-links",
    option.Some(body),
    invite_link_payload_decoder(),
    to_msg,
  )
}

pub fn regenerate_invite_link(
  email: String,
  to_msg: fn(ApiResult(InviteLink)) -> msg,
) -> Effect(msg) {
  let body = json.object([#("email", json.string(string.trim(email)))])
  request(
    "POST",
    "/api/v1/org/invite-links/regenerate",
    option.Some(body),
    invite_link_payload_decoder(),
    to_msg,
  )
}

pub fn list_capabilities(
  to_msg: fn(ApiResult(List(Capability))) -> msg,
) -> Effect(msg) {
  let decoder =
    decode.field(
      "capabilities",
      decode.list(capability_decoder()),
      decode.success,
    )
  request("GET", "/api/v1/capabilities", option.None, decoder, to_msg)
}

pub fn create_capability(
  name: String,
  to_msg: fn(ApiResult(Capability)) -> msg,
) -> Effect(msg) {
  let body = json.object([#("name", json.string(name))])
  let decoder = decode.field("capability", capability_decoder(), decode.success)
  request("POST", "/api/v1/capabilities", option.Some(body), decoder, to_msg)
}

pub fn list_org_users(
  query: String,
  to_msg: fn(ApiResult(List(OrgUser))) -> msg,
) -> Effect(msg) {
  let q = string.trim(query)

  let url = case q == "" {
    True -> "/api/v1/org/users"
    False -> "/api/v1/org/users?q=" <> encode_uri_component(q)
  }

  let decoder =
    decode.field("users", decode.list(org_user_decoder()), decode.success)
  request("GET", url, option.None, decoder, to_msg)
}

pub fn update_org_user_role(
  user_id: Int,
  org_role: String,
  to_msg: fn(ApiResult(OrgUser)) -> msg,
) -> Effect(msg) {
  let body = json.object([#("org_role", json.string(org_role))])

  let decoder = decode.field("user", org_user_decoder(), decode.success)

  request(
    "PATCH",
    "/api/v1/org/users/" <> int.to_string(user_id),
    option.Some(body),
    decoder,
    to_msg,
  )
}

pub fn list_project_members(
  project_id: Int,
  to_msg: fn(ApiResult(List(ProjectMember))) -> msg,
) -> Effect(msg) {
  let decoder =
    decode.field(
      "members",
      decode.list(project_member_decoder()),
      decode.success,
    )
  request(
    "GET",
    "/api/v1/projects/" <> int.to_string(project_id) <> "/members",
    option.None,
    decoder,
    to_msg,
  )
}

pub fn add_project_member(
  project_id: Int,
  user_id: Int,
  role: String,
  to_msg: fn(ApiResult(ProjectMember)) -> msg,
) -> Effect(msg) {
  let body =
    json.object([#("user_id", json.int(user_id)), #("role", json.string(role))])
  let decoder = decode.field("member", project_member_decoder(), decode.success)
  request(
    "POST",
    "/api/v1/projects/" <> int.to_string(project_id) <> "/members",
    option.Some(body),
    decoder,
    to_msg,
  )
}

pub fn remove_project_member(
  project_id: Int,
  user_id: Int,
  to_msg: fn(ApiResult(Nil)) -> msg,
) -> Effect(msg) {
  request_nil(
    "DELETE",
    "/api/v1/projects/"
      <> int.to_string(project_id)
      <> "/members/"
      <> int.to_string(user_id),
    option.None,
    to_msg,
  )
}

pub fn list_task_types(
  project_id: Int,
  to_msg: fn(ApiResult(List(TaskType))) -> msg,
) -> Effect(msg) {
  let decoder =
    decode.field("task_types", decode.list(task_type_decoder()), decode.success)
  request(
    "GET",
    "/api/v1/projects/" <> int.to_string(project_id) <> "/task-types",
    option.None,
    decoder,
    to_msg,
  )
}

pub type TaskFilters {
  TaskFilters(
    status: option.Option(String),
    type_id: option.Option(Int),
    capability_id: option.Option(Int),
    q: option.Option(String),
  )
}

pub fn project_tasks_url(project_id: Int, filters: TaskFilters) -> String {
  let TaskFilters(
    status: status,
    type_id: type_id,
    capability_id: capability_id,
    q: q,
  ) = filters

  let params =
    ""
    |> add_param_string("status", status)
    |> add_param_int("type_id", type_id)
    |> add_param_int("capability_id", capability_id)
    |> add_param_string("q", q)

  "/api/v1/projects/" <> int.to_string(project_id) <> "/tasks" <> params
}

pub fn list_project_tasks(
  project_id: Int,
  filters: TaskFilters,
  to_msg: fn(ApiResult(List(Task))) -> msg,
) -> Effect(msg) {
  let url = project_tasks_url(project_id, filters)

  let decoder =
    decode.field("tasks", decode.list(task_decoder()), decode.success)

  request("GET", url, option.None, decoder, to_msg)
}

pub fn create_task(
  project_id: Int,
  title: String,
  description: option.Option(String),
  priority: Int,
  type_id: Int,
  to_msg: fn(ApiResult(Task)) -> msg,
) -> Effect(msg) {
  let entries = [
    #("title", json.string(title)),
    #("priority", json.int(priority)),
    #("type_id", json.int(type_id)),
  ]

  let entries = case description {
    option.Some(desc) ->
      list.append(entries, [#("description", json.string(desc))])
    option.None -> entries
  }

  let body = json.object(entries)
  let decoder = decode.field("task", task_decoder(), decode.success)

  request(
    "POST",
    "/api/v1/projects/" <> int.to_string(project_id) <> "/tasks",
    option.Some(body),
    decoder,
    to_msg,
  )
}

pub fn claim_task(
  task_id: Int,
  version: Int,
  to_msg: fn(ApiResult(Task)) -> msg,
) -> Effect(msg) {
  let body = json.object([#("version", json.int(version))])
  let decoder = decode.field("task", task_decoder(), decode.success)
  request(
    "POST",
    "/api/v1/tasks/" <> int.to_string(task_id) <> "/claim",
    option.Some(body),
    decoder,
    to_msg,
  )
}

pub fn release_task(
  task_id: Int,
  version: Int,
  to_msg: fn(ApiResult(Task)) -> msg,
) -> Effect(msg) {
  let body = json.object([#("version", json.int(version))])
  let decoder = decode.field("task", task_decoder(), decode.success)
  request(
    "POST",
    "/api/v1/tasks/" <> int.to_string(task_id) <> "/release",
    option.Some(body),
    decoder,
    to_msg,
  )
}

pub fn complete_task(
  task_id: Int,
  version: Int,
  to_msg: fn(ApiResult(Task)) -> msg,
) -> Effect(msg) {
  let body = json.object([#("version", json.int(version))])
  let decoder = decode.field("task", task_decoder(), decode.success)
  request(
    "POST",
    "/api/v1/tasks/" <> int.to_string(task_id) <> "/complete",
    option.Some(body),
    decoder,
    to_msg,
  )
}

pub fn list_task_notes(
  task_id: Int,
  to_msg: fn(ApiResult(List(TaskNote))) -> msg,
) -> Effect(msg) {
  let decoder =
    decode.field("notes", decode.list(note_decoder()), decode.success)
  request(
    "GET",
    "/api/v1/tasks/" <> int.to_string(task_id) <> "/notes",
    option.None,
    decoder,
    to_msg,
  )
}

pub fn add_task_note(
  task_id: Int,
  content: String,
  to_msg: fn(ApiResult(TaskNote)) -> msg,
) -> Effect(msg) {
  let body = json.object([#("content", json.string(content))])
  let decoder = decode.field("note", note_decoder(), decode.success)

  request(
    "POST",
    "/api/v1/tasks/" <> int.to_string(task_id) <> "/notes",
    option.Some(body),
    decoder,
    to_msg,
  )
}

pub fn get_me_active_task(
  to_msg: fn(ApiResult(ActiveTaskPayload)) -> msg,
) -> Effect(msg) {
  request(
    "GET",
    "/api/v1/me/active-task",
    option.None,
    active_task_payload_decoder(),
    to_msg,
  )
}

pub fn start_me_active_task(
  task_id: Int,
  to_msg: fn(ApiResult(ActiveTaskPayload)) -> msg,
) -> Effect(msg) {
  let body = json.object([#("task_id", json.int(task_id))])
  request(
    "POST",
    "/api/v1/me/active-task/start",
    option.Some(body),
    active_task_payload_decoder(),
    to_msg,
  )
}

pub fn pause_me_active_task(
  to_msg: fn(ApiResult(ActiveTaskPayload)) -> msg,
) -> Effect(msg) {
  request(
    "POST",
    "/api/v1/me/active-task/pause",
    option.None,
    active_task_payload_decoder(),
    to_msg,
  )
}

pub fn heartbeat_me_active_task(
  to_msg: fn(ApiResult(ActiveTaskPayload)) -> msg,
) -> Effect(msg) {
  request(
    "POST",
    "/api/v1/me/active-task/heartbeat",
    option.None,
    active_task_payload_decoder(),
    to_msg,
  )
}

pub fn get_me_metrics(
  window_days: Int,
  to_msg: fn(ApiResult(MyMetrics)) -> msg,
) -> Effect(msg) {
  let decoder = decode.field("metrics", my_metrics_decoder(), decode.success)
  request(
    "GET",
    "/api/v1/me/metrics?window_days=" <> int.to_string(window_days),
    option.None,
    decoder,
    to_msg,
  )
}

pub fn get_org_metrics_overview(
  window_days: Int,
  to_msg: fn(ApiResult(OrgMetricsOverview)) -> msg,
) -> Effect(msg) {
  let decoder =
    decode.field("overview", org_metrics_overview_decoder(), decode.success)

  request(
    "GET",
    "/api/v1/org/metrics/overview?window_days=" <> int.to_string(window_days),
    option.None,
    decoder,
    to_msg,
  )
}

pub fn get_org_metrics_project_tasks(
  project_id: Int,
  window_days: Int,
  to_msg: fn(ApiResult(OrgMetricsProjectTasksPayload)) -> msg,
) -> Effect(msg) {
  request(
    "GET",
    "/api/v1/org/metrics/projects/"
      <> int.to_string(project_id)
      <> "/tasks?window_days="
      <> int.to_string(window_days),
    option.None,
    org_metrics_project_tasks_payload_decoder(),
    to_msg,
  )
}

pub fn list_me_task_positions(
  project_id: option.Option(Int),
  to_msg: fn(ApiResult(List(TaskPosition))) -> msg,
) -> Effect(msg) {
  let url = case project_id {
    option.None -> "/api/v1/me/task-positions"
    option.Some(id) ->
      "/api/v1/me/task-positions?project_id=" <> int.to_string(id)
  }

  let decoder =
    decode.field("positions", decode.list(position_decoder()), decode.success)

  request("GET", url, option.None, decoder, to_msg)
}

pub fn upsert_me_task_position(
  task_id: Int,
  x: Int,
  y: Int,
  to_msg: fn(ApiResult(TaskPosition)) -> msg,
) -> Effect(msg) {
  let body = json.object([#("x", json.int(x)), #("y", json.int(y))])
  let decoder = decode.field("position", position_decoder(), decode.success)

  request(
    "PUT",
    "/api/v1/me/task-positions/" <> int.to_string(task_id),
    option.Some(body),
    decoder,
    to_msg,
  )
}

pub fn get_me_capability_ids(
  to_msg: fn(ApiResult(List(Int))) -> msg,
) -> Effect(msg) {
  let decoder =
    decode.field("capability_ids", decode.list(decode.int), decode.success)
  request("GET", "/api/v1/me/capabilities", option.None, decoder, to_msg)
}

pub fn put_me_capability_ids(
  ids: List(Int),
  to_msg: fn(ApiResult(List(Int))) -> msg,
) -> Effect(msg) {
  let body = json.object([#("capability_ids", json.array(ids, of: json.int))])
  let decoder =
    decode.field("capability_ids", decode.list(decode.int), decode.success)
  request("PUT", "/api/v1/me/capabilities", option.Some(body), decoder, to_msg)
}

fn add_param_string(
  existing: String,
  key: String,
  value: option.Option(String),
) -> String {
  case value {
    option.None -> existing
    option.Some(v) ->
      existing
      <> append_query(existing)
      <> key
      <> "="
      <> encode_uri_component(v)
  }
}

fn add_param_int(
  existing: String,
  key: String,
  value: option.Option(Int),
) -> String {
  case value {
    option.None -> existing
    option.Some(v) ->
      existing <> append_query(existing) <> key <> "=" <> int.to_string(v)
  }
}

fn append_query(existing: String) -> String {
  case string.contains(existing, "?") {
    True -> "&"
    False -> "?"
  }
}

pub fn create_task_type(
  project_id: Int,
  name: String,
  icon: String,
  capability_id: option.Option(Int),
  to_msg: fn(ApiResult(TaskType)) -> msg,
) -> Effect(msg) {
  let base = [#("name", json.string(name)), #("icon", json.string(icon))]

  let entries = case capability_id {
    option.Some(id) -> list.append(base, [#("capability_id", json.int(id))])
    option.None -> base
  }

  let body = json.object(entries)
  let decoder = decode.field("task_type", task_type_decoder(), decode.success)

  request(
    "POST",
    "/api/v1/projects/" <> int.to_string(project_id) <> "/task-types",
    option.Some(body),
    decoder,
    to_msg,
  )
}
