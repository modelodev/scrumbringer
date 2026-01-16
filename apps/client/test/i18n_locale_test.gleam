import gleeunit/should
import scrumbringer_client/i18n/locale

pub fn locale_normalize_language_es_variants_test() {
  locale.normalize_language("es") |> should.equal(locale.Es)
  locale.normalize_language("es-ES") |> should.equal(locale.Es)
  locale.normalize_language("ES-ar") |> should.equal(locale.Es)
}

pub fn locale_normalize_language_defaults_to_en_test() {
  locale.normalize_language("en") |> should.equal(locale.En)
  locale.normalize_language("en-US") |> should.equal(locale.En)
  locale.normalize_language("fr-FR") |> should.equal(locale.En)
  locale.normalize_language("") |> should.equal(locale.En)
}

pub fn locale_serialize_roundtrip_test() {
  locale.Es |> locale.serialize |> locale.deserialize |> should.equal(locale.Es)
  locale.En |> locale.serialize |> locale.deserialize |> should.equal(locale.En)
}
