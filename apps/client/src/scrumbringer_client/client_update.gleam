//// Update function and helpers for Scrumbringer client.
////
//// ## Mission
////
//// Handle all state transitions for the Lustre SPA client.
////
//// ## Responsibilities
////
//// - Message dispatch and state transitions
//// - Effect management (API calls, navigation, timers)
//// - URL handling and routing
////
//// ## Non-responsibilities
////
//// - Type definitions (see `client_state.gleam`)
//// - View rendering (see `scrumbringer_client.gleam`)

import gleam/dict
import gleam/int
import gleam/list
import gleam/option as opt
import gleam/string

import lustre/effect.{type Effect}

import scrumbringer_domain/org_role

import scrumbringer_client/accept_invite
import scrumbringer_client/api
import scrumbringer_client/client_ffi
import scrumbringer_client/hydration
import scrumbringer_client/member_section
import scrumbringer_client/permissions
import scrumbringer_client/pool_prefs
import scrumbringer_client/reset_password
import scrumbringer_client/router
import scrumbringer_client/theme
import scrumbringer_client/update_helpers

import scrumbringer_client/i18n/text as i18n_text

import scrumbringer_client/client_state.{
  type Model, type Msg, type NavMode, type Remote,
  AcceptInvite as AcceptInvitePage, AcceptInviteMsg, Admin,
  AdminMetricsOverviewFetched, AdminMetricsProjectTasksFetched,
  CapabilitiesFetched, CapabilityCreateNameChanged, CapabilityCreateSubmitted,
  CapabilityCreated, Failed, ForgotPasswordClicked, ForgotPasswordCopyClicked,
  ForgotPasswordCopyFinished, ForgotPasswordDismissed,
  ForgotPasswordEmailChanged, ForgotPasswordFinished, ForgotPasswordSubmitted,
  GlobalKeyDown, IconError, IconIdle, IconLoading, IconOk, InviteLinkCopyClicked,
  InviteLinkCopyFinished, InviteLinkCreateSubmitted, InviteLinkCreated,
  InviteLinkEmailChanged, InviteLinkRegenerateClicked, InviteLinkRegenerated,
  InviteLinksFetched, Loaded, Loading, LocaleSelected, Login, LoginDomValuesRead,
  LoginEmailChanged, LoginFinished, LoginPasswordChanged, LoginSubmitted,
  LogoutClicked, LogoutFinished, MeFetched, Member, MemberActiveTaskFetched,
  MemberActiveTaskHeartbeated, MemberActiveTaskPaused, MemberActiveTaskStarted,
  MemberAddDialogClosed, MemberAddDialogOpened, MemberAddRoleChanged,
  MemberAddSubmitted, MemberAddUserSelected, MemberAdded,
  MemberCanvasRectFetched, MemberClaimClicked, MemberCompleteClicked,
  MemberCreateDescriptionChanged, MemberCreateDialogClosed,
  MemberCreateDialogOpened, MemberCreatePriorityChanged, MemberCreateSubmitted,
  MemberCreateTitleChanged, MemberCreateTypeIdChanged, MemberDrag,
  MemberDragEnded, MemberDragMoved, MemberDragStarted, MemberMetricsFetched,
  MemberMyCapabilityIdsFetched, MemberMyCapabilityIdsSaved, MemberNoteAdded,
  MemberNoteContentChanged, MemberNoteSubmitted, MemberNotesFetched,
  MemberNowWorkingPauseClicked, MemberNowWorkingStartClicked,
  MemberPoolCapabilityChanged, MemberPoolDragToClaimArmed,
  MemberPoolFiltersToggled, MemberPoolMyTasksRectFetched,
  MemberPoolSearchChanged, MemberPoolSearchDebounced, MemberPoolStatusChanged,
  MemberPoolTypeChanged, MemberPoolViewModeSet, MemberPositionEditClosed,
  MemberPositionEditOpened, MemberPositionEditSubmitted,
  MemberPositionEditXChanged, MemberPositionEditYChanged, MemberPositionSaved,
  MemberPositionsFetched, MemberProjectTasksFetched, MemberReleaseClicked,
  MemberRemoveCancelled, MemberRemoveClicked, MemberRemoveConfirmed,
  MemberRemoved, MemberSaveCapabilitiesClicked, MemberTaskClaimed,
  MemberTaskCompleted, MemberTaskCreated, MemberTaskDetailsClosed,
  MemberTaskDetailsOpened, MemberTaskReleased, MemberTaskTypesFetched,
  MemberToggleCapability, MemberToggleMyCapabilitiesQuick, MembersFetched, Model,
  NavigateTo, NotAsked, NowWorkingTicked, OrgSettingsRoleChanged,
  OrgSettingsSaveClicked, OrgSettingsSaved, OrgSettingsUsersFetched,
  OrgUsersCacheFetched, OrgUsersSearchChanged, OrgUsersSearchDebounced,
  OrgUsersSearchResults, ProjectCreateNameChanged, ProjectCreateSubmitted,
  ProjectCreated, ProjectSelected, ProjectsFetched, Push, Rect, Replace,
  ResetPassword as ResetPasswordPage, ResetPasswordMsg,
  TaskTypeCreateCapabilityChanged, TaskTypeCreateIconChanged,
  TaskTypeCreateNameChanged, TaskTypeCreateSubmitted, TaskTypeCreated,
  TaskTypeIconErrored, TaskTypeIconLoaded, TaskTypesFetched, ThemeSelected,
  ToastDismissed, UrlChanged, rect_contains_point,
}

