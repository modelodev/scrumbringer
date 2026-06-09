import scrumbringer_client/ui/badge

pub fn new_truncated_truncates_valid_text_test() {
  let assert Ok(result) = badge.new_truncated("Long status", badge.Neutral, 4)

  let assert "Long…" = badge.get_text(result)
  let assert badge.Neutral = badge.get_variant(result)
}

pub fn new_truncated_rejects_empty_text_test() {
  let assert Error("Badge text cannot be empty") =
    badge.new_truncated("   ", badge.Warning, 8)
}
