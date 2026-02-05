//// Hydration update handling.
////
//// ## Mission
////
//// Compute and execute hydration commands when navigating between routes.
////
//// ## Responsibilities
////
//// - Build model snapshot for hydration planning
//// - Translate hydration commands into effects and state updates
//// - Handle hydration-triggered redirects
////
//// ## Non-responsibilities
////
//// - Route parsing/formatting (see `router.gleam`)
//// - API implementations (see `api/*.gleam`)

import gleam/list
import gleam/option as opt

import lustre/effect

import domain/remote.{type Remote, Loaded, Loading, NotAsked, Failed}
import domain/user.{type User}
import scrumbringer_client/api/auth as api_auth
import scrumbringer_client/api/metrics as api_metrics
import scrumbringer_client/api/org as api_org
import scrumbringer_client/api/projects as api_projects
import scrumbringer_client/api/tasks as api_tasks
import scrumbringer_client/client_state
import scrumbringer_client/client_state/admin as admin_state
import scrumbringer_client/client_state/admin/capabilities as admin_capabilities
import scrumbringer_client/client_state/admin/invites as admin_invites
import scrumbringer_client/client_state/admin/members as admin_members
import scrumbringer_client/client_state/admin/metrics as admin_metrics
import scrumbringer_client/client_state/admin/task_types as admin_task_types
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/metrics as member_metrics
import scrumbringer_client/client_state/member/skills as member_skills
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/helpers/selection as helpers_selection
import scrumbringer_client/hydration
import scrumbringer_client/permissions
import scrumbringer_client/router

/// Provides hydration context.
pub type Context {
  Context(
    current_route: fn(client_state.Model) -> router.Route,
    handle_navigate_to: fn(client_state.Model, router.Route, client_state.NavMode) ->
      #(client_state.Model, effect.Effect(client_state.Msg)),
    member_refresh: fn(client_state.Model) -> #(client_state.Model, effect.Effect(client_state.Msg)),
  )
}

fn remote_state(remote: Remote(a)) -> hydration.ResourceState {
  case remote {
    NotAsked -> hydration.NotAsked
    Loading -> hydration.Loading
    Loaded(_) -> hydration.Loaded
    Failed(_) -> hydration.Failed
  }
}

// Justification: nested case improves clarity for branching logic.
fn auth_state(model: client_state.Model) -> hydration.AuthState {
  case model.core.user {
    opt.Some(user) -> hydration.Authed(user.org_role)

    opt.None ->
      case model.core.auth_checked {
        True -> hydration.Unauthed
        False -> hydration.Unknown
      }
  }
}

fn build_snapshot(model: client_state.Model) -> hydration.Snapshot {
  let projects = helpers_selection.active_projects(model)
  hydration.Snapshot(
    auth: auth_state(model),
    projects: remote_state(model.core.projects),
    is_any_project_manager: permissions.any_project_manager(projects),
    invite_links: remote_state(model.admin.invites.invite_links),
    capabilities: remote_state(model.admin.capabilities.capabilities),
    my_capability_ids: remote_state(model.member.skills.member_my_capability_ids),
    org_settings_users: remote_state(model.admin.members.org_settings_users),
    org_users_cache: remote_state(model.admin.members.org_users_cache),
    members: remote_state(model.admin.members.members),
    members_project_id: model.admin.members.members_project_id,
    task_types: remote_state(model.admin.task_types.task_types),
    task_types_project_id: model.admin.task_types.task_types_project_id,
    member_tasks: remote_state(model.member.pool.member_tasks),
    member_cards: remote_state(model.member.pool.member_cards),
    work_sessions: remote_state(model.member.metrics.member_work_sessions),
    me_metrics: remote_state(model.member.metrics.member_metrics),
    org_metrics_overview: remote_state(model.admin.metrics.admin_metrics_overview),
    org_metrics_project_tasks: remote_state(
      model.admin.metrics.admin_metrics_project_tasks,
    ),
    org_metrics_project_id: model.admin.metrics.admin_metrics_project_id,
  )
}

/// Hydrate model based on current route and resource states.
pub fn hydrate_model(
  model: client_state.Model,
  ctx: Context,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let Context(
    current_route: current_route,
    handle_navigate_to: handle_navigate_to,
    member_refresh: member_refresh,
  ) = ctx

  let route = current_route(model)
  let commands = hydration.plan(route, build_snapshot(model))

  case redirect_from_commands(commands) {
    opt.Some(to) ->
      handle_hydration_redirect(model, route, to, handle_navigate_to)
    opt.None -> apply_hydration_commands(model, commands, member_refresh)
  }
}

