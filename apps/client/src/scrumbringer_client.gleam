import gleam/dict
import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/list
import gleam/option as opt
import gleam/order
import gleam/string

import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html.{
  button, div, form, h1, h2, h3, hr, img, input, label, option, p, select, span,
  style, table, tbody, td, text, th, thead, tr,
}
import lustre/event

import scrumbringer_domain/org_role
import scrumbringer_domain/user.{type User}

import scrumbringer_client/accept_invite
import scrumbringer_client/api
import scrumbringer_client/hydration
import scrumbringer_client/member_section
import scrumbringer_client/member_visuals
import scrumbringer_client/permissions
import scrumbringer_client/reset_password
import scrumbringer_client/router
import scrumbringer_client/styles
import scrumbringer_client/theme

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
  AcceptInvite
  ResetPassword
  Admin
  Member
}

type IconPreview {
  IconIdle
  IconLoading
  IconOk
  IconError
}

type MemberDrag {
  MemberDrag(task_id: Int, offset_x: Int, offset_y: Int)
}

pub opaque type Model {
  Model(
    page: Page,
    user: opt.Option(User),
    auth_checked: Bool,
    is_mobile: Bool,
    active_section: permissions.AdminSection,
    toast: opt.Option(String),
    theme: theme.Theme,
    login_email: String,
    login_password: String,
    login_error: opt.Option(String),
    login_in_flight: Bool,
    forgot_password_open: Bool,
    forgot_password_email: String,
    forgot_password_in_flight: Bool,
    forgot_password_result: opt.Option(api.PasswordReset),
    forgot_password_error: opt.Option(String),
    forgot_password_copy_status: opt.Option(String),
    accept_invite: accept_invite.Model,
    reset_password: reset_password.Model,
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
    members_project_id: opt.Option(Int),
    org_users_cache: Remote(List(api.OrgUser)),
    org_settings_users: Remote(List(api.OrgUser)),
    org_settings_role_drafts: dict.Dict(Int, String),
    org_settings_save_in_flight: Bool,
    org_settings_error: opt.Option(String),
    org_settings_error_user_id: opt.Option(Int),
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
    task_types_project_id: opt.Option(Int),
    task_types_create_name: String,
    task_types_create_icon: String,
    task_types_create_capability_id: opt.Option(String),
    task_types_create_in_flight: Bool,
    task_types_create_error: opt.Option(String),
    task_types_icon_preview: IconPreview,
    member_section: member_section.MemberSection,
    member_active_task: Remote(api.ActiveTaskPayload),
    member_now_working_in_flight: Bool,
    member_now_working_error: opt.Option(String),
    now_working_tick: Int,
    now_working_tick_running: Bool,
    now_working_server_offset_ms: Int,
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

pub type NavMode {
  Push
  Replace
}

pub type Msg {
  UrlChanged
  NavigateTo(router.Route, NavMode)

  MeFetched(api.ApiResult(User))
  AcceptInviteMsg(accept_invite.Msg)
  ResetPasswordMsg(reset_password.Msg)

  LoginEmailChanged(String)
  LoginPasswordChanged(String)
  LoginSubmitted
  LoginDomValuesRead(String, String)
  LoginFinished(api.ApiResult(User))

  ForgotPasswordClicked
  ForgotPasswordEmailChanged(String)
  ForgotPasswordSubmitted
  ForgotPasswordFinished(api.ApiResult(api.PasswordReset))
  ForgotPasswordCopyClicked
  ForgotPasswordCopyFinished(Bool)
  ForgotPasswordDismissed

  LogoutClicked
  LogoutFinished(api.ApiResult(Nil))

  ToastDismissed

  ThemeSelected(String)

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
  OrgSettingsUsersFetched(api.ApiResult(List(api.OrgUser)))
  OrgSettingsRoleChanged(Int, String)
  OrgSettingsSaveClicked(Int)
  OrgSettingsSaved(Int, api.ApiResult(api.OrgUser))

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

  MemberNowWorkingStartClicked(Int)
  MemberNowWorkingPauseClicked
  MemberActiveTaskFetched(api.ApiResult(api.ActiveTaskPayload))
  MemberActiveTaskStarted(api.ApiResult(api.ActiveTaskPayload))
  MemberActiveTaskPaused(api.ApiResult(api.ActiveTaskPayload))
  NowWorkingTicked

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
  let pathname = location_pathname_ffi()
  let search = location_search_ffi()
  let hash = location_hash_ffi()
  let is_mobile = is_mobile_ffi()

  let parsed =
    router.parse(pathname, search, hash)
    |> router.apply_mobile_rules(is_mobile)

  let route = case parsed {
    router.Parsed(route) -> route
    router.Redirect(route) -> route
  }

  let accept_token = case route {
    router.AcceptInvite(token) -> token
    _ -> ""
  }

  let reset_token = case route {
    router.ResetPassword(token) -> token
    _ -> ""
  }

  let page = case route {
    router.Login -> Login
    router.AcceptInvite(_) -> AcceptInvite
    router.ResetPassword(_) -> ResetPassword
    router.Admin(_, _) -> Admin
    router.Member(_, _) -> Member
  }

  let active_section = case route {
    router.Admin(section, _) -> section
    _ -> permissions.Invites
  }

  let member_section = case route {
    router.Member(section, _) -> section
    _ -> member_section.Pool
  }

  let selected_project_id = case route {
    router.Admin(_, project_id) | router.Member(_, project_id) -> project_id
    _ -> opt.None
  }

  let #(accept_model, accept_action) = accept_invite.init(accept_token)
  let #(reset_model, reset_action) = reset_password.init(reset_token)

  let active_theme = theme.load_from_storage()

  let model =
    Model(
      page: page,
      user: opt.None,
      auth_checked: False,
      is_mobile: is_mobile,
      active_section: active_section,
      toast: opt.None,
      theme: active_theme,
      login_email: "",
      login_password: "",
      login_error: opt.None,
      login_in_flight: False,
      forgot_password_open: False,
      forgot_password_email: "",
      forgot_password_in_flight: False,
      forgot_password_result: opt.None,
      forgot_password_error: opt.None,
      forgot_password_copy_status: opt.None,
      accept_invite: accept_model,
      reset_password: reset_model,
      projects: NotAsked,
      selected_project_id: selected_project_id,
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
      members_project_id: opt.None,
      org_users_cache: NotAsked,
      org_settings_users: NotAsked,
      org_settings_role_drafts: dict.new(),
      org_settings_save_in_flight: False,
      org_settings_error: opt.None,
      org_settings_error_user_id: opt.None,
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
      task_types_project_id: opt.None,
      task_types_create_name: "",
      task_types_create_icon: "",
      task_types_create_capability_id: opt.None,
      task_types_create_in_flight: False,
      task_types_create_error: opt.None,
      task_types_icon_preview: IconIdle,
      member_section: member_section,
      member_active_task: NotAsked,
      member_now_working_in_flight: False,
      member_now_working_error: opt.None,
      now_working_tick: 0,
      now_working_tick_running: False,
      now_working_server_offset_ms: 0,
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

  let base_effect = case page {
    AcceptInvite -> accept_invite_effect(accept_action)
    ResetPassword -> reset_password_effect(reset_action)
    _ -> api.fetch_me(MeFetched)
  }

  let tick_fx = effect.none()

  let redirect_fx = case parsed {
    router.Redirect(_) -> write_url(Replace, route)
    router.Parsed(_) -> effect.none()
  }

  #(
    model,
    effect.batch([
      register_popstate_effect(),
      redirect_fx,
      base_effect,
      tick_fx,
    ]),
  )
}

fn current_route(model: Model) -> router.Route {
  case model.page {
    Login -> router.Login

    AcceptInvite -> {
      let accept_invite.Model(token: token, ..) = model.accept_invite
      router.AcceptInvite(token)
    }

    ResetPassword -> {
      let reset_password.Model(token: token, ..) = model.reset_password
      router.ResetPassword(token)
    }

    Admin -> router.Admin(model.active_section, model.selected_project_id)

    Member -> router.Member(model.member_section, model.selected_project_id)
  }
}

fn url_for_model(model: Model) -> String {
  router.format(current_route(model))
}

@external(javascript, "./scrumbringer_client/fetch.ffi.mjs", "history_push_state")
fn history_push_state_ffi(_path: String) -> Nil {
  Nil
}

@external(javascript, "./scrumbringer_client/fetch.ffi.mjs", "history_replace_state")
fn history_replace_state_ffi(_path: String) -> Nil {
  Nil
}

fn replace_url(model: Model) -> Effect(Msg) {
  let path = url_for_model(model)
  effect.from(fn(_dispatch) { history_replace_state_ffi(path) })
}

fn accept_invite_effect(action: accept_invite.Action) -> Effect(Msg) {
  case action {
    accept_invite.ValidateToken(token) ->
      api.validate_invite_link_token(token, fn(result) {
        AcceptInviteMsg(accept_invite.TokenValidated(result))
      })

    _ -> effect.none()
  }
}

fn reset_password_effect(action: reset_password.Action) -> Effect(Msg) {
  case action {
    reset_password.ValidateToken(token) ->
      api.validate_password_reset_token(token, fn(result) {
        ResetPasswordMsg(reset_password.TokenValidated(result))
      })

    _ -> effect.none()
  }
}

@external(javascript, "./scrumbringer_client/fetch.ffi.mjs", "register_popstate")
fn register_popstate_ffi(_cb: fn(Nil) -> Nil) -> Nil {
  Nil
}

fn register_popstate_effect() -> Effect(Msg) {
  effect.from(fn(dispatch) {
    register_popstate_ffi(fn(_) { dispatch(UrlChanged) })
  })
}

fn read_login_values_effect() -> Effect(Msg) {
  effect.from(fn(dispatch) {
    let email = input_value_ffi("login-email")
    let password = input_value_ffi("login-password")
    dispatch(LoginDomValuesRead(email, password))
    Nil
  })
}

fn write_url(mode: NavMode, route: router.Route) -> Effect(Msg) {
  let url = router.format(route)

  effect.from(fn(_dispatch) {
    case mode {
      Push -> history_push_state_ffi(url)
      Replace -> history_replace_state_ffi(url)
    }
  })
}

fn apply_route_fields(
  model: Model,
  route: router.Route,
) -> #(Model, Effect(Msg)) {
  let model = Model(..model, toast: opt.None)

  case route {
    router.Login -> {
      #(
        Model(..model, page: Login, selected_project_id: opt.None),
        effect.none(),
      )
    }

    router.AcceptInvite(token) -> {
      let #(accept_model, action) = accept_invite.init(token)
      let model =
        Model(
          ..model,
          page: AcceptInvite,
          accept_invite: accept_model,
          selected_project_id: opt.None,
        )

      #(model, accept_invite_effect(action))
    }

    router.ResetPassword(token) -> {
      let #(reset_model, action) = reset_password.init(token)
      let model =
        Model(
          ..model,
          page: ResetPassword,
          reset_password: reset_model,
          selected_project_id: opt.None,
        )

      #(model, reset_password_effect(action))
    }

    router.Admin(section, project_id) -> {
      #(
        Model(
          ..model,
          page: Admin,
          active_section: section,
          selected_project_id: project_id,
        ),
        effect.none(),
      )
    }

    router.Member(section, project_id) -> {
      #(
        Model(
          ..model,
          page: Member,
          member_section: section,
          selected_project_id: project_id,
        ),
        effect.none(),
      )
    }
  }
}

