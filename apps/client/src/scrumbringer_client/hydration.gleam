import gleam/list
import gleam/option.{type Option, Some}

import scrumbringer_client/member_section
import scrumbringer_client/permissions
import scrumbringer_client/router
import scrumbringer_domain/org_role.{type OrgRole, Admin}

pub type ResourceState {
  NotAsked
  Loading
  Loaded
  Failed
}

pub type AuthState {
  Unknown
  Unauthed
  Authed(OrgRole)
}

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
  )
}

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

          case member_tasks {
            NotAsked | Failed -> list.append(base, [RefreshMember])
            Loading | Loaded -> base
          }
        }
      }
    }
  }
}
