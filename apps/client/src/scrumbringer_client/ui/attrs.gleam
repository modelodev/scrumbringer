//// Shared attribute helpers for common UI classes.

import lustre/attribute.{type Attribute}

/// Section wrapper class.
pub fn section() -> Attribute(msg) {
  attribute.class("section")
}

/// Empty state wrapper class.
pub fn empty() -> Attribute(msg) {
  attribute.class("empty")
}

/// Error message wrapper class.
pub fn error() -> Attribute(msg) {
  attribute.class("error")
}
