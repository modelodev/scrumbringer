import gleam/dict
import gleam/int
import gleam/list
import gleam/option as opt

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, form, input, label, p, span, text}
import lustre/event

import domain/capability.{type Capability}
import domain/project.{type ProjectMember}
import domain/remote.{type Remote, Loaded}

import scrumbringer_client/client_state/admin/capabilities as admin_capabilities
import scrumbringer_client/client_state/admin/members as admin_members
import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/helpers/lookup as helpers_lookup
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/action_buttons
import scrumbringer_client/ui/admin_surface
import scrumbringer_client/ui/badge
import scrumbringer_client/ui/data_table
import scrumbringer_client/ui/dialog
import scrumbringer_client/ui/form_field
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/section_header

pub type Config(msg) {
  Config(
    locale: Locale,
    capabilities: admin_capabilities.Model,
    members: admin_members.Model,
    selected_project_name: String,
    on_create_opened: msg,
    on_create_closed: msg,
    on_create_name_changed: fn(String) -> msg,
    on_create_submitted: msg,
    on_edit_opened: fn(Int, String) -> msg,
    on_edit_closed: msg,
    on_edit_name_changed: fn(String) -> msg,
    on_edit_submitted: msg,
    on_delete_opened: fn(Int) -> msg,
    on_delete_closed: msg,
    on_delete_submitted: msg,
    on_members_opened: fn(Int) -> msg,
    on_members_closed: msg,
    on_member_toggled: fn(Int) -> msg,
    on_members_save_clicked: msg,
  )
}

pub fn view(config: Config(msg)) -> Element(msg) {
  admin_surface.view(
    section_header.view_with_action(
      icons.Crosshairs,
      t(config, i18n_text.Capabilities),
      dialog.add_button_with_locale(
        config.locale,
        i18n_text.CreateCapability,
        config.on_create_opened,
      ),
    ),
    view_list(config, config.capabilities.capabilities),
    [
      view_create_dialog(config),
      case config.capabilities.capability_members_dialog_capability_id {
        opt.Some(capability_id) -> view_members_dialog(config, capability_id)
        opt.None -> element.none()
      },
      view_edit_dialog(config),
      view_delete_dialog(config),
    ],
  )
}

fn view_create_dialog(config: Config(msg)) -> Element(msg) {
  let is_open = case config.capabilities.capabilities_dialog_mode {
    dialog_mode.DialogCreate -> True
    _ -> False
  }

  dialog.view(
    dialog.DialogConfig(
      title: t(config, i18n_text.CreateCapability),
      icon: opt.None,
      size: dialog.DialogSm,
      on_close: config.on_create_closed,
    ),
    is_open,
    config.capabilities.capabilities_create_error,
    [
      form(
        [
          event.on_submit(fn(_) { config.on_create_submitted }),
          attribute.id("capability-create-form"),
        ],
        [
          form_field.view(
            t(config, i18n_text.Name),
            input([
              attribute.type_("text"),
              attribute.value(config.capabilities.capabilities_create_name),
              event.on_input(config.on_create_name_changed),
              attribute.required(True),
              attribute.placeholder(t(
                config,
                i18n_text.CapabilityNamePlaceholder,
              )),
              attribute.attribute("aria-label", "Capability name"),
            ]),
          ),
        ],
      ),
    ],
    [
      dialog.cancel_button_with_locale(config.locale, config.on_create_closed),
      button(
        [
          attribute.type_("submit"),
          attribute.form("capability-create-form"),
          attribute.disabled(config.capabilities.capabilities_create_in_flight),
          attribute.class(
            case config.capabilities.capabilities_create_in_flight {
              True -> "btn-loading"
              False -> ""
            },
          ),
        ],
        [
          text(case config.capabilities.capabilities_create_in_flight {
            True -> t(config, i18n_text.Creating)
            False -> t(config, i18n_text.Create)
          }),
        ],
      ),
    ],
  )
}