fn remote_state(remote: Remote(a)) -> hydration.ResourceState {
  case remote {
    NotAsked -> hydration.NotAsked
    Loading -> hydration.Loading
    Loaded(_) -> hydration.Loaded
    Failed(_) -> hydration.Failed
  }
}

fn auth_state(model: Model) -> hydration.AuthState {
  case model.user {
    opt.Some(user) -> hydration.Authed(user.org_role)

    opt.None ->
      case model.auth_checked {
        True -> hydration.Unauthed
        False -> hydration.Unknown
      }
  }
}

fn build_snapshot(model: Model) -> hydration.Snapshot {
  hydration.Snapshot(
    auth: auth_state(model),
    projects: remote_state(model.projects),
    invite_links: remote_state(model.invite_links),
    capabilities: remote_state(model.capabilities),
    my_capability_ids: remote_state(model.member_my_capability_ids),
    org_settings_users: remote_state(model.org_settings_users),
    members: remote_state(model.members),
    members_project_id: model.members_project_id,
    task_types: remote_state(model.task_types),
    task_types_project_id: model.task_types_project_id,
    member_tasks: remote_state(model.member_tasks),
    active_task: remote_state(model.member_active_task),
  )
}

fn hydrate_model(model: Model) -> #(Model, Effect(Msg)) {
  let route = current_route(model)
  let commands = hydration.plan(route, build_snapshot(model))

  case
    list.find(commands, fn(cmd) {
      case cmd {
        hydration.Redirect(_) -> True
        _ -> False
      }
    })
  {
    Ok(hydration.Redirect(to: to)) -> {
      case to == route {
        True -> #(model, effect.none())
        False -> handle_navigate_to(model, to, Replace)
      }
    }

    _ -> {
      let #(next, effects) =
        list.fold(commands, #(model, []), fn(state, cmd) {
          let #(m, fx) = state

          case cmd {
            hydration.FetchMe -> {
              #(m, [api.fetch_me(MeFetched), ..fx])
            }

            hydration.FetchProjects -> {
              case m.projects {
                Loading | Loaded(_) -> #(m, fx)

                _ -> {
                  let m = Model(..m, projects: Loading)
                  #(m, [api.list_projects(ProjectsFetched), ..fx])
                }
              }
            }

            hydration.FetchInviteLinks -> {
              case m.invite_links {
                Loading | Loaded(_) -> #(m, fx)

                _ -> {
                  let m = Model(..m, invite_links: Loading)
                  #(m, [api.list_invite_links(InviteLinksFetched), ..fx])
                }
              }
            }

            hydration.FetchCapabilities -> {
              case m.capabilities {
                Loading | Loaded(_) -> #(m, fx)

                _ -> {
                  let m = Model(..m, capabilities: Loading)
                  #(m, [api.list_capabilities(CapabilitiesFetched), ..fx])
                }
              }
            }

            hydration.FetchMeCapabilityIds -> {
              case m.member_my_capability_ids {
                Loading | Loaded(_) -> #(m, fx)

                _ -> {
                  let m = Model(..m, member_my_capability_ids: Loading)
                  #(m, [
                    api.get_me_capability_ids(MemberMyCapabilityIdsFetched),
                    ..fx
                  ])
                }
              }
            }

            hydration.FetchActiveTask -> {
              case m.member_active_task {
                Loading | Loaded(_) -> #(m, fx)

                _ -> {
                  let m = Model(..m, member_active_task: Loading)
                  #(m, [api.get_me_active_task(MemberActiveTaskFetched), ..fx])
                }
              }
            }

            hydration.FetchOrgSettingsUsers -> {
              case m.org_settings_users {
                Loading | Loaded(_) -> #(m, fx)

                _ -> {
                  let m =
                    Model(
                      ..m,
                      org_settings_users: Loading,
                      org_settings_role_drafts: dict.new(),
                      org_settings_save_in_flight: False,
                      org_settings_error: opt.None,
                      org_settings_error_user_id: opt.None,
                    )

                  #(m, [api.list_org_users("", OrgSettingsUsersFetched), ..fx])
                }
              }
            }

            hydration.FetchMembers(project_id: project_id) -> {
              let can_fetch = case m.projects {
                Loaded(projects) ->
                  list.any(projects, fn(p) { p.id == project_id })
                _ -> False
              }

              case can_fetch {
                False -> #(m, fx)

                True ->
                  case m.members {
                    Loading -> #(m, fx)

                    _ -> {
                      let m =
                        Model(
                          ..m,
                          members: Loading,
                          members_project_id: opt.Some(project_id),
                          org_users_cache: Loading,
                        )

                      let fx_members =
                        api.list_project_members(project_id, MembersFetched)
                      let fx_users =
                        api.list_org_users("", OrgUsersCacheFetched)

                      #(m, [effect.batch([fx_members, fx_users]), ..fx])
                    }
                  }
              }
            }

            hydration.FetchTaskTypes(project_id: project_id) -> {
              let can_fetch = case m.projects {
                Loaded(projects) ->
                  list.any(projects, fn(p) { p.id == project_id })
                _ -> False
              }

              case can_fetch {
                False -> #(m, fx)

                True ->
                  case m.task_types {
                    Loading -> #(m, fx)

                    _ -> {
                      let m =
                        Model(
                          ..m,
                          task_types: Loading,
                          task_types_project_id: opt.Some(project_id),
                        )

                      #(m, [
                        api.list_task_types(project_id, TaskTypesFetched),
                        ..fx
                      ])
                    }
                  }
              }
            }

            hydration.RefreshMember -> {
              case m.projects {
                Loaded(_) -> {
                  let #(m, member_fx) = member_refresh(m)
                  #(m, [member_fx, ..fx])
                }

                _ -> #(m, fx)
              }
            }

            hydration.Redirect(_) -> #(m, fx)
          }
        })

      #(next, effect.batch(list.reverse(effects)))
    }
  }
}

