import gleam/option as opt
import lustre/effect

import domain/api_error.{ApiError}
import domain/org.{type InviteLink, Active, InviteLink}
import domain/remote.{Loaded}
import scrumbringer_client/client_state
import scrumbringer_client/features/admin/invites_route
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/permissions

fn base_model() -> client_state.Model {
  client_state.update_core(client_state.default_model(), fn(core) {
    client_state.CoreModel(
      ..core,
      page: client_state.Admin,
      active_section: permissions.Team,
    )
  })
}

fn invite_link(email: String) -> InviteLink {
  InviteLink(
    email: email,
    token: "token",
    url_path: "/accept-invite?token=token",
    state: Active,
    created_at: "2026-01-01T10:00:00Z",
    used_at: opt.None,
    invalidated_at: opt.None,
  )
}

pub fn try_update_routes_invite_links_fetched_test() {
  let link = invite_link("ana@example.test")

  let assert opt.Some(#(next, fx)) =
    invites_route.try_update(
      base_model(),
      admin_messages.InviteLinksFetched(Ok([link])),
    )

  let assert Loaded([stored]) = next.admin.invites.invite_links
  let assert "ana@example.test" = stored.email
  let assert True = fx == effect.none()
}

pub fn try_update_handles_unauthorized_before_apply_test() {
  let err =
    ApiError(status: 401, code: "UNAUTHORIZED", message: "Sign in again")

  let assert opt.Some(#(next, fx)) =
    invites_route.try_update(
      base_model(),
      admin_messages.InviteLinksFetched(Error(err)),
    )

  let assert client_state.Login = next.core.page
  let assert opt.None = next.core.user
  let assert True = fx == effect.none()
}

pub fn try_update_ignores_non_invite_messages_test() {
  let assert opt.None =
    invites_route.try_update(base_model(), admin_messages.MemberAddDialogOpened)
}
