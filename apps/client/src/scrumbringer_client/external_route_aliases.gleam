//// External URL aliases for pre-canonical client routes.
////
//// These aliases exist only for incoming URLs such as old bookmarks. Route
//// formatting must continue to use canonical paths.

import gleam/option.{type Option, None, Some}

import scrumbringer_client/permissions

pub fn config_section(slug: String) -> Option(permissions.AdminSection) {
  case slug {
    "templates" | "rule-metrics" -> Some(permissions.Members)
    _ -> None
  }
}

pub fn org_section(slug: String) -> Option(permissions.AdminSection) {
  case slug {
    "assignments" -> Some(permissions.Team)
    _ -> None
  }
}
