import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option as opt
import gleam/result
import gleam/string

import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html.{
  button, div, form, h1, h2, h3, hr, img, input, label, option, p, select, span,
  table, tbody, td, text, th, thead, tr,
}
import lustre/event

import scrumbringer_domain/user.{type User}

import scrumbringer_client/api
import scrumbringer_client/permissions

pub fn main() -> lustre.App(Nil, Model, Msg) {
  lustre.application(init, update, view)
}

type Remote(a) {
  NotAsked
  Loading
  Loaded(a)
  Failed(api.ApiError)
}

type Page {
  Login
  Admin
}

type IconPreview {
  IconIdle
  IconLoading
  IconOk
  IconError
}

pub opaque type Model {
  Model(
    page: Page,
    user: opt.Option(User),
    active_section: permissions.AdminSection,
    toast: opt.Option(String),
    login_email: String,
    login_password: String,
    login_error: opt.Option(String),
    login_in_flight: Bool,
    projects: Remote(List(api.Project)),
    selected_project_id: opt.Option(Int),
    invites_expires_in_hours: String,
    invites_in_flight: Bool,
    invites_error: opt.Option(String),
    last_invite: opt.Option(api.OrgInvite),
    invite_copy_status: opt.Option(String),
    projects_create_name: String,
    projects_create_in_flight: Bool,
    projects_create_error: opt.Option(String),
    capabilities: Remote(List(api.Capability)),
    capabilities_create_name: String,
    capabilities_create_in_flight: Bool,
    capabilities_create_error: opt.Option(String),
    members: Remote(List(api.ProjectMember)),
    org_users_cache: Remote(List(api.OrgUser)),
    members_add_dialog_open: Bool,
    members_add_selected_user: opt.Option(api.OrgUser),
    members_add_role: String,
    members_add_in_flight: Bool,
    members_add_error: opt.Option(String),
    members_remove_confirm: opt.Option(api.OrgUser),
    members_remove_in_flight: Bool,
    members_remove_error: opt.Option(String),
    org_users_search_query: String,
    org_users_search_results: Remote(List(api.OrgUser)),
    task_types: Remote(List(api.TaskType)),
    task_types_create_name: String,
    task_types_create_icon: String,
    task_types_create_capability_id: opt.Option(String),
    task_types_create_in_flight: Bool,
    task_types_create_error: opt.Option(String),
    task_types_icon_preview: IconPreview,
  )
}

pub type Msg {
  MeFetched(api.ApiResult(User))

  LoginEmailChanged(String)
  LoginPasswordChanged(String)
  LoginSubmitted
  LoginFinished(api.ApiResult(User))

  LogoutClicked
  LogoutFinished(api.ApiResult(Nil))

  ToastDismissed

  NavSelected(permissions.AdminSection)
  ProjectSelected(String)

  ProjectsFetched(api.ApiResult(List(api.Project)))
  ProjectCreateNameChanged(String)
  ProjectCreateSubmitted
  ProjectCreated(api.ApiResult(api.Project))

  InvitesExpiresChanged(String)
  InviteCreateSubmitted
  InviteCreated(api.ApiResult(api.OrgInvite))
  InviteCopyClicked
  InviteCopyFinished(Bool)

  CapabilitiesFetched(api.ApiResult(List(api.Capability)))
  CapabilityCreateNameChanged(String)
  CapabilityCreateSubmitted
  CapabilityCreated(api.ApiResult(api.Capability))

  MembersFetched(api.ApiResult(List(api.ProjectMember)))
  OrgUsersCacheFetched(api.ApiResult(List(api.OrgUser)))

  MemberAddDialogOpened
  MemberAddDialogClosed
  MemberAddRoleChanged(String)
  MemberAddUserSelected(Int)
  MemberAddSubmitted
  MemberAdded(api.ApiResult(api.ProjectMember))

  MemberRemoveClicked(Int)
  MemberRemoveCancelled
  MemberRemoveConfirmed
  MemberRemoved(api.ApiResult(Nil))

  OrgUsersSearchChanged(String)
  OrgUsersSearchDebounced(String)
  OrgUsersSearchResults(api.ApiResult(List(api.OrgUser)))

  TaskTypesFetched(api.ApiResult(List(api.TaskType)))
  TaskTypeCreateNameChanged(String)
  TaskTypeCreateIconChanged(String)
  TaskTypeIconLoaded
  TaskTypeIconErrored
  TaskTypeCreateCapabilityChanged(String)
  TaskTypeCreateSubmitted
  TaskTypeCreated(api.ApiResult(api.TaskType))
}

