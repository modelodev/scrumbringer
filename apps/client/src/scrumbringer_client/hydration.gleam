//// Hydration logic for client state management.
////
//// ## Mission
////
//// Computes the minimal set of API calls needed when navigating routes,
//// avoiding redundant fetches by comparing current snapshot to requirements.
////
//// ## Responsibilities
////
//// - Model snapshot extraction for comparing resource states
//// - Route-based resource requirement planning
//// - Efficient fetch command generation (only what's missing/stale)
////
//// ## Non-responsibilities
////
//// - HTTP requests (see `api.gleam`)
//// - State transitions (see `client_update.gleam`)

import gleam/list
import gleam/option.{type Option, None, Some}

import domain/org_role.{type OrgRole, Admin}
import scrumbringer_client/member_section
import scrumbringer_client/permissions.{type AdminSection}
import scrumbringer_client/router

/// Loading state for a resource (simplified from Remote for snapshot comparison).
pub type ResourceState {
  NotAsked
  Loading
  Loaded
  Failed
}

/// Authentication state for hydration decisions.
pub type AuthState {
  Unknown
  Unauthed
  Authed(OrgRole)
}

/// Snapshot of current model state for hydration planning.
pub type Snapshot {
  Snapshot(
    auth: AuthState,
    projects: ResourceState,
    /// True if user is a project manager on any project (only valid when projects: Loaded)
    is_any_project_manager: Bool,
    invite_links: ResourceState,
    capabilities: ResourceState,
    my_capability_ids: ResourceState,
    org_settings_users: ResourceState,
    org_users_cache: ResourceState,
    members: ResourceState,
    members_project_id: Option(Int),
    task_types: ResourceState,
    task_types_project_id: Option(Int),
    member_tasks: ResourceState,
    work_sessions: ResourceState,
    me_metrics: ResourceState,
    org_metrics_overview: ResourceState,
    org_metrics_project_tasks: ResourceState,
    org_metrics_project_id: Option(Int),
  )
}

/// Command to execute during hydration (API fetch or redirect).
pub type Command {
  FetchMe
  FetchProjects
  FetchInviteLinks
  FetchCapabilities
  FetchMeCapabilityIds
  FetchOrgSettingsUsers
  FetchOrgUsersCache
  FetchMembers(project_id: Int)
  FetchTaskTypes(project_id: Int)
  RefreshMember
  FetchWorkSessions
  FetchMeMetrics
  FetchOrgMetricsOverview
  FetchOrgMetricsProjectTasks(project_id: Int)
  Redirect(to: router.Route)
}

// ----------------------------------------------------------------------------
// Helpers for declarative hydration
// ----------------------------------------------------------------------------

/// Returns True if resource needs fetching (not asked or failed).
fn needs_fetch(state: ResourceState) -> Bool {
  case state {
    NotAsked | Failed -> True
    Loading | Loaded -> False
  }
}

/// Returns True if a project-scoped resource needs fetching for target_id.
fn needs_project_fetch(
  state: ResourceState,
  loaded_id: Option(Int),
  target_id: Option(Int),
) -> Bool {
  case state, loaded_id, target_id {
    Loading, _, _ -> False
    Loaded, Some(lid), Some(tid) if lid == tid -> False
    _, _, Some(_) -> True
    _, _, None -> False
  }
}