// Justification: nested case improves clarity for branching logic.
fn redirect_from_commands(
  commands: List(hydration.Command),
) -> opt.Option(router.Route) {
  case
    list.find(commands, fn(cmd) {
      case cmd {
        hydration.Redirect(_) -> True
        _ -> False
      }
    })
  {
    Ok(hydration.Redirect(to: to)) -> opt.Some(to)
    _ -> opt.None
  }
}

fn handle_hydration_redirect(
  model: client_state.Model,
  route: router.Route,
  to: router.Route,
  handle_navigate_to: fn(client_state.Model, router.Route, client_state.NavMode) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case to == route {
    True -> #(model, effect.none())
    False -> handle_navigate_to(model, to, client_state.Replace)
  }
}

fn apply_hydration_commands(
  model: client_state.Model,
  commands: List(hydration.Command),
  member_refresh: fn(client_state.Model) -> #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let #(next, effects) =
    list.fold(commands, #(model, []), fn(state, cmd) {
      let #(m, fx) = state
      apply_hydration_command(m, fx, cmd, member_refresh)
    })

  #(next, effect.batch(list.reverse(effects)))
}

fn apply_hydration_command(
  model: client_state.Model,
  fx: List(effect.Effect(client_state.Msg)),
  cmd: hydration.Command,
  member_refresh: fn(client_state.Model) -> #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, List(effect.Effect(client_state.Msg))) {
  case cmd {
    hydration.FetchMe -> hydrate_fetch_me(model, fx)
    hydration.FetchProjects -> hydrate_fetch_projects(model, fx)
    hydration.FetchInviteLinks -> hydrate_fetch_invite_links(model, fx)
    hydration.FetchCapabilities -> hydrate_fetch_capabilities(model, fx)
    hydration.FetchMeCapabilityIds -> hydrate_fetch_me_capability_ids(model, fx)
    hydration.FetchWorkSessions -> hydrate_fetch_work_sessions(model, fx)
    hydration.FetchMeMetrics -> hydrate_fetch_me_metrics(model, fx)
    hydration.FetchOrgMetricsOverview ->
      hydrate_fetch_org_metrics_overview(model, fx)
    hydration.FetchOrgMetricsProjectTasks(project_id: project_id) ->
      hydrate_fetch_org_metrics_project_tasks(model, fx, project_id)
    hydration.FetchOrgSettingsUsers ->
      hydrate_fetch_org_settings_users(model, fx)
    hydration.FetchOrgUsersCache -> hydrate_fetch_org_users_cache(model, fx)
    hydration.FetchMembers(project_id: project_id) ->
      hydrate_fetch_members(model, fx, project_id)
    hydration.FetchTaskTypes(project_id: project_id) ->
      hydrate_fetch_task_types(model, fx, project_id)
    hydration.RefreshMember -> hydrate_refresh_member(model, fx, member_refresh)
    hydration.Redirect(_) -> #(model, fx)
  }
}

fn hydrate_fetch_me(
  model: client_state.Model,
  fx: List(effect.Effect(client_state.Msg)),
) -> #(client_state.Model, List(effect.Effect(client_state.Msg))) {
  #(model, [api_auth.fetch_me(client_state.MeFetched), ..fx])
}

fn hydrate_fetch_projects(
  model: client_state.Model,
  fx: List(effect.Effect(client_state.Msg)),
) -> #(client_state.Model, List(effect.Effect(client_state.Msg))) {
  case model.core.projects {
    Loading | Loaded(_) -> #(model, fx)
    _ -> hydrate_projects_request(model, fx)
  }
}

fn hydrate_projects_request(
  model: client_state.Model,
  fx: List(effect.Effect(client_state.Msg)),
) -> #(client_state.Model, List(effect.Effect(client_state.Msg))) {
  let model =
    client_state.update_core(model, fn(core) {
      client_state.CoreModel(..core, projects: Loading)
    })

  #(model, [
    api_projects.list_projects(fn(result) {
      client_state.admin_msg(admin_messages.ProjectsFetched(result))
    }),
    ..fx
  ])
}

