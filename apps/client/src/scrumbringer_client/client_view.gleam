//// View Assembler for Scrumbringer client.
////
//// ## Mission
////
//// Thin assembler that composes views from domain-specific view modules.
//// Delegates all rendering to feature modules while handling top-level
//// page routing and shared layout concerns.
////
//// ## Responsibilities
////
//// - Main `view` function dispatching to page views
//// - Admin and member page assembly
//// - Topbar, nav, and layout composition
//// - Theme and locale switches
////
//// ## Non-responsibilities
////
//// - Domain-specific views (see `features/*/view.gleam`)
//// - State management (see `client_update.gleam`)
//// - Type definitions (see `client_state.gleam`)
////
//// ## Relations
////
//// - **features/pool/view.gleam**: Pool canvas, task cards, filters
//// - **features/tasks/view.gleam**: Task view utilities and distributed task view docs
//// - **features/metrics/view.gleam**: Admin metrics views
//// - **features/skills/view.gleam**: Member skills/capabilities
//// - **features/admin/view.gleam**: Admin section views
//// - **features/auth/view.gleam**: Auth views (login, register, etc.)

import gleam/int
import gleam/list
import gleam/option as opt

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{
  button, div, h2, h3, label, option, p, select, span, style, text,
}
import lustre/event

import domain/org_role
import domain/project.{type Project}
import domain/user.{type User}

import scrumbringer_client/client_state.{
  type Model, type Msg, AcceptInvite as AcceptInvitePage, Admin, LocaleSelected,
  Login, LogoutClicked, Member, NavigateTo, Push,
  ResetPassword as ResetPasswordPage, ThemeSelected, ToastDismissed,
}
import scrumbringer_client/features/admin/view as admin_view
import scrumbringer_client/features/auth/view as auth_view
import scrumbringer_client/features/invites/view as invites_view
import scrumbringer_client/features/metrics/view as metrics_view
import scrumbringer_client/features/my_bar/view as my_bar_view
import scrumbringer_client/features/now_working/view as now_working_view
import scrumbringer_client/features/pool/view as pool_view
import scrumbringer_client/features/projects/view as projects_view
import scrumbringer_client/features/skills/view as skills_view
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/member_section
import scrumbringer_client/permissions
import scrumbringer_client/router
import scrumbringer_client/styles
import scrumbringer_client/theme
import scrumbringer_client/ui/layout as ui_layout
import scrumbringer_client/ui/toast as ui_toast
import scrumbringer_client/update_helpers

// =============================================================================
// Main View
// =============================================================================

/// Renders the main application view.
pub fn view(model: Model) -> Element(Msg) {
  div(
    [
      attribute.class("app"),
      attribute.attribute("style", theme.css_vars(model.theme)),
    ],
    [
      style([], styles.base_css()),
      ui_toast.view(
        model.toast,
        update_helpers.i18n_t(model, i18n_text.Dismiss),
        ToastDismissed,
      ),
      case model.page {
        Login -> auth_view.view_login(model)
        AcceptInvitePage -> auth_view.view_accept_invite(model)
        ResetPasswordPage -> auth_view.view_reset_password(model)
        Admin -> view_admin(model)
        Member -> view_member(model)
      },
    ],
  )
}

/// Test helper for now_working elapsed time calculation.
pub fn now_working_elapsed_from_ms_for_test(
  accumulated_s: Int,
  started_ms: Int,
  server_now_ms: Int,
) -> String {
  update_helpers.now_working_elapsed_from_ms(
    accumulated_s,
    started_ms,
    server_now_ms,
  )
}

// =============================================================================
// Admin Views
// =============================================================================

fn view_admin(model: Model) -> Element(Msg) {
  case model.user {
    opt.None -> auth_view.view_login(model)

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

fn view_topbar(model: Model, user: User) -> Element(Msg) {
  let show_project_selector =
    model.active_section == permissions.Members
    || model.active_section == permissions.TaskTypes
    || model.active_section == permissions.Metrics

  div([attribute.class("topbar")], [
    div([attribute.class("topbar-title")], [
      text(i18n.t(model.locale, admin_section_label(model.active_section))),
    ]),
    case show_project_selector {
      True -> view_project_selector(model)
      False -> element.none()
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
              [text(i18n.t(model.locale, admin_section_label(section)))],
            )
          }),
        )
    },
  ])
}

