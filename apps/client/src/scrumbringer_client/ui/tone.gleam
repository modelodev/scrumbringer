//// Shared semantic tones for UI signals.

/// Semantic visual tone shared by compact UI signals.
pub type Tone {
  Neutral
  Primary
  Available
  Claimed
  Ongoing
  Blocked
  Warning
  Success
  Danger
  Info
}

/// Convert a semantic tone to its CSS modifier class.
pub fn class_name(tone: Tone) -> String {
  case tone {
    Neutral -> "neutral"
    Primary -> "primary"
    Available -> "available"
    Claimed -> "claimed"
    Ongoing -> "ongoing"
    Blocked -> "blocked"
    Warning -> "warning"
    Success -> "success"
    Danger -> "danger"
    Info -> "info"
  }
}
