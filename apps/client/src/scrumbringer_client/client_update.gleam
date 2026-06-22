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
//// ## Structure Note
////
//// Central TEA update hub with thin dispatch to feature handlers.
//// Admin/Pool subtrees are delegated to feature update modules
//// to keep this file focused on top-level orchestration.

import domain/api_error.{type ApiError, type ApiResult}
import domain/org_role
import domain/project.{type Project}
import domain/remote.{Failed, Loaded, Loading, NotAsked, should_fetch}
import domain/user.{type User}
import domain/view_mode
import gleam/dict
import gleam/int
import gleam/list
import gleam/option as opt
import gleam/uri.{type Uri}
import lustre/effect.{type Effect}

import scrumbringer_client/accept_invite
import scrumbringer_client/app/effects as app_effects
import scrumbringer_client/assignments_view_mode

// API modules
import scrumbringer_client/api/api_tokens as api_tokens_api
import scrumbringer_client/api/cards as api_cards
import scrumbringer_client/api/operational_metrics as api_metrics
import scrumbringer_client/api/org as api_org
import scrumbringer_client/api/projects as api_projects
import scrumbringer_client/api/tasks/active as active_api
import scrumbringer_client/api/tasks/capabilities as capabilities_api
import scrumbringer_client/api/tasks/operations as task_operations_api
import scrumbringer_client/api/tasks/positions as task_positions_api
import scrumbringer_client/api/tasks/task_types as task_types_api
import scrumbringer_client/api/workflows as api_workflows

// Domain types
import domain/task.{type TaskFilters, TaskFilters}
import scrumbringer_client/client_ffi
import scrumbringer_client/permissions
import scrumbringer_client/pool_prefs
import scrumbringer_client/reset_password
import scrumbringer_client/router
import scrumbringer_client/theme
import scrumbringer_client/token_flow
import scrumbringer_client/ui/toast
import scrumbringer_client/url_state

import scrumbringer_client/client_state
import scrumbringer_client/client_state/admin as admin_state
import scrumbringer_client/client_state/admin/api_tokens as admin_api_tokens
import scrumbringer_client/client_state/admin/assignments as assignments_state
import scrumbringer_client/client_state/admin/cards as admin_cards
import scrumbringer_client/client_state/admin/invites as admin_invites
import scrumbringer_client/client_state/admin/members as admin_members
import scrumbringer_client/client_state/admin/metrics as admin_metrics
import scrumbringer_client/client_state/admin/task_types as admin_task_types
import scrumbringer_client/client_state/admin/workflows as admin_workflows
import scrumbringer_client/client_state/auth as auth_state
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/client_state/ui as ui_state
import scrumbringer_client/features/hydration/update as hydration_workflow
import scrumbringer_client/features/plan/url as plan_url

import scrumbringer_client/client_state/selectors as state_selectors
import scrumbringer_client/features/admin/cards as admin_cards_workflow
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/features/admin/rule_metrics as rule_metrics_workflow
import scrumbringer_client/features/admin/task_templates as task_templates_workflow
import scrumbringer_client/features/admin/update as admin_workflow
import scrumbringer_client/features/auth/root_context as auth_context
import scrumbringer_client/features/auth/update as auth_workflow
import scrumbringer_client/features/i18n/update as i18n_workflow
import scrumbringer_client/features/layout/update as layout_workflow
import scrumbringer_client/features/pool/card_refresh
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/pool/update as pool_workflow
import scrumbringer_client/features/tasks/show_state as task_show_state
import scrumbringer_client/helpers/options as helpers_options
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/text as i18n_text

// ---------------------------------------------------------------------------
// Routing helpers
// ---------------------------------------------------------------------------

fn rule_metrics_context() -> rule_metrics_workflow.Context(client_state.Msg) {
  rule_metrics_workflow.Context(
    on_rule_metrics_fetched: fn(result) {
      client_state.pool_msg(pool_messages.AdminRuleMetricsFetched(result))
    },
    on_workflow_details_fetched: fn(result) {
      client_state.pool_msg(
        pool_messages.AdminRuleMetricsWorkflowDetailsFetched(result),
      )
    },
    on_rule_details_fetched: fn(result) {
      client_state.pool_msg(pool_messages.AdminRuleMetricsRuleDetailsFetched(
        result,
      ))
    },
    on_executions_fetched: fn(result) {
      client_state.pool_msg(pool_messages.AdminRuleMetricsExecutionsFetched(
        result,
      ))
    },
  )
}

fn admin_cards_context(
  model: client_state.Model,
) -> admin_cards_workflow.Context(client_state.Msg) {
  admin_cards_workflow.Context(
    selected_project_id: model.core.selected_project_id,
    on_cards_fetched: fn(result) {
      client_state.pool_msg(pool_messages.CardsFetched(result))
    },
  )
}

fn update_admin_cards(
  model: client_state.Model,
  f: fn(admin_cards.Model) -> admin_cards.Model,
) -> client_state.Model {
  client_state.update_admin(model, fn(admin) {
    let cards = admin.cards
    admin_state.AdminModel(..admin, cards: f(cards))
  })
}

fn fetch_cards_for_project(
  model: client_state.Model,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  let #(cards, fx) =
    admin_cards_workflow.fetch_cards_for_project(
      model.admin.cards,
      admin_cards_context(model),
    )

  #(update_admin_cards(model, fn(_) { cards }), fx)
}

fn handle_projects_fetched(
  model: client_state.Model,
  result: ApiResult(List(Project)),
) -> #(client_state.Model, Effect(client_state.Msg)) {
  case result {
    Ok(projects) -> handle_projects_fetched_ok(model, projects)
    Error(err) -> handle_projects_fetched_error(model, err)
  }
}

fn handle_projects_fetched_ok(
  model: client_state.Model,
  projects: List(Project),
) -> #(client_state.Model, Effect(client_state.Msg)) {
  let selected =
    state_selectors.ensure_selected_project(
      model.core.selected_project_id,
      projects,
    )
  let model =
    client_state.update_core(model, fn(core) {
      client_state.CoreModel(
        ..core,
        projects: Loaded(projects),
        selected_project_id: selected,
      )
    })
    |> state_selectors.ensure_default_section

  case model.core.page {
    client_state.Member -> {
      let #(model, fx) = member_refresh(model)
      let #(model, hyd_fx) = hydrate_model(model)
      #(model, effect.batch([fx, hyd_fx, replace_url(model)]))
    }

    client_state.Admin -> {
      let #(model, fx) = refresh_section_for_test(model)
      let #(model, hyd_fx) = hydrate_model(model)
      #(model, effect.batch([fx, hyd_fx, replace_url(model)]))
    }

    _ -> {
      let #(model, hyd_fx) = hydrate_model(model)
      #(model, effect.batch([hyd_fx, replace_url(model)]))
    }
  }
}

fn handle_projects_fetched_error(
  model: client_state.Model,
  err: ApiError,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  case err.status == 401 {
    True -> {
      let model =
        client_state.update_member(
          client_state.update_core(model, fn(core) {
            client_state.CoreModel(
              ..core,
              page: client_state.Login,
              user: opt.None,
            )
          }),
          member_state.reset_drag_state,
        )
      #(model, replace_url(model))
    }

    False -> #(
      client_state.update_core(model, fn(core) {
        client_state.CoreModel(..core, projects: Failed(err))
      }),
      effect.none(),
    )
  }
}

