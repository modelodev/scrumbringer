//// Invite links admin view.
////
//// ## Mission
////
//// Renders the invite links management UI for org admins.
////
//// ## Responsibilities
////
//// - Invite link creation form via modal dialog
//// - Latest invite link display with copy button
//// - Invite links list table with actions
////
//// ## Relations
////
//// - **client_view.gleam**: Dispatches to view_invites from admin section
//// - **features/invites/update.gleam**: Handles invite link messages

import gleam/option as opt

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, form, h3, input, text}
import lustre/event

import domain/org.{
  type InviteLink, type InviteLinkState, Active, Invalidated, Used,
}
import scrumbringer_client/client_state/admin/invites as invites_state
import scrumbringer_client/client_state/types.{
  DialogClosed, DialogOpen, Error, InFlight,
}
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/action_buttons
import scrumbringer_client/ui/badge
import scrumbringer_client/ui/button as ui_button
import scrumbringer_client/ui/confirm_dialog
import scrumbringer_client/ui/copyable_input
import scrumbringer_client/ui/data_table
import scrumbringer_client/ui/dialog
import scrumbringer_client/ui/form_field
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/section_header
import scrumbringer_client/utils/format_date

// =============================================================================
// Public API
// =============================================================================

pub type Config(msg) {
  Config(
    locale: Locale,
    invites: invites_state.Model,
    origin: String,
    on_create_dialog_opened: msg,
    on_create_dialog_closed: msg,
    on_create_submitted: msg,
    on_email_changed: fn(String) -> msg,
    on_link_copy_clicked: fn(String) -> msg,
    on_link_regenerate_clicked: fn(String) -> msg,
    on_link_invalidate_clicked: fn(String) -> msg,
    on_link_invalidate_cancelled: msg,
    on_link_invalidate_confirmed: msg,
  )
}

/// Main invite links section view.
pub fn view_invites(config: Config(msg)) -> Element(msg) {
  div([attribute.class("section")], [
    // Section header with add button (Story 4.8: consistent icons)
    section_header.view_with_action(
      icons.Invites,
      t(config, i18n_text.InvitesTitle),
      dialog.add_button_with_locale(
        config.locale,
        i18n_text.CreateInviteLink,
        config.on_create_dialog_opened,
      ),
    ),
    // Latest invite link result (if any)
    view_latest_invite(config),
    // Invite links list
    view_invite_links_list(config),
    view_invalidate_confirm(config),
    // Create dialog
    view_create_dialog(config),
  ])
}

// =============================================================================
// Private Helpers
// =============================================================================

fn view_latest_invite(config: Config(msg)) -> Element(msg) {
  case config.invites.invite_link_last {
    opt.None -> element.none()

    opt.Some(link) -> {
      let full = build_full_url(config.origin, link.url_path)

      div([attribute.class("invite-result")], [
        h3([], [
          text(t(config, i18n_text.LatestInviteLink)),
        ]),
        form_field.view_required(
          t(config, i18n_text.EmailLabel),
          input([
            attribute.type_("text"),
            attribute.value(link.email),
            attribute.readonly(True),
          ]),
        ),
        copyable_input.view(
          t(config, i18n_text.Link),
          full,
          config.on_link_copy_clicked(full),
          t(config, i18n_text.Copy),
          config.invites.invite_link_copy_status,
        ),
      ])
    }
  }
}

fn view_invite_links_list(config: Config(msg)) -> Element(msg) {
  let translate = fn(key) { t(config, key) }
  let #(_open, _email, _error, in_flight) = invite_dialog_info(config.invites)

  data_table.view_remote(
    config.invites.invite_links,
    loading_msg: translate(i18n_text.LoadingEllipsis),
    empty_msg: translate(i18n_text.NoInviteLinksYet),
    config: data_table.new()
      |> data_table.with_error_prefix(translate(
        i18n_text.FailedToLoadInviteLinksPrefix,
      ))
      |> data_table.with_columns([
        data_table.column(translate(i18n_text.EmailLabel), fn(link: InviteLink) {
          text(link.email)
        }),
        data_table.column(translate(i18n_text.State), fn(link: InviteLink) {
          badge.status(translate_invite_state(config.locale, link.state))
        }),
        data_table.column(translate(i18n_text.CreatedAt), fn(link: InviteLink) {
          text(format_date.date_only(link.created_at))
        }),
        data_table.column_with_class(
          translate(i18n_text.Link),
          fn(link: InviteLink) {
            let full = build_full_url(config.origin, link.url_path)
            action_buttons.task_icon_button(
              translate(i18n_text.CopyLink),
              config.on_link_copy_clicked(full),
              icons.Copy,
              action_buttons.SizeXs,
              in_flight,
              "",
              opt.None,
              opt.None,
            )
          },
          "col-actions",
          "cell-actions",
        ),
        data_table.column_with_class(
          translate(i18n_text.Actions),
          fn(link: InviteLink) { view_invite_actions(config, link, in_flight) },
          "col-actions",
          "cell-actions",
        ),
      ])
      |> data_table.with_key(fn(link: InviteLink) { link.email }),
  )
}

