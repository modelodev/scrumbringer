//// Main client module for Scrumbringer web application.
////
//// ## Mission
////
//// Entry point and orchestrator for the Lustre-based SPA client. Wires together
//// initialization, routing, state management, and view rendering.
////
//// ## Responsibilities
////
//// - Application bootstrap (`main`, `init`)
//// - Lustre update cycle (`update`)
//// - View rendering and routing (`view`)
//// - Effect management (API calls, navigation, timers)
//// - Message dispatch and state transitions
////
//// ## Non-responsibilities
////
//// - Type definitions (see `client_state.gleam`)
//// - API request/response handling (see `api.gleam`)
//// - JavaScript FFI (see `client_ffi.gleam`)
//// - Routing logic and URL parsing (see `router.gleam`)
//// - Internationalization (see `i18n/` modules)
//// - Theme and styling (see `theme.gleam`, `styles.gleam`)
////
//// ## Architecture
////
//// Follows the Lustre/Elm architecture pattern:
//// - **Model**: Application state (defined in `client_state.gleam`)
//// - **Msg**: Messages that trigger state changes (defined in `client_state.gleam`)
//// - **Update**: Pure function `(Model, Msg) -> #(Model, Effect(Msg))`
//// - **View**: Pure function `Model -> Element(Msg)`
////
//// ## Module Structure (planned refactor)
////
//// This module is currently monolithic. Future refactoring will extract:
//// - `client_update.gleam`: update function and helpers
//// - `client_view.gleam`: view function and subviews
////
//// ## Relations
////
//// - **client_state.gleam**: Provides Model, Msg, and state types
//// - **api.gleam**: Provides API effects for data fetching
//// - **client_ffi.gleam**: Provides browser FFI (history, DOM, timers)
//// - **router.gleam**: Provides URL parsing and route types
//// - **theme.gleam**: Provides theme management
//// - **styles.gleam**: Provides CSS generation

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
import scrumbringer_client/client_ffi
import scrumbringer_client/hydration
import scrumbringer_client/member_section
import scrumbringer_client/member_visuals
import scrumbringer_client/permissions
import scrumbringer_client/pool_prefs
import scrumbringer_client/reset_password
import scrumbringer_client/router
import scrumbringer_client/styles
import scrumbringer_client/theme
import scrumbringer_client/update_helpers

import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale as i18n_locale
import scrumbringer_client/i18n/text as i18n_text

import scrumbringer_client/client_state.{
  // Types (used in type annotations)
  type Model, type Msg, type NavMode, type Remote,
  // Type constructors
  Model, MemberDrag, Rect,
  // Remote constructors
  NotAsked, Loading, Loaded, Failed,
  // Page constructors
  Login, AcceptInvite as AcceptInvitePage, ResetPassword as ResetPasswordPage, Admin, Member,
  // IconPreview constructors
  IconIdle, IconLoading, IconOk, IconError,
  // NavMode constructors
  Push, Replace,
  // Msg constructors - Navigation
  MemberPoolMyTasksRectFetched, MemberPoolDragToClaimArmed, UrlChanged, NavigateTo,
  // Msg constructors - Auth
  MeFetched, AcceptInviteMsg, ResetPasswordMsg,
  // Msg constructors - Login
  LoginEmailChanged, LoginPasswordChanged, LoginSubmitted, LoginDomValuesRead, LoginFinished,
  // Msg constructors - Forgot password
  ForgotPasswordClicked, ForgotPasswordEmailChanged, ForgotPasswordSubmitted,
  ForgotPasswordFinished, ForgotPasswordCopyClicked, ForgotPasswordCopyFinished, ForgotPasswordDismissed,
  // Msg constructors - Logout
  LogoutClicked, LogoutFinished,
  // Msg constructors - UI
  ToastDismissed, ThemeSelected, LocaleSelected, ProjectSelected,
  // Msg constructors - Projects
  ProjectsFetched, ProjectCreateNameChanged, ProjectCreateSubmitted, ProjectCreated,
  // Msg constructors - Invite links
  InviteLinkEmailChanged, InviteLinkCreateSubmitted, InviteLinkCreated, InviteLinksFetched,
  InviteLinkRegenerateClicked, InviteLinkRegenerated, InviteLinkCopyClicked, InviteLinkCopyFinished,
  // Msg constructors - Capabilities
  CapabilitiesFetched, CapabilityCreateNameChanged, CapabilityCreateSubmitted, CapabilityCreated,
  // Msg constructors - Members
  MembersFetched, OrgUsersCacheFetched, OrgSettingsUsersFetched, OrgSettingsRoleChanged,
  OrgSettingsSaveClicked, OrgSettingsSaved, MemberAddDialogOpened, MemberAddDialogClosed,
  MemberAddRoleChanged, MemberAddUserSelected, MemberAddSubmitted, MemberAdded,
  MemberRemoveClicked, MemberRemoveCancelled, MemberRemoveConfirmed, MemberRemoved,
  // Msg constructors - Org users search
  OrgUsersSearchChanged, OrgUsersSearchDebounced, OrgUsersSearchResults,
  // Msg constructors - Task types
  TaskTypesFetched, TaskTypeCreateNameChanged, TaskTypeCreateIconChanged, TaskTypeIconLoaded,
  TaskTypeIconErrored, TaskTypeCreateCapabilityChanged, TaskTypeCreateSubmitted, TaskTypeCreated,
  // Msg constructors - Pool filters
  MemberPoolStatusChanged, MemberPoolTypeChanged, MemberPoolCapabilityChanged,
  MemberPoolSearchChanged, MemberPoolSearchDebounced, MemberToggleMyCapabilitiesQuick,
  MemberPoolFiltersToggled, MemberPoolViewModeSet, GlobalKeyDown,
  // Msg constructors - Member tasks
  MemberProjectTasksFetched, MemberTaskTypesFetched,
  // Msg constructors - Drag and drop
  MemberCanvasRectFetched, MemberDragStarted, MemberDragMoved, MemberDragEnded,
  // Msg constructors - Task creation
  MemberCreateDialogOpened, MemberCreateDialogClosed, MemberCreateTitleChanged,
  MemberCreateDescriptionChanged, MemberCreatePriorityChanged, MemberCreateTypeIdChanged,
  MemberCreateSubmitted, MemberTaskCreated,
  // Msg constructors - Task actions
  MemberClaimClicked, MemberReleaseClicked, MemberCompleteClicked,
  MemberTaskClaimed, MemberTaskReleased, MemberTaskCompleted,
  // Msg constructors - Now working
  MemberNowWorkingStartClicked, MemberNowWorkingPauseClicked, MemberActiveTaskFetched,
  MemberActiveTaskStarted, MemberActiveTaskPaused, MemberActiveTaskHeartbeated,
  MemberMetricsFetched, AdminMetricsOverviewFetched, AdminMetricsProjectTasksFetched, NowWorkingTicked,
  // Msg constructors - Member capabilities
  MemberMyCapabilityIdsFetched, MemberToggleCapability, MemberSaveCapabilitiesClicked, MemberMyCapabilityIdsSaved,
  // Msg constructors - Position editing
  MemberPositionsFetched, MemberPositionEditOpened, MemberPositionEditClosed,
  MemberPositionEditXChanged, MemberPositionEditYChanged, MemberPositionEditSubmitted, MemberPositionSaved,
  // Msg constructors - Task details
  MemberTaskDetailsOpened, MemberTaskDetailsClosed, MemberNotesFetched,
  MemberNoteContentChanged, MemberNoteSubmitted, MemberNoteAdded,
  // Helper functions
  rect_contains_point,
}

pub fn app() -> lustre.App(Nil, Model, Msg) {
  lustre.application(init, update, view)
}

pub fn main() {
  case lustre.start(app(), "#app", Nil) {
    Ok(_) -> Nil
    Error(_) -> Nil
  }
}

fn init(_flags: Nil) -> #(Model, Effect(Msg)) {
  let pathname = client_ffi.location_pathname()
  let search = client_ffi.location_search()
  let hash = client_ffi.location_hash()
  let is_mobile = client_ffi.is_mobile()

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
    router.AcceptInvite(_) -> AcceptInvitePage
    router.ResetPassword(_) -> ResetPasswordPage
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
  let active_locale = i18n_locale.load()

  let pool_filters_default_visible = theme.filters_default_visible(active_theme)

  let pool_filters_visible =
    theme.local_storage_get(pool_prefs.filters_visible_storage_key)
    |> pool_prefs.deserialize_bool(pool_filters_default_visible)

  let pool_view_mode =
    theme.local_storage_get(pool_prefs.view_mode_storage_key)
    |> pool_prefs.deserialize_view_mode

  let model =
    Model(
      page: page,
      user: opt.None,
      auth_checked: False,
      is_mobile: is_mobile,
      active_section: active_section,
      toast: opt.None,
      theme: active_theme,
      locale: active_locale,
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
      admin_metrics_overview: NotAsked,
      admin_metrics_project_tasks: NotAsked,
      admin_metrics_project_id: opt.None,
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
      member_metrics: NotAsked,
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
      // UX: default to My Capabilities enabled.
      member_quick_my_caps: True,
      member_pool_filters_visible: pool_filters_visible,
      member_pool_view_mode: pool_view_mode,
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
      member_pool_my_tasks_rect: opt.None,
      member_pool_drag_to_claim_armed: False,
      member_pool_drag_over_my_tasks: False,
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
    AcceptInvitePage -> accept_invite_effect(accept_action)
    ResetPasswordPage -> reset_password_effect(reset_action)
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
      register_keydown_effect(),
      redirect_fx,
      base_effect,
      tick_fx,
    ]),
  )
}

fn current_route(model: Model) -> router.Route {
  case model.page {
    Login -> router.Login

    AcceptInvitePage -> {
      let accept_invite.Model(token: token, ..) = model.accept_invite
      router.AcceptInvite(token)
    }

    ResetPasswordPage -> {
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

fn replace_url(model: Model) -> Effect(Msg) {
  let path = url_for_model(model)
  effect.from(fn(_dispatch) { client_ffi.history_replace_state(path) })
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

fn register_popstate_effect() -> Effect(Msg) {
  effect.from(fn(dispatch) {
    client_ffi.register_popstate(fn(_) { dispatch(UrlChanged) })
  })
}

fn register_keydown_effect() -> Effect(Msg) {
  effect.from(fn(dispatch) {
    client_ffi.register_keydown(fn(payload) {
      let #(key, ctrl, meta, shift, is_editing, modal_open) = payload
      dispatch(
        GlobalKeyDown(pool_prefs.KeyEvent(
          key,
          ctrl,
          meta,
          shift,
          is_editing,
          modal_open,
        )),
      )
    })
  })
}

fn focus_element_effect(id: String) -> Effect(Msg) {
  effect.from(fn(_dispatch) {
    // Ensure we attempt focus after the DOM update.
    client_ffi.set_timeout(0, fn(_) {
      client_ffi.focus_element(id)
      Nil
    })
    Nil
  })
}

fn save_pool_filters_visible_effect(visible: Bool) -> Effect(Msg) {
  effect.from(fn(_dispatch) {
    theme.local_storage_set(
      pool_prefs.filters_visible_storage_key,
      pool_prefs.serialize_bool(visible),
    )
  })
}

fn save_pool_view_mode_effect(mode: pool_prefs.ViewMode) -> Effect(Msg) {
  effect.from(fn(_dispatch) {
    theme.local_storage_set(
      pool_prefs.view_mode_storage_key,
      pool_prefs.serialize_view_mode(mode),
    )
  })
}

fn handle_pool_keydown(
  model: Model,
  event: pool_prefs.KeyEvent,
) -> #(Model, Effect(Msg)) {
  case model.page == Member && model.member_section == member_section.Pool {
    False -> #(model, effect.none())
    True -> {
      case pool_prefs.shortcut_action(event) {
        pool_prefs.NoAction -> #(model, effect.none())

        pool_prefs.ToggleFilters -> {
          let next = !model.member_pool_filters_visible
          #(
            Model(..model, member_pool_filters_visible: next),
            save_pool_filters_visible_effect(next),
          )
        }

        pool_prefs.FocusSearch -> {
          let should_show = !model.member_pool_filters_visible

          let model = Model(..model, member_pool_filters_visible: True)

          let show_fx = case should_show {
            True -> save_pool_filters_visible_effect(True)
            False -> effect.none()
          }

          #(
            model,
            effect.batch([
              show_fx,
              focus_element_effect("pool-filter-q"),
            ]),
          )
        }

        pool_prefs.OpenCreate -> {
          case model.member_create_dialog_open {
            True -> #(model, effect.none())
            False -> #(
              Model(..model, member_create_dialog_open: True),
              effect.none(),
            )
          }
        }
      }
    }
  }
}

fn read_login_values_effect() -> Effect(Msg) {
  effect.from(fn(dispatch) {
    let email = client_ffi.input_value("login-email")
    let password = client_ffi.input_value("login-password")
    dispatch(LoginDomValuesRead(email, password))
    Nil
  })
}