fn apply_admin_metrics_transition(
  model: client_state.Model,
  transition: fn(admin_metrics.Model) ->
    #(admin_metrics.Model, Effect(client_state.Msg)),
) -> #(client_state.Model, Effect(client_state.Msg)) {
  let #(metrics, fx) = transition(model.admin.metrics)
  let model =
    client_state.update_admin(model, fn(admin) {
      admin_state.AdminModel(..admin, metrics: metrics)
    })
  #(model, fx)
}

fn route_view_or_current(
  view: opt.Option(view_mode.ViewMode),
  current: view_mode.ViewMode,
) -> view_mode.ViewMode {
  case view {
    opt.None -> current
    opt.Some(next) -> next
  }
}

fn route_search_or_empty(search: opt.Option(String)) -> String {
  case search {
    opt.None -> ""
    opt.Some(value) -> value
  }
}

fn current_route(model: client_state.Model) -> router.Route {
  case model.core.page {
    client_state.Login -> router.Login

    client_state.AcceptInvite -> {
      let token_flow.Model(token: token, ..) = model.auth.accept_invite
      router.AcceptInvite(token)
    }

    client_state.ResetPassword -> {
      let token_flow.Model(token: token, ..) = model.auth.reset_password
      router.ResetPassword(token)
    }

    client_state.Admin ->
      case model.core.active_section {
        permissions.Invites
        | permissions.OrgSettings
        | permissions.Projects
        | permissions.Team
        | permissions.ApiTokens
        | permissions.Metrics -> router.Org(model.core.active_section)
        _ ->
          router.Config(
            model.core.active_section,
            model.core.selected_project_id,
          )
      }

    client_state.Member -> {
      let state = case model.core.selected_project_id {
        opt.Some(project_id) ->
          url_state.with_project(url_state.empty(), project_id)
        opt.None -> url_state.empty()
      }
      let state = url_state.with_view(state, model.member.pool.view_mode)
      let state = case model.member.pool.view_mode {
        view_mode.Cards ->
          url_state.with_plan_mode(
            state,
            plan_url.mode_to_url(model.member.pool.member_plan_mode),
          )
        _ -> state
      }
      let state =
        url_state.with_capability_scope(
          state,
          model.member.pool.member_capability_scope,
        )
      let state =
        url_state.with_type_filter(
          state,
          model.member.pool.member_filters_type_id,
        )
      let state =
        url_state.with_capability_filter(
          state,
          model.member.pool.member_filters_capability_id,
        )
      let state =
        url_state.with_search(
          state,
          helpers_options.empty_to_opt(model.member.pool.member_filters_q),
        )
      let state =
        url_state.with_card_depth(
          state,
          model.member.pool.member_card_depth_filter,
        )
      let state = case
        model.member.pool.member_plan_scope_kind,
        model.member.pool.member_plan_scope_card_id
      {
        member_pool.PlanScopeCard, opt.Some(card_id) ->
          url_state.with_card_work_scope(state, card_id)
        _, _ -> state
      }
      let state = case model.member.pool.card_show_open {
        opt.Some(card_id) -> url_state.with_card_show(state, card_id)
        opt.None ->
          case model.member.notes.member_notes_task_id {
            opt.Some(task_id) -> url_state.with_task_show(state, task_id)
            opt.None -> state
          }
      }
      router.Member(state)
    }
  }
}

pub fn toast_action_to_msg(action: toast.ToastActionKind) -> client_state.Msg {
  case action {
    toast.ClearPoolFilters ->
      client_state.pool_msg(pool_messages.MemberClearFilters)
    toast.ViewTask(task_id) ->
      client_state.pool_msg(pool_messages.MemberTaskShowOpened(task_id))
  }
}

fn replace_url(model: client_state.Model) -> Effect(client_state.Msg) {
  router.replace(current_route(model))
}

fn replace_url_and_title(model: client_state.Model) -> Effect(client_state.Msg) {
  let route = current_route(model)
  effect.batch([
    router.replace(route),
    router.update_page_title(route, model.ui.locale),
  ])
}

fn current_browser_uri() -> opt.Option(Uri) {
  let raw =
    client_ffi.location_pathname()
    <> client_ffi.location_search()
    <> client_ffi.location_hash()

  raw
  |> uri.parse
  |> opt.from_result
}

fn apply_authenticated_browser_route(
  model: client_state.Model,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  case current_browser_uri() {
    opt.None -> #(model, effect.none())
    opt.Some(uri) ->
      case router.parse_uri(uri) {
        router.Parsed(router.Member(_) as route)
        | router.Parsed(router.Config(_, _) as route)
        | router.Parsed(router.Org(_) as route) ->
          apply_route_fields(model, route)

        router.Redirect(router.Member(_) as route)
        | router.Redirect(router.Config(_, _) as route)
        | router.Redirect(router.Org(_) as route) -> {
          let #(model, route_fx) = apply_route_fields(model, route)
          #(
            model,
            effect.batch([write_url(client_state.Replace, route), route_fx]),
          )
        }

        _ -> #(model, effect.none())
      }
  }
}

/// Registers keydown effect.
///
/// Example:
///   register_keydown_effect(...)
pub fn register_keydown_effect() -> Effect(client_state.Msg) {
  effect.from(fn(dispatch) {
    client_ffi.register_keydown(fn(payload) {
      let #(key, ctrl, meta, shift, is_editing, modal_open) = payload
      dispatch(
        client_state.pool_msg(
          pool_messages.GlobalKeyDown(pool_prefs.KeyEvent(
            key,
            ctrl,
            meta,
            shift,
            is_editing,
            modal_open,
          )),
        ),
      )
    })
  })
}

/// Write URL to browser history using the appropriate navigation mode.
///
/// Delegates to `router.push` or `router.replace` based on mode.
pub fn write_url(
  mode: client_state.NavMode,
  route: router.Route,
) -> Effect(client_state.Msg) {
  case mode {
    client_state.Push -> router.push(route)
    client_state.Replace -> router.replace(route)
  }
}

