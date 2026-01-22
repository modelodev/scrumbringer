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

import scrumbringer_client/member_section
import scrumbringer_client/permissions
import scrumbringer_client/router
import domain/org_role.{type OrgRole, Admin}

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
    members: ResourceState,
    members_project_id: Option(Int),
    task_types: ResourceState,
    task_types_project_id: Option(Int),
    member_tasks: ResourceState,
    active_task: ResourceState,
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
  FetchMembers(project_id: Int)
  FetchTaskTypes(project_id: Int)
  RefreshMember
  FetchActiveTask
  FetchMeMetrics
  FetchOrgMetricsOverview
  FetchOrgMetricsProjectTasks(project_id: Int)
  Redirect(to: router.Route)
}

pub fn plan(route: router.Route, snapshot: Snapshot) -> List(Command) {
  let Snapshot(
    auth: auth,
    projects: projects,
    is_any_project_manager: is_any_project_manager,
    invite_links: invite_links,
    capabilities: capabilities,
    my_capability_ids: my_capability_ids,
    org_settings_users: org_settings_users,
    members: members,
    members_project_id: members_project_id,
    task_types: task_types,
    task_types_project_id: task_types_project_id,
    member_tasks: member_tasks,
    active_task: active_task,
    me_metrics: me_metrics,
    org_metrics_overview: org_metrics_overview,
    org_metrics_project_tasks: org_metrics_project_tasks,
    org_metrics_project_id: org_metrics_project_id,
  ) = snapshot

  case route {
    router.AcceptInvite(_) | router.ResetPassword(_) -> []

    router.Login ->
      case auth {
        Unknown -> [FetchMe]
        _ -> []
      }

    router.Admin(section, project_id) -> {
      case auth {
        Unknown -> [FetchMe]
        Unauthed -> [Redirect(to: router.Login)]
        Authed(role) -> {
          // Check access based on org role and project manager status
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
            False -> is_org_admin || is_any_project_manager
          }

          // If projects not loaded yet, we can't determine PM status
          // Fetch projects first before deciding to redirect
          let needs_projects_to_decide =
            !is_org_admin && !is_org_level_section && projects != Loaded

          case needs_projects_to_decide {
            True -> [FetchProjects]
            False ->
              case has_access {
                False -> [
                  Redirect(to: router.Member(
                    member_section.Pool,
                    project_id,
                    None,
                  )),
                ]
                True -> {
                  let base = case projects {
                    NotAsked | Failed -> [FetchProjects]
                    _ -> []
                  }

                  let base = case is_org_admin, invite_links {
                    True, NotAsked | True, Failed ->
                      list.append(base, [FetchInviteLinks])
                    _, _ -> base
                  }

                  let base = case capabilities {
                    NotAsked | Failed -> list.append(base, [FetchCapabilities])
                    _ -> base
                  }

                  case section {
                    permissions.Members ->
                      case project_id, projects {
                        Some(id), Loaded ->
                          case members, members_project_id {
                            Loading, _ -> base
                            Loaded, Some(pid) if pid == id -> base
                            _, _ ->
                              list.append(base, [FetchMembers(project_id: id)])
                          }

                        _, _ -> base
                      }

                    permissions.TaskTypes ->
                      case project_id, projects {
                        Some(id), Loaded ->
                          case task_types, task_types_project_id {
                            Loading, _ -> base
                            Loaded, Some(pid) if pid == id -> base
                            _, _ ->
                              list.append(base, [FetchTaskTypes(project_id: id)])
                          }

                        _, _ -> base
                      }

                    permissions.OrgSettings ->
                      case org_settings_users {
                        NotAsked | Failed ->
                          list.append(base, [FetchOrgSettingsUsers])
                        _ -> base
                      }

                    permissions.Metrics -> {
                      let base = case org_metrics_overview {
                        NotAsked | Failed ->
                          list.append(base, [FetchOrgMetricsOverview])
                        _ -> base
                      }

                      case project_id {
                        Some(id) ->
                          case org_metrics_project_tasks, org_metrics_project_id {
                            Loading, _ -> base
                            Loaded, Some(pid) if pid == id -> base
                            _, _ ->
                              list.append(base, [
                                FetchOrgMetricsProjectTasks(project_id: id),
                              ])
                          }

                        None -> base
                      }
                    }

                    _ -> base
                  }
                }
              }
          }
        }
      }
    }

    router.Member(_section, _project_id, _view_mode) -> {
      case auth {
        Unknown -> [FetchMe]
        Unauthed -> [Redirect(to: router.Login)]

        Authed(_role) -> {
          let base = case projects {
            NotAsked | Failed -> [FetchProjects]
            _ -> []
          }

          let base = case capabilities {
            NotAsked | Failed -> list.append(base, [FetchCapabilities])
            _ -> base
          }

          let base = case my_capability_ids {
            NotAsked | Failed -> list.append(base, [FetchMeCapabilityIds])
            _ -> base
          }

          let base = case active_task {
            NotAsked | Failed -> list.append(base, [FetchActiveTask])
            _ -> base
          }

          let base = case me_metrics {
            NotAsked | Failed -> list.append(base, [FetchMeMetrics])
            _ -> base
          }

          case member_tasks {
            NotAsked | Failed -> list.append(base, [RefreshMember])
            Loading | Loaded -> base
          }
        }
      }
    }
  }
}
