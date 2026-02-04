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

import gleam/dict
import gleam/option.{type Option}
import gleam/set
import gleam/uri.{type Uri}

import domain/user.{type User}

import scrumbringer_client/accept_invite
import scrumbringer_client/assignments_view_mode

// API types from domain modules
import domain/api_error.{type ApiError, type ApiResult}
import domain/capability.{type Capability}
import domain/card.{type Card}
import domain/metrics.{
  type MyMetrics, type OrgMetricsOverview, type OrgMetricsProjectTasksPayload,
  type OrgMetricsUserOverview,
}
import domain/org.{type InviteLink, type OrgUser}
import domain/org_role
import domain/project.{type Project, type ProjectMember}
import domain/project_role.{type ProjectRole, Member as MemberRole}
import domain/remote.{type Remote, Failed, Loaded, Loading, NotAsked}
import domain/task.{
  type Task, type TaskDependency, type TaskNote, type TaskPosition,
  type WorkSessionsPayload,
}
import domain/task_type.{type TaskType}
import domain/view_mode
import domain/workflow.{
  type Rule, type RuleTemplate, type TaskTemplate, type Workflow,
}
import scrumbringer_client/api/auth.{type PasswordReset}
import scrumbringer_client/api/projects as api_projects
import scrumbringer_client/api/workflows as api_workflows
import scrumbringer_client/client_state/admin as admin_state
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/types as state_types
import scrumbringer_client/domain/ids.{type ToastId}
import scrumbringer_client/hydration
import scrumbringer_client/i18n/locale as i18n_locale
import scrumbringer_client/member_section
import scrumbringer_client/permissions
import scrumbringer_client/pool_prefs
import scrumbringer_client/reset_password
import scrumbringer_client/router
import scrumbringer_client/state/normalized_store
import scrumbringer_client/theme
import scrumbringer_client/ui/task_tabs
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
pub type AuthModel {
  AuthModel(
    login_email: String,
    login_password: String,
    login_error: Option(String),
    login_in_flight: Bool,
    forgot_password_open: Bool,
    forgot_password_email: String,
    forgot_password_in_flight: Bool,
    forgot_password_result: Option(PasswordReset),
    forgot_password_error: Option(String),
    forgot_password_copy_status: Option(String),
    accept_invite: accept_invite.Model,
    reset_password: reset_password.Model,
  )
}

/// Represents UiModel.
pub type UiModel {
  UiModel(
    is_mobile: Bool,
    toast_state: toast.ToastState,
    theme: theme.Theme,
    locale: i18n_locale.Locale,
    mobile_drawer: MobileDrawerState,
    sidebar_collapse: SidebarCollapse,
    preferences_popup_open: Bool,
  )
}

/// Represents MobileDrawerState.
pub type MobileDrawerState {
  DrawerClosed
  DrawerLeftOpen
  DrawerRightOpen
}

/// Represents SidebarCollapse.
pub type SidebarCollapse {
  NoneCollapsed
  ConfigCollapsed
  OrgCollapsed
  BothCollapsed
}

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
pub type AuthMsg {
  LoginEmailChanged(String)
  LoginPasswordChanged(String)
  LoginSubmitted
  LoginDomValuesRead(String, String)
  LoginFinished(ApiResult(User))
  ForgotPasswordClicked
  ForgotPasswordEmailChanged(String)
  ForgotPasswordSubmitted
  ForgotPasswordFinished(ApiResult(PasswordReset))
  ForgotPasswordCopyClicked
  ForgotPasswordCopyFinished(Bool)
  ForgotPasswordDismissed
  LogoutClicked
  LogoutFinished(ApiResult(Nil))
}