fn handle_url_changed(model: Model) -> #(Model, Effect(Msg)) {
  let pathname = location_pathname_ffi()
  let search = location_search_ffi()
  let hash = location_hash_ffi()
  let is_mobile = is_mobile_ffi()

  let model = Model(..model, is_mobile: is_mobile)

  let parsed =
    router.parse(pathname, search, hash)
    |> router.apply_mobile_rules(is_mobile)

  let route = case parsed {
    router.Parsed(route) -> route
    router.Redirect(route) -> route
  }

  let current = current_route(model)

  case parsed {
    router.Parsed(_) ->
      case route == current {
        True -> #(model, effect.none())

        False -> {
          let #(model, route_fx) = apply_route_fields(model, route)
          let #(model, hyd_fx) = hydrate_model(model)
          #(model, effect.batch([route_fx, hyd_fx]))
        }
      }

    router.Redirect(_) -> {
      let #(model, route_fx) = apply_route_fields(model, route)
      let #(model, hyd_fx) = hydrate_model(model)
      #(model, effect.batch([write_url(Replace, route), route_fx, hyd_fx]))
    }
  }
}

fn handle_navigate_to(
  model: Model,
  route: router.Route,
  mode: NavMode,
) -> #(Model, Effect(Msg)) {
  let #(next_route, next_mode) = case model.is_mobile, route {
    True, router.Member(member_section.Pool, project_id) -> #(
      router.Member(member_section.MyBar, project_id),
      Replace,
    )
    _, _ -> #(route, mode)
  }

  case next_route == current_route(model) {
    True -> #(model, effect.none())

    False -> {
      let #(model, route_fx) = apply_route_fields(model, next_route)
      let #(model, hyd_fx) = hydrate_model(model)

      #(
        model,
        effect.batch([write_url(next_mode, next_route), route_fx, hyd_fx]),
      )
    }
  }
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    UrlChanged -> handle_url_changed(model)

    NavigateTo(route, mode) -> handle_navigate_to(model, route, mode)

    MeFetched(Ok(user)) -> {
      let default_page = case user.org_role {
        org_role.Admin -> Admin
        _ -> Member
      }

      let resolved_page = case model.page {
        // Allow admin users to keep using the Member app if the URL requested it.
        Member -> Member

        // Non-admin users cannot access /admin/*.
        Admin ->
          case user.org_role {
            org_role.Admin -> Admin
            _ -> Member
          }

        // Login, AcceptInvite, ResetPassword: go to role default.
        _ -> default_page
      }

      let model =
        Model(
          ..model,
          page: resolved_page,
          user: opt.Some(user),
          auth_checked: True,
        )
      let #(model, boot) = bootstrap_admin(model)
      let #(model, hyd_fx) = hydrate_model(model)

      #(
        model,
        effect.batch([
          boot,
          hyd_fx,
          replace_url(model),
        ]),
      )
    }

    MeFetched(Error(err)) -> {
      case err.status == 401 {
        True -> {
          let model =
            Model(..model, page: Login, user: opt.None, auth_checked: True)
          #(model, replace_url(model))
        }

        False -> {
          let model =
            Model(
              ..model,
              page: Login,
              user: opt.None,
              auth_checked: True,
              login_error: opt.Some(err.message),
            )

          #(model, replace_url(model))
        }
      }
    }

    AcceptInviteMsg(inner) -> {
      let #(next_accept, action) =
        accept_invite.update(model.accept_invite, inner)
      let model = Model(..model, accept_invite: next_accept, toast: opt.None)

      case action {
        accept_invite.NoOp -> #(model, effect.none())

        accept_invite.ValidateToken(_) -> #(model, accept_invite_effect(action))

        accept_invite.Register(token: token, password: password) -> #(
          model,
          api.register_with_invite_link(token, password, fn(result) {
            AcceptInviteMsg(accept_invite.Registered(result))
          }),
        )

        accept_invite.Authed(user) -> {
          let page = case user.org_role {
            org_role.Admin -> Admin
            _ -> Member
          }

          let model =
            Model(
              ..model,
              page: page,
              user: opt.Some(user),
              auth_checked: True,
              toast: opt.Some("Welcome"),
            )

          let #(model, boot) = bootstrap_admin(model)
          let #(model, hyd_fx) = hydrate_model(model)
          #(
            model,
            effect.batch([
              boot,
              hyd_fx,
              replace_url(model),
            ]),
          )
        }
      }
    }

    ResetPasswordMsg(inner) -> {
      let #(next_reset, action) =
        reset_password.update(model.reset_password, inner)

      let model = Model(..model, reset_password: next_reset, toast: opt.None)

      case action {
        reset_password.NoOp -> #(model, effect.none())

        reset_password.ValidateToken(_) -> #(
          model,
          reset_password_effect(action),
        )

        reset_password.Consume(token: token, password: password) -> #(
          model,
          api.consume_password_reset_token(token, password, fn(result) {
            ResetPasswordMsg(reset_password.Consumed(result))
          }),
        )

        reset_password.GoToLogin -> {
          let model =
            Model(
              ..model,
              page: Login,
              toast: opt.Some("Password updated"),
              login_password: "",
              login_error: opt.None,
            )

          #(model, replace_url(model))
        }
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

          #(model, read_login_values_effect())
        }
      }
    }

    LoginDomValuesRead(raw_email, raw_password) -> {
      let email = string.trim(raw_email)
      let password = raw_password

      case email == "" || password == "" {
        True -> #(
          Model(
            ..model,
            login_in_flight: False,
            login_error: opt.Some("Email and password required"),
          ),
          effect.none(),
        )

        False -> {
          let model =
            Model(..model, login_email: email, login_password: password)
          #(model, api.login(email, password, LoginFinished))
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
          auth_checked: True,
          login_in_flight: False,
          login_password: "",
          toast: opt.Some("Logged in"),
        )

      let #(model, boot) = bootstrap_admin(model)
      let #(model, hyd_fx) = hydrate_model(model)
      #(
        model,
        effect.batch([
          boot,
          hyd_fx,
          replace_url(model),
        ]),
      )
    }

    LoginFinished(Error(err)) -> {
      let message = case err.status {
        401 | 403 -> "Invalid credentials"
        _ -> err.message
      }

      #(
        Model(..model, login_in_flight: False, login_error: opt.Some(message)),
        effect.none(),
      )
    }

    ForgotPasswordClicked -> {
      let open = !model.forgot_password_open

      #(
        Model(
          ..model,
          forgot_password_open: open,
          forgot_password_in_flight: False,
          forgot_password_result: opt.None,
          forgot_password_error: opt.None,
          forgot_password_copy_status: opt.None,
          toast: opt.None,
        ),
        effect.none(),
      )
    }

    ForgotPasswordEmailChanged(email) -> #(
      Model(
        ..model,
        forgot_password_email: email,
        forgot_password_error: opt.None,
        forgot_password_copy_status: opt.None,
      ),
      effect.none(),
    )

    ForgotPasswordSubmitted -> {
      case model.forgot_password_in_flight {
        True -> #(model, effect.none())

        False -> {
          let email = string.trim(model.forgot_password_email)

          case email == "" {
            True -> #(
              Model(
                ..model,
                forgot_password_error: opt.Some("Email is required"),
              ),
              effect.none(),
            )

            False -> {
              let model =
                Model(
                  ..model,
                  forgot_password_in_flight: True,
                  forgot_password_error: opt.None,
                  forgot_password_result: opt.None,
                  forgot_password_copy_status: opt.None,
                )

              #(
                model,
                api.request_password_reset(email, ForgotPasswordFinished),
              )
            }
          }
        }
      }
    }

    ForgotPasswordFinished(Ok(reset)) -> #(
      Model(
        ..model,
        forgot_password_in_flight: False,
        forgot_password_result: opt.Some(reset),
        forgot_password_error: opt.None,
        forgot_password_copy_status: opt.None,
      ),
      effect.none(),
    )

    ForgotPasswordFinished(Error(err)) -> #(
      Model(
        ..model,
        forgot_password_in_flight: False,
        forgot_password_error: opt.Some(err.message),
      ),
      effect.none(),
    )

    ForgotPasswordCopyClicked -> {
      case model.forgot_password_result {
        opt.None -> #(model, effect.none())

        opt.Some(reset) -> {
          let origin = location_origin_ffi()
          let text = origin <> reset.url_path

          #(
            Model(..model, forgot_password_copy_status: opt.Some("Copying…")),
            copy_to_clipboard(text, ForgotPasswordCopyFinished),
          )
        }
      }
    }

    ForgotPasswordCopyFinished(ok) -> {
      let message = case ok {
        True -> "Copied"
        False -> "Copy failed"
      }

      #(
        Model(..model, forgot_password_copy_status: opt.Some(message)),
        effect.none(),
      )
    }

    ForgotPasswordDismissed -> #(
      Model(
        ..model,
        forgot_password_error: opt.None,
        forgot_password_copy_status: opt.None,
        forgot_password_result: opt.None,
      ),
      effect.none(),
    )

    LogoutClicked -> #(
      Model(..model, toast: opt.None),
      api.logout(LogoutFinished),
    )

    LogoutFinished(Ok(_)) -> {
      let model =
        Model(
          ..model,
          page: Login,
          user: opt.None,
          auth_checked: False,
          toast: opt.Some("Logged out"),
        )

      #(model, replace_url(model))
    }

    LogoutFinished(Error(err)) -> {
      case err.status == 401 {
        True -> {
          let model =
            Model(..model, page: Login, user: opt.None, auth_checked: False)
          #(model, replace_url(model))
        }

        False -> #(
          Model(..model, toast: opt.Some("Logout failed")),
          effect.none(),
        )
      }
    }

    ToastDismissed -> #(Model(..model, toast: opt.None), effect.none())

    ThemeSelected(value) -> {
      let next_theme = theme.deserialize(value)

      case next_theme == model.theme {
        True -> #(model, effect.none())

        False -> #(
          Model(..model, theme: next_theme),
          effect.from(fn(_dispatch) { theme.save_to_storage(next_theme) }),
        )
      }
    }

    ProjectSelected(project_id) -> {
      let selected = case int.parse(project_id) {
        Ok(id) -> opt.Some(id)
        Error(_) -> opt.None
      }

      let should_pause =
        should_pause_active_task_on_project_change(
          model.page == Member,
          model.selected_project_id,
          selected,
        )

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
        Member -> {
          let #(model, fx) = member_refresh(model)

          let pause_fx = case should_pause {
            True -> api.pause_me_active_task(MemberActiveTaskPaused)
            False -> effect.none()
          }

          #(model, effect.batch([fx, pause_fx, replace_url(model)]))
        }

        _ -> {
          let #(model, fx) = refresh_section(model)
          #(model, effect.batch([fx, replace_url(model)]))
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

      case model.page {
        Member -> {
          let #(model, fx) = member_refresh(model)
          let #(model, hyd_fx) = hydrate_model(model)
          #(model, effect.batch([fx, hyd_fx, replace_url(model)]))
        }

        Admin -> {
          let #(model, fx) = refresh_section(model)
          let #(model, hyd_fx) = hydrate_model(model)
          #(model, effect.batch([fx, hyd_fx, replace_url(model)]))
        }

        _ -> {
          let #(model, hyd_fx) = hydrate_model(model)
          #(model, effect.batch([hyd_fx, replace_url(model)]))
        }
      }
    }

    ProjectsFetched(Error(err)) -> {
      case err.status == 401 {
        True -> {
          let model = Model(..model, page: Login, user: opt.None)
          #(model, replace_url(model))
        }

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

    OrgSettingsUsersFetched(Ok(users)) -> #(
      Model(
        ..model,
        org_settings_users: Loaded(users),
        org_settings_role_drafts: dict.new(),
        org_settings_save_in_flight: False,
        org_settings_error: opt.None,
        org_settings_error_user_id: opt.None,
      ),
      effect.none(),
    )

    OrgSettingsUsersFetched(Error(err)) -> {
      case err.status {
        401 -> #(Model(..model, page: Login, user: opt.None), effect.none())

        403 -> #(
          Model(
            ..model,
            org_settings_users: Failed(err),
            toast: opt.Some("Not permitted"),
          ),
          effect.none(),
        )

        _ -> #(Model(..model, org_settings_users: Failed(err)), effect.none())
      }
    }

    OrgSettingsRoleChanged(user_id, org_role) -> #(
      Model(
        ..model,
        org_settings_role_drafts: dict.insert(
          model.org_settings_role_drafts,
          user_id,
          org_role,
        ),
        org_settings_error: opt.None,
        org_settings_error_user_id: opt.None,
      ),
      effect.none(),
    )

    OrgSettingsSaveClicked(user_id) -> {
      case model.org_settings_save_in_flight {
        True -> #(model, effect.none())

        False -> {
          let role = case dict.get(model.org_settings_role_drafts, user_id) {
            Ok(r) -> r

            Error(_) -> {
              case model.org_settings_users {
                Loaded(users) -> {
                  case list.find(users, fn(u) { u.id == user_id }) {
                    Ok(u) -> u.org_role
                    Error(_) -> ""
                  }
                }

                _ -> ""
              }
            }
          }

          case role {
            "admin" | "member" -> {
              let model =
                Model(
                  ..model,
                  org_settings_save_in_flight: True,
                  org_settings_error: opt.None,
                  org_settings_error_user_id: opt.None,
                )

              #(
                model,
                api.update_org_user_role(user_id, role, fn(result) {
                  OrgSettingsSaved(user_id, result)
                }),
              )
            }

            _ -> #(model, effect.none())
          }
        }
      }
    }

    OrgSettingsSaved(_user_id, Ok(updated)) -> {
      let update_list = fn(users: List(api.OrgUser)) {
        list.map(users, fn(u) {
          case u.id == updated.id {
            True -> updated
            False -> u
          }
        })
      }

      let org_settings_users = case model.org_settings_users {
        Loaded(users) -> Loaded(update_list(users))
        other -> other
      }

      let org_users_cache = case model.org_users_cache {
        Loaded(users) -> Loaded(update_list(users))
        other -> other
      }

      #(
        Model(
          ..model,
          org_settings_users: org_settings_users,
          org_users_cache: org_users_cache,
          org_settings_save_in_flight: False,
          org_settings_error: opt.None,
          org_settings_error_user_id: opt.None,
          toast: opt.Some("Role updated"),
        ),
        effect.none(),
      )
    }

    OrgSettingsSaved(user_id, Error(err)) -> {
      case err.status {
        401 -> #(Model(..model, page: Login, user: opt.None), effect.none())

        403 -> #(
          Model(
            ..model,
            org_settings_save_in_flight: False,
            toast: opt.Some("Not permitted"),
          ),
          effect.none(),
        )

        409 -> #(
          Model(
            ..model,
            org_settings_save_in_flight: False,
            org_settings_error_user_id: opt.Some(user_id),
            org_settings_error: opt.Some(err.message),
          ),
          effect.none(),
        )

        _ -> #(
          Model(
            ..model,
            org_settings_save_in_flight: False,
            org_settings_error_user_id: opt.Some(user_id),
            org_settings_error: opt.Some(err.message),
          ),
          effect.none(),
        )
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
    MemberTaskReleased(Ok(_)) -> {
      let model =
        Model(
          ..model,
          member_task_mutation_in_flight: False,
          toast: opt.Some("Task released"),
        )

      let #(model, fx) = member_refresh(model)
      #(
        model,
        effect.batch([fx, api.get_me_active_task(MemberActiveTaskFetched)]),
      )
    }
    MemberTaskCompleted(Ok(_)) -> {
      let model =
        Model(
          ..model,
          member_task_mutation_in_flight: False,
          toast: opt.Some("Task completed"),
        )

      let #(model, fx) = member_refresh(model)
      #(
        model,
        effect.batch([fx, api.get_me_active_task(MemberActiveTaskFetched)]),
      )
    }

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

    MemberNowWorkingStartClicked(task_id) -> {
      case model.member_now_working_in_flight {
        True -> #(model, effect.none())
        False -> {
          let model =
            Model(
              ..model,
              member_now_working_in_flight: True,
              member_now_working_error: opt.None,
            )
          #(model, api.start_me_active_task(task_id, MemberActiveTaskStarted))
        }
      }
    }

    MemberNowWorkingPauseClicked -> {
      case model.member_now_working_in_flight {
        True -> #(model, effect.none())
        False -> {
          let model =
            Model(
              ..model,
              member_now_working_in_flight: True,
              member_now_working_error: opt.None,
            )
          #(model, api.pause_me_active_task(MemberActiveTaskPaused))
        }
      }
    }

    MemberActiveTaskFetched(Ok(payload)) -> {
      let api.ActiveTaskPayload(as_of: as_of, ..) = payload
      let server_ms = parse_iso_ms_ffi(as_of)
      let offset = now_ms_ffi() - server_ms

      let #(model, tick_fx) =
        Model(
          ..model,
          member_active_task: Loaded(payload),
          now_working_server_offset_ms: offset,
        )
        |> start_now_working_tick_if_needed

      #(model, tick_fx)
    }

    MemberActiveTaskFetched(Error(err)) -> {
      case err.status {
        401 -> #(Model(..model, page: Login, user: opt.None), effect.none())
        _ -> #(Model(..model, member_active_task: Failed(err)), effect.none())
      }
    }

    MemberActiveTaskStarted(Ok(payload)) -> {
      let api.ActiveTaskPayload(as_of: as_of, ..) = payload
      let server_ms = parse_iso_ms_ffi(as_of)
      let offset = now_ms_ffi() - server_ms

      let #(model, tick_fx) =
        Model(
          ..model,
          member_now_working_in_flight: False,
          member_active_task: Loaded(payload),
          now_working_server_offset_ms: offset,
        )
        |> start_now_working_tick_if_needed

      #(model, tick_fx)
    }

    MemberActiveTaskStarted(Error(err)) -> {
      let model = Model(..model, member_now_working_in_flight: False)

      case err.status {
        401 -> #(Model(..model, page: Login, user: opt.None), effect.none())
        _ -> #(
          Model(
            ..model,
            member_now_working_error: opt.Some(err.message),
            toast: opt.Some(err.message),
          ),
          effect.none(),
        )
      }
    }

    MemberActiveTaskPaused(Ok(payload)) -> {
      let api.ActiveTaskPayload(as_of: as_of, ..) = payload
      let server_ms = parse_iso_ms_ffi(as_of)
      let offset = now_ms_ffi() - server_ms

      let model =
        Model(
          ..model,
          member_now_working_in_flight: False,
          member_active_task: Loaded(payload),
          now_working_server_offset_ms: offset,
        )

      // Stop tick loop when active task is cleared.
      let model = case now_working_active_task(model) {
        opt.None -> Model(..model, now_working_tick_running: False)
        opt.Some(_) -> model
      }

      #(model, effect.none())
    }

    MemberActiveTaskPaused(Error(err)) -> {
      let model = Model(..model, member_now_working_in_flight: False)

      case err.status {
        401 -> #(Model(..model, page: Login, user: opt.None), effect.none())
        _ -> #(
          Model(
            ..model,
            member_now_working_error: opt.Some(err.message),
            toast: opt.Some(err.message),
          ),
          effect.none(),
        )
      }
    }

    NowWorkingTicked -> {
      let model = Model(..model, now_working_tick: model.now_working_tick + 1)

      case now_working_active_task(model) {
        opt.Some(_) -> #(model, now_working_tick_effect())

        opt.None -> #(
          Model(..model, now_working_tick_running: False),
          effect.none(),
        )
      }
    }

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
  let is_admin = case model.user {
    opt.Some(user) -> user.org_role == org_role.Admin
    opt.None -> False
  }

  let model =
    Model(
      ..model,
      projects: Loading,
      capabilities: Loading,
      member_my_capability_ids: Loading,
      invite_links: case is_admin {
        True -> Loading
        False -> model.invite_links
      },
    )

  let effects = [
    api.list_projects(ProjectsFetched),
    api.list_capabilities(CapabilitiesFetched),
    api.get_me_capability_ids(MemberMyCapabilityIdsFetched),
  ]

  let effects = case is_admin {
    True -> [api.list_invite_links(InviteLinksFetched), ..effects]
    False -> effects
  }

  #(model, effect.batch(effects))
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

    permissions.OrgSettings -> {
      let model =
        Model(
          ..model,
          org_settings_users: Loading,
          org_settings_role_drafts: dict.new(),
          org_settings_save_in_flight: False,
          org_settings_error: opt.None,
          org_settings_error_user_id: opt.None,
        )

      #(model, api.list_org_users("", OrgSettingsUsersFetched))
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
          let model =
            Model(
              ..model,
              members: Loading,
              members_project_id: opt.Some(project_id),
              org_users_cache: Loading,
            )
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
          let model =
            Model(
              ..model,
              task_types: Loading,
              task_types_project_id: opt.Some(project_id),
            )
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

@external(javascript, "./scrumbringer_client/fetch.ffi.mjs", "is_mobile")
fn is_mobile_ffi() -> Bool {
  False
}

@external(javascript, "./scrumbringer_client/fetch.ffi.mjs", "now_ms")
fn now_ms_ffi() -> Int {
  0
}

@external(javascript, "./scrumbringer_client/fetch.ffi.mjs", "parse_iso_ms")
fn parse_iso_ms_ffi(_iso: String) -> Int {
  0
}

@external(javascript, "./scrumbringer_client/fetch.ffi.mjs", "set_timeout")
fn set_timeout_ffi(_ms: Int, _cb: fn(Nil) -> Nil) -> Int {
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

@external(javascript, "./scrumbringer_client/fetch.ffi.mjs", "location_pathname")
fn location_pathname_ffi() -> String {
  ""
}

@external(javascript, "./scrumbringer_client/fetch.ffi.mjs", "location_hash")
fn location_hash_ffi() -> String {
  ""
}

@external(javascript, "./scrumbringer_client/fetch.ffi.mjs", "location_search")
fn location_search_ffi() -> String {
  ""
}

@external(javascript, "./scrumbringer_client/fetch.ffi.mjs", "input_value")
fn input_value_ffi(_id: String) -> String {
  ""
}

fn copy_to_clipboard(text: String, msg: fn(Bool) -> Msg) -> Effect(Msg) {
  effect.from(fn(dispatch) {
    copy_to_clipboard_ffi(text, fn(ok) { dispatch(msg(ok)) })
  })
}

fn now_working_tick_effect() -> Effect(Msg) {
  effect.from(fn(dispatch) {
    set_timeout_ffi(1000, fn(_) { dispatch(NowWorkingTicked) })
    Nil
  })
}

fn start_now_working_tick_if_needed(model: Model) -> #(Model, Effect(Msg)) {
  case model.now_working_tick_running {
    True -> #(model, effect.none())

    False ->
      case now_working_active_task(model) {
        opt.Some(_) -> #(
          Model(..model, now_working_tick_running: True),
          now_working_tick_effect(),
        )
        opt.None -> #(model, effect.none())
      }
  }
}

