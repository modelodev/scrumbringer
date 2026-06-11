import gleam/int
import gleam/option as opt

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, option, p, select, text}
import lustre/event

import domain/org.{type OrgUser}
import domain/org_role.{type OrgRole}
import domain/remote.{Failed, Loaded, Loading, NotAsked}

import scrumbringer_client/client_state/admin/members as admin_members
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/action_buttons
import scrumbringer_client/ui/admin_surface
import scrumbringer_client/ui/data_table
import scrumbringer_client/ui/dialog
import scrumbringer_client/ui/error_notice
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/section_header
import scrumbringer_client/ui/skeleton

pub type Config(msg) {
  Config(
    locale: Locale,
    model: admin_members.Model,
    current_user_id: opt.Option(Int),
    on_role_changed: fn(Int, OrgRole) -> msg,
    on_invalid_role: msg,
    on_delete_clicked: fn(Int) -> msg,
    on_delete_cancelled: msg,
    on_delete_confirmed: msg,
  )
}

pub fn view(config: Config(msg)) -> Element(msg) {
  admin_surface.view(
    section_header.view_with_subtitle(
      icons.OrgUsers,
      t(config, i18n_text.OrgUsers),
      t(config, i18n_text.OrgSettingsHelp),
    ),
    view_table(config),
    [view_delete_dialog(config)],
  )
}

fn view_table(config: Config(msg)) -> Element(msg) {
  case config.model.org_settings_users {
    NotAsked ->
      div([attribute.class("empty")], [
        text(t(config, i18n_text.OpenThisSectionToLoadUsers)),
      ])

    Loading -> skeleton.skeleton_table(5)

    Failed(err) -> error_notice.view(err.message)

    Loaded(users) ->
      data_table.new()
      |> data_table.with_columns([
        data_table.column(t(config, i18n_text.EmailLabel), fn(u: OrgUser) {
          text(u.email)
        }),
        data_table.column(t(config, i18n_text.OrgRole), fn(u: OrgUser) {
          view_role_cell(config, u)
        }),
        data_table.column_with_class(
          t(config, i18n_text.Actions),
          fn(u: OrgUser) {
            action_buttons.task_icon_button_with_class(
              t(config, i18n_text.DeleteUser),
              config.on_delete_clicked(u.id),
              icons.Trash,
              icons.Small,
              is_current_user(config, u.id)
                || config.model.org_settings_delete_in_flight,
              "btn-icon btn-xs btn-danger-icon",
              opt.None,
              opt.Some("org-user-delete-btn"),
            )
          },
          "col-actions",
          "cell-actions",
        ),
      ])
      |> data_table.with_rows(users, fn(u: OrgUser) { int.to_string(u.id) })
      |> data_table.view()
  }
}

fn view_delete_dialog(config: Config(msg)) -> Element(msg) {
  case config.model.org_settings_delete_confirm {
    opt.None -> element.none()
    opt.Some(user) ->
      dialog.view(
        dialog.DialogConfig(
          title: t(config, i18n_text.DeleteUser),
          icon: opt.None,
          size: dialog.DialogSm,
          on_close: config.on_delete_cancelled,
        ),
        True,
        config.model.org_settings_delete_error,
        [
          p([], [
            text(t(config, i18n_text.ConfirmDeleteUser(user.email))),
          ]),
        ],
        [
          dialog.cancel_button_with_locale(
            config.locale,
            config.on_delete_cancelled,
          ),
          button(
            [
              attribute.type_("button"),
              attribute.class("btn btn-danger"),
              attribute.disabled(config.model.org_settings_delete_in_flight),
              event.on_click(config.on_delete_confirmed),
            ],
            [
              text(case config.model.org_settings_delete_in_flight {
                True -> t(config, i18n_text.Deleting)
                False -> t(config, i18n_text.Delete)
              }),
            ],
          ),
        ],
      )
  }
}

fn view_role_cell(config: Config(msg), u: OrgUser) -> Element(msg) {
  let current_role = u.org_role
  let current_role_string = org_role.to_string(current_role)

  let inline_error = case
    config.model.org_settings_error_user_id,
    config.model.org_settings_error
  {
    opt.Some(id), opt.Some(message) if id == u.id -> message
    _, _ -> ""
  }

  element.fragment([
    select(
      [
        attribute.value(current_role_string),
        attribute.disabled(config.model.org_settings_save_in_flight),
        event.on_input(fn(value) {
          case org_role.parse(value) {
            Ok(role) -> config.on_role_changed(u.id, role)
            Error(_) -> config.on_invalid_role
          }
        }),
      ],
      [
        option(
          [
            attribute.value("admin"),
            attribute.selected(current_role == org_role.Admin),
          ],
          t(config, i18n_text.RoleAdmin),
        ),
        option(
          [
            attribute.value("member"),
            attribute.selected(current_role == org_role.Member),
          ],
          t(config, i18n_text.RoleMember),
        ),
      ],
    ),
    case inline_error == "" {
      True -> element.none()
      False -> error_notice.view(inline_error)
    },
  ])
}

fn is_current_user(config: Config(msg), user_id: Int) -> Bool {
  case config.current_user_id {
    opt.Some(current_user_id) -> current_user_id == user_id
    opt.None -> False
  }
}

fn t(config: Config(msg), key: i18n_text.Text) -> String {
  i18n.t(config.locale, key)
}