/// Represents AdminMsg.
pub type AdminMsg {
  ProjectsFetched(ApiResult(List(Project)))
  ProjectCreateDialogOpened
  ProjectCreateDialogClosed
  ProjectCreateNameChanged(String)
  ProjectCreateSubmitted
  ProjectCreated(ApiResult(Project))
  ProjectEditDialogOpened(Int, String)
  ProjectEditDialogClosed
  ProjectEditNameChanged(String)
  ProjectEditSubmitted
  ProjectUpdated(ApiResult(Project))
  ProjectDeleteConfirmOpened(Int, String)
  ProjectDeleteConfirmClosed
  ProjectDeleteSubmitted
  ProjectDeleted(ApiResult(Nil))
  InviteCreateDialogOpened
  InviteCreateDialogClosed
  InviteLinkEmailChanged(String)
  InviteLinkCreateSubmitted
  InviteLinkCreated(ApiResult(InviteLink))
  InviteLinksFetched(ApiResult(List(InviteLink)))
  InviteLinkRegenerateClicked(String)
  InviteLinkRegenerated(ApiResult(InviteLink))
  InviteLinkCopyClicked(String)
  InviteLinkCopyFinished(Bool)
  CapabilitiesFetched(ApiResult(List(Capability)))
  CapabilityCreateDialogOpened
  CapabilityCreateDialogClosed
  CapabilityCreateNameChanged(String)
  CapabilityCreateSubmitted
  CapabilityCreated(ApiResult(Capability))
  CapabilityDeleteDialogOpened(Int)
  CapabilityDeleteDialogClosed
  CapabilityDeleteSubmitted
  CapabilityDeleted(ApiResult(Int))
  MembersFetched(ApiResult(List(ProjectMember)))
  OrgUsersCacheFetched(ApiResult(List(OrgUser)))
  OrgSettingsUsersFetched(ApiResult(List(OrgUser)))
  OrgSettingsRoleChanged(Int, org_role.OrgRole)
  OrgSettingsSaved(Int, ApiResult(OrgUser))
  OrgSettingsDeleteClicked(Int)
  OrgSettingsDeleteCancelled
  OrgSettingsDeleteConfirmed
  OrgSettingsDeleted(ApiResult(Nil))
  MemberAddDialogOpened
  MemberAddDialogClosed
  MemberAddRoleChanged(String)
  MemberAddUserSelected(Int)
  MemberAddSubmitted
  MemberAdded(ApiResult(ProjectMember))
  MemberRemoveClicked(Int)
  MemberRemoveCancelled
  MemberRemoveConfirmed
  MemberRemoved(ApiResult(Nil))
  MemberReleaseAllClicked(Int, Int)
  MemberReleaseAllCancelled
  MemberReleaseAllConfirmed
  MemberReleaseAllResult(ApiResult(api_projects.ReleaseAllResult))
  MemberRoleChangeRequested(Int, ProjectRole)
  MemberRoleChanged(ApiResult(api_projects.RoleChangeResult))
  MemberCapabilitiesDialogOpened(Int)
  MemberCapabilitiesDialogClosed
  MemberCapabilitiesToggled(Int)
  MemberCapabilitiesSaveClicked
  MemberCapabilitiesFetched(ApiResult(api_projects.MemberCapabilities))
  MemberCapabilitiesSaved(ApiResult(api_projects.MemberCapabilities))
  CapabilityMembersDialogOpened(Int)
  CapabilityMembersDialogClosed
  CapabilityMembersToggled(Int)
  CapabilityMembersSaveClicked
  CapabilityMembersFetched(ApiResult(api_projects.CapabilityMembers))
  CapabilityMembersSaved(ApiResult(api_projects.CapabilityMembers))
  OrgUsersSearchChanged(String)
  OrgUsersSearchDebounced(String)
  OrgUsersSearchResults(Int, ApiResult(List(OrgUser)))
  AssignmentsViewModeChanged(assignments_view_mode.AssignmentsViewMode)
  AssignmentsSearchChanged(String)
  AssignmentsSearchDebounced(String)
  AssignmentsProjectMembersFetched(Int, ApiResult(List(ProjectMember)))
  AssignmentsUserProjectsFetched(Int, ApiResult(List(Project)))
  AssignmentsInlineAddStarted(AssignmentsAddContext)
  AssignmentsInlineAddSearchChanged(String)
  AssignmentsInlineAddSelectionChanged(String)
  AssignmentsInlineAddRoleChanged(String)
  AssignmentsInlineAddSubmitted
  AssignmentsInlineAddCancelled
  AssignmentsProjectMemberAdded(Int, ApiResult(ProjectMember))
  AssignmentsUserProjectAdded(Int, ApiResult(Project))
  AssignmentsRemoveClicked(Int, Int)
  AssignmentsRemoveCancelled
  AssignmentsRemoveConfirmed
  AssignmentsRemoveCompleted(Int, Int, ApiResult(Nil))
  AssignmentsRoleChanged(Int, Int, ProjectRole)
  AssignmentsRoleChangeCompleted(
    Int,
    Int,
    ApiResult(api_projects.RoleChangeResult),
  )
  AssignmentsProjectToggled(Int)
  AssignmentsUserToggled(Int)
  TaskTypesFetched(ApiResult(List(TaskType)))
  TaskTypeCreateDialogOpened
  TaskTypeCreateDialogClosed
  TaskTypeCreateNameChanged(String)
  TaskTypeCreateIconChanged(String)
  TaskTypeCreateIconSearchChanged(String)
  TaskTypeCreateIconCategoryChanged(String)
  TaskTypeIconLoaded
  TaskTypeIconErrored
  TaskTypeCreateCapabilityChanged(String)
  TaskTypeCreateSubmitted
  TaskTypeCreated(ApiResult(TaskType))
  OpenTaskTypeDialog(TaskTypeDialogMode)
  CloseTaskTypeDialog
  TaskTypeCrudCreated(TaskType)
  TaskTypeCrudUpdated(TaskType)
  TaskTypeCrudDeleted(Int)
}

