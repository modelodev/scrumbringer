//// Admin section views.
////
//// ## Mission
////
//// Renders admin panel views for organization and project administration.
////
//// ## Responsibilities
////
//// - Organization settings view (role management)
//// - Capabilities management view
//// - Project members management view
//// - Task types management view
////
//// ## Line Count Justification
////
//// ~780 lines: Consolidates all admin panel views that share a common admin
//// context (permissions, project selection, CRUD patterns). These views are
//// tightly coupled through shared UI patterns and state dependencies. Splitting
//// further would fragment the cohesive admin experience. Each sub-view (members,
//// capabilities, task_types, org_settings) requires similar imports and patterns.
////
//// ## Relations
////
//// - **client_view.gleam**: Dispatches to admin views from view_section
//// - **features/admin/update.gleam**: Handles admin-related messages
//// - **client_state.gleam**: Provides Model, Msg, Remote types

import gleam/dict
import gleam/int
import gleam/list
import gleam/option as opt
import gleam/string

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{
  button, div, form, h2, h3, hr, img, input, label, option, p, select, span,
  table, td, text, th, thead, tr,
}
import lustre/element/keyed
import lustre/event

import gleam/dynamic/decode

import domain/card.{type Card}
import domain/capability.{type Capability}
import domain/org.{type OrgUser}
import domain/project.{type Project, type ProjectMember}
import domain/task_type.{type TaskType}

import scrumbringer_client/client_state.{
  type Model, type Msg, type Remote, CapabilityCreateNameChanged,
  CapabilityCreateSubmitted, CardCreateDescriptionChanged,
  CardCreateSubmitted, CardCreateTitleChanged, CardDeleteCancelled,
  CardDeleteClicked, CardDeleteConfirmed, CardEditCancelled, CardEditClicked,
  CardEditDescriptionChanged, CardEditSubmitted, CardEditTitleChanged, Failed,
  IconError, IconOk, Loaded, Loading, MemberAddDialogClosed,
  MemberAddDialogOpened, MemberAddRoleChanged, MemberAddSubmitted,
  MemberAddUserSelected, MemberRemoveCancelled, MemberRemoveClicked,
  MemberRemoveConfirmed, NotAsked, OrgSettingsRoleChanged, OrgSettingsSaveClicked,
  OrgUsersSearchChanged, OrgUsersSearchDebounced, TaskTypeCreateCapabilityChanged,
  TaskTypeCreateIconChanged, TaskTypeCreateNameChanged, TaskTypeCreateSubmitted,
  TaskTypeIconErrored, TaskTypeIconLoaded,
}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/theme
import scrumbringer_client/update_helpers

// =============================================================================
// Public API
// =============================================================================

/// Organization settings view - manage user roles.
pub fn view_org_settings(model: Model) -> Element(Msg) {
  div([attribute.class("section")], [
    p([], [text(update_helpers.i18n_t(model, i18n_text.OrgSettingsHelp))]),
    case model.org_settings_users {
      NotAsked ->
        div([], [
          text(update_helpers.i18n_t(
            model,
            i18n_text.OpenThisSectionToLoadUsers,
          )),
        ])
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
          keyed.tbody(
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

              #(int.to_string(u.id), tr([], [
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
                    True -> element.none()
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
              ]))
            }),
          ),
        ])
      }
    },
  ])
}

