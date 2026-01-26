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

import domain/view_mode.{type ViewMode}
import scrumbringer_client/client_ffi
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale as i18n_locale
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/member_section.{type MemberSection}
import scrumbringer_client/permissions

/// Client route representing the current page and state.
///
/// Story 4.5: Routes now use /config/* and /org/* instead of /admin/*.
/// /admin/* routes are redirected to their new equivalents.
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
  Member(
    section: MemberSection,
    project_id: Option(Int),
    view_mode: Option(ViewMode),
  )
  // Legacy route - kept for redirect handling
  Admin(section: permissions.AdminSection, project_id: Option(Int))
}

/// Result of parsing a URL, indicating whether it was parsed directly
/// or needs a redirect (for legacy URLs or invalid query params).
pub type ParseResult {
  Parsed(Route)
  Redirect(Route)
}

/// Parsed query parameters used by routes.
pub type QueryParams {
  QueryParams(project_id: Option(Int), view_mode: Option(ViewMode))
}

type QueryError {
  InvalidProject(String)
  InvalidView(String)
}

type QueryParseError {
  InvalidQuery(params: QueryParams, errors: List(QueryError))
}

/// Parse URL components into a Route.
///
/// Handles both modern path-based URLs and legacy hash-based URLs.
/// Returns Redirect if the URL uses legacy format or has invalid query params.
///
/// Story 4.5: /admin/* routes are redirected to /config/* or /org/*
///
/// ## Example
///
/// ```gleam
/// parse("/config/members", "?project=5", "")
/// // Parsed(Config(Members, Some(5)))
///
/// parse("/admin/members", "?project=5", "")
/// // Redirect(Config(Members, Some(5))) -- admin redirects to config
///
/// parse("/admin/invites", "", "")
/// // Redirect(Org(Invites)) -- org sections redirect to /org
/// ```
pub fn parse(pathname: String, search: String, hash: String) -> ParseResult {
  let query_result = parse_query_params(search)
  let #(query_params, query_invalid) = case query_result {
    Ok(params) -> #(params, False)
    Error(InvalidQuery(params, _)) -> #(params, True)
  }

  // Legacy support: old hash routing `/?project=2#/admin/members`.
  let legacy = case pathname == "/" {
    True -> parse_legacy_hash(hash, query_params)
    False -> None
  }

  let route = case legacy {
    Some(route) -> route
    None -> parse_pathname(pathname, search, query_params)
  }

  // Story 4.5: Convert Admin routes to Config/Org routes
  let #(route, admin_redirect) = convert_admin_route(route)

  // Normalize invalid `project=` query values by removing them (replaceState).
  // Also redirect deprecated member section slugs (Story 4.4)
  // Story 4.5: Redirect /admin/* to new routes
  let needs_redirect =
    legacy != None
    || query_invalid
    || has_deprecated_member_slug(pathname)
    || admin_redirect

  case needs_redirect {
    True -> Redirect(route)
    False -> Parsed(route)
  }
}

/// Story 4.4: Check if pathname contains a deprecated member section slug
fn has_deprecated_member_slug(pathname: String) -> Bool {
  case string.starts_with(pathname, "/app/") {
    True -> {
      let slug = path_segment(pathname, "/app")
      member_section.is_deprecated_slug(slug)
    }
    False -> False
  }
}

fn parse_query_params(search: String) -> Result(QueryParams, QueryParseError) {
  let #(project_id, project_error) = parse_optional_int_param(search, "project")
  let #(view_mode, view_error) = parse_optional_view_param(search, "view")
  let params = QueryParams(project_id: project_id, view_mode: view_mode)

  let errors =
    [project_error, view_error]
    |> list.filter_map(fn(err) { option.to_result(err, Nil) })

  case errors {
    [] -> Ok(params)
    _ -> Error(InvalidQuery(params, errors))
  }
}

fn parse_optional_int_param(
  search: String,
  key: String,
) -> #(Option(Int), Option(QueryError)) {
  case query_param(search, key) {
    None -> #(None, None)

    Some(raw) ->
      case int.parse(raw) {
        Ok(id) -> #(Some(id), None)
        Error(_) -> #(None, Some(InvalidProject(raw)))
      }
  }
}

fn parse_optional_view_param(
  search: String,
  key: String,
) -> #(Option(ViewMode), Option(QueryError)) {
  case query_param(search, key) {
    None -> #(None, None)

    Some(raw) ->
      case view_mode_from_param(raw) {
        Some(mode) -> #(Some(mode), None)
        None -> #(None, Some(InvalidView(raw)))
      }
  }
}

fn view_mode_from_param(raw: String) -> Option(ViewMode) {
  case raw {
    "pool" -> Some(view_mode.Pool)
    "list" -> Some(view_mode.List)
    "cards" -> Some(view_mode.Cards)
    _ -> None
  }
}