/// Represents PoolMsg.
pub type PoolMsg {
  MemberPoolMyTasksRectFetched(Int, Int, Int, Int)
  MemberPoolDragToClaimArmed(Bool)
  MemberPoolStatusChanged(String)
  MemberPoolTypeChanged(String)
  MemberPoolCapabilityChanged(String)
  MemberPoolSearchChanged(String)
  MemberPoolSearchDebounced(String)
  MemberToggleMyCapabilitiesQuick
  MemberPoolFiltersToggled
  MemberClearFilters
  MemberPoolViewModeSet(pool_prefs.ViewMode)
  MemberPoolTouchStarted(Int, Int, Int)
  MemberPoolTouchEnded(Int)
  MemberPoolLongPressCheck(Int)
  MemberTaskHoverOpened(Int)
  MemberTaskHoverNotesFetched(Int, ApiResult(List(TaskNote)))
  MemberListHideCompletedToggled
  MemberListCardToggled(Int)
  ViewModeChanged(view_mode.ViewMode)
  MemberPanelToggled
  MobileLeftDrawerToggled
  MobileRightDrawerToggled
  MobileDrawersClosed
  SidebarConfigToggled
  SidebarOrgToggled
  PreferencesPopupToggled
  GlobalKeyDown(pool_prefs.KeyEvent)
  MemberProjectTasksFetched(Int, ApiResult(List(Task)))
  MemberTaskTypesFetched(Int, ApiResult(List(TaskType)))
  MemberCanvasRectFetched(Int, Int)
  MemberDragStarted(Int, Int, Int)
  MemberDragOffsetResolved(Int, Int, Int)
  MemberDragMoved(Int, Int)
  MemberDragEnded
  MemberCreateDialogOpened
  MemberCreateDialogOpenedWithCard(Int)
  MemberCreateDialogClosed
  MemberCreateTitleChanged(String)
  MemberCreateDescriptionChanged(String)
  MemberCreatePriorityChanged(String)
  MemberCreateTypeIdChanged(String)
  MemberCreateCardIdChanged(String)
  MemberCreateSubmitted
  MemberTaskCreated(ApiResult(Task))
  MemberClaimClicked(Int, Int)
  MemberReleaseClicked(Int, Int)
  MemberCompleteClicked(Int, Int)
  MemberTaskClaimed(ApiResult(Task))
  MemberTaskReleased(ApiResult(Task))
  MemberTaskCompleted(ApiResult(Task))
  MemberNowWorkingStartClicked(Int)
  MemberNowWorkingPauseClicked
  MemberWorkSessionsFetched(ApiResult(WorkSessionsPayload))
  MemberWorkSessionStarted(ApiResult(WorkSessionsPayload))
  MemberWorkSessionPaused(ApiResult(WorkSessionsPayload))
  MemberWorkSessionHeartbeated(ApiResult(WorkSessionsPayload))
  MemberMetricsFetched(ApiResult(MyMetrics))
  NowWorkingTicked
  MemberMyCapabilityIdsFetched(ApiResult(List(Int)))
  MemberProjectCapabilitiesFetched(ApiResult(List(Capability)))
  MemberToggleCapability(Int)
  MemberSaveCapabilitiesClicked
  MemberMyCapabilityIdsSaved(ApiResult(List(Int)))
  MemberProjectCardsFetched(Int, ApiResult(List(Card)))
  MemberPositionsFetched(ApiResult(List(TaskPosition)))

  MemberPositionEditOpened(Int)
  MemberPositionEditClosed
  MemberPositionEditXChanged(String)
  MemberPositionEditYChanged(String)
  MemberPositionEditSubmitted
  MemberPositionSaved(ApiResult(TaskPosition))
  MemberTaskDetailsOpened(Int)
  MemberTaskDetailsClosed
  MemberTaskDetailTabClicked(task_tabs.Tab)
  MemberDependenciesFetched(ApiResult(List(TaskDependency)))
  MemberDependencyDialogOpened
  MemberDependencyDialogClosed
  MemberDependencySearchChanged(String)
  MemberDependencyCandidatesFetched(ApiResult(List(Task)))
  MemberDependencySelected(Int)
  MemberDependencyAddSubmitted
  MemberDependencyAdded(ApiResult(TaskDependency))
  MemberDependencyRemoveClicked(Int)
  MemberDependencyRemoved(Int, ApiResult(Nil))
  MemberBlockedClaimCancelled
  MemberBlockedClaimConfirmed
  MemberNotesFetched(ApiResult(List(TaskNote)))
  MemberNoteContentChanged(String)
  MemberNoteDialogOpened
  MemberNoteDialogClosed
  MemberNoteSubmitted
  MemberNoteAdded(ApiResult(TaskNote))
  AdminMetricsOverviewFetched(ApiResult(OrgMetricsOverview))
  AdminMetricsProjectTasksFetched(ApiResult(OrgMetricsProjectTasksPayload))
  AdminMetricsUsersFetched(ApiResult(List(OrgMetricsUserOverview)))
  AdminRuleMetricsFetched(
    ApiResult(List(api_workflows.OrgWorkflowMetricsSummary)),
  )
  AdminRuleMetricsFromChanged(String)
  AdminRuleMetricsToChanged(String)
  AdminRuleMetricsFromChangedAndRefresh(String)
  AdminRuleMetricsToChangedAndRefresh(String)
  AdminRuleMetricsRefreshClicked
  AdminRuleMetricsQuickRangeClicked(String, String)
  AdminRuleMetricsWorkflowExpanded(Int)
  AdminRuleMetricsWorkflowDetailsFetched(
    ApiResult(api_workflows.WorkflowMetrics),
  )
  AdminRuleMetricsDrilldownClicked(Int)
  AdminRuleMetricsDrilldownClosed
  AdminRuleMetricsRuleDetailsFetched(
    ApiResult(api_workflows.RuleMetricsDetailed),
  )
  AdminRuleMetricsExecutionsFetched(
    ApiResult(api_workflows.RuleExecutionsResponse),
  )
  AdminRuleMetricsExecPageChanged(Int)
  CardsFetched(ApiResult(List(Card)))
  OpenCardDialog(CardDialogMode)
  CloseCardDialog
  CardCrudCreated(Card)
  CardCrudUpdated(Card)
  CardCrudDeleted(Int)
  CardsShowEmptyToggled
  CardsShowCompletedToggled
  CardsStateFilterChanged(String)
  CardsSearchChanged(String)
  OpenCardDetail(Int)
  CloseCardDetail
  WorkflowsProjectFetched(ApiResult(List(Workflow)))
  OpenWorkflowDialog(WorkflowDialogMode)
  CloseWorkflowDialog
  WorkflowCrudCreated(Workflow)
  WorkflowCrudUpdated(Workflow)
  WorkflowCrudDeleted(Int)
  WorkflowRulesClicked(Int)
  RulesFetched(ApiResult(List(Rule)))
  RulesBackClicked
  OpenRuleDialog(RuleDialogMode)
  CloseRuleDialog
  RuleCrudCreated(Rule)
  RuleCrudUpdated(Rule)
  RuleCrudDeleted(Int)
  RuleTemplatesClicked(Int)
  RuleTemplatesFetched(ApiResult(List(RuleTemplate)))
  RuleAttachTemplateSelected(String)
  RuleAttachTemplateSubmitted
  RuleTemplateAttached(ApiResult(List(RuleTemplate)))
  RuleTemplateDetachClicked(Int)
  RuleTemplateDetached(ApiResult(Nil))
  RuleExpandToggled(Int)
  AttachTemplateModalOpened(Int)
  AttachTemplateModalClosed
  AttachTemplateSelected(Int)
  AttachTemplateSubmitted
  AttachTemplateSucceeded(Int, List(RuleTemplate))
  AttachTemplateFailed(ApiError)
  TemplateDetachClicked(Int, Int)
  TemplateDetachSucceeded(Int, Int)
  TemplateDetachFailed(Int, Int, ApiError)
  RuleMetricsFetched(ApiResult(api_workflows.WorkflowMetrics))
  TaskTemplatesProjectFetched(ApiResult(List(TaskTemplate)))
  OpenTaskTemplateDialog(TaskTemplateDialogMode)
  CloseTaskTemplateDialog
  TaskTemplateCrudCreated(TaskTemplate)
  TaskTemplateCrudUpdated(TaskTemplate)
  TaskTemplateCrudDeleted(Int)
}

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
  AcceptInviteMsg(accept_invite.Msg)
  ResetPasswordMsg(reset_password.Msg)
  AuthMsg(AuthMsg)
  AdminMsg(AdminMsg)
  PoolMsg(PoolMsg)
  ToastShow(String, toast.ToastVariant)
  ToastDismiss(ToastId)
  ToastTick(Int)
  ThemeSelected(String)
  LocaleSelected(String)
  ProjectSelected(String)
}

