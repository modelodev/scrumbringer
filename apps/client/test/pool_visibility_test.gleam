import scrumbringer_client/features/pool/visibility.{
  AllOpen, Blocked, ReadyToClaim,
}

pub fn pool_visibility_default_is_all_open_test() {
  let assert AllOpen = visibility.default()
}

pub fn pool_visibility_parse_roundtrip_test() {
  let assert Ok(AllOpen) = visibility.parse(visibility.to_string(AllOpen))
  let assert Ok(ReadyToClaim) =
    visibility.parse(visibility.to_string(ReadyToClaim))
  let assert Ok(Blocked) = visibility.parse(visibility.to_string(Blocked))
}

pub fn pool_visibility_rejects_unknown_test() {
  let assert Error(Nil) = visibility.parse("claimed")
  let assert Error(Nil) = visibility.parse("")
}

pub fn pool_visibility_labels_match_product_language_test() {
  let assert "Abiertas" = visibility.label(AllOpen)
  let assert "Reclamables" = visibility.label(ReadyToClaim)
  let assert "Bloqueadas" = visibility.label(Blocked)
}