fn page_title(section: permissions.AdminSection) -> String {
  case section {
    permissions.Invites -> "Invites"
    permissions.OrgSettings -> "Org Settings"
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

fn now_working_active_task(model: Model) -> opt.Option(api.ActiveTask) {
  case model.member_active_task {
    Loaded(api.ActiveTaskPayload(active_task: active_task, ..)) -> active_task
    _ -> opt.None
  }
}

fn now_working_active_task_id(model: Model) -> opt.Option(Int) {
  case now_working_active_task(model) {
    opt.Some(api.ActiveTask(task_id: task_id, ..)) -> opt.Some(task_id)
    opt.None -> opt.None
  }
}

fn find_task_by_id(
  tasks: Remote(List(api.Task)),
  task_id: Int,
) -> opt.Option(api.Task) {
  case tasks {
    Loaded(tasks) ->
      case
        list.find(tasks, fn(t) {
          let api.Task(id: id, ..) = t
          id == task_id
        })
      {
        Ok(t) -> opt.Some(t)
        Error(_) -> opt.None
      }

    _ -> opt.None
  }
}

fn format_seconds(value: Int) -> String {
  let hours = value / 3600
  let minutes_total = value / 60
  let minutes = minutes_total - minutes_total / 60 * 60
  let seconds = value - minutes_total * 60

  let mm = minutes |> int.to_string |> string.pad_start(2, "0")
  let ss = seconds |> int.to_string |> string.pad_start(2, "0")

  case hours {
    0 -> mm <> ":" <> ss
    _ -> int.to_string(hours) <> ":" <> mm <> ":" <> ss
  }
}

fn now_working_elapsed(model: Model) -> String {
  case now_working_active_task(model) {
    opt.None -> "00:00"

    opt.Some(api.ActiveTask(started_at: started_at, ..)) -> {
      let started_ms = parse_iso_ms_ffi(started_at)
      let local_now_ms = now_ms_ffi()
      let server_now_ms = local_now_ms - model.now_working_server_offset_ms
      let diff_ms = server_now_ms - started_ms

      let seconds = case diff_ms < 0 {
        True -> 0
        False -> diff_ms / 1000
      }

      format_seconds(seconds)
    }
  }
}

fn view(model: Model) -> Element(Msg) {
  div(
    [
      attribute.class("app"),
      attribute.attribute("style", theme.css_vars(model.theme)),
    ],
    [
      style([], styles.base_css()),
      view_toast(model.toast),
      case model.page {
        Login -> view_login(model)
        AcceptInvite -> view_accept_invite(model)
        ResetPassword -> view_reset_password(model)
        Admin -> view_admin(model)
        Member -> view_member(model)
      },
    ],
  )
}

fn view_toast(toast: opt.Option(String)) -> Element(Msg) {
  case toast {
    opt.None -> div([], [])
    opt.Some(message) ->
      div([attribute.class("toast")], [
        span([], [text(message)]),
        button(
          [
            attribute.class("toast-dismiss btn-xs"),
            attribute.attribute("aria-label", "Dismiss"),
            event.on_click(ToastDismissed),
          ],
          [text("×")],
        ),
      ])
  }
}

fn view_accept_invite(model: Model) -> Element(Msg) {
  let accept_invite.Model(
    state: state,
    password: password,
    password_error: password_error,
    submit_error: submit_error,
    ..,
  ) = model.accept_invite

  let content = case state {
    accept_invite.NoToken ->
      div([attribute.class("error")], [text("Missing invite token")])

    accept_invite.Validating ->
      div([attribute.class("loading")], [text("Validating invite…")])

    accept_invite.Invalid(code: _, message: message) ->
      div([attribute.class("error")], [text(message)])

    accept_invite.Ready(email) ->
      view_accept_invite_form(email, password, False, password_error)

    accept_invite.Registering(email) ->
      view_accept_invite_form(email, password, True, password_error)

    accept_invite.Done -> div([attribute.class("loading")], [text("Signed in")])
  }

  div([attribute.class("page")], [
    h1([], [text("ScrumBringer")]),
    h2([], [text("Accept invite")]),
    case submit_error {
      opt.Some(err) ->
        div([attribute.class("error")], [
          span([], [text(err)]),
          button(
            [event.on_click(AcceptInviteMsg(accept_invite.ErrorDismissed))],
            [text("Dismiss")],
          ),
        ])
      opt.None -> div([], [])
    },
    content,
  ])
}

fn view_accept_invite_form(
  email: String,
  password: String,
  in_flight: Bool,
  password_error: opt.Option(String),
) -> Element(Msg) {
  let submit_label = case in_flight {
    True -> "Registering…"
    False -> "Register"
  }

  form([event.on_submit(fn(_) { AcceptInviteMsg(accept_invite.Submitted) })], [
    div([attribute.class("field")], [
      label([], [text("Email")]),
      input([
        attribute.type_("email"),
        attribute.value(email),
        attribute.disabled(True),
      ]),
    ]),
    div([attribute.class("field")], [
      label([], [text("Password")]),
      input([
        attribute.type_("password"),
        attribute.value(password),
        event.on_input(fn(value) {
          AcceptInviteMsg(accept_invite.PasswordChanged(value))
        }),
        attribute.required(True),
      ]),
      case password_error {
        opt.Some(err) -> div([attribute.class("error")], [text(err)])
        opt.None -> div([], [])
      },
      p([], [text("Minimum 12 characters")]),
    ]),
    button([attribute.type_("submit"), attribute.disabled(in_flight)], [
      text(submit_label),
    ]),
  ])
}

fn view_reset_password(model: Model) -> Element(Msg) {
  let reset_password.Model(
    state: state,
    password: password,
    password_error: password_error,
    submit_error: submit_error,
    ..,
  ) = model.reset_password

  let content = case state {
    reset_password.NoToken ->
      div([attribute.class("error")], [text("Missing reset token")])

    reset_password.Validating ->
      div([attribute.class("loading")], [text("Validating reset token…")])

    reset_password.Invalid(code: _, message: message) ->
      div([attribute.class("error")], [text(message)])

    reset_password.Ready(email) ->
      view_reset_password_form(email, password, False, password_error)

    reset_password.Consuming(email) ->
      view_reset_password_form(email, password, True, password_error)

    reset_password.Done ->
      div([attribute.class("loading")], [text("Password updated")])
  }

  div([attribute.class("page")], [
    h1([], [text("ScrumBringer")]),
    h2([], [text("Reset password")]),
    case submit_error {
      opt.Some(err) ->
        div([attribute.class("error")], [
          span([], [text(err)]),
          button(
            [event.on_click(ResetPasswordMsg(reset_password.ErrorDismissed))],
            [text("Dismiss")],
          ),
        ])
      opt.None -> div([], [])
    },
    content,
  ])
}

fn view_reset_password_form(
  email: String,
  password: String,
  in_flight: Bool,
  password_error: opt.Option(String),
) -> Element(Msg) {
  let submit_label = case in_flight {
    True -> "Saving…"
    False -> "Save new password"
  }

  form([event.on_submit(fn(_) { ResetPasswordMsg(reset_password.Submitted) })], [
    div([attribute.class("field")], [
      label([], [text("Email")]),
      input([
        attribute.type_("email"),
        attribute.value(email),
        attribute.disabled(True),
      ]),
    ]),
    div([attribute.class("field")], [
      label([], [text("New password")]),
      input([
        attribute.type_("password"),
        attribute.value(password),
        event.on_input(fn(value) {
          ResetPasswordMsg(reset_password.PasswordChanged(value))
        }),
        attribute.required(True),
      ]),
      case password_error {
        opt.Some(err) -> div([attribute.class("error")], [text(err)])
        opt.None -> div([], [])
      },
      p([], [text("Minimum 12 characters")]),
    ]),
    button([attribute.type_("submit"), attribute.disabled(in_flight)], [
      text(submit_label),
    ]),
  ])
}

fn view_forgot_password(model: Model) -> Element(Msg) {
  let submit_label = case model.forgot_password_in_flight {
    True -> "Working..."
    False -> "Generate reset link"
  }

  let origin = location_origin_ffi()

  let link = case model.forgot_password_result {
    opt.Some(reset) -> origin <> reset.url_path
    opt.None -> ""
  }

  div([attribute.class("section")], [
    p([], [
      text(
        "No email integration in MVP. This generates a reset link you can copy/paste.",
      ),
    ]),
    case model.forgot_password_error {
      opt.Some(err) ->
        div([attribute.class("error")], [
          span([], [text(err)]),
          button([event.on_click(ForgotPasswordDismissed)], [text("Dismiss")]),
        ])
      opt.None -> div([], [])
    },
    form([event.on_submit(fn(_) { ForgotPasswordSubmitted })], [
      div([attribute.class("field")], [
        label([], [text("Email")]),
        input([
          attribute.type_("email"),
          attribute.value(model.forgot_password_email),
          event.on_input(ForgotPasswordEmailChanged),
          attribute.required(True),
        ]),
      ]),
      button(
        [
          attribute.type_("submit"),
          attribute.disabled(model.forgot_password_in_flight),
        ],
        [text(submit_label)],
      ),
    ]),
    case link == "" {
      True -> div([], [])

      False ->
        div([attribute.class("field")], [
          label([], [text("Reset link")]),
          div([attribute.class("copy")], [
            input([
              attribute.type_("text"),
              attribute.value(link),
              attribute.readonly(True),
            ]),
            button([event.on_click(ForgotPasswordCopyClicked)], [text("Copy")]),
          ]),
          case model.forgot_password_copy_status {
            opt.Some(msg) -> div([attribute.class("hint")], [text(msg)])
            opt.None -> div([], [])
          },
        ])
    },
  ])
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
          attribute.attribute("id", "login-email"),
          attribute.type_("email"),
          attribute.value(model.login_email),
          event.on_input(LoginEmailChanged),
          attribute.required(True),
        ]),
      ]),
      div([attribute.class("field")], [
        label([], [text("Password")]),
        input([
          attribute.attribute("id", "login-password"),
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
    button([event.on_click(ForgotPasswordClicked)], [text("Forgot password?")]),
    case model.forgot_password_open {
      True -> view_forgot_password(model)
      False -> div([], [])
    },
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

fn view_theme_switch(model: Model) -> Element(Msg) {
  let current = theme.serialize(model.theme)

  label([attribute.class("theme-switch")], [
    text("Theme"),
    select([attribute.value(current), event.on_input(ThemeSelected)], [
      option([attribute.value("default")], "Default"),
      option([attribute.value("dark")], "Dark"),
    ]),
  ])
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
      view_theme_switch(model),
      span([attribute.class("user")], [text(user.email)]),
      button(
        [
          event.on_click(NavigateTo(
            router.Member(model.member_section, model.selected_project_id),
            Push,
          )),
        ],
        [text("App")],
      ),
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
                event.on_click(NavigateTo(
                  router.Admin(section, model.selected_project_id),
                  Push,
                )),
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
        permissions.OrgSettings -> view_org_settings(model)
        permissions.Projects -> view_projects(model)
        permissions.Capabilities -> view_capabilities(model)
        permissions.Members -> view_members(model, selected)
        permissions.TaskTypes -> view_task_types(model, selected)
      }
  }
}

fn view_org_settings(model: Model) -> Element(Msg) {
  div([attribute.class("section")], [
    p([], [
      text(
        "Manage org roles (admin/member). Changes require an explicit Save and are protected by a last-admin guardrail.",
      ),
    ]),
    case model.org_settings_users {
      NotAsked -> div([], [text("Open this section to load users.")])
      Loading -> div([attribute.class("loading")], [text("Loading users…")])

      Failed(err) -> div([attribute.class("error")], [text(err.message)])

      Loaded(users) -> {
        table([attribute.class("table")], [
          thead([], [
            tr([], [
              th([], [text("Email")]),
              th([], [text("Role")]),
              th([], [text("Actions")]),
            ]),
          ]),
          tbody(
            [],
            list.map(users, fn(u) {
              let draft = case dict.get(model.org_settings_role_drafts, u.id) {
                Ok(role) -> role
                Error(_) -> u.org_role
              }

              let inline_error = case
                model.org_settings_error_user_id,
                model.org_settings_error
              {
                opt.Some(id), opt.Some(message) if id == u.id -> message
                _, _ -> ""
              }

              tr([], [
                td([], [text(u.email)]),
                td([], [
                  select(
                    [
                      attribute.value(draft),
                      attribute.disabled(model.org_settings_save_in_flight),
                      event.on_input(fn(value) {
                        OrgSettingsRoleChanged(u.id, value)
                      }),
                    ],
                    [
                      option([attribute.value("admin")], "admin"),
                      option([attribute.value("member")], "member"),
                    ],
                  ),
                  case inline_error == "" {
                    True -> div([], [])
                    False ->
                      div([attribute.class("error")], [text(inline_error)])
                  },
                ]),
                td([], [
                  button(
                    [
                      attribute.disabled(model.org_settings_save_in_flight),
                      event.on_click(OrgSettingsSaveClicked(u.id)),
                    ],
                    [text("Save")],
                  ),
                ]),
              ])
            }),
          ),
        ])
      }
    },
  ])
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
      case model.is_mobile {
        True ->
          div([attribute.class("member")], [
            view_member_topbar(model, user),
            view_now_working_panel(model, user),
            div([attribute.class("content")], [view_member_section(model, user)]),
          ])

        False ->
          div([attribute.class("member")], [
            view_member_topbar(model, user),
            view_now_working_panel(model, user),
            div([attribute.class("body")], [
              view_member_nav(model),
              div([attribute.class("content")], [
                view_member_section(model, user),
              ]),
            ]),
          ])
      }
  }
}

fn view_member_topbar(model: Model, user: User) -> Element(Msg) {
  div([attribute.class("topbar")], [
    div([attribute.class("topbar-title")], [
      text(case model.member_section {
        member_section.Pool -> "Pool"
        member_section.MyBar -> "My Bar"
        member_section.MySkills -> "My Skills"
      }),
    ]),
    view_project_selector(model),
    div([attribute.class("topbar-actions")], [
      case user.org_role {
        org_role.Admin ->
          button(
            [
              event.on_click(NavigateTo(
                router.Admin(permissions.Invites, model.selected_project_id),
                Push,
              )),
            ],
            [text("Admin")],
          )
        _ -> div([], [])
      },
      view_theme_switch(model),
      span([attribute.class("user")], [text(user.email)]),
      button([event.on_click(LogoutClicked)], [text("Logout")]),
    ]),
  ])
}

fn view_now_working_panel(model: Model, _user: User) -> Element(Msg) {
  let error = case model.member_now_working_error {
    opt.Some(err) -> div([attribute.class("now-working-error")], [text(err)])
    opt.None -> div([], [])
  }

  case model.member_active_task {
    Loading ->
      div([attribute.class("now-working")], [text("Now Working: loading...")])

    Failed(err) ->
      div([attribute.class("now-working")], [
        div([attribute.class("now-working-error")], [
          text("Now Working error: " <> err.message),
        ]),
      ])

    NotAsked | Loaded(_) -> {
      let active = now_working_active_task(model)

      case active {
        opt.None ->
          div([attribute.class("now-working")], [
            div([attribute.class("now-working-empty")], [
              text("Now Working: none"),
            ]),
            error,
          ])

        opt.Some(api.ActiveTask(task_id: task_id, ..)) -> {
          let title = case find_task_by_id(model.member_tasks, task_id) {
            opt.Some(api.Task(title: title, ..)) -> title
            opt.None -> "Task #" <> int.to_string(task_id)
          }

          let disable_actions =
            model.member_task_mutation_in_flight
            || model.member_now_working_in_flight

          let pause_action =
            button(
              [
                attribute.class("btn-xs"),
                attribute.disabled(disable_actions),
                event.on_click(MemberNowWorkingPauseClicked),
              ],
              [text("Pause")],
            )

          let task_actions = case find_task_by_id(model.member_tasks, task_id) {
            opt.Some(api.Task(version: version, ..)) -> [
              button(
                [
                  attribute.class("btn-xs"),
                  attribute.disabled(disable_actions),
                  event.on_click(MemberCompleteClicked(task_id, version)),
                ],
                [text("Complete")],
              ),
              button(
                [
                  attribute.class("btn-xs"),
                  attribute.disabled(disable_actions),
                  event.on_click(MemberReleaseClicked(task_id, version)),
                ],
                [text("Release")],
              ),
            ]

            opt.None -> []
          }

          div([attribute.class("now-working")], [
            div([], [
              div([attribute.class("now-working-title")], [text(title)]),
              div([attribute.class("now-working-timer")], [
                text(now_working_elapsed(model)),
              ]),
            ]),
            div([attribute.class("now-working-actions")], [
              pause_action,
              ..task_actions
            ]),
            error,
          ])
        }
      }
    }
  }
}

fn view_member_nav(model: Model) -> Element(Msg) {
  let items = case model.is_mobile {
    True -> [
      view_member_nav_button(model, member_section.MyBar, "My Bar"),
      view_member_nav_button(model, member_section.MySkills, "My Skills"),
    ]

    False -> [
      view_member_nav_button(model, member_section.Pool, "Pool"),
      view_member_nav_button(model, member_section.MyBar, "My Bar"),
      view_member_nav_button(model, member_section.MySkills, "My Skills"),
    ]
  }

  div([attribute.class("nav")], [
    h3([], [text("App")]),
    div([], items),
  ])
}

fn view_member_nav_button(
  model: Model,
  section: member_section.MemberSection,
  label: String,
) -> Element(Msg) {
  let classes = case section == model.member_section {
    True -> "nav-item active"
    False -> "nav-item"
  }

  button(
    [
      attribute.class(classes),
      event.on_click(NavigateTo(
        router.Member(section, model.selected_project_id),
        Push,
      )),
    ],
    [text(label)],
  )
}

fn view_member_section(model: Model, user: User) -> Element(Msg) {
  case model.member_section {
    member_section.Pool -> view_member_pool(model)
    member_section.MyBar -> view_member_bar(model, user)
    member_section.MySkills -> view_member_skills(model)
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
          text("Tip: use the ⠿ handle on a card to drag it."),
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

        _ -> {
          let visible_tasks =
            tasks
            |> list.filter(fn(t) {
              let api.Task(status: status, ..) = t
              status == "available"
            })

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
            list.map(visible_tasks, fn(task) {
              view_member_task_card(model, task)
            }),
          )
        }
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

  let card_classes = case highlight {
    True -> "task-card highlight"
    False -> "task-card"
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
    <> "px; padding:40px 8px 8px 8px; overflow:hidden; opacity:"
    <> float.to_string(opacity)
    <> "; filter:saturate("
    <> float.to_string(saturation)
    <> ");"

  let disable_actions = model.member_task_mutation_in_flight

  // Make the primary action visible even on tiny cards (the card size is
  // priority-driven and content is overflow-hidden).
  let primary_action = case status, is_mine {
    "available", _ ->
      button(
        [
          attribute.class("btn-xs btn-icon"),
          attribute.attribute("title", "Claim task"),
          attribute.attribute("aria-label", "Claim task"),
          event.on_click(MemberClaimClicked(id, version)),
          attribute.disabled(disable_actions),
        ],
        [text("C")],
      )

    "claimed", True ->
      button(
        [
          attribute.class("btn-xs btn-icon"),
          attribute.attribute("title", "Release task"),
          attribute.attribute("aria-label", "Release task"),
          event.on_click(MemberReleaseClicked(id, version)),
          attribute.disabled(disable_actions),
        ],
        [text("R")],
      )

    _, _ -> div([], [])
  }

  let drag_handle =
    div(
      [
        attribute.class("drag-handle"),
        attribute.attribute("title", "Drag to move"),
        attribute.attribute("aria-label", "Drag to move"),
        event.on("mousedown", {
          use ox <- decode.field("offsetX", decode.int)
          use oy <- decode.field("offsetY", decode.int)
          decode.success(MemberDragStarted(id, ox, oy))
        }),
      ],
      [text("⠿")],
    )

  let complete_action = case status, is_mine {
    "claimed", True ->
      button(
        [
          attribute.class("btn-xs btn-icon"),
          attribute.attribute("title", "Complete task"),
          attribute.attribute("aria-label", "Complete task"),
          event.on_click(MemberCompleteClicked(id, version)),
          attribute.disabled(disable_actions),
        ],
        [text("✓")],
      )

    _, _ -> div([], [])
  }

  div([attribute.class(card_classes), attribute.attribute("style", style)], [
    div(
      [
        attribute.attribute(
          "style",
          "position:absolute; top:8px; left:8px; right:8px; display:flex; justify-content:space-between; gap:6px;",
        ),
      ],
      [
        div(
          [
            attribute.attribute(
              "style",
              "min-width:0; overflow:hidden; white-space:nowrap; text-overflow:ellipsis;",
            ),
          ],
          [
            h3([attribute.attribute("style", "margin:0; font-size:14px;")], [
              text(title),
            ]),
          ],
        ),
        div(
          [
            attribute.attribute(
              "style",
              "display:flex; gap:6px; align-items:center; flex-shrink:0;",
            ),
          ],
          [primary_action, complete_action, drag_handle],
        ),
      ],
    ),
    p([], [text("type: " <> type_label)]),
    p([], [text("age: " <> int.to_string(age_days) <> "d")]),
    p([], [text("status: " <> status)]),
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

fn member_bar_status_rank(status: String) -> Int {
  case status {
    "claimed" -> 0
    "available" -> 1
    "completed" -> 2
    _ -> 3
  }
}

fn compare_member_bar_tasks(a: api.Task, b: api.Task) -> order.Order {
  let api.Task(
    priority: priority_a,
    status: status_a,
    created_at: created_at_a,
    ..,
  ) = a
  let api.Task(
    priority: priority_b,
    status: status_b,
    created_at: created_at_b,
    ..,
  ) = b

  case int.compare(priority_b, priority_a) {
    order.Eq ->
      case
        int.compare(
          member_bar_status_rank(status_a),
          member_bar_status_rank(status_b),
        )
      {
        order.Eq -> string.compare(created_at_b, created_at_a)
        other -> other
      }

    other -> other
  }
}

fn view_member_bar(model: Model, user: User) -> Element(Msg) {
  case active_projects(model) {
    [] ->
      div([attribute.class("empty")], [
        text("You are not in any project yet. Ask an admin to add you."),
      ])

    _ ->
      case model.member_tasks {
        NotAsked | Loading ->
          div([attribute.class("empty")], [text("Loading...")])

        Failed(err) -> div([attribute.class("error")], [text(err.message)])

        Loaded(tasks) -> {
          let mine =
            tasks
            |> list.filter(fn(t) {
              let api.Task(claimed_by: claimed_by, ..) = t
              claimed_by == opt.Some(user.id)
            })
            |> list.sort(by: compare_member_bar_tasks)

          div([attribute.class("section")], [
            case mine {
              [] ->
                div([attribute.class("empty")], [text("No claimed tasks yet")])

              _ ->
                div(
                  [attribute.class("task-list")],
                  list.map(mine, fn(t) {
                    view_member_bar_task_row(model, user, t)
                  }),
                )
            },
          ])
        }
      }
  }
}

fn view_member_bar_task_row(
  model: Model,
  user: User,
  task: api.Task,
) -> Element(Msg) {
  let api.Task(
    id: id,
    type_id: type_id,
    title: title,
    priority: priority,
    status: status,
    created_at: created_at,
    version: version,
    claimed_by: claimed_by,
    ..,
  ) = task

  let is_mine = claimed_by == opt.Some(user.id)

  let task_type = member_task_type_by_id(model.member_task_types, type_id)

  let type_label = case task_type {
    opt.Some(tt) -> tt.name <> " (" <> tt.icon <> ")"
    opt.None -> "Type #" <> int.to_string(type_id)
  }

  let disable_actions =
    model.member_task_mutation_in_flight || model.member_now_working_in_flight

  let claim_action =
    button(
      [
        attribute.class("btn-xs btn-icon"),
        attribute.attribute("title", "Claim task"),
        attribute.attribute("aria-label", "Claim task"),
        event.on_click(MemberClaimClicked(id, version)),
        attribute.disabled(disable_actions),
      ],
      [text("C")],
    )

  let release_action =
    button(
      [
        attribute.class("btn-xs btn-icon"),
        attribute.attribute("title", "Release task"),
        attribute.attribute("aria-label", "Release task"),
        event.on_click(MemberReleaseClicked(id, version)),
        attribute.disabled(disable_actions),
      ],
      [text("R")],
    )

  let complete_action =
    button(
      [
        attribute.class("btn-xs btn-icon"),
        attribute.attribute("title", "Complete task"),
        attribute.attribute("aria-label", "Complete task"),
        event.on_click(MemberCompleteClicked(id, version)),
        attribute.disabled(disable_actions),
      ],
      [text("✓")],
    )

  let start_action =
    button(
      [
        attribute.class("btn-xs"),
        attribute.attribute("title", "Start now working"),
        attribute.attribute("aria-label", "Start now working"),
        event.on_click(MemberNowWorkingStartClicked(id)),
        attribute.disabled(disable_actions),
      ],
      [text("Start")],
    )

  let pause_action =
    button(
      [
        attribute.class("btn-xs"),
        attribute.attribute("title", "Pause now working"),
        attribute.attribute("aria-label", "Pause now working"),
        event.on_click(MemberNowWorkingPauseClicked),
        attribute.disabled(disable_actions),
      ],
      [text("Pause")],
    )

  let is_active = now_working_active_task_id(model) == opt.Some(id)

  let now_working_action = case is_active {
    True -> pause_action
    False -> start_action
  }

  let actions = case status, is_mine {
    "available", _ -> [claim_action]
    "claimed", True -> [now_working_action, release_action, complete_action]
    _, _ -> []
  }

  div([attribute.class("task-row")], [
    div([], [
      div([attribute.class("task-row-title")], [text(title)]),
      div([attribute.class("task-row-meta")], [
        text(
          "priority: "
          <> int.to_string(priority)
          <> " · status: "
          <> status
          <> " · type: "
          <> type_label
          <> " · created: "
          <> created_at,
        ),
      ]),
    ]),
    div([attribute.class("task-row-actions")], actions),
  ])
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
        [attribute.class("skills-list")],
        list.map(capabilities, fn(c) {
          let selected = case
            dict.get(model.member_my_capability_ids_edit, c.id)
          {
            Ok(v) -> v
            Error(_) -> False
          }

          div([attribute.class("skill-row")], [
            span([attribute.class("skill-name")], [text(c.name)]),
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
    member_section.MySkills -> #(model, effect.none())

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
            member_section.MyBar ->
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

pub fn should_pause_active_task_on_project_change(
  is_member_page: Bool,
  previous_project_id: opt.Option(Int),
  next_project_id: opt.Option(Int),
) -> Bool {
  case is_member_page {
    False -> False
    True -> previous_project_id != next_project_id
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
