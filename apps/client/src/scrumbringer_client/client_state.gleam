//// Client state types for scrumbringer_client.
////
//// ## Mission
////
//// Defines the root state shell for the Scrumbringer client application.
//// Feature-specific state lives in `client_state/*` owner modules and is
//// composed here through the root model and message types.
////
//// ## Responsibilities
////
//// - Define the `Model` type containing all application state
//// - Define page variants (`Page`) for client-side routing
//// - Define all message variants (`Msg`) for the Lustre update cycle
//// - Expose root-level aliases required by the Lustre shell
//// - Define navigation mode (`NavMode`) for history management
//// - Provide `default_model` for state initialization
////
//// ## Non-responsibilities
////
//// - HTTP requests and API logic (see `api/` modules)
//// - Routing logic and URL parsing (see `router.gleam`)
//// - View rendering and HTML generation (see `scrumbringer_client.gleam`)
//// - Update logic and effect handling (see `scrumbringer_client.gleam`)
//// - Internationalization (see `i18n/` modules)
//// - Theme and styling (see `theme.gleam`, `styles.gleam`)
////
//// ## Design Decision: Model is NOT Opaque
////
//// `Model` is intentionally a public (non-opaque) type because:
//// 1. The Lustre update pattern requires `Model(..model, field: value)` syntax
//// 2. Making it opaque would require 70+ accessor/setter functions
//// 3. The trade-off favors ergonomics over strict encapsulation
////
//// Use `default_model()` for initialization to get sensible defaults.
////
//// ## Line Count Justification
////
//// This module contains the root `Model`, `Msg`, `CoreModel`, `Page` and
//// navigation types for the SPA. Slice-specific state, dialog modes and
//// interaction state live in their owner modules under `client_state/*`.
//// The root still stays public so update functions can use Gleam record
//// update syntax.
////
//// ## Relations
////
//// - **scrumbringer_client.gleam**: Main module that uses these types for
////   init, update, and view functions
//// - **api/***: Provides API types used in `Model` and `Msg`
//// - **router.gleam**: Provides `Route` type used in `NavigateTo` message
//// - **permissions.gleam**: Provides `AdminSection` type
//// - **i18n/locale.gleam**: Provides `Locale` type

import gleam/option.{type Option}
import gleam/uri.{type Uri}

import domain/user.{type User}

// API types from domain modules
import domain/api_error.{type ApiResult}
import domain/project.{type Project}
import domain/remote.{type Remote, Failed, Loaded, Loading, NotAsked}
import scrumbringer_client/client_state/admin as admin_state
import scrumbringer_client/client_state/auth as auth_state
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/types as state_types
import scrumbringer_client/client_state/ui as ui_state
import scrumbringer_client/domain/ids.{type ToastId}
import scrumbringer_client/features/admin/msg as admin_msg
import scrumbringer_client/features/auth/msg as auth_msg
import scrumbringer_client/features/i18n/msg as i18n_msg
import scrumbringer_client/features/layout/msg as layout_msg
import scrumbringer_client/features/pool/msg as pool_msg
import scrumbringer_client/hydration
import scrumbringer_client/permissions
import scrumbringer_client/router
import scrumbringer_client/ui/toast

// ----------------------------------------------------------------------------
// Remote data loading state
// ----------------------------------------------------------------------------

// Represents the state of data that must be fetched from the server.
//
// This type models the lifecycle of async data loading:
// - `NotAsked`: Initial state before any request is made
// - `Loading`: Request in progress
// - `Loaded(a)`: Request succeeded with data
// - `Failed(ApiError)`: Request failed with error details
//
// Note: remote type is imported from domain/remote.gleam to avoid duplication.
// ----------------------------------------------------------------------------
// Page navigation
// ----------------------------------------------------------------------------

/// Current page/view in the application.
///
/// Maps to URL routes and determines which view to render:
/// - `Login`: Authentication page at `/`
/// - `AcceptInvite`: Invite acceptance flow at `/accept-invite`
/// - `ResetPassword`: Password reset flow at `/reset-password`
/// - `Admin`: Admin panel pages at `/admin/*`
/// - `Member`: Member workspace pages at `/app/*`
pub type Page {
  Login
  AcceptInvite
  ResetPassword
  Admin
  Member
}

pub type OperationState =
  state_types.OperationState

pub type DialogState(form) =
  state_types.DialogState(form)

// ----------------------------------------------------------------------------
// Navigation mode
// ----------------------------------------------------------------------------

/// History API navigation mode.
///
/// Determines how URL changes are recorded:
/// - `Push`: Add new entry to history (back button will return)
/// - `Replace`: Replace current entry (no new history entry)
pub type NavMode {
  Push
  Replace
}

// ----------------------------------------------------------------------------
// Main application state
// ----------------------------------------------------------------------------

/// Main application state container.
///
/// This type holds all client-side state including:
/// - Authentication and user info
/// - Current page and navigation state
/// - Current admin section
/// - Root project cache
/// - Selected project
pub type CoreModel {
  CoreModel(
    page: Page,
    user: Option(User),
    auth_checked: Bool,
    active_section: permissions.AdminSection,
    projects: Remote(List(Project)),
    selected_project_id: Option(Int),
  )
}

/// Represents AuthModel.
pub type AuthModel =
  auth_state.AuthModel

/// Represents UiModel.
pub type UiModel =
  ui_state.UiModel

/// Represents MobileDrawerState.
pub type MobileDrawerState =
  ui_state.MobileDrawerState

/// Represents SidebarCollapse.
pub type SidebarCollapse =
  ui_state.SidebarCollapse

pub type AdminModel =
  admin_state.AdminModel

