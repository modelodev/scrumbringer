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
    text.LoginTitle -> "Sign in"
    text.LoginSubtitle -> "Sign in to access ScrumBringer."
    text.NoEmailIntegrationNote ->
      "Email delivery is not connected in this environment. This creates a reset link you can copy."
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
    text.TaskClosed -> "Task closed"
    text.TaskDeleted -> "Task deleted"
    text.SkillsSaved -> "Capabilities saved"
    text.NoteAdded -> "Note added"

    // Task mutation errors
    text.TaskVersionConflict -> "Task was modified. Please refresh."
    text.TaskAlreadyClaimed -> "Task is already claimed by someone else"
    text.TaskBlockedByDependencies -> "Task has open dependencies"
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
    text.TaskCreateParentCardConflict -> "Choose one card for the task."
    text.TaskCreateRequiresCard -> "Choose an active card to create the task."
    text.TaskCreateActiveCardLabel -> "Active card"
    text.TaskCreateNoActiveCards -> "No active cards can receive tasks"
    text.TaskCreateCardsLoadFailed -> "Could not load active cards"
    text.TaskCreateDraftCardTarget -> "Draft · activate it to create tasks here"
    text.CardPickerSearchAllCardsHint ->
      "Type to search all active cards in this project."
    text.CardPickerRefineSearchHint ->
      "More cards match this search. Keep typing to narrow results."
    text.TaskEditCardLabel -> "Move task to card"
    text.TaskCreateMissingCard ->
      "Selected card is not available. Close this dialog and try again."
    text.TaskCreateInactiveCard -> "Only active cards can receive new tasks."
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
    text.Back -> "Back"
    text.Continue -> "Continue"
    text.Skip -> "Skip"
    text.Create -> "Create"
    text.SaveDraftCard -> "Save draft"
    text.CreateAndActivateCard -> "Create and activate"
    text.Creating -> "Creating…"
    text.CreatingAndActivating -> "Creating and activating…"
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

    // Member sections
    text.Pool -> "Pool"
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
    text.TaskOverdue(due_date) -> "Overdue since " <> due_date
    text.TaskDueToday -> "Due today"
    text.TaskDueSoon(due_date) -> "Due soon: " <> due_date
    text.EditPosition -> "Edit position"
    text.XLabel -> "x"
    text.YLabel -> "y"

    // Member pool controls
    text.Canvas -> "Canvas"
    text.List -> "List"
    text.Kanban -> "Kanban"
    text.CapabilitiesBoard -> "Capabilities"
    text.People -> "People"
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
    text.KanbanColumnPending -> "Pending"
    text.PlanEmptyCardScopeBody ->
      "Search for a card to review its subtree, capabilities, tasks, and risk."
    text.PlanEmptyScopeTitle -> "No cards in this scope."
    text.PlanEmptyScopeBody ->
      "Create a card or change the scope to review another part of the plan."
    text.PlanCapabilityList -> "List"
    text.PlanCapabilityMatrix -> "Matrix"
    text.PlanClosed -> "Closed"
    text.PlanStatusAll -> "All"
    text.PlanIncludesClosed -> "Includes closed"
    text.PoolPurpose -> "Active tasks available for the team to claim."
    text.PoolVisibilityLabel -> "Show"
    text.PoolVisibilityAllOpen -> "Open"
    text.PoolVisibilityReadyToClaim -> "Claimable"
    text.PoolVisibilityBlocked -> "Blocked"
    text.PoolOpenCount -> "Open"
    text.PoolHealthyLimit -> "Healthy limit"
    text.NewTask -> "New task"
    text.Description -> "Description"
    text.Priority -> "Priority"
    text.PriorityHighest -> "highest"
    text.PriorityLowest -> "lowest"
    text.AllOption -> "All"
    text.SelectType -> "Select type"
    text.TypeLabel -> "Type"
    text.CapabilityLabel -> "Capability"
    text.CapabilityScopeLabel -> "Capabilities"
    text.ScopeAll -> "All"
    text.ScopeMine -> "Mine"
    text.SearchLabel -> "Search"
    text.SearchPlaceholder -> "q"
    text.ClearFilters -> "Clear"
    text.NoAvailableTasksRightNow -> "No available tasks right now"
    text.NoTasksMatchYourFilters -> "No tasks match your filters"
    text.NoOpenPoolTasks -> "No open tasks in the Pool"
    text.NoOpenPoolTasksBody ->
      "Open work will appear here when it is ready for the team to pull."
    text.NoClaimablePoolTasks -> "No claimable tasks right now"
    text.NoClaimablePoolTasksBlockedBody(count) ->
      "There are "
      <> int.to_string(count)
      <> " blocked tasks that need dependencies or a team conversation."
    text.NoClaimablePoolTasksBody ->
      "The Pool is clear for your current filters."
    text.NoBlockedPoolTasks -> "No blocked tasks"
    text.NoBlockedPoolTasksBody ->
      "Blockers will appear here when an unfinished dependency prevents claiming."
    text.ViewBlockedTasks -> "View blocked"
    text.ViewOpenTasks -> "View open"
    text.HideClosedTasks -> "Hide closed tasks"
    text.PriorityShort(priority) -> "P" <> int.to_string(priority)
    text.Claim -> "Claim"
    text.ClaimThisTask -> "Claim this task and move it to My Tasks"
    text.ClaimedBy -> "Claimed by"
    text.UnknownUser -> "Unknown user"
    text.PeopleSearchPlaceholder -> "Search person, task, or card"
    text.PeopleEmpty -> "No members in this project"
    text.PeopleNoResults -> "No people match your search"
    text.PeopleLoading -> "Loading people..."
    text.PeopleLoadError -> "Could not load people"
    text.PeoplePurpose ->
      "Operational team state by owned work, blockers, and availability."
    text.PeopleAttentionLabel -> "Attention"
    text.PeopleFreeLabel -> "Available"
    text.PeopleBusyLabel -> "With work"
    text.PeopleWorkingLabel -> "Working now"
    text.PeopleOngoingCount(count) -> int.to_string(count) <> " ongoing"
    text.PeopleReservedCount(count) -> int.to_string(count) <> " claimed"
    text.PeopleBlockedCount(count) -> int.to_string(count) <> " blocked"
    text.PeopleCardsCount(count) -> int.to_string(count) <> " cards"
    text.PeopleLoadWarning -> "High load"
    text.PeopleTrayTitle(person) -> "Work for " <> person
    text.PeopleNowSection -> "Now"
    text.PeopleNowDescription ->
      "Active focus. Claimed work waits until this is paused, closed, or released."
    text.PeopleReservedSection -> "Claimed, not started"
    text.PeopleReservedDescription ->
      "Claimed by this person; not active focus yet."
    text.PeopleNoActiveFocus -> "No active focus"
    text.PeopleNoReservedWork -> "No claimed work"
    text.PeopleNoCardContext -> "No card"
    text.PeopleColumnPerson -> "Person"
    text.PeopleColumnWork -> "Work"
    text.PeopleColumnLoad -> "Load"
    text.PeopleSectionNeedsAttention -> "Needs attention"
    text.PeopleSectionWorkingNow -> "Working now"
    text.PeopleSectionReservedWork -> "Claimed"
    text.PeopleSectionAvailable -> "Available"
    text.PeopleWorkingNowState -> "Working now"
    text.PeopleAvailableState -> "Available"
    text.PeopleNeedsAttentionState -> "Needs attention"
    text.PeopleNoOwnedWork -> "No claimed work"
    text.PeopleNextWork(title) -> "Next: " <> title
    text.PeopleReservedGroupCount(count) ->
      int.to_string(count)
      <> case count {
        1 -> " task"
        _ -> " tasks"
      }
    text.PeopleTaskNowMeta(context) -> "In progress · " <> context
    text.PeopleTaskReservedMeta(context) -> "Claimed · " <> context
    text.PeopleTaskBlockedMeta(context) -> "Blocked · " <> context
    text.PeopleBlockedBy(title) -> "Blocked by: " <> title
    text.PeopleOpenDependencies -> "open dependencies"
    text.PeopleShowLabel -> "Show"
    text.PeopleFilterEveryone -> "Everyone"
    text.PeopleFilterWithWork -> "With work"
    text.PeopleFilterAttention -> "Attention"
    text.PeopleFilterFree -> "Available"
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
    text.CapabilityBoardPurpose ->
      "Capacity by card, derived from real descendant tasks."
    text.CapabilityBoardCardColumn -> "Card"
    text.CapabilityBoardLevelColumn -> "Level"
    text.CapabilityBoardTotal -> "Total"
    text.CapabilityBoardNoTasks -> "No active tasks"
    text.CapabilityBoardEmptyCell -> "No tasks"
    text.NoCapability -> "No capability"
    text.HierarchyActivationTitle -> "Activate hierarchy"
    text.HierarchyActivationBody(cards_count, tasks_count) ->
      "This action is irreversible. It will activate all content in this hierarchy ("
      <> int.to_string(cards_count)
      <> " cards, "
      <> int.to_string(tasks_count)
      <> " tasks)."
    text.HierarchyActivationWarning ->
      "You will not be able to undo this action"
    text.ActivateHierarchy -> "Activate"
    text.HierarchyActivated -> "Hierarchy activated"
    text.HierarchyActivationPoolImpact(pool_impact) ->
      "On activation: +" <> int.to_string(pool_impact) <> " tasks"
    text.HierarchyActivationPoolSaturated(pool_open_after, healthy_pool_limit) ->
      "Pool at "
      <> int.to_string(pool_open_after)
      <> "/"
      <> int.to_string(healthy_pool_limit)
    text.HierarchyActivateFailed -> "Could not activate hierarchy"
    text.HierarchyMoreActions -> "More actions"
    text.HierarchyMoveTo -> "Move"
    text.HierarchyScopeSubtitle ->
      "Review nested cards and their tasks in this scope."
    text.HierarchyScopeDirectTasks -> "Direct tasks"
    text.HierarchyScopeCardTitle -> "Card scope"
    text.HierarchyScopeDepthFallback(depth) -> "Depth " <> int.to_string(depth)
    text.HierarchyScopeEmptyDepthTitle -> "No cards at this level"
    text.HierarchyScopeEmptyDepthBody(name) ->
      "Create a card at this level to start organizing " <> name
    text.OpenIn -> "Open in"
    text.ViewInPlan -> "View in Plan"
    text.ViewInKanban -> "View in Kanban"
    text.ViewInCapabilities -> "View in Capabilities"
    text.ViewInPeople -> "View in People"
    text.ExpandPerson(name) -> "Expand status for " <> name
    text.CollapsePerson(name) -> "Collapse status for " <> name
    text.Drag -> "Drag"
    text.NowWorking -> "Working now"
    text.NowWorkingNone ->
      "Nothing active. Start a task from My Tasks when you are ready to work."
    text.Pause -> "Pause"
    text.Release -> "Release"
    text.TaskNumber(task_id) -> "Task #" <> int.to_string(task_id)

    // Admin
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
    text.NotPermitted -> "Not permitted"
    text.NotPermittedBody -> "You don't have permission to access this section."

    // Admin sidebar groups (SA01-SA05)
    text.ProjectLabel -> "Project"
    text.AllProjects -> "All projects"
    text.MyMetrics -> "My Metrics"
    text.LoadingMetrics -> "Loading metrics…"
    text.WindowDays(days) -> "Window: " <> int.to_string(days) <> " days"
    text.Claimed -> "Claimed"
    text.Released -> "Released"
    text.Closed -> "Closed"
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
    text.AvgClaimToClose -> "Avg claim → close"
    text.AvgTimeInClaimed -> "Avg time in claimed"
    text.StaleClaims -> "Stale claims"
    text.LastClaim -> "Last claim"
    text.TimeToFirstClaim -> "Time to first claim"
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
    text.Closures -> "Closures"
    text.FirstClaim -> "First claim"
    text.ProjectTasks(project_name) -> "Project tasks: " <> project_name

    // Org users
    text.OpenThisSectionToLoadUsers -> "Open this section to load users."
    text.LoadingUsers -> "Loading users…"
    text.Role -> "Role"
    text.Actions -> "Actions"
    text.User -> "User"
    text.UserNumber(user_id) -> "User #" <> int.to_string(user_id)
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
    text.ProjectCreateStepLabel(current, total) ->
      "Step " <> int.to_string(current) <> " of " <> int.to_string(total)
    text.ProjectCreateGeneralTitle -> "General"
    text.ProjectCreateGeneralHint ->
      "Name the project so the team can recognize where this work belongs."
    text.ProjectCreateCapabilitiesTitle -> "Capabilities"
    text.ProjectCreateCapabilitiesHint ->
      "Initial capabilities can be configured after creation, before inviting or assigning the team."
    text.ProjectCreateTeamTitle -> "Team"
    text.ProjectCreateTeamHint ->
      "Invite members after the project exists so roles and capabilities can be adjusted in context."
    text.ProjectCreateReviewTitle -> "Review"
    text.ProjectCreateReviewHint ->
      "Confirm the required structure. Capabilities and team setup can continue after creation."
    text.ProjectCreateReviewSkipped -> "Configured after creation"

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
    text.UserProjectsEmpty -> "This user does not belong to any projects."
    text.UserProjectsAdd -> "Add to project"
    text.SelectProject -> "Select project"
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

    // Project structure and Pool settings
    text.ProjectStructureAndPool -> "Structure and Pool"
    text.ProjectStructureCreateHint ->
      "Choose how deep cards can nest before work reaches the Pool."
    text.ProjectStructureEditHint ->
      "Visible level names define how cards are grouped before work reaches the Pool."
    text.ProjectMaximumDepth -> "Maximum depth"
    text.ProjectPoolSoftLimit -> "Pool soft limit"
    text.ProjectStructureExamples ->
      "Examples: Card -> Task for small teams, Initiative -> Feature -> Task group for product work."
    text.ProjectPoolSoftLimitHint ->
      "This limit never blocks. It helps avoid saturation and team frustration when too many tasks are available in the Pool."
    text.ProjectDepthLevel(depth) -> "Level " <> int.to_string(depth)
    text.ProjectDepthLevelRole(depth, max_depth) -> {
      let level = "Level " <> int.to_string(depth)
      case depth == 1, depth == max_depth {
        True, True -> level <> " · top, receives tasks"
        True, False -> level <> " · top"
        False, True -> level <> " · receives tasks"
        False, False -> level
      }
    }
    text.ProjectDepthOrientationHelp ->
      "Levels run from the broadest card to the card closest to tasks."
    text.ProjectDepthTasksEndpoint -> "Tasks"
    text.ProjectDepthLevelSingularName(depth) ->
      "Level " <> int.to_string(depth) <> " singular name"
    text.ProjectDepthLevelPluralName(depth) ->
      "Level " <> int.to_string(depth) <> " plural name"
    text.ProjectDepthReductionHidden ->
      "Depth reduction confirmation appears before closing cards outside a new limit."
    text.ProjectDepthReductionNeedsReview(new_max_depth) ->
      "Reducing depth to "
      <> int.to_string(new_max_depth)
      <> " levels needs review before any cards are closed."
    text.ProjectDepthReductionReviewCards -> "Review affected cards"
    text.ProjectDepthReductionLoading(new_max_depth) ->
      "Checking cards below " <> int.to_string(new_max_depth) <> " levels..."
    text.ProjectDepthReductionBlocked(cards_count, claimed_tasks_count) ->
      int.to_string(cards_count)
      <> " cards are below the new limit, but "
      <> int.to_string(claimed_tasks_count)
      <> " claimed or ongoing tasks must be released or closed first."
    text.ProjectDepthReductionReady(cards_count, available_tasks_count) ->
      int.to_string(cards_count)
      <> " cards and "
      <> int.to_string(available_tasks_count)
      <> " available tasks are below the new limit."
    text.ProjectDepthReductionAffectedCards -> "Affected cards"
    text.ProjectDepthReductionConfirm -> "Confirm depth reduction"
    text.ProjectDepthReductionConfirmed(new_max_depth) ->
      "Depth reduction to "
      <> int.to_string(new_max_depth)
      <> " levels confirmed."
    text.ProjectPoolSoftLimitPositive ->
      "Pool soft limit must be a positive number"
    text.ProjectMaximumDepthPositive ->
      "Maximum depth must be a positive number"
    text.ProjectAddLevelNamesBeforeIncreasingDepth ->
      "Add level names before increasing maximum depth"
    text.ProjectReviewAffectedCardsBeforeLoweringDepth ->
      "Review affected cards before saving a lower maximum depth"
    text.ProjectDepthNamesRequired ->
      "Every level needs singular and plural names"

    // Contextual hints (Story 4.9 AC21-22)
    text.TemplatesHintRules ->
      "Templates define what tasks to create. Rules determine when each template creates work."
    text.IdentitySection -> "Identity"
    text.Icon -> "Icon"
    text.OptionalFields -> "Optional"
    text.SelectIcon -> "Select icon"
    text.UnknownIcon -> "Unknown icon"
    text.TaskTypeNameHint -> "e.g. Bug, Feature, Docs"
    text.NoTaskTypesYet -> "No task types yet"
    text.CreateFirstTaskTypeHint ->
      "Create the first task type below to start using the Pool."
    text.TaskTypesExplain ->
      "Task types define what cards people can create (e.g., Bug, Feature)."
    text.TitleTooLongMax56 -> "Title too long (max 56 characters)"
    text.NameAndIconRequired -> "Name and icon are required"
    text.PriorityMustBe1To5 -> "Priority must be 1-5"

    // Popover
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
    text.CardPhaseActive -> "Active"
    text.CardPhaseClosed -> "Closed"
    text.CardTasks -> "Tasks"
    text.CardCreated -> "Card created"
    text.CardUpdated -> "Card updated"
    text.CardDeleted -> "Card deleted"
    text.CardDeleteConfirm(card_title, task_count, subcard_count) ->
      "Delete card \""
      <> card_title
      <> "\"? "
      <> card_delete_impact_copy(task_count, subcard_count)
    text.NoCardsYet -> "No cards yet"
    text.KanbanEmptyDraft -> "No cards are waiting for work"
    text.KanbanEmptyActive -> "No active cards need attention"
    text.KanbanEmptyClosed -> "Closed cards will appear here"
    text.KanbanSurfacePurpose ->
      "Card flow by state, with friction and next work visible at a glance."
    text.KanbanSummaryCards -> "Cards"
    text.AdminAutomations -> "Automations"
    text.AutomationEnginesProjectTitle(project_name) ->
      "Engines - " <> project_name
    text.SelectProjectForAutomations -> "Select a project to manage automations"
    text.AutomationEngineName -> "Name"
    text.AutomationEngineDescription -> "Description"
    text.AutomationEngineRules -> "Rules"
    text.AutomationEngineActive -> "Active"
    text.AutomationEngineCreated -> "Engine created"
    text.AutomationEngineUpdated -> "Engine updated"
    text.CreateAutomationEngine -> "Create engine"
    text.EditAutomationEngine -> "Edit engine"
    text.DeleteAutomationEngine -> "Delete engine"
    text.AutomationEngineDeleteConfirm(name) ->
      "Delete engine \"" <> name <> "\"?"
    text.NoAutomationEnginesYet -> "No engines yet"
    text.AutomationEngineDeleted -> "Engine deleted"
    text.AutomationEnginesDescription ->
      "Group automation rules that create work in the Pool without assigning it."
    text.AutomationEnginesSearchPlaceholder ->
      "Search engines by name or description"
    text.AutomationEngineStatus -> "Status"
    text.AutomationEngineStatusAll -> "All statuses"
    text.AutomationEngineStatusActive -> "Active"
    text.AutomationEngineStatusPaused -> "Paused"
    text.AutomationConsolePurpose ->
      "Create work automatically in the Pool without assigning it to anyone."
    text.AutomationSummaryActiveEngines -> "active engines"
    text.AutomationSummaryRules -> "rules"
    text.AutomationSummaryTemplates -> "templates"
    text.AutomationSummaryCreatedTasks -> "created tasks"
    text.AutomationModeAriaLabel -> "Automation mode"
    text.AutomationModeEngines -> "Engines"
    text.AutomationModeTemplates -> "Templates"
    text.AutomationModeExecutions -> "Executions"
    text.AutomationSelectedEngine(id) ->
      "Engine #" <> int.to_string(id) <> " selected"
    text.AutomationSelectedRule(id) ->
      "Rule #" <> int.to_string(id) <> " selected"
    text.AutomationSelectedRuleInEngine(rule_id, engine_id) ->
      "Rule #"
      <> int.to_string(rule_id)
      <> " selected in engine #"
      <> int.to_string(engine_id)
    text.AutomationSelectedTemplate(id) ->
      "Template #" <> int.to_string(id) <> " selected"
    text.AutomationSelectedExecution(id) ->
      "Execution #" <> int.to_string(id) <> " selected"

    // Rules
    text.RulesTitle(engine_name) -> "Rules - " <> engine_name
    text.RuleName -> "Name"
    text.RuleGoal -> "Goal"
    text.RuleTaskType -> "Task Type"
    text.RuleActive -> "Active"
    text.CreateRule -> "Create Rule"
    text.EditRule -> "Edit Rule"
    text.DeleteRule -> "Delete Rule"
    text.NoRulesYet -> "No rules yet"
    text.RuleCreated -> "Rule created"
    text.RuleUpdated -> "Rule updated"
    text.RuleDeleted -> "Rule deleted"
    text.RuleDeleteConfirm(name) -> "Delete rule \"" <> name <> "\"?"
    text.RuleMetricsApplied -> "Created"
    text.RuleMetricsSuppressed -> "Ignored"
    text.RuleTemplateSearchPlaceholder -> "Search templates"
    text.RuleTemplateNoSearchResults -> "No templates match this search."
    text.RuleBuilderNewRule -> "New rule"
    text.RuleBuilderEditRule -> "Edit rule"
    text.RuleBuilderSaveRule -> "Save rule"
    text.RuleBuilderWhen -> "When"
    text.RuleBuilderEvent -> "Event"
    text.RuleBuilderCreateTaskFrom -> "Create work from"
    text.RuleBuilderCardScope -> "Card automation scope"
    text.RuleBuilderAnyCard -> "Any card"
    text.RuleBuilderCardsAtLevel(level_name) -> "Cards at level: " <> level_name
    text.RuleBuilderSubject -> "Rule subject"
    text.RuleBuilderTask -> "Task"
    text.RuleBuilderCard -> "Card"
    text.RuleBuilderAnyTaskType -> "Any task type"
    text.RuleBuilderTaskTemplate -> "Rule task template"
    text.RuleBuilderChooseTemplate -> "Choose a template"
    text.RuleBuilderTaskCreatedEvent -> "is created"
    text.RuleBuilderTaskClosedEvent -> "is closed"
    text.RuleBuilderTaskClaimedEvent -> "is claimed"
    text.RuleBuilderTaskReleasedEvent -> "is released"
    text.RuleBuilderCardActivatedEvent -> "is activated"
    text.RuleBuilderCardClosedEvent -> "is closed"
    text.RuleBuilderPreview -> "Preview"
    text.RulePreviewTaskCreated(subject) ->
      "When " <> subject <> " is created, work is created in the Pool."
    text.RulePreviewTaskClaimed(subject) ->
      "When " <> subject <> " is claimed, work is created in the Pool."
    text.RulePreviewTaskReleased(subject) ->
      "When " <> subject <> " is released, work is created in the Pool."
    text.RulePreviewTaskClosed(subject) ->
      "When " <> subject <> " is closed, work is created in the Pool."
    text.RulePreviewCardActivated(scope) ->
      "When " <> scope <> " is activated, work is created in the Pool."
    text.RulePreviewCardClosed(scope) ->
      "When " <> scope <> " is closed, work is created in the Pool."
    text.RulePreviewRequiresReview ->
      "This rule uses a target that requires review before it can run."
    text.RulePreviewAnyCard -> "any card"
    text.RulePreviewCardLevel(level_name) -> "a " <> level_name
    text.RulePreviewFallbackCardLevel(depth) ->
      "a card at level " <> int.to_string(depth)
    text.RulePreviewSelectedCardLevel -> "a selected card level"
    text.RulePreviewAnyTask -> "any task"
    text.RulePreviewTaskType(task_type_name) ->
      "a " <> task_type_name <> " task"
    text.RulePreviewSelectedTaskType -> "a selected task type"
    text.RuleTriggerTaskClaimedWord -> "claimed"
    text.RuleTriggerTaskClosedWord -> "closed"
    text.RuleTriggerTaskCreatedWord -> "created"
    text.RuleTriggerTaskReleasedWord -> "released"
    text.RulePreviewTemplateWillCreate(template_name) ->
      "It will create \"" <> template_name <> "\" as available work."
    text.RulePreviewChooseTemplate ->
      "Choose one template before saving this rule."
    text.RulePreviewCardActivationNoiseWarning ->
      "Warning: activating a card with many subcards can create a lot of Pool work."
    text.RuleBuilderTemplateVariablesUnavailable(variables) ->
      "This template uses variables unavailable for the selected trigger: "
      <> variables
      <> ". Change the trigger or choose another template."
    text.RuleBuilderCardScopeUnavailable(depth) ->
      "Card level "
      <> int.to_string(depth)
      <> " is no longer available. Choose an existing card level or Any card."

    text.ExpandRule -> "Expand"
    text.CollapseRule -> "Collapse"
    text.AttachedTemplates -> "Selected Template"
    text.AttachTemplateHint ->
      "Select a template so this rule creates one task automatically when triggered."

    // Task States (for Rules)
    text.TaskStateAvailable -> "Available"
    text.TaskStateClaimed -> "Claimed"
    text.TaskStateOngoing -> "Working now"
    text.TaskStateClosed -> "Closed"
    text.TaskStateAvailableHint -> "Ready to claim from the Pool"
    text.TaskStateClaimedHint -> "In My Tasks, ready to start"
    text.TaskStateOngoingHint -> "Active work session is running"
    text.TaskStateClosedHint -> "Closed and no longer actionable"
    text.TaskHeadlineAvailable -> "Ready to claim"
    text.TaskHeadlineClaimedByYou -> "In My Tasks, ready to start"
    text.TaskHeadlineClaimedByOther -> "Claimed by another user"
    text.TaskHeadlineClaimed -> "Claimed"
    text.TaskHeadlineOngoingByYou -> "You are working now"
    text.TaskHeadlineOngoingByOther -> "Working now by another user"
    text.TaskHeadlineOngoing -> "Working now"
    text.TaskHeadlineClosed -> "Closed"
    text.TaskNextActionLabel -> "Next action"
    text.TaskNextActionClaim -> "Claim to My Tasks"
    text.TaskNextActionStart -> "Start working"
    text.TaskNextActionPause -> "Pause work"
    text.TaskNextActionClose -> "Close task"
    text.TaskNextActionRelease -> "Release back to Pool"
    text.TaskNextActionOpen -> "Open task"

    // Task Templates
    text.AdminTaskTemplates -> "Templates"
    text.TaskTemplatesTitle -> "Template library"
    text.TaskTemplatesProjectTitle(project_name) ->
      "Template library - " <> project_name
    text.AutomationTemplatesDescription ->
      "Manage reusable templates for rules. Generated tasks stay available in the Pool."
    text.AutomationTemplatesSearchPlaceholder -> "Search templates"
    text.TaskTemplateName -> "Name"
    text.TaskTemplateDescription -> "Description"
    text.TaskTemplateType -> "Type"
    text.TaskTemplatePriority -> "Priority"
    text.TaskTemplateUsages -> "Uses"
    text.TaskTemplateUnused -> "Unused"
    text.TaskTemplateCreatedTasks -> "Created"
    text.TaskTemplateLastExecution -> "Last"
    text.TaskTemplateNeverExecuted -> "Never"
    text.TaskTemplateCreated -> "Template created"
    text.TaskTemplateUpdated -> "Template updated"
    text.CreateTaskTemplate -> "Create Template"
    text.EditTaskTemplate -> "Edit Template"
    text.DeleteTaskTemplate -> "Delete Template"
    text.NoTaskTemplatesYet -> "No templates yet"
    text.TaskTemplateDeleted -> "Template deleted"
    text.TaskTemplateDeleteConfirm(name) ->
      "Delete template \"" <> name <> "\"?"
    text.TaskTemplateDeleteRulesWarning ->
      "Rules using this template should be paused or updated first."
    text.TaskTemplateEditFutureTasksWarning ->
      "This template is used by active rules. Changes affect only future generated tasks; tasks already created keep their original content and origin."
    text.TaskTemplateVariablesHelp ->
      "Variables: {{origin}} (origin task/card), {{trigger}} (automation trigger), {{project}} (project name), {{user}} (user who triggered), {{task_title}} and {{task_type}} for task-triggered automations, {{card_title}} and {{card_level}} for card-triggered automations"
    text.TaskTemplateDescriptionHint ->
      "Use variables in the description: {{origin}}, {{trigger}}, {{project}}, {{user}}, {{task_title}}, {{task_type}}, {{card_title}}, {{card_level}}"
    text.AvailableVariables -> "Available variables"
    text.TaskTemplateInsertVariable(variable) ->
      "Insert variable {{" <> variable <> "}}"
    text.SelectTaskType -> "Select type"

    // Automation executions tab
    text.AdminRuleMetrics -> "Executions"
    text.RuleMetricsDescription ->
      "Review automation executions, created tasks, and ignored events."
    text.RuleMetricsHelp ->
      "Select a date range (max 90 days) to review automation executions and ignored events."
    text.RuleMetricsFrom -> "From"
    text.RuleMetricsTo -> "To"
    text.RuleMetricsQuickRange -> "Quick range:"
    text.RuleMetrics7Days -> "7 days"
    text.RuleMetrics30Days -> "30 days"
    text.RuleMetrics90Days -> "90 days"
    text.RuleMetricsSelectRange -> "Select a date range"
    text.RuleMetricsNoData -> "No execution diagnostics for the selected range"
    text.RuleMetricsRuleCount -> "Rules"
    text.RuleMetricsEvaluated -> "Evaluated"
    text.RuleMetricsNoRules -> "No rules in this engine"
    text.ViewDetails -> "View Details"
    text.OpenTask -> "Open task"
    text.OpenCard -> "Open card"
    text.AgeLabel -> "Age"
    text.ParentCardLabel -> "Card"
    text.RuleMetricsDrilldown -> "Execution details"
    text.SuppressionBreakdown -> "Ignored events"
    text.SuppressionIdempotent -> "Duplicate (already processed)"
    text.SuppressionNotUserTriggered -> "Not user triggered"
    text.SuppressionNotMatching -> "Conditions not matching"
    text.SuppressionInactive -> "Rule inactive"
    text.RecentExecutions -> "Recent Executions"
    text.NoExecutions -> "No executions found"
    text.ProjectExecutionsSelectProject -> "Select a project to see executions."
    text.ProjectExecutionsDiagnostics -> "Diagnostics by engine"
    text.ProjectExecutionsDateColumn -> "Date"
    text.ProjectExecutionsEngineColumn -> "Engine"
    text.ProjectExecutionsRuleColumn -> "Rule"
    text.ProjectExecutionsTemplateColumn -> "Template"
    text.ProjectExecutionsOriginColumn -> "Origin"
    text.ProjectExecutionsOutcomeColumn -> "Outcome"
    text.ProjectExecutionsTaskColumn -> "Task"
    text.FirstPage -> "First page"
    text.PreviousPage -> "Previous page"
    text.NextPage -> "Next page"
    text.LastPage -> "Last page"
    text.Origin -> "Origin"
    text.Outcome -> "Outcome"
    text.Timestamp -> "Timestamp"
    text.OutcomeApplied -> "Created"
    text.OutcomeSuppressed -> "Ignored"

    // Story 3.4 - Member Card Views
    text.MemberCards -> "Plan"
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
    text.CardProgressCount(closed, total) ->
      case total {
        0 -> "No tasks"
        _ -> {
          let task_label = case total {
            1 -> " task"
            _ -> " tasks"
          }

          int.to_string(closed)
          <> " of "
          <> int.to_string(total)
          <> task_label
          <> " closed"
        }
      }

    // Card detail (member)
    text.CardAddTask -> "Add task"
    text.CardAddSubcard -> "Add subcard"
    text.CloseCard -> "Close card"
    text.CloseCardManagerOnly -> "Only managers can close cards."
    text.CloseCardConfirmTitle -> "Close card"
    text.CloseCardConfirmBody ->
      "This will close this card and its subcards. Available tasks will be closed automatically. Tasks already closed will not change."
    text.CardClosed -> "Card closed"
    text.CardCloseFailed -> "Could not close card"
    text.CardReadyToCloseTitle -> "Work already complete"
    text.CardReadyToCloseBody ->
      "All direct tasks are closed. Close the card instead of activating it."
    text.CardEmptyWorkTitle -> "This card has no work yet"
    text.CardEmptyWorkBody ->
      "Choose whether this card will contain tasks or subcards."
    text.CardSummaryNoWorkTitle -> "Define the work"
    text.CardSummaryNoWorkBody ->
      "This card is active but has no direct tasks yet."
    text.CardSummaryBlockedTitle(count) ->
      int.to_string(count) <> " blocking signal"
    text.CardSummaryBlockedBody ->
      "Resolve blockers before expecting healthy flow from this card."
    text.CardSummaryCompleteTitle -> "Work complete"
    text.CardSummaryCompleteBody ->
      "All direct tasks are closed. Review whether the card can be closed."
    text.CardSummaryFlowTitle -> "Work is flowing"
    text.CardSummaryFlowBody ->
      "Direct tasks are defined and no blockers dominate this card."
    text.CardSummaryNoDescription -> "No purpose has been written yet."
    text.CardTasksEmpty -> "No tasks"
    text.CardTasksClosed -> "closed"
    text.TaskType -> "Task type"
    text.NoCard -> "No card"
    text.NewTaskInCard(card_title) -> "Add task to " <> card_title

    // Story 4.4 - Three-panel layout
    // Accessibility labels
    text.MainNavigation -> "Main navigation"
    text.MyActivity -> "My activity"

    // Left panel sections
    text.Work -> "Work"
    text.NewCard -> "New Card"
    text.NoTasksYet -> "No tasks yet"
    text.CardTasksMore(hidden_count) ->
      "+" <> int.to_string(hidden_count) <> " more tasks"
    text.Configuration -> "Configuration"
    text.Team -> "Team"
    // Note: text.Capabilities already translated in Capabilities section
    // Story 4.9: New config nav items
    text.CardsConfig -> "Cards"
    text.TaskTypes -> "Task Types"
    text.ShowEmptyCards -> "Show empty"
    text.ShowClosedCards -> "Show closed"
    text.Organization -> "Organization"
    text.OrgUsers -> "Users"
    text.Invites -> "Invitations"

    // Right panel sections
    text.InProgress -> "In Progress"
    text.Resume -> "Resume"
    text.MyCards -> "Context"
    text.NoTasksClaimedHint -> "Browse Pool to claim a task"
    text.NoCardsAssignedHint -> "View Cards to see available cards"
    text.NoTasksInProgressHint -> "Start a task from My Tasks"

    // Story 5.3: Card notes hovers (AC16-AC22)
    text.NewNotesTooltip -> "There are new notes"
    text.EditCardTooltip -> "Edit card"
    text.DeleteCardTooltip -> "Delete card"
    // AC16: Rich tooltip on [!] indicator
    text.TabNotes -> "Notes"
    text.TabSummary -> "Summary"
    text.TabWork -> "Work"
    text.TabActivity -> "Activity"
    text.ActivityLoading -> "Loading activity..."
    text.ActivityEmpty -> "No activity yet."
    text.ActivityLoadFailed -> "Could not load activity."
    text.ActivityLoadMore(remaining) ->
      "Load more (" <> int.to_string(remaining) <> ")"
    // 5.4.1: Task Show
    text.TabDetails -> "Details"
    text.TabBlockers -> "Blockers"
    text.EditTask -> "Edit task"
    text.TaskUpdated -> "Task updated"
    text.TaskEditPlanning -> "Planning"
    text.TaskEditLocation -> "Location"
    text.TaskEditKeyboardHint -> "Ctrl/Cmd+Enter saves. Esc cancels."
    text.TaskEditRequiresClaim ->
      "You can edit unclaimed tasks, or claim the task to keep editing it while in progress."
    text.TaskEditClosedReadOnly ->
      "Closed tasks are read-only. Reopen or duplicate the work before changing details."
    text.TaskDescriptionEmpty -> "No description yet"
    text.TaskOperationalSummary -> "Operational summary"
    text.TaskOwner -> "Owner"
    text.TaskAutomationOrigin -> "Origin"
    text.TaskAutomationCreatedBy -> "Created by automation"
    text.TaskAutomationEngineLabel(engine_id) ->
      "Engine #" <> int.to_string(engine_id)
    text.TaskAutomationRuleLabel(rule_id) -> "Rule #" <> int.to_string(rule_id)
    text.TaskAutomationRuleChip(rule_id) ->
      "Automation #" <> int.to_string(rule_id)
    text.TaskAutomationRuleSignal(rule_id) ->
      "Created by automation rule #" <> int.to_string(rule_id)
    text.TaskAutomationTemplateLabel(template_id) ->
      "Template #" <> int.to_string(template_id)
    text.TaskAutomationTemplateFallback -> "Template"
    text.TaskAutomationGoToAutomation -> "Go to automation"
    text.TaskAutomationViewEngine -> "View engine"
    text.TaskAutomationViewRule -> "View rule"
    text.TaskAutomationViewTemplate -> "View template"
    text.TaskDueDateLabel -> "Due"
    text.NoDueDate -> "No due date"
    text.TaskBlockingClear -> "No active blockers"
    text.MetricsAvailable -> "Available"
    text.MetricsClaimed -> "Claimed"
    text.MetricsOngoing -> "Ongoing"
    text.ClaimTask -> "Claim task"

    // Error states
    text.ErrorLoadingTasks -> "Error loading tasks"

    // Automations / Rules
    text.BackToAutomations -> "← Back to Automations"
    text.RuleMetricsNoExecutions ->
      "No automation executions found in the selected range."
  }
}

fn card_delete_impact_copy(task_count: Int, subcard_count: Int) -> String {
  case task_count, subcard_count {
    0, 0 -> "This card will be removed from operational views."
    0, _ ->
      "This will remove this card and "
      <> count_label(subcard_count, "subcard", "subcards")
      <> " from operational views."
    _, 0 ->
      "This will remove this card and "
      <> count_label(task_count, "task", "tasks")
      <> " from operational views."
    _, _ ->
      "This will remove this card, "
      <> count_label(subcard_count, "subcard", "subcards")
      <> " and "
      <> count_label(task_count, "task", "tasks")
      <> " from operational views."
  }
}

fn count_label(count: Int, singular: String, plural: String) -> String {
  case count {
    1 -> "1 " <> singular
    _ -> int.to_string(count) <> " " <> plural
  }
}
