import gleeunit/should

import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale
import scrumbringer_client/i18n/text

pub fn people_labels_es_test() {
  i18n.t(locale.Es, text.People) |> should.equal("Personas")
  i18n.t(locale.Es, text.Busy) |> should.equal("Ocupado")
  i18n.t(locale.Es, text.Free) |> should.equal("Libre")
  i18n.t(locale.Es, text.PeopleSearchPlaceholder)
  |> should.equal("Buscar persona")
  i18n.t(locale.Es, text.PeopleEmpty)
  |> should.equal("No hay miembros en este proyecto")
  i18n.t(locale.Es, text.PeopleNoResults)
  |> should.equal("No hay personas que coincidan con la busqueda")
  i18n.t(locale.Es, text.PeopleLoading) |> should.equal("Cargando personas...")
  i18n.t(locale.Es, text.PeopleLoadError)
  |> should.equal("No se pudieron cargar las personas")
  i18n.t(locale.Es, text.ExpandPerson(name: "Ana"))
  |> should.equal("Expandir estado de Ana")
  i18n.t(locale.Es, text.CollapsePerson(name: "Ana"))
  |> should.equal("Colapsar estado de Ana")
}

pub fn people_labels_en_test() {
  i18n.t(locale.En, text.People) |> should.equal("People")
  i18n.t(locale.En, text.Busy) |> should.equal("Busy")
  i18n.t(locale.En, text.Free) |> should.equal("Free")
  i18n.t(locale.En, text.PeopleSearchPlaceholder)
  |> should.equal("Search person")
  i18n.t(locale.En, text.PeopleEmpty)
  |> should.equal("No members in this project")
  i18n.t(locale.En, text.PeopleNoResults)
  |> should.equal("No people match your search")
  i18n.t(locale.En, text.PeopleLoading) |> should.equal("Loading people...")
  i18n.t(locale.En, text.PeopleLoadError)
  |> should.equal("Could not load people")
  i18n.t(locale.En, text.ExpandPerson(name: "Ana"))
  |> should.equal("Expand status for Ana")
  i18n.t(locale.En, text.CollapsePerson(name: "Ana"))
  |> should.equal("Collapse status for Ana")
}
