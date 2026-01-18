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
////
//// ## Line Count Justification
////
//// ~2300 lines: Central TEA update hub that dispatches all Msg variants to
//// feature-specific update handlers. While large, this file acts as an
//// orchestration layer with clear delegation patterns:
//// - Each `case msg { ... }` branch delegates to `features/*/update.gleam`
//// - Splitting further would fragment the single entry point pattern
//// - Lustre's TEA model benefits from a unified `update` function
//// Future: Consider code generation for message dispatch if Msg variants
//// exceed 100.

import gleam/dict
import gleam/int
import gleam/list
import gleam/option as opt
import gleam/string

import lustre/effect.{type Effect}

import scrumbringer_domain/org_role

import scrumbringer_client/accept_invite
// API modules
import scrumbringer_client/api/auth as api_auth
import scrumbringer_client/api/projects as api_projects
import scrumbringer_client/api/tasks as api_tasks
import scrumbringer_client/api/org as api_org
import scrumbringer_client/api/metrics as api_metrics
// Domain types
import domain/task.{Task, TaskFilters, TaskPosition}
import domain/metrics.{OrgMetricsProjectTasksPayload}
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
  GlobalKeyDown, InviteLinkCopyClicked,
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

import scrumbringer_client/features/admin/update as admin_workflow
import scrumbringer_client/features/auth/update as auth_workflow
import scrumbringer_client/features/capabilities/update as capabilities_workflow
import scrumbringer_client/features/i18n/update as i18n_workflow
import scrumbringer_client/features/invites/update as invite_links_workflow
import scrumbringer_client/features/now_working/update as now_working_workflow
import scrumbringer_client/features/projects/update as projects_workflow
import scrumbringer_client/features/task_types/update as task_types_workflow
import scrumbringer_client/features/tasks/update as tasks_workflow

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
      api_auth.validate_invite_link_token(token, fn(result) {
        AcceptInviteMsg(accept_invite.TokenValidated(result))
      })

    _ -> effect.none()
  }
}