fn init(_flags: Nil) -> #(Model, Effect(Msg)) {
  let model =
    Model(
      page: Login,
      user: opt.None,
      active_section: permissions.Invites,
      toast: opt.None,
      login_email: "",
      login_password: "",
      login_error: opt.None,
      login_in_flight: False,
      projects: NotAsked,
      selected_project_id: opt.None,
      invites_expires_in_hours: "168",
      invites_in_flight: False,
      invites_error: opt.None,
      last_invite: opt.None,
      invite_copy_status: opt.None,
      projects_create_name: "",
      projects_create_in_flight: False,
      projects_create_error: opt.None,
      capabilities: NotAsked,
      capabilities_create_name: "",
      capabilities_create_in_flight: False,
      capabilities_create_error: opt.None,
      members: NotAsked,
      org_users_cache: NotAsked,
      members_add_dialog_open: False,
      members_add_selected_user: opt.None,
      members_add_role: "member",
      members_add_in_flight: False,
      members_add_error: opt.None,
      members_remove_confirm: opt.None,
      members_remove_in_flight: False,
      members_remove_error: opt.None,
      org_users_search_query: "",
      org_users_search_results: NotAsked,
      task_types: NotAsked,
      task_types_create_name: "",
      task_types_create_icon: "",
      task_types_create_capability_id: opt.None,
      task_types_create_in_flight: False,
      task_types_create_error: opt.None,
      task_types_icon_preview: IconIdle,
    )

  #(model, api.fetch_me(MeFetched))
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    MeFetched(Ok(user)) -> {
      let model = Model(..model, page: Admin, user: opt.Some(user))
      let #(model, effect) = bootstrap_admin(model)
      #(model, effect)
    }

    MeFetched(Error(err)) -> {
      case err.status == 401 {
        True -> #(Model(..model, page: Login, user: opt.None), effect.none())
        False -> #(
          Model(
            ..model,
            page: Login,
            user: opt.None,
            login_error: opt.Some(err.message),
          ),
          effect.none(),
        )
      }
    }

    LoginEmailChanged(email) -> #(
      Model(..model, login_email: email),
      effect.none(),
    )

    LoginPasswordChanged(password) -> #(
      Model(..model, login_password: password),
      effect.none(),
    )

    LoginSubmitted -> {
      case model.login_in_flight {
        True -> #(model, effect.none())
        False -> {
          let model =
            Model(
              ..model,
              login_in_flight: True,
              login_error: opt.None,
              toast: opt.None,
            )
          #(
            model,
            api.login(model.login_email, model.login_password, LoginFinished),
          )
        }
      }
    }

    LoginFinished(Ok(user)) -> {
      let model =
        Model(
          ..model,
          page: Admin,
          user: opt.Some(user),
          login_in_flight: False,
          login_password: "",
          toast: opt.Some("Logged in"),
        )

      let #(model, effect) = bootstrap_admin(model)
      #(model, effect)
    }

    LoginFinished(Error(err)) -> {
      let message = case err.status == 401 {
        True -> "Invalid credentials"
        False -> err.message
      }

      #(
        Model(..model, login_in_flight: False, login_error: opt.Some(message)),
        effect.none(),
      )
    }

    LogoutClicked -> #(
      Model(..model, toast: opt.None),
      api.logout(LogoutFinished),
    )

    LogoutFinished(Ok(_)) -> #(
      Model(..model, page: Login, user: opt.None, toast: opt.Some("Logged out")),
      effect.none(),
    )

    LogoutFinished(Error(err)) -> {
      case err.status == 401 {
        True -> #(Model(..model, page: Login, user: opt.None), effect.none())
        False -> #(
          Model(..model, toast: opt.Some("Logout failed")),
          effect.none(),
        )
      }
    }

    ToastDismissed -> #(Model(..model, toast: opt.None), effect.none())

    NavSelected(section) -> {
      let model = Model(..model, active_section: section, toast: opt.None)
      refresh_section(model)
    }

    ProjectSelected(project_id) -> {
      case string.trim(project_id) == "" {
        True ->
          refresh_section(
            Model(..model, selected_project_id: opt.None, toast: opt.None),
          )
        False -> {
          case int.parse(project_id) {
            Ok(id) ->
              refresh_section(
                Model(
                  ..model,
                  selected_project_id: opt.Some(id),
                  toast: opt.None,
                ),
              )
            Error(_) -> #(
              Model(..model, selected_project_id: opt.None),
              effect.none(),
            )
          }
        }
      }
    }

    ProjectsFetched(Ok(projects)) -> {
      let selected =
        ensure_selected_project(model.selected_project_id, projects)
      let model =
        Model(
          ..model,
          projects: Loaded(projects),
          selected_project_id: selected,
        )

      let model = ensure_default_section(model)

      #(model, effect.none())
    }

    ProjectsFetched(Error(err)) -> {
      case err.status == 401 {
        True -> #(Model(..model, page: Login, user: opt.None), effect.none())
        False -> #(Model(..model, projects: Failed(err)), effect.none())
      }
    }

    ProjectCreateNameChanged(name) -> #(
      Model(..model, projects_create_name: name),
      effect.none(),
    )

    ProjectCreateSubmitted -> {
      case model.projects_create_in_flight {
        True -> #(model, effect.none())
        False -> {
          let name = string.trim(model.projects_create_name)

          case name == "" {
            True -> #(
              Model(
                ..model,
                projects_create_error: opt.Some("Name is required"),
              ),
              effect.none(),
            )
            False -> {
              let model =
                Model(
                  ..model,
                  projects_create_in_flight: True,
                  projects_create_error: opt.None,
                )
              #(model, api.create_project(name, ProjectCreated))
            }
          }
        }
      }
    }

    ProjectCreated(Ok(project)) -> {
      let updated_projects = case model.projects {
        Loaded(projects) -> [project, ..projects]
        _ -> [project]
      }

      #(
        Model(
          ..model,
          projects: Loaded(updated_projects),
          selected_project_id: opt.Some(project.id),
          projects_create_in_flight: False,
          projects_create_name: "",
          toast: opt.Some("Project created"),
        ),
        effect.none(),
      )
    }

    ProjectCreated(Error(err)) -> {
      case err.status {
        401 -> #(Model(..model, page: Login, user: opt.None), effect.none())
        403 -> #(
          Model(
            ..model,
            projects_create_in_flight: False,
            projects_create_error: opt.Some("Not permitted"),
            toast: opt.Some("Not permitted"),
          ),
          effect.none(),
        )
        _ -> #(
          Model(
            ..model,
            projects_create_in_flight: False,
            projects_create_error: opt.Some(err.message),
          ),
          effect.none(),
        )
      }
    }

    InvitesExpiresChanged(value) -> #(
      Model(..model, invites_expires_in_hours: value),
      effect.none(),
    )

    InviteCreateSubmitted -> {
      case model.invites_in_flight {
        True -> #(model, effect.none())
        False -> {
          let hours_str = string.trim(model.invites_expires_in_hours)

          let maybe_hours = case hours_str == "" {
            True -> Ok(opt.None)
            False -> int.parse(hours_str) |> result.map(opt.Some)
          }

          case maybe_hours {
            Ok(value) -> {
              let model =
                Model(
                  ..model,
                  invites_in_flight: True,
                  invites_error: opt.None,
                  invite_copy_status: opt.None,
                )
              #(model, api.create_invite(value, InviteCreated))
            }
            Error(_) -> #(
              Model(
                ..model,
                invites_error: opt.Some("expires_in_hours must be a number"),
              ),
              effect.none(),
            )
          }
        }
      }
    }

    InviteCreated(Ok(invite)) -> {
      #(
        Model(
          ..model,
          invites_in_flight: False,
          last_invite: opt.Some(invite),
          toast: opt.Some("Invite created"),
        ),
        effect.none(),
      )
    }

    InviteCreated(Error(err)) -> {
      case err.status {
        401 -> #(Model(..model, page: Login, user: opt.None), effect.none())
        403 -> #(
          Model(
            ..model,
            invites_in_flight: False,
            invites_error: opt.Some("Not permitted"),
            toast: opt.Some("Not permitted"),
          ),
          effect.none(),
        )
        _ -> #(
          Model(
            ..model,
            invites_in_flight: False,
            invites_error: opt.Some(err.message),
          ),
          effect.none(),
        )
      }
    }

    InviteCopyClicked -> {
      case model.last_invite {
        opt.None -> #(model, effect.none())
        opt.Some(invite) -> #(
          Model(..model, invite_copy_status: opt.Some("Copying...")),
          copy_to_clipboard(invite.code, InviteCopyFinished),
        )
      }
    }

    InviteCopyFinished(ok) -> {
      let message = case ok {
        True -> "Copied"
        False -> "Copy failed"
      }
      #(Model(..model, invite_copy_status: opt.Some(message)), effect.none())
    }

    CapabilitiesFetched(Ok(capabilities)) -> #(
      Model(..model, capabilities: Loaded(capabilities)),
      effect.none(),
    )

    CapabilitiesFetched(Error(err)) -> {
      case err.status == 401 {
        True -> #(Model(..model, page: Login, user: opt.None), effect.none())
        False -> #(Model(..model, capabilities: Failed(err)), effect.none())
      }
    }

    CapabilityCreateNameChanged(name) -> #(
      Model(..model, capabilities_create_name: name),
      effect.none(),
    )

    CapabilityCreateSubmitted -> {
      case model.capabilities_create_in_flight {
        True -> #(model, effect.none())
        False -> {
          let name = string.trim(model.capabilities_create_name)

          case name == "" {
            True -> #(
              Model(
                ..model,
                capabilities_create_error: opt.Some("Name is required"),
              ),
              effect.none(),
            )
            False -> {
              let model =
                Model(
                  ..model,
                  capabilities_create_in_flight: True,
                  capabilities_create_error: opt.None,
                )
              #(model, api.create_capability(name, CapabilityCreated))
            }
          }
        }
      }
    }

    CapabilityCreated(Ok(capability)) -> {
      let updated = case model.capabilities {
        Loaded(capabilities) -> [capability, ..capabilities]
        _ -> [capability]
      }

      #(
        Model(
          ..model,
          capabilities: Loaded(updated),
          capabilities_create_in_flight: False,
          capabilities_create_name: "",
          toast: opt.Some("Capability created"),
        ),
        effect.none(),
      )
    }

    CapabilityCreated(Error(err)) -> {
      case err.status {
        401 -> #(Model(..model, page: Login, user: opt.None), effect.none())
        403 -> #(
          Model(
            ..model,
            capabilities_create_in_flight: False,
            capabilities_create_error: opt.Some("Not permitted"),
            toast: opt.Some("Not permitted"),
          ),
          effect.none(),
        )
        _ -> #(
          Model(
            ..model,
            capabilities_create_in_flight: False,
            capabilities_create_error: opt.Some(err.message),
          ),
          effect.none(),
        )
      }
    }

    MembersFetched(Ok(members)) -> #(
      Model(..model, members: Loaded(members)),
      effect.none(),
    )

    MembersFetched(Error(err)) -> {
      case err.status == 401 {
        True -> #(Model(..model, page: Login, user: opt.None), effect.none())
        False -> #(Model(..model, members: Failed(err)), effect.none())
      }
    }

    OrgUsersCacheFetched(Ok(users)) -> #(
      Model(..model, org_users_cache: Loaded(users)),
      effect.none(),
    )

    OrgUsersCacheFetched(Error(err)) -> {
      case err.status == 401 {
        True -> #(Model(..model, page: Login, user: opt.None), effect.none())
        False -> #(Model(..model, org_users_cache: Failed(err)), effect.none())
      }
    }

    MemberAddDialogOpened -> {
      #(
        Model(
          ..model,
          members_add_dialog_open: True,
          members_add_selected_user: opt.None,
          members_add_error: opt.None,
          org_users_search_query: "",
          org_users_search_results: NotAsked,
        ),
        effect.none(),
      )
    }

    MemberAddDialogClosed -> {
      #(
        Model(
          ..model,
          members_add_dialog_open: False,
          members_add_selected_user: opt.None,
          members_add_error: opt.None,
          org_users_search_query: "",
          org_users_search_results: NotAsked,
        ),
        effect.none(),
      )
    }

    MemberAddRoleChanged(role) -> #(
      Model(..model, members_add_role: role),
      effect.none(),
    )

    MemberAddUserSelected(user_id) -> {
      let selected = case model.org_users_search_results {
        Loaded(users) ->
          case list.find(users, fn(u) { u.id == user_id }) {
            Ok(user) -> opt.Some(user)
            Error(_) -> opt.None
          }

        _ -> opt.None
      }

      #(Model(..model, members_add_selected_user: selected), effect.none())
    }

    MemberAddSubmitted -> {
      case model.members_add_in_flight {
        True -> #(model, effect.none())
        False -> {
          case model.selected_project_id, model.members_add_selected_user {
            opt.Some(project_id), opt.Some(user) -> {
              let model =
                Model(
                  ..model,
                  members_add_in_flight: True,
                  members_add_error: opt.None,
                )
              #(
                model,
                api.add_project_member(
                  project_id,
                  user.id,
                  model.members_add_role,
                  MemberAdded,
                ),
              )
            }

            _, _ -> #(
              Model(..model, members_add_error: opt.Some("Select a user first")),
              effect.none(),
            )
          }
        }
      }
    }

    MemberAdded(Ok(_)) -> {
      let model =
        Model(
          ..model,
          members_add_in_flight: False,
          members_add_dialog_open: False,
          toast: opt.Some("Member added"),
        )
      refresh_section(model)
    }

    MemberAdded(Error(err)) -> {
      case err.status {
        401 -> #(Model(..model, page: Login, user: opt.None), effect.none())
        403 -> #(
          Model(
            ..model,
            members_add_in_flight: False,
            members_add_error: opt.Some("Not permitted"),
            toast: opt.Some("Not permitted"),
          ),
          effect.none(),
        )
        _ -> #(
          Model(
            ..model,
            members_add_in_flight: False,
            members_add_error: opt.Some(err.message),
          ),
          effect.none(),
        )
      }
    }

    MemberRemoveClicked(user_id) -> {
      let maybe_user = resolve_org_user(model.org_users_cache, user_id)

      let user = case maybe_user {
        opt.Some(user) -> user
        opt.None -> fallback_org_user(user_id)
      }

      #(
        Model(
          ..model,
          members_remove_confirm: opt.Some(user),
          members_remove_error: opt.None,
        ),
        effect.none(),
      )
    }

    MemberRemoveCancelled -> #(
      Model(
        ..model,
        members_remove_confirm: opt.None,
        members_remove_error: opt.None,
      ),
      effect.none(),
    )

    MemberRemoveConfirmed -> {
      case model.members_remove_in_flight {
        True -> #(model, effect.none())
        False -> {
          case model.selected_project_id, model.members_remove_confirm {
            opt.Some(project_id), opt.Some(user) -> {
              let model =
                Model(
                  ..model,
                  members_remove_in_flight: True,
                  members_remove_error: opt.None,
                )
              #(
                model,
                api.remove_project_member(project_id, user.id, MemberRemoved),
              )
            }
            _, _ -> #(model, effect.none())
          }
        }
      }
    }

    MemberRemoved(Ok(_)) -> {
      let model =
        Model(
          ..model,
          members_remove_in_flight: False,
          members_remove_confirm: opt.None,
          toast: opt.Some("Member removed"),
        )
      refresh_section(model)
    }

    MemberRemoved(Error(err)) -> {
      case err.status {
        401 -> #(Model(..model, page: Login, user: opt.None), effect.none())
        403 -> #(
          Model(
            ..model,
            members_remove_in_flight: False,
            members_remove_error: opt.Some("Not permitted"),
            toast: opt.Some("Not permitted"),
          ),
          effect.none(),
        )
        _ -> #(
          Model(
            ..model,
            members_remove_in_flight: False,
            members_remove_error: opt.Some(err.message),
          ),
          effect.none(),
        )
      }
    }

    OrgUsersSearchChanged(query) -> #(
      Model(..model, org_users_search_query: query),
      effect.none(),
    )

    OrgUsersSearchDebounced(query) -> {
      case string.trim(query) == "" {
        True -> #(
          Model(..model, org_users_search_results: NotAsked),
          effect.none(),
        )
        False -> {
          let model = Model(..model, org_users_search_results: Loading)
          #(model, api.list_org_users(query, OrgUsersSearchResults))
        }
      }
    }

    OrgUsersSearchResults(Ok(users)) -> #(
      Model(..model, org_users_search_results: Loaded(users)),
      effect.none(),
    )

    OrgUsersSearchResults(Error(err)) -> {
      case err.status == 401 {
        True -> #(Model(..model, page: Login, user: opt.None), effect.none())
        False -> #(
          Model(..model, org_users_search_results: Failed(err)),
          effect.none(),
        )
      }
    }

    TaskTypesFetched(Ok(task_types)) -> #(
      Model(..model, task_types: Loaded(task_types)),
      effect.none(),
    )

    TaskTypesFetched(Error(err)) -> {
      case err.status == 401 {
        True -> #(Model(..model, page: Login, user: opt.None), effect.none())
        False -> #(Model(..model, task_types: Failed(err)), effect.none())
      }
    }

    TaskTypeCreateNameChanged(name) -> #(
      Model(..model, task_types_create_name: name),
      effect.none(),
    )

    TaskTypeCreateIconChanged(icon) -> #(
      Model(
        ..model,
        task_types_create_icon: icon,
        task_types_icon_preview: IconLoading,
      ),
      effect.none(),
    )

    TaskTypeIconLoaded -> #(
      Model(..model, task_types_icon_preview: IconOk),
      effect.none(),
    )

    TaskTypeIconErrored -> #(
      Model(..model, task_types_icon_preview: IconError),
      effect.none(),
    )

    TaskTypeCreateCapabilityChanged(value) -> {
      case string.trim(value) == "" {
        True -> #(
          Model(..model, task_types_create_capability_id: opt.None),
          effect.none(),
        )
        False -> #(
          Model(..model, task_types_create_capability_id: opt.Some(value)),
          effect.none(),
        )
      }
    }

    TaskTypeCreateSubmitted -> {
      case model.task_types_create_in_flight {
        True -> #(model, effect.none())
        False -> {
          case model.selected_project_id {
            opt.None -> #(
              Model(
                ..model,
                task_types_create_error: opt.Some("Select a project first"),
              ),
              effect.none(),
            )

            opt.Some(project_id) -> {
              let name = string.trim(model.task_types_create_name)
              let icon = string.trim(model.task_types_create_icon)

              case name == "" || icon == "" {
                True -> #(
                  Model(
                    ..model,
                    task_types_create_error: opt.Some(
                      "Name and icon are required",
                    ),
                  ),
                  effect.none(),
                )
                False -> {
                  case model.task_types_icon_preview {
                    IconError -> #(
                      Model(
                        ..model,
                        task_types_create_error: opt.Some("Unknown icon"),
                      ),
                      effect.none(),
                    )
                    IconLoading | IconIdle -> #(
                      Model(
                        ..model,
                        task_types_create_error: opt.Some(
                          "Wait for icon preview",
                        ),
                      ),
                      effect.none(),
                    )
                    IconOk -> {
                      let capability_id = case
                        model.task_types_create_capability_id
                      {
                        opt.None -> opt.None
                        opt.Some(id_str) ->
                          case int.parse(id_str) {
                            Ok(id) -> opt.Some(id)
                            Error(_) -> opt.None
                          }
                      }

                      let model =
                        Model(
                          ..model,
                          task_types_create_in_flight: True,
                          task_types_create_error: opt.None,
                        )

                      #(
                        model,
                        api.create_task_type(
                          project_id,
                          name,
                          icon,
                          capability_id,
                          TaskTypeCreated,
                        ),
                      )
                    }
                  }
                }
              }
            }
          }
        }
      }
    }

    TaskTypeCreated(Ok(_)) -> {
      let model =
        Model(
          ..model,
          task_types_create_in_flight: False,
          task_types_create_name: "",
          task_types_create_icon: "",
          task_types_create_capability_id: opt.None,
          task_types_icon_preview: IconIdle,
          toast: opt.Some("Task type created"),
        )

      refresh_section(model)
    }

    TaskTypeCreated(Error(err)) -> {
      case err.status {
        401 -> #(Model(..model, page: Login, user: opt.None), effect.none())
        403 -> #(
          Model(
            ..model,
            task_types_create_in_flight: False,
            task_types_create_error: opt.Some("Not permitted"),
            toast: opt.Some("Not permitted"),
          ),
          effect.none(),
        )
        _ -> #(
          Model(
            ..model,
            task_types_create_in_flight: False,
            task_types_create_error: opt.Some(err.message),
          ),
          effect.none(),
        )
      }
    }
  }
}

