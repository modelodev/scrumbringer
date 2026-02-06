//// URL routing for Scrumbringer client.
////
//// ## Mission
////
//// Provides URL parsing, formatting, and navigation effects for client-side
//// routing using path-based URLs.
////
//// ## Responsibilities
////
//// - Route type definitions (Login, Admin, Member, etc.)
//// - URL parsing (`parse`)
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
//// case router.parse_uri(uri) {
////   router.Parsed(route) -> apply_route(route)
////   router.Redirect(route) -> redirect_to(route)
//// }
////
//// // Format URL
//// let url = router.format(router.Config(permissions.Members, Some(5)))
//// // "/config/members?project=5"
////
//// // Navigate with push (adds history entry)
//// router.push(router.Config(permissions.Projects, None))
////
//// // Navigate with replace (no history entry)
//// router.replace(router.Login)
////
//// // Update browser title
//// router.update_page_title(route, locale)
//// ```

import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import gleam/uri.{type Uri}
import modem

import lustre/effect.{type Effect}

import scrumbringer_client/assignments_view_mode
import scrumbringer_client/client_ffi
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale as i18n_locale
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/member_section.{type MemberSection}
import scrumbringer_client/permissions
import scrumbringer_client/url_state

/// Client route representing the current page and state.
///
/// Story 4.5: Routes use /config/* and /org/* for admin sections.
///
/// ## Example
///
/// ```gleam
/// let route = router.Config(permissions.Members, Some(5))
/// router.format(route)  // "/config/members?project=5"
///
/// let route = router.Org(permissions.Invites)
/// router.format(route)  // "/org/invites"
/// ```
pub type Route {
  Login
  AcceptInvite(token: String)
  ResetPassword(token: String)
  // Story 4.5: New unified routes
  Config(section: permissions.AdminSection, project_id: Option(Int))
  Org(section: permissions.AdminSection)
  Member(section: MemberSection, state: url_state.UrlState)
}

/// Result of parsing a URL, indicating whether it was parsed directly
/// or needs a redirect (for invalid query params).
pub type ParseResult {
  Parsed(Route)
  Redirect(Route)
}

/// Parse URL components into a Route.
///
/// Returns Redirect if the URL has invalid query params.
fn parse(pathname: String, search: String, _hash: String) -> ParseResult {
  parse_pathname(pathname, search)
}

/// Parse a URI into a Route.
pub fn parse_uri(uri: Uri) -> ParseResult {
  let search = case uri.query {
    None -> ""
    Some(query) -> "?" <> query
  }
  let hash = case uri.fragment {
    None -> ""
    Some(fragment) -> "#" <> fragment
  }
  parse(uri.path, search, hash)
}

fn parse_pathname(pathname: String, search: String) -> ParseResult {
  case pathname {
    "/" -> Parsed(Login)

    "/accept-invite" -> Parsed(AcceptInvite(token_from_search(search)))

    "/reset-password" -> Parsed(ResetPassword(token_from_search(search)))

    _ -> parse_app_route(pathname, search)
  }
}

fn parse_app_route(pathname: String, search: String) -> ParseResult {
  case string.starts_with(pathname, "/config") {
    True -> parse_config_route(pathname, search)
    False -> parse_org_route(pathname, search)
  }
}

fn parse_config_route(pathname: String, search: String) -> ParseResult {
  let slug = path_segment(pathname, "/config")
  let section = config_section_from_slug(slug)
  let result = url_state.parse_query(search_to_query(search), url_state.Config)
  let route = case result {
    url_state.Parsed(state) -> Config(section, url_state.project(state))
    url_state.Redirect(state) -> Config(section, url_state.project(state))
  }

  case result {
    url_state.Parsed(_) -> Parsed(route)
    url_state.Redirect(_) -> Redirect(route)
  }
}

fn parse_org_route(pathname: String, search: String) -> ParseResult {
  case string.starts_with(pathname, "/org") {
    True -> parse_org_section(pathname, search)
    False -> parse_member_route(pathname, search)
  }
}

fn parse_org_section(pathname: String, search: String) -> ParseResult {
  let slug = path_segment(pathname, "/org")
  let section = org_section_from_slug(slug)
  let context = case section {
    permissions.Assignments -> url_state.OrgAssignments
    _ -> url_state.Org
  }
  let result = url_state.parse_query(search_to_query(search), context)
  let route = Org(section)

  case result {
    url_state.Parsed(_) -> Parsed(route)
    url_state.Redirect(_) -> Redirect(route)
  }
}

