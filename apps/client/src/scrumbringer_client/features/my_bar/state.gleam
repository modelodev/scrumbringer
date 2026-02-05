//// my_bar feature state types.
////
//// Facade over member state (Phase 1 modularization).

import scrumbringer_client/client_state/member as member_state

/// Represents my_bar model slice (member-scoped).
pub type Model =
  member_state.MemberModel