fn hydrate_fetch_invite_links(
  model: client_state.Model,
  fx: List(effect.Effect(client_state.Msg)),
) -> #(client_state.Model, List(effect.Effect(client_state.Msg))) {
  case model.admin.invites.invite_links {
    Loading | Loaded(_) -> #(model, fx)
    _ -> hydrate_invite_links_request(model, fx)
  }
}

fn hydrate_invite_links_request(
  model: client_state.Model,
  fx: List(effect.Effect(client_state.Msg)),
) -> #(client_state.Model, List(effect.Effect(client_state.Msg))) {
  let model =
    client_state.update_admin(model, fn(admin) {
      admin_state.AdminModel(
        ..admin,
        invites: admin_invites.Model(
          ..admin.invites,
          invite_links: Loading,
        ),
      )
    })

  #(model, [
    api_org.list_invite_links(fn(result) {
      client_state.admin_msg(admin_messages.InviteLinksFetched(result))
    }),
    ..fx
  ])
}

fn hydrate_fetch_capabilities(
  model: client_state.Model,
  fx: List(effect.Effect(client_state.Msg)),
) -> #(client_state.Model, List(effect.Effect(client_state.Msg))) {
  case model.admin.capabilities.capabilities, model.core.selected_project_id {
    Loading, _ | Loaded(_), _ -> #(model, fx)
    _, opt.Some(project_id) ->
      hydrate_capabilities_request(model, fx, project_id)
    _, opt.None -> #(model, fx)
  }
}

fn hydrate_capabilities_request(
  model: client_state.Model,
  fx: List(effect.Effect(client_state.Msg)),
  project_id: Int,
) -> #(client_state.Model, List(effect.Effect(client_state.Msg))) {
  let model =
    client_state.update_admin(model, fn(admin) {
      let capabilities = admin.capabilities
      admin_state.AdminModel(
        ..admin,
        capabilities: admin_capabilities.Model(
          ..capabilities,
          capabilities: Loading,
        ),
      )
    })

  #(model, [
    api_org.list_project_capabilities(project_id, fn(result) {
      client_state.admin_msg(admin_messages.CapabilitiesFetched(result))
    }),
    ..fx
  ])
}

fn hydrate_fetch_me_capability_ids(
  model: client_state.Model,
  fx: List(effect.Effect(client_state.Msg)),
) -> #(client_state.Model, List(effect.Effect(client_state.Msg))) {
  case
    model.member.skills.member_my_capability_ids,
    model.core.selected_project_id,
    model.core.user
  {
    Loading, _, _ | Loaded(_), _, _ -> #(model, fx)
    _, opt.Some(project_id), opt.Some(user) ->
      hydrate_me_capability_ids_request(model, fx, project_id, user)
    _, _, _ -> #(model, fx)
  }
}

fn hydrate_me_capability_ids_request(
  model: client_state.Model,
  fx: List(effect.Effect(client_state.Msg)),
  project_id: Int,
  user: User,
) -> #(client_state.Model, List(effect.Effect(client_state.Msg))) {
  let model =
    client_state.update_member(model, fn(member) {
      let skills = member.skills
      member_state.MemberModel(
        ..member,
        skills: member_skills.Model(
          ..skills,
          member_my_capability_ids: Loading,
        ),
      )
    })

  #(model, [
    api_tasks.get_member_capability_ids(project_id, user.id, fn(result) {
      client_state.pool_msg(pool_messages.MemberMyCapabilityIdsFetched(result))
    }),
    ..fx
  ])
}

fn hydrate_fetch_work_sessions(
  model: client_state.Model,
  fx: List(effect.Effect(client_state.Msg)),
) -> #(client_state.Model, List(effect.Effect(client_state.Msg))) {
  case model.member.metrics.member_work_sessions {
    Loading | Loaded(_) -> #(model, fx)
    _ -> hydrate_work_sessions_request(model, fx)
  }
}

fn hydrate_work_sessions_request(
  model: client_state.Model,
  fx: List(effect.Effect(client_state.Msg)),
) -> #(client_state.Model, List(effect.Effect(client_state.Msg))) {
  let model =
    client_state.update_member(model, fn(member) {
      let metrics = member.metrics
      member_state.MemberModel(
        ..member,
        metrics: member_metrics.Model(
          ..metrics,
          member_work_sessions: Loading,
        ),
      )
    })

  #(model, [
    api_tasks.get_work_sessions(fn(result) {
      client_state.pool_msg(pool_messages.MemberWorkSessionsFetched(result))
    }),
    ..fx
  ])
}