fn parse_member_route(pathname: String, search: String) -> ParseResult {
  case string.starts_with(pathname, "/app") {
    True -> parse_member_section(pathname, search)
    False -> Parsed(Login)
  }
}

fn parse_member_section(pathname: String, search: String) -> ParseResult {
  let slug = path_segment(pathname, "/app")
  let section = member_section.from_slug(slug)
  let result = url_state.parse_query(search_to_query(search), url_state.Member)

  case result {
    url_state.Parsed(state) -> Parsed(Member(section, state))
    url_state.Redirect(state) -> Redirect(Member(section, state))
  }
}

// Justification: nested case improves clarity for branching logic.
/// Format a Route into a URL string.
///
/// ## Example
///
/// ```gleam
/// format(Login)  // "/"
/// format(Config(Members, Some(5)))  // "/config/members?project=5"
/// format(AcceptInvite("abc123"))  // "/accept-invite?token=abc123"
/// Justification: nested case improves clarity for branching logic.
/// ```
pub fn format(route: Route) -> String {
  let #(path, query, fragment) = format_parts(route)
  let with_query = case query {
    None -> path
    Some(q) -> path <> "?" <> q
  }
  case fragment {
    None -> with_query
    Some(f) -> with_query <> "#" <> f
  }
}

fn format_parts(route: Route) -> #(String, Option(String), Option(String)) {
  case route {
    Login -> #("/", None, None)

    AcceptInvite(token) ->
      case token {
        "" -> #("/accept-invite", None, None)
        _ -> #("/accept-invite", Some("token=" <> token), None)
      }

    ResetPassword(token) ->
      case token {
        "" -> #("/reset-password", None, None)
        _ -> #("/reset-password", Some("token=" <> token), None)
      }

    // Story 4.5: New /config/* routes for project-scoped config
    Config(section, project_id) -> {
      let base = "/config/" <> config_section_slug(section)
      let state = state_with_project(project_id)
      let query =
        query_option(url_state.to_query_string_for(url_state.Config, state))
      #(base, query, None)
    }

    // Story 4.5: New /org/* routes for org-scoped admin
    Org(section) -> #("/org/" <> org_section_slug(section), None, None)

    Member(section, state) -> {
      let base = "/app/" <> member_section.to_slug(section)
      let query =
        query_option(url_state.to_query_string_for(url_state.Member, state))
      #(base, query, None)
    }
  }
}

fn state_with_project(project_id: Option(Int)) -> url_state.UrlState {
  case project_id {
    Some(id) -> url_state.with_project(url_state.empty(), id)
    None -> url_state.empty()
  }
}

fn query_option(query: String) -> Option(String) {
  case query {
    "" -> None
    q -> Some(q)
  }
}

// =============================================================================
// Assignments view helpers
// =============================================================================

pub fn format_assignments(
  view: Option(assignments_view_mode.AssignmentsViewMode),
) -> String {
  let base = "/org/assignments"
  let state = case view {
    Some(mode) -> url_state.with_assignments_view(url_state.empty(), mode)
    None -> url_state.empty()
  }
  let query =
    query_option(url_state.to_query_string_for(url_state.OrgAssignments, state))

  case query {
    None -> base
    Some(q) -> base <> "?" <> q
  }
}

pub fn replace_assignments_view(
  view: assignments_view_mode.AssignmentsViewMode,
) -> Effect(msg) {
  let state = url_state.with_assignments_view(url_state.empty(), view)
  let query =
    query_option(url_state.to_query_string_for(url_state.OrgAssignments, state))
  modem.replace("/org/assignments", query, None)
}

pub fn push_assignments_view(
  view: assignments_view_mode.AssignmentsViewMode,
) -> Effect(msg) {
  let state = url_state.with_assignments_view(url_state.empty(), view)
  let query =
    query_option(url_state.to_query_string_for(url_state.OrgAssignments, state))
  modem.push("/org/assignments", query, None)
}

fn search_to_query(search: String) -> String {
  case string.starts_with(search, "?") {
    True -> string.drop_start(search, 1)
    False -> search
  }
}

