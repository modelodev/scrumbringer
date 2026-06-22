//// English translations for Scrumbringer UI.
////
//// Provides English (en) translations for all UI text keys defined in text.gleam.

import gleam/int

import scrumbringer_client/i18n/text.{type Text}

/// Provides translate.
///
/// Example:
///   translate(...)
pub fn translate(text: Text) -> String {
  case text {
    // App
    text.AppName -> "ScrumBringer"
    text.AppSectionTitle -> "App"

    // Auth
    text.LoginTitle -> "Login"
    text.LoginSubtitle -> "Login to access the admin UI."
    text.NoEmailIntegrationNote ->
      "No email integration in MVP. This generates a reset link you can copy/paste."
    text.EmailLabel -> "Email"
    text.EmailPlaceholderExample -> "user@company.com"
    text.PasswordLabel -> "Password"
    text.NewPasswordLabel -> "New password"
    text.MinimumPasswordLength -> "Minimum 12 characters"
    text.Logout -> "Logout"

    text.AcceptInviteTitle -> "Accept invite"
    text.ResetPasswordTitle -> "Reset password"
    text.MissingInviteToken -> "Missing invite token"
    text.ValidatingInvite -> "Validating invite…"
    text.SignedIn -> "Signed in"
    text.MissingResetToken -> "Missing reset token"
    text.ValidatingResetToken -> "Validating reset token…"
    text.PasswordUpdated -> "Password updated"
    text.Welcome -> "Welcome"
    text.LoggedIn -> "Logged in"
    text.InvalidCredentials -> "Invalid credentials"
    text.EmailAndPasswordRequired -> "Email and password required"
    text.EmailRequired -> "Email is required"
    text.LogoutFailed -> "Logout failed"

    // Toasts / messages
    text.LoggedOut -> "Logged out"
    text.ProjectCreated -> "Project created"
    text.CapabilityCreated -> "Capability created"
    text.CapabilityDeleted -> "Capability deleted"
    text.CapabilityUpdated -> "Capability updated"
    text.InviteLinkCreated -> "Invite link created"
    text.InviteLinkRegenerated -> "Invite link regenerated"
    text.InviteLinkInvalidated -> "Invite link invalidated"
    text.RoleUpdated -> "Role updated"
    text.CannotDemoteLastManager -> "Cannot demote the last project manager"
    text.MemberAdded -> "Member added"
    text.MemberRemoved -> "Member removed"
    text.TaskTypeCreated -> "Task type created"
    text.TaskCreated -> "Task created"
    text.TaskCreatedNotVisibleByFilters ->
      "Task created, but not visible with current filters"
    text.TaskClaimed -> "Task claimed"
    text.TaskReleased -> "Task released"
    text.TaskDone -> "Task completed"
    text.TaskDeleted -> "Task deleted"
    text.SkillsSaved -> "Skills saved"
    text.NoteAdded -> "Note added"

    // Task mutation errors
    text.TaskClaimFailed -> "Could not claim task"
    text.TaskReleaseFailed -> "Could not release task"
    text.TaskCompleteFailed -> "Could not complete task"
    text.TaskVersionConflict -> "Task was modified. Please refresh."
    text.TaskAlreadyClaimed -> "Task is already claimed by someone else"
    text.TaskBlockedByDependencies -> "Task has incomplete dependencies"
    text.TaskHasOperationalHistory ->
      "This task has operational history. Close it instead of deleting it."
    text.TaskNotFound -> "Task not found"
    text.TaskMutationRolledBack -> "Action rolled back"

    // Validation
    text.NameRequired -> "Name is required"
    text.ScopeRequired -> "Select at least one scope"
    text.TitleRequired -> "Title is required"
    text.TypeRequired -> "Type is required"
    text.SelectProjectFirst -> "Select a project first"
    text.SelectUserFirst -> "Select a user first"
    text.InvalidXY -> "Invalid x/y"
    text.ContentRequired -> "Content required"
    text.TaskCreateCardHasChildCards ->
      "This card already contains child cards. Add the task to a task group or choose an empty card."
    text.TaskCreateParentCardConflict ->
      "Choose one task location only. A task can belong to a card or the Root Pool, not both."
    text.TaskCreateRootPoolHint ->
      "Root Pool task. Requires manage flow; it will be available in the Pool and will not be auto-claimed."
    text.TaskCreateMissingCard ->
      "Selected card is not available. Close this dialog and try again."
    text.TaskCreateDraftCardHint ->
      "This task will not be auto-claimed. It will stay prepared until this card is activated."
    text.TaskCreateActiveCardHint ->
      "This task will enter the Pool when created and be available for someone with the matching capability. It will not be auto-claimed."
    text.TaskCreateClosedCard -> "Closed cards cannot receive new tasks."
    text.CardClosedCannotReceiveChildren ->
      "Closed cards cannot receive new child cards or tasks."
    text.CardHasOperationalHistory ->
      "This card has operational history. Close it instead of deleting it."
    text.ActivateHierarchyManagerOnly ->
      "Only project managers can activate a card hierarchy."

    text.Copied -> "Copied"
    text.Copying -> "Copying…"
    text.CopyFailed -> "Copy failed"

    // Accessibility
    text.SkipToContent -> "Skip to content"

    // Common
    text.Dismiss -> "Dismiss"
    text.Cancel -> "Cancel"
    text.Close -> "Close"
    text.Create -> "Create"
    text.Creating -> "Creating…"
    text.Copy -> "Copy"
    text.Save -> "Save"
    text.Saved -> "Saved"
    text.SaveNewPassword -> "Save new password"
    text.Saving -> "Saving…"
    text.Register -> "Register"
    text.Registering -> "Registering…"
    text.Working -> "Working…"
    text.GenerateResetLink -> "Generate reset link"
    text.ForgotPassword -> "Forgot password?"
    text.ResetLink -> "Reset link"
    text.CreateInviteLink -> "Create invite link"
    text.Add -> "Add"
    text.Adding -> "Adding…"
    text.Removing -> "Removing…"
    text.Delete -> "Delete"
    text.DeleteAsAdmin -> "Delete (as admin)"
    text.PinNote -> "Pin note"
    text.UnpinNote -> "Unpin note"
    text.CannotPinNote -> "Only the author or a manager can pin this note"
    text.Deleting -> "Deleting…"
    text.Deleted -> "Deleted"
    text.NoneOption -> "None"
    text.Start -> "Start"
    text.LoggingIn -> "Logging in…"
    text.Loading -> "Loading"
    text.LoadingEllipsis -> "Loading…"
    text.Retry -> "Retry"

    // Settings controls
    text.Preferences -> "Preferences"
    text.ThemeLabel -> "Theme"
    text.ThemeDefault -> "Light"
    text.ThemeDark -> "Dark"
    text.LanguageLabel -> "Language"
    text.LanguageEs -> "Spanish"
    text.LanguageEn -> "English"

    // Member sections
    text.Pool -> "Pool"
    text.MyBar -> "My Bar"
    text.MySkills -> "My Skills"
    text.MySkillsHelp ->
      "Select the capabilities you have. The Pool will highlight matching tasks."
    text.MyTasks -> "My tasks"
    text.NoClaimedTasks ->
      "No tasks in My Tasks yet. Claim work from the Pool first."
    text.GoToPoolToClaimTasks -> "Claim work from the Pool first."
    text.NoProjectsBody -> "Ask an admin to add you to a project."
    text.You -> "You"
    text.Notes -> "Notes"
    text.AddNote -> "Add note"
    text.NotePlaceholder -> "Write a note..."
    text.RecentNotes -> "Recent notes"
    text.PinnedContext -> "Pinned context"
    text.OpenNotes -> "Open notes"
    text.MorePinnedNotes(count) -> "+" <> int.to_string(count) <> " in notes"
    text.Dependencies -> "Dependencies"
    text.AddDependency -> "Add dependency"
    text.NoDependencies -> "No dependencies"
    text.TaskDependenciesHint ->
      "Use dependencies to block this task until other work is finished."
    text.TaskDependenciesEmptyHint ->
      "Add a dependency to reflect the order in which work should happen."
    text.TaskNotesHint ->
      "Capture decisions, context, or progress updates here."
    text.NoNotesYet -> "No notes yet"
    text.TaskNotesEmptyHint ->
      "Add the first note to keep this task aligned and searchable."
    text.NoMatchingTasks -> "No matching tasks"
    text.TaskDependsOn -> "This task depends on"
    text.Blocked -> "Blocked"
    text.BlockedByTasks(count) ->
      "Blocked by " <> int.to_string(count) <> " tasks"
    text.HiddenBlockedByFilters(count) ->
      int.to_string(count) <> " blockers out of view due to filters"
    text.EditPosition -> "Edit position"
    text.XLabel -> "x"
    text.YLabel -> "y"

    // Member pool controls
    text.ViewCanvas -> "View: canvas"
    text.ViewList -> "View: list"
    text.Canvas -> "Canvas"
    text.List -> "List"
    text.Kanban -> "Kanban"
    text.CapabilitiesBoard -> "Capabilities"
    text.People -> "People"
    text.Hierarchies -> "Hierarchies"
    text.Tracking -> "Tracking"
    text.WorkSurfaceView -> "View"
    text.PlanScope -> "Scope"
    text.PlanScopeProject -> "Project"
    text.PlanScopeLevel -> "Level"
    text.PlanScopeCard -> "Card"
    text.PlanScopeAllLevels -> "All levels"
    text.PlanScopeSelectCard -> "Select an active card"
    text.PlanScopeNoActiveCards -> "No active cards"
    text.PlanMode -> "Mode"
    text.PlanModeStructure -> "Structure"
    text.PlanModeKanban -> "Kanban"
    text.PlanEmptyCardScopeBody ->
      "Search for a card to review its subtree, capabilities, tasks, and risk."
    text.PlanEmptyScopeTitle -> "No cards in this scope."
    text.PlanEmptyScopeBody ->
      "Create a card or change the scope to review another part of the plan."
    text.PlanCapabilityMode -> "Mode"
    text.PlanCapabilityList -> "List"
    text.PlanCapabilityMatrix -> "Matrix"
    text.PlanClosed -> "Closed"
    text.PoolPurpose -> "Active tasks available for the team to claim."
    text.PoolVisibilityLabel -> "Show"
    text.PoolVisibilityAllOpen -> "Open"
    text.PoolVisibilityReadyToClaim -> "Claimable"
    text.PoolVisibilityBlocked -> "Blocked"
    text.PoolOpenCount -> "Open"
    text.PoolReadyCount -> "Claimable"
    text.PoolBlockedCount -> "Blocked"
    text.PoolHealthyLimit -> "Healthy limit"
    text.NewTask -> "New task"
    text.Description -> "Description"
    text.Priority -> "Priority"
    text.PriorityHighest -> "highest"
    text.PriorityLowest -> "lowest"
    text.NewTaskShortcut -> "New task (n)"
    text.AllOption -> "All"
    text.SelectType -> "Select type"
    text.MyCapabilitiesOn -> "ON"
    text.MyCapabilitiesOff -> "OFF"
    text.TypeLabel -> "Type"
    text.CapabilityLabel -> "Capability"
    text.MyCapabilitiesLabel -> "My capabilities"
    text.MyCapabilitiesHint -> "Filter tasks matching my capabilities"
    text.ScopeAll -> "All"
    text.ScopeMine -> "Mine"
    text.SearchLabel -> "Search"
    text.SearchPlaceholder -> "q"
    text.ClearFilters -> "Clear"
    text.ActiveFilters(count) ->
      int.to_string(count)
      <> " active filter"
      <> case count {
        1 -> ""
        _ -> "s"
      }
    text.NoAvailableTasksRightNow -> "No available tasks right now"
    text.CreateFirstTaskToStartUsingPool ->
      "Create your first task to start using the Pool."
    text.NoTasksMatchYourFilters -> "No tasks match your filters"
    text.HideDoneTasks -> "Hide completed tasks"
    text.TypeNumber(type_id) -> "Type #" <> int.to_string(type_id)
    text.MetaType -> "type: "
    text.MetaPriority -> "priority: "
    text.MetaCreated -> "created: "
    text.PriorityShort(priority) -> "P" <> int.to_string(priority)
    text.Claim -> "Claim"
    text.ClaimThisTask -> "Claim this task and move it to My Tasks"
    text.ClaimedBy -> "Claimed by"
    text.UnknownUser -> "Unknown user"
    text.Busy -> "Busy"
    text.Free -> "Free"
    text.PeopleSearchPlaceholder -> "Search person"
    text.PeopleEmpty -> "No members in this project"
    text.PeopleNoResults -> "No people match your search"
    text.PeopleLoading -> "Loading people..."
    text.PeopleLoadError -> "Could not load people"
    text.PeoplePurpose -> "Team load by current work and claimed tasks."
    text.PeopleFreeLabel -> "Free"
    text.PeopleBusyLabel -> "Busy"
    text.PeopleWorkingLabel -> "Working"
    text.PeopleClaimedLabel -> "Claimed"
    text.PeopleFreeCount(count) -> int.to_string(count) <> " free"
    text.PeopleBusyCount(count) -> int.to_string(count) <> " busy"
    text.PeopleWorkingCount(count) -> int.to_string(count) <> " working now"
    text.PeopleClaimedTotal(count) -> int.to_string(count) <> " claimed"
    text.PeopleOngoingCount(count) -> int.to_string(count) <> " ongoing"
    text.PeopleClaimedCount(count) -> int.to_string(count) <> " claimed"
    text.PeopleCardsCount(count) -> int.to_string(count) <> " cards"
    text.PeopleLoadWarning -> "High load"
    text.PeopleAvailableCapacity -> "Available capacity"
    text.PeopleNoClaimedTasks -> "No claimed tasks"
    text.PeopleNoCardContext -> "No card"
    text.PeopleShowLabel -> "Show"
    text.PeopleFilterEveryone -> "Everyone"
    text.PeopleFilterWithWork -> "With work"
    text.PeopleFilterAttention -> "Attention"
    text.PeopleFilterFree -> "Free"
    text.PeopleSortLabel -> "Sort"
    text.PeopleSortAttention -> "Attention"
    text.PeopleSortName -> "Name"
    text.PeopleSortClaimed -> "Most claimed"
    text.PeopleCardScopeNoWork -> "No claimed work in this card scope"
    text.CapabilityBoardLoading -> "Loading capabilities..."
    text.CapabilityBoardEmpty -> "No active tasks grouped by capability"
    text.CapabilityBoardNoResults ->
      "No active tasks grouped by capability match the current filters"
    text.CapabilityBoardLoadError -> "Could not load the capability board"
    text.CapabilityBoardEmptyPending -> "No pending tasks"
    text.CapabilityBoardEmptyClaimed -> "No claimed tasks"
    text.CapabilityBoardEmptyOngoing -> "No ongoing tasks"
    text.CapabilityBoardPurpose ->
      "Capacity by card, derived from real descendant tasks."
    text.CapabilityBoardCardColumn -> "Card"
    text.CapabilityBoardLevelColumn -> "Level"
    text.CapabilityBoardTotal -> "Total"
    text.CapabilityBoardComplete -> "complete"
    text.CapabilityBoardNoTasks -> "No active tasks"
    text.CapabilityBoardEmptyCell -> "No tasks"
    text.CapabilityBoardOldest -> "Oldest"
    text.CapabilityBoardPressureBlocked -> "Blocked"
    text.CapabilityBoardPressureNoTraction -> "No traction"
    text.CapabilityBoardPressureFlowing -> "Flowing"
    text.NoCapability -> "No capability"
    text.HierarchiesEmpty -> "No hierarchies yet"
    text.HierarchiesNoResults -> "No hierarchies match current filters"
    text.HierarchiesLoadError -> "Could not load hierarchies"
    text.HierarchiesPurpose ->
      "Delivery structure by objective, loose work, and card progress."
    text.CreateHierarchy -> "Create hierarchy"
    text.CreateFirstHierarchy -> "Create first hierarchy"
    text.HierarchyCreated -> "Hierarchy created"
    text.HierarchyCreateFailed -> "Could not create hierarchy"
    text.ShowDoneHierarchies -> "Show completed"
    text.ShowEmptyHierarchies -> "Show empty"
    text.HierarchiesActive -> "Active"
    text.HierarchiesDone -> "Done"
    text.HierarchyStateReady -> "Ready"
    text.HierarchyStateActive -> "Active"
    text.HierarchyStateDone -> "Done"
    text.HierarchyEmptyHint -> "No work assigned yet"
    text.HierarchyDone -> "Done"
    text.HierarchyActivationTitle -> "Activate hierarchy"
    text.HierarchyActivationBody(cards_count, tasks_count) ->
      "This action is irreversible. It will activate all content in this hierarchy ("
      <> int.to_string(cards_count)
      <> " cards, "
      <> int.to_string(tasks_count)
      <> " tasks)."
    text.HierarchyActivationWarning ->
      "You will not be able to undo this action"
    text.HierarchyDetails -> "Details"
    text.HierarchyTabOverview -> "Overview"
    text.HierarchyTabContent -> "Content"
    text.HierarchyTabPlanning -> "Planning"
    text.ActivateHierarchy -> "Activate"
    text.ActivatingHierarchy -> "Activating..."
    text.HierarchyActivated -> "Hierarchy activated"
    text.HierarchyActivationPoolImpact(pool_impact) ->
      "On activation: +" <> int.to_string(pool_impact) <> " tasks"
    text.HierarchyActivationPoolSaturated(pool_open_after, healthy_pool_limit) ->
      "Pool at "
      <> int.to_string(pool_open_after)
      <> "/"
      <> int.to_string(healthy_pool_limit)
    text.HierarchyActivateFailed -> "Could not activate hierarchy"
    text.EditHierarchy -> "Edit hierarchy"
    text.DeleteHierarchy -> "Delete hierarchy"
    text.DeleteHierarchyTitle -> "Delete hierarchy"
    text.DeleteHierarchyConfirm(name) ->
      "Permanently delete hierarchy \"" <> name <> "\"?"
    text.HierarchyUpdated -> "Hierarchy updated"
    text.HierarchyUpdateFailed -> "Could not update hierarchy"
    text.HierarchyDeleted -> "Hierarchy deleted"
    text.HierarchyDeleteFailed -> "Could not delete hierarchy"
    text.HierarchyDeleteNotAllowed -> "Hierarchy must be ready and empty"
    text.HierarchyAlreadyActive -> "Another hierarchy is already active"
    text.HierarchyActivationIrreversible ->
      "Hierarchy cannot be activated in its current state"
    text.HierarchyOpenDetails -> "Open details"
    text.HierarchyMoreActions -> "More actions"
    text.HierarchyMoveTo -> "Move"
    text.HierarchyCardsLabel -> "Cards"
    text.HierarchyTasksLabel -> "Tasks"
    text.HierarchyCardsProgress(completed, total) ->
      "Cards " <> int.to_string(completed) <> "/" <> int.to_string(total)
    text.HierarchyTasksProgress(completed, total) ->
      "Tasks " <> int.to_string(completed) <> "/" <> int.to_string(total)
    text.HierarchyStructureSummary -> "Structure summary"
    text.HierarchyActions -> "Actions"
    text.HierarchySearchPlaceholder -> "Search hierarchies"
    text.HierarchyLooseTasksNotice -> "Tasks without card"
    text.HierarchyLooseTasksHint ->
      "These tasks are not grouped inside a card yet"
    text.HierarchyCardTasksEmpty -> "This card has no tasks yet"
    text.HierarchyCardTasksRegion(name) -> "Tasks for " <> name
    text.HierarchyNoSelection -> "Select a hierarchy"
    text.HierarchyNoSelectionHint ->
      "Choose a hierarchy from the list to inspect its content"
    text.HierarchyCardsCount(cards_count) ->
      int.to_string(cards_count) <> " cards"
    text.HierarchyLooseTasksCount(tasks_count) ->
      int.to_string(tasks_count) <> " loose tasks"
    text.HierarchyBlockedTasksCount(tasks_count) ->
      int.to_string(tasks_count) <> " blocked tasks"
    text.HierarchyEmptyCardsCount(cards_count) ->
      int.to_string(cards_count) <> " empty cards"
    text.HierarchyCardsWithoutProgressCount(cards_count) ->
      int.to_string(cards_count) <> " cards without progress"
    text.HierarchyStructureComplete -> "Structure complete"
    text.HierarchyLooseTasksDiagnostic(tasks_count) ->
      int.to_string(tasks_count) <> " tasks are not grouped inside cards yet"
    text.HierarchyBlockedTasksDiagnostic(tasks_count) ->
      int.to_string(tasks_count) <> " blocked tasks need attention"
    text.HierarchyEmptyCardsDiagnostic(cards_count) ->
      int.to_string(cards_count) <> " empty cards need content"
    text.HierarchyCardsWithoutProgressDiagnostic(cards_count) ->
      int.to_string(cards_count) <> " cards have not started moving"
    text.HierarchyCardEmpty -> "Empty"
    text.HierarchyCardNoProgress -> "No progress"
    text.HierarchyCardBlocked -> "Blocked"
    text.HierarchyCardComplete -> "Complete"
    text.OpenIn -> "Open in"
    text.ViewInPlan -> "View in Plan"
    text.ViewInKanban -> "View in Kanban"
    text.ViewInCapabilities -> "View in Capabilities"
    text.ViewInPeople -> "View in People"
    text.HierarchyTotalTasksCount(tasks_count) ->
      int.to_string(tasks_count) <> " total tasks"
    text.HierarchyTaskPhaseAvailable -> "available"
    text.HierarchyTaskPhaseClaimed -> "claimed"
    text.HierarchyTaskPhaseDone -> "completed"
    text.ExpandHierarchyCard(name) -> "Show tasks for " <> name
    text.CollapseHierarchyCard(name) -> "Hide tasks for " <> name
    text.ExpandHierarchy(name) -> "Expand hierarchy " <> name
    text.CollapseHierarchy(name) -> "Collapse hierarchy " <> name
    text.ExpandPerson(name) -> "Expand status for " <> name
    text.CollapsePerson(name) -> "Collapse status for " <> name
    text.PeopleActiveSection -> "Active"
    text.PeopleClaimedSection -> "Claimed"
    text.Drag -> "Drag"
    text.StartNowWorking -> "Start working"
    text.PauseNowWorking -> "Pause work"

    // Now working
    text.NowWorking -> "Working now"
    text.NowWorkingLoading -> "Working now: loading…"
    text.NowWorkingNone ->
      "Nothing active. Start a task from My Tasks when you are ready to work."
    text.NowWorkingErrorPrefix -> "Working now error: "
    text.Pause -> "Pause"
    text.Complete -> "Complete"
    text.Release -> "Release"
    text.TaskNumber(task_id) -> "Task #" <> int.to_string(task_id)

    // Admin
    text.Admin -> "Admin"
    text.AdminInvites -> "Invites"
    text.AdminOrgSettings -> "Org Settings"
    text.OrgSettingsHelp ->
      "Manage org roles (admin/member). Changes require an explicit Save and are protected by a last-admin guardrail."
    text.RoleAdmin -> "admin"
    text.RoleMember -> "member"
    text.RoleManager -> "manager"
    text.AdminProjects -> "Projects"
    text.AdminMetrics -> "Metrics"
    text.OrgMetrics -> "Org Metrics"
    text.AdminMembers -> "Members"
    text.AdminCapabilities -> "Capabilities"
    text.AdminTaskTypes -> "Task Types"
    text.AdminApiTokens -> "API tokens"
    text.Integration -> "Integration"
    text.IntegrationIdentity -> "Integration identity"
    text.IntegrationIdentityHint ->
      "Existing names are reused; new names create a technical identity."
    text.ApiTokenGrantsImmutable ->
      "Grants are immutable. Revoke and create a new token to change scopes, project, or expiration."
    text.RenameApiToken -> "Rename API token"
    text.Integrations -> "Integrations"
    text.NoIntegrationUsersYet -> "No integration identities yet"
    text.ActiveTokenCount -> "Active tokens"
    text.DeactivateIntegration -> "Deactivate integration"
    text.DeactivateIntegrationConfirm ->
      "Deactivate this integration identity? It cannot be used for new tokens unless reactivated later."
    text.IntegrationRequired -> "Integration is required"
    text.ApiTokens -> "API tokens"
    text.CreateApiToken -> "Create API token"
    text.ApiTokenCreatedSecretNotice ->
      "Copy this token now. It will not be shown again."
    text.ApiTokenSecret -> "Token"
    text.NoApiTokensYet -> "No API tokens yet"
    text.FailedToLoadPrefix -> "Failed to load: "
    text.Project -> "Project"
    text.Scopes -> "Permissions"
    text.PermissionRead -> "Read"
    text.PermissionWrite -> "Write"
    text.ResourceProjects -> "Projects"
    text.ResourceTasks -> "Tasks"
    text.ResourceCards -> "Cards"
    text.ResourceNotes -> "Notes"
    text.LastUsed -> "Last used"
    text.ExpiresAtOptional -> "Expires at (optional)"
    text.Revoke -> "Revoke"
    text.Revoked -> "Revoked"
    text.Expired -> "Expired"
    text.Active -> "Active"
    text.RevokeApiToken -> "Revoke API token"
    text.RevokeApiTokenConfirm ->
      "Revoke this token? External systems using it will stop working."
    text.TeamByProject -> "By Project"
    text.TeamByPerson -> "By Person"
    text.TeamSearchPlaceholder -> "Search projects or people"
    text.TeamNoProjectsTitle -> "No projects yet"
    text.TeamNoProjectsBody -> "Create a project to start building the team."
    text.TeamNoPeopleTitle -> "No people yet"
    text.TeamNoPeopleBody -> "Invite someone to start adding them to projects."
    text.TeamNoPeopleBadge -> "NO MEMBERS"
    text.TeamNoProjectsBadge -> "NO PROJECTS"
    text.TeamPeopleCount(count) ->
      int.to_string(count)
      <> case count {
        1 -> " person"
        _ -> " people"
      }
    text.TeamProjectsCount(count) ->
      int.to_string(count)
      <> " project"
      <> case count {
        1 -> ""
        _ -> "s"
      }
    text.TeamLoadingMembers -> "Loading members…"
    text.TeamLoadingProjects -> "Loading projects…"
    text.NoAdminPermissions -> "No admin permissions"
    text.NotPermitted -> "Not permitted"
    text.NotPermittedBody -> "You don't have permission to access this section."

    // Admin sidebar groups (SA01-SA05)
    text.NavGroupOrganization -> "Organization"
    text.NavGroupProjects -> "Projects"
    text.NavGroupConfiguration -> "Configuration"
    text.NavGroupContent -> "Content"

    // Project selector
    text.ProjectLabel -> "Project"
    text.AllProjects -> "All projects"
    text.SelectProjectToManageSettings -> "Select a project to manage settings…"
    text.ShowingTasksFromAllProjects -> "Showing tasks from all projects"
    text.SelectProjectToManageMembersOrTaskTypes ->
      "Select a project to manage members or task types"

    // Metrics
    text.MyMetrics -> "My Metrics"
    text.LoadingMetrics -> "Loading metrics…"
    text.WindowDays(days) -> "Window: " <> int.to_string(days) <> " days"
    text.Claimed -> "Claimed"
    text.Released -> "Released"
    text.Done -> "Done"
    text.MetricsOverview -> "Metrics Overview"
    text.LoadingOverview -> "Loading overview…"
    text.ReleasePercent -> "Release %"
    text.FlowPercent -> "Flow %"
    text.AvailableCount -> "Available"
    text.OngoingCount -> "Ongoing"
    text.WipCount -> "WIP"
    text.HealthPanel -> "Flow health"
    text.HealthFlow -> "Flow"
    text.HealthRelease -> "Release rate"
    text.HealthTimeToFirstClaim -> "Time to first claim"
    text.HealthOk -> "OK"
    text.HealthAttention -> "Attention"
    text.HealthAlert -> "Alert"
    text.NoSample -> "No sample"
    text.AvgClaimToComplete -> "Avg claim → complete"
    text.AvgTimeInClaimed -> "Avg time in claimed"
    text.StaleClaims -> "Stale claims"
    text.LastClaim -> "Last claim"
    text.TimeToFirstClaim -> "Time to first claim"
    text.TimeToFirstClaimP50(p50, sample_size) ->
      "P50: " <> p50 <> " (n=" <> int.to_string(sample_size) <> ")"
    text.ReleaseRateDistribution -> "Release rate distribution"
    text.Bucket -> "Bucket"
    text.Count -> "Count"
    text.ByProject -> "By project"
    text.Drill -> "Drill"
    text.View -> "View"
    text.ProjectDrillDown -> "Project drill-down"
    text.SelectProjectToInspectTasks -> "Select a project to inspect tasks."
    text.LoadingTasks -> "Loading tasks…"
    text.Title -> "Title"
    text.Status -> "Status"
    text.Claims -> "Claims"
    text.Releases -> "Releases"
    text.Completes -> "Completes"
    text.FirstClaim -> "First claim"
    text.ProjectTasks(project_name) -> "Project tasks: " <> project_name

    // Org users
    text.OpenThisSectionToLoadUsers -> "Open this section to load users."
    text.LoadingUsers -> "Loading users…"
    text.Role -> "Role"
    text.Actions -> "Actions"
    text.User -> "User"
    text.UserId -> "User ID"
    text.UserNumber(user_id) -> "User #" <> int.to_string(user_id)
    text.Created -> "Created"
    text.SearchByEmail -> "Search by email"
    text.Searching -> "Searching…"
    text.TypeAnEmailToSearch -> "Type an email to search"
    text.NoResults -> "No results"
    text.Select -> "Select"
    text.Selected -> "Selected"
    text.OrgRole -> "Org Role"

    // Invite links
    text.InvitesTitle -> "INVITES"
    text.LatestInviteLink -> "Latest invite link"
    text.InviteLinks -> "Invite links"
    text.InviteLinksHelp ->
      "Create invite links tied to a specific email. Copy the generated link to onboard a user."
    text.FailedToLoadInviteLinksPrefix -> "Failed to load invite links: "
    text.NoInviteLinksYet -> "No invite links yet"
    text.Link -> "Link"
    text.State -> "State"
    text.CreatedAt -> "Created"
    text.Regenerate -> "Regenerate"
    text.InvalidateInvite -> "Invalidate"
    text.InvalidateInviteConfirm(email) ->
      "Invalidate invite for " <> email <> "? This link will stop working."
    // Invite link states (Story 4.8)
    text.InviteStateActive -> "Pending"
    text.InviteStateUsed -> "Used"
    text.InviteStateExpired -> "Expired"
    text.CopyLink -> "Copy link"
    text.LinkCopied -> "Link copied!"

    // Projects
    text.Projects -> "Projects"
    text.CreateProject -> "Create Project"
    text.Name -> "Name"
    text.MyRole -> "My Role"
    text.NoProjectsYet -> "No projects yet"
    // Project edit/delete (Story 4.8 AC39)
    text.EditProject -> "Edit project"
    text.DeleteProject -> "Delete project"
    text.DeleteProjectTitle -> "Delete project"
    text.DeleteProjectConfirm(name) -> "Permanently delete \"" <> name <> "\"?"
    text.DeleteProjectWarning ->
      "This action cannot be undone. All tasks, cards and members will be deleted."
    text.MembersCount -> "Members"

    // Capabilities
    text.Capabilities -> "Capabilities"
    text.CreateCapability -> "Create Capability"
    text.DeleteCapability -> "Delete Capability"
    text.ConfirmDeleteCapability(name) ->
      "Delete capability \"" <> name <> "\"? This action cannot be undone."
    text.EditCapability -> "Edit capability"
    text.CapabilityNamePlaceholder -> "e.g., Frontend, Backend, UX..."
    text.NoCapabilitiesYet -> "No capabilities yet"

    // Members
    text.SelectProjectToManageMembers -> "Select a project to manage members."
    text.MembersTitle(project_name) -> "Members - " <> project_name
    text.MembersHelp ->
      "Members can view and claim tasks in this project. Manage who has access and with what role."
    text.AddMember -> "Add member"
    text.NoMembersYet -> "No members yet"
    text.RemoveMemberTitle -> "Remove member"
    text.RemoveMemberConfirm(user_email, project_name) ->
      "Remove " <> user_email <> " from " <> project_name <> "?"
    text.Remove -> "Remove"
    text.ClaimedTasks(count) -> int.to_string(count) <> " claimed"
    text.ReleaseAll -> "Release all"
    text.ReleaseAllConfirmTitle -> "Confirm release"
    text.ReleaseAllConfirmBody(count, user_name) ->
      "You are about to release "
      <> int.to_string(count)
      <> " tasks from "
      <> user_name
      <> ". The tasks will return to the pool."
    text.ReleaseAllSuccess(count, user_name) ->
      "Released " <> int.to_string(count) <> " tasks from " <> user_name
    text.ReleaseAllNone(user_name) -> user_name <> " has no claimed tasks"
    text.ReleaseAllError(user_name) ->
      "Could not release tasks from " <> user_name
    text.ReleaseAllSelfError -> "You cannot release your own tasks"
    // Member capabilities (Story 4.7 AC10-14, Story 4.8 AC23)
    text.CapabilitiesForUser(user_email, project_name) ->
      "Capabilities for " <> user_email <> " in " <> project_name
    text.NoCapabilitiesDefined -> "No capabilities defined for this project"
    text.ManageCapabilities -> "Manage capabilities"
    // Capability members (Story 4.7 AC16-17, Story 4.8 AC24)
    text.MembersForCapability(capability_name, project_name) ->
      "Members with " <> capability_name <> " in " <> project_name
    text.MembersSaved -> "Members saved"
    text.NoMembersDefined -> "No members in this project"
    text.ManageMembers -> "Manage members"

    // User Projects dialog
    text.UserProjectsTitle(user_email) -> "Projects for " <> user_email
    text.UserProjectsEmpty -> "This user does not belong to any projects."
    text.UserProjectsAdd -> "Add to project"
    text.SelectProject -> "Select project"
    text.UserProjectRemove -> "Remove"
    text.RoleInProject -> "Role in project"
    text.ProjectRoleUpdated -> "Project role updated"

    // Org Users main table
    text.Manage -> "Manage"
    text.SaveOrgRoleChanges -> "Save role changes"
    text.PendingChanges -> "pending changes"
    text.ProjectsSummary(count, summary) ->
      case count {
        0 -> "No projects"
        _ -> int.to_string(count) <> ": " <> summary
      }
    text.DeleteUser -> "Delete user"
    text.DeleteOwnUserBlocked -> "Cannot delete your own user"
    text.ConfirmDeleteUser(user_email) ->
      "Delete user \"" <> user_email <> "\"?"
    text.UserDeleted -> "User deleted"

    // Task types
    text.SelectProjectToManageTaskTypes ->
      "Select a project to manage task types."
    text.TaskTypesTitle(project_name) -> "Task Types - " <> project_name
    text.CreateTaskType -> "Create type"
    text.EditTaskType -> "Edit Task Type"
    text.DeleteTaskType -> "Delete Task Type"
    text.ConfirmDeleteTaskType(name) -> "Delete task type \"" <> name <> "\"?"
    text.TaskTypeHasTasks(count) ->
      "Cannot delete: has "
      <> int.to_string(count)
      <> " task"
      <> case count {
        1 -> ""
        _ -> "s"
      }
    text.TaskTypeName -> "Type name"
    text.TaskTypeUpdated -> "Task type updated"
    text.TaskTypeDeleted -> "Task type deleted"

    // Contextual hints (Story 4.9 AC21-22)
    text.RulesHintTemplates ->
      "Rules use templates to create tasks. Manage templates in "
    text.RulesHintTemplatesLink -> "Templates"
    text.TemplatesHintRules ->
      "Templates define what tasks to create. Rules determine when to create them. See "
    text.TemplatesHintRulesLink -> "Rules"

    text.IdentitySection -> "Identity"
    text.AppearanceSection -> "Appearance"
    text.ConfigurationSection -> "Configuration"
    text.Icon -> "Icon"
    text.OptionalFields -> "Optional"
    text.SelectIcon -> "Select icon"
    text.UnknownIcon -> "Unknown icon"
    text.CapabilityOptional -> "Capability (optional)"
    text.TaskTypeNameHint -> "e.g. Bug, Feature, Docs"
    text.LoadingCapabilities -> "Loading capabilities…"
    text.NoTaskTypesYet -> "No task types yet"
    text.CreateFirstTaskTypeHint ->
      "Create the first task type below to start using the Pool."
    text.TaskTypesExplain ->
      "Task types define what cards people can create (e.g., Bug, Feature)."
    text.HeroiconSearchPlaceholder -> "Search heroicon name (e.g. bug-ant)"
    text.WaitForIconPreview -> "Wait for icon preview"
    text.TitleTooLongMax56 -> "Title too long (max 56 characters)"
    text.NameAndIconRequired -> "Name and icon are required"
    text.PriorityMustBe1To5 -> "Priority must be 1-5"

    // Popover
    text.PopoverType -> "Type"
    text.PopoverCreated -> "Created"
    text.PopoverStatus -> "Status"
    text.CreatedAgoDays(days) -> {
      case days {
        0 -> "today"
        1 -> "1 day ago"
        _ -> int.to_string(days) <> " days ago"
      }
    }

    // Cards
    text.AdminCards -> "Cards"
    text.CardsTitle(project_name) -> "Cards - " <> project_name
    text.SelectProjectToManageCards -> "Select a project to manage cards."
    text.CreateCard -> "Create Card"
    text.EditCard -> "Edit Card"
    text.DeleteCard -> "Delete Card"
    text.CardTitle -> "Title"
    text.CardDescription -> "Description"
    text.CardPhase -> "State"
    text.CardPhaseDraft -> "Pending"
    text.CardPhaseActive -> "In Progress"
    text.CardPhaseClosed -> "Closed"
    text.CardTasks -> "Tasks"
    text.CardProgress -> "Progress"
    text.CardCreated -> "Card created"
    text.CardUpdated -> "Card updated"
    text.CardDeleted -> "Card deleted"
    text.CardDeleteBlocked -> "Cannot delete: has tasks"
    text.CardDeleteConfirm(card_title) ->
      "Delete card \"" <> card_title <> "\"?"
    text.NoCardsYet -> "No cards yet"
    text.CardTaskCount(completed, total) ->
      int.to_string(completed) <> "/" <> int.to_string(total)
    text.KanbanEmptyColumn -> "No cards here"
    text.KanbanEmptyDraft -> "No cards are waiting for work"
    text.KanbanEmptyActive -> "No active cards need attention"
    text.KanbanEmptyClosed -> "Closed cards will appear here"
    text.KanbanSurfacePurpose ->
      "Card flow by state, with friction and next work visible at a glance."
    text.KanbanSummaryCards -> "Cards"
    text.KanbanSummaryOngoing -> "Ongoing"

    // Workflows
    text.AdminWorkflows -> "Workflows"
    text.WorkflowsTitle -> "Workflows"
    text.WorkflowsOrgTitle -> "Organization Workflows"
    text.WorkflowsProjectTitle(project_name) -> "Workflows - " <> project_name
    text.SelectProjectForWorkflows -> "Select a project to manage workflows"
    text.WorkflowName -> "Name"
    text.WorkflowDescription -> "Description"
    text.WorkflowScope -> "Scope"
    text.WorkflowScopeOrg -> "Organization"
    text.WorkflowScopeProject -> "Project"
    text.WorkflowRules -> "Rules"
    text.WorkflowActive -> "Active"
    text.WorkflowCreated -> "Workflow created"
    text.WorkflowUpdated -> "Workflow updated"
    text.CreateWorkflow -> "Create Workflow"
    text.EditWorkflow -> "Edit Workflow"
    text.DeleteWorkflow -> "Delete Workflow"
    text.WorkflowDeleteConfirm(name) -> "Delete workflow \"" <> name <> "\"?"
    text.NoWorkflowsYet -> "No workflows yet"
    text.WorkflowDeleted -> "Workflow deleted"

    // Rules
    text.RulesTitle(workflow_name) -> "Rules - " <> workflow_name
    text.RuleName -> "Name"
    text.RuleGoal -> "Goal"
    text.RuleResourceType -> "Resource Type"
    text.RuleResourceTypeTask -> "Task"
    text.RuleResourceTypeCard -> "Card"
    text.RuleToState -> "Target State"
    text.RuleTaskType -> "Task Type"
    text.RuleActive -> "Active"
    text.RuleTemplates -> "Templates"
    text.CreateRule -> "Create Rule"
    text.EditRule -> "Edit Rule"
    text.DeleteRule -> "Delete Rule"
    text.NoRulesYet -> "No rules yet"
    text.RuleCreated -> "Rule created"
    text.RuleUpdated -> "Rule updated"
    text.RuleDeleted -> "Rule deleted"
    text.RuleDeleteConfirm(name) -> "Delete rule \"" <> name <> "\"?"
    text.AttachTemplate -> "Attach Template"
    text.DetachTemplate -> "Detach Template"
    text.RuleMetricsApplied -> "Applied"
    text.RuleMetricsSuppressed -> "Suppressed"

    // Story 4.10: Rule template attachment UI
    text.ExpandRule -> "Expand"
    text.CollapseRule -> "Collapse"
    text.AttachedTemplates -> "Attached Templates"
    text.AttachedTemplatesCount(count) ->
      int.to_string(count)
      <> " template"
      <> case count {
        1 -> ""
        _ -> "s"
      }
    text.NoTemplatesAttached -> "No templates attached"
    text.NoTemplatesWontCreateTasks -> "No templates (won't create tasks)"
    text.SelectTemplateToAttach -> "Select template to attach"
    text.AvailableTemplatesInProject -> "Available templates in this project"
    text.AttachTemplateHint ->
      "Attach a template so this rule creates tasks automatically when triggered."
    text.NoTemplatesInProject -> "No templates in this project"
    text.CreateTemplateLink -> "Create one in Templates"
    text.Attach -> "Attach"
    text.Attaching -> "Attaching…"
    text.TemplateAttached -> "Template attached"
    text.TemplateDetached -> "Template detached"
    text.DetachTemplateConfirm(name) -> "Detach template \"" <> name <> "\"?"
    text.Detaching -> "Detaching…"
    text.RemoveTemplate -> "Remove template"

    // Task States (for Rules)
    text.TaskStateAvailable -> "Available"
    text.TaskStateClaimed -> "Claimed"
    text.TaskStateOngoing -> "Working now"
    text.TaskStateDone -> "Done"
    text.TaskStateAvailableHint -> "Ready to claim from the Pool"
    text.TaskStateClaimedHint -> "In My Tasks, ready to start"
    text.TaskStateOngoingHint -> "Active work session is running"
    text.TaskStateDoneHint -> "Done and no longer actionable"
    text.TaskNextActionLabel -> "Next action"
    text.TaskNextActionClaim -> "Claim to My Tasks"
    text.TaskNextActionStart -> "Start working"
    text.TaskNextActionPause -> "Pause work"
    text.TaskNextActionComplete -> "Complete task"
    text.TaskNextActionRelease -> "Release back to Pool"
    text.TaskNextActionOpen -> "Open task"

    // Task Templates
    text.AdminTaskTemplates -> "Task Templates"
    text.TaskTemplatesTitle -> "Task Templates"
    text.TaskTemplatesOrgTitle -> "Organization Templates"
    text.TaskTemplatesProjectTitle(project_name) ->
      "Templates - " <> project_name
    text.TaskTemplateName -> "Name"
    text.TaskTemplateDescription -> "Description"
    text.TaskTemplateType -> "Type"
    text.TaskTemplatePriority -> "Priority"
    text.TaskTemplateScope -> "Scope"
    text.TaskTemplateCreated -> "Template created"
    text.TaskTemplateUpdated -> "Template updated"
    text.CreateTaskTemplate -> "Create Template"
    text.EditTaskTemplate -> "Edit Template"
    text.DeleteTaskTemplate -> "Delete Template"
    text.NoTaskTemplatesYet -> "No task templates yet"
    text.TaskTemplateDeleted -> "Template deleted"
    text.TaskTemplateDeleteConfirm(name) ->
      "Delete template \"" <> name <> "\"?"
    text.TaskTemplateVariablesHelp ->
      "Variables: {{father}} (origin task/card), {{from_state}} (previous state), {{to_state}} (new state), {{project}} (project name), {{user}} (user who triggered)"
    text.TaskTemplateDescriptionHint ->
      "Use variables in the description: {{father}}, {{from_state}}, {{to_state}}, {{project}}, {{user}}"
    text.AvailableVariables -> "Available variables"
    text.SelectTaskType -> "Select type"

    // Rule Metrics Tab
    text.AdminRuleMetrics -> "Rule Metrics"
    text.RuleMetricsTitle -> "Rule Metrics"
    text.RuleMetricsDescription ->
      "View how many times automation rules have been executed and their effectiveness."
    text.RuleMetricsHelp ->
      "View rule execution metrics for workflows. Select a date range (max 90 days) to see applied and suppressed counts."
    text.RuleMetricsFrom -> "From"
    text.RuleMetricsTo -> "To"
    text.RuleMetricsRefresh -> "Refresh"
    text.RuleMetricsQuickRange -> "Quick range:"
    text.RuleMetrics7Days -> "7 days"
    text.RuleMetrics30Days -> "30 days"
    text.RuleMetrics90Days -> "90 days"
    text.RuleMetricsSelectRange -> "Select a date range"
    text.RuleMetricsNoData -> "No metrics data for the selected range"
    text.RuleMetricsRuleCount -> "Rules"
    text.RuleMetricsEvaluated -> "Evaluated"
    text.RuleMetricsNoRules -> "No rules in this workflow"
    text.ViewDetails -> "View Details"
    text.OpenTask -> "Open task"
    text.AgeLabel -> "Age"
    text.ParentCardLabel -> "Card"
    text.RuleMetricsDrilldown -> "Rule Metrics Details"
    text.SuppressionBreakdown -> "Suppression Breakdown"
    text.SuppressionIdempotent -> "Idempotent (already applied)"
    text.SuppressionNotUserTriggered -> "Not user triggered"
    text.SuppressionNotMatching -> "Conditions not matching"
    text.SuppressionInactive -> "Rule inactive"
    text.RecentExecutions -> "Recent Executions"
    text.NoExecutions -> "No executions found"
    text.FirstPage -> "First page"
    text.PreviousPage -> "Previous page"
    text.NextPage -> "Next page"
    text.LastPage -> "Last page"
    text.Origin -> "Origin"
    text.Outcome -> "Outcome"
    text.Timestamp -> "Timestamp"
    text.OutcomeApplied -> "Applied"
    text.OutcomeSuppressed -> "Suppressed"

    // Story 3.4 - Member Card Views
    text.MemberCards -> "Plan"
    text.MemberCardsEmpty -> "No cards"
    text.MemberCardsEmptyHint -> "Cards group related tasks"

    // Color picker
    text.ColorLabel -> "Color"
    text.ColorNone -> "None"
    text.ColorGray -> "Gray"
    text.ColorRed -> "Red"
    text.ColorOrange -> "Orange"
    text.ColorYellow -> "Yellow"
    text.ColorGreen -> "Green"
    text.ColorBlue -> "Blue"
    text.ColorPurple -> "Purple"
    text.ColorPink -> "Pink"

    // Card grouping
    text.UngroupedTasks -> "No card"
    text.CardProgressCount(completed, total) ->
      int.to_string(completed) <> "/" <> int.to_string(total)

    // Card detail (member)
    text.CardAddTask -> "Add task"
    text.CardTasksEmpty -> "No tasks"
    text.CardTasksDone -> "completed"
    text.TaskType -> "Task type"
    text.TaskTitlePlaceholder -> "Task title..."

    // Story 4.12 - Card selector for new task
    text.NoCard -> "No card"
    text.NewTaskInCard(card_title) -> "Add task to " <> card_title

    // Story 4.4 - Three-panel layout
    // Accessibility labels
    text.MainNavigation -> "Main navigation"
    text.MyActivity -> "My activity"

    // Left panel sections
    text.Work -> "Work"
    text.NewCard -> "New Card"
    text.QuickCard -> "New card"
    text.QuickTask -> "New task"
    text.NoTasksYet -> "No tasks yet"
    text.CardTasksMore(hidden_count) ->
      "+" <> int.to_string(hidden_count) <> " more tasks"
    text.NewCardInThisHierarchy -> "New card in this hierarchy"
    text.HierarchyTarget -> "Destination hierarchy"
    text.Configuration -> "Configuration"
    text.Team -> "Team"
    // Note: text.Capabilities already translated in Capabilities section
    // Story 4.9: New config nav items
    text.CardsConfig -> "Cards"
    text.TaskTypes -> "Task Types"
    text.Templates -> "Templates"
    text.Rules -> "Rules"
    // Story 4.9: Cards config filters (UX improvements)
    text.ShowEmptyCards -> "Show empty"
    text.ShowDoneCards -> "Show completed"
    text.Organization -> "Organization"
    text.OrgUsers -> "Users"
    text.Invites -> "Invitations"

    // Right panel sections
    text.InProgress -> "In Progress"
    text.Resume -> "Resume"
    text.MyCards -> "Context"
    text.NoTasksClaimed -> "No tasks claimed"
    text.NoCardsAssigned -> "No cards assigned"
    text.NoTasksInProgress -> "No tasks in progress"
    // AC32: Empty state hints
    text.NoTasksClaimedHint -> "Browse Pool to claim a task"
    text.NoCardsAssignedHint -> "View Cards to see available cards"
    text.NoTasksInProgressHint -> "Start a task from My Tasks"

    // Story 5.3: Card notes hovers (AC16-AC22)
    text.NewNotesTooltip -> "There are new notes"
    text.EditCardTooltip -> "Edit card"
    text.DeleteCardTooltip -> "Delete card"
    text.ProgressTooltip(completed, in_progress, pending) ->
      int.to_string(completed)
      <> " completed, "
      <> int.to_string(in_progress)
      <> " in progress, "
      <> int.to_string(pending)
      <> " pending"
    // AC16: Rich tooltip on [!] indicator
    text.NotesPreviewNewNotes -> "new notes"
    text.NotesPreviewTimeAgo -> "since"
    text.NotesPreviewLatest -> "Latest:"
    // AC21: Tab badge tooltip
    text.TabBadgeTotalNotes -> "notes total"
    text.TabBadgeNewNotes -> "new for you"
    // AC21: Tab labels
    text.TabTasks -> "Tasks"
    text.TabNotes -> "Notes"
    text.TabSummary -> "Summary"
    text.TabWork -> "Work"
    text.TabActivity -> "Activity"
    text.ActivityLoading -> "Loading activity..."
    text.ActivityEmpty -> "No activity yet."
    text.ActivityLoadFailed -> "Could not load activity."
    // 5.4.1: Task detail modal
    text.TabDetails -> "Details"
    text.TabDependencies -> "Dependencies"
    text.EditTask -> "Edit task"
    text.TaskUpdated -> "Task updated"
    text.TaskEditPlanning -> "Planning"
    text.TaskEditLocation -> "Location"
    text.TaskEditKeyboardHint -> "Ctrl/Cmd+Enter saves. Esc cancels."
    text.TaskEditRequiresClaim ->
      "You can edit unclaimed tasks, or claim the task to keep editing it while in progress."
    text.TaskEditDoneReadOnly ->
      "Done tasks are read-only. Reopen or duplicate the work before changing details."
    text.HierarchyLabel -> "Hierarchy"
    text.NoHierarchy -> "No hierarchy"
    text.TaskHierarchyInheritedFromCard -> "Hierarchy inherited from the card"
    text.TaskDescriptionEmpty -> "No description yet"
    text.TaskOperationalSummary -> "Operational summary"
    text.TaskOwner -> "Owner"
    text.TaskBlockingClear -> "No active blockers"
    text.MetricsTasksTotal -> "Tasks total"
    text.MetricsTasksDone -> "Tasks completed"
    text.MetricsProgress -> "Progress"
    text.MetricsRebotesAvg -> "Average bounces"
    text.MetricsPoolLifetimeAvg -> "Average pool lifetime"
    text.MetricsAvailable -> "Available"
    text.MetricsClaimed -> "Claimed"
    text.MetricsOngoing -> "Ongoing"
    text.MetricsExecutors -> "Executors"
    text.MetricsTotal -> "Total"
    text.MetricsClaimCount -> "Claim count"
    text.MetricsReleaseCount -> "Release count"
    text.MetricsUniqueExecutors -> "Unique executors"
    text.MetricsFirstClaimAt -> "First claim at"
    text.MetricsCurrentStateTime -> "Current state time"
    text.MetricsPoolLifetime -> "Pool lifetime"
    text.MetricsSessionCount -> "Session count"
    text.MetricsTotalWorkTime -> "Total work time"
    text.MetricsAvgExecutors -> "Avg executors"
    text.MetricsWorkflows -> "Workflows"
    text.MetricsMostActivated -> "Most activated"
    text.MetricsNotAvailable -> "Not available"
    text.MetricsEmptyState -> "Not enough data for metrics"
    text.MetricsLoadError -> "Could not load metrics"
    text.Unassigned -> "Unassigned"
    text.Assigned -> "Assigned"
    text.ClaimTask -> "Claim task"

    // Error states
    text.ErrorLoadingTasks -> "Error loading tasks"

    // Workflows / Rules
    text.BackToWorkflows -> "← Back to Workflows"
    text.ResourceTypeTask -> "task"
    text.RuleMetricsNoExecutions ->
      "No automation executions found in the selected range."
    text.RuleMetricsResults -> "Results"

    // Icon picker
    text.NoIconsFound -> "No icons found"
    text.SearchIconsPlaceholder -> "Search icons..."
  }
}