fn bootstrap_admin(model: Model) -> #(Model, Effect(Msg)) {
  let model = Model(..model, projects: Loading)

  #(
    model,
    effect.batch([
      api.list_projects(ProjectsFetched),
      api.list_capabilities(CapabilitiesFetched),
    ]),
  )
}

fn ensure_selected_project(
  selected: opt.Option(Int),
  projects: List(api.Project),
) -> opt.Option(Int) {
  case selected {
    opt.Some(id) ->
      case list.any(projects, fn(p) { p.id == id }) {
        True -> opt.Some(id)
        False ->
          case projects {
            [first, ..] -> opt.Some(first.id)
            [] -> opt.None
          }
      }

    opt.None ->
      case projects {
        [first, ..] -> opt.Some(first.id)
        [] -> opt.None
      }
  }
}

fn ensure_default_section(model: Model) -> Model {
  case model.user, model.projects {
    opt.Some(user), Loaded(projects) -> {
      let visible = permissions.visible_sections(user.org_role, projects)

      case list.any(visible, fn(s) { s == model.active_section }) {
        True -> model
        False ->
          case visible {
            [first, ..] -> Model(..model, active_section: first)
            [] -> model
          }
      }
    }

    _, _ -> model
  }
}

fn refresh_section(model: Model) -> #(Model, Effect(Msg)) {
  case model.active_section {
    permissions.Invites -> #(model, effect.none())

    permissions.Projects -> #(model, api.list_projects(ProjectsFetched))

    permissions.Capabilities -> #(
      model,
      api.list_capabilities(CapabilitiesFetched),
    )

    permissions.Members ->
      case model.selected_project_id {
        opt.None -> #(model, effect.none())
        opt.Some(project_id) -> {
          let model = Model(..model, members: Loading, org_users_cache: Loading)
          #(
            model,
            effect.batch([
              api.list_project_members(project_id, MembersFetched),
              api.list_org_users("", OrgUsersCacheFetched),
            ]),
          )
        }
      }

    permissions.TaskTypes ->
      case model.selected_project_id {
        opt.None -> #(model, effect.none())
        opt.Some(project_id) -> {
          let model = Model(..model, task_types: Loading)
          #(model, api.list_task_types(project_id, TaskTypesFetched))
        }
      }
  }
}