fn apply_route_fields(
  model: client_state.Model,
  route: router.Route,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  case route {
    router.Login -> {
      let model =
        client_state.update_member(
          client_state.update_core(model, fn(core) {
            client_state.CoreModel(
              ..core,
              page: client_state.Login,
              selected_project_id: opt.None,
            )
          }),
          member_state.reset_drag_state,
        )
      #(model, effect.none())
    }

    router.AcceptInvite(token) -> {
      let #(new_accept_model, action) = accept_invite.init(token)
      let model =
        client_state.update_member(
          client_state.update_auth(
            client_state.update_core(model, fn(core) {
              client_state.CoreModel(
                ..core,
                page: client_state.AcceptInvite,
                selected_project_id: opt.None,
              )
            }),
            fn(auth) {
              auth_state.AuthModel(..auth, accept_invite: new_accept_model)
            },
          ),
          member_state.reset_drag_state,
        )

      #(
        model,
        auth_workflow.accept_invite_effect(
          action,
          auth_context.from_state(model),
        ),
      )
    }

    router.ResetPassword(token) -> {
      let #(new_reset_model, action) = reset_password.init(token)
      let model =
        client_state.update_member(
          client_state.update_auth(
            client_state.update_core(model, fn(core) {
              client_state.CoreModel(
                ..core,
                page: client_state.ResetPassword,
                selected_project_id: opt.None,
              )
            }),
            fn(auth) {
              auth_state.AuthModel(..auth, reset_password: new_reset_model)
            },
          ),
          member_state.reset_drag_state,
        )

      #(
        model,
        auth_workflow.reset_password_effect(
          action,
          auth_context.from_state(model),
        ),
      )
    }

    router.Config(section, project_id) -> {
      let model =
        client_state.update_member(
          client_state.update_core(model, fn(core) {
            client_state.CoreModel(
              ..core,
              page: client_state.Admin,
              active_section: section,
              selected_project_id: project_id,
            )
          }),
          member_state.reset_drag_state,
        )
      let #(model, fx) = refresh_section_for_test(model)
      #(model, fx)
    }

    router.Org(section) -> {
      let model =
        client_state.update_member(
          client_state.update_core(model, fn(core) {
            client_state.CoreModel(
              ..core,
              page: client_state.Admin,
              active_section: section,
              selected_project_id: opt.None,
            )
          }),
          member_state.reset_drag_state,
        )

      let model = case section {
        permissions.Team ->
          client_state.update_admin(model, fn(admin) {
            let assignments_state.AssignmentsModel(
              view_mode: _,
              search_input: search_input,
              search_query: search_query,
              project_members: project_members,
              user_projects: user_projects,
              expanded_projects: expanded_projects,
              expanded_users: expanded_users,
              inline_add_context: _,
              inline_add_selection: _,
              inline_add_search: _,
              inline_add_role: inline_add_role,
              inline_add_in_flight: _,
              inline_remove_confirm: _,
              role_change_in_flight: _,
              role_change_previous: _,
            ) = admin.assignments
            admin_state.AdminModel(
              ..admin,
              assignments: assignments_state.AssignmentsModel(
                view_mode: assignments_view_mode.ByProject,
                search_input: search_input,
                search_query: search_query,
                project_members: project_members,
                user_projects: user_projects,
                expanded_projects: expanded_projects,
                expanded_users: expanded_users,
                inline_add_context: opt.None,
                inline_add_selection: opt.None,
                inline_add_search: "",
                inline_add_role: inline_add_role,
                inline_add_in_flight: False,
                inline_remove_confirm: opt.None,
                role_change_in_flight: opt.None,
                role_change_previous: opt.None,
              ),
            )
          })
        _ -> model
      }
      let #(model, fx) = refresh_section_for_test(model)
      #(model, fx)
    }

    router.Member(state) -> {
      let project_id = url_state.project(state)
      let capabilities_fx = case model.core.page, project_id {
        client_state.Admin, opt.Some(pid) ->
          api_org.list_project_capabilities(pid, fn(result) {
            client_state.admin_msg(admin_messages.CapabilitiesFetched(result))
          })
        _, _ -> effect.none()
      }

      // Update view mode if provided in URL
      let new_view =
        route_view_or_current(
          url_state.view_param(state),
          model.member.pool.view_mode,
        )

      let next_model =
        client_state.update_member(
          client_state.update_core(model, fn(core) {
            client_state.CoreModel(
              ..core,
              page: client_state.Member,
              selected_project_id: project_id,
            )
          }),
          fn(member) {
            let member = member_state.reset_drag_state(member)
            let pool = member.pool
            member_state.MemberModel(
              ..member,
              pool: member_pool.Model(
                ..pool,
                view_mode: new_view,
                member_plan_mode: plan_url.mode_from_url(url_state.plan_mode(
                  state,
                )),
                member_card_depth_filter: url_state.card_depth(state),
                member_plan_scope_kind: case url_state.card_work_scope(state) {
                  opt.Some(_) -> member_pool.PlanScopeCard
                  opt.None -> pool.member_plan_scope_kind
                },
                member_plan_scope_card_id: url_state.card_work_scope(state),
                member_capability_scope: url_state.capability_scope(state),
                member_filters_type_id: url_state.type_filter(state),
                member_filters_capability_id: url_state.capability_filter(state),
                member_filters_q: route_search_or_empty(url_state.search(state)),
              ),
            )
          },
        )
      let show_fx = route_show_effect(next_model, url_state.show(state))
      #(next_model, effect.batch([capabilities_fx, show_fx]))
    }
  }
}

fn route_show_effect(
  model: client_state.Model,
  show: opt.Option(url_state.ShowParam),
) -> Effect(client_state.Msg) {
  case show {
    opt.Some(url_state.CardShowParam(card_id)) ->
      effect.from(fn(dispatch) {
        dispatch(client_state.pool_msg(pool_messages.OpenCardShow(card_id)))
        Nil
      })
    opt.Some(url_state.TaskShowParam(task_id)) ->
      effect.from(fn(dispatch) {
        dispatch(
          client_state.pool_msg(pool_messages.MemberTaskShowOpened(task_id)),
        )
        Nil
      })
    opt.None -> close_current_show_effect(model)
  }
}

fn close_current_show_effect(
  model: client_state.Model,
) -> Effect(client_state.Msg) {
  let card_fx = case model.member.pool.card_show_open {
    opt.Some(_) ->
      effect.from(fn(dispatch) {
        dispatch(client_state.pool_msg(pool_messages.CloseCardShow))
        Nil
      })
    opt.None -> effect.none()
  }
  let task_fx = case model.member.notes.member_notes_task_id {
    opt.Some(_) ->
      effect.from(fn(dispatch) {
        dispatch(client_state.pool_msg(pool_messages.MemberTaskShowClosed))
        Nil
      })
    opt.None -> effect.none()
  }

  effect.batch([card_fx, task_fx])
}

fn hydrate_model(
  model: client_state.Model,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  hydration_workflow.hydrate_model(
    model,
    hydration_workflow.Context(
      current_route: current_route,
      handle_navigate_to: handle_navigate_to,
      member_refresh: member_refresh,
    ),
  )
}

fn auth_toast_effect(
  message: String,
  variant: toast.ToastVariant,
) -> Effect(client_state.Msg) {
  effect.from(fn(dispatch) {
    dispatch(client_state.ToastShow(message, variant))
    Nil
  })
}

fn auth_page_for_org_role(role: org_role.OrgRole) -> client_state.Page {
  case role {
    org_role.Admin -> client_state.Admin
    _ -> client_state.Member
  }
}

fn show_toast(
  model: client_state.Model,
  message: String,
  variant: toast.ToastVariant,
  action: opt.Option(toast.ToastAction),
) -> #(client_state.Model, Effect(client_state.Msg)) {
  let now = client_ffi.now_ms()
  let next_state =
    toast.show_with_action(model.ui.toast_state, message, variant, action, now)
  let tick_effect =
    app_effects.schedule_timeout(toast.auto_dismiss_ms, fn() {
      client_state.ToastTick(client_ffi.now_ms())
    })

  #(
    client_state.update_ui(model, fn(ui) {
      ui_state.UiModel(..ui, toast_state: next_state)
    }),
    tick_effect,
  )
}

fn show_login_without_user(
  model: client_state.Model,
  auth_checked: Bool,
) -> client_state.Model {
  client_state.update_core(model, fn(core) {
    client_state.CoreModel(
      ..core,
      page: client_state.Login,
      user: opt.None,
      auth_checked: auth_checked,
    )
  })
}

fn finish_authenticated_session(
  model: client_state.Model,
  user: User,
  page: client_state.Page,
  local_fx: Effect(client_state.Msg),
  success_text: i18n_text.Text,
  bootstrap_fn: fn(client_state.Model) ->
    #(client_state.Model, Effect(client_state.Msg)),
  hydrate_fn: fn(client_state.Model) ->
    #(client_state.Model, Effect(client_state.Msg)),
  replace_url_fn: fn(client_state.Model) -> Effect(client_state.Msg),
) -> #(client_state.Model, Effect(client_state.Msg)) {
  let model =
    client_state.update_core(model, fn(core) {
      client_state.CoreModel(
        ..core,
        page: page,
        user: opt.Some(user),
        auth_checked: True,
      )
    })
  let #(model, boot) = bootstrap_fn(model)
  let #(model, hyd_fx) = hydrate_fn(model)
  #(
    model,
    effect.batch([
      local_fx,
      boot,
      hyd_fx,
      replace_url_fn(model),
      auth_toast_effect(i18n.t(model.ui.locale, success_text), toast.Success),
    ]),
  )
}

