//// Main client module for Scrumbringer web application.
////
//// ## Mission
////
//// Entry point and orchestrator for the Lustre-based SPA client. Wires together
//// initialization, routing, state management, and view rendering.
////
//// ## Responsibilities
////
//// - Application bootstrap (`main`, `init`)
//// - Lustre wiring (connects init, update, view)
////
//// ## Non-responsibilities
////
//// - Type definitions (see `client_state.gleam`)
//// - Update logic (see `client_update.gleam`)
//// - View rendering (see `client_view.gleam`)
//// - API request/response handling (see `api.gleam`)
//// - JavaScript FFI (see `client_ffi.gleam`)
//// - Routing logic and URL parsing (see `router.gleam`)
////
//// ## Architecture
////
//// Follows the Lustre/Elm architecture pattern:
//// - **Model**: Application state (defined in `client_state.gleam`)
//// - **Msg**: Messages that trigger state changes (defined in `client_state.gleam`)
//// - **Update**: `client_update.update` handles state transitions
//// - **View**: `client_view.view` renders the UI
////
//// ## Flags Decision
////
//// The application uses typed `Flags` for Lustre initialization to keep
//// `init` deterministic and testable:
////
//// 1. **No base_url needed**: API uses relative URLs (`/api/...`), allowing
////    the client to work with any deployment origin without configuration.
////
//// 2. **No feature_flags needed**: Single deployment target with no runtime
////    feature toggling requirements at this stage.
////
//// 3. **Runtime config via host flags**: User preferences (theme, locale)
////    are passed into `init` as flags to avoid JS reads during init.
////
//// If future requirements need additional external configuration (e.g.,
//// multi-tenant base URLs, A/B testing flags), extend the `Flags` record.
////
//// ## Relations
////
//// - **client_state.gleam**: Provides Model, Msg, and state types
//// - **client_update.gleam**: Provides update function and effect helpers
//// - **client_view.gleam**: Provides view function and UI components
//// - **api.gleam**: Provides API effects for data fetching
//// - **client_ffi.gleam**: Provides browser FFI (history, DOM, timers)
//// - **router.gleam**: Provides URL parsing and route types

import gleam/option as opt
import gleam/string
import gleam/uri.{type Uri, Uri}

import lustre
import lustre/effect.{type Effect}

import domain/view_mode
import modem
import scrumbringer_client/accept_invite
import scrumbringer_client/api/auth as api_auth
import scrumbringer_client/client_ffi
import scrumbringer_client/member_section
import scrumbringer_client/permissions
import scrumbringer_client/pool_prefs
import scrumbringer_client/reset_password
import scrumbringer_client/router
import scrumbringer_client/storage
import scrumbringer_client/theme
import scrumbringer_client/ui/toast

import scrumbringer_client/app/effects as app_effects
import scrumbringer_client/i18n/locale as i18n_locale

import scrumbringer_client/client_state.{
  type Model, type Msg, AcceptInvite as AcceptInvitePage, Admin, AuthModel,
  CoreModel, Login, MeFetched, Member, MemberModel, Replace,
  ResetPassword as ResetPasswordPage, UiModel, update_auth, update_core,
  update_member, update_ui,
}

import scrumbringer_client/client_update
import scrumbringer_client/client_view
import scrumbringer_client/components/card_crud_dialog
import scrumbringer_client/components/card_detail_modal
import scrumbringer_client/components/rule_crud_dialog
import scrumbringer_client/components/task_template_crud_dialog
import scrumbringer_client/components/task_type_crud_dialog
import scrumbringer_client/components/workflow_crud_dialog

// =============================================================================
// Application Entry Point
// =============================================================================

/// Flags passed from the host to keep init deterministic.
pub type Flags {
  Flags(theme: theme.Theme, locale: i18n_locale.Locale)
}

/// Create the Lustre application with init, update, and view functions.
///
/// ## Example
///
/// ```gleam
/// let application = app()
/// lustre.start(application, "#app", Nil)
/// ```
pub fn app() -> lustre.App(Flags, Model, Msg) {
  lustre.application(init, client_update.update, client_view.view)
}

/// Application entry point - starts the Lustre SPA.
///
/// Mounts the application to the `#app` DOM element.
/// Also registers custom element components.
pub fn main() {
  // Register custom element components
  case card_detail_modal.register() {
    Ok(_) -> Nil
    Error(_) -> Nil
  }
  case card_crud_dialog.register() {
    Ok(_) -> Nil
    Error(_) -> Nil
  }
  case workflow_crud_dialog.register() {
    Ok(_) -> Nil
    Error(_) -> Nil
  }
  case task_template_crud_dialog.register() {
    Ok(_) -> Nil
    Error(_) -> Nil
  }
  case rule_crud_dialog.register() {
    Ok(_) -> Nil
    Error(_) -> Nil
  }
  case task_type_crud_dialog.register() {
    Ok(_) -> Nil
    Error(_) -> Nil
  }

  let flags = Flags(theme: storage.load_theme(), locale: storage.load_locale())

  // Start the main application
  case lustre.start(app(), "#app", flags) {
    Ok(_) -> Nil
    Error(_) -> Nil
  }
}

// =============================================================================
// Initialization
// =============================================================================