fn resolve_org_user(
  cache: Remote(List(api.OrgUser)),
  user_id: Int,
) -> opt.Option(api.OrgUser) {
  case cache {
    Loaded(users) ->
      case list.find(users, fn(u) { u.id == user_id }) {
        Ok(user) -> opt.Some(user)
        Error(_) -> opt.None
      }

    _ -> opt.None
  }
}

fn fallback_org_user(user_id: Int) -> api.OrgUser {
  api.OrgUser(
    id: user_id,
    email: "User #" <> int.to_string(user_id),
    org_role: "",
    created_at: "",
  )
}

@external(javascript, "./scrumbringer_client/fetch.ffi.mjs", "copy_to_clipboard")
fn copy_to_clipboard_ffi(_text: String, _cb: fn(Bool) -> Nil) -> Nil {
  Nil
}

fn copy_to_clipboard(text: String, msg: fn(Bool) -> Msg) -> Effect(Msg) {
  effect.from(fn(dispatch) {
    copy_to_clipboard_ffi(text, fn(ok) { dispatch(msg(ok)) })
  })
}

fn page_title(section: permissions.AdminSection) -> String {
  case section {
    permissions.Invites -> "Invites"
    permissions.Projects -> "Projects"
    permissions.Members -> "Members"
    permissions.Capabilities -> "Capabilities"
    permissions.TaskTypes -> "Task Types"
  }
}

