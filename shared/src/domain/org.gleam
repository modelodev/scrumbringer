//// Organization domain types for ScrumBringer.
////
//// Defines organization user, invite, and invite link structures.
////
//// ## Usage
////
//// ```gleam
//// import shared/domain/org.{type OrgUser, type OrgInvite, type InviteLink}
////
//// let user = OrgUser(id: 1, email: "user@example.com", org_role: "member", created_at: "2024-01-17T12:00:00Z")
//// ```

import gleam/option.{type Option}

// =============================================================================
// Types
// =============================================================================

/// A user in the organization.
///
/// ## Example
///
/// ```gleam
/// OrgUser(id: 1, email: "admin@example.com", org_role: "admin", created_at: "2024-01-17T12:00:00Z")
/// ```
pub type OrgUser {
  OrgUser(id: Int, email: String, org_role: String, created_at: String)
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

/// An invite link for a specific email.
///
/// ## Example
///
/// ```gleam
/// InviteLink(
///   email: "new@example.com",
///   token: "xyz789",
///   url_path: "/accept-invite?token=xyz789",
///   state: "active",
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
    state: String,
    created_at: String,
    used_at: Option(String),
    invalidated_at: Option(String),
  )
}