fn write_url(mode: NavMode, route: router.Route) -> Effect(Msg) {
  let url = router.format(route)

  effect.from(fn(_dispatch) {
    case mode {
      Push -> client_ffi.history_push_state(url)
      Replace -> client_ffi.history_replace_state(url)
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
        Model(
          ..model,
          page: Login,
          selected_project_id: opt.None,
          member_drag: opt.None,
          member_pool_drag_to_claim_armed: False,
          member_pool_drag_over_my_tasks: False,
        ),
        effect.none(),
      )
    }

    router.AcceptInvite(token) -> {
      let #(new_accept_model, action) = accept_invite.init(token)
      let model =
        Model(
          ..model,
          page: AcceptInvitePage,
          accept_invite: new_accept_model,
          selected_project_id: opt.None,
          member_drag: opt.None,
          member_pool_drag_to_claim_armed: False,
          member_pool_drag_over_my_tasks: False,
        )

      #(model, accept_invite_effect(action))
    }

    router.ResetPassword(token) -> {
      let #(new_reset_model, action) = reset_password.init(token)
      let model =
        Model(
          ..model,
          page: ResetPasswordPage,
          reset_password: new_reset_model,
          selected_project_id: opt.None,
          member_drag: opt.None,
          member_pool_drag_to_claim_armed: False,
          member_pool_drag_over_my_tasks: False,
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
          member_drag: opt.None,
          member_pool_drag_to_claim_armed: False,
          member_pool_drag_over_my_tasks: False,
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
          member_drag: opt.None,
          member_pool_drag_to_claim_armed: False,
          member_pool_drag_over_my_tasks: False,
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
    me_metrics: remote_state(model.member_metrics),
    org_metrics_overview: remote_state(model.admin_metrics_overview),
    org_metrics_project_tasks: remote_state(model.admin_metrics_project_tasks),
    org_metrics_project_id: model.admin_metrics_project_id,
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

            hydration.FetchMeMetrics -> {
              case m.member_metrics {
                Loading | Loaded(_) -> #(m, fx)

                _ -> {
                  let m = Model(..m, member_metrics: Loading)
                  #(m, [api.get_me_metrics(30, MemberMetricsFetched), ..fx])
                }
              }
            }

            hydration.FetchOrgMetricsOverview -> {
              case m.admin_metrics_overview {
                Loading | Loaded(_) -> #(m, fx)

                _ -> {
                  let m = Model(..m, admin_metrics_overview: Loading)
                  #(m, [
                    api.get_org_metrics_overview(
                      30,
                      AdminMetricsOverviewFetched,
                    ),
                    ..fx
                  ])
                }
              }
            }

            hydration.FetchOrgMetricsProjectTasks(project_id: project_id) -> {
              let can_fetch = case m.projects {
                Loaded(projects) ->
                  list.any(projects, fn(p) { p.id == project_id })
                _ -> False
              }

              case can_fetch {
                False -> #(m, fx)

                True ->
                  case
                    m.admin_metrics_project_tasks,
                    m.admin_metrics_project_id
                  {
                    Loading, _ -> #(m, fx)
                    Loaded(_), opt.Some(pid) if pid == project_id -> #(m, fx)

                    _, _ -> {
                      let m =
                        Model(
                          ..m,
                          admin_metrics_project_tasks: Loading,
                          admin_metrics_project_id: opt.Some(project_id),
                        )

                      let fx_tasks =
                        api.get_org_metrics_project_tasks(
                          project_id,
                          30,
                          AdminMetricsProjectTasksFetched,
                        )

                      #(m, [fx_tasks, ..fx])
                    }
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
  let pathname = client_ffi.location_pathname()
  let search = client_ffi.location_search()
  let hash = client_ffi.location_hash()
  let is_mobile = client_ffi.is_mobile()

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

    MemberPoolMyTasksRectFetched(left, top, width, height) -> #(
      Model(
        ..model,
        member_pool_my_tasks_rect: opt.Some(Rect(
          left: left,
          top: top,
          width: width,
          height: height,
        )),
      ),
      effect.none(),
    )

    MemberPoolDragToClaimArmed(armed) -> #(
      Model(
        ..model,
        member_pool_drag_to_claim_armed: armed,
        member_pool_drag_over_my_tasks: False,
      ),
      effect.none(),
    )

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
              toast: opt.Some(update_helpers.i18n_t(model, i18n_text.Welcome)),
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
              toast: opt.Some(update_helpers.i18n_t(model, i18n_text.PasswordUpdated)),
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
            login_error: opt.Some(update_helpers.i18n_t(
              model,
              i18n_text.EmailAndPasswordRequired,
            )),
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
          toast: opt.Some(update_helpers.i18n_t(model, i18n_text.LoggedIn)),
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
        401 | 403 -> update_helpers.i18n_t(model, i18n_text.InvalidCredentials)
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
                forgot_password_error: opt.Some(update_helpers.i18n_t(
                  model,
                  i18n_text.EmailRequired,
                )),
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
          let origin = client_ffi.location_origin()
          let text = origin <> reset.url_path

          #(
            Model(
              ..model,
              forgot_password_copy_status: opt.Some(update_helpers.i18n_t(
                model,
                i18n_text.Copying,
              )),
            ),
            copy_to_clipboard(text, ForgotPasswordCopyFinished),
          )
        }
      }
    }

    ForgotPasswordCopyFinished(ok) -> {
      let message = case ok {
        True -> update_helpers.i18n_t(model, i18n_text.Copied)
        False -> update_helpers.i18n_t(model, i18n_text.CopyFailed)
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
          toast: opt.Some(update_helpers.i18n_t(model, i18n_text.LoggedOut)),
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
          Model(..model, toast: opt.Some(update_helpers.i18n_t(model, i18n_text.LogoutFailed))),
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

    LocaleSelected(value) -> {
      let next_locale = i18n_locale.deserialize(value)

      case next_locale == model.locale {
        True -> #(model, effect.none())

        False -> #(
          Model(..model, locale: next_locale),
          effect.from(fn(_dispatch) { i18n_locale.save(next_locale) }),
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
        update_helpers.ensure_selected_project(model.selected_project_id, projects)
      let model =
        Model(
          ..model,
          projects: Loaded(projects),
          selected_project_id: selected,
        )

      let model = update_helpers.ensure_default_section(model)

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
          let model =
            Model(
              ..model,
              page: Login,
              user: opt.None,
              member_drag: opt.None,
              member_pool_drag_to_claim_armed: False,
              member_pool_drag_over_my_tasks: False,
            )
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
                projects_create_error: opt.Some(update_helpers.i18n_t(
                  model,
                  i18n_text.NameRequired,
                )),
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
          toast: opt.Some(update_helpers.i18n_t(model, i18n_text.ProjectCreated)),
        ),
        effect.none(),
      )
    }

    ProjectCreated(Error(err)) -> {
      case err.status {
        401 -> #(
          Model(
            ..model,
            page: Login,
            user: opt.None,
            member_drag: opt.None,
            member_pool_drag_to_claim_armed: False,
            member_pool_drag_over_my_tasks: False,
          ),
          effect.none(),
        )
        403 -> #(
          Model(
            ..model,
            projects_create_in_flight: False,
            projects_create_error: opt.Some(update_helpers.i18n_t(
              model,
              i18n_text.NotPermitted,
            )),
            toast: opt.Some(update_helpers.i18n_t(model, i18n_text.NotPermitted)),
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
              Model(
                ..model,
                invite_link_error: opt.Some(update_helpers.i18n_t(
                  model,
                  i18n_text.EmailRequired,
                )),
              ),
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
              Model(
                ..model,
                invite_link_error: opt.Some(update_helpers.i18n_t(
                  model,
                  i18n_text.EmailRequired,
                )),
              ),
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
          toast: opt.Some(update_helpers.i18n_t(model, i18n_text.InviteLinkCreated)),
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
          toast: opt.Some(update_helpers.i18n_t(model, i18n_text.InviteLinkRegenerated)),
        )

      #(model, api.list_invite_links(InviteLinksFetched))
    }

    InviteLinkRegenerated(Error(err)) -> {
      case err.status {
        401 -> #(
          Model(
            ..model,
            page: Login,
            user: opt.None,
            member_drag: opt.None,
            member_pool_drag_to_claim_armed: False,
            member_pool_drag_over_my_tasks: False,
          ),
          effect.none(),
        )
        403 -> #(
          Model(
            ..model,
            invite_link_in_flight: False,
            invite_link_error: opt.Some(update_helpers.i18n_t(model, i18n_text.NotPermitted)),
            toast: opt.Some(update_helpers.i18n_t(model, i18n_text.NotPermitted)),
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

    InviteLinkCreated(Error(err)) -> {
      case err.status {
        401 -> #(
          Model(
            ..model,
            page: Login,
            user: opt.None,
            member_drag: opt.None,
            member_pool_drag_to_claim_armed: False,
            member_pool_drag_over_my_tasks: False,
          ),
          effect.none(),
        )
        403 -> #(
          Model(
            ..model,
            invite_link_in_flight: False,
            invite_link_error: opt.Some(update_helpers.i18n_t(model, i18n_text.NotPermitted)),
            toast: opt.Some(update_helpers.i18n_t(model, i18n_text.NotPermitted)),
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
      Model(
        ..model,
        invite_link_copy_status: opt.Some(update_helpers.i18n_t(model, i18n_text.Copying)),
      ),
      copy_to_clipboard(text, InviteLinkCopyFinished),
    )

    InviteLinkCopyFinished(ok) -> {
      let message = case ok {
        True -> update_helpers.i18n_t(model, i18n_text.Copied)
        False -> update_helpers.i18n_t(model, i18n_text.CopyFailed)
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
                capabilities_create_error: opt.Some(update_helpers.i18n_t(
                  model,
                  i18n_text.NameRequired,
                )),
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
          toast: opt.Some(update_helpers.i18n_t(model, i18n_text.CapabilityCreated)),
        ),
        effect.none(),
      )
    }

    CapabilityCreated(Error(err)) -> {
      case err.status {
        401 -> #(
          Model(
            ..model,
            page: Login,
            user: opt.None,
            member_drag: opt.None,
            member_pool_drag_to_claim_armed: False,
            member_pool_drag_over_my_tasks: False,
          ),
          effect.none(),
        )
        403 -> #(
          Model(
            ..model,
            capabilities_create_in_flight: False,
            capabilities_create_error: opt.Some(update_helpers.i18n_t(
              model,
              i18n_text.NotPermitted,
            )),
            toast: opt.Some(update_helpers.i18n_t(model, i18n_text.NotPermitted)),
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
        401 -> #(
          Model(
            ..model,
            page: Login,
            user: opt.None,
            member_drag: opt.None,
            member_pool_drag_to_claim_armed: False,
            member_pool_drag_over_my_tasks: False,
          ),
          effect.none(),
        )

        403 -> #(
          Model(
            ..model,
            org_settings_users: Failed(err),
            toast: opt.Some(update_helpers.i18n_t(model, i18n_text.NotPermitted)),
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
          toast: opt.Some(update_helpers.i18n_t(model, i18n_text.RoleUpdated)),
        ),
        effect.none(),
      )
    }

    OrgSettingsSaved(user_id, Error(err)) -> {
      case err.status {
        401 -> #(
          Model(
            ..model,
            page: Login,
            user: opt.None,
            member_drag: opt.None,
            member_pool_drag_to_claim_armed: False,
            member_pool_drag_over_my_tasks: False,
          ),
          effect.none(),
        )

        403 -> #(
          Model(
            ..model,
            org_settings_save_in_flight: False,
            toast: opt.Some(update_helpers.i18n_t(model, i18n_text.NotPermitted)),
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
              Model(
                ..model,
                members_add_error: opt.Some(update_helpers.i18n_t(
                  model,
                  i18n_text.SelectUserFirst,
                )),
              ),
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
          toast: opt.Some(update_helpers.i18n_t(model, i18n_text.MemberAdded)),
        )
      refresh_section(model)
    }

    MemberAdded(Error(err)) -> {
      case err.status {
        401 -> #(
          Model(
            ..model,
            page: Login,
            user: opt.None,
            member_drag: opt.None,
            member_pool_drag_to_claim_armed: False,
            member_pool_drag_over_my_tasks: False,
          ),
          effect.none(),
        )
        403 -> #(
          Model(
            ..model,
            members_add_in_flight: False,
            members_add_error: opt.Some(update_helpers.i18n_t(model, i18n_text.NotPermitted)),
            toast: opt.Some(update_helpers.i18n_t(model, i18n_text.NotPermitted)),
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
      let maybe_user = update_helpers.resolve_org_user(model.org_users_cache, user_id)

      let user = case maybe_user {
        opt.Some(user) -> user
        opt.None -> fallback_org_user(model, user_id)
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
          toast: opt.Some(update_helpers.i18n_t(model, i18n_text.MemberRemoved)),
        )
      refresh_section(model)
    }

    MemberRemoved(Error(err)) -> {
      case err.status {
        401 -> #(
          Model(
            ..model,
            page: Login,
            user: opt.None,
            member_drag: opt.None,
            member_pool_drag_to_claim_armed: False,
            member_pool_drag_over_my_tasks: False,
          ),
          effect.none(),
        )
        403 -> #(
          Model(
            ..model,
            members_remove_in_flight: False,
            members_remove_error: opt.Some(update_helpers.i18n_t(model, i18n_text.NotPermitted)),
            toast: opt.Some(update_helpers.i18n_t(model, i18n_text.NotPermitted)),
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
                task_types_create_error: opt.Some(update_helpers.i18n_t(
                  model,
                  i18n_text.SelectProjectFirst,
                )),
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
                    task_types_create_error: opt.Some(update_helpers.i18n_t(
                      model,
                      i18n_text.NameAndIconRequired,
                    )),
                  ),
                  effect.none(),
                )
                False -> {
                  case model.task_types_icon_preview {
                    IconError -> #(
                      Model(
                        ..model,
                        task_types_create_error: opt.Some(update_helpers.i18n_t(
                          model,
                          i18n_text.UnknownIcon,
                        )),
                      ),
                      effect.none(),
                    )
                    IconLoading | IconIdle -> #(
                      Model(
                        ..model,
                        task_types_create_error: opt.Some(update_helpers.i18n_t(
                          model,
                          i18n_text.WaitForIconPreview,
                        )),
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
          toast: opt.Some(update_helpers.i18n_t(model, i18n_text.TaskTypeCreated)),
        )

      refresh_section(model)
    }

    TaskTypeCreated(Error(err)) -> {
      case err.status {
        401 -> #(
          Model(
            ..model,
            page: Login,
            user: opt.None,
            member_drag: opt.None,
            member_pool_drag_to_claim_armed: False,
            member_pool_drag_over_my_tasks: False,
          ),
          effect.none(),
        )
        403 -> #(
          Model(
            ..model,
            task_types_create_in_flight: False,
            task_types_create_error: opt.Some(update_helpers.i18n_t(
              model,
              i18n_text.NotPermitted,
            )),
            toast: opt.Some(update_helpers.i18n_t(model, i18n_text.NotPermitted)),
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

    MemberPoolFiltersToggled -> {
      let next = !model.member_pool_filters_visible
      #(
        Model(..model, member_pool_filters_visible: next),
        save_pool_filters_visible_effect(next),
      )
    }

    MemberPoolViewModeSet(mode) -> #(
      Model(..model, member_pool_view_mode: mode),
      save_pool_view_mode_effect(mode),
    )

    GlobalKeyDown(event) -> handle_pool_keydown(model, event)

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
          Model(..model, member_tasks: Loaded(update_helpers.flatten_tasks(tasks_by_project))),
          effect.none(),
        )
        False -> #(model, effect.none())
      }
    }

    MemberProjectTasksFetched(_project_id, Error(err)) -> {
      case err.status {
        401 -> #(
          Model(
            ..model,
            page: Login,
            user: opt.None,
            member_drag: opt.None,
            member_pool_drag_to_claim_armed: False,
            member_pool_drag_over_my_tasks: False,
          ),
          effect.none(),
        )
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
            member_task_types: Loaded(update_helpers.flatten_task_types(task_types_by_project)),
          ),
          effect.none(),
        )
        False -> #(model, effect.none())
      }
    }

    MemberTaskTypesFetched(_project_id, Error(err)) -> {
      case err.status {
        401 -> #(
          Model(
            ..model,
            page: Login,
            user: opt.None,
            member_drag: opt.None,
            member_pool_drag_to_claim_armed: False,
            member_pool_drag_over_my_tasks: False,
          ),
          effect.none(),
        )
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
          member_pool_drag_to_claim_armed: True,
          member_pool_drag_over_my_tasks: False,
        )

      #(
        model,
        effect.from(fn(dispatch) {
          let #(left, top) = client_ffi.element_client_offset("member-canvas")
          dispatch(MemberCanvasRectFetched(left, top))

          let #(dz_left, dz_top, dz_width, dz_height) =
            client_ffi.element_client_rect("pool-my-tasks")
          dispatch(MemberPoolMyTasksRectFetched(
            dz_left,
            dz_top,
            dz_width,
            dz_height,
          ))
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

          let over_my_tasks = case model.member_pool_my_tasks_rect {
            opt.Some(rect) if model.member_pool_drag_to_claim_armed ->
              rect_contains_point(rect, client_x, client_y)
            _ -> False
          }

          #(
            Model(
              ..model,
              member_positions_by_task: dict.insert(
                model.member_positions_by_task,
                task_id,
                #(x, y),
              ),
              member_pool_drag_over_my_tasks: over_my_tasks,
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

          let over_my_tasks = model.member_pool_drag_over_my_tasks

          let model =
            Model(
              ..model,
              member_drag: opt.None,
              member_pool_drag_to_claim_armed: False,
              member_pool_drag_over_my_tasks: False,
            )

          // If the pointer ended over My Tasks, interpret as optional drop-to-claim.
          case over_my_tasks {
            True -> {
              case update_helpers.find_task_by_id(model.member_tasks, task_id) {
                opt.Some(api.Task(version: version, ..)) ->
                  case model.member_task_mutation_in_flight {
                    True -> #(model, effect.none())
                    False -> #(
                      Model(..model, member_task_mutation_in_flight: True),
                      api.claim_task(task_id, version, MemberTaskClaimed),
                    )
                  }

                opt.None -> #(model, effect.none())
              }
            }

            False -> {
              let #(x, y) = case
                dict.get(model.member_positions_by_task, task_id)
              {
                Ok(xy) -> xy
                Error(_) -> #(0, 0)
              }

              #(
                model,
                api.upsert_me_task_position(task_id, x, y, MemberPositionSaved),
              )
            }
          }
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
                member_create_error: opt.Some(update_helpers.i18n_t(
                  model,
                  i18n_text.SelectProjectFirst,
                )),
              ),
              effect.none(),
            )

            opt.Some(project_id) -> {
              let title = string.trim(model.member_create_title)

              case title == "" {
                True -> #(
                  Model(
                    ..model,
                    member_create_error: opt.Some(update_helpers.i18n_t(
                      model,
                      i18n_text.TitleRequired,
                    )),
                  ),
                  effect.none(),
                )

                False ->
                  case string.length(title) > 56 {
                    True -> #(
                      Model(
                        ..model,
                        member_create_error: opt.Some(update_helpers.i18n_t(
                          model,
                          i18n_text.TitleTooLongMax56,
                        )),
                      ),
                      effect.none(),
                    )

                    False ->
                      case int.parse(model.member_create_type_id) {
                        Error(_) -> #(
                          Model(
                            ..model,
                            member_create_error: opt.Some(update_helpers.i18n_t(
                              model,
                              i18n_text.TypeRequired,
                            )),
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
                                member_create_error: opt.Some(update_helpers.i18n_t(
                                  model,
                                  i18n_text.PriorityMustBe1To5,
                                )),
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
          toast: opt.Some(update_helpers.i18n_t(model, i18n_text.TaskCreated)),
        )
      member_refresh(model)
    }

    MemberTaskCreated(Error(err)) -> {
      case err.status {
        401 -> #(
          Model(
            ..model,
            page: Login,
            user: opt.None,
            member_drag: opt.None,
            member_pool_drag_to_claim_armed: False,
            member_pool_drag_over_my_tasks: False,
          ),
          effect.none(),
        )
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
          toast: opt.Some(update_helpers.i18n_t(model, i18n_text.TaskClaimed)),
        ),
      )
    MemberTaskReleased(Ok(_)) -> {
      let model =
        Model(
          ..model,
          member_task_mutation_in_flight: False,
          toast: opt.Some(update_helpers.i18n_t(model, i18n_text.TaskReleased)),
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
          toast: opt.Some(update_helpers.i18n_t(model, i18n_text.TaskCompleted)),
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
      let server_ms = client_ffi.parse_iso_ms(as_of)
      let offset = client_ffi.now_ms() - server_ms

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
        401 -> #(
          Model(
            ..model,
            page: Login,
            user: opt.None,
            member_drag: opt.None,
            member_pool_drag_to_claim_armed: False,
            member_pool_drag_over_my_tasks: False,
          ),
          effect.none(),
        )
        _ -> #(Model(..model, member_active_task: Failed(err)), effect.none())
      }
    }

    MemberActiveTaskStarted(Ok(payload)) -> {
      let api.ActiveTaskPayload(as_of: as_of, ..) = payload
      let server_ms = client_ffi.parse_iso_ms(as_of)
      let offset = client_ffi.now_ms() - server_ms

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
        401 -> #(
          Model(
            ..model,
            page: Login,
            user: opt.None,
            member_drag: opt.None,
            member_pool_drag_to_claim_armed: False,
            member_pool_drag_over_my_tasks: False,
          ),
          effect.none(),
        )
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
      let server_ms = client_ffi.parse_iso_ms(as_of)
      let offset = client_ffi.now_ms() - server_ms

      let model =
        Model(
          ..model,
          member_now_working_in_flight: False,
          member_active_task: Loaded(payload),
          now_working_server_offset_ms: offset,
        )

      // Stop tick loop when active task is cleared.
      let model = case update_helpers.now_working_active_task(model) {
        opt.None -> Model(..model, now_working_tick_running: False)
        opt.Some(_) -> model
      }

      #(model, effect.none())
    }

    MemberActiveTaskPaused(Error(err)) -> {
      let model = Model(..model, member_now_working_in_flight: False)

      case err.status {
        401 -> #(
          Model(
            ..model,
            page: Login,
            user: opt.None,
            member_drag: opt.None,
            member_pool_drag_to_claim_armed: False,
            member_pool_drag_over_my_tasks: False,
          ),
          effect.none(),
        )
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

    MemberActiveTaskHeartbeated(Ok(payload)) -> {
      let api.ActiveTaskPayload(as_of: as_of, ..) = payload
      let server_ms = client_ffi.parse_iso_ms(as_of)
      let offset = client_ffi.now_ms() - server_ms

      let #(model, tick_fx) =
        Model(
          ..model,
          member_active_task: Loaded(payload),
          now_working_server_offset_ms: offset,
        )
        |> start_now_working_tick_if_needed

      #(model, tick_fx)
    }

    MemberActiveTaskHeartbeated(Error(err)) -> {
      case err.status {
        401 -> #(
          Model(
            ..model,
            page: Login,
            user: opt.None,
            member_drag: opt.None,
            member_pool_drag_to_claim_armed: False,
            member_pool_drag_over_my_tasks: False,
          ),
          effect.none(),
        )
        _ -> #(model, effect.none())
      }
    }

    MemberMetricsFetched(Ok(metrics)) -> #(
      Model(..model, member_metrics: Loaded(metrics)),
      effect.none(),
    )

    MemberMetricsFetched(Error(err)) -> {
      case err.status {
        401 -> #(
          Model(
            ..model,
            page: Login,
            user: opt.None,
            member_drag: opt.None,
            member_pool_drag_to_claim_armed: False,
            member_pool_drag_over_my_tasks: False,
          ),
          effect.none(),
        )
        _ -> #(Model(..model, member_metrics: Failed(err)), effect.none())
      }
    }

    AdminMetricsOverviewFetched(Ok(overview)) -> #(
      Model(..model, admin_metrics_overview: Loaded(overview)),
      effect.none(),
    )

    AdminMetricsOverviewFetched(Error(err)) -> {
      case err.status {
        401 -> #(
          Model(
            ..model,
            page: Login,
            user: opt.None,
            member_drag: opt.None,
            member_pool_drag_to_claim_armed: False,
            member_pool_drag_over_my_tasks: False,
          ),
          effect.none(),
        )
        _ -> #(
          Model(..model, admin_metrics_overview: Failed(err)),
          effect.none(),
        )
      }
    }

    AdminMetricsProjectTasksFetched(Ok(payload)) -> {
      let api.OrgMetricsProjectTasksPayload(project_id: project_id, ..) =
        payload

      #(
        Model(
          ..model,
          admin_metrics_project_tasks: Loaded(payload),
          admin_metrics_project_id: opt.Some(project_id),
        ),
        effect.none(),
      )
    }

    AdminMetricsProjectTasksFetched(Error(err)) -> {
      case err.status {
        401 -> #(
          Model(
            ..model,
            page: Login,
            user: opt.None,
            member_drag: opt.None,
            member_pool_drag_to_claim_armed: False,
            member_pool_drag_over_my_tasks: False,
          ),
          effect.none(),
        )
        _ -> #(
          Model(..model, admin_metrics_project_tasks: Failed(err)),
          effect.none(),
        )
      }
    }

    NowWorkingTicked -> {
      let next_tick = model.now_working_tick + 1
      let model = Model(..model, now_working_tick: next_tick)

      let heartbeat_fx = case
        next_tick % 60 == 0
        && model.member_now_working_in_flight == False
        && update_helpers.now_working_active_task(model) != opt.None
      {
        True -> api.heartbeat_me_active_task(MemberActiveTaskHeartbeated)
        False -> effect.none()
      }

      case update_helpers.now_working_active_task(model) {
        opt.Some(_) -> #(
          model,
          effect.batch([now_working_tick_effect(), heartbeat_fx]),
        )

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
        member_my_capability_ids_edit: update_helpers.ids_to_bool_dict(ids),
      ),
      effect.none(),
    )

    MemberMyCapabilityIdsFetched(Error(err)) -> {
      case err.status {
        401 -> #(
          Model(
            ..model,
            page: Login,
            user: opt.None,
            member_drag: opt.None,
            member_pool_drag_to_claim_armed: False,
            member_pool_drag_over_my_tasks: False,
          ),
          effect.none(),
        )
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
          let ids = update_helpers.bool_dict_to_ids(model.member_my_capability_ids_edit)
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
        member_my_capability_ids_edit: update_helpers.ids_to_bool_dict(ids),
        toast: opt.Some(update_helpers.i18n_t(model, i18n_text.SkillsSaved)),
      ),
      effect.none(),
    )

    MemberMyCapabilityIdsSaved(Error(err)) -> {
      case err.status {
        401 -> #(
          Model(
            ..model,
            page: Login,
            user: opt.None,
            member_drag: opt.None,
            member_pool_drag_to_claim_armed: False,
            member_pool_drag_over_my_tasks: False,
          ),
          effect.none(),
        )
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
      Model(..model, member_positions_by_task: update_helpers.positions_to_dict(positions)),
      effect.none(),
    )

    MemberPositionsFetched(Error(err)) -> {
      case err.status {
        401 -> #(
          Model(
            ..model,
            page: Login,
            user: opt.None,
            member_drag: opt.None,
            member_pool_drag_to_claim_armed: False,
            member_pool_drag_over_my_tasks: False,
          ),
          effect.none(),
        )
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
                    member_position_edit_error: opt.Some(update_helpers.i18n_t(
                      model,
                      i18n_text.InvalidXY,
                    )),
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
        401 -> #(
          Model(
            ..model,
            page: Login,
            user: opt.None,
            member_drag: opt.None,
            member_pool_drag_to_claim_armed: False,
            member_pool_drag_over_my_tasks: False,
          ),
          effect.none(),
        )
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
        401 -> #(
          Model(
            ..model,
            page: Login,
            user: opt.None,
            member_drag: opt.None,
            member_pool_drag_to_claim_armed: False,
            member_pool_drag_over_my_tasks: False,
          ),
          effect.none(),
        )
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
                    member_note_error: opt.Some(update_helpers.i18n_t(
                      model,
                      i18n_text.ContentRequired,
                    )),
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
          toast: opt.Some(update_helpers.i18n_t(model, i18n_text.NoteAdded)),
        ),
        effect.none(),
      )
    }

    MemberNoteAdded(Error(err)) -> {
      case err.status {
        401 -> #(
          Model(
            ..model,
            page: Login,
            user: opt.None,
            member_drag: opt.None,
            member_pool_drag_to_claim_armed: False,
            member_pool_drag_over_my_tasks: False,
          ),
          effect.none(),
        )
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

    permissions.Metrics -> {
      let model = Model(..model, admin_metrics_overview: Loading)

      let overview_fx =
        api.get_org_metrics_overview(30, AdminMetricsOverviewFetched)

      case model.selected_project_id {
        opt.None -> #(model, overview_fx)

        opt.Some(project_id) -> {
          let model =
            Model(
              ..model,
              admin_metrics_project_tasks: Loading,
              admin_metrics_project_id: opt.Some(project_id),
            )

          let tasks_fx =
            api.get_org_metrics_project_tasks(
              project_id,
              30,
              AdminMetricsProjectTasksFetched,
            )

          #(model, effect.batch([overview_fx, tasks_fx]))
        }
      }
    }

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

fn fallback_org_user(model: Model, user_id: Int) -> api.OrgUser {
  api.OrgUser(
    id: user_id,
    email: update_helpers.i18n_t(model, i18n_text.UserNumber(user_id)),
    org_role: "",
    created_at: "",
  )
}

fn copy_to_clipboard(text: String, msg: fn(Bool) -> Msg) -> Effect(Msg) {
  effect.from(fn(dispatch) {
    client_ffi.copy_to_clipboard(text, fn(ok) { dispatch(msg(ok)) })
  })
}

fn now_working_tick_effect() -> Effect(Msg) {
  effect.from(fn(dispatch) {
    client_ffi.set_timeout(1000, fn(_) { dispatch(NowWorkingTicked) })
    Nil
  })
}

fn start_now_working_tick_if_needed(model: Model) -> #(Model, Effect(Msg)) {
  case model.now_working_tick_running {
    True -> #(model, effect.none())

    False ->
      case update_helpers.now_working_active_task(model) {
        opt.Some(_) -> #(
          Model(..model, now_working_tick_running: True),
          now_working_tick_effect(),
        )
        opt.None -> #(model, effect.none())
      }
  }
}