/// Provides auth msg.
///
/// Example:
///   auth_msg(...)
pub fn auth_msg(msg: AuthMsg) -> Msg {
  AuthMsg(msg)
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
    True, True -> BothCollapsed
    True, False -> ConfigCollapsed
    False, True -> OrgCollapsed
    False, False -> NoneCollapsed
  }
}

/// Provides sidebar collapse to bools.
///
/// Example:
///   sidebar_collapse_to_bools(...)
pub fn sidebar_collapse_to_bools(state: SidebarCollapse) -> #(Bool, Bool) {
  case state {
    NoneCollapsed -> #(False, False)
    ConfigCollapsed -> #(True, False)
    OrgCollapsed -> #(False, True)
    BothCollapsed -> #(True, True)
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
    DrawerLeftOpen -> True
    _ -> False
  }
}

/// Provides mobile drawer right open.
///
/// Example:
///   mobile_drawer_right_open(...)
pub fn mobile_drawer_right_open(state: MobileDrawerState) -> Bool {
  case state {
    DrawerRightOpen -> True
    _ -> False
  }
}

/// Toggles left drawer.
///
/// Example:
///   toggle_left_drawer(...)
pub fn toggle_left_drawer(state: MobileDrawerState) -> MobileDrawerState {
  case state {
    DrawerLeftOpen -> DrawerClosed
    _ -> DrawerLeftOpen
  }
}

