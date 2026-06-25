import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale
import scrumbringer_client/i18n/text

fn assert_equal(actual: String, expected: String) {
  let assert True = actual == expected
}

pub fn people_labels_es_test() {
  i18n.t(locale.Es, text.People) |> assert_equal("Personas")
  i18n.t(locale.Es, text.Busy) |> assert_equal("Ocupado")
  i18n.t(locale.Es, text.Free) |> assert_equal("Libre")
  i18n.t(locale.Es, text.PeopleSearchPlaceholder)
  |> assert_equal("Buscar persona, tarea o tarjeta")
  i18n.t(locale.Es, text.PeopleEmpty)
  |> assert_equal("No hay miembros en este proyecto")
  i18n.t(locale.Es, text.PeopleNoResults)
  |> assert_equal("No hay personas que coincidan con la búsqueda")
  i18n.t(locale.Es, text.PeopleAttentionLabel) |> assert_equal("Atención")
  i18n.t(locale.Es, text.PeopleBusyLabel) |> assert_equal("Con trabajo")
  i18n.t(locale.Es, text.PeopleFreeLabel) |> assert_equal("Disponibles")
  i18n.t(locale.Es, text.PeopleLoading) |> assert_equal("Cargando personas...")
  i18n.t(locale.Es, text.PeopleLoadError)
  |> assert_equal("No se pudieron cargar las personas")
  i18n.t(locale.Es, text.ExpandPerson(name: "Ana"))
  |> assert_equal("Expandir estado de Ana")
  i18n.t(locale.Es, text.CollapsePerson(name: "Ana"))
  |> assert_equal("Colapsar estado de Ana")
}

pub fn people_labels_en_test() {
  i18n.t(locale.En, text.People) |> assert_equal("People")
  i18n.t(locale.En, text.Busy) |> assert_equal("Busy")
  i18n.t(locale.En, text.Free) |> assert_equal("Free")
  i18n.t(locale.En, text.PeopleSearchPlaceholder)
  |> assert_equal("Search person, task, or card")
  i18n.t(locale.En, text.PeopleEmpty)
  |> assert_equal("No members in this project")
  i18n.t(locale.En, text.PeopleNoResults)
  |> assert_equal("No people match your search")
  i18n.t(locale.En, text.PeopleLoading) |> assert_equal("Loading people...")
  i18n.t(locale.En, text.PeopleLoadError)
  |> assert_equal("Could not load people")
  i18n.t(locale.En, text.PeopleAttentionLabel) |> assert_equal("Attention")
  i18n.t(locale.En, text.PeopleBusyLabel) |> assert_equal("With work")
  i18n.t(locale.En, text.PeopleFreeLabel) |> assert_equal("Available")
  i18n.t(locale.En, text.ExpandPerson(name: "Ana"))
  |> assert_equal("Expand status for Ana")
  i18n.t(locale.En, text.CollapsePerson(name: "Ana"))
  |> assert_equal("Collapse status for Ana")
}
