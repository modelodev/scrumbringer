//// Client state types for scrumbringer_client.
////
//// ## Mission
////
//// Centralizes all state-related type definitions for the Scrumbringer client
//// application. This module serves as the single source of truth for the
//// application's state model, page navigation, remote data handling, and
//// message types.
////
//// ## Responsibilities
////
//// - Define the `Model` type containing all application state
//// - Define page variants (`Page`) for client-side routing
//// - Define remote data loading states (`Remote`) for async operations
//// - Define all message variants (`Msg`) for the Lustre update cycle
//// - Define UI state types (`IconPreview`, `DragState`, `Rect`)
//// - Define navigation mode (`NavMode`) for history management
//// - Provide smart constructors (`default_model`) for state initialization
//// - Provide geometry helpers tied to state types (e.g., `rect_contains_point`)
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
//// ~750 lines: Contains all Model, Msg, Page, Remote types for the SPA.
//// Splitting by feature would scatter related types and break the TEA
//// pattern's expectation of a unified Model definition. Gleam's exhaustive
//// pattern matching ensures type safety across this large variant set.
////
//// ## Relations
////
//// - **scrumbringer_client.gleam**: Main module that uses these types for
////   init, update, and view functions
//// - **api/***: Provides API types used in `Model` and `Msg`
//// - **router.gleam**: Provides `Route` type used in `NavigateTo` message
//// - **accept_invite.gleam**: Child component with its own `Model` and `Msg`
//// - **reset_password.gleam**: Child component with its own `Model` and `Msg`
//// - **permissions.gleam**: Provides `AdminSection` type
//// - **member_section.gleam**: Provides `MemberSection` type
//// - **pool_prefs.gleam**: Provides `ViewMode` and `KeyEvent` types
//// - **theme.gleam**: Provides `Theme` type
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

// ----------------------------------------------------------------------------
// UI state types
// ----------------------------------------------------------------------------

pub type IconPreview =
  state_types.IconPreview

pub type OperationState =
  state_types.OperationState

pub type DialogState(form) =
  state_types.DialogState(form)

pub type InviteLinkForm =
  state_types.InviteLinkForm

pub type DragState =
  state_types.DragState

pub type PoolDragState =
  state_types.PoolDragState

pub type Rect =
  state_types.Rect

pub type CardDialogMode =
  state_types.CardDialogMode

pub type WorkflowDialogMode =
  state_types.WorkflowDialogMode

pub type TaskTemplateDialogMode =
  state_types.TaskTemplateDialogMode

pub type RuleDialogMode =
  state_types.RuleDialogMode

pub type TaskTypeDialogMode =
  state_types.TaskTypeDialogMode

pub fn rect_contains_point(rect: Rect, x: Int, y: Int) -> Bool {
  state_types.rect_contains_point(rect, x, y)
}

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
/// - UI preferences (theme, locale, mobile detection)
/// - Form inputs and validation state
/// - Remote data caches and loading states
/// - Child component states (accept_invite, reset_password)
/// - Drag-and-drop state
/// - Filter and search state
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

pub type OrgUsersSearchState =
  state_types.OrgUsersSearchState

pub type ProjectDialogForm =
  state_types.ProjectDialogForm

pub type AssignmentsAddContext =
  state_types.AssignmentsAddContext

pub type ReleaseAllTarget =
  state_types.ReleaseAllTarget

pub type AssignmentsModel =
  state_types.AssignmentsModel

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

/// Provides sidebar collapse from bools.
///
/// Example:
///   sidebar_collapse_from_bools(...)
pub fn sidebar_collapse_from_bools(config: Bool, org: Bool) -> SidebarCollapse {
  case config, org {
    True, True -> ui_state.BothCollapsed
    True, False -> ui_state.ConfigCollapsed
    False, True -> ui_state.OrgCollapsed
    False, False -> ui_state.NoneCollapsed
  }
}