/// Capabilities management view.
pub fn view_capabilities(model: Model) -> Element(Msg) {
  div([attribute.class("section")], [
    h2([], [text(update_helpers.i18n_t(model, i18n_text.Capabilities))]),
    view_capabilities_list(model, model.capabilities),
    hr([]),
    h3([], [text(update_helpers.i18n_t(model, i18n_text.CreateCapability))]),
    case model.capabilities_create_error {
      opt.Some(err) -> div([attribute.class("error")], [text(err)])
      opt.None -> element.none()
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

/// Project members management view.
pub fn view_members(
  model: Model,
  selected_project: opt.Option(Project),
) -> Element(Msg) {
  case selected_project {
    opt.None ->
      div([attribute.class("empty")], [
        text(update_helpers.i18n_t(
          model,
          i18n_text.SelectProjectToManageMembers,
        )),
      ])

    opt.Some(project) ->
      div([attribute.class("section")], [
        h2([], [
          text(update_helpers.i18n_t(
            model,
            i18n_text.MembersTitle(project.name),
          )),
        ]),
        button([event.on_click(MemberAddDialogOpened)], [
          text(update_helpers.i18n_t(model, i18n_text.AddMember)),
        ]),
        case model.members_remove_error {
          opt.Some(err) -> div([attribute.class("error")], [text(err)])
          opt.None -> element.none()
        },
        view_members_table(model, model.members, model.org_users_cache),
        case model.members_add_dialog_open {
          True -> view_add_member_dialog(model)
          False -> element.none()
        },
        case model.members_remove_confirm {
          opt.Some(user) -> view_remove_member_dialog(model, project.name, user)
          opt.None -> element.none()
        },
      ])
  }
}

/// Task types management view.
pub fn view_task_types(
  model: Model,
  selected_project: opt.Option(Project),
) -> Element(Msg) {
  case selected_project {
    opt.None ->
      div([attribute.class("empty")], [
        text(update_helpers.i18n_t(
          model,
          i18n_text.SelectProjectToManageTaskTypes,
        )),
      ])

    opt.Some(project) ->
      div([attribute.class("section")], [
        h2([], [
          text(update_helpers.i18n_t(
            model,
            i18n_text.TaskTypesTitle(project.name),
          )),
        ]),
        view_task_types_list(model, model.task_types, model.theme),
        hr([]),
        h3([], [text(update_helpers.i18n_t(model, i18n_text.CreateTaskType))]),
        case model.task_types_create_error {
          opt.Some(err) -> div([attribute.class("error")], [text(err)])
          opt.None -> element.none()
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
              _ -> element.none()
            },
          ]),
          div([attribute.class("field")], [
            label([], [
              text(update_helpers.i18n_t(model, i18n_text.CapabilityOptional)),
            ]),
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

// =============================================================================
// Capabilities Helpers
// =============================================================================

fn view_capabilities_list(
  model: Model,
  capabilities: Remote(List(Capability)),
) -> Element(Msg) {
  case capabilities {
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

    Loaded(capabilities) ->
      case capabilities {
        [] ->
          div([attribute.class("empty")], [
            text(update_helpers.i18n_t(model, i18n_text.NoCapabilitiesYet)),
          ])
        _ ->
          table([attribute.class("table")], [
            thead([], [
              tr([], [
                th([], [text(update_helpers.i18n_t(model, i18n_text.Name))]),
              ]),
            ]),
            keyed.tbody(
              [],
              list.map(capabilities, fn(c) {
                #(int.to_string(c.id), tr([], [td([], [text(c.name)])]))
              }),
            ),
          ])
      }
  }
}

// =============================================================================
// Members Helpers
// =============================================================================

fn view_members_table(
  model: Model,
  members: Remote(List(ProjectMember)),
  cache: Remote(List(OrgUser)),
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
            keyed.tbody(
              [],
              list.map(members, fn(m) {
                let email = case
                  update_helpers.resolve_org_user(cache, m.user_id)
                {
                  opt.Some(user) -> user.email
                  opt.None ->
                    update_helpers.i18n_t(
                      model,
                      i18n_text.UserNumber(m.user_id),
                    )
                }

                #(int.to_string(m.user_id), tr([], [
                  td([], [text(email)]),
                  td([], [text(int.to_string(m.user_id))]),
                  td([], [text(m.role)]),
                  td([], [text(m.created_at)]),
                  td([], [
                    button([event.on_click(MemberRemoveClicked(m.user_id))], [
                      text(update_helpers.i18n_t(model, i18n_text.Remove)),
                    ]),
                  ]),
                ]))
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
        opt.None -> element.none()
      },
      div([attribute.class("field")], [
        label([], [text(update_helpers.i18n_t(model, i18n_text.SearchByEmail))]),
        input([
          attribute.type_("text"),
          attribute.value(model.org_users_search_query),
          event.on_input(OrgUsersSearchChanged),
          event.debounce(event.on_input(OrgUsersSearchDebounced), 350),
          attribute.placeholder(update_helpers.i18n_t(
            model,
            i18n_text.EmailPlaceholderExample,
          )),
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
  results: Remote(List(OrgUser)),
) -> Element(Msg) {
  case results {
    NotAsked ->
      div([attribute.class("empty")], [
        text(update_helpers.i18n_t(model, i18n_text.TypeAnEmailToSearch)),
      ])

    Loading ->
      div([attribute.class("empty")], [
        text(update_helpers.i18n_t(model, i18n_text.Searching)),
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
                th([], [
                  text(update_helpers.i18n_t(model, i18n_text.EmailLabel)),
                ]),
                th([], [text(update_helpers.i18n_t(model, i18n_text.OrgRole))]),
                th([], [text(update_helpers.i18n_t(model, i18n_text.Created))]),
                th([], [text(update_helpers.i18n_t(model, i18n_text.Select))]),
              ]),
            ]),
            keyed.tbody(
              [],
              list.map(users, fn(u) {
                #(int.to_string(u.id), tr([], [
                  td([], [text(u.email)]),
                  td([], [text(u.org_role)]),
                  td([], [text(u.created_at)]),
                  td([], [
                    button([event.on_click(MemberAddUserSelected(u.id))], [
                      text(update_helpers.i18n_t(model, i18n_text.Select)),
                    ]),
                  ]),
                ]))
              }),
            ),
          ])
      }
  }
}

fn view_remove_member_dialog(
  model: Model,
  project_name: String,
  user: OrgUser,
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
        opt.None -> element.none()
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

// =============================================================================
// Task Types Helpers
// =============================================================================

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

/// Render a task type icon - either heroicon or emoji.
/// Exported for use in pool/task card views.
pub fn view_task_type_icon_inline(
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
  capabilities: Remote(List(Capability)),
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
          option(
            [attribute.value("")],
            update_helpers.i18n_t(model, i18n_text.NoneOption),
          ),
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
  task_types: Remote(List(TaskType)),
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
            h2([], [
              text(update_helpers.i18n_t(model, i18n_text.NoTaskTypesYet)),
            ]),
            p([], [
              text(update_helpers.i18n_t(model, i18n_text.TaskTypesExplain)),
            ]),
            p([], [
              text(update_helpers.i18n_t(
                model,
                i18n_text.CreateFirstTaskTypeHint,
              )),
            ]),
          ])
        _ ->
          table([attribute.class("table")], [
            thead([], [
              tr([], [
                th([], [text(update_helpers.i18n_t(model, i18n_text.Name))]),
                th([], [text(update_helpers.i18n_t(model, i18n_text.Icon))]),
                th([], [
                  text(update_helpers.i18n_t(model, i18n_text.CapabilityLabel)),
                ]),
              ]),
            ]),
            keyed.tbody(
              [],
              list.map(task_types, fn(tt) {
                #(int.to_string(tt.id), tr([], [
                  td([], [text(tt.name)]),
                  td([], [view_task_type_icon_inline(tt.icon, 20, theme)]),
                  td([], [
                    case tt.capability_id {
                      opt.Some(id) -> text(int.to_string(id))
                      opt.None -> text("-")
                    },
                  ]),
                ]))
              }),
            ),
          ])
      }
  }
}