fn handle_auth_action(
  model: client_state.Model,
  action: auth_workflow.Action,
  local_fx: Effect(client_state.Msg),
  bootstrap_fn: fn(client_state.Model) ->
    #(client_state.Model, Effect(client_state.Msg)),
  hydrate_fn: fn(client_state.Model) ->
    #(client_state.Model, Effect(client_state.Msg)),
  replace_url_fn: fn(client_state.Model) -> Effect(client_state.Msg),
) -> #(client_state.Model, Effect(client_state.Msg)) {
  case action {
    auth_workflow.NoAction -> #(model, local_fx)

    auth_workflow.LoginSucceeded(user) ->
      finish_authenticated_session(
        model,
        user,
        client_state.Member,
        local_fx,
        i18n_text.LoggedIn,
        bootstrap_fn,
        hydrate_fn,
        replace_url_fn,
      )

    auth_workflow.LogoutSucceeded -> {
      let model = show_login_without_user(model, False)
      #(
        model,
        effect.batch([
          local_fx,
          replace_url_fn(model),
          auth_toast_effect(
            i18n.t(model.ui.locale, i18n_text.LoggedOut),
            toast.Success,
          ),
        ]),
      )
    }

    auth_workflow.LogoutUnauthorized -> {
      let model = show_login_without_user(model, False)
      #(model, effect.batch([local_fx, replace_url_fn(model)]))
    }

    auth_workflow.LogoutFailed -> #(
      model,
      effect.batch([
        local_fx,
        auth_toast_effect(
          i18n.t(model.ui.locale, i18n_text.LogoutFailed),
          toast.Error,
        ),
      ]),
    )

    auth_workflow.AcceptInviteAuthed(user) ->
      finish_authenticated_session(
        model,
        user,
        auth_page_for_org_role(user.org_role),
        local_fx,
        i18n_text.Welcome,
        bootstrap_fn,
        hydrate_fn,
        replace_url_fn,
      )

    auth_workflow.PasswordResetDone -> {
      let model =
        client_state.update_core(model, fn(core) {
          client_state.CoreModel(..core, page: client_state.Login)
        })
      #(
        model,
        effect.batch([
          local_fx,
          replace_url_fn(model),
          auth_toast_effect(
            i18n.t(model.ui.locale, i18n_text.PasswordUpdated),
            toast.Success,
          ),
        ]),
      )
    }
  }
}

fn handle_url_changed(
  model: client_state.Model,
  uri: Uri,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  let is_mobile = client_ffi.is_mobile()

  let model =
    client_state.update_ui(model, fn(ui) {
      ui_state.UiModel(..ui, is_mobile: is_mobile)
    })

  let parsed = router.parse_uri(uri)

  let route = case parsed {
    router.Parsed(route) -> route
    router.Redirect(route) -> route
  }

  let current = current_route(model)
  let title_fx = router.update_page_title(route, model.ui.locale)

  case parsed {
    router.Parsed(_) ->
      case route == current {
        True -> #(model, effect.none())

        False -> {
          let #(model, route_fx) = apply_route_fields(model, route)
          let model = apply_assignments_view_from_url(model, route, uri)
          let #(model, hyd_fx) = hydrate_model(model)
          #(model, effect.batch([route_fx, hyd_fx, title_fx]))
        }
      }

    router.Redirect(_) -> {
      let #(model, route_fx) = apply_route_fields(model, route)
      let model = apply_assignments_view_from_url(model, route, uri)
      let #(model, hyd_fx) = hydrate_model(model)
      #(
        model,
        effect.batch([
          write_url(client_state.Replace, route),
          route_fx,
          hyd_fx,
          title_fx,
        ]),
      )
    }
  }
}

fn apply_assignments_view_from_url(
  model: client_state.Model,
  route: router.Route,
  uri: Uri,
) -> client_state.Model {
  case route {
    router.Org(permissions.Team) ->
      case url_state.parse(uri, url_state.OrgAssignments) {
        url_state.Parsed(state) | url_state.Redirect(state) ->
          case url_state.assignments_view_param(state) {
            opt.Some(view_mode) ->
              client_state.update_admin(model, fn(admin) {
                let assignments_state.AssignmentsModel(
                  view_mode: _,
                  search_input: search_input,
                  search_query: search_query,
                  project_members: project_members,
                  user_projects: user_projects,
                  expanded_projects: expanded_projects,
                  expanded_users: expanded_users,
                  inline_add_context: inline_add_context,
                  inline_add_selection: inline_add_selection,
                  inline_add_search: inline_add_search,
                  inline_add_role: inline_add_role,
                  inline_add_in_flight: inline_add_in_flight,
                  inline_remove_confirm: inline_remove_confirm,
                  role_change_in_flight: role_change_in_flight,
                  role_change_previous: role_change_previous,
                ) = admin.assignments
                admin_state.AdminModel(
                  ..admin,
                  assignments: assignments_state.AssignmentsModel(
                    view_mode: view_mode,
                    search_input: search_input,
                    search_query: search_query,
                    project_members: project_members,
                    user_projects: user_projects,
                    expanded_projects: expanded_projects,
                    expanded_users: expanded_users,
                    inline_add_context: inline_add_context,
                    inline_add_selection: inline_add_selection,
                    inline_add_search: inline_add_search,
                    inline_add_role: inline_add_role,
                    inline_add_in_flight: inline_add_in_flight,
                    inline_remove_confirm: inline_remove_confirm,
                    role_change_in_flight: role_change_in_flight,
                    role_change_previous: role_change_previous,
                  ),
                )
              })
            opt.None -> model
          }
      }
    _ -> model
  }
}

fn handle_navigate_to(
  model: client_state.Model,
  route: router.Route,
  mode: client_state.NavMode,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  let #(next_route, next_mode) = #(route, mode)

  case next_route == current_route(model) {
    True -> #(model, effect.none())

    False -> {
      let model =
        client_state.update_ui(model, fn(ui) {
          ui_state.UiModel(..ui, mobile_drawer: ui_state.DrawerClosed)
        })
      let #(model, route_fx) = apply_route_fields(model, next_route)
      let #(model, hyd_fx) = hydrate_model(model)
      let title_fx = router.update_page_title(next_route, model.ui.locale)

      #(
        model,
        effect.batch([
          write_url(next_mode, next_route),
          route_fx,
          hyd_fx,
          title_fx,
        ]),
      )
    }
  }
}

// ---------------------------------------------------------------------------
// Bootstrap and refresh helpers
// ---------------------------------------------------------------------------

