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
//// - Define UI state types (`IconPreview`, `MemberDrag`, `Rect`)
//// - Define navigation mode (`NavMode`) for history management
//// - Provide smart constructors (`default_model`) for state initialization
//// - Provide geometry helpers tied to state types (e.g., `rect_contains_point`)
////
//// ## Non-responsibilities
////
//// - HTTP requests and API logic (see `api.gleam`)
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
//// ## Relations
////
//// - **scrumbringer_client.gleam**: Main module that uses these types for
////   init, update, and view functions
//// - **api.gleam**: Provides API types used in `Model` and `Msg`
//// - **router.gleam**: Provides `Route` type used in `NavigateTo` message
//// - **accept_invite.gleam**: Child component with its own `Model` and `Msg`
//// - **reset_password.gleam**: Child component with its own `Model` and `Msg`
//// - **permissions.gleam**: Provides `AdminSection` type
//// - **member_section.gleam**: Provides `MemberSection` type
//// - **pool_prefs.gleam**: Provides `ViewMode` and `KeyEvent` types
//// - **theme.gleam**: Provides `Theme` type
//// - **i18n/locale.gleam**: Provides `Locale` type

import gleam/dict.{type Dict}
import gleam/option.{type Option}

import scrumbringer_domain/user.{type User}

import scrumbringer_client/accept_invite
import scrumbringer_client/api
import scrumbringer_client/hydration
import scrumbringer_client/i18n/locale as i18n_locale
import scrumbringer_client/member_section
import scrumbringer_client/permissions
import scrumbringer_client/pool_prefs
import scrumbringer_client/reset_password
import scrumbringer_client/router
import scrumbringer_client/theme

// ----------------------------------------------------------------------------
// Remote data loading state
// ----------------------------------------------------------------------------

/// Represents the state of data that must be fetched from the server.
///
/// This type models the lifecycle of async data loading:
/// - `NotAsked`: Initial state before any request is made
/// - `Loading`: Request in progress
/// - `Loaded(a)`: Request succeeded with data
/// - `Failed(ApiError)`: Request failed with error details
pub type Remote(a) {
  NotAsked
  Loading
  Loaded(a)
  Failed(api.ApiError)
}

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

/// State of icon URL preview in task type creation.
///
/// Tracks the loading state when validating an icon URL:
/// - `IconIdle`: No preview attempted yet
/// - `IconLoading`: Image loading in progress
/// - `IconOk`: Image loaded successfully
/// - `IconError`: Image failed to load
pub type IconPreview {
  IconIdle
  IconLoading
  IconOk
  IconError
}

/// State during drag-and-drop of a task card.
///
/// Captures the task being dragged and the offset from the cursor
/// to the card's origin, enabling smooth visual feedback.
pub type MemberDrag {
  MemberDrag(task_id: Int, offset_x: Int, offset_y: Int)
}

/// Rectangle geometry for hit testing.
///
/// Used for detecting when a dragged card is over a drop target
/// like the "My Tasks" zone.
pub type Rect {
  Rect(left: Int, top: Int, width: Int, height: Int)
}

