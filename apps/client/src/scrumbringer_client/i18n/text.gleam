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
  CapabilityDeleted
  InviteLinkCreated
  InviteLinkRegenerated
  RoleUpdated
  CannotDemoteLastManager
  MemberAdded
  MemberRemoved
  TaskTypeCreated
  TaskCreated
  TaskCreatedNotVisibleByFilters
  TaskClaimed
  TaskReleased
  TaskCompleted
  SkillsSaved
  NoteAdded

  // Task mutation errors
  TaskClaimFailed
  TaskReleaseFailed
  TaskCompleteFailed
  TaskVersionConflict
  TaskAlreadyClaimed
  TaskNotFound
  TaskMutationRolledBack

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
  Saved
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
  Delete
  DeleteAsAdmin
  Deleting
  Deleted
  NoneOption
  Start
  LoggingIn
  Loading
  LoadingEllipsis

  // Settings controls
  Preferences
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
  NotePlaceholder
  RecentNotes
  Dependencies
  AddDependency
  NoDependencies
  TaskDependenciesHint
  TaskDependenciesEmptyHint
  TaskNotesHint
  NoNotesYet
  TaskNotesEmptyHint
  NoMatchingTasks
  TaskDependsOn
  Blocked
  BlockedByTasks(count: Int)
  HiddenBlockedByFilters(count: Int)
  BlockedTaskTitle
  BlockedTaskWarning(count: Int)
  EditPosition
  XLabel
  YLabel

  // Member pool controls
  ViewCanvas
  ViewList
  Canvas
  List
  Kanban
  People
  Milestones
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
  ClaimThisTask
  ClaimedBy
  UnknownUser
  Busy
  Free
  PeopleSearchPlaceholder
  PeopleEmpty
  PeopleNoResults
  PeopleLoading
  PeopleLoadError
  MilestonesEmpty
  MilestonesNoResults
  MilestonesLoadError
  ShowCompletedMilestones
  ShowEmptyMilestones
  MilestonesReady
  MilestonesActive
  MilestonesCompleted
  MilestoneDone
  MilestoneActivationTitle
  MilestoneActivationBody(cards_count: Int, tasks_count: Int)
  MilestoneActivationWarning
  MilestoneDetails
  MilestoneTabOverview
  MilestoneTabContent
  ActivateMilestone
  ActivatingMilestone
  MilestoneActivated
  MilestoneActivateFailed
  EditMilestone
  DeleteMilestone
  DeleteMilestoneTitle
  DeleteMilestoneConfirm(name: String)
  MilestoneUpdated
  MilestoneUpdateFailed
  MilestoneDeleted
  MilestoneDeleteFailed
  MilestoneDeleteNotAllowed
  MilestoneAlreadyActive
  MilestoneActivationIrreversible
  MilestoneOpenDetails
  MilestoneMoreActions
  MilestoneMoveTo
  ExpandMilestone(name: String)
  CollapseMilestone(name: String)
  ExpandPerson(name: String)
  CollapsePerson(name: String)
  PeopleActiveSection
  PeopleClaimedSection
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
  Assignments
  AssignmentsByProject
  AssignmentsByUser
  AssignmentsSearchPlaceholder
  AssignmentsNoProjectsTitle
  AssignmentsNoProjectsBody
  AssignmentsNoUsersTitle
  AssignmentsNoUsersBody
  AssignmentsNoMembersBadge
  AssignmentsNoProjectsBadge
  AssignmentsUsersCount(count: Int)
  AssignmentsProjectsCount(count: Int)
  AssignmentsLoadingMembers
  AssignmentsLoadingProjects
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
  AvailableCount
  OngoingCount
  WipCount
  HealthPanel
  HealthFlow
  HealthRelease
  HealthTimeToFirstClaim
  HealthOk
  HealthAttention
  HealthAlert
  NoSample
  AvgClaimToComplete
  AvgTimeInClaimed
  StaleClaims
  LastClaim
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
  // Invite link states (Story 4.8)
  InviteStateActive
  InviteStateUsed
  InviteStateExpired
  CopyLink
  LinkCopied

  // Projects
  Projects
  CreateProject
  Name
  MyRole
  NoProjectsYet
  // Project edit/delete (Story 4.8 AC39)
  EditProject
  DeleteProject
  DeleteProjectTitle
  DeleteProjectConfirm(project_name: String)
  DeleteProjectWarning
  MembersCount

  // Capabilities
  Capabilities
  CreateCapability
  DeleteCapability
  ConfirmDeleteCapability(name: String)
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
  ClaimedTasks(count: Int)
  ReleaseAll
  ReleaseAllConfirmTitle
  ReleaseAllConfirmBody(count: Int, user_name: String)
  ReleaseAllSuccess(count: Int, user_name: String)
  ReleaseAllNone(user_name: String)
  ReleaseAllError(user_name: String)
  ReleaseAllSelfError
  // Member capabilities (Story 4.7 AC10-14, Story 4.8 AC23)
  CapabilitiesForUser(user_email: String, project_name: String)
  NoCapabilitiesDefined
  ManageCapabilities
  // Capability members (Story 4.7 AC16-17, Story 4.8 AC24)
  MembersForCapability(capability_name: String, project_name: String)
  MembersSaved
  NoMembersDefined
  ManageMembers

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
  DeleteUser
  ConfirmDeleteUser(user_email: String)
  UserDeleted

  // Task types
  SelectProjectToManageTaskTypes
  TaskTypesTitle(project_name: String)
  CreateTaskType
  EditTaskType
  DeleteTaskType
  ConfirmDeleteTaskType(name: String)
  TaskTypeHasTasks(count: Int)
  TaskTypeName
  TaskTypeUpdated
  TaskTypeDeleted

  // Contextual hints (Story 4.9 AC21-22)
  RulesHintTemplates
  RulesHintTemplatesLink
  TemplatesHintRules
  TemplatesHintRulesLink

  IdentitySection
  AppearanceSection
  ConfigurationSection
  Icon
  OptionalFields
  SelectIcon
  UnknownIcon
  CapabilityOptional
  TaskTypeNameHint
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
  KanbanEmptyPendiente
  KanbanEmptyEnCurso
  KanbanEmptyCerrada

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

  // Story 4.10: Rule template attachment UI
  ExpandRule
  CollapseRule
  AttachedTemplates
  AttachedTemplatesCount(count: Int)
  NoTemplatesAttached
  NoTemplatesWontCreateTasks
  SelectTemplateToAttach
  AvailableTemplatesInProject
  AttachTemplateHint
  NoTemplatesInProject
  CreateTemplateLink
  Attach
  Attaching
  TemplateAttached
  TemplateDetached
  DetachTemplateConfirm(template_name: String)
  Detaching
  RemoveTemplate

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
  TaskTemplateDescriptionHint
  AvailableVariables
  SelectTaskType

  // Rule Metrics Tab
  AdminRuleMetrics
  RuleMetricsTitle
  RuleMetricsDescription
  RuleMetricsHelp
  RuleMetricsFrom
  RuleMetricsTo
  RuleMetricsRefresh
  RuleMetricsQuickRange
  RuleMetrics7Days
  RuleMetrics30Days
  RuleMetrics90Days
  RuleMetricsSelectRange
  RuleMetricsNoData
  RuleMetricsRuleCount
  RuleMetricsEvaluated
  RuleMetricsNoRules
  ViewDetails
  OpenTask
  AgeLabel
  ParentCardLabel
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

  // Story 4.12 - Card selector for new task
  NoCard
  NewTaskInCard(card_title: String)

  // Story 4.4 - Three-panel layout
  // Accessibility labels
  MainNavigation
  MyActivity

  // Left panel sections
  Work
  NewCard
  Configuration
  Team
  // Note: Capabilities is already defined in the Capabilities section above
  // Story 4.9: New config nav items
  CardsConfig
  TaskTypes
  Templates
  Rules
  // Story 4.9: Cards config filters (UX improvements)
  ShowEmptyCards
  ShowCompletedCards
  Organization
  OrgUsers
  Invites

  // Right panel sections
  InProgress
  Resume
  MyCards
  NoTasksClaimed
  NoCardsAssigned
  NoTasksInProgress
  // AC32: Empty state hints with CTAs
  NoTasksClaimedHint
  NoCardsAssignedHint
  NoTasksInProgressHint

  // Story 5.3: Card notes hovers (AC16-AC22)
  NewNotesTooltip
  EditCardTooltip
  DeleteCardTooltip
  ProgressTooltip(completed: Int, in_progress: Int, pending: Int)
  // AC16: Rich tooltip on [!] indicator
  NotesPreviewNewNotes
  NotesPreviewTimeAgo
  NotesPreviewLatest
  // AC21: Tab badge tooltip
  TabBadgeTotalNotes
  TabBadgeNewNotes
  // AC21: Tab labels
  TabTasks
  TabNotes
  // 5.4.1: Task detail modal
  TabDetails
  TabDependencies
  Unassigned
  Assigned
  ClaimTask

  // Error states
  ErrorLoadingTasks

  // Workflows / Rules
  BackToWorkflows
  ResourceTypeTask
  RuleMetricsNoExecutions
  RuleMetricsResults

  // Icon picker
  NoIconsFound
  SearchIconsPlaceholder
}
