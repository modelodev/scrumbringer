import gleam/http/response.{Response}
import gleeunit
import lustre_http

pub fn main() {
  gleeunit.main()
}

pub fn response_to_result_accepts_success_status_test() {
  let response = Response(status: 201, headers: [], body: "created")

  let assert Ok("created") = lustre_http.response_to_result(response)
}

pub fn response_to_result_maps_unauthorized_test() {
  let response = Response(status: 401, headers: [], body: "")

  let assert Error(lustre_http.Unauthorized) =
    lustre_http.response_to_result(response)
}

pub fn response_to_result_maps_not_found_test() {
  let response = Response(status: 404, headers: [], body: "")

  let assert Error(lustre_http.NotFound) =
    lustre_http.response_to_result(response)
}

pub fn response_to_result_keeps_internal_server_error_body_test() {
  let response = Response(status: 500, headers: [], body: "server failed")

  let assert Error(lustre_http.InternalServerError("server failed")) =
    lustre_http.response_to_result(response)
}

pub fn response_to_result_keeps_other_error_status_and_body_test() {
  let response = Response(status: 422, headers: [], body: "invalid")

  let assert Error(lustre_http.OtherError(422, "invalid")) =
    lustre_http.response_to_result(response)
}