fn bootstrap_admin(
  model: client_state.Model,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  let is_admin = case model.core.user {
    opt.Some(user) -> user.org_role == org_role.Admin
    opt.None -> False
  }

  // Capabilities and member capability IDs are now project-scoped
  // They will be fetched when a project is selected
  let model =
    client_state.update_admin(
      client_state.update_core(model, fn(core) {
        client_state.CoreModel(..core, projects: Loading)
      }),
      fn(admin) {
        admin_state.AdminModel(
          ..admin,
          invites: admin_invites.Model(
            ..admin.invites,
            invite_links: case is_admin {
              True -> Loading
              False -> admin.invites.invite_links
            },
          ),
        )
      },
    )

  let effects = [
    api_projects.list_projects(fn(result) {
      client_state.admin_msg(admin_messages.ProjectsFetched(result))
    }),
  ]

  // Fetch capabilities if project is selected
  let effects = case model.core.selected_project_id {
    opt.Some(project_id) -> [
      api_org.list_project_capabilities(project_id, fn(result) {
        client_state.admin_msg(admin_messages.CapabilitiesFetched(result))
      }),
      ..effects
    ]
    opt.None -> effects
  }

  // Fetch member capability IDs if project and user are available
  let effects = case model.core.selected_project_id, model.core.user {
    opt.Some(project_id), opt.Some(user) -> [
      capabilities_api.get_member_capability_ids(
        project_id,
        user.id,
        fn(result) {
          client_state.pool_msg(pool_messages.MemberMyCapabilityIdsFetched(
            result,
          ))
        },
      ),
      ..effects
    ]
    _, _ -> effects
  }

  let effects = case is_admin {
    True -> [
      api_org.list_invite_links(fn(result) {
        client_state.admin_msg(admin_messages.InviteLinksFetched(result))
      }),
      ..effects
    ]
    False -> effects
  }

  #(model, effect.batch(effects))
}

/// Provides refresh section for test.
///
/// Example:
///   refresh_section_for_test(...)
pub fn refresh_section_for_test(
  model: client_state.Model,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  case model.core.active_section {
    permissions.Invites -> {
      let model =
        client_state.update_admin(model, fn(admin) {
          admin_state.AdminModel(
            ..admin,
            invites: admin_invites.Model(..admin.invites, invite_links: Loading),
          )
        })
      #(
        model,
        api_org.list_invite_links(fn(result) {
          client_state.admin_msg(admin_messages.InviteLinksFetched(result))
        }),
      )
    }

    permissions.OrgSettings -> {
      let model =
        client_state.update_admin(model, fn(admin) {
          let members = admin.members
          admin_state.AdminModel(
            ..admin,
            members: admin_members.Model(
              ..members,
              org_settings_users: Loading,
              org_settings_save_in_flight: False,
              org_settings_error: opt.None,
              org_settings_error_user_id: opt.None,
            ),
          )
        })

      #(
        model,
        api_org.list_org_users("", fn(result) {
          client_state.admin_msg(admin_messages.OrgSettingsUsersFetched(result))
        }),
      )
    }

    permissions.Projects -> #(
      model,
      api_projects.list_projects(fn(result) {
        client_state.admin_msg(admin_messages.ProjectsFetched(result))
      }),
    )

    permissions.Team -> {
      let #(model, fx) = refresh_assignments(model)
      #(model, fx)
    }

    permissions.ApiTokens -> {
      let model =
        client_state.update_admin(model, fn(admin) {
          let api_tokens = admin.api_tokens
          admin_state.AdminModel(
            ..admin,
            api_tokens: admin_api_tokens.ApiTokensModel(
              ..api_tokens,
              integration_users: Loading,
              tokens: Loading,
            ),
          )
        })

      #(
        model,
        effect.batch([
          api_tokens_api.list_integration_users(fn(result) {
            client_state.admin_msg(admin_messages.IntegrationUsersFetched(
              result,
            ))
          }),
          api_tokens_api.list_tokens(fn(result) {
            client_state.admin_msg(admin_messages.ApiTokensFetched(result))
          }),
        ]),
      )
    }

    permissions.Metrics -> {
      let model =
        client_state.update_admin(model, fn(admin) {
          let metrics = admin.metrics
          admin_state.AdminModel(
            ..admin,
            metrics: admin_metrics.Model(
              ..metrics,
              admin_metrics_overview: Loading,
            ),
          )
        })

      let overview_fx =
        api_metrics.get_org_metrics_overview(30, fn(result) {
          client_state.pool_msg(pool_messages.AdminMetricsOverviewFetched(
            result,
          ))
        })

      case model.core.selected_project_id {
        opt.None -> #(model, overview_fx)

        opt.Some(project_id) -> {
          let model =
            client_state.update_admin(model, fn(admin) {
              let metrics = admin.metrics
              admin_state.AdminModel(
                ..admin,
                metrics: admin_metrics.Model(
                  ..metrics,
                  admin_metrics_project_tasks: Loading,
                  admin_metrics_project_id: opt.Some(project_id),
                ),
              )
            })

          let tasks_fx =
            api_metrics.get_org_metrics_project_tasks(
              project_id,
              30,
              fn(result) {
                client_state.pool_msg(
                  pool_messages.AdminMetricsProjectTasksFetched(result),
                )
              },
            )

          with_right_panel_data(model, [overview_fx, tasks_fx])
        }
      }
    }

    permissions.RuleMetrics -> {
      let #(model, fx) =
        apply_admin_metrics_transition(model, fn(metrics) {
          rule_metrics_workflow.init_tab(metrics, rule_metrics_context())
        })
      with_right_panel_data(model, [fx])
    }

    permissions.Capabilities ->
      case model.core.selected_project_id {
        opt.Some(project_id) -> {
          with_right_panel_data(model, [
            api_org.list_project_capabilities(project_id, fn(result) {
              client_state.admin_msg(admin_messages.CapabilitiesFetched(result))
            }),
          ])
        }
        opt.None -> #(model, effect.none())
      }

    permissions.Members ->
      case model.core.selected_project_id {
        opt.None -> #(model, effect.none())
        opt.Some(project_id) -> {
          let model =
            client_state.update_admin(model, fn(admin) {
              let members = admin.members
              admin_state.AdminModel(
                ..admin,
                members: admin_members.Model(
                  ..members,
                  members: Loading,
                  members_project_id: opt.Some(project_id),
                  org_users_cache: Loading,
                ),
              )
            })
          with_right_panel_data(model, [
            api_projects.list_project_members(project_id, fn(result) {
              client_state.admin_msg(admin_messages.MembersFetched(result))
            }),
            api_org.list_org_users("", fn(result) {
              client_state.admin_msg(admin_messages.OrgUsersCacheFetched(result))
            }),
          ])
        }
      }

    permissions.TaskTypes ->
      case model.core.selected_project_id {
        opt.None -> #(model, effect.none())
        opt.Some(project_id) -> {
          let model =
            client_state.update_admin(model, fn(admin) {
              let task_types = admin.task_types
              admin_state.AdminModel(
                ..admin,
                task_types: admin_task_types.Model(
                  ..task_types,
                  task_types: Loading,
                  task_types_project_id: opt.Some(project_id),
                ),
              )
            })
          with_right_panel_data(model, [
            task_types_api.list_task_types(project_id, fn(result) {
              client_state.admin_msg(admin_messages.TaskTypesFetched(result))
            }),
          ])
        }
      }

    permissions.Cards -> {
      let #(model, fx) = fetch_cards_for_project(model)
      with_right_panel_data(model, [fx])
    }

    permissions.Workflows -> {
      let #(model, fx) = fetch_workflows(model)
      with_right_panel_data(model, [fx])
    }

    permissions.TaskTemplates -> {
      let #(model, fx) = task_templates_workflow.fetch_task_templates(model)
      // Also fetch task types for the template dialog type selector
      let task_types_fx = case
        model.core.selected_project_id,
        model.admin.task_types.task_types
      {
        opt.Some(project_id), NotAsked ->
          task_types_api.list_task_types(project_id, fn(result) {
            client_state.admin_msg(admin_messages.TaskTypesFetched(result))
          })
        opt.Some(project_id), Failed(_) ->
          task_types_api.list_task_types(project_id, fn(result) {
            client_state.admin_msg(admin_messages.TaskTypesFetched(result))
          })
        _, _ -> effect.none()
      }
      with_right_panel_data(model, [fx, task_types_fx])
    }
  }
}

