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

import gleam/dict.{type Dict}
import gleam/option.{type Option}

import domain/user.{type User}

import scrumbringer_client/accept_invite
// API types from domain modules
import domain/api_error.{type ApiError, type ApiResult}
import domain/project.{type Project, type ProjectMember}
import domain/capability.{type Capability}
import domain/org.{type InviteLink, type OrgUser}
import domain/task.{
  type ActiveTaskPayload, type Task,
  type TaskNote, type TaskPosition,
  type WorkSessionsPayload,
}
import domain/task_type.{type TaskType}
import domain/card.{type Card}
import domain/workflow.{type Rule, type RuleTemplate, type TaskTemplate, type Workflow}
import scrumbringer_client/api/workflows as api_workflows
import domain/metrics.{
  type MyMetrics, type OrgMetricsOverview,
  type OrgMetricsProjectTasksPayload,
}
import scrumbringer_client/api/auth.{type PasswordReset}
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
  Failed(ApiError)
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

/// Dialog mode for Card CRUD operations.
///
/// Used by the parent to control which dialog the card-crud-dialog
/// component should display:
/// - `CardDialogCreate`: Show create new card form
/// - `CardDialogEdit(Int)`: Show edit form for card with given ID
/// - `CardDialogDelete(Int)`: Show delete confirmation for card with given ID
pub type CardDialogMode {
  CardDialogCreate
  CardDialogEdit(Int)
  CardDialogDelete(Int)
}

/// Dialog mode for Workflow CRUD operations.
///
/// Used by the parent to control which dialog the workflow-crud-dialog
/// component should display:
/// - `WorkflowDialogCreate`: Show create new workflow form
/// - `WorkflowDialogEdit(Workflow)`: Show edit form for given workflow
/// - `WorkflowDialogDelete(Workflow)`: Show delete confirmation for given workflow
pub type WorkflowDialogMode {
  WorkflowDialogCreate
  WorkflowDialogEdit(Workflow)
  WorkflowDialogDelete(Workflow)
}

/// Dialog mode for Task Template CRUD operations.
///
/// Used by the parent to control which dialog the task-template-crud-dialog
/// component should display:
/// - `TaskTemplateDialogCreate`: Show create new template form
/// - `TaskTemplateDialogEdit(TaskTemplate)`: Show edit form for given template
/// - `TaskTemplateDialogDelete(TaskTemplate)`: Show delete confirmation for given template
pub type TaskTemplateDialogMode {
  TaskTemplateDialogCreate
  TaskTemplateDialogEdit(TaskTemplate)
  TaskTemplateDialogDelete(TaskTemplate)
}