/// Tests if a point (x, y) is inside the rectangle (inclusive bounds).
pub fn rect_contains_point(rect: Rect, x: Int, y: Int) -> Bool {
  let Rect(left: left, top: top, width: width, height: height) = rect
  x >= left && x <= left + width && y >= top && y <= top + height
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
pub type Model {
  Model(
    // Core navigation and auth
    page: Page,
    user: Option(User),
    auth_checked: Bool,
    is_mobile: Bool,
    active_section: permissions.AdminSection,
    toast: Option(String),
    theme: theme.Theme,
    locale: i18n_locale.Locale,
    // Login form
    login_email: String,
    login_password: String,
    login_error: Option(String),
    login_in_flight: Bool,
    // Forgot password dialog
    forgot_password_open: Bool,
    forgot_password_email: String,
    forgot_password_in_flight: Bool,
    forgot_password_result: Option(api.PasswordReset),
    forgot_password_error: Option(String),
    forgot_password_copy_status: Option(String),
    // Child components
    accept_invite: accept_invite.Model,
    reset_password: reset_password.Model,
    // Projects
    projects: Remote(List(api.Project)),
    selected_project_id: Option(Int),
    // Invite links
    invite_links: Remote(List(api.InviteLink)),
    invite_link_email: String,
    invite_link_in_flight: Bool,
    invite_link_error: Option(String),
    invite_link_last: Option(api.InviteLink),
    invite_link_copy_status: Option(String),
    // Project creation
    projects_create_name: String,
    projects_create_in_flight: Bool,
    projects_create_error: Option(String),
    // Capabilities
    capabilities: Remote(List(api.Capability)),
    capabilities_create_name: String,
    capabilities_create_in_flight: Bool,
    capabilities_create_error: Option(String),
    // Members
    members: Remote(List(api.ProjectMember)),
    members_project_id: Option(Int),
    // Org users
    org_users_cache: Remote(List(api.OrgUser)),
    org_settings_users: Remote(List(api.OrgUser)),
    // Admin metrics
    admin_metrics_overview: Remote(api.OrgMetricsOverview),
    admin_metrics_project_tasks: Remote(api.OrgMetricsProjectTasksPayload),
    admin_metrics_project_id: Option(Int),
    // Org settings
    org_settings_role_drafts: Dict(Int, String),
    org_settings_save_in_flight: Bool,
    org_settings_error: Option(String),
    org_settings_error_user_id: Option(Int),
    // Member add dialog
    members_add_dialog_open: Bool,
    members_add_selected_user: Option(api.OrgUser),
    members_add_role: String,
    members_add_in_flight: Bool,
    members_add_error: Option(String),
    // Member remove dialog
    members_remove_confirm: Option(api.OrgUser),
    members_remove_in_flight: Bool,
    members_remove_error: Option(String),
    // Org user search
    org_users_search_query: String,
    org_users_search_results: Remote(List(api.OrgUser)),
    // Task types
    task_types: Remote(List(api.TaskType)),
    task_types_project_id: Option(Int),
    task_types_create_name: String,
    task_types_create_icon: String,
    task_types_create_capability_id: Option(String),
    task_types_create_in_flight: Bool,
    task_types_create_error: Option(String),
    task_types_icon_preview: IconPreview,
    // Member section
    member_section: member_section.MemberSection,
    member_active_task: Remote(api.ActiveTaskPayload),
    member_metrics: Remote(api.MyMetrics),
    member_now_working_in_flight: Bool,
    member_now_working_error: Option(String),
    // Now working timer
    now_working_tick: Int,
    now_working_tick_running: Bool,
    now_working_server_offset_ms: Int,
    // Member tasks
    member_tasks: Remote(List(api.Task)),
    member_tasks_pending: Int,
    member_tasks_by_project: Dict(Int, List(api.Task)),
    member_task_types: Remote(List(api.TaskType)),
    member_task_types_pending: Int,
    member_task_types_by_project: Dict(Int, List(api.TaskType)),
    member_task_mutation_in_flight: Bool,
    // Member filters
    member_filters_status: String,
    member_filters_type_id: String,
    member_filters_capability_id: String,
    member_filters_q: String,
    member_quick_my_caps: Bool,
    member_pool_filters_visible: Bool,
    member_pool_view_mode: pool_prefs.ViewMode,
    // Member task creation
    member_create_dialog_open: Bool,
    member_create_title: String,
    member_create_description: String,
    member_create_priority: String,
    member_create_type_id: String,
    member_create_in_flight: Bool,
    member_create_error: Option(String),
    // Member capabilities
    member_my_capability_ids: Remote(List(Int)),
    member_my_capability_ids_edit: Dict(Int, Bool),
    member_my_capabilities_in_flight: Bool,
    member_my_capabilities_error: Option(String),
    // Member drag-and-drop
    member_positions_by_task: Dict(Int, #(Int, Int)),
    member_drag: Option(MemberDrag),
    member_canvas_left: Int,
    member_canvas_top: Int,
    member_pool_my_tasks_rect: Option(Rect),
    member_pool_drag_to_claim_armed: Bool,
    member_pool_drag_over_my_tasks: Bool,
    // Member position editing
    member_position_edit_task: Option(Int),
    member_position_edit_x: String,
    member_position_edit_y: String,
    member_position_edit_in_flight: Bool,
    member_position_edit_error: Option(String),
    // Member notes
    member_notes_task_id: Option(Int),
    member_notes: Remote(List(api.TaskNote)),
    member_note_content: String,
    member_note_in_flight: Bool,
    member_note_error: Option(String),
  )
}

// ----------------------------------------------------------------------------
// Messages
// ----------------------------------------------------------------------------

/// All messages that can be dispatched to the update function.
///
/// Messages are grouped by feature area:
/// - Navigation and routing
/// - Authentication and user management
/// - Login and forgot password flows
/// - Project and capability management
/// - Member and invite management
/// - Task pool and filtering
/// - Drag-and-drop interactions
/// - Timer and metrics
pub type Msg {
  // Pool drag-to-claim
  MemberPoolMyTasksRectFetched(Int, Int, Int, Int)
  MemberPoolDragToClaimArmed(Bool)

  // Navigation
  UrlChanged
  NavigateTo(router.Route, NavMode)

  // Auth
  MeFetched(api.ApiResult(User))
  AcceptInviteMsg(accept_invite.Msg)
  ResetPasswordMsg(reset_password.Msg)

  // Login form
  LoginEmailChanged(String)
  LoginPasswordChanged(String)
  LoginSubmitted
  LoginDomValuesRead(String, String)
  LoginFinished(api.ApiResult(User))

  // Forgot password
  ForgotPasswordClicked
  ForgotPasswordEmailChanged(String)
  ForgotPasswordSubmitted
  ForgotPasswordFinished(api.ApiResult(api.PasswordReset))
  ForgotPasswordCopyClicked
  ForgotPasswordCopyFinished(Bool)
  ForgotPasswordDismissed

  // Logout
  LogoutClicked
  LogoutFinished(api.ApiResult(Nil))

  // Toast
  ToastDismissed

  // Preferences
  ThemeSelected(String)
  LocaleSelected(String)

  // Project selection
  ProjectSelected(String)

  // Projects CRUD
  ProjectsFetched(api.ApiResult(List(api.Project)))
  ProjectCreateNameChanged(String)
  ProjectCreateSubmitted
  ProjectCreated(api.ApiResult(api.Project))

  // Invite links
  InviteLinkEmailChanged(String)
  InviteLinkCreateSubmitted
  InviteLinkCreated(api.ApiResult(api.InviteLink))
  InviteLinksFetched(api.ApiResult(List(api.InviteLink)))
  InviteLinkRegenerateClicked(String)
  InviteLinkRegenerated(api.ApiResult(api.InviteLink))
  InviteLinkCopyClicked(String)
  InviteLinkCopyFinished(Bool)

  // Capabilities
  CapabilitiesFetched(api.ApiResult(List(api.Capability)))
  CapabilityCreateNameChanged(String)
  CapabilityCreateSubmitted
  CapabilityCreated(api.ApiResult(api.Capability))

  // Members
  MembersFetched(api.ApiResult(List(api.ProjectMember)))
  OrgUsersCacheFetched(api.ApiResult(List(api.OrgUser)))
  OrgSettingsUsersFetched(api.ApiResult(List(api.OrgUser)))
  OrgSettingsRoleChanged(Int, String)
  OrgSettingsSaveClicked(Int)
  OrgSettingsSaved(Int, api.ApiResult(api.OrgUser))

  // Member add dialog
  MemberAddDialogOpened
  MemberAddDialogClosed
  MemberAddRoleChanged(String)
  MemberAddUserSelected(Int)
  MemberAddSubmitted
  MemberAdded(api.ApiResult(api.ProjectMember))

  // Member remove
  MemberRemoveClicked(Int)
  MemberRemoveCancelled
  MemberRemoveConfirmed
  MemberRemoved(api.ApiResult(Nil))

  // Org user search
  OrgUsersSearchChanged(String)
  OrgUsersSearchDebounced(String)
  OrgUsersSearchResults(api.ApiResult(List(api.OrgUser)))

  // Task types
  TaskTypesFetched(api.ApiResult(List(api.TaskType)))
  TaskTypeCreateNameChanged(String)
  TaskTypeCreateIconChanged(String)
  TaskTypeIconLoaded
  TaskTypeIconErrored
  TaskTypeCreateCapabilityChanged(String)
  TaskTypeCreateSubmitted
  TaskTypeCreated(api.ApiResult(api.TaskType))

  // Pool filters
  MemberPoolStatusChanged(String)
  MemberPoolTypeChanged(String)
  MemberPoolCapabilityChanged(String)
  MemberPoolSearchChanged(String)
  MemberPoolSearchDebounced(String)
  MemberToggleMyCapabilitiesQuick
  MemberPoolFiltersToggled
  MemberPoolViewModeSet(pool_prefs.ViewMode)

  // Keyboard
  GlobalKeyDown(pool_prefs.KeyEvent)

  // Member tasks
  MemberProjectTasksFetched(Int, api.ApiResult(List(api.Task)))
  MemberTaskTypesFetched(Int, api.ApiResult(List(api.TaskType)))

  // Drag-and-drop
  MemberCanvasRectFetched(Int, Int)
  MemberDragStarted(Int, Int, Int)
  MemberDragMoved(Int, Int)
  MemberDragEnded

  // Task creation
  MemberCreateDialogOpened
  MemberCreateDialogClosed
  MemberCreateTitleChanged(String)
  MemberCreateDescriptionChanged(String)
  MemberCreatePriorityChanged(String)
  MemberCreateTypeIdChanged(String)
  MemberCreateSubmitted
  MemberTaskCreated(api.ApiResult(api.Task))

  // Task actions
  MemberClaimClicked(Int, Int)
  MemberReleaseClicked(Int, Int)
  MemberCompleteClicked(Int, Int)
  MemberTaskClaimed(api.ApiResult(api.Task))
  MemberTaskReleased(api.ApiResult(api.Task))
  MemberTaskCompleted(api.ApiResult(api.Task))

  // Now working
  MemberNowWorkingStartClicked(Int)
  MemberNowWorkingPauseClicked
  MemberActiveTaskFetched(api.ApiResult(api.ActiveTaskPayload))
  MemberActiveTaskStarted(api.ApiResult(api.ActiveTaskPayload))
  MemberActiveTaskPaused(api.ApiResult(api.ActiveTaskPayload))
  MemberActiveTaskHeartbeated(api.ApiResult(api.ActiveTaskPayload))
  MemberMetricsFetched(api.ApiResult(api.MyMetrics))
  AdminMetricsOverviewFetched(api.ApiResult(api.OrgMetricsOverview))
  AdminMetricsProjectTasksFetched(
    api.ApiResult(api.OrgMetricsProjectTasksPayload),
  )
  NowWorkingTicked

  // Member capabilities
  MemberMyCapabilityIdsFetched(api.ApiResult(List(Int)))
  MemberToggleCapability(Int)
  MemberSaveCapabilitiesClicked
  MemberMyCapabilityIdsSaved(api.ApiResult(List(Int)))

  // Position editing
  MemberPositionsFetched(api.ApiResult(List(api.TaskPosition)))
  MemberPositionEditOpened(Int)
  MemberPositionEditClosed
  MemberPositionEditXChanged(String)
  MemberPositionEditYChanged(String)
  MemberPositionEditSubmitted
  MemberPositionSaved(api.ApiResult(api.TaskPosition))

  // Task details and notes
  MemberTaskDetailsOpened(Int)
  MemberTaskDetailsClosed
  MemberNotesFetched(api.ApiResult(List(api.TaskNote)))
  MemberNoteContentChanged(String)
  MemberNoteSubmitted
  MemberNoteAdded(api.ApiResult(api.TaskNote))
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
/// - `members_add_role` defaults to `"member"`
pub fn default_model() -> Model {
  Model(
    // Core navigation and auth
    page: Login,
    user: option.None,
    auth_checked: False,
    is_mobile: False,
    active_section: permissions.Invites,
    toast: option.None,
    theme: theme.Default,
    locale: i18n_locale.En,
    // Login form
    login_email: "",
    login_password: "",
    login_error: option.None,
    login_in_flight: False,
    // Forgot password dialog
    forgot_password_open: False,
    forgot_password_email: "",
    forgot_password_in_flight: False,
    forgot_password_result: option.None,
    forgot_password_error: option.None,
    forgot_password_copy_status: option.None,
    // Child components (initialized with empty token state)
    accept_invite: accept_invite.Model(
      token: "",
      state: accept_invite.NoToken,
      password: "",
      password_error: option.None,
      submit_error: option.None,
    ),
    reset_password: reset_password.Model(
      token: "",
      state: reset_password.NoToken,
      password: "",
      password_error: option.None,
      submit_error: option.None,
    ),
    // Projects
    projects: NotAsked,
    selected_project_id: option.None,
    // Invite links
    invite_links: NotAsked,
    invite_link_email: "",
    invite_link_in_flight: False,
    invite_link_error: option.None,
    invite_link_last: option.None,
    invite_link_copy_status: option.None,
    // Project creation
    projects_create_name: "",
    projects_create_in_flight: False,
    projects_create_error: option.None,
    // Capabilities
    capabilities: NotAsked,
    capabilities_create_name: "",
    capabilities_create_in_flight: False,
    capabilities_create_error: option.None,
    // Members
    members: NotAsked,
    members_project_id: option.None,
    // Org users
    org_users_cache: NotAsked,
    org_settings_users: NotAsked,
    // Admin metrics
    admin_metrics_overview: NotAsked,
    admin_metrics_project_tasks: NotAsked,
    admin_metrics_project_id: option.None,
    // Org settings
    org_settings_role_drafts: dict.new(),
    org_settings_save_in_flight: False,
    org_settings_error: option.None,
    org_settings_error_user_id: option.None,
    // Member add dialog
    members_add_dialog_open: False,
    members_add_selected_user: option.None,
    members_add_role: "member",
    members_add_in_flight: False,
    members_add_error: option.None,
    // Member remove dialog
    members_remove_confirm: option.None,
    members_remove_in_flight: False,
    members_remove_error: option.None,
    // Org user search
    org_users_search_query: "",
    org_users_search_results: NotAsked,
    // Task types
    task_types: NotAsked,
    task_types_project_id: option.None,
    task_types_create_name: "",
    task_types_create_icon: "",
    task_types_create_capability_id: option.None,
    task_types_create_in_flight: False,
    task_types_create_error: option.None,
    task_types_icon_preview: IconIdle,
    // Member section
    member_section: member_section.Pool,
    member_active_task: NotAsked,
    member_metrics: NotAsked,
    member_now_working_in_flight: False,
    member_now_working_error: option.None,
    // Now working timer
    now_working_tick: 0,
    now_working_tick_running: False,
    now_working_server_offset_ms: 0,
    // Member tasks
    member_tasks: NotAsked,
    member_tasks_pending: 0,
    member_tasks_by_project: dict.new(),
    member_task_types: NotAsked,
    member_task_types_pending: 0,
    member_task_types_by_project: dict.new(),
    member_task_mutation_in_flight: False,
    // Member filters
    member_filters_status: "",
    member_filters_type_id: "",
    member_filters_capability_id: "",
    member_filters_q: "",
    // UX: default to My Capabilities enabled
    member_quick_my_caps: True,
    member_pool_filters_visible: False,
    member_pool_view_mode: pool_prefs.Canvas,
    // Member task creation
    member_create_dialog_open: False,
    member_create_title: "",
    member_create_description: "",
    member_create_priority: "3",
    member_create_type_id: "",
    member_create_in_flight: False,
    member_create_error: option.None,
    // Member capabilities
    member_my_capability_ids: NotAsked,
    member_my_capability_ids_edit: dict.new(),
    member_my_capabilities_in_flight: False,
    member_my_capabilities_error: option.None,
    // Member drag-and-drop
    member_positions_by_task: dict.new(),
    member_drag: option.None,
    member_canvas_left: 0,
    member_canvas_top: 0,
    member_pool_my_tasks_rect: option.None,
    member_pool_drag_to_claim_armed: False,
    member_pool_drag_over_my_tasks: False,
    // Member position editing
    member_position_edit_task: option.None,
    member_position_edit_x: "",
    member_position_edit_y: "",
    member_position_edit_in_flight: False,
    member_position_edit_error: option.None,
    // Member notes
    member_notes_task_id: option.None,
    member_notes: NotAsked,
    member_note_content: "",
    member_note_in_flight: False,
    member_note_error: option.None,
  )
}
