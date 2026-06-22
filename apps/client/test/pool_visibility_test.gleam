import gleam/list

import scrumbringer_client/features/pool/visibility.{
  AllOpen, Blocked, ReadyToClaim,
}
import scrumbringer_client/i18n/locale

pub fn pool_visibility_default_is_all_open_test() {
  let assert AllOpen = visibility.default()
}

pub fn pool_visibility_parse_roundtrip_test() {
  let assert Ok(AllOpen) = visibility.parse(visibility.to_string(AllOpen))
  let assert Ok(ReadyToClaim) =
    visibility.parse(visibility.to_string(ReadyToClaim))
  let assert Ok(Blocked) = visibility.parse(visibility.to_string(Blocked))
}

pub fn pool_visibility_label_roundtrip_test() {
  let items = [
    #(AllOpen, "Abiertas", "Open"),
    #(ReadyToClaim, "Reclamables", "Claimable"),
    #(Blocked, "Bloqueadas", "Blocked"),
  ]

  let assert [
    #(AllOpen, "Abiertas", "Open"),
    #(ReadyToClaim, "Reclamables", "Claimable"),
    #(Blocked, "Bloqueadas", "Blocked"),
  ] =
    list.map(items, fn(item) {
      let #(visibility_item, _, _) = item
      #(
        visibility_item,
        visibility.label(locale.Es, visibility_item),
        visibility.label(locale.En, visibility_item),
      )
    })
}

pub fn pool_visibility_rejects_unknown_test() {
  let assert Error(Nil) = visibility.parse("claimed")
  let assert Error(Nil) = visibility.parse("")
}