/// Toggles right drawer.
///
/// Example:
///   toggle_right_drawer(...)
pub fn toggle_right_drawer(state: MobileDrawerState) -> MobileDrawerState {
  case state {
    DrawerRightOpen -> DrawerClosed
    _ -> DrawerRightOpen
  }
}

/// Closes drawers.
///
/// Example:
///   close_drawers(...)
pub fn close_drawers(_state: MobileDrawerState) -> MobileDrawerState {
  DrawerClosed
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
    auth: AuthModel(
      login_email: "",
      login_password: "",
      login_error: option.None,
      login_in_flight: False,
      forgot_password_open: False,
      forgot_password_email: "",
      forgot_password_in_flight: False,
      forgot_password_result: option.None,
      forgot_password_error: option.None,
      forgot_password_copy_status: option.None,
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
    ),
    admin: admin_state.AdminModel(
      invite_links: NotAsked,
      invite_link_dialog: state_types.DialogClosed(operation: state_types.Idle),
      invite_link_last: option.None,
      invite_link_copy_status: option.None,
      projects_dialog: state_types.DialogClosed(operation: state_types.Idle),
      capabilities: NotAsked,
      capabilities_create_dialog_open: False,
      capabilities_create_name: "",
      capabilities_create_in_flight: False,
      capabilities_create_error: option.None,
      capability_delete_dialog_id: option.None,
      capability_delete_in_flight: False,
      capability_delete_error: option.None,
      members: NotAsked,
      members_project_id: option.None,
      org_users_cache: NotAsked,
      org_settings_users: NotAsked,
      admin_metrics_overview: NotAsked,
      admin_metrics_project_tasks: NotAsked,
      admin_metrics_project_id: option.None,
      admin_metrics_users: NotAsked,
      admin_rule_metrics: NotAsked,
      admin_rule_metrics_from: "",
      admin_rule_metrics_to: "",
      admin_rule_metrics_expanded_workflow: option.None,
      admin_rule_metrics_workflow_details: NotAsked,
      admin_rule_metrics_drilldown_rule_id: option.None,
      admin_rule_metrics_rule_details: NotAsked,
      admin_rule_metrics_executions: NotAsked,
      admin_rule_metrics_exec_offset: 0,
      org_settings_save_in_flight: False,
      org_settings_error: option.None,
      org_settings_error_user_id: option.None,
      org_settings_delete_confirm: option.None,
      org_settings_delete_in_flight: False,
      org_settings_delete_error: option.None,
      members_add_dialog_open: False,
      members_add_selected_user: option.None,
      members_add_role: MemberRole,
      members_add_in_flight: False,
      members_add_error: option.None,
      members_remove_confirm: option.None,
      members_remove_in_flight: False,
      members_remove_error: option.None,
      members_release_confirm: option.None,
      members_release_in_flight: option.None,
      members_release_error: option.None,
      member_capabilities_dialog_user_id: option.None,
      member_capabilities_loading: False,
      member_capabilities_saving: False,
      member_capabilities_cache: dict.new(),
      member_capabilities_selected: [],
      member_capabilities_error: option.None,
      capability_members_dialog_capability_id: option.None,
      capability_members_loading: False,
      capability_members_saving: False,
      capability_members_cache: dict.new(),
      capability_members_selected: [],
      capability_members_error: option.None,
      org_users_search: state_types.OrgUsersSearchIdle("", 0),
      task_types: NotAsked,
      task_types_project_id: option.None,
      task_types_dialog_mode: option.None,
      task_types_create_dialog_open: False,
      task_types_create_name: "",
      task_types_create_icon: "",
      task_types_create_icon_search: "",
      task_types_create_icon_category: "all",
      task_types_create_capability_id: option.None,
      task_types_create_in_flight: False,
      task_types_create_error: option.None,
      task_types_icon_preview: state_types.IconIdle,
      cards: NotAsked,
      cards_project_id: option.None,
      cards_dialog_mode: option.None,
      cards_show_empty: False,
      cards_show_completed: False,
      cards_state_filter: option.None,
      cards_search: "",
      workflows_org: NotAsked,
      workflows_project: NotAsked,
      workflows_dialog_mode: option.None,
      rules_workflow_id: option.None,
      rules: NotAsked,
      rules_dialog_mode: option.None,
      rules_templates: NotAsked,
      rules_attach_template_id: option.None,
      rules_attach_in_flight: False,
      rules_attach_error: option.None,
      rules_expanded: set.new(),
      attach_template_modal: option.None,
      attach_template_selected: option.None,
      attach_template_loading: False,
      detaching_templates: set.new(),
      rules_metrics: NotAsked,
      task_templates_org: NotAsked,
      task_templates_project: NotAsked,
      task_templates_dialog_mode: option.None,
      assignments: state_types.AssignmentsModel(
        view_mode: assignments_view_mode.ByProject,
        search_input: "",
        search_query: "",
        project_members: dict.new(),
        user_projects: dict.new(),
        expanded_projects: set.new(),
        expanded_users: set.new(),
        inline_add_context: option.None,
        inline_add_selection: option.None,
        inline_add_search: "",
        inline_add_role: MemberRole,
        inline_add_in_flight: False,
        inline_remove_confirm: option.None,
        role_change_in_flight: option.None,
        role_change_previous: option.None,
      ),
    ),
    member: member_state.MemberModel(
      member_section: member_section.Pool,
      view_mode: view_mode.Pool,
      member_work_sessions: NotAsked,
      member_metrics: NotAsked,
      member_now_working_in_flight: False,
      member_now_working_error: option.None,
      now_working_tick: 0,
      now_working_tick_running: False,
      now_working_server_offset_ms: 0,
      member_tasks: NotAsked,
      member_tasks_pending: 0,
      member_tasks_by_project: dict.new(),
      member_task_types: NotAsked,
      member_task_types_pending: 0,
      member_task_types_by_project: dict.new(),
      member_cards_store: normalized_store.new(),
      member_cards: NotAsked,
      member_capabilities: NotAsked,
      member_task_mutation_in_flight: False,
      member_task_mutation_task_id: option.None,
      member_tasks_snapshot: option.None,
      member_filters_status: option.None,
      member_filters_type_id: option.None,
      member_filters_capability_id: option.None,
      member_filters_q: "",
      member_quick_my_caps: True,
      member_pool_filters_visible: False,
      member_pool_view_mode: pool_prefs.Canvas,
      member_list_hide_completed: True,
      member_list_expanded_cards: dict.new(),
      member_panel_expanded: False,
      member_create_dialog_open: False,
      member_create_title: "",
      member_create_description: "",
      member_create_priority: "3",
      member_create_type_id: "",
      member_create_card_id: option.None,
      member_create_in_flight: False,
      member_create_error: option.None,
      member_my_capability_ids: NotAsked,
      member_my_capability_ids_edit: dict.new(),
      member_my_capabilities_in_flight: False,
      member_my_capabilities_error: option.None,
      member_positions_by_task: dict.new(),
      member_drag: state_types.DragIdle,
      member_canvas_left: 0,
      member_canvas_top: 0,
      member_pool_drag: state_types.PoolDragIdle,
      member_pool_touch_task_id: option.None,
      member_pool_touch_longpress: option.None,
      member_pool_touch_client_x: 0,
      member_pool_touch_client_y: 0,
      member_pool_preview_task_id: option.None,
      member_hover_notes_cache: dict.new(),
      member_hover_notes_pending: dict.new(),
      member_position_edit_task: option.None,
      member_position_edit_x: "",
      member_position_edit_y: "",
      member_position_edit_in_flight: False,
      member_position_edit_error: option.None,
      member_notes_task_id: option.None,
      member_notes: NotAsked,
      member_note_content: "",
      member_note_in_flight: False,
      member_note_error: option.None,
      member_note_dialog_open: False,
      card_detail_open: option.None,
      member_task_detail_tab: task_tabs.DetailsTab,
      member_dependencies: NotAsked,
      member_dependency_dialog_open: False,
      member_dependency_search_query: "",
      member_dependency_candidates: NotAsked,
      member_dependency_selected_task_id: option.None,
      member_dependency_add_in_flight: False,
      member_dependency_add_error: option.None,
      member_dependency_remove_in_flight: option.None,
      member_blocked_claim_task: option.None,
    ),
    ui: UiModel(
      is_mobile: False,
      toast_state: toast.init(),
      theme: theme.Default,
      locale: i18n_locale.En,
      mobile_drawer: DrawerClosed,
      sidebar_collapse: BothCollapsed,
      preferences_popup_open: False,
    ),
  )
}
