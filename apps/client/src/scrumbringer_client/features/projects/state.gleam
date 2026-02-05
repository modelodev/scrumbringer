//// projects feature state types.
////
//// Facade over admin state (Phase 1 modularization).

import scrumbringer_client/client_state/admin as admin_state

/// Represents projects model slice (admin-scoped).
pub type Model =
  admin_state.AdminModel