fn view_edit_dialog(config: Config(msg)) -> Element(msg) {
  let is_open = case config.capabilities.capabilities_dialog_mode {
    dialog_mode.DialogEdit -> True
    _ -> False
  }

  dialog.view(
    dialog.DialogConfig(
      title: t(config, i18n_text.EditCapability),
      icon: opt.None,
      size: dialog.DialogSm,
      on_close: config.on_edit_closed,
    ),
    is_open,
    config.capabilities.capability_edit_error,
    [
      form(
        [
          event.on_submit(fn(_) { config.on_edit_submitted }),
          attribute.id("capability-edit-form"),
        ],
        [
          form_field.view(
            t(config, i18n_text.Name),
            input([
              attribute.type_("text"),
              attribute.value(config.capabilities.capability_edit_name),
              event.on_input(config.on_edit_name_changed),
              attribute.required(True),
              attribute.placeholder(t(
                config,
                i18n_text.CapabilityNamePlaceholder,
              )),
              attribute.attribute("aria-label", "Capability name"),
            ]),
          ),
        ],
      ),
    ],
    [
      dialog.cancel_button_with_locale(config.locale, config.on_edit_closed),
      button(
        [
          attribute.type_("submit"),
          attribute.form("capability-edit-form"),
          attribute.disabled(config.capabilities.capability_edit_in_flight),
          attribute.class(case config.capabilities.capability_edit_in_flight {
            True -> "btn-loading"
            False -> ""
          }),
        ],
        [
          text(case config.capabilities.capability_edit_in_flight {
            True -> t(config, i18n_text.Saving)
            False -> t(config, i18n_text.Save)
          }),
        ],
      ),
    ],
  )
}

fn view_delete_dialog(config: Config(msg)) -> Element(msg) {
  let capability_name = case config.capabilities.capability_delete_dialog_id {
    opt.Some(id) ->
      resolve_capability_name(config.capabilities.capabilities, id)
      |> capability_name_or_empty
    opt.None -> ""
  }

  dialog.view(
    dialog.DialogConfig(
      title: t(config, i18n_text.DeleteCapability),
      icon: opt.None,
      size: dialog.DialogSm,
      on_close: config.on_delete_closed,
    ),
    opt.is_some(config.capabilities.capability_delete_dialog_id),
    config.capabilities.capability_delete_error,
    [
      p([], [
        text(t(config, i18n_text.ConfirmDeleteCapability(capability_name))),
      ]),
    ],
    [
      dialog.cancel_button_with_locale(config.locale, config.on_delete_closed),
      button(
        [
          attribute.type_("button"),
          attribute.class("btn btn-danger"),
          attribute.disabled(config.capabilities.capability_delete_in_flight),
          event.on_click(config.on_delete_submitted),
        ],
        [
          text(case config.capabilities.capability_delete_in_flight {
            True -> t(config, i18n_text.Deleting)
            False -> t(config, i18n_text.Delete)
          }),
        ],
      ),
    ],
  )
}

fn view_list(
  config: Config(msg),
  capabilities: Remote(List(Capability)),
) -> Element(msg) {
  let get_member_count = fn(cap_id: Int) -> Int {
    case dict.get(config.capabilities.capability_members_cache, cap_id) {
      Ok(ids) -> list.length(ids)
      Error(_) -> 0
    }
  }

  data_table.view_remote_with_forbidden(
    capabilities,
    loading_msg: t(config, i18n_text.LoadingEllipsis),
    empty_msg: t(config, i18n_text.NoCapabilitiesYet),
    forbidden_msg: t(config, i18n_text.NotPermitted),
    config: data_table.new()
      |> data_table.with_columns([
        data_table.column(t(config, i18n_text.Name), fn(c: Capability) {
          text(c.name)
        }),
        data_table.column_with_class(
          t(config, i18n_text.AdminMembers),
          fn(c: Capability) {
            badge.new_unchecked(
              int.to_string(get_member_count(c.id)),
              badge.Neutral,
            )
            |> badge.view_with_class("count-badge")
          },
          "col-number",
          "cell-number",
        ),
        data_table.column_with_class(
          t(config, i18n_text.Actions),
          fn(c: Capability) {
            div([attribute.class("btn-group")], [
              action_buttons.edit_button_with_testid(
                t(config, i18n_text.EditCapability),
                config.on_edit_opened(c.id, c.name),
                "capability-edit-btn",
              ),
              action_buttons.settings_button_with_testid(
                t(config, i18n_text.ManageMembers),
                config.on_members_opened(c.id),
                "capability-members-btn",
              ),
              action_buttons.delete_button_with_testid(
                t(config, i18n_text.Delete),
                config.on_delete_opened(c.id),
                "capability-delete-btn",
              ),
            ])
          },
          "col-actions",
          "cell-actions",
        ),
      ])
      |> data_table.with_key(fn(c: Capability) { int.to_string(c.id) }),
  )
}

