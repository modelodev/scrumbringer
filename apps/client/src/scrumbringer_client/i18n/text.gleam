//// I18n text key definitions for Scrumbringer UI.
////
//// Defines all translatable text keys as a variant type. Each key maps to
//// translations in language-specific modules (en.gleam, es.gleam).

pub type Text {
  // App
  AppName

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
  TaskClosed
  TaskDeleted
  SkillsSaved
  NoteAdded

  // Task mutation errors
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
  TaskCreateRequiresCard
  TaskCreateActiveCardLabel
  TaskCreateNoActiveCards
  TaskCreateCardsLoadFailed
  TaskCreateDraftCardTarget
  CardPickerSearchAllCardsHint
  CardPickerRefineSearchHint
  TaskEditCardLabel
  TaskCreateMissingCard
  TaskCreateInactiveCard
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
  Back
  Continue
  Skip
  Create
  SaveDraftCard
  CreateAndActivateCard
  Creating
  CreatingAndActivating
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

  // Member sections
  Pool
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
  Canvas
  List
  Kanban
  CapabilitiesBoard
  People
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
  KanbanColumnPending
  PlanEmptyCardScopeBody
  PlanEmptyScopeTitle
  PlanEmptyScopeBody
  PlanCapabilityList
  PlanCapabilityMatrix
  PlanClosed
  PlanStatusAll
  PlanIncludesClosed
  PoolPurpose
  PoolVisibilityLabel
  PoolVisibilityAllOpen
  PoolVisibilityReadyToClaim
  PoolVisibilityBlocked
  PoolOpenCount
  PoolHealthyLimit
  NewTask
  Description
  Priority
  PriorityHighest
  PriorityLowest
  AllOption
  SelectType
  TypeLabel
  CapabilityLabel
  CapabilityScopeLabel
  ScopeAll
  ScopeMine
  SearchLabel
  SearchPlaceholder
  ClearFilters
  NoAvailableTasksRightNow
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
  HideClosedTasks
  PriorityShort(priority: Int)
  Claim
  ClaimThisTask
  ClaimedBy
  UnknownUser
  PeopleSearchPlaceholder
  PeopleEmpty
  PeopleNoResults
  PeopleLoading
  PeopleLoadError
  PeoplePurpose
  PeopleAttentionLabel
  PeopleFreeLabel
  PeopleBusyLabel
  PeopleWorkingLabel
  PeopleOngoingCount(count: Int)
  PeopleReservedCount(count: Int)
  PeopleBlockedCount(count: Int)
  PeopleCardsCount(count: Int)
  PeopleLoadWarning
  PeopleTrayTitle(person: String)
  PeopleNowSection
  PeopleNowDescription
  PeopleReservedSection
  PeopleReservedDescription
  PeopleNoActiveFocus
  PeopleNoReservedWork
  PeopleNoCardContext
  PeopleColumnPerson
  PeopleColumnWork
  PeopleColumnLoad
  PeopleSectionNeedsAttention
  PeopleSectionWorkingNow
  PeopleSectionReservedWork
  PeopleSectionAvailable
  PeopleWorkingNowState
  PeopleAvailableState
  PeopleNeedsAttentionState
  PeopleNoOwnedWork
  PeopleNextWork(title: String)
  PeopleReservedGroupCount(count: Int)
  PeopleTaskNowMeta(context: String)
  PeopleTaskReservedMeta(context: String)
  PeopleTaskBlockedMeta(context: String)
  PeopleBlockedBy(title: String)
  PeopleOpenDependencies
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
  CapabilityBoardPurpose
  CapabilityBoardCardColumn
  CapabilityBoardLevelColumn
  CapabilityBoardTotal
  CapabilityBoardNoTasks
  CapabilityBoardEmptyCell
  NoCapability
  HierarchyActivationTitle
  HierarchyActivationBody(cards_count: Int, tasks_count: Int)
  HierarchyActivationWarning
  ActivateHierarchy
  HierarchyActivated
  HierarchyActivationPoolImpact(pool_impact: Int)
  HierarchyActivationPoolSaturated(
    pool_open_after: Int,
    healthy_pool_limit: Int,
  )
  HierarchyActivateFailed
  HierarchyMoreActions
  HierarchyMoveTo
  HierarchyScopeSubtitle
  HierarchyScopeDirectTasks
  HierarchyScopeCardTitle
  HierarchyScopeDepthFallback(depth: Int)
  HierarchyScopeEmptyDepthTitle
  HierarchyScopeEmptyDepthBody(name: String)
  OpenIn
  ViewInPlan
  ViewInKanban
  ViewInCapabilities
  ViewInPeople
  ExpandPerson(name: String)
  CollapsePerson(name: String)
  Drag

  // Now working
  NowWorking
  NowWorkingNone
  Pause
  Release
  TaskNumber(task_id: Int)

  // Admin
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
  NotPermitted
  NotPermittedBody

  // Admin sidebar groups (SA01-SA05)
  // Project selector
  ProjectLabel
  AllProjects

  // Metrics (member + org)
  MyMetrics
  LoadingMetrics
  WindowDays(days: Int)
  Claimed
  Released
  Closed
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
  AvgClaimToClose
  AvgTimeInClaimed
  StaleClaims
  LastClaim
  TimeToFirstClaim
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
  Closures
  FirstClaim
  ProjectTasks(project_name: String)

  // Org users
  OpenThisSectionToLoadUsers
  LoadingUsers
  Role
  Actions
  User
  UserNumber(user_id: Int)
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
  UserProjectsEmpty
  UserProjectsAdd
  SelectProject

  // Org Users main table
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
  ProjectCreateStepLabel(current: Int, total: Int)
  ProjectCreateGeneralTitle
  ProjectCreateGeneralHint
  ProjectCreateCapabilitiesTitle
  ProjectCreateCapabilitiesHint
  ProjectCreateTeamTitle
  ProjectCreateTeamHint
  ProjectCreateReviewTitle
  ProjectCreateReviewHint
  ProjectCreateReviewSkipped
  ProjectStructureCreateHint
  ProjectStructureEditHint
  ProjectMaximumDepth
  ProjectPoolSoftLimit
  ProjectStructureExamples
  ProjectPoolSoftLimitHint
  ProjectDepthLevel(depth: Int)
  ProjectDepthLevelRole(depth: Int, max_depth: Int)
  ProjectDepthOrientationHelp
  ProjectDepthTasksEndpoint
  ProjectDepthLevelSingularName(depth: Int)
  ProjectDepthLevelPluralName(depth: Int)
  ProjectDepthReductionHidden
  ProjectDepthReductionNeedsReview(new_max_depth: Int)
  ProjectDepthReductionReviewCards
  ProjectDepthReductionLoading(new_max_depth: Int)
  ProjectDepthReductionBlocked(cards_count: Int, claimed_tasks_count: Int)
  ProjectDepthReductionReady(cards_count: Int, available_tasks_count: Int)
  ProjectDepthReductionAffectedCards
  ProjectDepthReductionConfirm
  ProjectDepthReductionConfirmed(new_max_depth: Int)
  ProjectPoolSoftLimitPositive
  ProjectMaximumDepthPositive
  ProjectAddLevelNamesBeforeIncreasingDepth
  ProjectReviewAffectedCardsBeforeLoweringDepth
  ProjectDepthNamesRequired

  // Contextual hints (Story 4.9 AC21-22)
  TemplatesHintRules

  IdentitySection
  Icon
  OptionalFields
  SelectIcon
  UnknownIcon
  TaskTypeNameHint
  NoTaskTypesYet
  CreateFirstTaskTypeHint
  TaskTypesExplain
  TitleTooLongMax56
  NameAndIconRequired
  PriorityMustBe1To5

  // Popover labels
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
  CardCreated
  CardUpdated
  CardDeleted
  CardDeleteBlocked
  CardDeleteConfirm(card_title: String)
  NoCardsYet
  KanbanEmptyDraft
  KanbanEmptyActive
  KanbanEmptyClosed
  KanbanSurfacePurpose
  KanbanSummaryCards

  // Automations
  AdminAutomations
  AutomationEnginesProjectTitle(project_name: String)
  SelectProjectForAutomations
  AutomationEngineName
  AutomationEngineDescription
  AutomationEngineRules
  AutomationEngineActive
  AutomationEngineCreated
  AutomationEngineUpdated
  CreateAutomationEngine
  EditAutomationEngine
  DeleteAutomationEngine
  AutomationEngineDeleteConfirm(engine_name: String)
  NoAutomationEnginesYet
  AutomationEngineDeleted
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
  RulesTitle(engine_name: String)
  RuleName
  RuleGoal
  RuleTaskType
  RuleActive
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
  RuleBuilderTaskClosedEvent
  RuleBuilderTaskClaimedEvent
  RuleBuilderTaskReleasedEvent
  RuleBuilderCardActivatedEvent
  RuleBuilderCardClosedEvent
  RuleBuilderPreview
  RulePreviewTaskCreated(subject: String)
  RulePreviewTaskClaimed(subject: String)
  RulePreviewTaskReleased(subject: String)
  RulePreviewTaskClosed(subject: String)
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
  RuleTriggerTaskClaimedWord
  RuleTriggerTaskClosedWord
  RuleTriggerTaskCreatedWord
  RuleTriggerTaskReleasedWord
  RulePreviewTemplateWillCreate(template_name: String)
  RulePreviewChooseTemplate
  RulePreviewCardActivationNoiseWarning
  RuleBuilderTemplateVariablesUnavailable(variables: String)
  RuleBuilderCardScopeUnavailable(depth: Int)

  ExpandRule
  CollapseRule
  AttachedTemplates
  AttachTemplateHint

  // Task States (for Rules)
  TaskStateAvailable
  TaskStateClaimed
  TaskStateOngoing
  TaskStateClosed
  TaskStateAvailableHint
  TaskStateClaimedHint
  TaskStateOngoingHint
  TaskStateClosedHint
  TaskHeadlineAvailable
  TaskHeadlineClaimedByYou
  TaskHeadlineClaimedByOther
  TaskHeadlineClaimed
  TaskHeadlineOngoingByYou
  TaskHeadlineOngoingByOther
  TaskHeadlineOngoing
  TaskHeadlineClosed
  TaskNextActionLabel
  TaskNextActionClaim
  TaskNextActionStart
  TaskNextActionPause
  TaskNextActionClose
  TaskNextActionRelease
  TaskNextActionOpen

  // Task Templates
  AdminTaskTemplates
  TaskTemplatesTitle
  TaskTemplatesProjectTitle(project_name: String)
  AutomationTemplatesDescription
  AutomationTemplatesSearchPlaceholder
  TaskTemplateName
  TaskTemplateDescription
  TaskTemplateType
  TaskTemplatePriority
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
  TaskTemplateEditFutureTasksWarning
  TaskTemplateVariablesHelp
  TaskTemplateDescriptionHint
  AvailableVariables
  TaskTemplateInsertVariable(variable: String)
  SelectTaskType

  // Rule Metrics Tab
  AdminRuleMetrics
  RuleMetricsDescription
  RuleMetricsHelp
  RuleMetricsFrom
  RuleMetricsTo
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
  CardProgressCount(closed: Int, total: Int)

  // Card detail (member)
  CardAddTask
  CardAddSubcard
  CloseCard
  CloseCardManagerOnly
  CloseCardConfirmTitle
  CloseCardConfirmBody
  CardClosed
  CardCloseFailed
  CardReadyToCloseTitle
  CardReadyToCloseBody
  CardEmptyWorkTitle
  CardEmptyWorkBody
  CardSummaryNoWorkTitle
  CardSummaryNoWorkBody
  CardSummaryBlockedTitle(count: Int)
  CardSummaryBlockedBody
  CardSummaryCompleteTitle
  CardSummaryCompleteBody
  CardSummaryFlowTitle
  CardSummaryFlowBody
  CardSummaryNoDescription
  CardTasksEmpty
  CardTasksClosed
  TaskType

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
  NoTasksYet
  CardTasksMore(hidden_count: Int)
  Configuration
  Team
  // Note: Capabilities is already defined in the Capabilities section above
  // Story 4.9: New config nav items
  CardsConfig
  TaskTypes
  // Story 4.9: Cards config filters (UX improvements)
  ShowEmptyCards
  ShowClosedCards
  Organization
  OrgUsers
  Invites

  // Right panel sections
  InProgress
  Resume
  MyCards
  // AC32: Empty state hints with CTAs
  NoTasksClaimedHint
  NoCardsAssignedHint
  NoTasksInProgressHint

  // Story 5.3: Card notes hovers (AC16-AC22)
  NewNotesTooltip
  EditCardTooltip
  DeleteCardTooltip
  // AC16: Rich tooltip on [!] indicator
  // AC21: Tab badge tooltip
  // AC21: Tab labels
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
  TabBlockers
  EditTask
  TaskUpdated
  TaskEditPlanning
  TaskEditLocation
  TaskEditKeyboardHint
  TaskEditRequiresClaim
  TaskEditClosedReadOnly
  TaskDescriptionEmpty
  TaskOperationalSummary
  TaskOwner
  TaskAutomationOrigin
  TaskAutomationCreatedBy
  TaskAutomationEngineLabel(engine_id: Int)
  TaskAutomationRuleLabel(rule_id: Int)
  TaskAutomationRuleChip(rule_id: Int)
  TaskAutomationRuleSignal(rule_id: Int)
  TaskAutomationTemplateLabel(template_id: Int)
  TaskAutomationTemplateFallback
  TaskAutomationGoToAutomation
  TaskAutomationViewEngine
  TaskAutomationViewRule
  TaskAutomationViewTemplate
  TaskDueDateLabel
  NoDueDate
  TaskBlockingClear
  MetricsAvailable
  MetricsClaimed
  MetricsOngoing
  ClaimTask

  // Error states
  ErrorLoadingTasks

  // Automations / Rules
  BackToAutomations
  RuleMetricsNoExecutions
  // Icon picker
}