/// Dialog mode for Rule CRUD operations.
///
/// Used by the parent to control which dialog the rule-crud-dialog
/// component should display:
/// - `RuleDialogCreate`: Show create new rule form
/// - `RuleDialogEdit(Rule)`: Show edit form for given rule
/// - `RuleDialogDelete(Rule)`: Show delete confirmation for given rule
pub type RuleDialogMode {
  RuleDialogCreate
  RuleDialogEdit(Rule)
  RuleDialogDelete(Rule)
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
    forgot_password_result: Option(PasswordReset),
    forgot_password_error: Option(String),
    forgot_password_copy_status: Option(String),
    // Child components
    accept_invite: accept_invite.Model,
    reset_password: reset_password.Model,
    // Projects
    projects: Remote(List(Project)),
    selected_project_id: Option(Int),
    // Invite links
    invite_links: Remote(List(InviteLink)),
    invite_link_email: String,
    invite_link_in_flight: Bool,
    invite_link_error: Option(String),
    invite_link_last: Option(InviteLink),
    invite_link_copy_status: Option(String),
    // Project creation
    projects_create_dialog_open: Bool,
    projects_create_name: String,
    projects_create_in_flight: Bool,
    projects_create_error: Option(String),
    // Capabilities
    capabilities: Remote(List(Capability)),
    capabilities_create_dialog_open: Bool,
    capabilities_create_name: String,
    capabilities_create_in_flight: Bool,
    capabilities_create_error: Option(String),
    // Members
    members: Remote(List(ProjectMember)),
    members_project_id: Option(Int),
    // Org users
    org_users_cache: Remote(List(OrgUser)),
    org_settings_users: Remote(List(OrgUser)),
    // Admin metrics
    admin_metrics_overview: Remote(OrgMetricsOverview),
    admin_metrics_project_tasks: Remote(OrgMetricsProjectTasksPayload),
    admin_metrics_project_id: Option(Int),
    // Rule metrics tab
    admin_rule_metrics: Remote(List(api_workflows.OrgWorkflowMetricsSummary)),
    admin_rule_metrics_from: String,
    admin_rule_metrics_to: String,
    // Rule metrics drill-down
    admin_rule_metrics_expanded_workflow: Option(Int),
    admin_rule_metrics_workflow_details: Remote(api_workflows.WorkflowMetrics),
    admin_rule_metrics_drilldown_rule_id: Option(Int),
    admin_rule_metrics_rule_details: Remote(api_workflows.RuleMetricsDetailed),
    admin_rule_metrics_executions: Remote(api_workflows.RuleExecutionsResponse),
    admin_rule_metrics_exec_offset: Int,
    // Org settings
    org_settings_role_drafts: Dict(Int, String),
    org_settings_save_in_flight: Bool,
    org_settings_error: Option(String),
    org_settings_error_user_id: Option(Int),
    // User projects dialog
    user_projects_dialog_open: Bool,
    user_projects_dialog_user: Option(OrgUser),
    user_projects_list: Remote(List(Project)),
    user_projects_add_project_id: Option(Int),
    user_projects_in_flight: Bool,
    user_projects_error: Option(String),
    // Member add dialog
    members_add_dialog_open: Bool,
    members_add_selected_user: Option(OrgUser),
    members_add_role: String,
    members_add_in_flight: Bool,
    members_add_error: Option(String),
    // Member remove dialog
    members_remove_confirm: Option(OrgUser),
    members_remove_in_flight: Bool,
    members_remove_error: Option(String),
    // Org user search
    org_users_search_query: String,
    org_users_search_token: Int,
    org_users_search_results: Remote(List(OrgUser)),
    // Task types
    task_types: Remote(List(TaskType)),
    task_types_project_id: Option(Int),
    task_types_create_dialog_open: Bool,
    task_types_create_name: String,
    task_types_create_icon: String,
    task_types_create_icon_search: String,
    task_types_create_icon_category: String,
    task_types_create_capability_id: Option(String),
    task_types_create_in_flight: Bool,
    task_types_create_error: Option(String),
    task_types_icon_preview: IconPreview,
    // Cards - list data and dialog mode (component handles CRUD state internally)
    cards: Remote(List(Card)),
    cards_project_id: Option(Int),
    cards_dialog_mode: Option(CardDialogMode),
    // Card detail (member view) - only open state, component manages internal state
    card_detail_open: Option(Int),
    // Workflows
    workflows_org: Remote(List(Workflow)),
    workflows_project: Remote(List(Workflow)),
    // Workflows - dialog mode (component handles CRUD state internally)
    workflows_dialog_mode: Option(WorkflowDialogMode),
    // Rules (for selected workflow) - list and dialog mode (component handles CRUD state internally)
    rules_workflow_id: Option(Int),
    rules: Remote(List(Rule)),
    rules_dialog_mode: Option(RuleDialogMode),
    // Rule templates (attached templates)
    rules_templates: Remote(List(RuleTemplate)),
    rules_attach_template_id: Option(Int),
    rules_attach_in_flight: Bool,
    rules_attach_error: Option(String),
    // Rule metrics (inline display)
    rules_metrics: Remote(api_workflows.WorkflowMetrics),
    // Task templates - list data and dialog mode (component handles CRUD state internally)
    task_templates_org: Remote(List(TaskTemplate)),
    task_templates_project: Remote(List(TaskTemplate)),
    task_templates_dialog_mode: Option(TaskTemplateDialogMode),
    // Member section
    member_section: member_section.MemberSection,
    member_active_task: Remote(ActiveTaskPayload),
    // Work sessions (multi-session model)
    member_work_sessions: Remote(WorkSessionsPayload),
    member_metrics: Remote(MyMetrics),
    member_now_working_in_flight: Bool,
    member_now_working_error: Option(String),
    // Now working timer
    now_working_tick: Int,
    now_working_tick_running: Bool,
    now_working_server_offset_ms: Int,
    // Member tasks
    member_tasks: Remote(List(Task)),
    member_tasks_pending: Int,
    member_tasks_by_project: Dict(Int, List(Task)),
    member_task_types: Remote(List(TaskType)),
    member_task_types_pending: Int,
    member_task_types_by_project: Dict(Int, List(TaskType)),
    member_task_mutation_in_flight: Bool,
    member_task_mutation_task_id: Option(Int),
    member_tasks_snapshot: Option(List(Task)),
    // Member filters
    member_filters_status: String,
    member_filters_type_id: String,
    member_filters_capability_id: String,
    member_filters_q: String,
    member_quick_my_caps: Bool,
    member_pool_filters_visible: Bool,
    member_pool_view_mode: pool_prefs.ViewMode,
    // Mobile panel toggle
    member_panel_expanded: Bool,
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
    member_notes: Remote(List(TaskNote)),
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
  MeFetched(ApiResult(User))
  AcceptInviteMsg(accept_invite.Msg)
  ResetPasswordMsg(reset_password.Msg)

  // Login form
  LoginEmailChanged(String)
  LoginPasswordChanged(String)
  LoginSubmitted
  LoginDomValuesRead(String, String)
  LoginFinished(ApiResult(User))

  // Forgot password
  ForgotPasswordClicked
  ForgotPasswordEmailChanged(String)
  ForgotPasswordSubmitted
  ForgotPasswordFinished(ApiResult(PasswordReset))
  ForgotPasswordCopyClicked
  ForgotPasswordCopyFinished(Bool)
  ForgotPasswordDismissed

  // Logout
  LogoutClicked
  LogoutFinished(ApiResult(Nil))

  // Toast
  ToastDismissed

  // Preferences
  ThemeSelected(String)
  LocaleSelected(String)

  // Project selection
  ProjectSelected(String)

  // Projects CRUD
  ProjectsFetched(ApiResult(List(Project)))
  ProjectCreateDialogOpened
  ProjectCreateDialogClosed
  ProjectCreateNameChanged(String)
  ProjectCreateSubmitted
  ProjectCreated(ApiResult(Project))

  // Invite links
  InviteLinkEmailChanged(String)
  InviteLinkCreateSubmitted
  InviteLinkCreated(ApiResult(InviteLink))
  InviteLinksFetched(ApiResult(List(InviteLink)))
  InviteLinkRegenerateClicked(String)
  InviteLinkRegenerated(ApiResult(InviteLink))
  InviteLinkCopyClicked(String)
  InviteLinkCopyFinished(Bool)

  // Capabilities
  CapabilitiesFetched(ApiResult(List(Capability)))
  CapabilityCreateDialogOpened
  CapabilityCreateDialogClosed
  CapabilityCreateNameChanged(String)
  CapabilityCreateSubmitted
  CapabilityCreated(ApiResult(Capability))

  // Members
  MembersFetched(ApiResult(List(ProjectMember)))
  OrgUsersCacheFetched(ApiResult(List(OrgUser)))
  OrgSettingsUsersFetched(ApiResult(List(OrgUser)))
  OrgSettingsRoleChanged(Int, String)
  OrgSettingsSaveClicked(Int)
  OrgSettingsSaved(Int, ApiResult(OrgUser))

  // User projects dialog
  UserProjectsDialogOpened(OrgUser)
  UserProjectsDialogClosed
  UserProjectsFetched(ApiResult(List(Project)))
  UserProjectsAddProjectChanged(String)
  UserProjectsAddSubmitted
  UserProjectAdded(ApiResult(Project))
  UserProjectRemoveClicked(Int)
  UserProjectRemoved(ApiResult(Nil))

  // Member add dialog
  MemberAddDialogOpened
  MemberAddDialogClosed
  MemberAddRoleChanged(String)
  MemberAddUserSelected(Int)
  MemberAddSubmitted
  MemberAdded(ApiResult(ProjectMember))

  // Member remove
  MemberRemoveClicked(Int)
  MemberRemoveCancelled
  MemberRemoveConfirmed
  MemberRemoved(ApiResult(Nil))

  // Org user search
  OrgUsersSearchChanged(String)
  OrgUsersSearchDebounced(String)
  OrgUsersSearchResults(Int, ApiResult(List(OrgUser)))

  // Task types
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

  // Cards - list loading
  CardsFetched(ApiResult(List(Card)))
  // Cards - dialog mode control (component pattern)
  OpenCardDialog(CardDialogMode)
  CloseCardDialog
  // Cards - component events (card-crud-dialog emits these)
  CardCrudCreated(Card)
  CardCrudUpdated(Card)
  CardCrudDeleted(Int)

  // Card detail (member view) - component manages internal state
  OpenCardDetail(Int)
  CloseCardDetail

  // Workflows
  WorkflowsOrgFetched(ApiResult(List(Workflow)))
  WorkflowsProjectFetched(ApiResult(List(Workflow)))
  // Workflows - dialog mode control (component pattern)
  OpenWorkflowDialog(WorkflowDialogMode)
  CloseWorkflowDialog
  // Workflows - component events (workflow-crud-dialog emits these)
  WorkflowCrudCreated(Workflow)
  WorkflowCrudUpdated(Workflow)
  WorkflowCrudDeleted(Int)
  WorkflowRulesClicked(Int)

  // Rules
  RulesFetched(ApiResult(List(Rule)))
  RulesBackClicked
  // Rules - dialog mode control (component pattern)
  OpenRuleDialog(RuleDialogMode)
  CloseRuleDialog
  // Rules - component events (rule-crud-dialog emits these)
  RuleCrudCreated(Rule)
  RuleCrudUpdated(Rule)
  RuleCrudDeleted(Int)
  RuleTemplatesClicked(Int)

  // Rule templates
  RuleTemplatesFetched(ApiResult(List(RuleTemplate)))
  RuleAttachTemplateSelected(String)
  RuleAttachTemplateSubmitted
  RuleTemplateAttached(ApiResult(List(RuleTemplate)))
  RuleTemplateDetachClicked(Int)
  RuleTemplateDetached(ApiResult(Nil))

  // Rule metrics (inline display)
  RuleMetricsFetched(ApiResult(api_workflows.WorkflowMetrics))

  // Task templates
  TaskTemplatesOrgFetched(ApiResult(List(TaskTemplate)))
  TaskTemplatesProjectFetched(ApiResult(List(TaskTemplate)))
  // Task templates - dialog mode control (component pattern)
  OpenTaskTemplateDialog(TaskTemplateDialogMode)
  CloseTaskTemplateDialog
  // Task templates - component events (task-template-crud-dialog emits these)
  TaskTemplateCrudCreated(TaskTemplate)
  TaskTemplateCrudUpdated(TaskTemplate)
  TaskTemplateCrudDeleted(Int)

  // Pool filters
  MemberPoolStatusChanged(String)
  MemberPoolTypeChanged(String)
  MemberPoolCapabilityChanged(String)
  MemberPoolSearchChanged(String)
  MemberPoolSearchDebounced(String)
  MemberToggleMyCapabilitiesQuick
  MemberPoolFiltersToggled
  MemberPoolViewModeSet(pool_prefs.ViewMode)
  MemberPanelToggled

  // Keyboard
  GlobalKeyDown(pool_prefs.KeyEvent)

  // Member tasks
  MemberProjectTasksFetched(Int, ApiResult(List(Task)))
  MemberTaskTypesFetched(Int, ApiResult(List(TaskType)))

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
  MemberTaskCreated(ApiResult(Task))

  // Task actions
  MemberClaimClicked(Int, Int)
  MemberReleaseClicked(Int, Int)
  MemberCompleteClicked(Int, Int)
  MemberTaskClaimed(ApiResult(Task))
  MemberTaskReleased(ApiResult(Task))
  MemberTaskCompleted(ApiResult(Task))

  // Now working (legacy single-session)
  MemberNowWorkingStartClicked(Int)
  MemberNowWorkingPauseClicked
  MemberActiveTaskFetched(ApiResult(ActiveTaskPayload))
  MemberActiveTaskStarted(ApiResult(ActiveTaskPayload))
  MemberActiveTaskPaused(ApiResult(ActiveTaskPayload))
  MemberActiveTaskHeartbeated(ApiResult(ActiveTaskPayload))
  // Work sessions (multi-session)
  MemberWorkSessionsFetched(ApiResult(WorkSessionsPayload))
  MemberWorkSessionStarted(ApiResult(WorkSessionsPayload))
  MemberWorkSessionPaused(ApiResult(WorkSessionsPayload))
  MemberWorkSessionHeartbeated(ApiResult(WorkSessionsPayload))
  // Metrics
  MemberMetricsFetched(ApiResult(MyMetrics))
  AdminMetricsOverviewFetched(ApiResult(OrgMetricsOverview))
  AdminMetricsProjectTasksFetched(
    ApiResult(OrgMetricsProjectTasksPayload),
  )
  NowWorkingTicked

  // Rule metrics tab
  AdminRuleMetricsFetched(ApiResult(List(api_workflows.OrgWorkflowMetricsSummary)))
  AdminRuleMetricsFromChanged(String)
  AdminRuleMetricsToChanged(String)
  AdminRuleMetricsRefreshClicked
  AdminRuleMetricsQuickRangeClicked(String, String)
  // Rule metrics drill-down
  AdminRuleMetricsWorkflowExpanded(Int)
  AdminRuleMetricsWorkflowDetailsFetched(ApiResult(api_workflows.WorkflowMetrics))
  AdminRuleMetricsDrilldownClicked(Int)
  AdminRuleMetricsDrilldownClosed
  AdminRuleMetricsRuleDetailsFetched(
    ApiResult(api_workflows.RuleMetricsDetailed),
  )
  AdminRuleMetricsExecutionsFetched(
    ApiResult(api_workflows.RuleExecutionsResponse),
  )
  AdminRuleMetricsExecPageChanged(Int)

  // Member capabilities
  MemberMyCapabilityIdsFetched(ApiResult(List(Int)))
  MemberToggleCapability(Int)
  MemberSaveCapabilitiesClicked
  MemberMyCapabilityIdsSaved(ApiResult(List(Int)))

  // Position editing
  MemberPositionsFetched(ApiResult(List(TaskPosition)))
  MemberPositionEditOpened(Int)
  MemberPositionEditClosed
  MemberPositionEditXChanged(String)
  MemberPositionEditYChanged(String)
  MemberPositionEditSubmitted
  MemberPositionSaved(ApiResult(TaskPosition))

  // Task details and notes
  MemberTaskDetailsOpened(Int)
  MemberTaskDetailsClosed
  MemberNotesFetched(ApiResult(List(TaskNote)))
  MemberNoteContentChanged(String)
  MemberNoteSubmitted
  MemberNoteAdded(ApiResult(TaskNote))
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
    projects_create_dialog_open: False,
    projects_create_name: "",
    projects_create_in_flight: False,
    projects_create_error: option.None,
    // Capabilities
    capabilities: NotAsked,
    capabilities_create_dialog_open: False,
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
    // Rule metrics tab (default: last 30 days)
    admin_rule_metrics: NotAsked,
    admin_rule_metrics_from: "",
    admin_rule_metrics_to: "",
    // Rule metrics drill-down
    admin_rule_metrics_expanded_workflow: option.None,
    admin_rule_metrics_workflow_details: NotAsked,
    admin_rule_metrics_drilldown_rule_id: option.None,
    admin_rule_metrics_rule_details: NotAsked,
    admin_rule_metrics_executions: NotAsked,
    admin_rule_metrics_exec_offset: 0,
    // Org settings
    org_settings_role_drafts: dict.new(),
    org_settings_save_in_flight: False,
    org_settings_error: option.None,
    org_settings_error_user_id: option.None,
    // User projects dialog
    user_projects_dialog_open: False,
    user_projects_dialog_user: option.None,
    user_projects_list: NotAsked,
    user_projects_add_project_id: option.None,
    user_projects_in_flight: False,
    user_projects_error: option.None,
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
    org_users_search_token: 0,
    org_users_search_results: NotAsked,
    // Task types
    task_types: NotAsked,
    task_types_project_id: option.None,
    task_types_create_dialog_open: False,
    task_types_create_name: "",
    task_types_create_icon: "",
    task_types_create_icon_search: "",
    task_types_create_icon_category: "all",
    task_types_create_capability_id: option.None,
    task_types_create_in_flight: False,
    task_types_create_error: option.None,
    task_types_icon_preview: IconIdle,
    // Cards - list and dialog mode (component handles CRUD state internally)
    cards: NotAsked,
    cards_project_id: option.None,
    cards_dialog_mode: option.None,
    // Card detail (member view) - only open state, component manages internal state
    card_detail_open: option.None,
    // Workflows
    workflows_org: NotAsked,
    workflows_project: NotAsked,
    // Workflows - dialog mode (component handles CRUD state internally)
    workflows_dialog_mode: option.None,
    // Rules (for selected workflow) - list and dialog mode
    rules_workflow_id: option.None,
    rules: NotAsked,
    rules_dialog_mode: option.None,
    // Rule templates
    rules_templates: NotAsked,
    rules_attach_template_id: option.None,
    rules_attach_in_flight: False,
    rules_attach_error: option.None,
    // Rule metrics (inline display)
    rules_metrics: NotAsked,
    // Task templates - list and dialog mode (component handles CRUD state internally)
    task_templates_org: NotAsked,
    task_templates_project: NotAsked,
    task_templates_dialog_mode: option.None,
    // Member section
    member_section: member_section.Pool,
    member_active_task: NotAsked,
    member_work_sessions: NotAsked,
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
    member_task_mutation_task_id: option.None,
    member_tasks_snapshot: option.None,
    // Member filters
    member_filters_status: "",
    member_filters_type_id: "",
    member_filters_capability_id: "",
    member_filters_q: "",
    // UX: default to My Capabilities enabled
    member_quick_my_caps: True,
    member_pool_filters_visible: False,
    member_pool_view_mode: pool_prefs.Canvas,
    // Mobile panel toggle
    member_panel_expanded: False,
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