fn token_from_search(search: String) -> String {
  case query_param(search, "token") {
    Some(token) -> token
    None -> ""
  }
}

// Justification: nested case improves clarity for branching logic.
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

// =============================================================================
// Story 4.5: Config and Org Route Helpers
// =============================================================================

/// Parse slug into config section (project-scoped sections)
fn config_section_from_slug(slug: String) -> permissions.AdminSection {
  case slug {
    "members" -> permissions.Members
    "capabilities" -> permissions.Capabilities
    "task-types" -> permissions.TaskTypes
    "cards" -> permissions.Cards
    "workflows" -> permissions.Workflows
    "templates" -> permissions.TaskTemplates
    "rule-metrics" -> permissions.RuleMetrics
    _ -> permissions.Members
  }
}

/// Convert config section to URL slug
fn config_section_slug(section: permissions.AdminSection) -> String {
  case section {
    permissions.Members -> "members"
    permissions.Capabilities -> "capabilities"
    permissions.TaskTypes -> "task-types"
    permissions.Cards -> "cards"
    permissions.Workflows -> "workflows"
    permissions.TaskTemplates -> "templates"
    permissions.RuleMetrics -> "rule-metrics"
    // Org sections should not use this, but provide fallback
    _ -> "members"
  }
}

/// Parse slug into org section (org-scoped sections)
fn org_section_from_slug(slug: String) -> permissions.AdminSection {
  case slug {
    "invites" -> permissions.Invites
    "settings" -> permissions.OrgSettings
    "users" -> permissions.OrgSettings
    "projects" -> permissions.Projects
    "assignments" -> permissions.Assignments
    "metrics" -> permissions.Metrics
    "rule-metrics" -> permissions.RuleMetrics
    _ -> permissions.Invites
  }
}

/// Convert org section to URL slug
fn org_section_slug(section: permissions.AdminSection) -> String {
  case section {
    permissions.Invites -> "invites"
    permissions.OrgSettings -> "settings"
    permissions.Projects -> "projects"
    permissions.Assignments -> "assignments"
    permissions.Metrics -> "metrics"
    permissions.RuleMetrics -> "rule-metrics"
    // Config sections should not use this, but provide fallback
    _ -> "invites"
  }
}

/// Apply mobile-specific routing rules.
///
/// Story 4.4: With the new 3-panel layout, mobile uses drawers instead of
/// redirecting to different routes. Pool works on mobile (no drag-drop,
/// uses tap-to-claim instead). This function is kept for backwards
/// compatibility but now returns the input unchanged.
///
/// ## Example
///
/// ```gleam
/// let result = parse_uri(uri)
/// apply_mobile_rules(result, True)
/// // Parsed(Member(Pool, state)) - no longer redirects
/// ```
pub fn apply_mobile_rules(result: ParseResult, _is_mobile: Bool) -> ParseResult {
  // Story 4.4: Mobile no longer redirects Pool to MyBar
  // The 3-panel layout handles mobile with drawers
  result
}

// =============================================================================
// Navigation Effects
// =============================================================================

/// Push a new URL to browser history (adds back button entry).
///
/// ## Example
///
/// ```gleam
/// router.push(router.Config(permissions.Projects, Some(5)))
/// // Navigates to "/config/projects?project=5" with history entry
/// ```
pub fn push(route: Route) -> Effect(msg) {
  let #(path, query, fragment) = format_parts(route)
  modem.push(path, query, fragment)
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
  let #(path, query, fragment) = format_parts(route)
  modem.replace(path, query, fragment)
}

/// Update the browser document title based on the current route.
///
/// Sets the title in the format "Section - Scrumbringer" for authenticated
/// pages, or just "Scrumbringer" for login/public pages.
///
/// ## Example
///
/// ```gleam
/// router.update_page_title(router.Config(permissions.Projects, None), locale)
/// // Sets document title to "Projects - Scrumbringer"
/// ```
pub fn update_page_title(
  route: Route,
  locale: i18n_locale.Locale,
) -> Effect(msg) {
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

    // Story 4.5: Config/Org routes use admin section titles
    Config(section, _) -> Some(admin_section_title(section, locale))
    Org(section) -> Some(admin_section_title(section, locale))

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
    permissions.Assignments -> i18n_text.Assignments
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