fn page_title(section: permissions.AdminSection) -> i18n_text.Text {
  case section {
    permissions.Invites -> i18n_text.AdminInvites
    permissions.OrgSettings -> i18n_text.AdminOrgSettings
    permissions.Projects -> i18n_text.AdminProjects
    permissions.Metrics -> i18n_text.AdminMetrics
    permissions.Members -> i18n_text.AdminMembers
    permissions.Capabilities -> i18n_text.AdminCapabilities
    permissions.TaskTypes -> i18n_text.AdminTaskTypes
  }
}

pub fn now_working_elapsed_from_ms_for_test(
  accumulated_s: Int,
  started_ms: Int,
  server_now_ms: Int,
) -> String {
  update_helpers.now_working_elapsed_from_ms(accumulated_s, started_ms, server_now_ms)
}

fn now_working_elapsed(model: Model) -> String {
  case update_helpers.now_working_active_task(model) {
    opt.None -> "00:00"

    opt.Some(api.ActiveTask(
      started_at: started_at,
      accumulated_s: accumulated_s,
      ..,
    )) -> {
      let started_ms = client_ffi.parse_iso_ms(started_at)
      let local_now_ms = client_ffi.now_ms()
      let server_now_ms = local_now_ms - model.now_working_server_offset_ms
      update_helpers.now_working_elapsed_from_ms(accumulated_s, started_ms, server_now_ms)
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
      view_toast(model),
      case model.page {
        Login -> view_login(model)
        AcceptInvitePage -> view_accept_invite(model)
        ResetPasswordPage -> view_reset_password(model)
        Admin -> view_admin(model)
        Member -> view_member(model)
      },
    ],
  )
}