// =============================================================================
// Cards (Fichas) Views
// =============================================================================

/// Cards management view.
pub fn view_cards(
  model: Model,
  selected_project: opt.Option(Project),
) -> Element(Msg) {
  case selected_project {
    opt.None ->
      div([attribute.class("empty")], [
        text(update_helpers.i18n_t(
          model,
          i18n_text.SelectProjectToManageCards,
        )),
      ])

    opt.Some(project) ->
      div([attribute.class("section")], [
        h2([], [
          text(update_helpers.i18n_t(
            model,
            i18n_text.CardsTitle(project.name),
          )),
        ]),
        view_cards_list(model, model.cards),
        hr([]),
        h3([], [text(update_helpers.i18n_t(model, i18n_text.CreateCard))]),
        case model.cards_create_error {
          opt.Some(err) -> div([attribute.class("error")], [text(err)])
          opt.None -> element.none()
        },
        form([event.on_submit(fn(_) { CardCreateSubmitted })], [
          div([attribute.class("field")], [
            label([], [text(update_helpers.i18n_t(model, i18n_text.CardTitle))]),
            input([
              attribute.type_("text"),
              attribute.value(model.cards_create_title),
              event.on_input(CardCreateTitleChanged),
              attribute.required(True),
            ]),
          ]),
          div([attribute.class("field")], [
            label([], [
              text(update_helpers.i18n_t(model, i18n_text.CardDescription)),
            ]),
            input([
              attribute.type_("text"),
              attribute.value(model.cards_create_description),
              event.on_input(CardCreateDescriptionChanged),
            ]),
          ]),
          button(
            [
              attribute.type_("submit"),
              attribute.disabled(model.cards_create_in_flight),
            ],
            [
              text(case model.cards_create_in_flight {
                True -> update_helpers.i18n_t(model, i18n_text.Creating)
                False -> update_helpers.i18n_t(model, i18n_text.Create)
              }),
            ],
          ),
        ]),
        case model.cards_edit_id {
          opt.Some(_) -> view_edit_card_dialog(model)
          opt.None -> element.none()
        },
        case model.cards_delete_confirm {
          opt.Some(card) -> view_delete_card_dialog(model, card)
          opt.None -> element.none()
        },
      ])
  }
}