fn hydrate_fetch_me_metrics(
  model: client_state.Model,
  fx: List(effect.Effect(client_state.Msg)),
) -> #(client_state.Model, List(effect.Effect(client_state.Msg))) {
  case model.member.metrics.member_metrics {
    Loading | Loaded(_) -> #(model, fx)
    _ -> hydrate_me_metrics_request(model, fx)
  }
}

fn hydrate_me_metrics_request(
  model: client_state.Model,
  fx: List(effect.Effect(client_state.Msg)),
) -> #(client_state.Model, List(effect.Effect(client_state.Msg))) {
  let model =
    client_state.update_member(model, fn(member) {
      let metrics = member.metrics
      member_state.MemberModel(
        ..member,
        metrics: member_metrics.Model(..metrics, member_metrics: Loading),
      )
    })

  #(model, [
    api_metrics.get_me_metrics(30, fn(result) {
      client_state.pool_msg(pool_messages.MemberMetricsFetched(result))
    }),
    ..fx
  ])
}

fn hydrate_fetch_org_metrics_overview(
  model: client_state.Model,
  fx: List(effect.Effect(client_state.Msg)),
) -> #(client_state.Model, List(effect.Effect(client_state.Msg))) {
  case model.admin.metrics.admin_metrics_overview {
    Loading | Loaded(_) -> #(model, fx)
    _ -> hydrate_org_metrics_overview_request(model, fx)
  }
}

fn hydrate_org_metrics_overview_request(
  model: client_state.Model,
  fx: List(effect.Effect(client_state.Msg)),
) -> #(client_state.Model, List(effect.Effect(client_state.Msg))) {
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

  #(model, [
    api_metrics.get_org_metrics_overview(30, fn(result) {
      client_state.pool_msg(pool_messages.AdminMetricsOverviewFetched(result))
    }),
    ..fx
  ])
}

fn hydrate_fetch_org_metrics_project_tasks(
  model: client_state.Model,
  fx: List(effect.Effect(client_state.Msg)),
  project_id: Int,
) -> #(client_state.Model, List(effect.Effect(client_state.Msg))) {
  case can_fetch_project(model, project_id) {
    False -> #(model, fx)
    True -> hydrate_org_metrics_project_tasks_if_ready(model, fx, project_id)
  }
}

fn hydrate_org_metrics_project_tasks_if_ready(
  model: client_state.Model,
  fx: List(effect.Effect(client_state.Msg)),
  project_id: Int,
) -> #(client_state.Model, List(effect.Effect(client_state.Msg))) {
  case
    model.admin.metrics.admin_metrics_project_tasks,
    model.admin.metrics.admin_metrics_project_id
  {
    Loading, _ -> #(model, fx)
    Loaded(_), opt.Some(pid) if pid == project_id -> #(model, fx)
    _, _ -> hydrate_org_metrics_project_tasks_request(model, fx, project_id)
  }
}

fn hydrate_org_metrics_project_tasks_request(
  model: client_state.Model,
  fx: List(effect.Effect(client_state.Msg)),
  project_id: Int,
) -> #(client_state.Model, List(effect.Effect(client_state.Msg))) {
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

  let fx_tasks =
    api_metrics.get_org_metrics_project_tasks(project_id, 30, fn(result) {
      client_state.pool_msg(pool_messages.AdminMetricsProjectTasksFetched(
        result,
      ))
    })

  #(model, [fx_tasks, ..fx])
}

fn hydrate_fetch_org_settings_users(
  model: client_state.Model,
  fx: List(effect.Effect(client_state.Msg)),
) -> #(client_state.Model, List(effect.Effect(client_state.Msg))) {
  case model.admin.members.org_settings_users {
    Loading | Loaded(_) -> #(model, fx)
    _ -> hydrate_org_settings_users_request(model, fx)
  }
}

fn hydrate_org_settings_users_request(
  model: client_state.Model,
  fx: List(effect.Effect(client_state.Msg)),
) -> #(client_state.Model, List(effect.Effect(client_state.Msg))) {
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

  #(model, [
    api_org.list_org_users("", fn(result) {
      client_state.admin_msg(admin_messages.OrgSettingsUsersFetched(result))
    }),
    ..fx
  ])
}