fn active_projects(model: Model) -> List(api.Project) {
  case model.projects {
    Loaded(projects) -> projects
    _ -> []
  }
}

fn selected_project(model: Model) -> opt.Option(api.Project) {
  case model.selected_project_id, model.projects {
    opt.Some(id), Loaded(projects) ->
      case list.find(projects, fn(p) { p.id == id }) {
        Ok(project) -> opt.Some(project)
        Error(_) -> opt.None
      }

    _, _ -> opt.None
  }
}

fn view(model: Model) -> Element(Msg) {
  div([attribute.class("app")], [
    view_toast(model.toast),
    case model.page {
      Login -> view_login(model)
      Admin -> view_admin(model)
    },
  ])
}

fn view_toast(toast: opt.Option(String)) -> Element(Msg) {
  case toast {
    opt.None -> div([], [])
    opt.Some(message) ->
      div([attribute.class("toast")], [
        span([], [text(message)]),
        button([event.on_click(ToastDismissed)], [text("Dismiss")]),
      ])
  }
}

fn view_login(model: Model) -> Element(Msg) {
  let submit_label = case model.login_in_flight {
    True -> "Logging in..."
    False -> "Login"
  }

  div([attribute.class("page")], [
    h1([], [text("ScrumBringer")]),
    p([], [text("Login to access the admin UI.")]),
    case model.login_error {
      opt.Some(err) -> div([attribute.class("error")], [text(err)])
      opt.None -> div([], [])
    },
    form([event.on_submit(fn(_) { LoginSubmitted })], [
      div([attribute.class("field")], [
        label([], [text("Email")]),
        input([
          attribute.type_("email"),
          attribute.value(model.login_email),
          event.on_input(LoginEmailChanged),
          attribute.required(True),
        ]),
      ]),
      div([attribute.class("field")], [
        label([], [text("Password")]),
        input([
          attribute.type_("password"),
          attribute.value(model.login_password),
          event.on_input(LoginPasswordChanged),
          attribute.required(True),
        ]),
      ]),
      button(
        [
          attribute.type_("submit"),
          attribute.disabled(model.login_in_flight),
        ],
        [text(submit_label)],
      ),
    ]),
  ])
}