fn view_toast(model: Model) -> Element(Msg) {
  case model.toast {
    opt.None -> div([], [])
    opt.Some(message) ->
      div([attribute.class("toast")], [
        span([], [text(message)]),
        button(
          [
            attribute.class("toast-dismiss btn-xs"),
            attribute.attribute("aria-label", update_helpers.i18n_t(model, i18n_text.Dismiss)),
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
      div([attribute.class("error")], [
        text(update_helpers.i18n_t(model, i18n_text.MissingInviteToken)),
      ])

    accept_invite.Validating ->
      div([attribute.class("loading")], [
        text(update_helpers.i18n_t(model, i18n_text.ValidatingInvite)),
      ])

    accept_invite.Invalid(code: _, message: message) ->
      div([attribute.class("error")], [text(message)])

    accept_invite.Ready(email) ->
      view_accept_invite_form(model, email, password, False, password_error)

    accept_invite.Registering(email) ->
      view_accept_invite_form(model, email, password, True, password_error)

    accept_invite.Done ->
      div([attribute.class("loading")], [
        text(update_helpers.i18n_t(model, i18n_text.SignedIn)),
      ])
  }

  div([attribute.class("page")], [
    h1([], [text(update_helpers.i18n_t(model, i18n_text.AppName))]),
    h2([], [text(update_helpers.i18n_t(model, i18n_text.AcceptInviteTitle))]),
    case submit_error {
      opt.Some(err) ->
        div([attribute.class("error")], [
          span([], [text(err)]),
          button(
            [event.on_click(AcceptInviteMsg(accept_invite.ErrorDismissed))],
            [text(update_helpers.i18n_t(model, i18n_text.Dismiss))],
          ),
        ])
      opt.None -> div([], [])
    },
    content,
  ])
}

fn view_accept_invite_form(
  model: Model,
  email: String,
  password: String,
  in_flight: Bool,
  password_error: opt.Option(String),
) -> Element(Msg) {
  let submit_label = case in_flight {
    True -> update_helpers.i18n_t(model, i18n_text.Registering)
    False -> update_helpers.i18n_t(model, i18n_text.Register)
  }

  form([event.on_submit(fn(_) { AcceptInviteMsg(accept_invite.Submitted) })], [
    div([attribute.class("field")], [
      label([], [text(update_helpers.i18n_t(model, i18n_text.EmailLabel))]),
      input([
        attribute.type_("email"),
        attribute.value(email),
        attribute.disabled(True),
      ]),
    ]),
    div([attribute.class("field")], [
      label([], [text(update_helpers.i18n_t(model, i18n_text.PasswordLabel))]),
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
      p([], [text(update_helpers.i18n_t(model, i18n_text.MinimumPasswordLength))]),
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
      div([attribute.class("error")], [
        text(update_helpers.i18n_t(model, i18n_text.MissingResetToken)),
      ])

    reset_password.Validating ->
      div([attribute.class("loading")], [
        text(update_helpers.i18n_t(model, i18n_text.ValidatingResetToken)),
      ])

    reset_password.Invalid(code: _, message: message) ->
      div([attribute.class("error")], [text(message)])

    reset_password.Ready(email) ->
      view_reset_password_form(model, email, password, False, password_error)

    reset_password.Consuming(email) ->
      view_reset_password_form(model, email, password, True, password_error)

    reset_password.Done ->
      div([attribute.class("loading")], [
        text(update_helpers.i18n_t(model, i18n_text.PasswordUpdated)),
      ])
  }

  div([attribute.class("page")], [
    h1([], [text(update_helpers.i18n_t(model, i18n_text.AppName))]),
    h2([], [text(update_helpers.i18n_t(model, i18n_text.ResetPasswordTitle))]),
    case submit_error {
      opt.Some(err) ->
        div([attribute.class("error")], [
          span([], [text(err)]),
          button(
            [event.on_click(ResetPasswordMsg(reset_password.ErrorDismissed))],
            [text(update_helpers.i18n_t(model, i18n_text.Dismiss))],
          ),
        ])
      opt.None -> div([], [])
    },
    content,
  ])
}

fn view_reset_password_form(
  model: Model,
  email: String,
  password: String,
  in_flight: Bool,
  password_error: opt.Option(String),
) -> Element(Msg) {
  let submit_label = case in_flight {
    True -> update_helpers.i18n_t(model, i18n_text.Saving)
    False -> update_helpers.i18n_t(model, i18n_text.SaveNewPassword)
  }

  form([event.on_submit(fn(_) { ResetPasswordMsg(reset_password.Submitted) })], [
    div([attribute.class("field")], [
      label([], [text(update_helpers.i18n_t(model, i18n_text.EmailLabel))]),
      input([
        attribute.type_("email"),
        attribute.value(email),
        attribute.disabled(True),
      ]),
    ]),
    div([attribute.class("field")], [
      label([], [text(update_helpers.i18n_t(model, i18n_text.NewPasswordLabel))]),
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
      p([], [text(update_helpers.i18n_t(model, i18n_text.MinimumPasswordLength))]),
    ]),
    button([attribute.type_("submit"), attribute.disabled(in_flight)], [
      text(submit_label),
    ]),
  ])
}

fn view_forgot_password(model: Model) -> Element(Msg) {
  let submit_label = case model.forgot_password_in_flight {
    True -> update_helpers.i18n_t(model, i18n_text.Working)
    False -> update_helpers.i18n_t(model, i18n_text.GenerateResetLink)
  }

  let origin = client_ffi.location_origin()

  let link = case model.forgot_password_result {
    opt.Some(reset) -> origin <> reset.url_path
    opt.None -> ""
  }

  div([attribute.class("section")], [
    p([], [text(update_helpers.i18n_t(model, i18n_text.NoEmailIntegrationNote))]),
    case model.forgot_password_error {
      opt.Some(err) ->
        div([attribute.class("error")], [
          span([], [text(err)]),
          button([event.on_click(ForgotPasswordDismissed)], [
            text(update_helpers.i18n_t(model, i18n_text.Dismiss)),
          ]),
        ])
      opt.None -> div([], [])
    },
    form([event.on_submit(fn(_) { ForgotPasswordSubmitted })], [
      div([attribute.class("field")], [
        label([], [text(update_helpers.i18n_t(model, i18n_text.EmailLabel))]),
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
          label([], [text(update_helpers.i18n_t(model, i18n_text.ResetLink))]),
          div([attribute.class("copy")], [
            input([
              attribute.type_("text"),
              attribute.value(link),
              attribute.readonly(True),
            ]),
            button([event.on_click(ForgotPasswordCopyClicked)], [
              text(update_helpers.i18n_t(model, i18n_text.Copy)),
            ]),
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
    True -> update_helpers.i18n_t(model, i18n_text.LoggingIn)
    False -> update_helpers.i18n_t(model, i18n_text.LoginTitle)
  }

  div([attribute.class("page")], [
    h1([], [text(update_helpers.i18n_t(model, i18n_text.AppName))]),
    p([], [text(update_helpers.i18n_t(model, i18n_text.LoginSubtitle))]),
    case model.login_error {
      opt.Some(err) -> div([attribute.class("error")], [text(err)])
      opt.None -> div([], [])
    },
    form([event.on_submit(fn(_) { LoginSubmitted })], [
      div([attribute.class("field")], [
        label([], [text(update_helpers.i18n_t(model, i18n_text.EmailLabel))]),
        input([
          attribute.attribute("id", "login-email"),
          attribute.type_("email"),
          attribute.value(model.login_email),
          event.on_input(LoginEmailChanged),
          attribute.required(True),
        ]),
      ]),
      div([attribute.class("field")], [
        label([], [text(update_helpers.i18n_t(model, i18n_text.PasswordLabel))]),
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
    button([event.on_click(ForgotPasswordClicked)], [
      text(update_helpers.i18n_t(model, i18n_text.ForgotPassword)),
    ]),
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
      let projects = update_helpers.active_projects(model)
      let selected = update_helpers.selected_project(model)
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
    text(i18n.t(model.locale, i18n_text.ThemeLabel)),
    select([attribute.value(current), event.on_input(ThemeSelected)], [
      option(
        [attribute.value("default")],
        i18n.t(model.locale, i18n_text.ThemeDefault),
      ),
      option(
        [attribute.value("dark")],
        i18n.t(model.locale, i18n_text.ThemeDark),
      ),
    ]),
  ])
}

fn view_locale_switch(model: Model) -> Element(Msg) {
  let current = i18n_locale.serialize(model.locale)

  label([attribute.class("theme-switch")], [
    text(i18n.t(model.locale, i18n_text.LanguageLabel)),
    select([attribute.value(current), event.on_input(LocaleSelected)], [
      option(
        [attribute.value("es")],
        i18n.t(model.locale, i18n_text.LanguageEs),
      ),
      option(
        [attribute.value("en")],
        i18n.t(model.locale, i18n_text.LanguageEn),
      ),
    ]),
  ])
}

fn view_topbar(model: Model, user: User) -> Element(Msg) {
  let show_project_selector =
    model.active_section == permissions.Members
    || model.active_section == permissions.TaskTypes
    || model.active_section == permissions.Metrics

  div([attribute.class("topbar")], [
    div([attribute.class("topbar-title")], [
      text(i18n.t(model.locale, page_title(model.active_section))),
    ]),
    case show_project_selector {
      True -> view_project_selector(model)
      False -> div([], [])
    },
    div([attribute.class("topbar-actions")], [
      view_theme_switch(model),
      view_locale_switch(model),
      span([attribute.class("user")], [text(user.email)]),
      button(
        [
          event.on_click(NavigateTo(
            router.Member(model.member_section, model.selected_project_id),
            Push,
          )),
        ],
        [text(i18n.t(model.locale, i18n_text.Pool))],
      ),
      button([event.on_click(LogoutClicked)], [
        text(i18n.t(model.locale, i18n_text.Logout)),
      ]),
    ]),
  ])
}

fn view_project_selector(model: Model) -> Element(Msg) {
  let projects = update_helpers.active_projects(model)

  let selected_id = case model.selected_project_id {
    opt.Some(id) -> int.to_string(id)
    opt.None -> ""
  }

  let empty_label = case model.page {
    Member -> update_helpers.i18n_t(model, i18n_text.AllProjects)
    _ -> update_helpers.i18n_t(model, i18n_text.SelectProjectToManageSettings)
  }

  let helper = case model.page, model.selected_project_id {
    Member, opt.None -> update_helpers.i18n_t(model, i18n_text.ShowingTasksFromAllProjects)
    Member, _ -> ""
    _, opt.None ->
      update_helpers.i18n_t(model, i18n_text.SelectProjectToManageMembersOrTaskTypes)
    _, _ -> ""
  }

  div([attribute.class("project-selector")], [
    div([attribute.class("topbar-group")], [
      label([], [text(update_helpers.i18n_t(model, i18n_text.ProjectLabel))]),
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
    ]),
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
    h3([], [text(update_helpers.i18n_t(model, i18n_text.Admin))]),
    case sections {
      [] ->
        div([attribute.class("empty")], [
          text(update_helpers.i18n_t(model, i18n_text.NoAdminPermissions)),
        ])
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
              [text(i18n.t(model.locale, page_title(section)))],
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
        h2([], [text(update_helpers.i18n_t(model, i18n_text.NotPermitted))]),
        p([], [text(update_helpers.i18n_t(model, i18n_text.NotPermittedBody))]),
      ])

    True ->
      case model.active_section {
        permissions.Invites -> view_invites(model)
        permissions.OrgSettings -> view_org_settings(model)
        permissions.Projects -> view_projects(model)
        permissions.Metrics -> view_metrics(model, selected)
        permissions.Capabilities -> view_capabilities(model)
        permissions.Members -> view_members(model, selected)
        permissions.TaskTypes -> view_task_types(model, selected)
      }
  }
}

fn view_metrics(model: Model, selected: opt.Option(api.Project)) -> Element(Msg) {
  div([attribute.class("section")], [
    view_metrics_overview_panel(model),
    view_metrics_project_panel(model, selected),
  ])
}

fn view_metrics_overview_panel(model: Model) -> Element(Msg) {
  case model.admin_metrics_overview {
    NotAsked | Loading ->
      div([attribute.class("panel")], [
        h2([], [text(update_helpers.i18n_t(model, i18n_text.MetricsOverview))]),
        div([attribute.class("loading")], [
          text(update_helpers.i18n_t(model, i18n_text.LoadingOverview)),
        ]),
      ])

    Failed(err) ->
      div([attribute.class("panel")], [
        h2([], [text(update_helpers.i18n_t(model, i18n_text.MetricsOverview))]),
        div([attribute.class("error")], [text(err.message)]),
      ])

    Loaded(overview) -> view_metrics_overview_loaded(model, overview)
  }
}

fn view_metrics_overview_loaded(
  model: Model,
  overview: api.OrgMetricsOverview,
) -> Element(Msg) {
  let api.OrgMetricsOverview(
    window_days: window_days,
    claimed_count: claimed_count,
    released_count: released_count,
    completed_count: completed_count,
    release_rate_percent: release_rate_percent,
    pool_flow_ratio_percent: pool_flow_ratio_percent,
    time_to_first_claim_p50_ms: time_to_first_claim_p50_ms,
    time_to_first_claim_sample_size: time_to_first_claim_sample_size,
    time_to_first_claim_buckets: time_to_first_claim_buckets,
    release_rate_buckets: release_rate_buckets,
    by_project: by_project,
  ) = overview

  div([attribute.class("panel")], [
    h2([], [text(update_helpers.i18n_t(model, i18n_text.MetricsOverview))]),
    p([], [text(update_helpers.i18n_t(model, i18n_text.WindowDays(window_days)))]),
    view_metrics_summary_table(
      model,
      claimed_count,
      released_count,
      completed_count,
      release_rate_percent,
      pool_flow_ratio_percent,
    ),
    view_metrics_time_to_first_claim(
      model,
      time_to_first_claim_p50_ms,
      time_to_first_claim_sample_size,
      time_to_first_claim_buckets,
    ),
    view_metrics_release_rate_buckets(model, release_rate_buckets),
    view_metrics_by_project_table(model, by_project),
  ])
}

fn view_metrics_summary_table(
  model: Model,
  claimed_count: Int,
  released_count: Int,
  completed_count: Int,
  release_rate_percent: opt.Option(Int),
  pool_flow_ratio_percent: opt.Option(Int),
) -> Element(Msg) {
  table([attribute.class("table")], [
    thead([], [
      tr([], [
        th([], [text(update_helpers.i18n_t(model, i18n_text.Claimed))]),
        th([], [text(update_helpers.i18n_t(model, i18n_text.Released))]),
        th([], [text(update_helpers.i18n_t(model, i18n_text.Completed))]),
        th([], [text(update_helpers.i18n_t(model, i18n_text.ReleasePercent))]),
        th([], [text(update_helpers.i18n_t(model, i18n_text.FlowPercent))]),
      ]),
    ]),
    tbody([], [
      tr([], [
        td([], [text(int.to_string(claimed_count))]),
        td([], [text(int.to_string(released_count))]),
        td([], [text(int.to_string(completed_count))]),
        td([], [text(option_percent_label(release_rate_percent))]),
        td([], [text(option_percent_label(pool_flow_ratio_percent))]),
      ]),
    ]),
  ])
}

fn view_metrics_time_to_first_claim(
  model: Model,
  p50_ms: opt.Option(Int),
  sample_size: Int,
  buckets: List(api.OrgMetricsBucket),
) -> Element(Msg) {
  div([], [
    h3([], [text(update_helpers.i18n_t(model, i18n_text.TimeToFirstClaim))]),
    p([], [
      text(update_helpers.i18n_t(
        model,
        i18n_text.TimeToFirstClaimP50(option_ms_label(p50_ms), sample_size),
      )),
    ]),
    div([attribute.class("buckets")], [view_metrics_bucket_table(model, buckets)]),
  ])
}

fn view_metrics_release_rate_buckets(
  model: Model,
  buckets: List(api.OrgMetricsBucket),
) -> Element(Msg) {
  div([], [
    h3([], [text(update_helpers.i18n_t(model, i18n_text.ReleaseRateDistribution))]),
    view_metrics_bucket_table(model, buckets),
  ])
}

fn view_metrics_bucket_table(
  model: Model,
  buckets: List(api.OrgMetricsBucket),
) -> Element(Msg) {
  table([attribute.class("table")], [
    thead([], [
      tr([], [
        th([], [text(update_helpers.i18n_t(model, i18n_text.Bucket))]),
        th([], [text(update_helpers.i18n_t(model, i18n_text.Count))]),
      ]),
    ]),
    tbody(
      [],
      list.map(buckets, fn(b) {
        let api.OrgMetricsBucket(bucket: bucket, count: count) = b
        tr([], [td([], [text(bucket)]), td([], [text(int.to_string(count))])])
      }),
    ),
  ])
}

fn view_metrics_by_project_table(
  model: Model,
  by_project: List(api.OrgMetricsProjectOverview),
) -> Element(Msg) {
  div([], [
    h3([], [text(update_helpers.i18n_t(model, i18n_text.ByProject))]),
    table([attribute.class("table")], [
      thead([], [
        tr([], [
          th([], [text(update_helpers.i18n_t(model, i18n_text.ProjectLabel))]),
          th([], [text(update_helpers.i18n_t(model, i18n_text.Claimed))]),
          th([], [text(update_helpers.i18n_t(model, i18n_text.Released))]),
          th([], [text(update_helpers.i18n_t(model, i18n_text.Completed))]),
          th([], [text(update_helpers.i18n_t(model, i18n_text.ReleasePercent))]),
          th([], [text(update_helpers.i18n_t(model, i18n_text.FlowPercent))]),
          th([], [text(update_helpers.i18n_t(model, i18n_text.Drill))]),
        ]),
      ]),
      tbody([], list.map(by_project, view_metrics_project_row(model, _))),
    ]),
  ])
}

fn view_metrics_project_row(
  model: Model,
  p: api.OrgMetricsProjectOverview,
) -> Element(Msg) {
  let api.OrgMetricsProjectOverview(
    project_id: project_id,
    project_name: project_name,
    claimed_count: claimed,
    released_count: released,
    completed_count: completed,
    release_rate_percent: rrp,
    pool_flow_ratio_percent: pfrp,
  ) = p

  tr([], [
    td([], [text(project_name)]),
    td([], [text(int.to_string(claimed))]),
    td([], [text(int.to_string(released))]),
    td([], [text(int.to_string(completed))]),
    td([], [text(option_percent_label(rrp))]),
    td([], [text(option_percent_label(pfrp))]),
    td([], [
      button(
        [
          attribute.class("btn-xs"),
          event.on_click(NavigateTo(
            router.Admin(permissions.Metrics, opt.Some(project_id)),
            Push,
          )),
        ],
        [text(update_helpers.i18n_t(model, i18n_text.View))],
      ),
    ]),
  ])
}

fn view_metrics_project_panel(
  model: Model,
  selected: opt.Option(api.Project),
) -> Element(Msg) {
  case selected {
    opt.None ->
      div([attribute.class("panel")], [
        h3([], [text(update_helpers.i18n_t(model, i18n_text.ProjectDrillDown))]),
        p([], [text(update_helpers.i18n_t(model, i18n_text.SelectProjectToInspectTasks))]),
      ])

    opt.Some(api.Project(name: project_name, ..)) ->
      view_metrics_project_tasks_panel(model, project_name)
  }
}

fn view_metrics_project_tasks_panel(
  model: Model,
  project_name: String,
) -> Element(Msg) {
  let body = case model.admin_metrics_project_tasks {
    NotAsked | Loading ->
      div([attribute.class("loading")], [
        text(update_helpers.i18n_t(model, i18n_text.LoadingTasks)),
      ])
    Failed(err) -> div([attribute.class("error")], [text(err.message)])
    Loaded(payload) -> view_metrics_project_tasks_table(model, payload)
  }

  div([attribute.class("panel")], [
    h3([], [text(update_helpers.i18n_t(model, i18n_text.ProjectTasks(project_name)))]),
    body,
  ])
}

fn view_metrics_project_tasks_table(
  model: Model,
  payload: api.OrgMetricsProjectTasksPayload,
) -> Element(Msg) {
  let api.OrgMetricsProjectTasksPayload(tasks: tasks, ..) = payload

  table([attribute.class("table")], [
    thead([], [
      tr([], [
        th([], [text(update_helpers.i18n_t(model, i18n_text.Title))]),
        th([], [text(update_helpers.i18n_t(model, i18n_text.Status))]),
        th([], [text(update_helpers.i18n_t(model, i18n_text.Claims))]),
        th([], [text(update_helpers.i18n_t(model, i18n_text.Releases))]),
        th([], [text(update_helpers.i18n_t(model, i18n_text.Completes))]),
        th([], [text(update_helpers.i18n_t(model, i18n_text.FirstClaim))]),
      ]),
    ]),
    tbody([], list.map(tasks, view_metrics_task_row)),
  ])
}

fn view_metrics_task_row(t: api.MetricsProjectTask) -> Element(Msg) {
  let api.MetricsProjectTask(
    task: api.Task(title: title, status: status, ..),
    claim_count: claim_count,
    release_count: release_count,
    complete_count: complete_count,
    first_claim_at: first_claim_at,
  ) = t

  tr([], [
    td([], [text(title)]),
    td([], [text(api.task_status_to_string(status))]),
    td([], [text(int.to_string(claim_count))]),
    td([], [text(int.to_string(release_count))]),
    td([], [text(int.to_string(complete_count))]),
    td([], [text(option_string_label(first_claim_at))]),
  ])
}

fn option_percent_label(value: opt.Option(Int)) -> String {
  case value {
    opt.Some(v) -> int.to_string(v) <> "%"
    opt.None -> "-"
  }
}

fn option_ms_label(value: opt.Option(Int)) -> String {
  case value {
    opt.Some(v) -> int.to_string(v) <> "ms"
    opt.None -> "-"
  }
}

fn option_string_label(value: opt.Option(String)) -> String {
  case value {
    opt.Some(v) -> v
    opt.None -> "-"
  }
}

fn view_org_settings(model: Model) -> Element(Msg) {
  div([attribute.class("section")], [
    p([], [text(update_helpers.i18n_t(model, i18n_text.OrgSettingsHelp))]),
    case model.org_settings_users {
      NotAsked ->
        div([], [text(update_helpers.i18n_t(model, i18n_text.OpenThisSectionToLoadUsers))])
      Loading ->
        div(
          [
            attribute.class("loading"),
          ],
          [text(update_helpers.i18n_t(model, i18n_text.LoadingUsers))],
        )

      Failed(err) -> div([attribute.class("error")], [text(err.message)])

      Loaded(users) -> {
        table([attribute.class("table")], [
          thead([], [
            tr([], [
              th([], [text(update_helpers.i18n_t(model, i18n_text.EmailLabel))]),
              th([], [text(update_helpers.i18n_t(model, i18n_text.Role))]),
              th([], [text(update_helpers.i18n_t(model, i18n_text.Actions))]),
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
                      option(
                        [attribute.value("admin")],
                        update_helpers.i18n_t(model, i18n_text.RoleAdmin),
                      ),
                      option(
                        [attribute.value("member")],
                        update_helpers.i18n_t(model, i18n_text.RoleMember),
                      ),
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
                    [text(update_helpers.i18n_t(model, i18n_text.Save))],
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
    True -> update_helpers.i18n_t(model, i18n_text.Working)
    False -> update_helpers.i18n_t(model, i18n_text.CreateInviteLink)
  }

  let origin = client_ffi.location_origin()

  div([attribute.class("section")], [
    p([], [text(update_helpers.i18n_t(model, i18n_text.InviteLinksHelp))]),
    case model.invite_link_error {
      opt.Some(err) -> div([attribute.class("error")], [text(err)])
      opt.None -> div([], [])
    },
    form([event.on_submit(fn(_) { InviteLinkCreateSubmitted })], [
      div([attribute.class("field")], [
        label([], [text(update_helpers.i18n_t(model, i18n_text.EmailLabel))]),
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
          h3([], [text(update_helpers.i18n_t(model, i18n_text.LatestInviteLink))]),
          div([attribute.class("field")], [
            label([], [text(update_helpers.i18n_t(model, i18n_text.EmailLabel))]),
            input([
              attribute.type_("text"),
              attribute.value(link.email),
              attribute.readonly(True),
            ]),
          ]),
          div([attribute.class("field")], [
            label([], [text(update_helpers.i18n_t(model, i18n_text.Link))]),
            input([
              attribute.type_("text"),
              attribute.value(full),
              attribute.readonly(True),
            ]),
          ]),
          button([event.on_click(InviteLinkCopyClicked(full))], [
            text(update_helpers.i18n_t(model, i18n_text.Copy)),
          ]),
          case model.invite_link_copy_status {
            opt.Some(status) -> div([attribute.class("hint")], [text(status)])
            opt.None -> div([], [])
          },
        ])
      }
    },
    hr([]),
    h3([], [text(update_helpers.i18n_t(model, i18n_text.InviteLinks))]),
    view_invite_links_list(model, origin),
  ])
}

fn view_invite_links_list(model: Model, origin: String) -> Element(Msg) {
  case model.invite_links {
    NotAsked | Loading ->
      div([attribute.class("empty")], [
        text(update_helpers.i18n_t(model, i18n_text.LoadingEllipsis)),
      ])

    Failed(err) ->
      div([attribute.class("error")], [
        text(
          update_helpers.i18n_t(model, i18n_text.FailedToLoadInviteLinksPrefix) <> err.message,
        ),
      ])

    Loaded(links) ->
      case links {
        [] ->
          div([attribute.class("empty")], [
            text(update_helpers.i18n_t(model, i18n_text.NoInviteLinksYet)),
          ])

        _ ->
          table([attribute.class("table")], [
            thead([], [
              tr([], [
                th([], [text(update_helpers.i18n_t(model, i18n_text.EmailLabel))]),
                th([], [text(update_helpers.i18n_t(model, i18n_text.State))]),
                th([], [text(update_helpers.i18n_t(model, i18n_text.CreatedAt))]),
                th([], [text(update_helpers.i18n_t(model, i18n_text.Link))]),
                th([], [text(update_helpers.i18n_t(model, i18n_text.Actions))]),
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
                      [text(update_helpers.i18n_t(model, i18n_text.Copy))],
                    ),
                    button(
                      [
                        attribute.disabled(model.invite_link_in_flight),
                        event.on_click(InviteLinkRegenerateClicked(link.email)),
                      ],
                      [text(update_helpers.i18n_t(model, i18n_text.Regenerate))],
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
    h2([], [text(update_helpers.i18n_t(model, i18n_text.Projects))]),
    view_projects_list(model, model.projects),
    hr([]),
    h3([], [text(update_helpers.i18n_t(model, i18n_text.CreateProject))]),
    case model.projects_create_error {
      opt.Some(err) -> div([attribute.class("error")], [text(err)])
      opt.None -> div([], [])
    },
    form([event.on_submit(fn(_) { ProjectCreateSubmitted })], [
      div([attribute.class("field")], [
        label([], [text(update_helpers.i18n_t(model, i18n_text.Name))]),
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
            True -> update_helpers.i18n_t(model, i18n_text.Creating)
            False -> update_helpers.i18n_t(model, i18n_text.Create)
          }),
        ],
      ),
    ]),
  ])
}

fn view_projects_list(
  model: Model,
  projects: Remote(List(api.Project)),
) -> Element(Msg) {
  case projects {
    NotAsked | Loading ->
      div([attribute.class("empty")], [
        text(update_helpers.i18n_t(model, i18n_text.LoadingEllipsis)),
      ])

    Failed(err) ->
      case err.status == 403 {
        True ->
          div(
            [
              attribute.class("not-permitted"),
            ],
            [text(update_helpers.i18n_t(model, i18n_text.NotPermitted))],
          )
        False -> div([attribute.class("error")], [text(err.message)])
      }

    Loaded(projects) ->
      case projects {
        [] ->
          div([attribute.class("empty")], [
            text(update_helpers.i18n_t(model, i18n_text.NoProjectsYet)),
          ])
        _ ->
          table([attribute.class("table")], [
            thead([], [
              tr([], [
                th([], [text(update_helpers.i18n_t(model, i18n_text.Name))]),
                th([], [text(update_helpers.i18n_t(model, i18n_text.MyRole))]),
              ]),
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
    h2([], [text(update_helpers.i18n_t(model, i18n_text.Capabilities))]),
    view_capabilities_list(model, model.capabilities),
    hr([]),
    h3([], [text(update_helpers.i18n_t(model, i18n_text.CreateCapability))]),
    case model.capabilities_create_error {
      opt.Some(err) -> div([attribute.class("error")], [text(err)])
      opt.None -> div([], [])
    },
    form([event.on_submit(fn(_) { CapabilityCreateSubmitted })], [
      div([attribute.class("field")], [
        label([], [text(update_helpers.i18n_t(model, i18n_text.Name))]),
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
            True -> update_helpers.i18n_t(model, i18n_text.Creating)
            False -> update_helpers.i18n_t(model, i18n_text.Create)
          }),
        ],
      ),
    ]),
  ])
}

fn view_capabilities_list(
  model: Model,
  capabilities: Remote(List(api.Capability)),
) -> Element(Msg) {
  case capabilities {
    NotAsked | Loading ->
      div([attribute.class("empty")], [
        text(update_helpers.i18n_t(model, i18n_text.LoadingEllipsis)),
      ])

    Failed(err) ->
      case err.status == 403 {
        True ->
          div(
            [
              attribute.class("not-permitted"),
            ],
            [text(update_helpers.i18n_t(model, i18n_text.NotPermitted))],
          )
        False -> div([attribute.class("error")], [text(err.message)])
      }

    Loaded(capabilities) ->
      case capabilities {
        [] ->
          div([attribute.class("empty")], [
            text(update_helpers.i18n_t(model, i18n_text.NoCapabilitiesYet)),
          ])
        _ ->
          table([attribute.class("table")], [
            thead([], [tr([], [th([], [text(update_helpers.i18n_t(model, i18n_text.Name))])])]),
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
        text(update_helpers.i18n_t(model, i18n_text.SelectProjectToManageMembers)),
      ])

    opt.Some(project) ->
      div([attribute.class("section")], [
        h2([], [text(update_helpers.i18n_t(model, i18n_text.MembersTitle(project.name)))]),
        button([event.on_click(MemberAddDialogOpened)], [
          text(update_helpers.i18n_t(model, i18n_text.AddMember)),
        ]),
        case model.members_remove_error {
          opt.Some(err) -> div([attribute.class("error")], [text(err)])
          opt.None -> div([], [])
        },
        view_members_table(model, model.members, model.org_users_cache),
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
  model: Model,
  members: Remote(List(api.ProjectMember)),
  cache: Remote(List(api.OrgUser)),
) -> Element(Msg) {
  case members {
    NotAsked | Loading ->
      div([attribute.class("empty")], [
        text(update_helpers.i18n_t(model, i18n_text.LoadingEllipsis)),
      ])

    Failed(err) ->
      case err.status == 403 {
        True ->
          div([attribute.class("not-permitted")], [
            text(update_helpers.i18n_t(model, i18n_text.NotPermitted)),
          ])
        False -> div([attribute.class("error")], [text(err.message)])
      }

    Loaded(members) ->
      case members {
        [] ->
          div([attribute.class("empty")], [
            text(update_helpers.i18n_t(model, i18n_text.NoMembersYet)),
          ])
        _ ->
          table([attribute.class("table")], [
            thead([], [
              tr([], [
                th([], [text(update_helpers.i18n_t(model, i18n_text.User))]),
                th([], [text(update_helpers.i18n_t(model, i18n_text.UserId))]),
                th([], [text(update_helpers.i18n_t(model, i18n_text.Role))]),
                th([], [text(update_helpers.i18n_t(model, i18n_text.CreatedAt))]),
                th([], [text(update_helpers.i18n_t(model, i18n_text.Actions))]),
              ]),
            ]),
            tbody(
              [],
              list.map(members, fn(m) {
                let email = case update_helpers.resolve_org_user(cache, m.user_id) {
                  opt.Some(user) -> user.email
                  opt.None -> update_helpers.i18n_t(model, i18n_text.UserNumber(m.user_id))
                }

                tr([], [
                  td([], [text(email)]),
                  td([], [text(int.to_string(m.user_id))]),
                  td([], [text(m.role)]),
                  td([], [text(m.created_at)]),
                  td([], [
                    button([event.on_click(MemberRemoveClicked(m.user_id))], [
                      text(update_helpers.i18n_t(model, i18n_text.Remove)),
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
      h3([], [text(update_helpers.i18n_t(model, i18n_text.AddMember))]),
      case model.members_add_error {
        opt.Some(err) -> div([attribute.class("error")], [text(err)])
        opt.None -> div([], [])
      },
      div([attribute.class("field")], [
        label([], [text(update_helpers.i18n_t(model, i18n_text.SearchByEmail))]),
        input([
          attribute.type_("text"),
          attribute.value(model.org_users_search_query),
          event.on_input(OrgUsersSearchChanged),
          event.debounce(event.on_input(OrgUsersSearchDebounced), 350),
          attribute.placeholder(update_helpers.i18n_t(model, i18n_text.EmailPlaceholderExample)),
        ]),
      ]),
      view_org_users_search_results(model, model.org_users_search_results),
      div([attribute.class("field")], [
        label([], [text(update_helpers.i18n_t(model, i18n_text.Role))]),
        select(
          [
            attribute.value(model.members_add_role),
            event.on_input(MemberAddRoleChanged),
          ],
          [
            option(
              [attribute.value("member")],
              update_helpers.i18n_t(model, i18n_text.RoleMember),
            ),
            option(
              [attribute.value("admin")],
              update_helpers.i18n_t(model, i18n_text.RoleAdmin),
            ),
          ],
        ),
      ]),
      div([attribute.class("actions")], [
        button([event.on_click(MemberAddDialogClosed)], [
          text(update_helpers.i18n_t(model, i18n_text.Cancel)),
        ]),
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
              True -> update_helpers.i18n_t(model, i18n_text.Working)
              False -> update_helpers.i18n_t(model, i18n_text.AddMember)
            }),
          ],
        ),
      ]),
    ]),
  ])
}

fn view_org_users_search_results(
  model: Model,
  results: Remote(List(api.OrgUser)),
) -> Element(Msg) {
  case results {
    NotAsked ->
      div([attribute.class("empty")], [
        text(update_helpers.i18n_t(model, i18n_text.TypeAnEmailToSearch)),
      ])

    Loading ->
      div([attribute.class("empty")], [text(update_helpers.i18n_t(model, i18n_text.Searching))])

    Failed(err) ->
      case err.status == 403 {
        True ->
          div(
            [
              attribute.class("not-permitted"),
            ],
            [text(update_helpers.i18n_t(model, i18n_text.NotPermitted))],
          )
        False -> div([attribute.class("error")], [text(err.message)])
      }

    Loaded(users) ->
      case users {
        [] ->
          div([attribute.class("empty")], [
            text(update_helpers.i18n_t(model, i18n_text.NoResults)),
          ])

        _ ->
          table([attribute.class("table")], [
            thead([], [
              tr([], [
                th([], [text(update_helpers.i18n_t(model, i18n_text.EmailLabel))]),
                th([], [text(update_helpers.i18n_t(model, i18n_text.OrgRole))]),
                th([], [text(update_helpers.i18n_t(model, i18n_text.Created))]),
                th([], [text(update_helpers.i18n_t(model, i18n_text.Select))]),
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
                      text(update_helpers.i18n_t(model, i18n_text.Select)),
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
      h3([], [text(update_helpers.i18n_t(model, i18n_text.RemoveMemberTitle))]),
      p([], [
        text(update_helpers.i18n_t(
          model,
          i18n_text.RemoveMemberConfirm(user.email, project_name),
        )),
      ]),
      case model.members_remove_error {
        opt.Some(err) -> div([attribute.class("error")], [text(err)])
        opt.None -> div([], [])
      },
      div([attribute.class("actions")], [
        button([event.on_click(MemberRemoveCancelled)], [
          text(update_helpers.i18n_t(model, i18n_text.Cancel)),
        ]),
        button(
          [
            event.on_click(MemberRemoveConfirmed),
            attribute.disabled(model.members_remove_in_flight),
          ],
          [
            text(case model.members_remove_in_flight {
              True -> update_helpers.i18n_t(model, i18n_text.Removing)
              False -> update_helpers.i18n_t(model, i18n_text.Remove)
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
        text(update_helpers.i18n_t(model, i18n_text.SelectProjectToManageTaskTypes)),
      ])

    opt.Some(project) ->
      div([attribute.class("section")], [
        h2([], [text(update_helpers.i18n_t(model, i18n_text.TaskTypesTitle(project.name)))]),
        view_task_types_list(model, model.task_types, model.theme),
        hr([]),
        h3([], [text(update_helpers.i18n_t(model, i18n_text.CreateTaskType))]),
        case model.task_types_create_error {
          opt.Some(err) -> div([attribute.class("error")], [text(err)])
          opt.None -> div([], [])
        },
        form([event.on_submit(fn(_) { TaskTypeCreateSubmitted })], [
          div([attribute.class("field")], [
            label([], [text(update_helpers.i18n_t(model, i18n_text.Name))]),
            input([
              attribute.type_("text"),
              attribute.value(model.task_types_create_name),
              event.on_input(TaskTypeCreateNameChanged),
              attribute.required(True),
            ]),
          ]),
          div([attribute.class("field")], [
            label([], [text(update_helpers.i18n_t(model, i18n_text.Icon))]),
            div([attribute.class("icon-row")], [
              input([
                attribute.type_("text"),
                attribute.value(model.task_types_create_icon),
                event.on_input(TaskTypeCreateIconChanged),
                attribute.required(True),
                attribute.placeholder(update_helpers.i18n_t(
                  model,
                  i18n_text.HeroiconSearchPlaceholder,
                )),
              ]),
              view_icon_preview(model.task_types_create_icon),
            ]),
            view_icon_picker(model.task_types_create_icon),
            case model.task_types_icon_preview {
              IconError ->
                div([attribute.class("error")], [
                  text(update_helpers.i18n_t(model, i18n_text.UnknownIcon)),
                ])
              _ -> div([], [])
            },
          ]),
          div([attribute.class("field")], [
            label([], [text(update_helpers.i18n_t(model, i18n_text.CapabilityOptional))]),
            view_capability_selector(
              model,
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
                True -> update_helpers.i18n_t(model, i18n_text.Creating)
                False -> update_helpers.i18n_t(model, i18n_text.Create)
              }),
            ],
          ),
        ]),
      ])
  }
}

fn heroicon_outline_url(name: String) -> String {
  "https://unpkg.com/heroicons@2.1.0/24/outline/" <> name <> ".svg"
}

fn view_heroicon_inline(
  name: String,
  size: Int,
  theme: theme.Theme,
) -> Element(Msg) {
  let url = heroicon_outline_url(name)

  let style = case theme {
    theme.Dark ->
      "vertical-align:middle; opacity:0.9; filter: invert(1) brightness(1.2);"
    theme.Default -> "vertical-align:middle; opacity:0.85;"
  }

  img([
    attribute.attribute("src", url),
    attribute.attribute("alt", name <> " icon"),
    attribute.attribute("width", int.to_string(size)),
    attribute.attribute("height", int.to_string(size)),
    attribute.attribute("style", style),
  ])
}

fn view_task_type_icon_inline(
  icon: String,
  size: Int,
  theme: theme.Theme,
) -> Element(Msg) {
  case string.contains(icon, "-") {
    True -> view_heroicon_inline(icon, size, theme)
    False ->
      span(
        [
          attribute.attribute(
            "style",
            "font-size:" <> int.to_string(size) <> "px;",
          ),
        ],
        [text(icon)],
      )
  }
}

fn view_icon_preview(icon_name: String) -> Element(Msg) {
  let name = string.trim(icon_name)

  case name == "" {
    True -> div([attribute.class("icon-preview")], [text("-")])

    False -> {
      let url = heroicon_outline_url(name)

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

fn view_icon_picker(current_icon: String) -> Element(Msg) {
  let current = string.trim(current_icon)

  let icons = [
    "bug-ant",
    "sparkles",
    "wrench-screwdriver",
    "clipboard-document-check",
    "light-bulb",
    "bolt",
    "beaker",
    "chat-bubble-left-right",
    "document-text",
    "flag",
    "exclamation-triangle",
    "check-circle",
    "arrow-path",
    "rocket-launch",
    "pencil-square",
    "cog-6-tooth",
  ]

  let has_current = current != "" && list.contains(icons, current)

  let options = [option([attribute.value("")], "Pick a common icon…")]

  let options = case current != "" && !has_current {
    True -> [
      option([attribute.value(current)], "Custom: " <> current),
      ..options
    ]
    False -> options
  }

  let options =
    list.append(
      options,
      list.map(icons, fn(name) { option([attribute.value(name)], name) }),
    )

  let selected = case current != "" && !has_current {
    True -> current
    False ->
      case has_current {
        True -> current
        False -> ""
      }
  }

  div([attribute.class("icon-picker")], [
    select(
      [
        attribute.value(selected),
        event.on_input(TaskTypeCreateIconChanged),
      ],
      options,
    ),
  ])
}

fn view_capability_selector(
  model: Model,
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
          option([attribute.value("")], update_helpers.i18n_t(model, i18n_text.NoneOption)),
          ..list.map(capabilities, fn(c) {
            option([attribute.value(int.to_string(c.id))], c.name)
          })
        ],
      )
    }

    _ ->
      div(
        [
          attribute.class("empty"),
        ],
        [text(update_helpers.i18n_t(model, i18n_text.LoadingCapabilities))],
      )
  }
}

fn view_task_types_list(
  model: Model,
  task_types: Remote(List(api.TaskType)),
  theme: theme.Theme,
) -> Element(Msg) {
  case task_types {
    NotAsked | Loading ->
      div([attribute.class("empty")], [
        text(update_helpers.i18n_t(model, i18n_text.LoadingEllipsis)),
      ])

    Failed(err) ->
      case err.status == 403 {
        True ->
          div(
            [
              attribute.class("not-permitted"),
            ],
            [text(update_helpers.i18n_t(model, i18n_text.NotPermitted))],
          )
        False -> div([attribute.class("error")], [text(err.message)])
      }

    Loaded(task_types) ->
      case task_types {
        [] ->
          div([attribute.class("empty")], [
            h2([], [text(update_helpers.i18n_t(model, i18n_text.NoTaskTypesYet))]),
            p([], [text(update_helpers.i18n_t(model, i18n_text.TaskTypesExplain))]),
            p([], [text(update_helpers.i18n_t(model, i18n_text.CreateFirstTaskTypeHint))]),
          ])
        _ ->
          table([attribute.class("table")], [
            thead([], [
              tr([], [
                th([], [text(update_helpers.i18n_t(model, i18n_text.Name))]),
                th([], [text(update_helpers.i18n_t(model, i18n_text.Icon))]),
                th([], [text(update_helpers.i18n_t(model, i18n_text.CapabilityLabel))]),
              ]),
            ]),
            tbody(
              [],
              list.map(task_types, fn(tt) {
                tr([], [
                  td([], [text(tt.name)]),
                  td([], [view_task_type_icon_inline(tt.icon, 20, theme)]),
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
            case model.member_section {
              member_section.Pool ->
                div(
                  [
                    attribute.class("body"),
                    event.on("mousemove", {
                      use x <- decode.field("clientX", decode.int)
                      use y <- decode.field("clientY", decode.int)
                      decode.success(MemberDragMoved(x, y))
                    }),
                    event.on("mouseup", decode.success(MemberDragEnded)),
                    // Safety: if leaving the pool layout while dragging, end drag.
                    event.on("mouseleave", decode.success(MemberDragEnded)),
                  ],
                  [
                    view_member_nav(model),
                    div([attribute.class("content pool-main")], [
                      view_member_pool_main(model, user),
                    ]),
                    div([attribute.class("pool-right")], [
                      view_pool_right_panel(model, user),
                    ]),
                  ],
                )

              _ ->
                div([], [
                  view_now_working_panel(model, user),
                  div([attribute.class("body")], [
                    view_member_nav(model),
                    div([attribute.class("content")], [
                      view_member_section(model, user),
                    ]),
                  ]),
                ])
            },
          ])
      }
  }
}

fn view_member_topbar(model: Model, user: User) -> Element(Msg) {
  div([attribute.class("topbar")], [
    div([attribute.class("topbar-title")], [
      text(
        update_helpers.i18n_t(model, case model.member_section {
          member_section.Pool -> i18n_text.Pool
          member_section.MyBar -> i18n_text.MyBar
          member_section.MySkills -> i18n_text.MySkills
        }),
      ),
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
            [text(update_helpers.i18n_t(model, i18n_text.Admin))],
          )
        _ -> div([], [])
      },
      view_theme_switch(model),
      span([attribute.class("user")], [text(user.email)]),
      button([event.on_click(LogoutClicked)], [
        text(update_helpers.i18n_t(model, i18n_text.Logout)),
      ]),
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
      div([attribute.class("now-working")], [
        text(update_helpers.i18n_t(model, i18n_text.NowWorkingLoading)),
      ])

    Failed(err) ->
      div([attribute.class("now-working")], [
        div([attribute.class("now-working-error")], [
          text(update_helpers.i18n_t(model, i18n_text.NowWorkingErrorPrefix) <> err.message),
        ]),
      ])

    NotAsked | Loaded(_) -> {
      let active = update_helpers.now_working_active_task(model)

      case active {
        opt.None ->
          div([attribute.class("now-working")], [
            div([attribute.class("now-working-empty")], [
              text(update_helpers.i18n_t(model, i18n_text.NowWorkingNone)),
            ]),
            error,
          ])

        opt.Some(api.ActiveTask(task_id: task_id, ..)) -> {
          let title = case update_helpers.find_task_by_id(model.member_tasks, task_id) {
            opt.Some(api.Task(title: title, ..)) -> title
            opt.None -> update_helpers.i18n_t(model, i18n_text.TaskNumber(task_id))
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
              [text(update_helpers.i18n_t(model, i18n_text.Pause))],
            )

          let task_actions = case update_helpers.find_task_by_id(model.member_tasks, task_id) {
            opt.Some(api.Task(version: version, ..)) -> [
              button(
                [
                  attribute.class("btn-xs"),
                  attribute.disabled(disable_actions),
                  event.on_click(MemberCompleteClicked(task_id, version)),
                ],
                [text(update_helpers.i18n_t(model, i18n_text.Complete))],
              ),
              button(
                [
                  attribute.class("btn-xs"),
                  attribute.disabled(disable_actions),
                  event.on_click(MemberReleaseClicked(task_id, version)),
                ],
                [text(update_helpers.i18n_t(model, i18n_text.Release))],
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

fn view_pool_right_panel(model: Model, user: User) -> Element(Msg) {
  let dropzone_class = case
    model.member_pool_drag_to_claim_armed,
    model.member_pool_drag_over_my_tasks
  {
    True, True -> "pool-my-tasks-dropzone drop-over"
    True, False -> "pool-my-tasks-dropzone drag-active"
    False, _ -> "pool-my-tasks-dropzone"
  }

  let claimed_tasks = case model.member_tasks {
    Loaded(tasks) ->
      tasks
      |> list.filter(fn(t) {
        let api.Task(status: status, claimed_by: claimed_by, ..) = t
        status == api.Claimed(api.Taken) && claimed_by == opt.Some(user.id)
      })
      |> list.sort(by: compare_member_bar_tasks)

    _ -> []
  }

  div([], [
    h3([], [text(update_helpers.i18n_t(model, i18n_text.NowWorking))]),
    view_now_working_panel(model, user),
    h3([], [text(update_helpers.i18n_t(model, i18n_text.MyTasks))]),
    // Drop-to-claim target (optional UX): we wrap the My Tasks area so we can
    // measure it and highlight it while dragging.
    div(
      [
        attribute.attribute("id", "pool-my-tasks"),
        attribute.class(dropzone_class),
      ],
      [
        case model.member_pool_drag_to_claim_armed {
          True ->
            div([attribute.class("dropzone-hint")], [
              text(
                update_helpers.i18n_t(model, i18n_text.Claim)
                <> ": "
                <> update_helpers.i18n_t(model, i18n_text.MyTasks),
              ),
            ])
          False -> div([], [])
        },
        case claimed_tasks {
          [] ->
            div([attribute.class("empty")], [
              text(update_helpers.i18n_t(model, i18n_text.NoClaimedTasks)),
            ])
          _ ->
            div(
              [attribute.class("task-list")],
              list.map(claimed_tasks, fn(t) {
                view_member_bar_task_row(model, user, t)
              }),
            )
        },
      ],
    ),
  ])
}

fn view_member_nav(model: Model) -> Element(Msg) {
  let items = case model.is_mobile {
    True -> [
      view_member_nav_button(model, member_section.MyBar, i18n_text.MyBar),
      view_member_nav_button(model, member_section.MySkills, i18n_text.MySkills),
    ]

    False -> [
      view_member_nav_button(model, member_section.Pool, i18n_text.Pool),
      view_member_nav_button(model, member_section.MyBar, i18n_text.MyBar),
      view_member_nav_button(model, member_section.MySkills, i18n_text.MySkills),
    ]
  }

  div([attribute.class("nav")], [
    h3([], [text(update_helpers.i18n_t(model, i18n_text.AppSectionTitle))]),
    div([], items),
  ])
}

fn view_member_nav_button(
  model: Model,
  section: member_section.MemberSection,
  label: i18n_text.Text,
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
    [text(update_helpers.i18n_t(model, label))],
  )
}

fn view_member_section(model: Model, user: User) -> Element(Msg) {
  case model.member_section {
    member_section.Pool -> view_member_pool_main(model, user)
    member_section.MyBar -> view_member_bar(model, user)
    member_section.MySkills -> view_member_skills(model)
  }
}

fn view_member_pool_main(model: Model, _user: User) -> Element(Msg) {
  case update_helpers.active_projects(model) {
    [] ->
      div([attribute.class("empty")], [
        h2([], [text(update_helpers.i18n_t(model, i18n_text.NoProjectsYet))]),
        p([], [text(update_helpers.i18n_t(model, i18n_text.NoProjectsBody))]),
      ])

    _ -> {
      let filters_toggle_label = case model.member_pool_filters_visible {
        True -> update_helpers.i18n_t(model, i18n_text.HideFilters)
        False -> update_helpers.i18n_t(model, i18n_text.ShowFilters)
      }

      let canvas_classes = case model.member_pool_view_mode {
        pool_prefs.Canvas -> "btn-xs btn-active"
        pool_prefs.List -> "btn-xs"
      }

      let list_classes = case model.member_pool_view_mode {
        pool_prefs.List -> "btn-xs btn-active"
        pool_prefs.Canvas -> "btn-xs"
      }

      div([attribute.class("section")], [
        div([attribute.class("actions")], [
          button(
            [
              attribute.class("btn-xs"),
              event.on_click(MemberPoolFiltersToggled),
            ],
            [text(filters_toggle_label)],
          ),
          button(
            [
              attribute.class(canvas_classes),
              attribute.attribute(
                "aria-label",
                update_helpers.i18n_t(model, i18n_text.ViewCanvas),
              ),
              event.on_click(MemberPoolViewModeSet(pool_prefs.Canvas)),
            ],
            [text(update_helpers.i18n_t(model, i18n_text.Canvas))],
          ),
          button(
            [
              attribute.class(list_classes),
              attribute.attribute(
                "aria-label",
                update_helpers.i18n_t(model, i18n_text.ViewList),
              ),
              event.on_click(MemberPoolViewModeSet(pool_prefs.List)),
            ],
            [text(update_helpers.i18n_t(model, i18n_text.List))],
          ),
          button(
            [
              attribute.class("btn-xs"),
              event.on_click(MemberCreateDialogOpened),
            ],
            [text(update_helpers.i18n_t(model, i18n_text.NewTaskShortcut))],
          ),
        ]),
        case model.member_pool_filters_visible {
          True -> view_member_filters(model)
          False -> div([], [])
        },
        view_member_tasks(model),
        case model.member_create_dialog_open {
          True -> view_member_create_dialog(model)
          False -> div([], [])
        },
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
}

fn view_member_filters(model: Model) -> Element(Msg) {
  let type_options = case model.member_task_types {
    Loaded(task_types) -> [
      option([attribute.value("")], update_helpers.i18n_t(model, i18n_text.AllOption)),
      ..list.map(task_types, fn(tt) {
        option([attribute.value(int.to_string(tt.id))], tt.name)
      })
    ]

    _ -> [option([attribute.value("")], update_helpers.i18n_t(model, i18n_text.AllOption))]
  }

  let capability_options = case model.capabilities {
    Loaded(caps) -> [
      option([attribute.value("")], update_helpers.i18n_t(model, i18n_text.AllOption)),
      ..list.map(caps, fn(c) {
        option([attribute.value(int.to_string(c.id))], c.name)
      })
    ]

    _ -> [option([attribute.value("")], update_helpers.i18n_t(model, i18n_text.AllOption))]
  }

  let my_caps_active = model.member_quick_my_caps

  let my_caps_class = case my_caps_active {
    True -> "btn-xs btn-icon"
    False -> "btn-xs btn-icon"
  }

  div([attribute.class("filters-row")], [
    div([attribute.class("field")], [
      span([attribute.class("filter-tooltip")], [
        text(update_helpers.i18n_t(model, i18n_text.TypeLabel)),
      ]),
      span(
        [
          attribute.class("filter-icon"),
          attribute.attribute("title", update_helpers.i18n_t(model, i18n_text.TypeLabel)),
          attribute.attribute("aria-hidden", "true"),
        ],
        [text("🏷")],
      ),
      label(
        [
          attribute.class("filter-label"),
          attribute.attribute("for", "pool-filter-type"),
        ],
        [text(update_helpers.i18n_t(model, i18n_text.TypeLabel))],
      ),
      select(
        [
          attribute.attribute("id", "pool-filter-type"),
          attribute.attribute("aria-label", update_helpers.i18n_t(model, i18n_text.TypeLabel)),
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
      span([attribute.class("filter-tooltip")], [
        text(update_helpers.i18n_t(model, i18n_text.CapabilityLabel)),
      ]),
      span(
        [
          attribute.class("filter-icon"),
          attribute.attribute("title", update_helpers.i18n_t(model, i18n_text.CapabilityLabel)),
          attribute.attribute("aria-hidden", "true"),
        ],
        [text("🎯")],
      ),
      label(
        [
          attribute.class("filter-label"),
          attribute.attribute("for", "pool-filter-capability"),
        ],
        [text(update_helpers.i18n_t(model, i18n_text.CapabilityLabel))],
      ),
      select(
        [
          attribute.attribute("id", "pool-filter-capability"),
          attribute.attribute(
            "aria-label",
            update_helpers.i18n_t(model, i18n_text.CapabilityLabel),
          ),
          attribute.value(model.member_filters_capability_id),
          event.on_input(MemberPoolCapabilityChanged),
        ],
        capability_options,
      ),
    ]),
    div([attribute.class("field")], [
      span([attribute.class("filter-tooltip")], [
        text(update_helpers.i18n_t(model, i18n_text.MyCapabilitiesLabel)),
      ]),
      span(
        [
          attribute.class("filter-icon"),
          attribute.attribute(
            "title",
            update_helpers.i18n_t(model, i18n_text.MyCapabilitiesLabel),
          ),
          attribute.attribute("aria-hidden", "true"),
        ],
        [text("★")],
      ),
      label([attribute.class("filter-label")], [
        text(update_helpers.i18n_t(model, i18n_text.MyCapabilitiesLabel)),
      ]),
      button(
        [
          attribute.class(my_caps_class),
          attribute.attribute(
            "title",
            update_helpers.i18n_t(model, i18n_text.MyCapabilitiesLabel),
          ),
          attribute.attribute(
            "aria-label",
            update_helpers.i18n_t(model, i18n_text.MyCapabilitiesLabel)
              <> ": "
              <> case my_caps_active {
              True -> update_helpers.i18n_t(model, i18n_text.MyCapabilitiesOn)
              False -> update_helpers.i18n_t(model, i18n_text.MyCapabilitiesOff)
            },
          ),
          event.on_click(MemberToggleMyCapabilitiesQuick),
        ],
        [
          text(case my_caps_active {
            True -> "★"
            False -> "☆"
          }),
        ],
      ),
    ]),

    div([attribute.class("field filter-q")], [
      span([attribute.class("filter-tooltip")], [
        text(update_helpers.i18n_t(model, i18n_text.SearchLabel)),
      ]),
      span(
        [
          attribute.class("filter-icon"),
          attribute.attribute("title", update_helpers.i18n_t(model, i18n_text.SearchLabel)),
          attribute.attribute("aria-hidden", "true"),
        ],
        [text("⌕")],
      ),
      label(
        [
          attribute.class("filter-label"),
          attribute.attribute("for", "pool-filter-q"),
        ],
        [text(update_helpers.i18n_t(model, i18n_text.SearchLabel))],
      ),
      input([
        attribute.attribute("id", "pool-filter-q"),
        attribute.attribute("aria-label", update_helpers.i18n_t(model, i18n_text.SearchLabel)),
        attribute.type_("text"),
        attribute.value(model.member_filters_q),
        event.on_input(MemberPoolSearchChanged),
        event.debounce(event.on_input(MemberPoolSearchDebounced), 350),
        attribute.placeholder(update_helpers.i18n_t(model, i18n_text.SearchPlaceholder)),
      ]),
    ]),
  ])
}

fn view_member_tasks(model: Model) -> Element(Msg) {
  case model.member_tasks {
    NotAsked | Loading ->
      div([attribute.class("empty")], [
        text(update_helpers.i18n_t(model, i18n_text.LoadingEllipsis)),
      ])
    Failed(err) -> div([attribute.class("error")], [text(err.message)])

    Loaded(tasks) -> {
      let available_tasks =
        tasks
        |> list.filter(fn(t) {
          let api.Task(status: status, ..) = t
          status == api.Available
        })

      case available_tasks {
        [] -> {
          let no_filters =
            string.trim(model.member_filters_type_id) == ""
            && string.trim(model.member_filters_capability_id) == ""
            && string.trim(model.member_filters_q) == ""

          case no_filters {
            True ->
              div([attribute.class("empty")], [
                h2([], [text(update_helpers.i18n_t(model, i18n_text.NoAvailableTasksRightNow))]),
                p([], [
                  text(update_helpers.i18n_t(model, i18n_text.CreateFirstTaskToStartUsingPool)),
                ]),
                button([event.on_click(MemberCreateDialogOpened)], [
                  text(update_helpers.i18n_t(model, i18n_text.NewTask)),
                ]),
              ])

            False ->
              div([attribute.class("empty")], [
                text(update_helpers.i18n_t(model, i18n_text.NoTasksMatchYourFilters)),
              ])
          }
        }

        _ -> {
          case model.member_pool_view_mode {
            pool_prefs.Canvas ->
              view_member_tasks_canvas(model, available_tasks)
            pool_prefs.List -> view_member_tasks_list(model, available_tasks)
          }
        }
      }
    }
  }
}

fn view_member_tasks_canvas(model: Model, tasks: List(api.Task)) -> Element(Msg) {
  div(
    [
      attribute.attribute("id", "member-canvas"),
      attribute.attribute(
        "style",
        "position: relative; min-height: 600px; touch-action: none;",
      ),
    ],
    list.map(tasks, fn(task) { view_member_task_card(model, task) }),
  )
}

fn view_member_tasks_list(model: Model, tasks: List(api.Task)) -> Element(Msg) {
  div(
    [attribute.class("task-list")],
    list.map(tasks, fn(task) { view_member_pool_task_row(model, task) }),
  )
}

fn view_member_pool_task_row(model: Model, task: api.Task) -> Element(Msg) {
  let api.Task(
    id: id,
    title: title,
    type_id: _type_id,
    task_type: task_type,
    priority: priority,
    created_at: created_at,
    version: version,
    ..,
  ) = task

  let type_label = task_type.name

  let type_icon = opt.Some(task_type.icon)

  let disable_actions = model.member_task_mutation_in_flight

  let claim_action =
    button(
      [
        attribute.class("btn-xs btn-icon"),
        attribute.attribute("title", update_helpers.i18n_t(model, i18n_text.Claim)),
        attribute.attribute("aria-label", update_helpers.i18n_t(model, i18n_text.Claim)),
        event.on_click(MemberClaimClicked(id, version)),
        attribute.disabled(disable_actions),
      ],
      [text("✋")],
    )

  div([attribute.class("task-row")], [
    div([], [
      div([attribute.class("task-row-title")], [text(title)]),
      div([attribute.class("task-row-meta")], [
        text(update_helpers.i18n_t(model, i18n_text.MetaType)),
        case type_icon {
          opt.Some(icon) ->
            span([attribute.attribute("style", "margin-right:4px;")], [
              view_task_type_icon_inline(icon, 16, model.theme),
            ])
        },
        text(type_label),
        text(" · "),
        text(update_helpers.i18n_t(model, i18n_text.MetaPriority)),
        text(int.to_string(priority)),
        text(" · "),
        text(update_helpers.i18n_t(model, i18n_text.MetaCreated)),
        text(created_at),
      ]),
    ]),
    div([attribute.class("task-row-actions")], [claim_action]),
  ])
}

fn view_member_task_card(model: Model, task: api.Task) -> Element(Msg) {
  let api.Task(
    id: id,
    type_id: _type_id,
    task_type: task_type,
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

  let type_label = task_type.name

  let type_icon = opt.Some(task_type.icon)

  let highlight = member_should_highlight_task(model, opt.Some(task_type))

  let #(x, y) = case dict.get(model.member_positions_by_task, id) {
    Ok(xy) -> xy
    Error(_) -> #(0, 0)
  }

  let size = member_visuals.priority_to_px(priority)

  let age_days = age_in_days(created_at)

  let #(opacity, saturation) = decay_to_visuals(age_days)

  let prefer_left =
    // Flip the tooltip left when the card is near the right edge of the viewport.
    // Heuristic: if there is less than ~420px to the right, flip.
    x > 760

  let card_classes = case highlight, prefer_left {
    True, True -> "task-card highlight preview-left"
    True, False -> "task-card highlight"
    False, True -> "task-card preview-left"
    False, False -> "task-card"
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
    <> "px; opacity:"
    <> float.to_string(opacity)
    <> "; filter:saturate("
    <> float.to_string(saturation)
    <> ");"

  let disable_actions = model.member_task_mutation_in_flight

  // Make the primary action visible even on tiny cards (the card size is
  // priority-driven and content is overflow-hidden).
  let primary_action = case status, is_mine {
    api.Available, _ ->
      button(
        [
          attribute.class("btn-xs btn-icon"),
          attribute.attribute("title", update_helpers.i18n_t(model, i18n_text.Claim)),
          attribute.attribute("aria-label", update_helpers.i18n_t(model, i18n_text.Claim)),
          event.on_click(MemberClaimClicked(id, version)),
          attribute.disabled(disable_actions),
        ],
        [text("✋")],
      )

    api.Claimed(_), True ->
      button(
        [
          attribute.class("btn-xs btn-icon"),
          attribute.attribute("title", update_helpers.i18n_t(model, i18n_text.Release)),
          attribute.attribute("aria-label", update_helpers.i18n_t(model, i18n_text.Release)),
          event.on_click(MemberReleaseClicked(id, version)),
          attribute.disabled(disable_actions),
        ],
        [text("⟲")],
      )

    _, _ -> div([], [])
  }

  let drag_handle =
    button(
      [
        attribute.class("btn-xs btn-icon secondary-action drag-handle"),
        attribute.attribute("title", update_helpers.i18n_t(model, i18n_text.Drag)),
        attribute.attribute("aria-label", update_helpers.i18n_t(model, i18n_text.Drag)),
        // Avoid accidental form submits if this ends up in a form.
        attribute.attribute("type", "button"),
        event.on("mousedown", {
          use ox <- decode.field("offsetX", decode.int)
          use oy <- decode.field("offsetY", decode.int)
          decode.success(MemberDragStarted(id, ox, oy))
        }),
      ],
      [text("⠿")],
    )

  let complete_action = case status, is_mine {
    api.Claimed(_), True ->
      button(
        [
          attribute.class("btn-xs btn-icon secondary-action"),
          attribute.attribute("title", update_helpers.i18n_t(model, i18n_text.Complete)),
          attribute.attribute("aria-label", update_helpers.i18n_t(model, i18n_text.Complete)),
          event.on_click(MemberCompleteClicked(id, version)),
          attribute.disabled(disable_actions),
        ],
        [text("☑")],
      )

    _, _ -> div([], [])
  }

  div(
    [
      attribute.class(card_classes),
      attribute.attribute("style", style),
      attribute.attribute(
        "aria-describedby",
        "task-preview-" <> int.to_string(id),
      ),
    ],
    [
      div([attribute.class("task-card-top")], [
        div([attribute.class("task-card-actions")], [
          primary_action,
          drag_handle,
          // Note: complete is only valid for claimed tasks; keep it secondary.
          complete_action,
        ]),
      ]),
      div([attribute.class("task-card-body")], [
        div([attribute.class("task-card-center")], [
          case type_icon {
            opt.Some(icon) ->
              div([attribute.class("task-card-center-icon")], [
                view_task_type_icon_inline(icon, 22, model.theme),
              ])
          },
          div(
            [
              attribute.class("task-card-title"),
              attribute.attribute("title", title),
            ],
            [text(title)],
          ),
        ]),
      ]),
      div(
        [
          attribute.class("task-card-preview"),
          attribute.attribute("id", "task-preview-" <> int.to_string(id)),
          attribute.attribute("role", "tooltip"),
        ],
        [
          div([attribute.class("task-preview-grid")], [
            span([attribute.class("task-preview-label")], [
              text(update_helpers.i18n_t(model, i18n_text.PopoverType)),
            ]),
            span([attribute.class("task-preview-value")], [text(type_label)]),
            span([attribute.class("task-preview-label")], [
              text(update_helpers.i18n_t(model, i18n_text.PopoverCreated)),
            ]),
            span([attribute.class("task-preview-value")], [
              text(update_helpers.i18n_t(model, i18n_text.CreatedAgoDays(age_days))),
            ]),
            span([attribute.class("task-preview-label")], [
              text(update_helpers.i18n_t(model, i18n_text.PopoverStatus)),
            ]),
            span([attribute.class("task-preview-value")], [
              span(
                [
                  attribute.class(
                    "task-preview-badge task-preview-badge-"
                    <> api.task_status_to_string(status),
                  ),
                ],
                [text(api.task_status_to_string(status))],
              ),
            ]),
          ]),
        ],
      ),
    ],
  )
}

fn view_member_create_dialog(model: Model) -> Element(Msg) {
  div([attribute.class("modal")], [
    div([attribute.class("modal-content")], [
      h3([], [text(update_helpers.i18n_t(model, i18n_text.NewTask))]),
      case model.member_create_error {
        opt.Some(err) -> div([attribute.class("error")], [text(err)])
        opt.None -> div([], [])
      },
      div([attribute.class("field")], [
        label([], [text(update_helpers.i18n_t(model, i18n_text.Title))]),
        input([
          attribute.type_("text"),
          attribute.attribute("maxlength", "56"),
          attribute.value(model.member_create_title),
          event.on_input(MemberCreateTitleChanged),
        ]),
      ]),
      div([attribute.class("field")], [
        label([], [text(update_helpers.i18n_t(model, i18n_text.Description))]),
        input([
          attribute.type_("text"),
          attribute.value(model.member_create_description),
          event.on_input(MemberCreateDescriptionChanged),
        ]),
      ]),
      div([attribute.class("field")], [
        label([], [text(update_helpers.i18n_t(model, i18n_text.Priority))]),
        input([
          attribute.type_("number"),
          attribute.value(model.member_create_priority),
          event.on_input(MemberCreatePriorityChanged),
        ]),
      ]),
      div([attribute.class("field")], [
        label([], [text(update_helpers.i18n_t(model, i18n_text.TypeLabel))]),
        select(
          [
            attribute.value(model.member_create_type_id),
            event.on_input(MemberCreateTypeIdChanged),
          ],
          case model.member_task_types {
            Loaded(task_types) -> [
              option([attribute.value("")], update_helpers.i18n_t(model, i18n_text.SelectType)),
              ..list.map(task_types, fn(tt) {
                option([attribute.value(int.to_string(tt.id))], tt.name)
              })
            ]
            _ -> [
              option(
                [attribute.value("")],
                update_helpers.i18n_t(model, i18n_text.LoadingEllipsis),
              ),
            ]
          },
        ),
      ]),
      div([attribute.class("actions")], [
        button([event.on_click(MemberCreateDialogClosed)], [
          text(update_helpers.i18n_t(model, i18n_text.Cancel)),
        ]),
        button(
          [
            event.on_click(MemberCreateSubmitted),
            attribute.disabled(model.member_create_in_flight),
          ],
          [
            text(case model.member_create_in_flight {
              True -> update_helpers.i18n_t(model, i18n_text.Creating)
              False -> update_helpers.i18n_t(model, i18n_text.Create)
            }),
          ],
        ),
      ]),
    ]),
  ])
}

fn member_bar_status_rank(status: api.TaskStatus) -> Int {
  case status {
    api.Claimed(api.Ongoing) -> 0
    api.Claimed(api.Taken) -> 1
    api.Available -> 2
    api.Completed -> 3
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

fn view_member_metrics_panel(model: Model) -> Element(Msg) {
  case model.member_metrics {
    NotAsked | Loading ->
      div([attribute.class("panel")], [
        h3([], [text(update_helpers.i18n_t(model, i18n_text.MyMetrics))]),
        div(
          [
            attribute.class("loading"),
          ],
          [text(update_helpers.i18n_t(model, i18n_text.LoadingMetrics))],
        ),
      ])

    Failed(err) ->
      div([attribute.class("panel")], [
        h3([], [text(update_helpers.i18n_t(model, i18n_text.MyMetrics))]),
        div([attribute.class("error")], [text(err.message)]),
      ])

    Loaded(metrics) -> {
      let api.MyMetrics(
        window_days: window_days,
        claimed_count: claimed_count,
        released_count: released_count,
        completed_count: completed_count,
      ) = metrics

      div([attribute.class("panel")], [
        h3([], [text(update_helpers.i18n_t(model, i18n_text.MyMetrics))]),
        p([], [text(update_helpers.i18n_t(model, i18n_text.WindowDays(window_days)))]),
        table([attribute.class("table")], [
          thead([], [
            tr([], [
              th([], [text(update_helpers.i18n_t(model, i18n_text.Claimed))]),
              th([], [text(update_helpers.i18n_t(model, i18n_text.Released))]),
              th([], [text(update_helpers.i18n_t(model, i18n_text.Completed))]),
            ]),
          ]),
          tbody([], [
            tr([], [
              td([], [text(int.to_string(claimed_count))]),
              td([], [text(int.to_string(released_count))]),
              td([], [text(int.to_string(completed_count))]),
            ]),
          ]),
        ]),
      ])
    }
  }
}

fn view_member_bar(model: Model, user: User) -> Element(Msg) {
  case update_helpers.active_projects(model) {
    [] ->
      div([attribute.class("empty")], [
        h2([], [text(update_helpers.i18n_t(model, i18n_text.NoProjectsYet))]),
        p([], [text(update_helpers.i18n_t(model, i18n_text.NoProjectsBody))]),
      ])

    _ ->
      case model.member_tasks {
        NotAsked | Loading ->
          div([attribute.class("empty")], [
            text(update_helpers.i18n_t(model, i18n_text.LoadingEllipsis)),
          ])

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
            view_member_metrics_panel(model),
            case mine {
              [] ->
                div([attribute.class("empty")], [
                  text(update_helpers.i18n_t(model, i18n_text.NoClaimedTasks)),
                ])

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
    type_id: _type_id,
    task_type: task_type,
    title: title,
    priority: priority,
    status: status,
    created_at: _created_at,
    version: version,
    claimed_by: claimed_by,
    ..,
  ) = task

  let is_mine = claimed_by == opt.Some(user.id)

  let type_label = task_type.name

  let type_icon = opt.Some(task_type.icon)

  let disable_actions =
    model.member_task_mutation_in_flight || model.member_now_working_in_flight

  let claim_action =
    button(
      [
        attribute.class("btn-xs btn-icon"),
        attribute.attribute("title", update_helpers.i18n_t(model, i18n_text.Claim)),
        attribute.attribute("aria-label", update_helpers.i18n_t(model, i18n_text.Claim)),
        event.on_click(MemberClaimClicked(id, version)),
        attribute.disabled(disable_actions),
      ],
      [text("✋")],
    )

  let release_action =
    button(
      [
        attribute.class("btn-xs btn-icon"),
        attribute.attribute("data-tooltip", update_helpers.i18n_t(model, i18n_text.Release)),
        attribute.attribute("title", update_helpers.i18n_t(model, i18n_text.Release)),
        attribute.attribute("aria-label", update_helpers.i18n_t(model, i18n_text.Release)),
        event.on_click(MemberReleaseClicked(id, version)),
        attribute.disabled(disable_actions),
      ],
      [text("⟲")],
    )

  let complete_action =
    button(
      [
        attribute.class("btn-xs btn-icon"),
        attribute.attribute("data-tooltip", update_helpers.i18n_t(model, i18n_text.Complete)),
        attribute.attribute("title", update_helpers.i18n_t(model, i18n_text.Complete)),
        attribute.attribute("aria-label", update_helpers.i18n_t(model, i18n_text.Complete)),
        event.on_click(MemberCompleteClicked(id, version)),
        attribute.disabled(disable_actions),
      ],
      [text("☑")],
    )

  let start_action =
    button(
      [
        attribute.class("btn-xs"),
        attribute.attribute("title", update_helpers.i18n_t(model, i18n_text.StartNowWorking)),
        attribute.attribute(
          "aria-label",
          update_helpers.i18n_t(model, i18n_text.StartNowWorking),
        ),
        event.on_click(MemberNowWorkingStartClicked(id)),
        attribute.disabled(disable_actions),
      ],
      [text(update_helpers.i18n_t(model, i18n_text.Start))],
    )

  let pause_action =
    button(
      [
        attribute.class("btn-xs"),
        attribute.attribute("title", update_helpers.i18n_t(model, i18n_text.PauseNowWorking)),
        attribute.attribute(
          "aria-label",
          update_helpers.i18n_t(model, i18n_text.PauseNowWorking),
        ),
        event.on_click(MemberNowWorkingPauseClicked),
        attribute.disabled(disable_actions),
      ],
      [text(update_helpers.i18n_t(model, i18n_text.Pause))],
    )

  let is_active = update_helpers.now_working_active_task_id(model) == opt.Some(id)

  let now_working_action = case is_active {
    True -> pause_action
    False -> start_action
  }

  let actions = case status, is_mine {
    api.Available, _ -> [claim_action]
    api.Claimed(_), True -> [
      now_working_action,
      release_action,
      complete_action,
    ]
    _, _ -> []
  }

  div([attribute.class("task-row")], [
    div([], [
      div([attribute.class("task-row-title")], [text(title)]),
      div([attribute.class("task-row-meta")], [
        text(update_helpers.i18n_t(model, i18n_text.PriorityShort(priority))),
        text(" · "),
        case type_icon {
          opt.Some(icon) ->
            span([attribute.attribute("style", "margin-right:4px;")], [
              view_task_type_icon_inline(icon, 16, model.theme),
            ])
        },
        text(type_label),
      ]),
    ]),
    div([attribute.class("task-row-actions")], actions),
  ])
}

fn view_member_skills(model: Model) -> Element(Msg) {
  div([attribute.class("section")], [
    h2([], [text(update_helpers.i18n_t(model, i18n_text.MySkills))]),
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
          True -> update_helpers.i18n_t(model, i18n_text.Saving)
          False -> update_helpers.i18n_t(model, i18n_text.Save)
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

    _ ->
      div(
        [
          attribute.class("empty"),
        ],
        [text(update_helpers.i18n_t(model, i18n_text.LoadingEllipsis))],
      )
  }
}

fn view_member_position_edit(model: Model, _task_id: Int) -> Element(Msg) {
  div([attribute.class("modal")], [
    div([attribute.class("modal-content")], [
      h3([], [text(update_helpers.i18n_t(model, i18n_text.EditPosition))]),
      case model.member_position_edit_error {
        opt.Some(err) -> div([attribute.class("error")], [text(err)])
        opt.None -> div([], [])
      },
      div([attribute.class("field")], [
        label([], [text(update_helpers.i18n_t(model, i18n_text.XLabel))]),
        input([
          attribute.type_("number"),
          attribute.value(model.member_position_edit_x),
          event.on_input(MemberPositionEditXChanged),
        ]),
      ]),
      div([attribute.class("field")], [
        label([], [text(update_helpers.i18n_t(model, i18n_text.YLabel))]),
        input([
          attribute.type_("number"),
          attribute.value(model.member_position_edit_y),
          event.on_input(MemberPositionEditYChanged),
        ]),
      ]),
      div([attribute.class("actions")], [
        button([event.on_click(MemberPositionEditClosed)], [
          text(update_helpers.i18n_t(model, i18n_text.Cancel)),
        ]),
        button(
          [
            event.on_click(MemberPositionEditSubmitted),
            attribute.disabled(model.member_position_edit_in_flight),
          ],
          [
            text(case model.member_position_edit_in_flight {
              True -> update_helpers.i18n_t(model, i18n_text.Saving)
              False -> update_helpers.i18n_t(model, i18n_text.Save)
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
      h3([], [text(update_helpers.i18n_t(model, i18n_text.Notes))]),
      button([event.on_click(MemberTaskDetailsClosed)], [
        text(update_helpers.i18n_t(model, i18n_text.Close)),
      ]),
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
        div([attribute.class("empty")], [
          text(update_helpers.i18n_t(model, i18n_text.LoadingEllipsis)),
        ])
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
              True -> update_helpers.i18n_t(model, i18n_text.You)
              False -> update_helpers.i18n_t(model, i18n_text.UserNumber(user_id))
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
      label([], [text(update_helpers.i18n_t(model, i18n_text.AddNote))]),
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
          True -> update_helpers.i18n_t(model, i18n_text.Adding)
          False -> update_helpers.i18n_t(model, i18n_text.Add)
        }),
      ],
    ),
  ])
}

fn member_refresh(model: Model) -> #(Model, Effect(Msg)) {
  case model.member_section {
    member_section.MySkills -> #(model, effect.none())

    _ -> {
      let projects = update_helpers.active_projects(model)

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

            member_section.Pool ->
              // Pool view must only *display* available tasks, but the right
              // panel needs access to claimed tasks too (Story 2.9). We fetch
              // without status filter and apply view-level guards.
              api.TaskFilters(
                status: opt.None,
                type_id: update_helpers.empty_to_int_opt(model.member_filters_type_id),
                capability_id: update_helpers.empty_to_int_opt(
                  model.member_filters_capability_id,
                ),
                q: update_helpers.empty_to_opt(model.member_filters_q),
              )

            _ ->
              api.TaskFilters(
                status: update_helpers.empty_to_opt(model.member_filters_status),
                type_id: update_helpers.empty_to_int_opt(model.member_filters_type_id),
                capability_id: update_helpers.empty_to_int_opt(
                  model.member_filters_capability_id,
                ),
                q: update_helpers.empty_to_opt(model.member_filters_q),
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
    401 -> #(
      Model(
        ..model,
        page: Login,
        user: opt.None,
        member_drag: opt.None,
        member_pool_drag_to_claim_armed: False,
        member_pool_drag_over_my_tasks: False,
      ),
      effect.none(),
    )
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

fn age_in_days(created_at: String) -> Int {
  client_ffi.days_since_iso(created_at)
}

fn decay_to_visuals(age_days: Int) -> #(Float, Float) {
  case age_days {
    d if d < 9 -> #(1.0, 1.0)
    d if d < 18 -> #(0.95, 0.85)
    d if d < 27 -> #(0.85, 0.65)
    _ -> #(0.8, 0.55)
  }
}

fn member_should_highlight_task(
  model: Model,
  _task_type: opt.Option(api.TaskTypeInline),
) -> Bool {
  case model.member_quick_my_caps {
    False -> False
    True ->
      // Capability highlighting depends on `task_type.capability_id`, which is
      // not present on the inline task type contract (id/name/icon).
      False
  }
}