/// Collects commands from a list of (condition, command) pairs.
fn collect(requirements: List(#(Bool, Command))) -> List(Command) {
  list.flat_map(requirements, fn(req) {
    case req.0 {
      True -> [req.1]
      False -> []
    }
  })
}

/// Provides plan.
///
/// Example:
///   plan(...)
pub fn plan(route: router.Route, snap: Snapshot) -> List(Command) {
  case route {
    router.AcceptInvite(_) | router.ResetPassword(_) -> []
    router.Login -> plan_login(snap)
    router.Config(section, project_id) -> plan_admin(snap, section, project_id)
    router.Org(section) -> plan_org(snap, section)
    router.Member(_, _, _) -> plan_member(snap)
  }
}

// ----------------------------------------------------------------------------
// Route-specific hydration planners
// ----------------------------------------------------------------------------

fn plan_login(snap: Snapshot) -> List(Command) {
  case snap.auth {
    Unknown -> [FetchMe]
    _ -> []
  }
}

fn plan_admin(
  snap: Snapshot,
  section: AdminSection,
  project_id: Option(Int),
) -> List(Command) {
  case snap.auth {
    Unknown -> [FetchMe]
    Unauthed -> [Redirect(to: router.Login)]
    Authed(role) -> plan_admin_authed(snap, section, project_id, role)
  }
}

// Justification: nested case improves clarity for branching logic.
fn plan_admin_authed(
  snap: Snapshot,
  section: AdminSection,
  project_id: Option(Int),
  role: OrgRole,
) -> List(Command) {
  let is_org_admin = role == Admin
  let is_org_level_section = case section {
    permissions.Invites
    | permissions.OrgSettings
    | permissions.Projects
    | permissions.Metrics -> True
    _ -> False
  }

  // Org-level sections: only org admin
  // Project-scoped sections: org admin OR any project manager
  let has_access = case is_org_level_section {
    True -> is_org_admin
    False -> is_org_admin || snap.is_any_project_manager
  }

  // If projects not loaded yet, we can't determine PM status
  let needs_projects_to_decide =
    !is_org_admin && !is_org_level_section && snap.projects != Loaded

  case needs_projects_to_decide {
    True -> [FetchProjects]
    False ->
      case has_access {
        False -> [
          Redirect(to: router.Member(member_section.Pool, project_id, None)),
        ]
        True -> plan_admin_with_access(snap, section, project_id, is_org_admin)
      }
  }
}

fn plan_admin_with_access(
  snap: Snapshot,
  section: AdminSection,
  project_id: Option(Int),
  is_org_admin: Bool,
) -> List(Command) {
  // Base resources for admin/config routes
  let base =
    collect([
      #(needs_fetch(snap.projects), FetchProjects),
      #(is_org_admin && needs_fetch(snap.invite_links), FetchInviteLinks),
      #(needs_fetch(snap.capabilities), FetchCapabilities),
      #(needs_fetch(snap.me_metrics), FetchMeMetrics),
      #(needs_fetch(snap.work_sessions), FetchWorkSessions),
    ])

  // Section-specific resources
  let section_cmds = case section, project_id, snap.projects {
    permissions.Members, Some(id), Loaded ->
      collect([
        #(
          needs_project_fetch(snap.members, snap.members_project_id, Some(id)),
          FetchMembers(project_id: id),
        ),
      ])

    permissions.TaskTypes, Some(id), Loaded ->
      collect([
        #(
          needs_project_fetch(
            snap.task_types,
            snap.task_types_project_id,
            Some(id),
          ),
          FetchTaskTypes(project_id: id),
        ),
      ])

    permissions.OrgSettings, _, _ ->
      collect([#(needs_fetch(snap.org_settings_users), FetchOrgSettingsUsers)])

    permissions.Metrics, _, _ -> {
      let overview =
        collect([
          #(needs_fetch(snap.org_metrics_overview), FetchOrgMetricsOverview),
        ])
      let project_tasks = case project_id {
        Some(id) ->
          collect([
            #(
              needs_project_fetch(
                snap.org_metrics_project_tasks,
                snap.org_metrics_project_id,
                Some(id),
              ),
              FetchOrgMetricsProjectTasks(project_id: id),
            ),
          ])
        None -> []
      }
      list.append(overview, project_tasks)
    }

    _, _, _ -> []
  }

  list.append(base, section_cmds)
}

fn plan_org(snap: Snapshot, section: AdminSection) -> List(Command) {
  case snap.auth {
    Unknown -> [FetchMe]
    Unauthed -> [Redirect(to: router.Login)]
    Authed(role) -> plan_org_for_role(snap, section, role)
  }
}

fn plan_org_for_role(
  snap: Snapshot,
  section: AdminSection,
  role: OrgRole,
) -> List(Command) {
  case role == Admin {
    False -> [Redirect(to: router.Member(member_section.Pool, None, None))]
    True -> plan_org_for_admin(snap, section)
  }
}

fn plan_org_for_admin(snap: Snapshot, section: AdminSection) -> List(Command) {
  let base =
    collect([
      #(needs_fetch(snap.projects), FetchProjects),
      #(needs_fetch(snap.invite_links), FetchInviteLinks),
      #(needs_fetch(snap.capabilities), FetchCapabilities),
      #(needs_fetch(snap.me_metrics), FetchMeMetrics),
      #(needs_fetch(snap.work_sessions), FetchWorkSessions),
    ])

  let section_cmds = case section {
    permissions.OrgSettings ->
      collect([
        #(needs_fetch(snap.org_settings_users), FetchOrgSettingsUsers),
      ])
    permissions.Metrics ->
      collect([
        #(needs_fetch(snap.org_metrics_overview), FetchOrgMetricsOverview),
      ])
    _ -> []
  }

  list.append(base, section_cmds)
}

fn plan_member(snap: Snapshot) -> List(Command) {
  case snap.auth {
    Unknown -> [FetchMe]
    Unauthed -> [Redirect(to: router.Login)]
    Authed(_) ->
      collect([
        #(needs_fetch(snap.projects), FetchProjects),
        #(needs_fetch(snap.capabilities), FetchCapabilities),
        #(needs_fetch(snap.my_capability_ids), FetchMeCapabilityIds),
        #(needs_fetch(snap.work_sessions), FetchWorkSessions),
        #(needs_fetch(snap.me_metrics), FetchMeMetrics),
        #(needs_fetch(snap.org_users_cache), FetchOrgUsersCache),
        #(needs_fetch(snap.member_tasks), RefreshMember),
      ])
  }
}