fn view_members_dialog(config: Config(msg), capability_id: Int) -> Element(msg) {
  let capability_name =
    resolve_capability_name(config.capabilities.capabilities, capability_id)
    |> capability_name_or_id(capability_id)

  let members = case config.members.members {
    Loaded(ms) -> ms
    _ -> []
  }

  dialog.view(
    dialog.DialogConfig(
      title: t(
        config,
        i18n_text.MembersForCapability(
          capability_name,
          config.selected_project_name,
        ),
      ),
      icon: opt.None,
      size: dialog.DialogMd,
      on_close: config.on_members_closed,
    ),
    True,
    config.capabilities.capability_members_error,
    [
      div([attribute.class("members-dialog")], [
        case config.capabilities.capability_members_loading {
          True ->
            div([attribute.class("loading")], [
              text(t(config, i18n_text.LoadingEllipsis)),
            ])
          False -> view_members_checklist(config, members)
        },
      ]),
    ],
    [
      dialog.cancel_button_with_locale(config.locale, config.on_members_closed),
      button(
        [
          attribute.class("btn-primary"),
          event.on_click(config.on_members_save_clicked),
          attribute.disabled(
            config.capabilities.capability_members_saving
            || config.capabilities.capability_members_loading,
          ),
        ],
        [
          text(case config.capabilities.capability_members_saving {
            True -> t(config, i18n_text.Saving)
            False -> t(config, i18n_text.Save)
          }),
        ],
      ),
    ],
  )
}

fn view_members_checklist(
  config: Config(msg),
  members: List(ProjectMember),
) -> Element(msg) {
  case members {
    [] ->
      div([attribute.class("empty")], [
        text(t(config, i18n_text.NoMembersDefined)),
      ])
    _ ->
      div(
        [
          attribute.class("members-checklist"),
          attribute.attribute("data-testid", "members-checklist"),
        ],
        list.map(members, fn(member) { view_member_checkbox(config, member) }),
      )
  }
}

fn view_member_checkbox(
  config: Config(msg),
  member: ProjectMember,
) -> Element(msg) {
  let email = case
    helpers_lookup.resolve_org_user(
      config.members.org_users_cache,
      member.user_id,
    )
  {
    opt.Some(user) -> user.email
    opt.None -> t(config, i18n_text.UserNumber(member.user_id))
  }
  let is_selected =
    list.contains(
      config.capabilities.capability_members_selected,
      member.user_id,
    )

  label(
    [
      attribute.class("checkbox-label"),
      attribute.attribute("data-member-id", int.to_string(member.user_id)),
    ],
    [
      input([
        attribute.type_("checkbox"),
        attribute.checked(is_selected),
        event.on_check(fn(_) { config.on_member_toggled(member.user_id) }),
      ]),
      span([attribute.class("member-email")], [text(email)]),
    ],
  )
}

fn resolve_capability_name(
  capabilities: Remote(List(Capability)),
  capability_id: Int,
) -> opt.Option(String) {
  case capabilities {
    Loaded(caps) ->
      list.find(caps, fn(cap: Capability) { cap.id == capability_id })
      |> opt.from_result
      |> opt.map(fn(cap) { cap.name })

    _ -> opt.None
  }
}

fn capability_name_or_empty(name: opt.Option(String)) -> String {
  case name {
    opt.None -> ""
    opt.Some(value) -> value
  }
}

fn capability_name_or_id(name: opt.Option(String), capability_id: Int) -> String {
  case name {
    opt.None -> "Capability #" <> int.to_string(capability_id)
    opt.Some(value) -> value
  }
}

fn t(config: Config(msg), key: i18n_text.Text) -> String {
  i18n.t(config.locale, key)
}
