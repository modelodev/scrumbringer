//// Helpers for serialising values used by HTML attributes.

pub fn boolean(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
}