fn refresh_assignments(
  model: client_state.Model,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  let #(model, projects_fx) = refresh_assignments_projects(model)
  let #(model, users_fx) = refresh_assignments_org_users(model)
  let #(model, members_fx) = refresh_assignments_project_members(model)
  let #(model, user_projects_fx) = refresh_assignments_user_projects(model)
  let #(model, metrics_fx) = refresh_assignments_metrics(model)
  let #(model, metrics_users_fx) = refresh_assignments_metrics_users(model)
  #(
    model,
    effect.batch([
      projects_fx,
      users_fx,
      members_fx,
      user_projects_fx,
      metrics_fx,
      metrics_users_fx,
    ]),
  )
}

fn refresh_assignments_metrics(
  model: client_state.Model,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  case should_fetch(model.admin.metrics.admin_metrics_overview) {
    False -> #(model, effect.none())
    True -> {
      let model =
        client_state.update_admin(model, fn(admin) {
          let metrics = admin.metrics
          admin_state.AdminModel(
            ..admin,
            metrics: admin_metrics.Model(
              ..metrics,
              admin_metrics_overview: Loading,
            ),
          )
        })
      let fx =
        api_metrics.get_org_metrics_overview(30, fn(result) {
          client_state.pool_msg(pool_messages.AdminMetricsOverviewFetched(
            result,
          ))
        })
      #(model, fx)
    }
  }
}

fn refresh_assignments_metrics_users(
  model: client_state.Model,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  case should_fetch(model.admin.metrics.admin_metrics_users) {
    False -> #(model, effect.none())
    True -> {
      let model =
        client_state.update_admin(model, fn(admin) {
          let metrics = admin.metrics
          admin_state.AdminModel(
            ..admin,
            metrics: admin_metrics.Model(
              ..metrics,
              admin_metrics_users: Loading,
            ),
          )
        })
      let fx =
        api_metrics.get_org_metrics_users(30, fn(result) {
          client_state.pool_msg(pool_messages.AdminMetricsUsersFetched(result))
        })
      #(model, fx)
    }
  }
}

fn refresh_assignments_projects(
  model: client_state.Model,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  case should_fetch(model.core.projects) {
    False -> #(model, effect.none())
    True -> {
      let model =
        client_state.update_core(model, fn(core) {
          client_state.CoreModel(..core, projects: Loading)
        })
      let fx =
        api_projects.list_projects(fn(result) {
          client_state.admin_msg(admin_messages.ProjectsFetched(result))
        })
      #(model, fx)
    }
  }
}

fn refresh_assignments_org_users(
  model: client_state.Model,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  case should_fetch(model.admin.members.org_users_cache) {
    False -> #(model, effect.none())
    True -> {
      let model =
        client_state.update_admin(model, fn(admin) {
          let members = admin.members
          admin_state.AdminModel(
            ..admin,
            members: admin_members.Model(..members, org_users_cache: Loading),
          )
        })
      let fx =
        api_org.list_org_users("", fn(result) {
          client_state.admin_msg(admin_messages.OrgUsersCacheFetched(result))
        })
      #(model, fx)
    }
  }
}

fn refresh_assignments_project_members(
  model: client_state.Model,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  let projects = state_selectors.active_projects(model)
  case projects {
    [] -> #(model, effect.none())
    _ -> {
      let assignments = model.admin.assignments

      let #(next_assignments, effects) =
        list.fold(projects, #(assignments, []), fn(state, project) {
          let #(current, fx) = state
          let assignments_state.AssignmentsModel(project_members: members, ..) =
            current
          let needs_fetch = case dict.get(members, project.id) {
            Ok(remote) -> should_fetch(remote)
            Error(_) -> True
          }
          case needs_fetch {
            False -> #(current, fx)
            True -> {
              let updated =
                assignments_state.AssignmentsModel(
                  ..current,
                  project_members: dict.insert(members, project.id, Loading),
                )
              let effect =
                api_projects.list_project_members(project.id, fn(result) {
                  client_state.admin_msg(
                    admin_messages.AssignmentsProjectMembersFetched(
                      project.id,
                      result,
                    ),
                  )
                })
              #(updated, [effect, ..fx])
            }
          }
        })

      let model =
        client_state.update_admin(model, fn(admin) {
          admin_state.AdminModel(..admin, assignments: next_assignments)
        })
      #(model, effect.batch(list.reverse(effects)))
    }
  }
}

fn refresh_assignments_user_projects(
  model: client_state.Model,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  case model.admin.members.org_users_cache {
    Loaded(users) -> {
      let assignments = model.admin.assignments

      let #(next_assignments, effects) =
        list.fold(users, #(assignments, []), fn(state, user) {
          let #(current, fx) = state
          let assignments_state.AssignmentsModel(user_projects: projects, ..) =
            current
          let needs_fetch = case dict.get(projects, user.id) {
            Ok(remote) -> should_fetch(remote)
            Error(_) -> True
          }
          case needs_fetch {
            False -> #(current, fx)
            True -> {
              let updated =
                assignments_state.AssignmentsModel(
                  ..current,
                  user_projects: dict.insert(projects, user.id, Loading),
                )
              let effect =
                api_org.list_user_projects(user.id, fn(result) {
                  client_state.admin_msg(
                    admin_messages.AssignmentsUserProjectsFetched(
                      user.id,
                      result,
                    ),
                  )
                })
              #(updated, [effect, ..fx])
            }
          }
        })

      let model =
        client_state.update_admin(model, fn(admin) {
          admin_state.AdminModel(..admin, assignments: next_assignments)
        })
      #(model, effect.batch(list.reverse(effects)))
    }
    _ -> #(model, effect.none())
  }
}

/// Fetches tasks and cards for the right panel in config views.
/// This ensures "My Tasks" and "My Cards" sections are populated
/// even when navigating directly to config routes.
/// Returns updated model (with pending counters) and list of effects.
fn fetch_right_panel_data(
  model: client_state.Model,
) -> #(client_state.Model, List(Effect(client_state.Msg))) {
  case model.core.selected_project_id {
    opt.None -> #(model, [])
    opt.Some(project_id) -> {
      // Fetch tasks with no filter to get all tasks
      let tasks_effect =
        task_operations_api.list_project_tasks(
          project_id,
          TaskFilters(
            status: opt.None,
            type_id: opt.None,
            capability_id: opt.None,
            q: opt.None,
            blocked: opt.None,
          ),
          fn(result) {
            client_state.pool_msg(pool_messages.MemberProjectTasksFetched(
              project_id,
              result,
            ))
          },
        )

      // Fetch cards for "My Cards" section
      let cards_effect =
        api_cards.list_cards(project_id, fn(result) {
          client_state.pool_msg(pool_messages.CardsFetched(result))
        })

      // Update model with pending counter and loading state
      let model =
        client_state.update_admin(
          client_state.update_member(model, fn(member) {
            let pool = member.pool
            member_state.MemberModel(
              ..member,
              pool: member_pool.Model(
                ..pool,
                member_tasks_pending: 1,
                member_tasks_by_project: dict.new(),
              ),
            )
          }),
          fn(admin) {
            let cards = admin.cards
            admin_state.AdminModel(
              ..admin,
              cards: admin_cards.Model(
                ..cards,
                cards: Loading,
                cards_project_id: opt.Some(project_id),
              ),
            )
          },
        )

      #(model, [tasks_effect, cards_effect])
    }
  }
}