pub fn reset_password_effect(action: reset_password.Action) -> Effect(Msg) {
  case action {
    reset_password.ValidateToken(token) ->
      api_auth.validate_password_reset_token(token, fn(result) {
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
              #(m, [api_auth.fetch_me(MeFetched), ..fx])
            }

            hydration.FetchProjects -> {
              case m.projects {
                Loading | Loaded(_) -> #(m, fx)

                _ -> {
                  let m = Model(..m, projects: Loading)
                  #(m, [api_projects.list_projects(ProjectsFetched), ..fx])
                }
              }
            }

            hydration.FetchInviteLinks -> {
              case m.invite_links {
                Loading | Loaded(_) -> #(m, fx)

                _ -> {
                  let m = Model(..m, invite_links: Loading)
                  #(m, [api_org.list_invite_links(InviteLinksFetched), ..fx])
                }
              }
            }

            hydration.FetchCapabilities -> {
              case m.capabilities {
                Loading | Loaded(_) -> #(m, fx)

                _ -> {
                  let m = Model(..m, capabilities: Loading)
                  #(m, [api_org.list_capabilities(CapabilitiesFetched), ..fx])
                }
              }
            }

            hydration.FetchMeCapabilityIds -> {
              case m.member_my_capability_ids {
                Loading | Loaded(_) -> #(m, fx)

                _ -> {
                  let m = Model(..m, member_my_capability_ids: Loading)
                  #(m, [
                    api_tasks.get_me_capability_ids(MemberMyCapabilityIdsFetched),
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
                  #(m, [api_tasks.get_me_active_task(MemberActiveTaskFetched), ..fx])
                }
              }
            }

            hydration.FetchMeMetrics -> {
              case m.member_metrics {
                Loading | Loaded(_) -> #(m, fx)

                _ -> {
                  let m = Model(..m, member_metrics: Loading)
                  #(m, [api_metrics.get_me_metrics(30, MemberMetricsFetched), ..fx])
                }
              }
            }

            hydration.FetchOrgMetricsOverview -> {
              case m.admin_metrics_overview {
                Loading | Loaded(_) -> #(m, fx)

                _ -> {
                  let m = Model(..m, admin_metrics_overview: Loading)
                  #(m, [
                    api_metrics.get_org_metrics_overview(
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
                        api_metrics.get_org_metrics_project_tasks(
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

                  #(m, [api_org.list_org_users("", OrgSettingsUsersFetched), ..fx])
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
                        api_projects.list_project_members(project_id, MembersFetched)
                      let fx_users =
                        api_org.list_org_users("", OrgUsersCacheFetched)

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
                        api_tasks.list_task_types(project_id, TaskTypesFetched),
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
    api_projects.list_projects(ProjectsFetched),
    api_org.list_capabilities(CapabilitiesFetched),
    api_tasks.get_me_capability_ids(MemberMyCapabilityIdsFetched),
  ]

  let effects = case is_admin {
    True -> [api_org.list_invite_links(InviteLinksFetched), ..effects]
    False -> effects
  }

  #(model, effect.batch(effects))
}

fn refresh_section(model: Model) -> #(Model, Effect(Msg)) {
  case model.active_section {
    permissions.Invites -> {
      let model = Model(..model, invite_links: Loading)
      #(model, api_org.list_invite_links(InviteLinksFetched))
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

      #(model, api_org.list_org_users("", OrgSettingsUsersFetched))
    }

    permissions.Projects -> #(model, api_projects.list_projects(ProjectsFetched))

    permissions.Metrics -> {
      let model = Model(..model, admin_metrics_overview: Loading)

      let overview_fx =
        api_metrics.get_org_metrics_overview(30, AdminMetricsOverviewFetched)

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
            api_metrics.get_org_metrics_project_tasks(
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
      api_org.list_capabilities(CapabilitiesFetched),
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
              api_projects.list_project_members(project_id, MembersFetched),
              api_org.list_org_users("", OrgUsersCacheFetched),
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
          #(model, api_tasks.list_task_types(project_id, TaskTypesFetched))
        }
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
              TaskFilters(
                status: opt.Some("claimed"),
                type_id: opt.None,
                capability_id: opt.None,
                q: opt.None,
              )

            member_section.Pool ->
              TaskFilters(
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
              TaskFilters(
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
            api_tasks.list_me_task_positions(
              model.selected_project_id,
              MemberPositionsFetched,
            )

          let task_effects =
            list.map(project_ids, fn(project_id) {
              api_tasks.list_project_tasks(project_id, filters, fn(result) {
                MemberProjectTasksFetched(project_id, result)
              })
            })

          let task_type_effects =
            list.map(project_ids, fn(project_id) {
              api_tasks.list_task_types(project_id, fn(result) {
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
          api_auth.register_with_invite_link(token, password, fn(result) {
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
          api_auth.consume_password_reset_token(token, password, fn(result) {
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

    LoginEmailChanged(email) ->
      auth_workflow.handle_login_email_changed(model, email)
    LoginPasswordChanged(password) ->
      auth_workflow.handle_login_password_changed(model, password)
    LoginSubmitted -> auth_workflow.handle_login_submitted(model)
    LoginDomValuesRead(raw_email, raw_password) ->
      auth_workflow.handle_login_dom_values_read(model, raw_email, raw_password)
    LoginFinished(Ok(user)) ->
      auth_workflow.handle_login_finished_ok(
        model,
        user,
        bootstrap_admin,
        hydrate_model,
        replace_url,
      )
    LoginFinished(Error(err)) ->
      auth_workflow.handle_login_finished_error(model, err)

    ForgotPasswordClicked ->
      auth_workflow.handle_forgot_password_clicked(model)
    ForgotPasswordEmailChanged(email) ->
      auth_workflow.handle_forgot_password_email_changed(model, email)
    ForgotPasswordSubmitted ->
      auth_workflow.handle_forgot_password_submitted(model)
    ForgotPasswordFinished(Ok(reset)) ->
      auth_workflow.handle_forgot_password_finished_ok(model, reset)
    ForgotPasswordFinished(Error(err)) ->
      auth_workflow.handle_forgot_password_finished_error(model, err)
    ForgotPasswordCopyClicked ->
      auth_workflow.handle_forgot_password_copy_clicked(model)
    ForgotPasswordCopyFinished(ok) ->
      auth_workflow.handle_forgot_password_copy_finished(model, ok)
    ForgotPasswordDismissed ->
      auth_workflow.handle_forgot_password_dismissed(model)

    LogoutClicked -> auth_workflow.handle_logout_clicked(model)
    LogoutFinished(Ok(_)) ->
      auth_workflow.handle_logout_finished_ok(model, replace_url)
    LogoutFinished(Error(err)) ->
      auth_workflow.handle_logout_finished_error(model, err, replace_url)

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

    LocaleSelected(value) -> i18n_workflow.handle_locale_selected(model, value)

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
            True -> api_tasks.pause_me_active_task(MemberActiveTaskPaused)
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

    ProjectCreateNameChanged(name) ->
      projects_workflow.handle_project_create_name_changed(model, name)
    ProjectCreateSubmitted ->
      projects_workflow.handle_project_create_submitted(model)
    ProjectCreated(Ok(project)) ->
      projects_workflow.handle_project_created_ok(model, project)
    ProjectCreated(Error(err)) ->
      projects_workflow.handle_project_created_error(model, err)

    InviteLinkEmailChanged(value) ->
      invite_links_workflow.handle_invite_link_email_changed(model, value)
    InviteLinksFetched(Ok(links)) ->
      invite_links_workflow.handle_invite_links_fetched_ok(model, links)
    InviteLinksFetched(Error(err)) ->
      invite_links_workflow.handle_invite_links_fetched_error(model, err)
    InviteLinkCreateSubmitted ->
      invite_links_workflow.handle_invite_link_create_submitted(model)
    InviteLinkRegenerateClicked(email) ->
      invite_links_workflow.handle_invite_link_regenerate_clicked(model, email)
    InviteLinkCreated(Ok(link)) ->
      invite_links_workflow.handle_invite_link_created_ok(model, link)
    InviteLinkCreated(Error(err)) ->
      invite_links_workflow.handle_invite_link_created_error(model, err)
    InviteLinkRegenerated(Ok(link)) ->
      invite_links_workflow.handle_invite_link_regenerated_ok(model, link)
    InviteLinkRegenerated(Error(err)) ->
      invite_links_workflow.handle_invite_link_regenerated_error(model, err)
    InviteLinkCopyClicked(text) ->
      invite_links_workflow.handle_invite_link_copy_clicked(model, text)
    InviteLinkCopyFinished(ok) ->
      invite_links_workflow.handle_invite_link_copy_finished(model, ok)

    CapabilitiesFetched(Ok(capabilities)) ->
      capabilities_workflow.handle_capabilities_fetched_ok(model, capabilities)
    CapabilitiesFetched(Error(err)) ->
      capabilities_workflow.handle_capabilities_fetched_error(model, err)
    CapabilityCreateNameChanged(name) ->
      capabilities_workflow.handle_capability_create_name_changed(model, name)
    CapabilityCreateSubmitted ->
      capabilities_workflow.handle_capability_create_submitted(model)
    CapabilityCreated(Ok(capability)) ->
      capabilities_workflow.handle_capability_created_ok(model, capability)
    CapabilityCreated(Error(err)) ->
      capabilities_workflow.handle_capability_created_error(model, err)

    MembersFetched(Ok(members)) ->
      admin_workflow.handle_members_fetched_ok(model, members)
    MembersFetched(Error(err)) ->
      admin_workflow.handle_members_fetched_error(model, err)

    OrgUsersCacheFetched(Ok(users)) ->
      admin_workflow.handle_org_users_cache_fetched_ok(model, users)
    OrgUsersCacheFetched(Error(err)) ->
      admin_workflow.handle_org_users_cache_fetched_error(model, err)
    OrgSettingsUsersFetched(Ok(users)) ->
      admin_workflow.handle_org_settings_users_fetched_ok(model, users)

    OrgSettingsUsersFetched(Error(err)) ->
      admin_workflow.handle_org_settings_users_fetched_error(model, err)
    OrgSettingsRoleChanged(user_id, org_role) ->
      admin_workflow.handle_org_settings_role_changed(model, user_id, org_role)
    OrgSettingsSaveClicked(user_id) ->
      admin_workflow.handle_org_settings_save_clicked(model, user_id)
    OrgSettingsSaved(_user_id, Ok(updated)) ->
      admin_workflow.handle_org_settings_saved_ok(model, updated)
    OrgSettingsSaved(user_id, Error(err)) ->
      admin_workflow.handle_org_settings_saved_error(model, user_id, err)

    MemberAddDialogOpened ->
      admin_workflow.handle_member_add_dialog_opened(model)
    MemberAddDialogClosed ->
      admin_workflow.handle_member_add_dialog_closed(model)
    MemberAddRoleChanged(role) ->
      admin_workflow.handle_member_add_role_changed(model, role)
    MemberAddUserSelected(user_id) ->
      admin_workflow.handle_member_add_user_selected(model, user_id)
    MemberAddSubmitted ->
      admin_workflow.handle_member_add_submitted(model)
    MemberAdded(Ok(_)) ->
      admin_workflow.handle_member_added_ok(model, refresh_section)
    MemberAdded(Error(err)) ->
      admin_workflow.handle_member_added_error(model, err)

    MemberRemoveClicked(user_id) ->
      admin_workflow.handle_member_remove_clicked(model, user_id)
    MemberRemoveCancelled ->
      admin_workflow.handle_member_remove_cancelled(model)
    MemberRemoveConfirmed ->
      admin_workflow.handle_member_remove_confirmed(model)
    MemberRemoved(Ok(_)) ->
      admin_workflow.handle_member_removed_ok(model, refresh_section)
    MemberRemoved(Error(err)) ->
      admin_workflow.handle_member_removed_error(model, err)

    OrgUsersSearchChanged(query) ->
      admin_workflow.handle_org_users_search_changed(model, query)

    OrgUsersSearchDebounced(query) ->
      admin_workflow.handle_org_users_search_debounced(model, query)
    OrgUsersSearchResults(Ok(users)) ->
      admin_workflow.handle_org_users_search_results_ok(model, users)
    OrgUsersSearchResults(Error(err)) ->
      admin_workflow.handle_org_users_search_results_error(model, err)

    TaskTypesFetched(Ok(task_types)) ->
      task_types_workflow.handle_task_types_fetched_ok(model, task_types)
    TaskTypesFetched(Error(err)) ->
      task_types_workflow.handle_task_types_fetched_error(model, err)
    TaskTypeCreateNameChanged(name) ->
      task_types_workflow.handle_task_type_create_name_changed(model, name)
    TaskTypeCreateIconChanged(icon) ->
      task_types_workflow.handle_task_type_create_icon_changed(model, icon)
    TaskTypeIconLoaded -> task_types_workflow.handle_task_type_icon_loaded(model)
    TaskTypeIconErrored ->
      task_types_workflow.handle_task_type_icon_errored(model)
    TaskTypeCreateCapabilityChanged(value) ->
      task_types_workflow.handle_task_type_create_capability_changed(model, value)
    TaskTypeCreateSubmitted ->
      task_types_workflow.handle_task_type_create_submitted(model)
    TaskTypeCreated(Ok(_)) ->
      task_types_workflow.handle_task_type_created_ok(model, refresh_section)
    TaskTypeCreated(Error(err)) ->
      task_types_workflow.handle_task_type_created_error(model, err)

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
                opt.Some(Task(version: version, ..)) ->
                  case model.member_task_mutation_in_flight {
                    True -> #(model, effect.none())
                    False -> #(
                      Model(..model, member_task_mutation_in_flight: True),
                      api_tasks.claim_task(task_id, version, MemberTaskClaimed),
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
                api_tasks.upsert_me_task_position(task_id, x, y, MemberPositionSaved),
              )
            }
          }
        }
      }
    }

    MemberCreateDialogOpened ->
      tasks_workflow.handle_create_dialog_opened(model)
    MemberCreateDialogClosed ->
      tasks_workflow.handle_create_dialog_closed(model)
    MemberCreateTitleChanged(v) ->
      tasks_workflow.handle_create_title_changed(model, v)
    MemberCreateDescriptionChanged(v) ->
      tasks_workflow.handle_create_description_changed(model, v)
    MemberCreatePriorityChanged(v) ->
      tasks_workflow.handle_create_priority_changed(model, v)
    MemberCreateTypeIdChanged(v) ->
      tasks_workflow.handle_create_type_id_changed(model, v)

    MemberCreateSubmitted ->
      tasks_workflow.handle_create_submitted(model, member_refresh)

    MemberTaskCreated(Ok(_)) ->
      tasks_workflow.handle_task_created_ok(model, member_refresh)
    MemberTaskCreated(Error(err)) ->
      tasks_workflow.handle_task_created_error(model, err)

    MemberClaimClicked(task_id, version) ->
      tasks_workflow.handle_claim_clicked(model, task_id, version)
    MemberReleaseClicked(task_id, version) ->
      tasks_workflow.handle_release_clicked(model, task_id, version)
    MemberCompleteClicked(task_id, version) ->
      tasks_workflow.handle_complete_clicked(model, task_id, version)

    MemberTaskClaimed(Ok(_)) ->
      tasks_workflow.handle_task_claimed_ok(model, member_refresh)
    MemberTaskReleased(Ok(_)) ->
      tasks_workflow.handle_task_released_ok(model, member_refresh)
    MemberTaskCompleted(Ok(_)) ->
      tasks_workflow.handle_task_completed_ok(model, member_refresh)

    MemberTaskClaimed(Error(err)) ->
      tasks_workflow.handle_mutation_error(model, err, member_refresh)
    MemberTaskReleased(Error(err)) ->
      tasks_workflow.handle_mutation_error(model, err, member_refresh)
    MemberTaskCompleted(Error(err)) ->
      tasks_workflow.handle_mutation_error(model, err, member_refresh)

    MemberNowWorkingStartClicked(task_id) ->
      now_working_workflow.handle_start_clicked(model, task_id)
    MemberNowWorkingPauseClicked ->
      now_working_workflow.handle_pause_clicked(model)

    MemberActiveTaskFetched(Ok(payload)) ->
      now_working_workflow.handle_fetched_ok(model, payload)
    MemberActiveTaskFetched(Error(err)) ->
      now_working_workflow.handle_fetched_error(model, err)

    MemberActiveTaskStarted(Ok(payload)) ->
      now_working_workflow.handle_started_ok(model, payload)
    MemberActiveTaskStarted(Error(err)) ->
      now_working_workflow.handle_started_error(model, err)

    MemberActiveTaskPaused(Ok(payload)) ->
      now_working_workflow.handle_paused_ok(model, payload)
    MemberActiveTaskPaused(Error(err)) ->
      now_working_workflow.handle_paused_error(model, err)

    MemberActiveTaskHeartbeated(Ok(payload)) ->
      now_working_workflow.handle_heartbeated_ok(model, payload)
    MemberActiveTaskHeartbeated(Error(err)) ->
      now_working_workflow.handle_heartbeated_error(model, err)

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
      let OrgMetricsProjectTasksPayload(project_id: project_id, ..) =
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

    NowWorkingTicked -> now_working_workflow.handle_ticked(model)

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
          #(model, api_tasks.put_me_capability_ids(ids, MemberMyCapabilityIdsSaved))
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
          api_tasks.get_me_capability_ids(MemberMyCapabilityIdsFetched),
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
                    api_tasks.upsert_me_task_position(
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
      let TaskPosition(task_id: task_id, x: x, y: y, ..) = pos

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
          api_tasks.list_me_task_positions(
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
      api_tasks.list_task_notes(task_id, MemberNotesFetched),
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
                  #(model, api_tasks.add_task_note(task_id, content, MemberNoteAdded))
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
              api_tasks.list_task_notes(task_id, MemberNotesFetched),
            )
            opt.None -> #(model, effect.none())
          }
        }
      }
    }
  }
}
