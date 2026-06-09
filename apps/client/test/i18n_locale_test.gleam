import scrumbringer_client/i18n/locale

pub fn locale_normalize_language_es_variants_test() {
  let assert locale.Es = locale.normalize_language("es")
  let assert locale.Es = locale.normalize_language("es-ES")
  let assert locale.Es = locale.normalize_language("ES-ar")
}

pub fn locale_normalize_language_defaults_to_en_test() {
  let assert locale.En = locale.normalize_language("en")
  let assert locale.En = locale.normalize_language("en-US")
  let assert locale.En = locale.normalize_language("fr-FR")
  let assert locale.En = locale.normalize_language("")
}

pub fn locale_serialize_roundtrip_test() {
  let assert Ok(locale.Es) =
    locale.Es
    |> locale.serialize
    |> locale.parse
  let assert Ok(locale.En) =
    locale.En
    |> locale.serialize
    |> locale.parse
}

pub fn locale_parse_invalid_returns_error_test() {
  let assert Error(locale.InvalidLocale("fr-fr")) = locale.parse("fr-FR")
}

pub fn locale_decode_storage_invalid_preserves_value_test() {
  let assert locale.LocaleInvalid("fr-fr") = locale.decode_storage("fr-FR")
}
