import gleam/option as opt
import lustre/effect

import domain/api_error.{ApiError}
import domain/capability.{Capability}
import domain/remote.{Loaded}
import scrumbringer_client/client_state
import scrumbringer_client/features/admin/capabilities_route
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/permissions

fn base_model() -> client_state.Model {
  client_state.update_core(client_state.default_model(), fn(core) {
    client_state.CoreModel(
      ..core,
      page: client_state.Admin,
      active_section: permissions.Capabilities,
    )
  })
}

pub fn try_update_routes_capability_messages_test() {
  let capability = Capability(id: 1, name: "Backend")

  let assert opt.Some(#(next, fx)) =
    capabilities_route.try_update(
      base_model(),
      admin_messages.CapabilitiesFetched(Ok([capability])),
    )

  let assert Loaded([stored]) = next.admin.capabilities.capabilities
  let assert 1 = stored.id
  let assert "Backend" = stored.name
  let assert True = fx == effect.none()
}

pub fn try_update_ignores_non_capability_messages_test() {
  let assert opt.None =
    capabilities_route.try_update(
      base_model(),
      admin_messages.MemberAddDialogOpened,
    )
}

pub fn try_update_handles_unauthorized_before_apply_test() {
  let err =
    ApiError(status: 401, code: "UNAUTHORIZED", message: "Sign in again")

  let assert opt.Some(#(next, fx)) =
    capabilities_route.try_update(
      base_model(),
      admin_messages.CapabilitiesFetched(Error(err)),
    )

  let assert client_state.Login = next.core.page
  let assert opt.None = next.core.user
  let assert True = fx == effect.none()
}
