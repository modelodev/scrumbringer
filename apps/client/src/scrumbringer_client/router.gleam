//// URL routing for Scrumbringer client.
////
//// ## Mission
////
//// Provides URL parsing, formatting, and navigation effects for client-side
//// routing. Handles both modern path-based URLs and legacy hash-based URLs
//// for backwards compatibility.
////
//// ## Responsibilities
////
//// - Route type definitions (Login, Admin, Member, etc.)
//// - URL parsing (`parse`) with legacy hash support
//// - URL formatting (`format`)
//// - Navigation effects (`push`, `replace`)
//// - Page title updates (`update_page_title`)
//// - Mobile-specific routing rules (`apply_mobile_rules`)
////
//// ## Non-responsibilities
////
//// - Model state changes (see client_update.gleam)
//// - Hydration effects (see hydration.gleam)
////
//// ## Usage
////
//// ```gleam
//// import scrumbringer_client/router
////
//// // Parse URL
//// case router.parse("/admin/members", "?project=5", "") {
////   router.Parsed(route) -> apply_route(route)
////   router.Redirect(route) -> redirect_to(route)
//// }
////
//// // Format URL
//// let url = router.format(router.Admin(permissions.Members, Some(5)))
//// // "/admin/members?project=5"
////
//// // Navigate with push (adds history entry)
//// router.push(router.Admin(permissions.Projects, None))
////
//// // Navigate with replace (no history entry)
//// router.replace(router.Login)
////
//// // Update browser title
//// router.update_page_title(route, locale)
//// ```

import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

import lustre/effect.{type Effect}

import scrumbringer_client/client_ffi
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale as i18n_locale
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/member_section.{type MemberSection}
import scrumbringer_client/permissions

/// Client route representing the current page and state.
///
/// ## Example
///
/// ```gleam
/// let route = router.Admin(permissions.Members, Some(5))
/// router.format(route)  // "/admin/members?project=5"
/// ```
pub type Route {
  Login
  AcceptInvite(token: String)
  ResetPassword(token: String)
  Admin(section: permissions.AdminSection, project_id: Option(Int))
  Member(section: MemberSection, project_id: Option(Int))
}

/// Result of parsing a URL, indicating whether it was parsed directly
/// or needs a redirect (for legacy URLs or invalid query params).
pub type ParseResult {
  Parsed(Route)
  Redirect(Route)
}

/// Parse URL components into a Route.
///
/// Handles both modern path-based URLs and legacy hash-based URLs.
/// Returns Redirect if the URL uses legacy format or has invalid query params.
///
/// ## Example
///
/// ```gleam
/// parse("/admin/members", "?project=5", "")
/// // Parsed(Admin(Members, Some(5)))
///
/// parse("/", "", "#/admin/members")
/// // Redirect(Admin(Members, None))  -- legacy hash format
/// ```
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

/// Format a Route into a URL string.
///
/// ## Example
///
/// ```gleam
/// format(Login)  // "/"
/// format(Admin(Members, Some(5)))  // "/admin/members?project=5"
/// format(AcceptInvite("abc123"))  // "/accept-invite?token=abc123"
/// ```
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
    "cards" -> permissions.Cards
    "workflows" -> permissions.Workflows
    "task-templates" -> permissions.TaskTemplates
    _ -> permissions.Invites
  }
}

fn admin_section_slug(section: permissions.AdminSection) -> String {
  case section {
    permissions.Invites -> "invites"
    permissions.OrgSettings -> "org-settings"
    permissions.Projects -> "projects"
    permissions.Metrics -> "metrics"
    permissions.RuleMetrics -> "rule-metrics"
    permissions.Members -> "members"
    permissions.Capabilities -> "capabilities"
    permissions.TaskTypes -> "task-types"
    permissions.Cards -> "cards"
    permissions.Workflows -> "workflows"
    permissions.TaskTemplates -> "task-templates"
  }
}

/// Apply mobile-specific routing rules.
///
/// On mobile devices, redirects Pool section to MyBar since Pool
/// requires drag-and-drop which is not supported on mobile.
///
/// ## Example
///
/// ```gleam
/// let result = parse("/app/pool", "", "")
/// apply_mobile_rules(result, True)
/// // Redirect(Member(MyBar, None))
/// ```
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

// =============================================================================
// Navigation Effects
// =============================================================================

/// Push a new URL to browser history (adds back button entry).
///
/// ## Example
///
/// ```gleam
/// router.push(router.Admin(permissions.Projects, Some(5)))
/// // Navigates to "/admin/projects?project=5" with history entry
/// ```
pub fn push(route: Route) -> Effect(msg) {
  let url = format(route)
  effect.from(fn(_dispatch) { client_ffi.history_push_state(url) })
}

/// Replace the current URL in browser history (no back button entry).
///
/// ## Example
///
/// ```gleam
/// router.replace(router.Login)
/// // Replaces current URL with "/" without history entry
/// ```
pub fn replace(route: Route) -> Effect(msg) {
  let url = format(route)
  effect.from(fn(_dispatch) { client_ffi.history_replace_state(url) })
}

/// Update the browser document title based on the current route.
///
/// Sets the title in the format "Section - Scrumbringer" for authenticated
/// pages, or just "Scrumbringer" for login/public pages.
///
/// ## Example
///
/// ```gleam
/// router.update_page_title(router.Admin(permissions.Projects, None), locale)
/// // Sets document title to "Projects - Scrumbringer"
/// ```
pub fn update_page_title(route: Route, locale: i18n_locale.Locale) -> Effect(msg) {
  let title = page_title_for_route(route, locale)
  effect.from(fn(_dispatch) { client_ffi.set_document_title(title) })
}

/// Get the page title string for a route.
///
/// Returns the full title string (e.g., "Projects - Scrumbringer").
pub fn page_title_for_route(route: Route, locale: i18n_locale.Locale) -> String {
  let section_title = case route {
    Login -> None
    AcceptInvite(_) -> None
    ResetPassword(_) -> None

    Admin(section, _) -> Some(admin_section_title(section, locale))

    Member(section, _) -> Some(member_section_title(section, locale))
  }

  case section_title {
    None -> "Scrumbringer"
    Some(title) -> title <> " - Scrumbringer"
  }
}

/// Get the i18n text key for an admin section title.
fn admin_section_title(
  section: permissions.AdminSection,
  locale: i18n_locale.Locale,
) -> String {
  let text = case section {
    permissions.Invites -> i18n_text.AdminInvites
    permissions.OrgSettings -> i18n_text.AdminOrgSettings
    permissions.Projects -> i18n_text.AdminProjects
    permissions.Metrics -> i18n_text.AdminMetrics
    permissions.RuleMetrics -> i18n_text.AdminRuleMetrics
    permissions.Members -> i18n_text.AdminMembers
    permissions.Capabilities -> i18n_text.AdminCapabilities
    permissions.TaskTypes -> i18n_text.AdminTaskTypes
    permissions.Cards -> i18n_text.AdminCards
    permissions.Workflows -> i18n_text.AdminWorkflows
    permissions.TaskTemplates -> i18n_text.AdminTaskTemplates
  }
  i18n.t(locale, text)
}

/// Get the i18n text key for a member section title.
fn member_section_title(
  section: MemberSection,
  locale: i18n_locale.Locale,
) -> String {
  let text = case section {
    member_section.Pool -> i18n_text.Pool
    member_section.MyBar -> i18n_text.MyBar
    member_section.MySkills -> i18n_text.MySkills
    member_section.Fichas -> i18n_text.MemberFichas
  }
  i18n.t(locale, text)
}
