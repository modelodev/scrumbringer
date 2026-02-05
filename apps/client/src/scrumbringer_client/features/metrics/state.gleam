//// Metrics feature state types.
////
//// Facade over admin and member state (Phase 1 modularization).

import scrumbringer_client/client_state/admin as admin_state
import scrumbringer_client/client_state/member as member_state

/// Represents metrics admin slice.
pub type AdminModel =
  admin_state.AdminModel

/// Represents metrics member slice.
pub type MemberModel =
  member_state.MemberModel
