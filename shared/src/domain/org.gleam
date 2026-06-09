//// Organization domain types for ScrumBringer.
////
//// Defines organization user, invite, and invite link structures.
////
//// ## Usage
////
//// ```gleam
//// import shared/domain/org.{type OrgUser, type OrgInvite, type InviteLink}
////
//// let user = OrgUser(id: 1, email: "user@example.com", org_role: Member, created_at: "2024-01-17T12:00:00Z")
//// ```

import domain/org_role.{type OrgRole}
import gleam/option.{type Option}

// =============================================================================
// Types
// =============================================================================

/// A user in the organization.
///
/// ## Example
///
/// ```gleam
/// OrgUser(id: 1, email: "admin@example.com", org_role: Admin, created_at: "2024-01-17T12:00:00Z")
/// ```
pub type OrgUser {
  OrgUser(id: Int, email: String, org_role: OrgRole, created_at: String)
}

/// An organization invite code.
///
/// ## Example
///
/// ```gleam
/// OrgInvite(code: "abc123", created_at: "2024-01-17T12:00:00Z", expires_at: "2024-01-24T12:00:00Z")
/// ```
pub type OrgInvite {
  OrgInvite(code: String, created_at: String, expires_at: String)
}

/// Lifecycle state for an invite link.
pub type InviteLinkState {
  Active
  Used
  Invalidated
}

/// Error returned when an external invite link state cannot be parsed.
pub type InviteLinkStateParseError {
  UnknownInviteLinkState(String)
}

/// An invite link for a specific email.
///
/// ## Example
///
/// ```gleam
/// InviteLink(
///   email: "new@example.com",
///   token: "xyz789",
///   url_path: "/accept-invite?token=xyz789",
///   state: Active,
///   created_at: "2024-01-17T12:00:00Z",
///   used_at: None,
///   invalidated_at: None,
/// )
/// ```
pub type InviteLink {
  InviteLink(
    email: String,
    token: String,
    url_path: String,
    state: InviteLinkState,
    created_at: String,
    used_at: Option(String),
    invalidated_at: Option(String),
  )
}

/// Convert InviteLinkState to its external string representation.
pub fn invite_link_state_to_string(state: InviteLinkState) -> String {
  case state {
    Active -> "active"
    Used -> "used"
    Invalidated -> "invalidated"
  }
}

/// Parse InviteLinkState from an external string.
pub fn parse_invite_link_state(
  value: String,
) -> Result(InviteLinkState, InviteLinkStateParseError) {
  case value {
    "active" -> Ok(Active)
    "used" -> Ok(Used)
    "invalidated" | "expired" -> Ok(Invalidated)
    other -> Error(UnknownInviteLinkState(other))
  }
}

/// Parse InviteLinkState from an external string.
///
/// This function is intentionally strict. Unknown external values must be
/// handled at the boundary instead of being silently normalised.
pub fn invite_link_state_from_string(
  value: String,
) -> Result(InviteLinkState, InviteLinkStateParseError) {
  parse_invite_link_state(value)
}
