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
//// The application uses `Nil` for Lustre flags rather than a typed `Flags`
//// record. This is intentional:
////
//// 1. **No base_url needed**: API uses relative URLs (`/api/...`), allowing
////    the client to work with any deployment origin without configuration.
////
//// 2. **No feature_flags needed**: Single deployment target with no runtime
////    feature toggling requirements at this stage.
////
//// 3. **Runtime config via localStorage**: User preferences (theme, locale,
////    pool view mode) are loaded from localStorage in `init`, not passed as
////    flags from the host page.
////
//// If future requirements need external configuration (e.g., multi-tenant
//// base URLs, A/B testing flags), add a `type Flags` record and update
//// `lustre.application(init, ...)` to `lustre.application(init_with_flags, ...)`.
////
//// ## Relations
////
//// - **client_state.gleam**: Provides Model, Msg, and state types
//// - **client_update.gleam**: Provides update function and effect helpers
//// - **client_view.gleam**: Provides view function and UI components
//// - **api.gleam**: Provides API effects for data fetching
//// - **client_ffi.gleam**: Provides browser FFI (history, DOM, timers)
//// - **router.gleam**: Provides URL parsing and route types

import gleam/dict
import gleam/option as opt

import lustre
import lustre/effect.{type Effect}

import scrumbringer_client/accept_invite
import scrumbringer_client/api/auth as api_auth
import scrumbringer_client/client_ffi
import scrumbringer_client/member_section
import scrumbringer_client/permissions
import scrumbringer_client/pool_prefs
import scrumbringer_client/reset_password
import scrumbringer_client/router
import scrumbringer_client/theme

import scrumbringer_client/i18n/locale as i18n_locale

import scrumbringer_client/client_state.{
  type Model, type Msg, AcceptInvite as AcceptInvitePage, Admin, IconIdle, Login,
  MeFetched, Member, Model, NotAsked, Replace,
  ResetPassword as ResetPasswordPage,
}

import scrumbringer_client/client_update
import scrumbringer_client/client_view
import scrumbringer_client/components/card_crud_dialog
import scrumbringer_client/components/card_detail_modal
import scrumbringer_client/components/rule_crud_dialog
import scrumbringer_client/components/task_template_crud_dialog
import scrumbringer_client/components/workflow_crud_dialog

// =============================================================================
// Application Entry Point
// =============================================================================

/// Create the Lustre application with init, update, and view functions.
///
/// ## Example
///
/// ```gleam
/// let application = app()
/// lustre.start(application, "#app", Nil)
/// ```
pub fn app() -> lustre.App(Nil, Model, Msg) {
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

  // Start the main application
  case lustre.start(app(), "#app", Nil) {
    Ok(_) -> Nil
    Error(_) -> Nil
  }
}