import scrumbringer_client/i18n/locale as i18n_locale

// ---------------------------------------------------------------------------
// Routing helpers
// ---------------------------------------------------------------------------

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

pub fn accept_invite_effect(action: accept_invite.Action) -> Effect(Msg) {
  case action {
    accept_invite.ValidateToken(token) ->
      api.validate_invite_link_token(token, fn(result) {
        AcceptInviteMsg(accept_invite.TokenValidated(result))
      })

    _ -> effect.none()
  }
}

pub fn reset_password_effect(action: reset_password.Action) -> Effect(Msg) {
  case action {
    reset_password.ValidateToken(token) ->
      api.validate_password_reset_token(token, fn(result) {
        ResetPasswordMsg(reset_password.TokenValidated(result))
      })

    _ -> effect.none()
  }
}

pub fn register_popstate_effect() -> Effect(Msg) {
  effect.from(fn(dispatch) {
    client_ffi.register_popstate(fn(_) { dispatch(UrlChanged) })
  })
}

pub fn register_keydown_effect() -> Effect(Msg) {
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

pub fn write_url(mode: NavMode, route: router.Route) -> Effect(Msg) {
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

/// Hydrate model based on current route and resource states.
///
/// ## Size Justification (259 lines)
///
/// This function handles hydration commands for 12 resource types, each requiring:
/// - State validation (Loading/Loaded check)
/// - Project ID validation where applicable
/// - Model updates and effect batching
///
/// Splitting would fragment the hydration logic and make the command-to-effect
/// mapping harder to understand. The function is a single-purpose dispatcher
/// that processes hydration.Command variants sequentially.
///
/// ## Example
///
/// ```gleam
/// let #(model, effects) = hydrate_model(model)
/// ```
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

// ---------------------------------------------------------------------------
// Bootstrap and refresh helpers
// ---------------------------------------------------------------------------

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

/// Refresh member section data (tasks, types, positions, active task, metrics).
///
/// ## Size Justification (105 lines)
///
/// Coordinates 5 parallel data fetches with project ID filtering:
/// - Tasks by project (with pending counter)
/// - Task types by project (with pending counter)
/// - Task positions
/// - Active task state
/// - Member metrics
///
/// The batched fetching logic and state updates are tightly coupled
/// and splitting would complicate the refresh coordination.
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
              api.TaskFilters(
                status: opt.None,
                type_id: update_helpers.empty_to_int_opt(
                  model.member_filters_type_id,
                ),
                capability_id: update_helpers.empty_to_int_opt(
                  model.member_filters_capability_id,
                ),
                q: update_helpers.empty_to_opt(model.member_filters_q),
              )

            _ ->
              api.TaskFilters(
                status: update_helpers.empty_to_opt(model.member_filters_status),
                type_id: update_helpers.empty_to_int_opt(
                  model.member_filters_type_id,
                ),
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

// ---------------------------------------------------------------------------
// Main update function
// ---------------------------------------------------------------------------

/// Main Lustre update function - dispatches messages to handlers.
///
/// ## Size Justification (~2800 lines)
///
/// This function is the central message dispatcher for the Lustre/Elm architecture.
/// It handles 163 distinct Msg variants covering:
/// - Authentication flow (login, logout, password reset)
/// - Navigation and routing
/// - Admin sections (projects, capabilities, members, task types, metrics, org settings)
/// - Member sections (pool, tasks, notes, drag-and-drop, timer)
/// - API responses and error handling
/// - UI state (dialogs, filters, toasts, themes)
///
/// The large case expression is inherent to the Elm architecture pattern where
/// a single update function handles all application messages. Splitting would
/// require either:
/// 1. Breaking the Lustre contract (not possible)
/// 2. Adding dispatch indirection that increases complexity without benefit
///
/// Each case arm delegates to focused handler functions, keeping individual
/// logic units small and testable. The update function itself is a flat
/// dispatcher with minimal logic per branch.
///
/// ## Example
///
/// ```gleam
/// let #(new_model, effects) = update(model, LoginSubmit)
/// ```
pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
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
        Member -> Member

        Admin ->
          case user.org_role {
            org_role.Admin -> Admin
            _ -> Member
          }

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
              toast: opt.Some(update_helpers.i18n_t(
                model,
                i18n_text.PasswordUpdated,
              )),
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
          Model(
            ..model,
            toast: opt.Some(update_helpers.i18n_t(model, i18n_text.LogoutFailed)),
          ),
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
        update_helpers.ensure_selected_project(
          model.selected_project_id,
          projects,
        )
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
          toast: opt.Some(update_helpers.i18n_t(
            model,
            i18n_text.InviteLinkCreated,
          )),
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
          toast: opt.Some(update_helpers.i18n_t(
            model,
            i18n_text.InviteLinkRegenerated,
          )),
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
            invite_link_error: opt.Some(update_helpers.i18n_t(
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
            invite_link_error: opt.Some(update_helpers.i18n_t(
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
        invite_link_copy_status: opt.Some(update_helpers.i18n_t(
          model,
          i18n_text.Copying,
        )),
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
          toast: opt.Some(update_helpers.i18n_t(
            model,
            i18n_text.CapabilityCreated,
          )),
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
            members_add_error: opt.Some(update_helpers.i18n_t(
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
            members_add_in_flight: False,
            members_add_error: opt.Some(err.message),
          ),
          effect.none(),
        )
      }
    }

    MemberRemoveClicked(user_id) -> {
      let maybe_user =
        update_helpers.resolve_org_user(model.org_users_cache, user_id)

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
            members_remove_error: opt.Some(update_helpers.i18n_t(
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
          toast: opt.Some(update_helpers.i18n_t(
            model,
            i18n_text.TaskTypeCreated,
          )),
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
          Model(
            ..model,
            member_tasks: Loaded(update_helpers.flatten_tasks(tasks_by_project)),
          ),
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
            member_task_types: Loaded(update_helpers.flatten_task_types(
              task_types_by_project,
            )),
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
                                member_create_error: opt.Some(
                                  update_helpers.i18n_t(
                                    model,
                                    i18n_text.PriorityMustBe1To5,
                                  ),
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
          let ids =
            update_helpers.bool_dict_to_ids(model.member_my_capability_ids_edit)
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
      Model(
        ..model,
        member_positions_by_task: update_helpers.positions_to_dict(positions),
      ),
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