fn hydrate_fetch_org_users_cache(
  model: client_state.Model,
  fx: List(effect.Effect(client_state.Msg)),
) -> #(client_state.Model, List(effect.Effect(client_state.Msg))) {
  case model.admin.members.org_users_cache {
    Loading | Loaded(_) -> #(model, fx)
    _ -> hydrate_org_users_cache_request(model, fx)
  }
}

fn hydrate_org_users_cache_request(
  model: client_state.Model,
  fx: List(effect.Effect(client_state.Msg)),
) -> #(client_state.Model, List(effect.Effect(client_state.Msg))) {
  let model =
    client_state.update_admin(model, fn(admin) {
      let members = admin.members
      admin_state.AdminModel(
        ..admin,
        members: admin_members.Model(..members, org_users_cache: Loading),
      )
    })

  #(model, [
    api_org.list_org_users("", fn(result) {
      client_state.admin_msg(admin_messages.OrgUsersCacheFetched(result))
    }),
    ..fx
  ])
}

fn hydrate_fetch_members(
  model: client_state.Model,
  fx: List(effect.Effect(client_state.Msg)),
  project_id: Int,
) -> #(client_state.Model, List(effect.Effect(client_state.Msg))) {
  case can_fetch_project(model, project_id) {
    False -> #(model, fx)
    True -> hydrate_members_if_ready(model, fx, project_id)
  }
}

fn hydrate_members_if_ready(
  model: client_state.Model,
  fx: List(effect.Effect(client_state.Msg)),
  project_id: Int,
) -> #(client_state.Model, List(effect.Effect(client_state.Msg))) {
  case model.admin.members.members {
    Loading -> #(model, fx)
    _ -> hydrate_members_request(model, fx, project_id)
  }
}

fn hydrate_members_request(
  model: client_state.Model,
  fx: List(effect.Effect(client_state.Msg)),
  project_id: Int,
) -> #(client_state.Model, List(effect.Effect(client_state.Msg))) {
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

  let fx_members =
    api_projects.list_project_members(project_id, fn(result) {
      client_state.admin_msg(admin_messages.MembersFetched(result))
    })
  let fx_users =
    api_org.list_org_users("", fn(result) {
      client_state.admin_msg(admin_messages.OrgUsersCacheFetched(result))
    })

  #(model, [effect.batch([fx_members, fx_users]), ..fx])
}

fn hydrate_fetch_task_types(
  model: client_state.Model,
  fx: List(effect.Effect(client_state.Msg)),
  project_id: Int,
) -> #(client_state.Model, List(effect.Effect(client_state.Msg))) {
  case can_fetch_project(model, project_id) {
    False -> #(model, fx)
    True -> hydrate_task_types_if_ready(model, fx, project_id)
  }
}

fn hydrate_task_types_if_ready(
  model: client_state.Model,
  fx: List(effect.Effect(client_state.Msg)),
  project_id: Int,
) -> #(client_state.Model, List(effect.Effect(client_state.Msg))) {
  case model.admin.task_types.task_types {
    Loading -> #(model, fx)
    _ -> hydrate_task_types_request(model, fx, project_id)
  }
}

fn hydrate_task_types_request(
  model: client_state.Model,
  fx: List(effect.Effect(client_state.Msg)),
  project_id: Int,
) -> #(client_state.Model, List(effect.Effect(client_state.Msg))) {
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

  #(model, [
    api_tasks.list_task_types(project_id, fn(result) {
      client_state.admin_msg(admin_messages.TaskTypesFetched(result))
    }),
    ..fx
  ])
}

fn hydrate_refresh_member(
  model: client_state.Model,
  fx: List(effect.Effect(client_state.Msg)),
  member_refresh: fn(client_state.Model) -> #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, List(effect.Effect(client_state.Msg))) {
  case model.core.projects {
    Loaded(_) -> {
      let #(next, member_fx) = member_refresh(model)
      #(next, [member_fx, ..fx])
    }
    _ -> #(model, fx)
  }
}

fn can_fetch_project(model: client_state.Model, project_id: Int) -> Bool {
  case model.core.projects {
    Loaded(projects) -> list.any(projects, fn(p) { p.id == project_id })
    _ -> False
  }
}