fn parse_legacy_hash(hash: String, query: QueryParams) -> Option(Route) {
  let QueryParams(project_id: project_id, view_mode: view_mode) = query
  case string.starts_with(hash, "#/admin/") {
    True -> {
      let slug = drop_prefix(hash, "#/admin/")
      let section = admin_section_from_slug(slug)
      Some(Admin(section, project_id))
    }

    False ->
      case string.starts_with(hash, "#/app/") {
        True -> {
          let slug = drop_prefix(hash, "#/app/")
          let section = member_section.from_slug(slug)
          Some(Member(section, project_id, view_mode))
        }

        False -> None
      }
  }
}

fn parse_pathname(pathname: String, search: String, query: QueryParams) -> Route {
  let QueryParams(project_id: project_id, view_mode: view_mode) = query
  case pathname {
    "/" -> Login

    "/accept-invite" -> AcceptInvite(token_from_search(search))

    "/reset-password" -> ResetPassword(token_from_search(search))

    _ -> {
      // Story 4.5: New /config/* routes (project-scoped)
      case string.starts_with(pathname, "/config") {
        True -> {
          let slug = path_segment(pathname, "/config")
          Config(config_section_from_slug(slug), project_id)
        }

        False ->
          // Story 4.5: New /org/* routes (org-scoped)
          case string.starts_with(pathname, "/org") {
            True -> {
              let slug = path_segment(pathname, "/org")
              Org(org_section_from_slug(slug))
            }

            False ->
              // Legacy /admin/* routes - redirect to new routes
              case string.starts_with(pathname, "/admin") {
                True -> {
                  let slug = path_segment(pathname, "/admin")
                  Admin(admin_section_from_slug(slug), project_id)
                }

                False ->
                  case string.starts_with(pathname, "/app") {
                    True -> {
                      let slug = path_segment(pathname, "/app")
                      Member(
                        member_section.from_slug(slug),
                        project_id,
                        view_mode,
                      )
                    }

                    False -> Login
                  }
              }
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

    // Story 4.5: New /config/* routes for project-scoped config
    Config(section, project_id) -> {
      let base = "/config/" <> config_section_slug(section)
      with_project(base, project_id)
    }

    // Story 4.5: New /org/* routes for org-scoped admin
    Org(section) -> {
      "/org/" <> org_section_slug(section)
    }

    // Legacy /admin/* routes - kept for backwards compat
    Admin(section, project_id) -> {
      let base = "/admin/" <> admin_section_slug(section)
      with_project(base, project_id)
    }

    Member(section, project_id, view) -> {
      let base = "/app/" <> member_section.to_slug(section)
      with_query_params(base, project_id, view)
    }
  }
}

fn with_project(base: String, project_id: Option(Int)) -> String {
  case project_id {
    None -> base
    Some(id) -> base <> "?project=" <> int.to_string(id)
  }
}

fn with_query_params(
  base: String,
  project_id: Option(Int),
  view: Option(ViewMode),
) -> String {
  let params = [
    project_id |> option.map(fn(id) { "project=" <> int.to_string(id) }),
    view |> option.map(fn(v) { "view=" <> view_mode.to_string(v) }),
  ]
  let query =
    params
    |> list.filter_map(fn(p) { option.to_result(p, Nil) })
    |> string.join("&")
  case query {
    "" -> base
    q -> base <> "?" <> q
  }
}

fn token_from_search(search: String) -> String {
  case query_param(search, "token") {
    Some(token) -> token
    None -> ""
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
    permissions.Metrics -> "metrics"
    permissions.RuleMetrics -> "rule-metrics"
    // Config sections should not use this, but provide fallback
    _ -> "invites"
  }
}

/// Check if a section is org-scoped (vs project-scoped)
fn is_org_section(section: permissions.AdminSection) -> Bool {
  case section {
    permissions.Invites
    | permissions.OrgSettings
    | permissions.Projects
    | permissions.Metrics -> True
    _ -> False
  }
}

/// Convert legacy Admin route to Config or Org route
fn convert_admin_route(route: Route) -> #(Route, Bool) {
  case route {
    Admin(section, project_id) ->
      case is_org_section(section) {
        True -> #(Org(section), True)
        False -> #(Config(section, project_id), True)
      }
    _ -> #(route, False)
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
/// let result = parse("/app/pool", "", "")
/// apply_mobile_rules(result, True)
/// // Parsed(Member(Pool, None)) - no longer redirects
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

    // Story 4.5: New routes use same title logic as Admin
    Config(section, _) -> Some(admin_section_title(section, locale))
    Org(section) -> Some(admin_section_title(section, locale))
    Admin(section, _) -> Some(admin_section_title(section, locale))

    Member(section, _, _) -> Some(member_section_title(section, locale))
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