fn view_section(
  model: Model,
  user: User,
  projects: List(Project),
  selected: opt.Option(Project),
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
        permissions.Invites -> invites_view.view_invites(model)
        permissions.OrgSettings -> admin_view.view_org_settings(model)
        permissions.Projects -> projects_view.view_projects(model)
        permissions.Metrics -> metrics_view.view_metrics(model, selected)
        permissions.Capabilities -> admin_view.view_capabilities(model)
        permissions.Members -> admin_view.view_members(model, selected)
        permissions.TaskTypes -> admin_view.view_task_types(model, selected)
        permissions.Cards -> admin_view.view_cards(model, selected)
        permissions.Workflows -> admin_view.view_workflows(model, selected)
        permissions.TaskTemplates ->
          admin_view.view_task_templates(model, selected)
      }
  }
}

// =============================================================================
// Member Views
// =============================================================================

fn view_member(model: Model) -> Element(Msg) {
  case model.user {
    opt.None -> auth_view.view_login(model)

    opt.Some(user) ->
      case model.is_mobile {
        True ->
          div([attribute.class("member")], [
            view_member_topbar(model, user),
            now_working_view.view_panel(model),
            div([attribute.class("content")], [view_member_section(model, user)]),
          ])

        False ->
          div([attribute.class("member")], [
            view_member_topbar(model, user),
            case model.member_section {
              member_section.Pool ->
                div([attribute.class("body")], [
                  view_member_nav(model),
                  pool_view.view_pool_body(model, user),
                ])

              _ ->
                div([], [
                  now_working_view.view_panel(model),
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
        _ -> element.none()
      },
      view_theme_switch(model),
      span([attribute.class("user")], [text(user.email)]),
      button([event.on_click(LogoutClicked)], [
        text(update_helpers.i18n_t(model, i18n_text.Logout)),
      ]),
    ]),
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
  label_text: i18n_text.Text,
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
    [text(update_helpers.i18n_t(model, label_text))],
  )
}

fn view_member_section(model: Model, user: User) -> Element(Msg) {
  case model.member_section {
    member_section.Pool -> pool_view.view_pool_main(model, user)
    member_section.MyBar -> my_bar_view.view_bar(model, user)
    member_section.MySkills -> skills_view.view_skills(model)
  }
}

// =============================================================================
// Shared Components
// =============================================================================

fn view_theme_switch(model: Model) -> Element(Msg) {
  ui_layout.theme_switch(model.locale, model.theme, ThemeSelected)
}

fn view_locale_switch(model: Model) -> Element(Msg) {
  ui_layout.locale_switch(model.locale, LocaleSelected)
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
    Member, opt.None ->
      update_helpers.i18n_t(model, i18n_text.ShowingTasksFromAllProjects)
    Member, _ -> ""
    _, opt.None ->
      update_helpers.i18n_t(
        model,
        i18n_text.SelectProjectToManageMembersOrTaskTypes,
      )
    _, _ -> ""
  }

  div([attribute.class("project-selector")], [
    div([attribute.class("topbar-group")], [
      label([], [text(update_helpers.i18n_t(model, i18n_text.ProjectLabel))]),
      select(
        [
          attribute.value(selected_id),
          event.on_input(client_state.ProjectSelected),
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
      True -> element.none()
      False -> div([attribute.class("hint")], [text(helper)])
    },
  ])
}

// =============================================================================
// Helpers
// =============================================================================

/// Returns the i18n text key for an admin section label.
///
/// Used for nav items and topbar title display. Returns an i18n_text.Text
/// variant for use with i18n.t(). For browser title updates, use
/// router.update_admin_section_label() instead.
fn admin_section_label(section: permissions.AdminSection) -> i18n_text.Text {
  case section {
    permissions.Invites -> i18n_text.AdminInvites
    permissions.OrgSettings -> i18n_text.AdminOrgSettings
    permissions.Projects -> i18n_text.AdminProjects
    permissions.Metrics -> i18n_text.AdminMetrics
    permissions.Members -> i18n_text.AdminMembers
    permissions.Capabilities -> i18n_text.AdminCapabilities
    permissions.TaskTypes -> i18n_text.AdminTaskTypes
    permissions.Cards -> i18n_text.AdminCards
    permissions.Workflows -> i18n_text.AdminWorkflows
    permissions.TaskTemplates -> i18n_text.AdminTaskTemplates
  }
}
