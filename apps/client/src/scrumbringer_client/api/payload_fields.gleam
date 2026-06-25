//// Shared JSON field encoders for API payload conventions.

import gleam/json

/// Encode the numeric PATCH `active` flag expected by workflow/rule endpoints.
pub fn active_update_field(active: Bool) -> #(String, json.Json) {
  #("active", json.int(active_flag_value(active)))
}

fn active_flag_value(active: Bool) -> Int {
  case active {
    True -> 1
    False -> 0
  }
}
