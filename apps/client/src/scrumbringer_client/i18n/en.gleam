//// English translations for Scrumbringer UI.
////
//// Provides English (en) translations for all UI text keys defined in text.gleam.

import gleam/int

import scrumbringer_client/i18n/text.{type Text}

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
    text.InviteLinkCreated -> "Invite link created"
    text.InviteLinkRegenerated -> "Invite link regenerated"
    text.RoleUpdated -> "Role updated"
    text.MemberAdded -> "Member added"
    text.MemberRemoved -> "Member removed"
    text.TaskTypeCreated -> "Task type created"
    text.TaskCreated -> "Task created"
    text.TaskClaimed -> "Task claimed"
    text.TaskReleased -> "Task released"
    text.TaskCompleted -> "Task completed"
    text.SkillsSaved -> "Skills saved"
    text.NoteAdded -> "Note added"

    // Validation
    text.NameRequired -> "Name is required"
    text.TitleRequired -> "Title is required"
    text.TypeRequired -> "Type is required"
    text.SelectProjectFirst -> "Select a project first"
    text.SelectUserFirst -> "Select a user first"
    text.InvalidXY -> "Invalid x/y"
    text.ContentRequired -> "Content required"

    text.Copied -> "Copied"
    text.Copying -> "Copying…"
    text.CopyFailed -> "Copy failed"

    // Common
    text.Dismiss -> "Dismiss"
    text.Cancel -> "Cancel"
    text.Close -> "Close"
    text.Create -> "Create"
    text.Creating -> "Creating…"
    text.Copy -> "Copy"
    text.Save -> "Save"
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
    text.NoneOption -> "None"
    text.Start -> "Start"
    text.LoggingIn -> "Logging in…"
    text.Loading -> "Loading"
    text.LoadingEllipsis -> "Loading…"

    // Settings controls
    text.ThemeLabel -> "Theme"
    text.ThemeDefault -> "Default"
    text.ThemeDark -> "Dark"
    text.LanguageLabel -> "Language"
    text.LanguageEs -> "Spanish"
    text.LanguageEn -> "English"

    // Member sections
    text.Pool -> "Pool"
    text.MyBar -> "My Bar"
    text.MySkills -> "My Skills"
    text.MyTasks -> "My tasks"
    text.NoClaimedTasks -> "No claimed tasks"
    text.NoProjectsBody -> "Ask an admin to add you to a project."
    text.You -> "You"
    text.Notes -> "Notes"
    text.AddNote -> "Add note"
    text.EditPosition -> "Edit position"
    text.XLabel -> "x"
    text.YLabel -> "y"

    // Member pool controls
    text.ViewCanvas -> "View: canvas"
    text.ViewList -> "View: list"
    text.Canvas -> "Canvas"
    text.List -> "List"
    text.ShowFilters -> "Show filters"
    text.HideFilters -> "Hide filters"
    text.NewTask -> "New task"
    text.Description -> "Description"
    text.Priority -> "Priority"
    text.NewTaskShortcut -> "New task (n)"
    text.AllOption -> "All"
    text.SelectType -> "Select type"
    text.MyCapabilitiesOn -> "ON"
    text.MyCapabilitiesOff -> "OFF"
    text.TypeLabel -> "Type"
    text.CapabilityLabel -> "Capability"
    text.MyCapabilitiesLabel -> "My capabilities"
    text.SearchLabel -> "Search"
    text.SearchPlaceholder -> "q"
    text.NoAvailableTasksRightNow -> "No available tasks right now"
    text.CreateFirstTaskToStartUsingPool ->
      "Create your first task to start using the Pool."
    text.NoTasksMatchYourFilters -> "No tasks match your filters"
    text.TypeNumber(type_id) -> "Type #" <> int.to_string(type_id)
    text.MetaType -> "type: "
    text.MetaPriority -> "priority: "
    text.MetaCreated -> "created: "
    text.PriorityShort(priority) -> "P" <> int.to_string(priority)
    text.Claim -> "Claim"
    text.Drag -> "Drag"
    text.StartNowWorking -> "Start now working"
    text.PauseNowWorking -> "Pause now working"

    // Now working
    text.NowWorking -> "Now Working"
    text.NowWorkingLoading -> "Now Working: loading…"
    text.NowWorkingNone -> "Now Working: none"
    text.NowWorkingErrorPrefix -> "Now Working error: "
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
    text.AdminProjects -> "Projects"
    text.AdminMetrics -> "Metrics"
    text.AdminMembers -> "Members"
    text.AdminCapabilities -> "Capabilities"
    text.AdminTaskTypes -> "Task Types"
    text.NoAdminPermissions -> "No admin permissions"
    text.NotPermitted -> "Not permitted"
    text.NotPermittedBody -> "You don't have permission to access this section."

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
    text.Completed -> "Completed"
    text.MetricsOverview -> "Metrics Overview"
    text.LoadingOverview -> "Loading overview…"
    text.ReleasePercent -> "Release %"
    text.FlowPercent -> "Flow %"
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
    text.OrgRole -> "Org Role"

    // Invite links
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

    // Projects
    text.Projects -> "Projects"
    text.CreateProject -> "Create Project"
    text.Name -> "Name"
    text.MyRole -> "My Role"
    text.NoProjectsYet -> "No projects yet"

    // Capabilities
    text.Capabilities -> "Capabilities"
    text.CreateCapability -> "Create Capability"
    text.NoCapabilitiesYet -> "No capabilities yet"

    // Members
    text.SelectProjectToManageMembers -> "Select a project to manage members."
    text.MembersTitle(project_name) -> "Members - " <> project_name
    text.AddMember -> "Add member"
    text.NoMembersYet -> "No members yet"
    text.RemoveMemberTitle -> "Remove member"
    text.RemoveMemberConfirm(user_email, project_name) ->
      "Remove " <> user_email <> " from " <> project_name <> "?"
    text.Remove -> "Remove"

    // Task types
    text.SelectProjectToManageTaskTypes ->
      "Select a project to manage task types."
    text.TaskTypesTitle(project_name) -> "Task Types - " <> project_name
    text.CreateTaskType -> "Create Task Type"
    text.Icon -> "Icon"
    text.UnknownIcon -> "Unknown icon"
    text.CapabilityOptional -> "Capability (optional)"
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
    text.CardState -> "State"
    text.CardStatePendiente -> "Pending"
    text.CardStateEnCurso -> "In Progress"
    text.CardStateCerrada -> "Closed"
    text.CardTasks -> "Tasks"
    text.CardProgress -> "Progress"
    text.CardCreated -> "Card created"
    text.CardUpdated -> "Card updated"
    text.CardDeleted -> "Card deleted"
    text.CardDeleteBlocked -> "Cannot delete: has tasks"
    text.CardDeleteConfirm(card_title) -> "Delete card \"" <> card_title <> "\"?"
    text.NoCardsYet -> "No cards yet"
    text.CardTaskCount(completed, total) ->
      int.to_string(completed) <> "/" <> int.to_string(total)
  }
}