/// Provides sidebar collapse to bools.
///
/// Example:
///   sidebar_collapse_to_bools(...)
pub fn sidebar_collapse_to_bools(state: SidebarCollapse) -> #(Bool, Bool) {
  case state {
    ui_state.NoneCollapsed -> #(False, False)
    ui_state.ConfigCollapsed -> #(True, False)
    ui_state.OrgCollapsed -> #(False, True)
    ui_state.BothCollapsed -> #(True, True)
  }
}

/// Provides sidebar config collapsed.
///
/// Example:
///   sidebar_config_collapsed(...)
pub fn sidebar_config_collapsed(state: SidebarCollapse) -> Bool {
  let #(config, _org) = sidebar_collapse_to_bools(state)
  config
}

/// Provides sidebar org collapsed.
///
/// Example:
///   sidebar_org_collapsed(...)
pub fn sidebar_org_collapsed(state: SidebarCollapse) -> Bool {
  let #(_config, org) = sidebar_collapse_to_bools(state)
  org
}

/// Toggles sidebar config.
///
/// Example:
///   toggle_sidebar_config(...)
pub fn toggle_sidebar_config(state: SidebarCollapse) -> SidebarCollapse {
  let #(config, org) = sidebar_collapse_to_bools(state)
  sidebar_collapse_from_bools(!config, org)
}

/// Toggles sidebar org.
///
/// Example:
///   toggle_sidebar_org(...)
pub fn toggle_sidebar_org(state: SidebarCollapse) -> SidebarCollapse {
  let #(config, org) = sidebar_collapse_to_bools(state)
  sidebar_collapse_from_bools(config, !org)
}

/// Provides mobile drawer left open.
///
/// Example:
///   mobile_drawer_left_open(...)
pub fn mobile_drawer_left_open(state: MobileDrawerState) -> Bool {
  case state {
    ui_state.DrawerLeftOpen -> True
    _ -> False
  }
}

/// Provides mobile drawer right open.
///
/// Example:
///   mobile_drawer_right_open(...)
pub fn mobile_drawer_right_open(state: MobileDrawerState) -> Bool {
  case state {
    ui_state.DrawerRightOpen -> True
    _ -> False
  }
}

/// Toggles left drawer.
///
/// Example:
///   toggle_left_drawer(...)
pub fn toggle_left_drawer(state: MobileDrawerState) -> MobileDrawerState {
  case state {
    ui_state.DrawerLeftOpen -> ui_state.DrawerClosed
    _ -> ui_state.DrawerLeftOpen
  }
}

/// Toggles right drawer.
///
/// Example:
///   toggle_right_drawer(...)
pub fn toggle_right_drawer(state: MobileDrawerState) -> MobileDrawerState {
  case state {
    ui_state.DrawerRightOpen -> ui_state.DrawerClosed
    _ -> ui_state.DrawerRightOpen
  }
}

/// Closes drawers.
///
/// Example:
///   close_drawers(...)
pub fn close_drawers(_state: MobileDrawerState) -> MobileDrawerState {
  ui_state.DrawerClosed
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
///   page: Admin,
///   user: option.Some(current_user),
///   theme: loaded_theme,
/// )
/// ```
///
/// ## Size Justification (~155 lines)
///
/// Initializes all 100+ Model fields with sensible defaults. The Model type
/// has grown to encompass the entire SPA state including:
/// - Authentication and navigation state
/// - Form fields for all dialogs (login, forgot password, create task, etc.)
/// - Remote data caches for all API resources
/// - Drag-and-drop and canvas positioning state
/// - Filter and preference states
///
/// A single constructor call is clearer than spreading initialization across
/// multiple functions. The function is pure, has no branching, and serves as
/// the single source of truth for initial state.
///
/// ## Defaults
///
/// - All `Remote` fields start as `NotAsked`
/// - All `Option` fields start as `None`
/// - All `Bool` flags start as `False` (except `member_quick_my_caps`)
/// - All `String` fields start as `""`
/// - All `Int` counters start as `0`
/// - All `Dict` fields start empty
/// - `page` defaults to `Login`
/// - `member_create_priority` defaults to `"3"` (medium)
/// - `members_add_role` defaults to `Member`
/// Justification: large function kept intact to preserve cohesive UI logic.
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