// =============================================================================
// Initialization
// =============================================================================

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
fn init(_flags: Nil) -> #(Model, Effect(Msg)) {
  let pathname = client_ffi.location_pathname()
  let search = client_ffi.location_search()
  let hash = client_ffi.location_hash()
  let is_mobile = client_ffi.is_mobile()

  let parsed =
    router.parse(pathname, search, hash)
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

  let page = case route {
    router.Login -> Login
    router.AcceptInvite(_) -> AcceptInvitePage
    router.ResetPassword(_) -> ResetPasswordPage
    router.Admin(_, _) -> Admin
    router.Member(_, _) -> Member
  }

  let active_section = case route {
    router.Admin(section, _) -> section
    _ -> permissions.Invites
  }

  let member_section = case route {
    router.Member(section, _) -> section
    _ -> member_section.Pool
  }

  let selected_project_id = case route {
    router.Admin(_, project_id) | router.Member(_, project_id) -> project_id
    _ -> opt.None
  }

  let #(accept_model, accept_action) = accept_invite.init(accept_token)
  let #(reset_model, reset_action) = reset_password.init(reset_token)

  let active_theme = theme.load_from_storage()
  let active_locale = i18n_locale.load()

  let pool_filters_default_visible = theme.filters_default_visible(active_theme)

  let pool_filters_visible =
    theme.local_storage_get(pool_prefs.filters_visible_storage_key)
    |> pool_prefs.deserialize_bool(pool_filters_default_visible)

  let pool_view_mode =
    theme.local_storage_get(pool_prefs.view_mode_storage_key)
    |> pool_prefs.deserialize_view_mode

  let model =
    Model(
      page: page,
      user: opt.None,
      auth_checked: False,
      is_mobile: is_mobile,
      active_section: active_section,
      toast: opt.None,
      theme: active_theme,
      locale: active_locale,
      login_email: "",
      login_password: "",
      login_error: opt.None,
      login_in_flight: False,
      forgot_password_open: False,
      forgot_password_email: "",
      forgot_password_in_flight: False,
      forgot_password_result: opt.None,
      forgot_password_error: opt.None,
      forgot_password_copy_status: opt.None,
      accept_invite: accept_model,
      reset_password: reset_model,
      projects: NotAsked,
      selected_project_id: selected_project_id,
      invite_links: NotAsked,
      invite_link_email: "",
      invite_link_in_flight: False,
      invite_link_error: opt.None,
      invite_link_last: opt.None,
      invite_link_copy_status: opt.None,
      projects_create_dialog_open: False,
      projects_create_name: "",
      projects_create_in_flight: False,
      projects_create_error: opt.None,
      capabilities: NotAsked,
      capabilities_create_dialog_open: False,
      capabilities_create_name: "",
      capabilities_create_in_flight: False,
      capabilities_create_error: opt.None,
      members: NotAsked,
      members_project_id: opt.None,
      org_users_cache: NotAsked,
      org_settings_users: NotAsked,
      admin_metrics_overview: NotAsked,
      admin_metrics_project_tasks: NotAsked,
      admin_metrics_project_id: opt.None,
      // Rule metrics tab
      admin_rule_metrics: NotAsked,
      admin_rule_metrics_from: "",
      admin_rule_metrics_to: "",
      // Rule metrics drill-down
      admin_rule_metrics_expanded_workflow: opt.None,
      admin_rule_metrics_workflow_details: NotAsked,
      admin_rule_metrics_drilldown_rule_id: opt.None,
      admin_rule_metrics_rule_details: NotAsked,
      admin_rule_metrics_executions: NotAsked,
      admin_rule_metrics_exec_offset: 0,
      org_settings_role_drafts: dict.new(),
      org_settings_save_in_flight: False,
      org_settings_error: opt.None,
      org_settings_error_user_id: opt.None,
      user_projects_dialog_open: False,
      user_projects_dialog_user: opt.None,
      user_projects_list: NotAsked,
      user_projects_add_project_id: opt.None,
      user_projects_in_flight: False,
      user_projects_error: opt.None,
      members_add_dialog_open: False,
      members_add_selected_user: opt.None,
      members_add_role: "member",
      members_add_in_flight: False,
      members_add_error: opt.None,
      members_remove_confirm: opt.None,
      members_remove_in_flight: False,
      members_remove_error: opt.None,
      org_users_search_query: "",
      org_users_search_token: 0,
      org_users_search_results: NotAsked,
      task_types: NotAsked,
      task_types_project_id: opt.None,
      task_types_create_dialog_open: False,
      task_types_create_name: "",
      task_types_create_icon: "",
      task_types_create_icon_search: "",
      task_types_create_icon_category: "all",
      task_types_create_capability_id: opt.None,
      task_types_create_in_flight: False,
      task_types_create_error: opt.None,
      task_types_icon_preview: IconIdle,
      member_section: member_section,
      member_active_task: NotAsked,
      member_work_sessions: NotAsked,
      member_metrics: NotAsked,
      member_now_working_in_flight: False,
      member_now_working_error: opt.None,
      now_working_tick: 0,
      now_working_tick_running: False,
      now_working_server_offset_ms: 0,
      member_tasks: NotAsked,
      member_tasks_pending: 0,
      member_tasks_by_project: dict.new(),
      member_task_types: NotAsked,
      member_task_types_pending: 0,
      member_task_types_by_project: dict.new(),
      member_task_mutation_in_flight: False,
      member_task_mutation_task_id: opt.None,
      member_tasks_snapshot: opt.None,
      member_filters_status: "",
      member_filters_type_id: "",
      member_filters_capability_id: "",
      member_filters_q: "",
      member_quick_my_caps: True,
      member_pool_filters_visible: pool_filters_visible,
      member_pool_view_mode: pool_view_mode,
      member_panel_expanded: False,
      member_create_dialog_open: False,
      member_create_title: "",
      member_create_description: "",
      member_create_priority: "3",
      member_create_type_id: "",
      member_create_in_flight: False,
      member_create_error: opt.None,
      member_my_capability_ids: NotAsked,
      member_my_capability_ids_edit: dict.new(),
      member_my_capabilities_in_flight: False,
      member_my_capabilities_error: opt.None,
      member_positions_by_task: dict.new(),
      member_drag: opt.None,
      member_canvas_left: 0,
      member_canvas_top: 0,
      member_pool_my_tasks_rect: opt.None,
      member_pool_drag_to_claim_armed: False,
      member_pool_drag_over_my_tasks: False,
      member_position_edit_task: opt.None,
      member_position_edit_x: "",
      member_position_edit_y: "",
      member_position_edit_in_flight: False,
      member_position_edit_error: opt.None,
      member_notes_task_id: opt.None,
      member_notes: NotAsked,
      member_note_content: "",
      member_note_in_flight: False,
      member_note_error: opt.None,
      // Cards (Fichas) - list and dialog mode (component handles CRUD state internally)
      cards: NotAsked,
      cards_project_id: opt.None,
      cards_dialog_mode: opt.None,
      // Card detail (member view) - only open state, component manages internal state
      card_detail_open: opt.None,
      // Workflows - list and dialog mode (component handles CRUD state internally)
      workflows_org: NotAsked,
      workflows_project: NotAsked,
      workflows_dialog_mode: opt.None,
      // Rules (list and dialog mode - component handles CRUD state internally)
      rules_workflow_id: opt.None,
      rules: NotAsked,
      rules_dialog_mode: opt.None,
      // Rule templates
      rules_templates: NotAsked,
      rules_attach_template_id: opt.None,
      rules_attach_in_flight: False,
      rules_attach_error: opt.None,
      // Rule metrics (inline display)
      rules_metrics: NotAsked,
      // Task templates (org/project lists, dialog mode managed by component)
      task_templates_org: NotAsked,
      task_templates_project: NotAsked,
      task_templates_dialog_mode: opt.None,
    )

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
      client_update.register_popstate_effect(),
      client_update.register_keydown_effect(),
      redirect_fx,
      base_effect,
      title_fx,
    ]),
  )
}