fn view_admin(model: Model) -> Element(Msg) {
  case model.user {
    opt.None -> view_login(model)

    opt.Some(user) -> {
      let projects = active_projects(model)
      let selected = selected_project(model)
      let sections = permissions.visible_sections(user.org_role, projects)

      div([attribute.class("admin")], [
        view_topbar(model, user),
        div([attribute.class("body")], [
          view_nav(model, sections),
          div([attribute.class("content")], [
            view_section(model, user, projects, selected),
          ]),
        ]),
      ])
    }
  }
}

fn view_topbar(model: Model, user: User) -> Element(Msg) {
  let show_project_selector =
    model.active_section == permissions.Members
    || model.active_section == permissions.TaskTypes

  div([attribute.class("topbar")], [
    div([attribute.class("topbar-title")], [
      text(page_title(model.active_section)),
    ]),
    case show_project_selector {
      True -> view_project_selector(model)
      False -> div([], [])
    },
    div([attribute.class("topbar-actions")], [
      span([attribute.class("user")], [text(user.email)]),
      button([event.on_click(LogoutClicked)], [text("Logout")]),
    ]),
  ])
}

fn view_project_selector(model: Model) -> Element(Msg) {
  let projects = active_projects(model)

  let selected_id = case model.selected_project_id {
    opt.Some(id) -> int.to_string(id)
    opt.None -> ""
  }

  div([attribute.class("project-selector")], [
    label([], [text("Project")]),
    select(
      [
        attribute.value(selected_id),
        event.on_input(ProjectSelected),
      ],
      [
        option([attribute.value("")], "Select project"),
        ..list.map(projects, fn(p) {
          option([attribute.value(int.to_string(p.id))], p.name)
        })
      ],
    ),
  ])
}

fn view_nav(
  model: Model,
  sections: List(permissions.AdminSection),
) -> Element(Msg) {
  div([attribute.class("nav")], [
    h3([], [text("Admin")]),
    case sections {
      [] -> div([attribute.class("empty")], [text("No admin permissions")])
      _ ->
        div(
          [],
          list.map(sections, fn(section) {
            let classes = case section == model.active_section {
              True -> "nav-item active"
              False -> "nav-item"
            }

            button(
              [
                attribute.class(classes),
                event.on_click(NavSelected(section)),
              ],
              [text(page_title(section))],
            )
          }),
        )
    },
  ])
}

fn view_section(
  model: Model,
  user: User,
  projects: List(api.Project),
  selected: opt.Option(api.Project),
) -> Element(Msg) {
  let allowed =
    permissions.can_access_section(
      model.active_section,
      user.org_role,
      projects,
      selected,
    )

  case allowed {
    False ->
      div([attribute.class("not-permitted")], [
        h2([], [text("Not permitted")]),
        p([], [text("You don't have permission to access this section.")]),
      ])

    True ->
      case model.active_section {
        permissions.Invites -> view_invites(model)
        permissions.Projects -> view_projects(model)
        permissions.Capabilities -> view_capabilities(model)
        permissions.Members -> view_members(model, selected)
        permissions.TaskTypes -> view_task_types(model, selected)
      }
  }
}

fn view_invites(model: Model) -> Element(Msg) {
  let create_label = case model.invites_in_flight {
    True -> "Creating..."
    False -> "Create invite"
  }

  div([attribute.class("section")], [
    p([], [text("Create an invite to onboard a new user.")]),
    case model.invites_error {
      opt.Some(err) -> div([attribute.class("error")], [text(err)])
      opt.None -> div([], [])
    },
    form([event.on_submit(fn(_) { InviteCreateSubmitted })], [
      div([attribute.class("field")], [
        label([], [text("expires_in_hours (optional)")]),
        input([
          attribute.type_("number"),
          attribute.value(model.invites_expires_in_hours),
          event.on_input(InvitesExpiresChanged),
        ]),
      ]),
      button(
        [
          attribute.type_("submit"),
          attribute.disabled(model.invites_in_flight),
        ],
        [text(create_label)],
      ),
    ]),
    hr([]),
    case model.last_invite {
      opt.None ->
        div([attribute.class("empty")], [text("No invite created yet")])

      opt.Some(invite) ->
        div([attribute.class("invite-result")], [
          h3([], [text("Invite Code")]),
          div([attribute.class("field")], [
            label([], [text("code")]),
            input([
              attribute.type_("text"),
              attribute.value(invite.code),
              attribute.readonly(True),
            ]),
          ]),
          button([event.on_click(InviteCopyClicked)], [text("Copy")]),
          case model.invite_copy_status {
            opt.Some(status) -> div([attribute.class("hint")], [text(status)])
            opt.None -> div([], [])
          },
          p([], [text("expires_at: " <> invite.expires_at)]),
        ])
    },
  ])
}

fn view_projects(model: Model) -> Element(Msg) {
  div([attribute.class("section")], [
    h2([], [text("Projects")]),
    view_projects_list(model.projects),
    hr([]),
    h3([], [text("Create Project")]),
    case model.projects_create_error {
      opt.Some(err) -> div([attribute.class("error")], [text(err)])
      opt.None -> div([], [])
    },
    form([event.on_submit(fn(_) { ProjectCreateSubmitted })], [
      div([attribute.class("field")], [
        label([], [text("name")]),
        input([
          attribute.type_("text"),
          attribute.value(model.projects_create_name),
          event.on_input(ProjectCreateNameChanged),
          attribute.required(True),
        ]),
      ]),
      button(
        [
          attribute.type_("submit"),
          attribute.disabled(model.projects_create_in_flight),
        ],
        [
          text(case model.projects_create_in_flight {
            True -> "Creating..."
            False -> "Create"
          }),
        ],
      ),
    ]),
  ])
}

fn view_projects_list(projects: Remote(List(api.Project))) -> Element(Msg) {
  case projects {
    NotAsked | Loading -> div([attribute.class("empty")], [text("Loading...")])

    Failed(err) ->
      case err.status == 403 {
        True -> div([attribute.class("not-permitted")], [text("Not permitted")])
        False -> div([attribute.class("error")], [text(err.message)])
      }

    Loaded(projects) ->
      case projects {
        [] -> div([attribute.class("empty")], [text("No projects yet")])
        _ ->
          table([attribute.class("table")], [
            thead([], [
              tr([], [th([], [text("Name")]), th([], [text("My Role")])]),
            ]),
            tbody(
              [],
              list.map(projects, fn(p) {
                tr([], [td([], [text(p.name)]), td([], [text(p.my_role)])])
              }),
            ),
          ])
      }
  }
}

