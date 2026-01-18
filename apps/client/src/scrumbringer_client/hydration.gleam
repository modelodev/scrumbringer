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
          case role == Admin {
            False -> [
              Redirect(to: router.Member(member_section.Pool, project_id)),
            ]

            True -> {
              let base = case projects {
                NotAsked | Failed -> [FetchProjects]
                _ -> []
              }

              let base = case invite_links {
                NotAsked | Failed -> list.append(base, [FetchInviteLinks])
                _ -> base
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

    router.Member(_section, _project_id) -> {
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
