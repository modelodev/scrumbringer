import gleeunit/should

import domain/api_error.{ApiError}
import domain/remote.{Failed, Loaded, Loading, NotAsked}
import scrumbringer_client/client_state.{
  Rect, rect_contains_point, remote_to_resource_state,
}
import scrumbringer_client/hydration

// =============================================================================
// rect_contains_point tests
// =============================================================================

pub fn rect_contains_point_center_test() {
  let rect = Rect(left: 10, top: 10, width: 100, height: 100)

  rect_contains_point(rect, 50, 50)
  |> should.be_true
}

pub fn rect_contains_point_top_left_corner_test() {
  let rect = Rect(left: 10, top: 10, width: 100, height: 100)

  // Inclusive bounds - point at top-left corner
  rect_contains_point(rect, 10, 10)
  |> should.be_true
}

pub fn rect_contains_point_bottom_right_corner_test() {
  let rect = Rect(left: 10, top: 10, width: 100, height: 100)

  // Inclusive bounds - point at bottom-right corner (10 + 100 = 110)
  rect_contains_point(rect, 110, 110)
  |> should.be_true
}

pub fn rect_contains_point_outside_left_test() {
  let rect = Rect(left: 10, top: 10, width: 100, height: 100)

  rect_contains_point(rect, 5, 50)
  |> should.be_false
}

pub fn rect_contains_point_outside_right_test() {
  let rect = Rect(left: 10, top: 10, width: 100, height: 100)

  rect_contains_point(rect, 115, 50)
  |> should.be_false
}

pub fn rect_contains_point_outside_top_test() {
  let rect = Rect(left: 10, top: 10, width: 100, height: 100)

  rect_contains_point(rect, 50, 5)
  |> should.be_false
}

pub fn rect_contains_point_outside_bottom_test() {
  let rect = Rect(left: 10, top: 10, width: 100, height: 100)

  rect_contains_point(rect, 50, 115)
  |> should.be_false
}

pub fn rect_contains_point_zero_origin_test() {
  let rect = Rect(left: 0, top: 0, width: 50, height: 50)

  rect_contains_point(rect, 0, 0)
  |> should.be_true

  rect_contains_point(rect, 25, 25)
  |> should.be_true

  rect_contains_point(rect, 50, 50)
  |> should.be_true
}

pub fn rect_contains_point_negative_coords_outside_test() {
  let rect = Rect(left: 0, top: 0, width: 50, height: 50)

  rect_contains_point(rect, -1, 25)
  |> should.be_false

  rect_contains_point(rect, 25, -1)
  |> should.be_false
}

// =============================================================================
// remote_to_resource_state tests
// =============================================================================

pub fn remote_to_resource_state_not_asked_test() {
  remote_to_resource_state(NotAsked)
  |> should.equal(hydration.NotAsked)
}

pub fn remote_to_resource_state_loading_test() {
  remote_to_resource_state(Loading)
  |> should.equal(hydration.Loading)
}

pub fn remote_to_resource_state_loaded_test() {
  // The inner value doesn't matter, just the variant
  remote_to_resource_state(Loaded([1, 2, 3]))
  |> should.equal(hydration.Loaded)
}

pub fn remote_to_resource_state_loaded_empty_test() {
  // Empty list is still Loaded
  remote_to_resource_state(Loaded([]))
  |> should.equal(hydration.Loaded)
}

pub fn remote_to_resource_state_failed_test() {
  let error = ApiError(status: 500, code: "SERVER_ERROR", message: "Oops")

  remote_to_resource_state(Failed(error))
  |> should.equal(hydration.Failed)
}

pub fn remote_to_resource_state_failed_401_test() {
  let error = ApiError(status: 401, code: "UNAUTHORIZED", message: "Login")

  remote_to_resource_state(Failed(error))
  |> should.equal(hydration.Failed)
}