fn view_capabilities(model: Model) -> Element(Msg) {
  div([attribute.class("section")], [
    h2([], [text("Capabilities")]),
    view_capabilities_list(model.capabilities),
    hr([]),
    h3([], [text("Create Capability")]),
    case model.capabilities_create_error {
      opt.Some(err) -> div([attribute.class("error")], [text(err)])
      opt.None -> div([], [])
    },
    form([event.on_submit(fn(_) { CapabilityCreateSubmitted })], [
      div([attribute.class("field")], [
        label([], [text("name")]),
        input([
          attribute.type_("text"),
          attribute.value(model.capabilities_create_name),
          event.on_input(CapabilityCreateNameChanged),
          attribute.required(True),
        ]),
      ]),
      button(
        [
          attribute.type_("submit"),
          attribute.disabled(model.capabilities_create_in_flight),
        ],
        [
          text(case model.capabilities_create_in_flight {
            True -> "Creating..."
            False -> "Create"
          }),
        ],
      ),
    ]),
  ])
}

fn view_capabilities_list(
  capabilities: Remote(List(api.Capability)),
) -> Element(Msg) {
  case capabilities {
    NotAsked | Loading -> div([attribute.class("empty")], [text("Loading...")])

    Failed(err) ->
      case err.status == 403 {
        True -> div([attribute.class("not-permitted")], [text("Not permitted")])
        False -> div([attribute.class("error")], [text(err.message)])
      }

    Loaded(capabilities) ->
      case capabilities {
        [] -> div([attribute.class("empty")], [text("No capabilities yet")])
        _ ->
          table([attribute.class("table")], [
            thead([], [tr([], [th([], [text("Name")])])]),
            tbody(
              [],
              list.map(capabilities, fn(c) { tr([], [td([], [text(c.name)])]) }),
            ),
          ])
      }
  }
}

fn view_members(
  model: Model,
  selected_project: opt.Option(api.Project),
) -> Element(Msg) {
  case selected_project {
    opt.None ->
      div([attribute.class("empty")], [
        text("Select a project to manage members."),
      ])

    opt.Some(project) ->
      div([attribute.class("section")], [
        h2([], [text("Members - " <> project.name)]),
        button([event.on_click(MemberAddDialogOpened)], [text("Add member")]),
        case model.members_remove_error {
          opt.Some(err) -> div([attribute.class("error")], [text(err)])
          opt.None -> div([], [])
        },
        view_members_table(model.members, model.org_users_cache),
        case model.members_add_dialog_open {
          True -> view_add_member_dialog(model)
          False -> div([], [])
        },
        case model.members_remove_confirm {
          opt.Some(user) -> view_remove_member_dialog(model, project.name, user)
          opt.None -> div([], [])
        },
      ])
  }
}

fn view_members_table(
  members: Remote(List(api.ProjectMember)),
  cache: Remote(List(api.OrgUser)),
) -> Element(Msg) {
  case members {
    NotAsked | Loading -> div([attribute.class("empty")], [text("Loading...")])

    Failed(err) ->
      case err.status == 403 {
        True -> div([attribute.class("not-permitted")], [text("Not permitted")])
        False -> div([attribute.class("error")], [text(err.message)])
      }

    Loaded(members) ->
      case members {
        [] -> div([attribute.class("empty")], [text("No members yet")])
        _ ->
          table([attribute.class("table")], [
            thead([], [
              tr([], [
                th([], [text("User")]),
                th([], [text("User ID")]),
                th([], [text("Role")]),
                th([], [text("Created")]),
                th([], [text("Actions")]),
              ]),
            ]),
            tbody(
              [],
              list.map(members, fn(m) {
                let email = case resolve_org_user(cache, m.user_id) {
                  opt.Some(user) -> user.email
                  opt.None -> "User #" <> int.to_string(m.user_id)
                }

                tr([], [
                  td([], [text(email)]),
                  td([], [text(int.to_string(m.user_id))]),
                  td([], [text(m.role)]),
                  td([], [text(m.created_at)]),
                  td([], [
                    button([event.on_click(MemberRemoveClicked(m.user_id))], [
                      text("Remove"),
                    ]),
                  ]),
                ])
              }),
            ),
          ])
      }
  }
}

fn view_add_member_dialog(model: Model) -> Element(Msg) {
  div([attribute.class("modal")], [
    div([attribute.class("modal-content")], [
      h3([], [text("Add member")]),
      case model.members_add_error {
        opt.Some(err) -> div([attribute.class("error")], [text(err)])
        opt.None -> div([], [])
      },
      div([attribute.class("field")], [
        label([], [text("Search by email")]),
        input([
          attribute.type_("text"),
          attribute.value(model.org_users_search_query),
          event.on_input(OrgUsersSearchChanged),
          event.debounce(event.on_input(OrgUsersSearchDebounced), 350),
          attribute.placeholder("user@company.com"),
        ]),
      ]),
      view_org_users_search_results(model.org_users_search_results),
      div([attribute.class("field")], [
        label([], [text("Role")]),
        select(
          [
            attribute.value(model.members_add_role),
            event.on_input(MemberAddRoleChanged),
          ],
          [
            option([attribute.value("member")], "member"),
            option([attribute.value("admin")], "admin"),
          ],
        ),
      ]),
      div([attribute.class("actions")], [
        button([event.on_click(MemberAddDialogClosed)], [text("Cancel")]),
        button(
          [
            event.on_click(MemberAddSubmitted),
            attribute.disabled(
              model.members_add_in_flight
              || model.members_add_selected_user == opt.None,
            ),
          ],
          [
            text(case model.members_add_in_flight {
              True -> "Adding..."
              False -> "Add"
            }),
          ],
        ),
      ]),
    ]),
  ])
}