fn with_right_panel_data(
  model: client_state.Model,
  effects: List(Effect(client_state.Msg)),
) -> #(client_state.Model, Effect(client_state.Msg)) {
  let #(model, right_panel_fx) = fetch_right_panel_data(model)
  #(model, effect.batch(list.append(effects, right_panel_fx)))
}

fn fetch_workflows(
  model: client_state.Model,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  case model.core.selected_project_id {
    opt.Some(project_id) -> {
      let model =
        client_state.update_admin(model, fn(admin) {
          admin_state.AdminModel(
            ..admin,
            workflows: admin_workflows.Model(
              ..admin.workflows,
              workflows_project: Loading,
            ),
          )
        })
      let fx =
        api_workflows.list_project_workflows(project_id, fn(result) {
          client_state.pool_msg(pool_messages.WorkflowsProjectFetched(result))
        })

      #(model, fx)
    }

    opt.None -> #(model, effect.none())
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
/// - client_state.Member metrics
///
/// The batched fetching logic and state updates are tightly coupled
/// and splitting would complicate the refresh coordination.
fn member_refresh(
  model: client_state.Model,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  refresh_member_tasks(model)
}

fn refresh_member_tasks(
  model: client_state.Model,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  let projects = state_selectors.active_projects(model)
  let project_ids = project_ids_for_member_refresh(model, projects)

  case project_ids {
    [] -> reset_member_tasks(model)
    _ -> refresh_member_data(model, project_ids)
  }
}

fn project_ids_for_member_refresh(
  model: client_state.Model,
  projects: List(Project),
) -> List(Int) {
  case model.core.selected_project_id {
    opt.Some(project_id) -> [project_id]
    opt.None -> projects |> list.map(fn(p) { p.id })
  }
}

fn reset_member_tasks(
  model: client_state.Model,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  #(
    client_state.update_member(model, fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_tasks: NotAsked,
          member_tasks_pending: 0,
          member_tasks_by_project: dict.new(),
          member_task_types: NotAsked,
          member_task_types_pending: 0,
          member_task_types_by_project: dict.new(),
          people_roster: NotAsked,
          people_expansions: dict.new(),
        ),
      )
    }),
    effect.none(),
  )
}

fn refresh_member_data(
  model: client_state.Model,
  project_ids: List(Int),
) -> #(client_state.Model, Effect(client_state.Msg)) {
  let filters = task_filters_for_member_route(model)

  let positions_effect =
    task_positions_api.list_me_task_positions(
      model.core.selected_project_id,
      fn(result) {
        client_state.pool_msg(pool_messages.MemberPositionsFetched(result))
      },
    )

  let task_effects =
    list.map(project_ids, fn(project_id) {
      task_operations_api.list_project_tasks(project_id, filters, fn(result) {
        client_state.pool_msg(pool_messages.MemberProjectTasksFetched(
          project_id,
          result,
        ))
      })
    })

  let task_type_effects =
    list.map(project_ids, fn(project_id) {
      task_types_api.list_task_types(project_id, fn(result) {
        client_state.pool_msg(pool_messages.MemberTaskTypesFetched(
          project_id,
          result,
        ))
      })
    })

  let member_card_effects =
    list.map(project_ids, fn(project_id) {
      api_cards.list_cards(project_id, fn(result) {
        client_state.pool_msg(pool_messages.MemberProjectCardsFetched(
          project_id,
          result,
        ))
      })
    })

  let roster_project_id = case model.core.selected_project_id, project_ids {
    opt.Some(project_id), _ -> opt.Some(project_id)
    opt.None, [project_id, ..] -> opt.Some(project_id)
    opt.None, [] -> opt.None
  }

  let roster_effect = case roster_project_id {
    opt.Some(project_id) ->
      api_projects.list_project_members(project_id, fn(result) {
        client_state.pool_msg(pool_messages.MemberPeopleRosterFetched(result))
      })
    opt.None -> effect.none()
  }

  let should_fetch_org_users = should_fetch(model.admin.members.org_users_cache)

  let org_users_effect = case should_fetch_org_users {
    True ->
      api_org.list_org_users("", fn(result) {
        client_state.admin_msg(admin_messages.OrgUsersCacheFetched(result))
      })
    False -> effect.none()
  }

  let effects =
    list.append(
      task_effects,
      list.append(
        task_type_effects,
        list.append(
          [positions_effect, roster_effect, org_users_effect],
          member_card_effects,
        ),
      ),
    )

  let next =
    client_state.update_member(model, fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_tasks: Loading,
          member_tasks_pending: list.length(project_ids),
          member_tasks_by_project: dict.new(),
          member_task_types: Loading,
          member_task_types_pending: list.length(project_ids),
          member_task_types_by_project: dict.new(),
          people_roster: case roster_project_id {
            opt.Some(_) -> Loading
            opt.None -> NotAsked
          },
          people_expansions: case roster_project_id {
            opt.Some(_) -> pool.people_expansions
            opt.None -> dict.new()
          },
          member_cards_store: card_refresh.mark_pending(
            pool.member_cards_store,
            list.length(project_ids),
          ),
          member_cards: card_refresh.loading_unless_loaded(pool.member_cards),
        ),
      )
    })

  let next = case should_fetch_org_users {
    False -> next
    True ->
      client_state.update_admin(next, fn(admin) {
        let members = admin.members
        admin_state.AdminModel(
          ..admin,
          members: admin_members.Model(..members, org_users_cache: Loading),
        )
      })
  }

  #(next, effect.batch(effects))
}

// cards_effects_for_refresh removed from member refresh to avoid admin coupling.

fn task_filters_for_member_route(model: client_state.Model) -> TaskFilters {
  TaskFilters(
    status: opt.None,
    type_id: model.member.pool.member_filters_type_id,
    capability_id: model.member.pool.member_filters_capability_id,
    q: helpers_options.empty_to_opt(model.member.pool.member_filters_q),
    blocked: opt.None,
  )
}

