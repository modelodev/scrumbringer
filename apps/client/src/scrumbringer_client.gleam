import gleam/dict
import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/list
import gleam/option as opt
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

import scrumbringer_domain/org_role
import scrumbringer_domain/user.{type User}

import scrumbringer_client/api
import scrumbringer_client/member_visuals
import scrumbringer_client/permissions

pub fn app() -> lustre.App(Nil, Model, Msg) {
  lustre.application(init, update, view)
}

pub fn main() {
  case lustre.start(app(), "#app", Nil) {
    Ok(_) -> Nil
    Error(_) -> Nil
  }
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
  Member
}

type IconPreview {
  IconIdle
  IconLoading
  IconOk
  IconError
}

pub type MemberSection {
  Pool
  MyBar
  MySkills
}

type MemberDrag {
  MemberDrag(task_id: Int, offset_x: Int, offset_y: Int)
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
    invite_links: Remote(List(api.InviteLink)),
    invite_link_email: String,
    invite_link_in_flight: Bool,
    invite_link_error: opt.Option(String),
    invite_link_last: opt.Option(api.InviteLink),
    invite_link_copy_status: opt.Option(String),
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
    member_section: MemberSection,
    member_tasks: Remote(List(api.Task)),
    member_tasks_pending: Int,
    member_tasks_by_project: dict.Dict(Int, List(api.Task)),
    member_task_types: Remote(List(api.TaskType)),
    member_task_types_pending: Int,
    member_task_types_by_project: dict.Dict(Int, List(api.TaskType)),
    member_task_mutation_in_flight: Bool,
    member_filters_status: String,
    member_filters_type_id: String,
    member_filters_capability_id: String,
    member_filters_q: String,
    member_quick_my_caps: Bool,
    member_create_dialog_open: Bool,
    member_create_title: String,
    member_create_description: String,
    member_create_priority: String,
    member_create_type_id: String,
    member_create_in_flight: Bool,
    member_create_error: opt.Option(String),
    member_my_capability_ids: Remote(List(Int)),
    member_my_capability_ids_edit: dict.Dict(Int, Bool),
    member_my_capabilities_in_flight: Bool,
    member_my_capabilities_error: opt.Option(String),
    member_positions_by_task: dict.Dict(Int, #(Int, Int)),
    member_drag: opt.Option(MemberDrag),
    member_canvas_left: Int,
    member_canvas_top: Int,
    member_position_edit_task: opt.Option(Int),
    member_position_edit_x: String,
    member_position_edit_y: String,
    member_position_edit_in_flight: Bool,
    member_position_edit_error: opt.Option(String),
    member_notes_task_id: opt.Option(Int),
    member_notes: Remote(List(api.TaskNote)),
    member_note_content: String,
    member_note_in_flight: Bool,
    member_note_error: opt.Option(String),
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

  InviteLinkEmailChanged(String)
  InviteLinkCreateSubmitted
  InviteLinkCreated(api.ApiResult(api.InviteLink))
  InviteLinksFetched(api.ApiResult(List(api.InviteLink)))
  InviteLinkRegenerateClicked(String)
  InviteLinkRegenerated(api.ApiResult(api.InviteLink))
  InviteLinkCopyClicked(String)
  InviteLinkCopyFinished(Bool)

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

  SwitchToAdmin
  SwitchToMember

  MemberNavSelected(MemberSection)
  MemberPoolStatusChanged(String)
  MemberPoolTypeChanged(String)
  MemberPoolCapabilityChanged(String)
  MemberPoolSearchChanged(String)
  MemberPoolSearchDebounced(String)
  MemberToggleMyCapabilitiesQuick

  MemberProjectTasksFetched(Int, api.ApiResult(List(api.Task)))
  MemberTaskTypesFetched(Int, api.ApiResult(List(api.TaskType)))

  MemberCanvasRectFetched(Int, Int)
  MemberDragStarted(Int, Int, Int)
  MemberDragMoved(Int, Int)
  MemberDragEnded

  MemberCreateDialogOpened
  MemberCreateDialogClosed
  MemberCreateTitleChanged(String)
  MemberCreateDescriptionChanged(String)
  MemberCreatePriorityChanged(String)
  MemberCreateTypeIdChanged(String)
  MemberCreateSubmitted
  MemberTaskCreated(api.ApiResult(api.Task))

  MemberClaimClicked(Int, Int)
  MemberReleaseClicked(Int, Int)
  MemberCompleteClicked(Int, Int)
  MemberTaskClaimed(api.ApiResult(api.Task))
  MemberTaskReleased(api.ApiResult(api.Task))
  MemberTaskCompleted(api.ApiResult(api.Task))

  MemberMyCapabilityIdsFetched(api.ApiResult(List(Int)))
  MemberToggleCapability(Int)
  MemberSaveCapabilitiesClicked
  MemberMyCapabilityIdsSaved(api.ApiResult(List(Int)))

  MemberPositionsFetched(api.ApiResult(List(api.TaskPosition)))
  MemberPositionEditOpened(Int)
  MemberPositionEditClosed
  MemberPositionEditXChanged(String)
  MemberPositionEditYChanged(String)
  MemberPositionEditSubmitted
  MemberPositionSaved(api.ApiResult(api.TaskPosition))

  MemberTaskDetailsOpened(Int)
  MemberTaskDetailsClosed
  MemberNotesFetched(api.ApiResult(List(api.TaskNote)))
  MemberNoteContentChanged(String)
  MemberNoteSubmitted
  MemberNoteAdded(api.ApiResult(api.TaskNote))
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
      invite_links: NotAsked,
      invite_link_email: "",
      invite_link_in_flight: False,
      invite_link_error: opt.None,
      invite_link_last: opt.None,
      invite_link_copy_status: opt.None,
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
      member_section: Pool,
      member_tasks: NotAsked,
      member_tasks_pending: 0,
      member_tasks_by_project: dict.new(),
      member_task_types: NotAsked,
      member_task_types_pending: 0,
      member_task_types_by_project: dict.new(),
      member_task_mutation_in_flight: False,
      member_filters_status: "",
      member_filters_type_id: "",
      member_filters_capability_id: "",
      member_filters_q: "",
      member_quick_my_caps: False,
      member_create_dialog_open: False,
      member_create_title: "",
      member_create_description: "",
      member_create_priority: "3",
      member_create_type_id: "",
      member_create_in_flight: False,
      member_create_error: opt.None,
      member_my_capability_ids: NotAsked,
      member_my_capability_ids_edit: dict.new(),
      member_my_capabilities_in_flight: False,
      member_my_capabilities_error: opt.None,
      member_positions_by_task: dict.new(),
      member_drag: opt.None,
      member_canvas_left: 0,
      member_canvas_top: 0,
      member_position_edit_task: opt.None,
      member_position_edit_x: "",
      member_position_edit_y: "",
      member_position_edit_in_flight: False,
      member_position_edit_error: opt.None,
      member_notes_task_id: opt.None,
      member_notes: NotAsked,
      member_note_content: "",
      member_note_in_flight: False,
      member_note_error: opt.None,
    )

  #(model, api.fetch_me(MeFetched))
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    MeFetched(Ok(user)) -> {
      let page = case user.org_role {
        org_role.Admin -> Admin
        _ -> Member
      }

      let model = Model(..model, page: page, user: opt.Some(user))
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
      let page = case user.org_role {
        org_role.Admin -> Admin
        _ -> Member
      }

      let model =
        Model(
          ..model,
          page: page,
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
      let selected = case int.parse(project_id) {
        Ok(id) -> opt.Some(id)
        Error(_) -> opt.None
      }

      let model = case selected {
        opt.None ->
          Model(
            ..model,
            selected_project_id: selected,
            toast: opt.None,
            member_filters_type_id: "",
            member_task_types: NotAsked,
          )
        _ -> Model(..model, selected_project_id: selected, toast: opt.None)
      }

      case model.page {
        Member -> member_refresh(model)
        _ -> refresh_section(model)
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

      case model.page {
        Member -> member_refresh(model)
        _ -> #(model, effect.none())
      }
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

    InviteLinkEmailChanged(value) -> #(
      Model(..model, invite_link_email: value),
      effect.none(),
    )

    InviteLinksFetched(Ok(links)) -> #(
      Model(..model, invite_links: Loaded(links)),
      effect.none(),
    )

    InviteLinksFetched(Error(err)) -> {
      case err.status == 401 {
        True -> #(Model(..model, page: Login, user: opt.None), effect.none())
        False -> #(Model(..model, invite_links: Failed(err)), effect.none())
      }
    }

    InviteLinkCreateSubmitted -> {
      case model.invite_link_in_flight {
        True -> #(model, effect.none())
        False -> {
          let email = string.trim(model.invite_link_email)

          case email == "" {
            True -> #(
              Model(..model, invite_link_error: opt.Some("Email is required")),
              effect.none(),
            )
            False -> {
              let model =
                Model(
                  ..model,
                  invite_link_in_flight: True,
                  invite_link_error: opt.None,
                  invite_link_copy_status: opt.None,
                )
              #(model, api.create_invite_link(email, InviteLinkCreated))
            }
          }
        }
      }
    }

    InviteLinkRegenerateClicked(email) -> {
      case model.invite_link_in_flight {
        True -> #(model, effect.none())
        False -> {
          let email = string.trim(email)

          case email == "" {
            True -> #(
              Model(..model, invite_link_error: opt.Some("Email is required")),
              effect.none(),
            )
            False -> {
              let model =
                Model(
                  ..model,
                  invite_link_in_flight: True,
                  invite_link_error: opt.None,
                  invite_link_copy_status: opt.None,
                  invite_link_email: email,
                )
              #(model, api.regenerate_invite_link(email, InviteLinkRegenerated))
            }
          }
        }
      }
    }

    InviteLinkCreated(Ok(link)) -> {
      let model =
        Model(
          ..model,
          invite_link_in_flight: False,
          invite_link_last: opt.Some(link),
          invite_link_email: "",
          toast: opt.Some("Invite link created"),
        )

      #(model, api.list_invite_links(InviteLinksFetched))
    }

    InviteLinkRegenerated(Ok(link)) -> {
      let model =
        Model(
          ..model,
          invite_link_in_flight: False,
          invite_link_last: opt.Some(link),
          invite_link_email: "",
          toast: opt.Some("Invite link regenerated"),
        )

      #(model, api.list_invite_links(InviteLinksFetched))
    }

    InviteLinkCreated(Error(err)) -> {
      case err.status {
        401 -> #(Model(..model, page: Login, user: opt.None), effect.none())
        403 -> #(
          Model(
            ..model,
            invite_link_in_flight: False,
            invite_link_error: opt.Some("Not permitted"),
            toast: opt.Some("Not permitted"),
          ),
          effect.none(),
        )
        _ -> #(
          Model(
            ..model,
            invite_link_in_flight: False,
            invite_link_error: opt.Some(err.message),
          ),
          effect.none(),
        )
      }
    }

    InviteLinkRegenerated(Error(err)) -> {
      case err.status {
        401 -> #(Model(..model, page: Login, user: opt.None), effect.none())
        403 -> #(
          Model(
            ..model,
            invite_link_in_flight: False,
            invite_link_error: opt.Some("Not permitted"),
            toast: opt.Some("Not permitted"),
          ),
          effect.none(),
        )
        _ -> #(
          Model(
            ..model,
            invite_link_in_flight: False,
            invite_link_error: opt.Some(err.message),
          ),
          effect.none(),
        )
      }
    }

    InviteLinkCopyClicked(text) -> #(
      Model(..model, invite_link_copy_status: opt.Some("Copying...")),
      copy_to_clipboard(text, InviteLinkCopyFinished),
    )

    InviteLinkCopyFinished(ok) -> {
      let message = case ok {
        True -> "Copied"
        False -> "Copy failed"
      }

      #(
        Model(..model, invite_link_copy_status: opt.Some(message)),
        effect.none(),
      )
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

    SwitchToAdmin -> #(Model(..model, page: Admin), effect.none())

    SwitchToMember -> {
      let model = Model(..model, page: Member)
      member_refresh(model)
    }

    MemberNavSelected(section) -> {
      let model = Model(..model, member_section: section)
      member_refresh(model)
    }

    MemberPoolStatusChanged(v) -> {
      let model = Model(..model, member_filters_status: v)
      member_refresh(model)
    }

    MemberPoolTypeChanged(v) -> {
      let model = Model(..model, member_filters_type_id: v)
      member_refresh(model)
    }

    MemberPoolCapabilityChanged(v) -> {
      let model = Model(..model, member_filters_capability_id: v)
      member_refresh(model)
    }

    MemberToggleMyCapabilitiesQuick -> #(
      Model(..model, member_quick_my_caps: !model.member_quick_my_caps),
      effect.none(),
    )

    MemberPoolSearchChanged(v) -> #(
      Model(..model, member_filters_q: v),
      effect.none(),
    )

    MemberPoolSearchDebounced(v) -> {
      let model = Model(..model, member_filters_q: v)
      member_refresh(model)
    }

    MemberProjectTasksFetched(project_id, Ok(tasks)) -> {
      let tasks_by_project =
        dict.insert(model.member_tasks_by_project, project_id, tasks)
      let pending = model.member_tasks_pending - 1

      let model =
        Model(
          ..model,
          member_tasks_by_project: tasks_by_project,
          member_tasks_pending: pending,
        )

      case pending <= 0 {
        True -> #(
          Model(..model, member_tasks: Loaded(flatten_tasks(tasks_by_project))),
          effect.none(),
        )
        False -> #(model, effect.none())
      }
    }

    MemberProjectTasksFetched(_project_id, Error(err)) -> {
      case err.status {
        401 -> #(Model(..model, page: Login, user: opt.None), effect.none())
        _ -> #(
          Model(..model, member_tasks: Failed(err), member_tasks_pending: 0),
          effect.none(),
        )
      }
    }

    MemberTaskTypesFetched(project_id, Ok(task_types)) -> {
      let task_types_by_project =
        dict.insert(model.member_task_types_by_project, project_id, task_types)
      let pending = model.member_task_types_pending - 1

      let model =
        Model(
          ..model,
          member_task_types_by_project: task_types_by_project,
          member_task_types_pending: pending,
        )

      case pending <= 0 {
        True -> #(
          Model(
            ..model,
            member_task_types: Loaded(flatten_task_types(task_types_by_project)),
          ),
          effect.none(),
        )
        False -> #(model, effect.none())
      }
    }

    MemberTaskTypesFetched(_project_id, Error(err)) -> {
      case err.status {
        401 -> #(Model(..model, page: Login, user: opt.None), effect.none())
        _ -> #(
          Model(
            ..model,
            member_task_types: Failed(err),
            member_task_types_pending: 0,
          ),
          effect.none(),
        )
      }
    }

    MemberCanvasRectFetched(left, top) -> #(
      Model(..model, member_canvas_left: left, member_canvas_top: top),
      effect.none(),
    )

    MemberDragStarted(task_id, offset_x, offset_y) -> {
      let model =
        Model(
          ..model,
          member_drag: opt.Some(MemberDrag(
            task_id: task_id,
            offset_x: offset_x,
            offset_y: offset_y,
          )),
        )

      #(
        model,
        effect.from(fn(dispatch) {
          let #(left, top) = element_client_offset_ffi("member-canvas")
          dispatch(MemberCanvasRectFetched(left, top))
        }),
      )
    }

    MemberDragMoved(client_x, client_y) -> {
      case model.member_drag {
        opt.None -> #(model, effect.none())

        opt.Some(drag) -> {
          let MemberDrag(task_id: task_id, offset_x: ox, offset_y: oy) = drag

          let x = client_x - model.member_canvas_left - ox
          let y = client_y - model.member_canvas_top - oy

          #(
            Model(
              ..model,
              member_positions_by_task: dict.insert(
                model.member_positions_by_task,
                task_id,
                #(x, y),
              ),
            ),
            effect.none(),
          )
        }
      }
    }

    MemberDragEnded -> {
      case model.member_drag {
        opt.None -> #(model, effect.none())

        opt.Some(drag) -> {
          let MemberDrag(task_id: task_id, ..) = drag

          let #(x, y) = case dict.get(model.member_positions_by_task, task_id) {
            Ok(xy) -> xy
            Error(_) -> #(0, 0)
          }

          #(
            Model(..model, member_drag: opt.None),
            api.upsert_me_task_position(task_id, x, y, MemberPositionSaved),
          )
        }
      }
    }

    MemberCreateDialogOpened -> #(
      Model(
        ..model,
        member_create_dialog_open: True,
        member_create_error: opt.None,
      ),
      effect.none(),
    )

    MemberCreateDialogClosed -> #(
      Model(
        ..model,
        member_create_dialog_open: False,
        member_create_error: opt.None,
      ),
      effect.none(),
    )

    MemberCreateTitleChanged(v) -> #(
      Model(..model, member_create_title: v),
      effect.none(),
    )
    MemberCreateDescriptionChanged(v) -> #(
      Model(..model, member_create_description: v),
      effect.none(),
    )
    MemberCreatePriorityChanged(v) -> #(
      Model(..model, member_create_priority: v),
      effect.none(),
    )
    MemberCreateTypeIdChanged(v) -> #(
      Model(..model, member_create_type_id: v),
      effect.none(),
    )

    MemberCreateSubmitted -> {
      case model.member_create_in_flight {
        True -> #(model, effect.none())
        False ->
          case model.selected_project_id {
            opt.None -> #(
              Model(
                ..model,
                member_create_error: opt.Some("Select a project first"),
              ),
              effect.none(),
            )

            opt.Some(project_id) -> {
              let title = string.trim(model.member_create_title)

              case title == "" {
                True -> #(
                  Model(
                    ..model,
                    member_create_error: opt.Some("Title is required"),
                  ),
                  effect.none(),
                )

                False ->
                  case int.parse(model.member_create_type_id) {
                    Error(_) -> #(
                      Model(
                        ..model,
                        member_create_error: opt.Some("Type is required"),
                      ),
                      effect.none(),
                    )

                    Ok(type_id) -> {
                      case int.parse(model.member_create_priority) {
                        Ok(priority) if priority >= 1 && priority <= 5 -> {
                          let desc =
                            string.trim(model.member_create_description)
                          let description = case desc == "" {
                            True -> opt.None
                            False -> opt.Some(desc)
                          }

                          let model =
                            Model(
                              ..model,
                              member_create_in_flight: True,
                              member_create_error: opt.None,
                            )

                          #(
                            model,
                            api.create_task(
                              project_id,
                              title,
                              description,
                              priority,
                              type_id,
                              MemberTaskCreated,
                            ),
                          )
                        }

                        _ -> #(
                          Model(
                            ..model,
                            member_create_error: opt.Some(
                              "Priority must be 1-5",
                            ),
                          ),
                          effect.none(),
                        )
                      }
                    }
                  }
              }
            }
          }
      }
    }

    MemberTaskCreated(Ok(_)) -> {
      let model =
        Model(
          ..model,
          member_create_in_flight: False,
          member_create_dialog_open: False,
          member_create_title: "",
          member_create_description: "",
          member_create_priority: "3",
          member_create_type_id: "",
          toast: opt.Some("Task created"),
        )
      member_refresh(model)
    }

    MemberTaskCreated(Error(err)) -> {
      case err.status {
        401 -> #(Model(..model, page: Login, user: opt.None), effect.none())
        _ -> #(
          Model(
            ..model,
            member_create_in_flight: False,
            member_create_error: opt.Some(err.message),
          ),
          effect.none(),
        )
      }
    }

    MemberClaimClicked(task_id, version) -> {
      case model.member_task_mutation_in_flight {
        True -> #(model, effect.none())
        False -> #(
          Model(..model, member_task_mutation_in_flight: True),
          api.claim_task(task_id, version, MemberTaskClaimed),
        )
      }
    }

    MemberReleaseClicked(task_id, version) -> {
      case model.member_task_mutation_in_flight {
        True -> #(model, effect.none())
        False -> #(
          Model(..model, member_task_mutation_in_flight: True),
          api.release_task(task_id, version, MemberTaskReleased),
        )
      }
    }

    MemberCompleteClicked(task_id, version) -> {
      case model.member_task_mutation_in_flight {
        True -> #(model, effect.none())
        False -> #(
          Model(..model, member_task_mutation_in_flight: True),
          api.complete_task(task_id, version, MemberTaskCompleted),
        )
      }
    }

    MemberTaskClaimed(Ok(_)) ->
      member_refresh(
        Model(
          ..model,
          member_task_mutation_in_flight: False,
          toast: opt.Some("Task claimed"),
        ),
      )
    MemberTaskReleased(Ok(_)) ->
      member_refresh(
        Model(
          ..model,
          member_task_mutation_in_flight: False,
          toast: opt.Some("Task released"),
        ),
      )
    MemberTaskCompleted(Ok(_)) ->
      member_refresh(
        Model(
          ..model,
          member_task_mutation_in_flight: False,
          toast: opt.Some("Task completed"),
        ),
      )

    MemberTaskClaimed(Error(err)) ->
      member_handle_task_mutation_error(
        Model(..model, member_task_mutation_in_flight: False),
        err,
      )
    MemberTaskReleased(Error(err)) ->
      member_handle_task_mutation_error(
        Model(..model, member_task_mutation_in_flight: False),
        err,
      )
    MemberTaskCompleted(Error(err)) ->
      member_handle_task_mutation_error(
        Model(..model, member_task_mutation_in_flight: False),
        err,
      )

    MemberMyCapabilityIdsFetched(Ok(ids)) -> #(
      Model(
        ..model,
        member_my_capability_ids: Loaded(ids),
        member_my_capability_ids_edit: ids_to_bool_dict(ids),
      ),
      effect.none(),
    )

    MemberMyCapabilityIdsFetched(Error(err)) -> {
      case err.status {
        401 -> #(Model(..model, page: Login, user: opt.None), effect.none())
        _ -> #(
          Model(..model, member_my_capability_ids: Failed(err)),
          effect.none(),
        )
      }
    }

    MemberToggleCapability(id) -> {
      let next = case dict.get(model.member_my_capability_ids_edit, id) {
        Ok(v) -> !v
        Error(_) -> True
      }

      #(
        Model(
          ..model,
          member_my_capability_ids_edit: dict.insert(
            model.member_my_capability_ids_edit,
            id,
            next,
          ),
        ),
        effect.none(),
      )
    }

    MemberSaveCapabilitiesClicked -> {
      case model.member_my_capabilities_in_flight {
        True -> #(model, effect.none())
        False -> {
          let ids = bool_dict_to_ids(model.member_my_capability_ids_edit)
          let model =
            Model(
              ..model,
              member_my_capabilities_in_flight: True,
              member_my_capabilities_error: opt.None,
            )
          #(model, api.put_me_capability_ids(ids, MemberMyCapabilityIdsSaved))
        }
      }
    }

    MemberMyCapabilityIdsSaved(Ok(ids)) -> #(
      Model(
        ..model,
        member_my_capabilities_in_flight: False,
        member_my_capability_ids: Loaded(ids),
        member_my_capability_ids_edit: ids_to_bool_dict(ids),
        toast: opt.Some("Skills saved"),
      ),
      effect.none(),
    )

    MemberMyCapabilityIdsSaved(Error(err)) -> {
      case err.status {
        401 -> #(Model(..model, page: Login, user: opt.None), effect.none())
        _ -> #(
          Model(
            ..model,
            member_my_capabilities_in_flight: False,
            member_my_capabilities_error: opt.Some(err.message),
            toast: opt.Some(err.message),
          ),
          api.get_me_capability_ids(MemberMyCapabilityIdsFetched),
        )
      }
    }

    MemberPositionsFetched(Ok(positions)) -> #(
      Model(..model, member_positions_by_task: positions_to_dict(positions)),
      effect.none(),
    )

    MemberPositionsFetched(Error(err)) -> {
      case err.status {
        401 -> #(Model(..model, page: Login, user: opt.None), effect.none())
        _ -> #(model, effect.none())
      }
    }

    MemberPositionEditOpened(task_id) -> {
      let #(x, y) = case dict.get(model.member_positions_by_task, task_id) {
        Ok(xy) -> xy
        Error(_) -> #(0, 0)
      }

      #(
        Model(
          ..model,
          member_position_edit_task: opt.Some(task_id),
          member_position_edit_x: int.to_string(x),
          member_position_edit_y: int.to_string(y),
          member_position_edit_error: opt.None,
        ),
        effect.none(),
      )
    }

    MemberPositionEditClosed -> #(
      Model(
        ..model,
        member_position_edit_task: opt.None,
        member_position_edit_error: opt.None,
      ),
      effect.none(),
    )

    MemberPositionEditXChanged(v) -> #(
      Model(..model, member_position_edit_x: v),
      effect.none(),
    )
    MemberPositionEditYChanged(v) -> #(
      Model(..model, member_position_edit_y: v),
      effect.none(),
    )

    MemberPositionEditSubmitted -> {
      case model.member_position_edit_in_flight {
        True -> #(model, effect.none())
        False ->
          case model.member_position_edit_task {
            opt.None -> #(model, effect.none())
            opt.Some(task_id) ->
              case
                int.parse(model.member_position_edit_x),
                int.parse(model.member_position_edit_y)
              {
                Ok(x), Ok(y) -> {
                  let model =
                    Model(
                      ..model,
                      member_position_edit_in_flight: True,
                      member_position_edit_error: opt.None,
                    )
                  #(
                    model,
                    api.upsert_me_task_position(
                      task_id,
                      x,
                      y,
                      MemberPositionSaved,
                    ),
                  )
                }
                _, _ -> #(
                  Model(
                    ..model,
                    member_position_edit_error: opt.Some("Invalid x/y"),
                  ),
                  effect.none(),
                )
              }
          }
      }
    }

    MemberPositionSaved(Ok(pos)) -> {
      let api.TaskPosition(task_id: task_id, x: x, y: y, ..) = pos

      #(
        Model(
          ..model,
          member_position_edit_in_flight: False,
          member_position_edit_task: opt.None,
          member_positions_by_task: dict.insert(
            model.member_positions_by_task,
            task_id,
            #(x, y),
          ),
        ),
        effect.none(),
      )
    }

    MemberPositionSaved(Error(err)) -> {
      case err.status {
        401 -> #(Model(..model, page: Login, user: opt.None), effect.none())
        _ -> #(
          Model(
            ..model,
            member_position_edit_in_flight: False,
            member_position_edit_error: opt.Some(err.message),
            toast: opt.Some(err.message),
          ),
          api.list_me_task_positions(
            model.selected_project_id,
            MemberPositionsFetched,
          ),
        )
      }
    }

    MemberTaskDetailsOpened(task_id) -> #(
      Model(
        ..model,
        member_notes_task_id: opt.Some(task_id),
        member_notes: Loading,
        member_note_error: opt.None,
      ),
      api.list_task_notes(task_id, MemberNotesFetched),
    )

    MemberTaskDetailsClosed -> #(
      Model(
        ..model,
        member_notes_task_id: opt.None,
        member_notes: NotAsked,
        member_note_content: "",
        member_note_error: opt.None,
      ),
      effect.none(),
    )

    MemberNotesFetched(Ok(notes)) -> #(
      Model(..model, member_notes: Loaded(notes)),
      effect.none(),
    )
    MemberNotesFetched(Error(err)) -> {
      case err.status {
        401 -> #(Model(..model, page: Login, user: opt.None), effect.none())
        _ -> #(Model(..model, member_notes: Failed(err)), effect.none())
      }
    }

    MemberNoteContentChanged(v) -> #(
      Model(..model, member_note_content: v),
      effect.none(),
    )

    MemberNoteSubmitted -> {
      case model.member_note_in_flight {
        True -> #(model, effect.none())
        False ->
          case model.member_notes_task_id {
            opt.None -> #(model, effect.none())
            opt.Some(task_id) -> {
              let content = string.trim(model.member_note_content)
              case content == "" {
                True -> #(
                  Model(
                    ..model,
                    member_note_error: opt.Some("Content required"),
                  ),
                  effect.none(),
                )
                False -> {
                  let model =
                    Model(
                      ..model,
                      member_note_in_flight: True,
                      member_note_error: opt.None,
                    )
                  #(model, api.add_task_note(task_id, content, MemberNoteAdded))
                }
              }
            }
          }
      }
    }

    MemberNoteAdded(Ok(note)) -> {
      let updated = case model.member_notes {
        Loaded(notes) -> [note, ..notes]
        _ -> [note]
      }

      #(
        Model(
          ..model,
          member_note_in_flight: False,
          member_note_content: "",
          member_notes: Loaded(updated),
          toast: opt.Some("Note added"),
        ),
        effect.none(),
      )
    }

    MemberNoteAdded(Error(err)) -> {
      case err.status {
        401 -> #(Model(..model, page: Login, user: opt.None), effect.none())
        _ -> {
          let model =
            Model(
              ..model,
              member_note_in_flight: False,
              member_note_error: opt.Some(err.message),
            )

          case model.member_notes_task_id {
            opt.Some(task_id) -> #(
              model,
              api.list_task_notes(task_id, MemberNotesFetched),
            )
            opt.None -> #(model, effect.none())
          }
        }
      }
    }
  }
}