// Justification: large function kept intact to preserve cohesive UI logic.
/// Initialize the application state from browser context.
///
/// ## Size Justification (~200 lines)
///
/// Performs comprehensive application bootstrap:
/// 1. URL parsing and route extraction (pathname, search, hash)
/// 2. Mobile detection and responsive rules
/// 3. Route-specific token extraction (accept invite, reset password)
/// 4. Page and section derivation from route
/// 5. Sub-module initialization (accept_invite, reset_password)
/// 6. Theme and locale loading from localStorage
/// 7. Pool preferences restoration
/// 8. Full Model construction with 60+ fields
/// 9. Initial effect batching (popstate, keydown, redirect, auth check)
///
/// The init function is a Lustre contract requirement that must return
/// the complete initial state. The Model has 60+ fields initialized from
/// route context, localStorage, and sub-modules. Splitting would require
/// either partial Model construction (not type-safe) or complex builder
/// patterns that add indirection without clarity.
fn init(flags: Flags) -> #(Model, Effect(Msg)) {
  let is_mobile = client_ffi.is_mobile()

  let parsed =
    router.parse_uri(initial_uri())
    |> router.apply_mobile_rules(is_mobile)

  let route = case parsed {
    router.Parsed(route) -> route
    router.Redirect(route) -> route
  }

  let accept_token = case route {
    router.AcceptInvite(token) -> token
    _ -> ""
  }

  let reset_token = case route {
    router.ResetPassword(token) -> token
    _ -> ""
  }

  // Story 4.5: Config and Org routes use Admin page type
  let page = case route {
    router.Login -> Login
    router.AcceptInvite(_) -> AcceptInvitePage
    router.ResetPassword(_) -> ResetPasswordPage
    router.Config(_, _) | router.Org(_) -> Admin
    router.Member(_, _, _) -> Member
  }

  let active_section = case route {
    router.Config(section, _) | router.Org(section) -> section
    _ -> permissions.Invites
  }

  let member_section = case route {
    router.Member(section, _, _) -> section
    _ -> member_section.Pool
  }

  let selected_project_id = case route {
    router.Config(_, project_id) | router.Member(_, project_id, _) -> project_id
    router.Org(_) -> opt.None
    _ -> opt.None
  }

  // Extract view mode from URL (default to Pool if not specified)
  let initial_view_mode = case route {
    router.Member(_, _, opt.Some(vm)) -> vm
    _ -> view_mode.Pool
  }

  let #(accept_model, accept_action) = accept_invite.init(accept_token)
  let #(reset_model, reset_action) = reset_password.init(reset_token)

  let active_theme = flags.theme
  let active_locale = flags.locale

  let pool_filters_default_visible = theme.filters_default_visible(active_theme)

  let pool_filters_visible =
    storage.load_pool_filters_visibility(pool_filters_default_visible)
    |> pool_prefs.visibility_to_bool

  let pool_view_mode = storage.load_pool_view_mode()

  // Load sidebar collapse state from localStorage
  let sidebar_collapse = app_effects.load_sidebar_state()

  let model =
    client_state.default_model()
    |> update_core(fn(core) {
      CoreModel(
        ..core,
        page: page,
        active_section: active_section,
        selected_project_id: selected_project_id,
      )
    })
    |> update_auth(fn(auth) {
      AuthModel(
        ..auth,
        accept_invite: accept_model,
        reset_password: reset_model,
      )
    })
    |> update_member(fn(member) {
      MemberModel(
        ..member,
        member_section: member_section,
        view_mode: initial_view_mode,
        member_pool_filters_visible: pool_filters_visible,
        member_pool_view_mode: pool_view_mode,
      )
    })
    |> update_ui(fn(ui) {
      UiModel(
        ..ui,
        is_mobile: is_mobile,
        toast_state: toast.init(),
        theme: active_theme,
        locale: active_locale,
        sidebar_collapse: sidebar_collapse,
      )
    })

  let base_effect = case page {
    AcceptInvitePage -> client_update.accept_invite_effect(accept_action)
    ResetPasswordPage -> client_update.reset_password_effect(reset_action)
    _ -> api_auth.fetch_me(MeFetched)
  }

  let redirect_fx = case parsed {
    router.Redirect(_) -> client_update.write_url(Replace, route)
    router.Parsed(_) -> effect.none()
  }

  let title_fx = router.update_page_title(route, active_locale)

  #(
    model,
    effect.batch([
      modem.init(client_state.UrlChanged),
      client_update.register_keydown_effect(),
      redirect_fx,
      base_effect,
      title_fx,
    ]),
  )
}

fn initial_uri() -> Uri {
  case modem.initial_uri() {
    Ok(uri) -> uri
    Error(_) -> uri_from_location()
  }
}

fn uri_from_location() -> Uri {
  let pathname = client_ffi.location_pathname()
  let search = client_ffi.location_search()
  let hash = client_ffi.location_hash()
  let query = case search {
    "" -> opt.None
    _ -> opt.Some(string.drop_start(search, 1))
  }
  let fragment = case hash {
    "" -> opt.None
    _ -> opt.Some(string.drop_start(hash, 1))
  }
  Uri(
    scheme: opt.None,
    userinfo: opt.None,
    host: opt.None,
    port: opt.None,
    path: pathname,
    query: query,
    fragment: fragment,
  )
}
