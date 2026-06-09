import domain/remote.{Loaded, NotAsked}
import gleam/dict
import gleam/option as opt
import gleam/string
import lustre/element
import scrumbringer_client/client_state
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/fichas/view as fichas_view
import scrumbringer_client/features/fichas/view_config as fichas_view_config
import scrumbringer_client/features/skills/view as skills_view
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/state/normalized_store

fn assert_contains(text: String, fragment: String) {
  let assert True = string.contains(text, fragment)
}

fn fichas_config(model: client_state.Model) {
  fichas_view_config.from_state(
    model.ui.locale,
    [],
    model.member.pool,
    opt.None,
    model.core.user,
    opt.None,
    fn(_) { "open" },
    fn(_) { "create" },
    "close",
  )
}

pub fn fichas_view_shows_empty_state_for_member_cards_test() {
  let model =
    client_state.default_model()
    |> client_state.update_member(fn(member) {
      let pool = member.pool

      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_cards_store: normalized_store.new(),
          member_cards: NotAsked,
        ),
      )
    })

  let html =
    model
    |> fichas_config
    |> fichas_view.view_fichas
    |> element.to_document_string

  let expected = i18n.t(model.ui.locale, i18n_text.MemberFichasEmpty)
  assert_contains(html, expected)
}

pub fn skills_view_shows_empty_state_for_member_capabilities_test() {
  let config =
    skills_view.Config(
      locale: locale.En,
      capabilities: Loaded([]),
      selected_capability_ids: dict.new(),
      error: opt.None,
      in_flight: False,
      on_save: 0,
      on_capability_toggle: fn(id) { id },
    )

  let html =
    skills_view.view_skills(config)
    |> element.to_document_string

  let expected = i18n.t(locale.En, i18n_text.NoCapabilitiesYet)
  assert_contains(html, expected)
}