pub type MemberModel =
  member_state.MemberModel

/// Represents Model.
pub type Model {
  Model(
    core: CoreModel,
    auth: AuthModel,
    admin: AdminModel,
    member: MemberModel,
    ui: UiModel,
  )
}

// Messages
// ----------------------------------------------------------------------------

/// Represents AuthMsg.
pub type AuthMsg =
  auth_msg.Msg

/// Represents I18nMsg.
pub type I18nMsg =
  i18n_msg.Msg

/// Represents LayoutMsg.
pub type LayoutMsg =
  layout_msg.Msg

/// Represents AdminMsg.
pub type AdminMsg =
  admin_msg.Msg

/// Represents PoolMsg.
pub type PoolMsg =
  pool_msg.Msg

/// All messages that can be dispatched to the update function.
///
/// Messages are grouped by feature area:
/// - Navigation and routing
/// - Authentication and user management
/// - Admin configuration flows
/// - Member pool flows
pub type Msg {
  NoOp
  UrlChanged(Uri)
  NavigateTo(router.Route, NavMode)
  MeFetched(ApiResult(User))
  AuthMsg(AuthMsg)
  I18nMsg(I18nMsg)
  LayoutMsg(LayoutMsg)
  AdminMsg(AdminMsg)
  PoolMsg(PoolMsg)
  ToastShow(String, toast.ToastVariant)
  ToastShowWithAction(String, toast.ToastVariant, toast.ToastAction)
  ToastActionTriggered(toast.ToastActionKind)
  ToastDismiss(ToastId)
  ToastTick(Int)
  ThemeSelected(String)
  ProjectSelected(String)
}

/// Provides auth msg.
///
/// Example:
///   auth_msg(...)
pub fn auth_msg(msg: AuthMsg) -> Msg {
  AuthMsg(msg)
}

/// Provides i18n msg.
///
/// Example:
///   i18n_msg(...)
pub fn i18n_msg(msg: I18nMsg) -> Msg {
  I18nMsg(msg)
}

/// Provides layout msg.
///
/// Example:
///   layout_msg(...)
pub fn layout_msg(msg: LayoutMsg) -> Msg {
  LayoutMsg(msg)
}

/// Provides admin msg.
///
/// Example:
///   admin_msg(...)
pub fn admin_msg(msg: AdminMsg) -> Msg {
  AdminMsg(msg)
}

/// Provides pool msg.
///
/// Example:
///   pool_msg(...)
pub fn pool_msg(msg: PoolMsg) -> Msg {
  PoolMsg(msg)
}

/// Updates core.
///
/// Example:
///   update_core(...)
pub fn update_core(model: Model, f: fn(CoreModel) -> CoreModel) -> Model {
  Model(..model, core: f(model.core))
}

/// Updates auth.
///
/// Example:
///   update_auth(...)
pub fn update_auth(model: Model, f: fn(AuthModel) -> AuthModel) -> Model {
  Model(..model, auth: f(model.auth))
}

/// Updates admin.
///
/// Example:
///   update_admin(...)
pub fn update_admin(model: Model, f: fn(AdminModel) -> AdminModel) -> Model {
  Model(..model, admin: f(model.admin))
}

/// Updates member.
///
/// Example:
///   update_member(...)
pub fn update_member(model: Model, f: fn(MemberModel) -> MemberModel) -> Model {
  Model(..model, member: f(model.member))
}

/// Updates ui.
///
/// Example:
///   update_ui(...)
pub fn update_ui(model: Model, f: fn(UiModel) -> UiModel) -> Model {
  Model(..model, ui: f(model.ui))
}

// ----------------------------------------------------------------------------
// Helper functions
// ----------------------------------------------------------------------------

/// Converts Remote state to hydration ResourceState for plan computation.
///
/// ## Example
///
/// ```gleam
/// let state = remote_to_resource_state(model.projects)
/// // Returns hydration.Loaded if projects are loaded
/// ```
pub fn remote_to_resource_state(remote: Remote(a)) -> hydration.ResourceState {
  case remote {
    NotAsked -> hydration.NotAsked
    Loading -> hydration.Loading
    Loaded(_) -> hydration.Loaded
    Failed(_) -> hydration.Failed
  }
}

/// Creates a Model with sensible default values for all fields.
///
/// Use this as a starting point and override specific fields:
///
/// ## Example
///
/// ```gleam
/// let model = Model(
///   ..default_model(),
///   core: CoreModel(..default_model().core, page: Admin),
/// )
/// ```
///
/// ## Size Justification
///
/// Initializes the root shell and delegates feature-specific defaults to their
/// owner modules. The root model intentionally composes:
/// - Authentication and navigation state
/// - Admin feature state
/// - Member workspace state
/// - UI preferences and layout state
/// - Root project cache and selected project
///
/// A single root constructor call keeps application initialization explicit
/// while each slice remains responsible for its own defaults.
///
/// ## Defaults
///
/// - All `Remote` fields start as `NotAsked`
/// - All `Option` fields start as `None`
/// - All `Bool` flags start as `False`
/// - All `String` fields start as `""`
/// - All `Int` counters start as `0`
/// - All `Dict` fields start empty
/// - `page` defaults to `Login`
pub fn default_model() -> Model {
  Model(
    core: CoreModel(
      page: Login,
      user: option.None,
      auth_checked: False,
      active_section: permissions.Invites,
      projects: NotAsked,
      selected_project_id: option.None,
    ),
    auth: auth_state.default_model(),
    admin: admin_state.default_model(),
    member: member_state.default_model(),
    ui: ui_state.default_model(),
  )
}