fn bootstrap_admin(model: Model) -> #(Model, Effect(Msg)) {
  let model = Model(..model, projects: Loading, invite_links: Loading)

  #(
    model,
    effect.batch([
      api.list_projects(ProjectsFetched),
      api.list_capabilities(CapabilitiesFetched),
      api.get_me_capability_ids(MemberMyCapabilityIdsFetched),
      api.list_invite_links(InviteLinksFetched),
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
    permissions.Invites -> {
      let model = Model(..model, invite_links: Loading)
      #(model, api.list_invite_links(InviteLinksFetched))
    }

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

@external(javascript, "./scrumbringer_client/fetch.ffi.mjs", "days_since_iso")
fn days_since_iso_ffi(_iso: String) -> Int {
  0
}

@external(javascript, "./scrumbringer_client/fetch.ffi.mjs", "element_client_offset")
fn element_client_offset_ffi(_id: String) -> #(Int, Int) {
  #(0, 0)
}

@external(javascript, "./scrumbringer_client/fetch.ffi.mjs", "location_origin")
fn location_origin_ffi() -> String {
  ""
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
      Member -> view_member(model)
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
      button([event.on_click(SwitchToMember)], [text("App")]),
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

  let empty_label = case model.page {
    Member -> "All projects"
    _ -> "Select a project to manage settings…"
  }

  let helper = case model.page, model.selected_project_id {
    Member, opt.None -> "Showing tasks from all projects"
    Member, _ -> ""
    _, opt.None -> "Select a project to manage members or task types"
    _, _ -> ""
  }

  div([attribute.class("project-selector")], [
    label([], [text("Project")]),
    select(
      [
        attribute.value(selected_id),
        event.on_input(ProjectSelected),
      ],
      [
        option([attribute.value("")], empty_label),
        ..list.map(projects, fn(p) {
          option([attribute.value(int.to_string(p.id))], p.name)
        })
      ],
    ),
    case helper == "" {
      True -> div([], [])
      False -> div([attribute.class("hint")], [text(helper)])
    },
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

            let needs_project =
              section == permissions.Members || section == permissions.TaskTypes

            let disabled =
              needs_project && model.selected_project_id == opt.None

            button(
              [
                attribute.class(classes),
                attribute.disabled(disabled),
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
  let create_label = case model.invite_link_in_flight {
    True -> "Working..."
    False -> "Create invite link"
  }

  let origin = location_origin_ffi()

  div([attribute.class("section")], [
    p([], [
      text(
        "Create invite links tied to a specific email. Copy the generated link to onboard a user.",
      ),
    ]),
    case model.invite_link_error {
      opt.Some(err) -> div([attribute.class("error")], [text(err)])
      opt.None -> div([], [])
    },
    form([event.on_submit(fn(_) { InviteLinkCreateSubmitted })], [
      div([attribute.class("field")], [
        label([], [text("email")]),
        input([
          attribute.type_("email"),
          attribute.value(model.invite_link_email),
          event.on_input(InviteLinkEmailChanged),
          attribute.required(True),
        ]),
      ]),
      button(
        [
          attribute.type_("submit"),
          attribute.disabled(model.invite_link_in_flight),
        ],
        [text(create_label)],
      ),
    ]),
    case model.invite_link_last {
      opt.None -> div([], [])

      opt.Some(link) -> {
        let full = build_full_url(origin, link.url_path)

        div([attribute.class("invite-result")], [
          h3([], [text("Latest invite link")]),
          div([attribute.class("field")], [
            label([], [text("email")]),
            input([
              attribute.type_("text"),
              attribute.value(link.email),
              attribute.readonly(True),
            ]),
          ]),
          div([attribute.class("field")], [
            label([], [text("link")]),
            input([
              attribute.type_("text"),
              attribute.value(full),
              attribute.readonly(True),
            ]),
          ]),
          button([event.on_click(InviteLinkCopyClicked(full))], [text("Copy")]),
          case model.invite_link_copy_status {
            opt.Some(status) -> div([attribute.class("hint")], [text(status)])
            opt.None -> div([], [])
          },
        ])
      }
    },
    hr([]),
    h3([], [text("Invite links")]),
    view_invite_links_list(model, origin),
  ])
}

fn view_invite_links_list(model: Model, origin: String) -> Element(Msg) {
  case model.invite_links {
    NotAsked | Loading -> div([attribute.class("empty")], [text("Loading...")])

    Failed(err) ->
      div([attribute.class("error")], [
        text("Failed to load invite links: " <> err.message),
      ])

    Loaded(links) ->
      case links {
        [] -> div([attribute.class("empty")], [text("No invite links yet")])

        _ ->
          table([attribute.class("table")], [
            thead([], [
              tr([], [
                th([], [text("email")]),
                th([], [text("state")]),
                th([], [text("created_at")]),
                th([], [text("link")]),
                th([], [text("actions")]),
              ]),
            ]),
            tbody(
              [],
              list.map(links, fn(link) {
                let full = build_full_url(origin, link.url_path)

                tr([], [
                  td([], [text(link.email)]),
                  td([], [text(link.state)]),
                  td([], [text(link.created_at)]),
                  td([], [text(full)]),
                  td([], [
                    button(
                      [
                        attribute.disabled(model.invite_link_in_flight),
                        event.on_click(InviteLinkCopyClicked(full)),
                      ],
                      [text("Copy")],
                    ),
                    button(
                      [
                        attribute.disabled(model.invite_link_in_flight),
                        event.on_click(InviteLinkRegenerateClicked(link.email)),
                      ],
                      [text("Regenerate")],
                    ),
                  ]),
                ])
              }),
            ),
          ])
      }
  }
}

fn build_full_url(origin: String, url_path: String) -> String {
  case origin {
    "" -> url_path
    _ -> origin <> url_path
  }
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
        [] ->
          div([attribute.class("empty")], [
            h2([], [text("No task types yet")]),
            p([], [
              text(
                "Task types define what cards people can create (e.g., Bug, Feature).",
              ),
            ]),
            p([], [
              text("Create the first task type below to start using the Pool."),
            ]),
          ])
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

// --- Member UI (Story 1.8) ---

fn view_member(model: Model) -> Element(Msg) {
  case model.user {
    opt.None -> view_login(model)

    opt.Some(user) ->
      div([attribute.class("member")], [
        view_member_topbar(model, user),
        div([attribute.class("body")], [
          view_member_nav(model),
          div([attribute.class("content")], [view_member_section(model, user)]),
        ]),
      ])
  }
}

fn view_member_topbar(model: Model, user: User) -> Element(Msg) {
  div([attribute.class("topbar")], [
    div([attribute.class("topbar-title")], [
      text(case model.member_section {
        Pool -> "Pool"
        MyBar -> "My Bar"
        MySkills -> "My Skills"
      }),
    ]),
    view_project_selector(model),
    div([attribute.class("topbar-actions")], [
      case user.org_role {
        org_role.Admin ->
          button([event.on_click(SwitchToAdmin)], [text("Admin")])
        _ -> div([], [])
      },
      span([attribute.class("user")], [text(user.email)]),
      button([event.on_click(LogoutClicked)], [text("Logout")]),
    ]),
  ])
}

fn view_member_nav(model: Model) -> Element(Msg) {
  div([attribute.class("nav")], [
    h3([], [text("App")]),
    div([], [
      view_member_nav_button(model, Pool, "Pool"),
      view_member_nav_button(model, MyBar, "My Bar"),
      view_member_nav_button(model, MySkills, "My Skills"),
    ]),
  ])
}

fn view_member_nav_button(
  model: Model,
  section: MemberSection,
  label: String,
) -> Element(Msg) {
  let classes = case section == model.member_section {
    True -> "nav-item active"
    False -> "nav-item"
  }

  button(
    [attribute.class(classes), event.on_click(MemberNavSelected(section))],
    [text(label)],
  )
}

fn view_member_section(model: Model, user: User) -> Element(Msg) {
  case model.member_section {
    Pool -> view_member_pool(model)
    MyBar -> view_member_bar(model, user)
    MySkills -> view_member_skills(model)
  }
}

fn view_member_pool(model: Model) -> Element(Msg) {
  case active_projects(model) {
    [] ->
      div([attribute.class("empty")], [
        h2([], [text("No projects yet")]),
        p([], [
          text("Ask an admin to add you to a project."),
        ]),
      ])

    _ ->
      div([attribute.class("section")], [
        view_member_filters(model),
        p([], [
          text("Tip: use the ≡ handle on a card to drag it."),
        ]),
        button([event.on_click(MemberCreateDialogOpened)], [text("New task")]),
        case model.member_create_dialog_open {
          True -> view_member_create_dialog(model)
          False -> div([], [])
        },
        view_member_tasks(model),
        case model.member_notes_task_id {
          opt.Some(task_id) -> view_member_task_details(model, task_id)
          opt.None -> div([], [])
        },
        case model.member_position_edit_task {
          opt.Some(task_id) -> view_member_position_edit(model, task_id)
          opt.None -> div([], [])
        },
      ])
  }
}

fn view_member_filters(model: Model) -> Element(Msg) {
  let type_options = case model.member_task_types {
    Loaded(task_types) -> [
      option([attribute.value("")], "All"),
      ..list.map(task_types, fn(tt) {
        option([attribute.value(int.to_string(tt.id))], tt.name)
      })
    ]
    _ -> [option([attribute.value("")], "All")]
  }

  let capability_options = case model.capabilities {
    Loaded(caps) -> [
      option([attribute.value("")], "All"),
      ..list.map(caps, fn(c) {
        option([attribute.value(int.to_string(c.id))], c.name)
      })
    ]
    _ -> [option([attribute.value("")], "All")]
  }

  div([attribute.class("filters")], [
    div([attribute.class("field")], [
      label([], [text("Status")]),
      select(
        [
          attribute.value(model.member_filters_status),
          event.on_input(MemberPoolStatusChanged),
        ],
        [
          option([attribute.value("")], "All"),
          option([attribute.value("available")], "Available"),
          option([attribute.value("claimed")], "Claimed"),
          option([attribute.value("completed")], "Completed"),
        ],
      ),
    ]),
    div([attribute.class("field")], [
      label([], [text("Type")]),
      select(
        [
          attribute.value(model.member_filters_type_id),
          event.on_input(MemberPoolTypeChanged),
          attribute.disabled(case model.member_task_types {
            Loaded(_) -> False
            _ -> True
          }),
        ],
        type_options,
      ),
    ]),
    div([attribute.class("field")], [
      label([], [text("Capability")]),
      select(
        [
          attribute.value(model.member_filters_capability_id),
          event.on_input(MemberPoolCapabilityChanged),
        ],
        capability_options,
      ),
      button([event.on_click(MemberToggleMyCapabilitiesQuick)], [
        text(case model.member_quick_my_caps {
          True -> "My capabilities: ON"
          False -> "My capabilities: OFF"
        }),
      ]),
    ]),
    div([attribute.class("field")], [
      label([], [text("Search")]),
      input([
        attribute.type_("text"),
        attribute.value(model.member_filters_q),
        event.on_input(MemberPoolSearchChanged),
        event.debounce(event.on_input(MemberPoolSearchDebounced), 350),
        attribute.placeholder("q..."),
      ]),
    ]),
  ])
}

fn view_member_tasks(model: Model) -> Element(Msg) {
  case model.member_tasks {
    NotAsked | Loading -> div([attribute.class("empty")], [text("Loading...")])
    Failed(err) -> div([attribute.class("error")], [text(err.message)])

    Loaded(tasks) ->
      case tasks {
        [] -> {
          let no_filters =
            string.trim(model.member_filters_status) == ""
            && string.trim(model.member_filters_type_id) == ""
            && string.trim(model.member_filters_capability_id) == ""
            && string.trim(model.member_filters_q) == ""

          case no_filters {
            True ->
              div([attribute.class("empty")], [
                h2([], [text("No tasks here yet")]),
                p([], [
                  text("Create your first task to start using the Pool."),
                ]),
                button([event.on_click(MemberCreateDialogOpened)], [
                  text("New task"),
                ]),
              ])

            False ->
              div([attribute.class("empty")], [
                text("No tasks match your filters"),
              ])
          }
        }

        _ ->
          div(
            [
              attribute.attribute("id", "member-canvas"),
              attribute.attribute(
                "style",
                "position: relative; min-height: 600px; touch-action: none;",
              ),
              event.on("mousemove", {
                use x <- decode.field("clientX", decode.int)
                use y <- decode.field("clientY", decode.int)
                decode.success(MemberDragMoved(x, y))
              }),
              event.on("mouseup", decode.success(MemberDragEnded)),
              event.on("mouseleave", decode.success(MemberDragEnded)),
            ],
            list.map(tasks, fn(task) { view_member_task_card(model, task) }),
          )
      }
  }
}

fn view_member_task_card(model: Model, task: api.Task) -> Element(Msg) {
  let api.Task(
    id: id,
    type_id: type_id,
    title: title,
    priority: priority,
    status: status,
    claimed_by: claimed_by,
    created_at: created_at,
    version: version,
    ..,
  ) = task

  let current_user_id = case model.user {
    opt.Some(u) -> u.id
    opt.None -> 0
  }

  let is_mine = claimed_by == opt.Some(current_user_id)

  let task_type = member_task_type_by_id(model.member_task_types, type_id)

  let type_label = case task_type {
    opt.Some(tt) -> tt.name <> " (" <> tt.icon <> ")"
    opt.None -> "Type #" <> int.to_string(type_id)
  }

  let highlight = member_should_highlight_task(model, task_type)

  let #(x, y) = case dict.get(model.member_positions_by_task, id) {
    Ok(xy) -> xy
    Error(_) -> #(0, 0)
  }

  let size = member_visuals.priority_to_px(priority)

  let age_days = age_in_days(created_at)

  let #(opacity, saturation) = decay_to_visuals(age_days)

  let border = case highlight {
    True -> "2px solid #0f766e"
    False -> "1px solid #ddd"
  }

  let style =
    "position:absolute; left:"
    <> int.to_string(x)
    <> "px; top:"
    <> int.to_string(y)
    <> "px; width:"
    <> int.to_string(size)
    <> "px; height:"
    <> int.to_string(size)
    <> "px; border:"
    <> border
    <> "; padding:8px; background:#fff; overflow:hidden; opacity:"
    <> float.to_string(opacity)
    <> "; filter:saturate("
    <> float.to_string(saturation)
    <> ");"

  let disable_actions = model.member_task_mutation_in_flight

  div([attribute.attribute("style", style)], [
    div(
      [
        attribute.attribute(
          "style",
          "display:flex; justify-content:space-between; align-items:flex-start; gap:8px;",
        ),
      ],
      [
        h3([], [text(title)]),
        div(
          [
            attribute.attribute(
              "style",
              "cursor:grab; user-select:none; padding:2px 6px; border:1px solid #ddd;",
            ),
            attribute.attribute("title", "Drag to move"),
            attribute.attribute("aria-label", "Drag to move"),
            event.on("mousedown", {
              use ox <- decode.field("offsetX", decode.int)
              use oy <- decode.field("offsetY", decode.int)
              decode.success(MemberDragStarted(id, ox, oy))
            }),
          ],
          [text("≡")],
        ),
      ],
    ),
    p([], [text("type: " <> type_label)]),
    p([], [text("age: " <> int.to_string(age_days) <> "d")]),
    p([], [text("status: " <> status)]),
    div([attribute.class("actions")], [
      case status, is_mine {
        "available", _ ->
          button(
            [
              event.on_click(MemberClaimClicked(id, version)),
              attribute.disabled(disable_actions),
            ],
            [text("Claim")],
          )

        "claimed", True ->
          div([], [
            button(
              [
                event.on_click(MemberReleaseClicked(id, version)),
                attribute.disabled(disable_actions),
              ],
              [text("Release")],
            ),
            button(
              [
                event.on_click(MemberCompleteClicked(id, version)),
                attribute.disabled(disable_actions),
              ],
              [text("Complete")],
            ),
          ])

        _, _ -> div([], [])
      },
      button(
        [
          event.on_click(MemberTaskDetailsOpened(id)),
          attribute.disabled(disable_actions),
        ],
        [text("Notes")],
      ),
      button(
        [
          event.on_click(MemberPositionEditOpened(id)),
          attribute.disabled(disable_actions),
        ],
        [text("Position")],
      ),
    ]),
  ])
}

fn view_member_create_dialog(model: Model) -> Element(Msg) {
  div([attribute.class("modal")], [
    div([attribute.class("modal-content")], [
      h3([], [text("New task")]),
      case model.member_create_error {
        opt.Some(err) -> div([attribute.class("error")], [text(err)])
        opt.None -> div([], [])
      },
      div([attribute.class("field")], [
        label([], [text("Title")]),
        input([
          attribute.type_("text"),
          attribute.value(model.member_create_title),
          event.on_input(MemberCreateTitleChanged),
        ]),
      ]),
      div([attribute.class("field")], [
        label([], [text("Description")]),
        input([
          attribute.type_("text"),
          attribute.value(model.member_create_description),
          event.on_input(MemberCreateDescriptionChanged),
        ]),
      ]),
      div([attribute.class("field")], [
        label([], [text("Priority")]),
        input([
          attribute.type_("number"),
          attribute.value(model.member_create_priority),
          event.on_input(MemberCreatePriorityChanged),
        ]),
      ]),
      div([attribute.class("field")], [
        label([], [text("Type")]),
        select(
          [
            attribute.value(model.member_create_type_id),
            event.on_input(MemberCreateTypeIdChanged),
          ],
          case model.member_task_types {
            Loaded(task_types) -> [
              option([attribute.value("")], "Select type"),
              ..list.map(task_types, fn(tt) {
                option([attribute.value(int.to_string(tt.id))], tt.name)
              })
            ]
            _ -> [option([attribute.value("")], "Loading...")]
          },
        ),
      ]),
      div([attribute.class("actions")], [
        button([event.on_click(MemberCreateDialogClosed)], [text("Cancel")]),
        button(
          [
            event.on_click(MemberCreateSubmitted),
            attribute.disabled(model.member_create_in_flight),
          ],
          [
            text(case model.member_create_in_flight {
              True -> "Creating..."
              False -> "Create"
            }),
          ],
        ),
      ]),
    ]),
  ])
}

fn view_member_bar(model: Model, user: User) -> Element(Msg) {
  case active_projects(model) {
    [] ->
      div([attribute.class("empty")], [
        text("You are not in any project yet. Ask an admin to add you."),
      ])

    _ -> {
      let tasks = case model.member_tasks {
        Loaded(tasks) -> tasks
        _ -> []
      }

      let mine =
        tasks
        |> list.filter(fn(t) {
          let api.Task(claimed_by: claimed_by, ..) = t
          claimed_by == opt.Some(user.id)
        })

      div([attribute.class("section")], [
        case mine {
          [] -> div([attribute.class("empty")], [text("No claimed tasks yet")])
          _ ->
            div([], list.map(mine, fn(t) { view_member_task_card(model, t) }))
        },
      ])
    }
  }
}

fn view_member_skills(model: Model) -> Element(Msg) {
  div([attribute.class("section")], [
    h2([], [text("My Skills")]),
    case model.member_my_capabilities_error {
      opt.Some(err) -> div([attribute.class("error")], [text(err)])
      opt.None -> div([], [])
    },
    view_member_skills_list(model),
    button(
      [
        event.on_click(MemberSaveCapabilitiesClicked),
        attribute.disabled(model.member_my_capabilities_in_flight),
      ],
      [
        text(case model.member_my_capabilities_in_flight {
          True -> "Saving..."
          False -> "Save"
        }),
      ],
    ),
  ])
}

fn view_member_skills_list(model: Model) -> Element(Msg) {
  case model.capabilities {
    Loaded(capabilities) ->
      div(
        [],
        list.map(capabilities, fn(c) {
          let selected = case
            dict.get(model.member_my_capability_ids_edit, c.id)
          {
            Ok(v) -> v
            Error(_) -> False
          }

          div([attribute.class("field")], [
            label([], [text(c.name)]),
            input([
              attribute.type_("checkbox"),
              attribute.attribute("checked", case selected {
                True -> "true"
                False -> "false"
              }),
              event.on_click(MemberToggleCapability(c.id)),
            ]),
          ])
        }),
      )

    _ -> div([attribute.class("empty")], [text("Loading...")])
  }
}

fn view_member_position_edit(model: Model, _task_id: Int) -> Element(Msg) {
  div([attribute.class("modal")], [
    div([attribute.class("modal-content")], [
      h3([], [text("Edit position")]),
      case model.member_position_edit_error {
        opt.Some(err) -> div([attribute.class("error")], [text(err)])
        opt.None -> div([], [])
      },
      div([attribute.class("field")], [
        label([], [text("x")]),
        input([
          attribute.type_("number"),
          attribute.value(model.member_position_edit_x),
          event.on_input(MemberPositionEditXChanged),
        ]),
      ]),
      div([attribute.class("field")], [
        label([], [text("y")]),
        input([
          attribute.type_("number"),
          attribute.value(model.member_position_edit_y),
          event.on_input(MemberPositionEditYChanged),
        ]),
      ]),
      div([attribute.class("actions")], [
        button([event.on_click(MemberPositionEditClosed)], [text("Cancel")]),
        button(
          [
            event.on_click(MemberPositionEditSubmitted),
            attribute.disabled(model.member_position_edit_in_flight),
          ],
          [
            text(case model.member_position_edit_in_flight {
              True -> "Saving..."
              False -> "Save"
            }),
          ],
        ),
      ]),
    ]),
  ])
}

fn view_member_task_details(model: Model, task_id: Int) -> Element(Msg) {
  div([attribute.class("modal")], [
    div([attribute.class("modal-content")], [
      h3([], [text("Notes")]),
      button([event.on_click(MemberTaskDetailsClosed)], [text("Close")]),
      view_member_notes(model, task_id),
    ]),
  ])
}

fn view_member_notes(model: Model, _task_id: Int) -> Element(Msg) {
  let current_user_id = case model.user {
    opt.Some(u) -> u.id
    opt.None -> 0
  }

  div([], [
    case model.member_notes {
      NotAsked | Loading ->
        div([attribute.class("empty")], [text("Loading...")])
      Failed(err) -> div([attribute.class("error")], [text(err.message)])
      Loaded(notes) ->
        div(
          [],
          list.map(notes, fn(n) {
            let api.TaskNote(
              user_id: user_id,
              content: content,
              created_at: created_at,
              ..,
            ) = n
            let author = case user_id == current_user_id {
              True -> "You"
              False -> "User #" <> int.to_string(user_id)
            }

            div([attribute.class("note")], [
              p([], [text(author <> " @ " <> created_at)]),
              p([], [text(content)]),
            ])
          }),
        )
    },
    case model.member_note_error {
      opt.Some(err) -> div([attribute.class("error")], [text(err)])
      opt.None -> div([], [])
    },
    div([attribute.class("field")], [
      label([], [text("Add note")]),
      input([
        attribute.type_("text"),
        attribute.value(model.member_note_content),
        event.on_input(MemberNoteContentChanged),
      ]),
    ]),
    button(
      [
        event.on_click(MemberNoteSubmitted),
        attribute.disabled(model.member_note_in_flight),
      ],
      [
        text(case model.member_note_in_flight {
          True -> "Adding..."
          False -> "Add"
        }),
      ],
    ),
  ])
}

fn member_refresh(model: Model) -> #(Model, Effect(Msg)) {
  case model.member_section {
    MySkills -> #(model, effect.none())

    _ -> {
      let projects = active_projects(model)

      let project_ids = case model.selected_project_id {
        opt.Some(project_id) -> [project_id]
        opt.None -> projects |> list.map(fn(p) { p.id })
      }

      case project_ids {
        [] -> #(
          Model(
            ..model,
            member_tasks: NotAsked,
            member_tasks_pending: 0,
            member_tasks_by_project: dict.new(),
            member_task_types: NotAsked,
            member_task_types_pending: 0,
            member_task_types_by_project: dict.new(),
          ),
          effect.none(),
        )

        _ -> {
          let filters = case model.member_section {
            MyBar ->
              api.TaskFilters(
                status: opt.Some("claimed"),
                type_id: opt.None,
                capability_id: opt.None,
                q: opt.None,
              )

            _ ->
              api.TaskFilters(
                status: empty_to_opt(model.member_filters_status),
                type_id: empty_to_int_opt(model.member_filters_type_id),
                capability_id: empty_to_int_opt(
                  model.member_filters_capability_id,
                ),
                q: empty_to_opt(model.member_filters_q),
              )
          }

          let positions_effect =
            api.list_me_task_positions(
              model.selected_project_id,
              MemberPositionsFetched,
            )

          let task_effects =
            list.map(project_ids, fn(project_id) {
              api.list_project_tasks(project_id, filters, fn(result) {
                MemberProjectTasksFetched(project_id, result)
              })
            })

          let task_type_effects =
            list.map(project_ids, fn(project_id) {
              api.list_task_types(project_id, fn(result) {
                MemberTaskTypesFetched(project_id, result)
              })
            })

          let effects =
            list.append(
              task_effects,
              list.append(task_type_effects, [positions_effect]),
            )

          let model =
            Model(
              ..model,
              member_tasks: Loading,
              member_tasks_pending: list.length(project_ids),
              member_tasks_by_project: dict.new(),
              member_task_types: Loading,
              member_task_types_pending: list.length(project_ids),
              member_task_types_by_project: dict.new(),
            )

          #(model, effect.batch(effects))
        }
      }
    }
  }
}

fn member_handle_task_mutation_error(
  model: Model,
  err: api.ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status {
    401 -> #(Model(..model, page: Login, user: opt.None), effect.none())
    _ -> member_refresh(Model(..model, toast: opt.Some(err.message)))
  }
}

fn empty_to_opt(value: String) -> opt.Option(String) {
  case string.trim(value) == "" {
    True -> opt.None
    False -> opt.Some(value)
  }
}

fn empty_to_int_opt(value: String) -> opt.Option(Int) {
  let trimmed = string.trim(value)

  case trimmed == "" {
    True -> opt.None
    False ->
      case int.parse(trimmed) {
        Ok(i) -> opt.Some(i)
        Error(_) -> opt.None
      }
  }
}

fn ids_to_bool_dict(ids: List(Int)) -> dict.Dict(Int, Bool) {
  ids |> list.fold(dict.new(), fn(acc, id) { dict.insert(acc, id, True) })
}

fn bool_dict_to_ids(values: dict.Dict(Int, Bool)) -> List(Int) {
  values
  |> dict.to_list
  |> list.filter_map(fn(pair) {
    let #(id, selected) = pair
    case selected {
      True -> Ok(id)
      False -> Error(Nil)
    }
  })
}

fn positions_to_dict(
  positions: List(api.TaskPosition),
) -> dict.Dict(Int, #(Int, Int)) {
  positions
  |> list.fold(dict.new(), fn(acc, pos) {
    let api.TaskPosition(task_id: task_id, x: x, y: y, ..) = pos
    dict.insert(acc, task_id, #(x, y))
  })
}

fn flatten_tasks(
  tasks_by_project: dict.Dict(Int, List(api.Task)),
) -> List(api.Task) {
  tasks_by_project
  |> dict.to_list
  |> list.fold([], fn(acc, pair) {
    let #(_project_id, tasks) = pair
    list.append(acc, tasks)
  })
}

fn flatten_task_types(
  task_types_by_project: dict.Dict(Int, List(api.TaskType)),
) -> List(api.TaskType) {
  task_types_by_project
  |> dict.to_list
  |> list.fold([], fn(acc, pair) {
    let #(_project_id, task_types) = pair
    list.append(acc, task_types)
  })
}

fn age_in_days(created_at: String) -> Int {
  days_since_iso_ffi(created_at)
}

fn decay_to_visuals(age_days: Int) -> #(Float, Float) {
  case age_days {
    d if d < 9 -> #(1.0, 1.0)
    d if d < 18 -> #(0.95, 0.85)
    d if d < 27 -> #(0.85, 0.65)
    _ -> #(0.8, 0.55)
  }
}

fn member_task_type_by_id(
  task_types: Remote(List(api.TaskType)),
  type_id: Int,
) -> opt.Option(api.TaskType) {
  case task_types {
    Loaded(task_types) ->
      case list.find(task_types, fn(tt) { tt.id == type_id }) {
        Ok(tt) -> opt.Some(tt)
        Error(_) -> opt.None
      }
    _ -> opt.None
  }
}

fn member_should_highlight_task(
  model: Model,
  task_type: opt.Option(api.TaskType),
) -> Bool {
  case model.member_quick_my_caps {
    False -> False
    True ->
      case model.member_my_capability_ids, task_type {
        Loaded(my_ids), opt.Some(tt) ->
          case tt.capability_id {
            opt.Some(cap_id) -> list.any(my_ids, fn(id) { id == cap_id })
            opt.None -> False
          }
        _, _ -> False
      }
  }
}
