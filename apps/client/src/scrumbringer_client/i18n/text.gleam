//// I18n text key definitions for Scrumbringer UI.
////
//// Defines all translatable text keys as a variant type. Each key maps to
//// translations in language-specific modules (en.gleam, es.gleam).

pub type Text {
  // App
  AppName
  AppSectionTitle

  // Auth flows
  LoginTitle
  LoginSubtitle
  NoEmailIntegrationNote
  EmailLabel
  EmailPlaceholderExample
  PasswordLabel
  NewPasswordLabel
  MinimumPasswordLength
  Logout

  AcceptInviteTitle
  ResetPasswordTitle
  MissingInviteToken
  ValidatingInvite
  SignedIn
  MissingResetToken
  ValidatingResetToken
  PasswordUpdated
  Welcome
  LoggedIn
  InvalidCredentials
  EmailAndPasswordRequired
  EmailRequired
  LogoutFailed

  // Toasts / messages
  LoggedOut
  ProjectCreated
  CapabilityCreated
  InviteLinkCreated
  InviteLinkRegenerated
  RoleUpdated
  CannotDemoteLastManager
  MemberAdded
  MemberRemoved
  TaskTypeCreated
  TaskCreated
  TaskClaimed
  TaskReleased
  TaskCompleted
  SkillsSaved
  NoteAdded

  // Validation
  NameRequired
  TitleRequired
  TypeRequired
  SelectProjectFirst
  SelectUserFirst
  InvalidXY
  ContentRequired

  // Accessibility
  SkipToContent

  // Buttons / common
  Dismiss
  Cancel
  Close
  Create
  Creating
  Copy
  Copied
  Copying
  CopyFailed
  Save
  SaveNewPassword
  Saving
  Register
  Registering
  Working
  GenerateResetLink
  ForgotPassword
  ResetLink
  CreateInviteLink
  Add
  Adding
  Removing
  NoneOption
  Start
  LoggingIn
  Loading
  LoadingEllipsis

  // Settings controls
  ThemeLabel
  ThemeDefault
  ThemeDark
  LanguageLabel
  LanguageEs
  LanguageEn

  // Member sections
  Pool
  MyBar
  MySkills
  MySkillsHelp
  MyTasks
  NoClaimedTasks
  GoToPoolToClaimTasks
  NoProjectsBody
  You
  Notes
  AddNote
  EditPosition
  XLabel
  YLabel

  // Member pool controls
  ViewCanvas
  ViewList
  Canvas
  List
  ShowFilters
  HideFilters
  NewTask
  Description
  Priority
  NewTaskShortcut
  AllOption
  SelectType
  TypeLabel
  CapabilityLabel
  MyCapabilitiesLabel
  MyCapabilitiesHint
  MyCapabilitiesOn
  MyCapabilitiesOff
  SearchLabel
  SearchPlaceholder
  ClearFilters
  ActiveFilters(count: Int)
  NoAvailableTasksRightNow
  CreateFirstTaskToStartUsingPool
  NoTasksMatchYourFilters
  HideCompletedTasks
  TypeNumber(type_id: Int)
  MetaType
  MetaPriority
  MetaCreated
  PriorityShort(priority: Int)
  Claim
  Drag
  StartNowWorking
  PauseNowWorking

  // Now working
  NowWorking
  NowWorkingLoading
  NowWorkingNone
  NowWorkingErrorPrefix
  Pause
  Complete
  Release
  TaskNumber(task_id: Int)

  // Admin
  Admin
  AdminInvites
  AdminOrgSettings
  OrgSettingsHelp
  RoleAdmin
  RoleMember
  RoleManager
  AdminProjects
  AdminMetrics
  OrgMetrics
  AdminMembers
  AdminCapabilities
  AdminTaskTypes
  NoAdminPermissions
  NotPermitted
  NotPermittedBody

  // Admin sidebar groups (SA01-SA05)
  NavGroupOrganization
  NavGroupProjects
  NavGroupConfiguration
  NavGroupContent

  // Project selector
  ProjectLabel
  AllProjects
  SelectProjectToManageSettings
  ShowingTasksFromAllProjects
  SelectProjectToManageMembersOrTaskTypes

  // Metrics (member + org)
  MyMetrics
  LoadingMetrics
  WindowDays(days: Int)
  Claimed
  Released
  Completed
  MetricsOverview
  LoadingOverview
  ReleasePercent
  FlowPercent
  TimeToFirstClaim
  TimeToFirstClaimP50(p50: String, sample_size: Int)
  ReleaseRateDistribution
  Bucket
  Count
  ByProject
  Drill
  View
  ProjectDrillDown
  SelectProjectToInspectTasks
  LoadingTasks
  Title
  Status
  Claims
  Releases
  Completes
  FirstClaim
  ProjectTasks(project_name: String)

  // Org users
  OpenThisSectionToLoadUsers
  LoadingUsers
  Role
  Actions
  User
  UserId
  UserNumber(user_id: Int)
  Created
  SearchByEmail
  Searching
  TypeAnEmailToSearch
  NoResults
  Select
  OrgRole

  // Invite links
  InvitesTitle
  LatestInviteLink
  InviteLinks
  InviteLinksHelp
  FailedToLoadInviteLinksPrefix
  NoInviteLinksYet
  Link
  State
  CreatedAt
  Regenerate

  // Projects
  Projects
  CreateProject
  Name
  MyRole
  NoProjectsYet

  // Capabilities
  Capabilities
  CreateCapability
  CapabilityNamePlaceholder
  NoCapabilitiesYet

  // Members
  SelectProjectToManageMembers
  MembersTitle(project_name: String)
  MembersHelp
  AddMember
  NoMembersYet
  RemoveMemberTitle
  RemoveMemberConfirm(user_email: String, project_name: String)
  Remove
  // Member capabilities (Story 4.7 AC10-14)
  CapabilitiesForUser(user_email: String)
  NoCapabilitiesDefined
  // Capability members (Story 4.7 AC16-17)
  MembersForCapability(capability_name: String)
  MembersSaved
  NoMembersDefined

  // User Projects dialog
  UserProjectsTitle(user_email: String)
  UserProjectsEmpty
  UserProjectsAdd
  SelectProject
  UserProjectRemove
  RoleInProject
  ProjectRoleUpdated

  // Org Users main table
  Manage
  SaveOrgRoleChanges
  PendingChanges
  ProjectsSummary(count: Int, summary: String)

  // Task types
  SelectProjectToManageTaskTypes
  TaskTypesTitle(project_name: String)
  CreateTaskType
  IdentitySection
  AppearanceSection
  ConfigurationSection
  Icon
  UnknownIcon
  CapabilityOptional
  LoadingCapabilities
  NoTaskTypesYet
  CreateFirstTaskTypeHint
  TaskTypesExplain
  HeroiconSearchPlaceholder
  WaitForIconPreview
  TitleTooLongMax56
  NameAndIconRequired
  PriorityMustBe1To5

  // Popover labels
  PopoverType
  PopoverCreated
  PopoverStatus
  CreatedAgoDays(days: Int)

  // Cards (fichas)
  AdminCards
  CardsTitle(project_name: String)
  SelectProjectToManageCards
  CreateCard
  EditCard
  DeleteCard
  CardTitle
  CardDescription
  CardState
  CardStatePendiente
  CardStateEnCurso
  CardStateCerrada
  CardTasks
  CardProgress
  CardCreated
  CardUpdated
  CardDeleted
  CardDeleteBlocked
  CardDeleteConfirm(card_title: String)
  NoCardsYet
  CardTaskCount(completed: Int, total: Int)
  KanbanEmptyColumn

  // Workflows
  AdminWorkflows
  WorkflowsTitle
  WorkflowsOrgTitle
  WorkflowsProjectTitle(project_name: String)
  SelectProjectForWorkflows
  WorkflowName
  WorkflowDescription
  WorkflowScope
  WorkflowScopeOrg
  WorkflowScopeProject
  WorkflowRules
  WorkflowActive
  WorkflowCreated
  WorkflowUpdated
  CreateWorkflow
  EditWorkflow
  DeleteWorkflow
  WorkflowDeleteConfirm(workflow_name: String)
  NoWorkflowsYet
  WorkflowDeleted

  // Rules
  RulesTitle(workflow_name: String)
  RuleName
  RuleGoal
  RuleResourceType
  RuleResourceTypeTask
  RuleResourceTypeCard
  RuleToState
  RuleTaskType
  RuleActive
  RuleTemplates
  CreateRule
  EditRule
  DeleteRule
  NoRulesYet
  RuleCreated
  RuleUpdated
  RuleDeleted
  RuleDeleteConfirm(rule_name: String)
  AttachTemplate
  DetachTemplate
  RuleMetricsApplied
  RuleMetricsSuppressed

  // Task States (for Rules)
  TaskStateAvailable
  TaskStateClaimed
  TaskStateCompleted

  // Task Templates
  AdminTaskTemplates
  TaskTemplatesTitle
  TaskTemplatesOrgTitle
  TaskTemplatesProjectTitle(project_name: String)
  TaskTemplateName
  TaskTemplateDescription
  TaskTemplateType
  TaskTemplatePriority
  TaskTemplateScope
  TaskTemplateCreated
  TaskTemplateUpdated
  CreateTaskTemplate
  EditTaskTemplate
  DeleteTaskTemplate
  NoTaskTemplatesYet
  TaskTemplateDeleted
  TaskTemplateDeleteConfirm(template_name: String)
  TaskTemplateVariablesHelp

  // Rule Metrics Tab
  AdminRuleMetrics
  RuleMetricsTitle
  RuleMetricsHelp
  RuleMetricsFrom
  RuleMetricsTo
  RuleMetricsRefresh
  RuleMetricsSelectRange
  RuleMetricsNoData
  RuleMetricsRuleCount
  RuleMetricsEvaluated
  RuleMetricsNoRules
  ViewDetails
  RuleMetricsDrilldown
  SuppressionBreakdown
  SuppressionIdempotent
  SuppressionNotUserTriggered
  SuppressionNotMatching
  SuppressionInactive
  RecentExecutions
  NoExecutions
  Origin
  Outcome
  Timestamp
  OutcomeApplied
  OutcomeSuppressed

  // Story 3.4 - Member Card Views
  // Member Fichas section
  MemberFichas
  MemberFichasEmpty
  MemberFichasEmptyHint

  // Color picker
  ColorLabel
  ColorNone
  ColorGray
  ColorRed
  ColorOrange
  ColorYellow
  ColorGreen
  ColorBlue
  ColorPurple
  ColorPink

  // Card grouping
  UngroupedTasks
  CardProgressCount(completed: Int, total: Int)

  // Card detail (member)
  CardAddTask
  CardTasksEmpty
  CardTasksCompleted
  TaskType
  TaskTitlePlaceholder

  // Story 4.4 - Three-panel layout
  // Accessibility labels
  MainNavigation
  MyActivity

  // Left panel sections
  Work
  NewCard
  Configuration
  Team
  Catalog
  Automation
  Organization
  OrgUsers
  Invites

  // Right panel sections
  InProgress
  Resume
  MyCards
  NoTasksClaimed
  NoCardsAssigned
  // AC32: Empty state hints with CTAs
  NoTasksClaimedHint
  NoCardsAssignedHint
}