fn view_cards_list(model: Model, cards: Remote(List(Card))) -> Element(Msg) {
  case cards {
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

    Loaded(cards) ->
      case cards {
        [] ->
          div([attribute.class("empty")], [
            text(update_helpers.i18n_t(model, i18n_text.NoCardsYet)),
          ])
        _ ->
          table([attribute.class("table")], [
            thead([], [
              tr([], [
                th([], [
                  text(update_helpers.i18n_t(model, i18n_text.CardTitle)),
                ]),
                th([], [
                  text(update_helpers.i18n_t(model, i18n_text.CardState)),
                ]),
                th([], [text(update_helpers.i18n_t(model, i18n_text.CardTasks))]),
                th([], [text(update_helpers.i18n_t(model, i18n_text.Actions))]),
              ]),
            ]),
            keyed.tbody(
              [],
              list.map(cards, fn(c) {
                #(int.to_string(c.id), tr([], [
                  td([], [text(c.title)]),
                  td([], [text(view_card_state_label(model, c.state))]),
                  td([], [
                    text(update_helpers.i18n_t(
                      model,
                      i18n_text.CardTaskCount(c.completed_count, c.task_count),
                    )),
                  ]),
                  td([], [
                    button([event.on_click(CardEditClicked(c))], [
                      text(update_helpers.i18n_t(model, i18n_text.EditCard)),
                    ]),
                    button([event.on_click(CardDeleteClicked(c))], [
                      text(update_helpers.i18n_t(model, i18n_text.DeleteCard)),
                    ]),
                  ]),
                ]))
              }),
            ),
          ])
      }
  }
}

fn view_card_state_label(model: Model, state: card.CardState) -> String {
  case state {
    card.Pendiente ->
      update_helpers.i18n_t(model, i18n_text.CardStatePendiente)
    card.EnCurso -> update_helpers.i18n_t(model, i18n_text.CardStateEnCurso)
    card.Cerrada -> update_helpers.i18n_t(model, i18n_text.CardStateCerrada)
  }
}

fn view_edit_card_dialog(model: Model) -> Element(Msg) {
  div([attribute.class("modal")], [
    div([attribute.class("modal-content")], [
      h3([], [text(update_helpers.i18n_t(model, i18n_text.EditCard))]),
      case model.cards_edit_error {
        opt.Some(err) -> div([attribute.class("error")], [text(err)])
        opt.None -> element.none()
      },
      form([event.on_submit(fn(_) { CardEditSubmitted })], [
        div([attribute.class("field")], [
          label([], [text(update_helpers.i18n_t(model, i18n_text.CardTitle))]),
          input([
            attribute.type_("text"),
            attribute.value(model.cards_edit_title),
            event.on_input(CardEditTitleChanged),
            attribute.required(True),
          ]),
        ]),
        div([attribute.class("field")], [
          label([], [
            text(update_helpers.i18n_t(model, i18n_text.CardDescription)),
          ]),
          input([
            attribute.type_("text"),
            attribute.value(model.cards_edit_description),
            event.on_input(CardEditDescriptionChanged),
          ]),
        ]),
        div([attribute.class("actions")], [
          button(
            [attribute.type_("button"), event.on_click(CardEditCancelled)],
            [text(update_helpers.i18n_t(model, i18n_text.Cancel))],
          ),
          button(
            [
              attribute.type_("submit"),
              attribute.disabled(model.cards_edit_in_flight),
            ],
            [
              text(case model.cards_edit_in_flight {
                True -> update_helpers.i18n_t(model, i18n_text.Working)
                False -> update_helpers.i18n_t(model, i18n_text.Save)
              }),
            ],
          ),
        ]),
      ]),
    ]),
  ])
}

fn view_delete_card_dialog(model: Model, card: Card) -> Element(Msg) {
  div([attribute.class("modal")], [
    div([attribute.class("modal-content")], [
      h3([], [text(update_helpers.i18n_t(model, i18n_text.DeleteCard))]),
      p([], [
        text(update_helpers.i18n_t(
          model,
          i18n_text.CardDeleteConfirm(card.title),
        )),
      ]),
      case model.cards_delete_error {
        opt.Some(err) -> div([attribute.class("error")], [text(err)])
        opt.None -> element.none()
      },
      div([attribute.class("actions")], [
        button([event.on_click(CardDeleteCancelled)], [
          text(update_helpers.i18n_t(model, i18n_text.Cancel)),
        ]),
        button(
          [
            event.on_click(CardDeleteConfirmed),
            attribute.disabled(model.cards_delete_in_flight),
          ],
          [
            text(case model.cards_delete_in_flight {
              True -> update_helpers.i18n_t(model, i18n_text.Removing)
              False -> update_helpers.i18n_t(model, i18n_text.DeleteCard)
            }),
          ],
        ),
      ]),
    ]),
  ])
}
