import gleam/option
import lustre/element
import support/render_assertions

import domain/org.{type InviteLink, Active, InviteLink}
import domain/remote
import scrumbringer_client/client_state/admin/invites as invites_state
import scrumbringer_client/features/invites/view as invites_view
import scrumbringer_client/i18n/locale

fn invite_link(email: String) -> InviteLink {
  InviteLink(
    email: email,
    token: "token",
    url_path: "/accept-invite?token=token",
    state: Active,
    created_at: "2026-01-01T10:00:00Z",
    used_at: option.None,
    invalidated_at: option.None,
  )
}

fn config(invites: invites_state.Model) -> invites_view.Config(String) {
  invites_view.Config(
    locale: locale.En,
    invites: invites,
    origin: "https://scrumbringer.test",
    on_create_dialog_opened: "open",
    on_create_dialog_closed: "close",
    on_create_submitted: "submit",
    on_email_changed: fn(value) { "email:" <> value },
    on_link_copy_clicked: fn(value) { "copy:" <> value },
    on_link_regenerate_clicked: fn(value) { "regenerate:" <> value },
    on_link_invalidate_clicked: fn(value) { "invalidate:" <> value },
    on_link_invalidate_cancelled: "invalidate-cancel",
    on_link_invalidate_confirmed: "invalidate-confirm",
  )
}

pub fn invites_view_loaded_links_uses_config_data_test() {
  let link = invite_link("new@example.test")
  let state =
    invites_state.Model(
      ..invites_state.default_model(),
      invite_links: remote.Loaded([link]),
      invite_link_last: option.Some(link),
    )

  let html =
    invites_view.view_invites(config(state))
    |> element.to_document_string

  render_assertions.contains(html, "INVITES")
  render_assertions.contains(html, "new@example.test")
  render_assertions.contains(
    html,
    "https://scrumbringer.test/accept-invite?token=token",
  )
  render_assertions.contains(html, "Pending")
}

pub fn invites_view_active_state_uses_spanish_open_copy_test() {
  let link = invite_link("new@example.test")
  let state =
    invites_state.Model(
      ..invites_state.default_model(),
      invite_links: remote.Loaded([link]),
    )

  let html =
    invites_view.view_invites(
      invites_view.Config(..config(state), locale: locale.Es),
    )
    |> element.to_document_string

  render_assertions.contains(html, "Por aceptar")
  render_assertions.not_contains(html, "Draft")
}
