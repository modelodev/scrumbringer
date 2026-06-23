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
  CapabilityUpdated
  InviteLinkCreated
  InviteLinkRegenerated
  InviteLinkInvalidated
  RoleUpdated
  CannotDemoteLastManager
  MemberAdded
  MemberRemoved
  TaskTypeCreated
  TaskCreated
  TaskCreatedNotVisibleByFilters
  TaskClaimed
  TaskReleased
  TaskDone
  TaskDeleted
  SkillsSaved
  NoteAdded

  // Task mutation errors
  TaskClaimFailed
  TaskReleaseFailed
  TaskCompleteFailed
  TaskVersionConflict
  TaskAlreadyClaimed
  TaskBlockedByDependencies
  TaskHasOperationalHistory
  TaskNotFound
  TaskMutationRolledBack

  // Validation
  NameRequired
  ScopeRequired
  TitleRequired
  TypeRequired
  SelectProjectFirst
  SelectUserFirst
  InvalidXY
  ContentRequired
  TaskCreateCardHasChildCards
  TaskCreateParentCardConflict
  TaskCreateRootPoolHint
  TaskCreateMissingCard
  TaskCreateDraftCardHint
  TaskCreateActiveCardHint
  TaskCreateClosedCard
  CardClosedCannotReceiveChildren
  CardHasOperationalHistory
  ActivateHierarchyManagerOnly

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
  PinNote
  UnpinNote
  CannotPinNote
  Deleting
  Deleted
  NoneOption
  Start
  LoggingIn
  Loading
  LoadingEllipsis
  Retry

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
  PinnedContext
  OpenNotes
  MorePinnedNotes(count: Int)
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
  TaskOverdue(due_date: String)
  TaskDueToday
  TaskDueSoon(due_date: String)
  EditPosition
  XLabel
  YLabel

  // Member pool controls
  ViewCanvas
  ViewList
  Canvas
  List
  Kanban
  CapabilitiesBoard
  People
  Hierarchies
  Tracking
  WorkSurfaceView
  PlanScope
  PlanScopeProject
  PlanScopeLevel
  PlanScopeCard
  PlanScopeAllLevels
  PlanScopeSelectCard
  PlanScopeNoActiveCards
  PlanMode
  PlanModeStructure
  PlanModeKanban
  KanbanColumnPending
  PlanEmptyCardScopeBody
  PlanEmptyScopeTitle
  PlanEmptyScopeBody
  PlanCapabilityMode
  PlanCapabilityList
  PlanCapabilityMatrix
  PlanClosed
  PoolPurpose
  PoolVisibilityLabel
  PoolVisibilityAllOpen
  PoolVisibilityReadyToClaim
  PoolVisibilityBlocked
  PoolOpenCount
  PoolReadyCount
  PoolBlockedCount
  PoolHealthyLimit
  NewTask
  Description
  Priority
  PriorityHighest
  PriorityLowest
  NewTaskShortcut
  AllOption
  SelectType
  TypeLabel
  CapabilityLabel
  MyCapabilitiesLabel
  MyCapabilitiesHint
  MyCapabilitiesOn
  MyCapabilitiesOff
  ScopeAll
  ScopeMine
  SearchLabel
  SearchPlaceholder
  ClearFilters
  ActiveFilters(count: Int)
  NoAvailableTasksRightNow
  CreateFirstTaskToStartUsingPool
  NoTasksMatchYourFilters
  NoOpenPoolTasks
  NoOpenPoolTasksBody
  NoClaimablePoolTasks
  NoClaimablePoolTasksBlockedBody(count: Int)
  NoClaimablePoolTasksBody
  NoBlockedPoolTasks
  NoBlockedPoolTasksBody
  ViewBlockedTasks
  ViewOpenTasks
  HideDoneTasks
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
  PeoplePurpose
  PeopleFreeLabel
  PeopleBusyLabel
  PeopleWorkingLabel
  PeopleClaimedLabel
  PeopleFreeCount(count: Int)
  PeopleBusyCount(count: Int)
  PeopleWorkingCount(count: Int)
  PeopleClaimedTotal(count: Int)
  PeopleOngoingCount(count: Int)
  PeopleClaimedCount(count: Int)
  PeopleCardsCount(count: Int)
  PeopleLoadWarning
  PeopleAvailableCapacity
  PeopleNoClaimedTasks
  PeopleNoCardContext
  PeopleShowLabel
  PeopleFilterEveryone
  PeopleFilterWithWork
  PeopleFilterAttention
  PeopleFilterFree
  PeopleSortLabel
  PeopleSortAttention
  PeopleSortName
  PeopleSortClaimed
  PeopleCardScopeNoWork
  CapabilityBoardLoading
  CapabilityBoardEmpty
  CapabilityBoardNoResults
  CapabilityBoardLoadError
  CapabilityBoardEmptyPending
  CapabilityBoardEmptyClaimed
  CapabilityBoardEmptyOngoing
  CapabilityBoardPurpose
  CapabilityBoardCardColumn
  CapabilityBoardLevelColumn
  CapabilityBoardTotal
  CapabilityBoardComplete
  CapabilityBoardNoTasks
  CapabilityBoardEmptyCell
  CapabilityBoardOldest
  CapabilityBoardPressureBlocked
  CapabilityBoardPressureNoTraction
  CapabilityBoardPressureFlowing
  NoCapability
  HierarchiesEmpty
  HierarchiesNoResults
  HierarchiesLoadError
  HierarchiesPurpose
  CreateHierarchy
  CreateFirstHierarchy
  HierarchyCreated
  HierarchyCreateFailed
  ShowDoneHierarchies
  ShowEmptyHierarchies
  HierarchiesActive
  HierarchiesDone
  HierarchyStateReady
  HierarchyStateActive
  HierarchyStateDone
  HierarchyEmptyHint
  HierarchyDone
  HierarchyActivationTitle
  HierarchyActivationBody(cards_count: Int, tasks_count: Int)
  HierarchyActivationWarning
  HierarchyDetails
  HierarchyTabOverview
  HierarchyTabContent
  HierarchyTabPlanning
  ActivateHierarchy
  ActivatingHierarchy
  HierarchyActivated
  HierarchyActivationPoolImpact(pool_impact: Int)
  HierarchyActivationPoolSaturated(
    pool_open_after: Int,
    healthy_pool_limit: Int,
  )
  HierarchyActivateFailed
  EditHierarchy
  DeleteHierarchy
  DeleteHierarchyTitle
  DeleteHierarchyConfirm(name: String)
  HierarchyUpdated
  HierarchyUpdateFailed
  HierarchyDeleted
  HierarchyDeleteFailed
  HierarchyDeleteNotAllowed
  HierarchyAlreadyActive
  HierarchyActivationIrreversible
  HierarchyOpenDetails
  HierarchyMoreActions
  HierarchyMoveTo
  HierarchyCardsLabel
  HierarchyTasksLabel
  HierarchyCardsProgress(completed: Int, total: Int)
  HierarchyTasksProgress(completed: Int, total: Int)
  HierarchyStructureSummary
  HierarchyActions
  HierarchySearchPlaceholder
  HierarchyLooseTasksNotice
  HierarchyLooseTasksHint
  HierarchyCardTasksEmpty
  HierarchyCardTasksRegion(name: String)
  HierarchyNoSelection
  HierarchyNoSelectionHint
  HierarchyCardsCount(cards_count: Int)
  HierarchyLooseTasksCount(tasks_count: Int)
  HierarchyBlockedTasksCount(tasks_count: Int)
  HierarchyEmptyCardsCount(cards_count: Int)
  HierarchyCardsWithoutProgressCount(cards_count: Int)
  HierarchyStructureComplete
  HierarchyLooseTasksDiagnostic(tasks_count: Int)
  HierarchyBlockedTasksDiagnostic(tasks_count: Int)
  HierarchyEmptyCardsDiagnostic(cards_count: Int)
  HierarchyCardsWithoutProgressDiagnostic(cards_count: Int)
  HierarchyCardEmpty
  HierarchyCardNoProgress
  HierarchyCardBlocked
  HierarchyCardComplete
  OpenIn
  ViewInPlan
  ViewInKanban
  ViewInCapabilities
  ViewInPeople
  HierarchyTotalTasksCount(tasks_count: Int)
  HierarchyTaskPhaseAvailable
  HierarchyTaskPhaseClaimed
  HierarchyTaskPhaseDone
  ExpandHierarchyCard(name: String)
  CollapseHierarchyCard(name: String)
  ExpandHierarchy(name: String)
  CollapseHierarchy(name: String)
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
  AdminApiTokens
  Integration
  IntegrationIdentity
  IntegrationIdentityHint
  ApiTokenGrantsImmutable
  RenameApiToken
  Integrations
  NoIntegrationUsersYet
  ActiveTokenCount
  DeactivateIntegration
  DeactivateIntegrationConfirm
  IntegrationRequired
  ApiTokens
  CreateApiToken
  ApiTokenCreatedSecretNotice
  ApiTokenSecret
  NoApiTokensYet
  FailedToLoadPrefix
  Project
  Scopes
  PermissionRead
  PermissionWrite
  ResourceProjects
  ResourceTasks
  ResourceCards
  ResourceNotes
  LastUsed
  ExpiresAtOptional
  Revoke
  Revoked
  Expired
  Active
  RevokeApiToken
  RevokeApiTokenConfirm
  TeamByProject
  TeamByPerson
  TeamSearchPlaceholder
  TeamNoProjectsTitle
  TeamNoProjectsBody
  TeamNoPeopleTitle
  TeamNoPeopleBody
  TeamNoPeopleBadge
  TeamNoProjectsBadge
  TeamPeopleCount(count: Int)
  TeamProjectsCount(count: Int)
  TeamLoadingMembers
  TeamLoadingProjects
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
  Done
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
  Selected
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
  InvalidateInvite
  InvalidateInviteConfirm(email: String)
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
  EditCapability
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
  DeleteOwnUserBlocked
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

  // Project structure and Pool settings
  ProjectStructureAndPool
  ProjectStructureCreateHint
  ProjectStructureEditHint
  ProjectMaximumDepth
  ProjectPoolSoftLimit
  ProjectStructureExamples
  ProjectPoolSoftLimitHint
  ProjectDepthLevel(depth: Int)
  ProjectDepthLevelSingularName(depth: Int)
  ProjectDepthLevelPluralName(depth: Int)
  ProjectDepthReductionHidden
  ProjectDepthReductionNeedsReview(new_max_depth: Int)
  ProjectDepthReductionReviewCards
  ProjectDepthReductionLoading(new_max_depth: Int)
  ProjectDepthReductionBlocked(cards_count: Int, claimed_tasks_count: Int)
  ProjectDepthReductionReady(cards_count: Int, available_tasks_count: Int)
  ProjectDepthReductionConfirm
  ProjectDepthReductionConfirmed(new_max_depth: Int)

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

  // Cards
  AdminCards
  CardsTitle(project_name: String)
  SelectProjectToManageCards
  CreateCard
  EditCard
  DeleteCard
  CardTitle
  CardDescription
  CardPhase
  CardPhaseDraft
  CardPhaseActive
  CardPhaseClosed
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
  KanbanEmptyDraft
  KanbanEmptyActive
  KanbanEmptyClosed
  KanbanSurfacePurpose
  KanbanSummaryCards
  KanbanSummaryOngoing

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
  AutomationEnginesDescription
  AutomationEnginesSearchPlaceholder
  AutomationEngineStatus
  AutomationEngineStatusAll
  AutomationEngineStatusActive
  AutomationEngineStatusPaused
  AutomationConsolePurpose
  AutomationSummaryActiveEngines
  AutomationSummaryRules
  AutomationSummaryTemplates
  AutomationSummaryCreatedTasks
  AutomationModeAriaLabel
  AutomationModeEngines
  AutomationModeTemplates
  AutomationModeExecutions
  AutomationSelectedEngine(id: Int)
  AutomationSelectedRule(id: Int)
  AutomationSelectedRuleInEngine(rule_id: Int, engine_id: Int)
  AutomationSelectedTemplate(id: Int)
  AutomationSelectedExecution(id: Int)

  // Rules
  RulesTitle(workflow_name: String)
  RuleName
  RuleGoal
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
  RuleMetricsApplied
  RuleMetricsSuppressed
  RuleTemplateSearchPlaceholder
  RuleTemplateNoSearchResults
  RuleBuilderNewRule
  RuleBuilderEditRule
  RuleBuilderSaveRule
  RuleBuilderWhen
  RuleBuilderEvent
  RuleBuilderCreateTaskFrom
  RuleBuilderCardScope
  RuleBuilderAnyCard
  RuleBuilderCardsAtLevel(level_name: String)
  RuleBuilderSubject
  RuleBuilderTask
  RuleBuilderCard
  RuleBuilderAnyTaskType
  RuleBuilderTaskTemplate
  RuleBuilderChooseTemplate
  RuleBuilderTaskCreatedEvent
  RuleBuilderTaskCompletedEvent
  RuleBuilderTaskClaimedEvent
  RuleBuilderTaskReleasedEvent
  RuleBuilderCardActivatedEvent
  RuleBuilderCardClosedEvent
  RuleBuilderPreview
  RulePreviewTaskCreated(subject: String)
  RulePreviewTaskClaimed(subject: String)
  RulePreviewTaskReleased(subject: String)
  RulePreviewTaskCompleted(subject: String)
  RulePreviewCardActivated(scope: String)
  RulePreviewCardClosed(scope: String)
  RulePreviewRequiresReview
  RulePreviewAnyCard
  RulePreviewCardLevel(level_name: String)
  RulePreviewFallbackCardLevel(depth: Int)
  RulePreviewSelectedCardLevel
  RulePreviewAnyTask
  RulePreviewTaskType(task_type_name: String)
  RulePreviewSelectedTaskType
  RulePreviewTemplateWillCreate(template_name: String)
  RulePreviewChooseTemplate
  RulePreviewCardActivationNoiseWarning

  ExpandRule
  CollapseRule
  AttachedTemplates
  NoTemplatesWontCreateTasks
  AttachTemplateHint

  // Task States (for Rules)
  TaskStateAvailable
  TaskStateClaimed
  TaskStateOngoing
  TaskStateDone
  TaskStateAvailableHint
  TaskStateClaimedHint
  TaskStateOngoingHint
  TaskStateDoneHint
  TaskNextActionLabel
  TaskNextActionClaim
  TaskNextActionStart
  TaskNextActionPause
  TaskNextActionComplete
  TaskNextActionRelease
  TaskNextActionOpen

  // Task Templates
  AdminTaskTemplates
  TaskTemplatesTitle
  TaskTemplatesOrgTitle
  TaskTemplatesProjectTitle(project_name: String)
  AutomationTemplatesDescription
  AutomationTemplatesSearchPlaceholder
  TaskTemplateName
  TaskTemplateDescription
  TaskTemplateType
  TaskTemplatePriority
  TaskTemplateScope
  TaskTemplateUsages
  TaskTemplateUnused
  TaskTemplateCreatedTasks
  TaskTemplateLastExecution
  TaskTemplateNeverExecuted
  TaskTemplateCreated
  TaskTemplateUpdated
  CreateTaskTemplate
  EditTaskTemplate
  DeleteTaskTemplate
  NoTaskTemplatesYet
  TaskTemplateDeleted
  TaskTemplateDeleteConfirm(template_name: String)
  TaskTemplateDeleteRulesWarning
  TaskTemplateVariablesHelp
  TaskTemplateDescriptionHint
  AvailableVariables
  TaskTemplateInsertVariable(variable: String)
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
  OpenCard
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
  ProjectExecutionsSelectProject
  ProjectExecutionsDiagnostics
  ProjectExecutionsDateColumn
  ProjectExecutionsEngineColumn
  ProjectExecutionsRuleColumn
  ProjectExecutionsTemplateColumn
  ProjectExecutionsOriginColumn
  ProjectExecutionsOutcomeColumn
  ProjectExecutionsTaskColumn
  FirstPage
  PreviousPage
  NextPage
  LastPage
  Origin
  Outcome
  Timestamp
  OutcomeApplied
  OutcomeSuppressed

  // Story 3.4 - Member Card Views
  // Member Cards section
  MemberCards
  MemberCardsEmpty
  MemberCardsEmptyHint

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
  CardAddSubcard
  CardEmptyWorkTitle
  CardEmptyWorkBody
  CardTasksEmpty
  CardTasksDone
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
  QuickCard
  QuickTask
  NoTasksYet
  CardTasksMore(hidden_count: Int)
  NewCardInThisHierarchy
  HierarchyTarget
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
  ShowDoneCards
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
  TabSummary
  TabWork
  TabActivity
  ActivityLoading
  ActivityEmpty
  ActivityLoadFailed
  ActivityLoadMore(remaining: Int)
  // 5.4.1: Task Show
  TabDetails
  TabDependencies
  TabBlockers
  EditTask
  TaskUpdated
  TaskEditPlanning
  TaskEditLocation
  TaskEditKeyboardHint
  TaskEditRequiresClaim
  TaskEditDoneReadOnly
  HierarchyLabel
  NoHierarchy
  TaskHierarchyInheritedFromCard
  TaskDescriptionEmpty
  TaskOperationalSummary
  TaskOwner
  TaskAutomationOrigin
  TaskAutomationCreatedBy
  TaskAutomationEngineLabel(engine_id: Int)
  TaskAutomationExecutionLabel(execution_id: Int)
  TaskAutomationRuleLabel(rule_id: Int)
  TaskAutomationRuleChip(rule_id: Int)
  TaskAutomationRuleSignal(rule_id: Int)
  TaskAutomationTemplateLabel(template_id: Int)
  TaskAutomationTemplateFallback
  TaskAutomationViewEngine
  TaskAutomationViewRule
  TaskAutomationViewTemplate
  TaskDueDateLabel
  NoDueDate
  TaskBlockingClear
  MetricsTasksTotal
  MetricsTasksDone
  MetricsProgress
  MetricsRebotesAvg
  MetricsPoolLifetimeAvg
  MetricsAvailable
  MetricsClaimed
  MetricsOngoing
  MetricsExecutors
  MetricsTotal
  MetricsClaimCount
  MetricsReleaseCount
  MetricsUniqueExecutors
  MetricsFirstClaimAt
  MetricsCurrentStateTime
  MetricsPoolLifetime
  MetricsSessionCount
  MetricsTotalWorkTime
  MetricsAvgExecutors
  MetricsWorkflows
  MetricsMostActivated
  MetricsNotAvailable
  MetricsEmptyState
  MetricsLoadError
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