fn view_invite_actions(
  config: Config(msg),
  link: InviteLink,
  in_flight: Bool,
) -> Element(msg) {
  let invalidate_in_flight =
    config.invites.invite_link_invalidate_in_flight == opt.Some(link.email)

  div([attribute.class("action-buttons")], [
    action_buttons.task_icon_button(
      t(config, i18n_text.Regenerate),
      config.on_link_regenerate_clicked(link.email),
      icons.Refresh,
      action_buttons.SizeXs,
      in_flight || invalidate_in_flight,
      "",
      opt.None,
      opt.None,
    ),
    case link.state {
      Active ->
        action_buttons.task_icon_button(
          t(config, i18n_text.InvalidateInvite),
          config.on_link_invalidate_clicked(link.email),
          icons.Trash,
          action_buttons.SizeXs,
          in_flight || invalidate_in_flight,
          "",
          opt.None,
          opt.None,
        )
      Used | Invalidated -> element.none()
    },
  ])
}

fn view_invalidate_confirm(config: Config(msg)) -> Element(msg) {
  case config.invites.invite_link_invalidate_confirm {
    opt.None -> element.none()
    opt.Some(email) ->
      confirm_dialog.view(confirm_dialog.ConfirmConfig(
        title: t(config, i18n_text.InvalidateInvite),
        body: [text(t(config, i18n_text.InvalidateInviteConfirm(email)))],
        confirm_label: t(config, i18n_text.InvalidateInvite),
        cancel_label: t(config, i18n_text.Cancel),
        on_confirm: config.on_link_invalidate_confirmed,
        on_cancel: config.on_link_invalidate_cancelled,
        is_open: True,
        is_loading: config.invites.invite_link_invalidate_in_flight
          == opt.Some(email),
        error: opt.None,
        confirm_intent: ui_button.Danger,
      ))
  }
}

fn view_create_dialog(config: Config(msg)) -> Element(msg) {
  let #(open, email, error, in_flight) = invite_dialog_info(config.invites)
  dialog.view(
    dialog.DialogConfig(
      title: t(config, i18n_text.CreateInviteLink),
      icon: opt.None,
      size: dialog.DialogMd,
      on_close: config.on_create_dialog_closed,
    ),
    open,
    error,
    [
      form(
        [
          event.on_submit(fn(_) { config.on_create_submitted }),
        ],
        [
          form_field.view(
            t(config, i18n_text.EmailLabel),
            input([
              attribute.type_("email"),
              attribute.value(email),
              event.on_input(fn(value) { config.on_email_changed(value) }),
              attribute.required(True),
              attribute.placeholder(t(config, i18n_text.EmailPlaceholderExample)),
            ]),
          ),
          div([attribute.class("dialog-footer")], [
            dialog.cancel_button_with_locale(
              config.locale,
              config.on_create_dialog_closed,
            ),
            dialog.submit_button_with_locale(
              config.locale,
              in_flight,
              False,
              i18n_text.Create,
              i18n_text.Creating,
            ),
          ]),
        ],
      ),
    ],
    [],
  )
}

fn invite_dialog_info(
  invites: invites_state.Model,
) -> #(Bool, String, opt.Option(String), Bool) {
  let #(open, email, operation) = case invites.invite_link_dialog {
    DialogOpen(
      form: invites_state.InviteLinkForm(email: email),
      operation: operation,
    ) -> #(True, email, operation)
    DialogClosed(operation: operation) -> #(False, "", operation)
  }

  let error = case operation {
    Error(message) -> opt.Some(message)
    _ -> opt.None
  }

  let in_flight = operation == InFlight

  #(open, email, error, in_flight)
}

fn build_full_url(origin: String, url_path: String) -> String {
  case origin {
    "" -> url_path
    _ -> origin <> url_path
  }
}

// =============================================================================
// Invite State Helpers (Story 4.8)
// =============================================================================

/// Translate invite link state to current locale.
fn translate_invite_state(locale: Locale, state: InviteLinkState) -> String {
  case state {
    Active -> i18n.t(locale, i18n_text.InviteStateActive)
    Used -> i18n.t(locale, i18n_text.InviteStateUsed)
    Invalidated -> i18n.t(locale, i18n_text.InviteStateExpired)
  }
}

fn t(config: Config(msg), text: i18n_text.Text) -> String {
  i18n.t(config.locale, text)
}
