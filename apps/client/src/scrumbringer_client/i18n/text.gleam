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
  MyTasks
  NoClaimedTasks
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
  MyCapabilitiesOn
  MyCapabilitiesOff
  SearchLabel
  SearchPlaceholder
  NoAvailableTasksRightNow
  CreateFirstTaskToStartUsingPool
  NoTasksMatchYourFilters
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
  AdminProjects
  AdminMetrics
  AdminMembers
  AdminCapabilities
  AdminTaskTypes
  NoAdminPermissions
  NotPermitted
  NotPermittedBody

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
  NoCapabilitiesYet

  // Members
  SelectProjectToManageMembers
  MembersTitle(project_name: String)
  AddMember
  NoMembersYet
  RemoveMemberTitle
  RemoveMemberConfirm(user_email: String, project_name: String)
  Remove

  // Task types
  SelectProjectToManageTaskTypes
  TaskTypesTitle(project_name: String)
  CreateTaskType
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

  // Workflows
  AdminWorkflows
  WorkflowsTitle
  WorkflowsOrgTitle
  WorkflowsProjectTitle(project_name: String)
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
  RuleDeleted
  AttachTemplate
  DetachTemplate

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
  CreateTaskTemplate
  EditTaskTemplate
  DeleteTaskTemplate
  NoTaskTemplatesYet
  TaskTemplateDeleted
  TaskTemplateVariablesHelp
}
