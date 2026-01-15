import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

import scrumbringer_client/member_section.{type MemberSection}
import scrumbringer_client/permissions

pub type Route {
  Login
  AcceptInvite(token: String)
  ResetPassword(token: String)
  Admin(section: permissions.AdminSection, project_id: Option(Int))
  Member(section: MemberSection, project_id: Option(Int))
}

pub type ParseResult {
  Parsed(Route)
  Redirect(Route)
}

pub fn parse(pathname: String, search: String, hash: String) -> ParseResult {
  // Legacy support: old hash routing `/?project=2#/admin/members`.
  let legacy = case pathname == "/" {
    True -> parse_legacy_hash(hash, search)
    False -> None
  }

  let route = case legacy {
    Some(route) -> route
    None -> parse_pathname(pathname, search)
  }

  // Normalize invalid `project=` query values by removing them (replaceState).
  case legacy != None || has_invalid_project(search) {
    True -> Redirect(route)
    False -> Parsed(route)
  }
}

fn has_invalid_project(search: String) -> Bool {
  case query_param(search, "project") {
    None -> False

    Some(raw) ->
      case int.parse(raw) {
        Ok(_) -> False
        Error(_) -> True
      }
  }
}

fn parse_legacy_hash(hash: String, search: String) -> Option(Route) {
  case string.starts_with(hash, "#/admin/") {
    True -> {
      let slug = drop_prefix(hash, "#/admin/")
      let section = admin_section_from_slug(slug)
      Some(Admin(section, project_id_from_search(search)))
    }

    False ->
      case string.starts_with(hash, "#/app/") {
        True -> {
          let slug = drop_prefix(hash, "#/app/")
          let section = member_section.from_slug(slug)
          Some(Member(section, project_id_from_search(search)))
        }

        False -> None
      }
  }
}

fn parse_pathname(pathname: String, search: String) -> Route {
  case pathname {
    "/" -> Login

    "/accept-invite" -> AcceptInvite(token_from_search(search))

    "/reset-password" -> ResetPassword(token_from_search(search))

    _ -> {
      case string.starts_with(pathname, "/admin") {
        True -> {
          let slug = path_segment(pathname, "/admin")
          Admin(admin_section_from_slug(slug), project_id_from_search(search))
        }

        False ->
          case string.starts_with(pathname, "/app") {
            True -> {
              let slug = path_segment(pathname, "/app")
              Member(
                member_section.from_slug(slug),
                project_id_from_search(search),
              )
            }

            False -> Login
          }
      }
    }
  }
}

pub fn format(route: Route) -> String {
  case route {
    Login -> "/"

    AcceptInvite(token) ->
      case token {
        "" -> "/accept-invite"
        _ -> "/accept-invite?token=" <> token
      }

    ResetPassword(token) ->
      case token {
        "" -> "/reset-password"
        _ -> "/reset-password?token=" <> token
      }

    Admin(section, project_id) -> {
      let base = "/admin/" <> admin_section_slug(section)
      with_project(base, project_id)
    }

    Member(section, project_id) -> {
      let base = "/app/" <> member_section.to_slug(section)
      with_project(base, project_id)
    }
  }
}

fn with_project(base: String, project_id: Option(Int)) -> String {
  case project_id {
    None -> base
    Some(id) -> base <> "?project=" <> int.to_string(id)
  }
}

fn token_from_search(search: String) -> String {
  case query_param(search, "token") {
    Some(token) -> token
    None -> ""
  }
}

fn project_id_from_search(search: String) -> Option(Int) {
  case query_param(search, "project") {
    None -> None

    Some(raw) ->
      case int.parse(raw) {
        Ok(id) -> Some(id)
        Error(_) -> None
      }
  }
}

fn query_param(search: String, key: String) -> Option(String) {
  let cleaned = case string.starts_with(search, "?") {
    True -> string.drop_start(search, 1)
    False -> search
  }

  case cleaned {
    "" -> None

    _ -> {
      let pairs = string.split(cleaned, "&")

      case list.find(pairs, fn(pair) { string.starts_with(pair, key <> "=") }) {
        Ok(pair) -> Some(string.drop_start(pair, string.length(key) + 1))
        Error(_) -> None
      }
    }
  }
}

fn path_segment(pathname: String, prefix: String) -> String {
  let rest = string.drop_start(pathname, string.length(prefix))

  case string.starts_with(rest, "/") {
    True -> string.drop_start(rest, 1)
    False -> rest
  }
}

fn drop_prefix(value: String, prefix: String) -> String {
  string.drop_start(value, string.length(prefix))
}

fn admin_section_from_slug(slug: String) -> permissions.AdminSection {
  case slug {
    "org-settings" -> permissions.OrgSettings
    "projects" -> permissions.Projects
    "metrics" -> permissions.Metrics
    "members" -> permissions.Members
    "capabilities" -> permissions.Capabilities
    "task-types" -> permissions.TaskTypes
    "invites" -> permissions.Invites
    _ -> permissions.Invites
  }
}

fn admin_section_slug(section: permissions.AdminSection) -> String {
  case section {
    permissions.Invites -> "invites"
    permissions.OrgSettings -> "org-settings"
    permissions.Projects -> "projects"
    permissions.Metrics -> "metrics"
    permissions.Members -> "members"
    permissions.Capabilities -> "capabilities"
    permissions.TaskTypes -> "task-types"
  }
}

pub fn apply_mobile_rules(result: ParseResult, is_mobile: Bool) -> ParseResult {
  case is_mobile {
    False -> result

    True ->
      case result {
        Parsed(route) ->
          case route {
            Member(member_section.Pool, project_id) ->
              Redirect(Member(member_section.MyBar, project_id))
            _ -> Parsed(route)
          }

        Redirect(route) ->
          case route {
            Member(member_section.Pool, project_id) ->
              Redirect(Member(member_section.MyBar, project_id))
            _ -> Redirect(route)
          }
      }
  }
}