fn view_org_users_search_results(
  results: Remote(List(api.OrgUser)),
) -> Element(Msg) {
  case results {
    NotAsked ->
      div([attribute.class("empty")], [text("Type an email to search")])
    Loading -> div([attribute.class("empty")], [text("Searching...")])

    Failed(err) ->
      case err.status == 403 {
        True -> div([attribute.class("not-permitted")], [text("Not permitted")])
        False -> div([attribute.class("error")], [text(err.message)])
      }

    Loaded(users) ->
      case users {
        [] -> div([attribute.class("empty")], [text("No results")])
        _ ->
          table([attribute.class("table")], [
            thead([], [
              tr([], [
                th([], [text("Email")]),
                th([], [text("Org Role")]),
                th([], [text("Created")]),
                th([], [text("Select")]),
              ]),
            ]),
            tbody(
              [],
              list.map(users, fn(u) {
                tr([], [
                  td([], [text(u.email)]),
                  td([], [text(u.org_role)]),
                  td([], [text(u.created_at)]),
                  td([], [
                    button([event.on_click(MemberAddUserSelected(u.id))], [
                      text("Select"),
                    ]),
                  ]),
                ])
              }),
            ),
          ])
      }
  }
}

fn view_remove_member_dialog(
  model: Model,
  project_name: String,
  user: api.OrgUser,
) -> Element(Msg) {
  div([attribute.class("modal")], [
    div([attribute.class("modal-content")], [
      h3([], [text("Remove member")]),
      p([], [text("Remove " <> user.email <> " from " <> project_name <> "?")]),
      case model.members_remove_error {
        opt.Some(err) -> div([attribute.class("error")], [text(err)])
        opt.None -> div([], [])
      },
      div([attribute.class("actions")], [
        button([event.on_click(MemberRemoveCancelled)], [text("Cancel")]),
        button(
          [
            event.on_click(MemberRemoveConfirmed),
            attribute.disabled(model.members_remove_in_flight),
          ],
          [
            text(case model.members_remove_in_flight {
              True -> "Removing..."
              False -> "Remove"
            }),
          ],
        ),
      ]),
    ]),
  ])
}

fn view_task_types(
  model: Model,
  selected_project: opt.Option(api.Project),
) -> Element(Msg) {
  case selected_project {
    opt.None ->
      div([attribute.class("empty")], [
        text("Select a project to manage task types."),
      ])

    opt.Some(project) ->
      div([attribute.class("section")], [
        h2([], [text("Task Types - " <> project.name)]),
        view_task_types_list(model.task_types),
        hr([]),
        h3([], [text("Create Task Type")]),
        case model.task_types_create_error {
          opt.Some(err) -> div([attribute.class("error")], [text(err)])
          opt.None -> div([], [])
        },
        form([event.on_submit(fn(_) { TaskTypeCreateSubmitted })], [
          div([attribute.class("field")], [
            label([], [text("name")]),
            input([
              attribute.type_("text"),
              attribute.value(model.task_types_create_name),
              event.on_input(TaskTypeCreateNameChanged),
              attribute.required(True),
            ]),
          ]),
          div([attribute.class("field")], [
            label([], [text("icon (heroicon name)")]),
            div([attribute.class("icon-row")], [
              input([
                attribute.type_("text"),
                attribute.value(model.task_types_create_icon),
                event.on_input(TaskTypeCreateIconChanged),
                attribute.required(True),
                attribute.placeholder("bug-ant"),
              ]),
              view_icon_preview(model.task_types_create_icon),
            ]),
            case model.task_types_icon_preview {
              IconError ->
                div([attribute.class("error")], [text("Unknown icon")])
              _ -> div([], [])
            },
          ]),
          div([attribute.class("field")], [
            label([], [text("capability (optional)")]),
            view_capability_selector(
              model.capabilities,
              model.task_types_create_capability_id,
            ),
          ]),
          button(
            [
              attribute.type_("submit"),
              attribute.disabled(
                model.task_types_create_in_flight
                || model.task_types_icon_preview != IconOk,
              ),
            ],
            [
              text(case model.task_types_create_in_flight {
                True -> "Creating..."
                False -> "Create"
              }),
            ],
          ),
        ]),
      ])
  }
}

fn view_icon_preview(icon_name: String) -> Element(Msg) {
  let name = string.trim(icon_name)

  case name == "" {
    True -> div([attribute.class("icon-preview")], [text("-")])

    False -> {
      let url =
        "https://unpkg.com/heroicons@2.1.0/24/outline/" <> name <> ".svg"

      div([attribute.class("icon-preview")], [
        img([
          attribute.attribute("src", url),
          attribute.attribute("alt", name <> " icon"),
          attribute.attribute("width", "24"),
          attribute.attribute("height", "24"),
          event.on("load", decode.success(TaskTypeIconLoaded)),
          event.on("error", decode.success(TaskTypeIconErrored)),
        ]),
      ])
    }
  }
}

fn view_capability_selector(
  capabilities: Remote(List(api.Capability)),
  selected: opt.Option(String),
) -> Element(Msg) {
  case capabilities {
    Loaded(capabilities) -> {
      let selected_value = opt.unwrap(selected, "")

      select(
        [
          attribute.value(selected_value),
          event.on_input(TaskTypeCreateCapabilityChanged),
        ],
        [
          option([attribute.value("")], "None"),
          ..list.map(capabilities, fn(c) {
            option([attribute.value(int.to_string(c.id))], c.name)
          })
        ],
      )
    }

    _ -> div([attribute.class("empty")], [text("Loading capabilities...")])
  }
}

fn view_task_types_list(task_types: Remote(List(api.TaskType))) -> Element(Msg) {
  case task_types {
    NotAsked | Loading -> div([attribute.class("empty")], [text("Loading...")])

    Failed(err) ->
      case err.status == 403 {
        True -> div([attribute.class("not-permitted")], [text("Not permitted")])
        False -> div([attribute.class("error")], [text(err.message)])
      }

    Loaded(task_types) ->
      case task_types {
        [] -> div([attribute.class("empty")], [text("No task types yet")])
        _ ->
          table([attribute.class("table")], [
            thead([], [
              tr([], [
                th([], [text("Name")]),
                th([], [text("Icon")]),
                th([], [text("Capability")]),
              ]),
            ]),
            tbody(
              [],
              list.map(task_types, fn(tt) {
                tr([], [
                  td([], [text(tt.name)]),
                  td([], [text(tt.icon)]),
                  td([], [
                    case tt.capability_id {
                      opt.Some(id) -> text(int.to_string(id))
                      opt.None -> text("-")
                    },
                  ]),
                ])
              }),
            ),
          ])
      }
  }
}