/// Provides should pause active task on project change.
///
/// Example:
///   should_pause_active_task_on_project_change(...)
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
/// It handles 163 distinct client_state.Msg variants covering:
/// - Authentication flow (login, logout, password reset)
/// - Navigation and routing
/// - client_state.Admin sections (projects, capabilities, members, task types, metrics, org settings)
/// - client_state.Member sections (pool, tasks, notes, drag-and-drop, timer)
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
pub fn update(
  model: client_state.Model,
  msg: client_state.Msg,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  case msg {
    client_state.NoOp -> #(model, effect.none())

    client_state.UrlChanged(uri) -> handle_url_changed(model, uri)

    client_state.NavigateTo(route, mode) ->
      handle_navigate_to(model, route, mode)

    client_state.MeFetched(Ok(user)) -> {
      let default_page = client_state.Member

      let resolved_page = case model.core.page {
        client_state.Member -> client_state.Member
        client_state.Admin -> client_state.Admin
        _ -> default_page
      }

      let model =
        client_state.update_core(model, fn(core) {
          client_state.CoreModel(
            ..core,
            page: resolved_page,
            user: opt.Some(user),
            auth_checked: True,
          )
        })
      let #(model, route_fx) = apply_authenticated_browser_route(model)
      let #(model, boot) = bootstrap_admin(model)
      let #(model, hyd_fx) = hydrate_model(model)

      #(
        model,
        effect.batch([
          route_fx,
          boot,
          hyd_fx,
          replace_url(model),
        ]),
      )
    }

    client_state.MeFetched(Error(err)) -> {
      case err.status == 401 {
        True -> {
          let model = show_login_without_user(model, True)
          #(model, replace_url_and_title(model))
        }

        False -> {
          let model =
            client_state.update_auth(
              show_login_without_user(model, True),
              fn(auth) {
                auth_state.AuthModel(..auth, login_error: opt.Some(err.message))
              },
            )

          #(model, replace_url_and_title(model))
        }
      }
    }

    client_state.AuthMsg(inner) -> {
      let #(auth, fx, action) =
        auth_workflow.update(model.auth, inner, auth_context.from_state(model))
      let model = client_state.update_auth(model, fn(_) { auth })
      handle_auth_action(
        model,
        action,
        fx,
        bootstrap_admin,
        hydrate_model,
        replace_url,
      )
    }

    client_state.ToastShow(message, variant) ->
      show_toast(model, message, variant, opt.None)

    client_state.ToastShowWithAction(message, variant, action) ->
      show_toast(model, message, variant, opt.Some(action))

    client_state.ToastActionTriggered(action) -> {
      let action_msg = toast_action_to_msg(action)

      #(model, effect.from(fn(dispatch) { dispatch(action_msg) }))
    }

    client_state.ToastDismiss(id) -> {
      let next_state = toast.dismiss(model.ui.toast_state, id)
      #(
        client_state.update_ui(model, fn(ui) {
          ui_state.UiModel(..ui, toast_state: next_state)
        }),
        effect.none(),
      )
    }

    client_state.ToastTick(now) -> {
      let #(next_state, should_schedule) = toast.tick(model.ui.toast_state, now)
      let tick_effect = case should_schedule {
        True ->
          app_effects.schedule_timeout(1000, fn() {
            client_state.ToastTick(client_ffi.now_ms())
          })
        False -> effect.none()
      }
      #(
        client_state.update_ui(model, fn(ui) {
          ui_state.UiModel(..ui, toast_state: next_state)
        }),
        tick_effect,
      )
    }

    client_state.ThemeSelected(value) -> {
      case theme.parse(value) {
        Ok(next_theme) -> {
          case next_theme == model.ui.theme {
            True -> #(model, effect.none())

            False -> #(
              client_state.update_ui(model, fn(ui) {
                ui_state.UiModel(..ui, theme: next_theme)
              }),
              effect.from(fn(_dispatch) { theme.save_to_storage(next_theme) }),
            )
          }
        }

        Error(_) -> #(model, effect.none())
      }
    }

    client_state.I18nMsg(inner) -> {
      let #(next_locale, fx) = i18n_workflow.update(model.ui.locale, inner)

      case next_locale == model.ui.locale {
        True -> #(model, fx)

        False -> #(
          client_state.update_ui(model, fn(ui) {
            ui_state.UiModel(..ui, locale: next_locale)
          }),
          fx,
        )
      }
    }

    client_state.LayoutMsg(inner) -> {
      let layout_model =
        layout_workflow.Model(
          ui: model.ui,
          member_panel_expanded: model.member.pool.member_panel_expanded,
        )
      let #(next_layout, fx) = layout_workflow.update(layout_model, inner)
      let next_model =
        client_state.update_member(
          client_state.update_ui(model, fn(_ui) { next_layout.ui }),
          fn(member) {
            let pool = member.pool
            member_state.MemberModel(
              ..member,
              pool: member_pool.Model(
                ..pool,
                member_panel_expanded: next_layout.member_panel_expanded,
              ),
            )
          },
        )

      #(next_model, fx)
    }

    client_state.ProjectSelected(project_id) -> {
      let selected = case int.parse(project_id) {
        Ok(id) -> opt.Some(id)
        Error(_) -> opt.None
      }

      let should_pause =
        should_pause_active_task_on_project_change(
          model.core.page == client_state.Member,
          model.core.selected_project_id,
          selected,
        )

      let model = case selected {
        opt.None ->
          client_state.update_member(
            client_state.update_core(model, fn(core) {
              client_state.CoreModel(..core, selected_project_id: selected)
            }),
            fn(member) {
              let pool = member.pool

              member_state.MemberModel(
                ..member,
                pool: member_pool.Model(
                  ..pool,
                  member_filters_type_id: opt.None,
                  member_task_types: NotAsked,
                ),
              )
            },
          )
        _ ->
          client_state.update_core(model, fn(core) {
            client_state.CoreModel(..core, selected_project_id: selected)
          })
      }

      case model.core.page {
        client_state.Member ->
          refresh_member_after_project_change(model, should_pause)
        _ -> refresh_admin_after_project_change(model)
      }
    }

    client_state.AdminMsg(inner) ->
      case inner {
        admin_messages.ProjectsFetched(result) ->
          handle_projects_fetched(model, result)

        _ ->
          admin_workflow.update(
            model,
            inner,
            admin_workflow.Context(
              refresh_section_for_test: refresh_section_for_test,
            ),
          )
      }

    client_state.PoolMsg(inner) -> handle_pool_msg(model, inner)
  }
}

fn handle_pool_msg(
  model: client_state.Model,
  inner: client_state.PoolMsg,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  let #(next, fx) =
    pool_workflow.update(
      model,
      inner,
      pool_workflow.Context(member_refresh: member_refresh),
    )
  let next = normalize_show_stack(next, inner)
  let route_fx = case should_sync_show_route(inner) {
    True -> replace_url(next)
    False -> effect.none()
  }

  #(next, effect.batch([fx, route_fx]))
}

fn normalize_show_stack(
  model: client_state.Model,
  inner: client_state.PoolMsg,
) -> client_state.Model {
  case inner {
    pool_messages.OpenCardShow(_) ->
      case model.member.notes.member_notes_task_id {
        opt.Some(_) -> close_task_show_in_model(model)
        opt.None -> model
      }
    _ -> model
  }
}

fn close_task_show_in_model(model: client_state.Model) -> client_state.Model {
  let #(pool, notes, dependencies) =
    task_show_state.close(model.member.pool, model.member.notes)

  client_state.update_member(model, fn(member) {
    member_state.MemberModel(
      ..member,
      pool: pool,
      notes: notes,
      dependencies: dependencies,
    )
  })
}

fn should_sync_show_route(inner: client_state.PoolMsg) -> Bool {
  case inner {
    pool_messages.OpenCardShow(_)
    | pool_messages.CloseCardShow
    | pool_messages.GlobalKeyDown(_)
    | pool_messages.MemberTaskShowOpened(_)
    | pool_messages.MemberTaskShowClosed -> True
    _ -> False
  }
}

fn refresh_member_after_project_change(
  model: client_state.Model,
  should_pause: Bool,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  let #(next, fx) = member_refresh(model)
  let pause_fx = pause_fx_for_project_change(next, should_pause)
  #(next, effect.batch([fx, pause_fx, replace_url(next)]))
}

fn pause_fx_for_project_change(
  model: client_state.Model,
  should_pause: Bool,
) -> Effect(client_state.Msg) {
  case should_pause {
    True -> pause_active_task_fx(model)
    False -> effect.none()
  }
}

fn pause_active_task_fx(model: client_state.Model) -> Effect(client_state.Msg) {
  case state_selectors.now_working_active_task_id(model) {
    opt.Some(task_id) ->
      active_api.pause_work_session(task_id, fn(result) {
        client_state.pool_msg(pool_messages.MemberWorkSessionPaused(result))
      })
    opt.None -> effect.none()
  }
}

fn refresh_admin_after_project_change(
  model: client_state.Model,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  let #(next, fx) = refresh_section_for_test(model)
  #(next, effect.batch([fx, replace_url(next)]))
}
