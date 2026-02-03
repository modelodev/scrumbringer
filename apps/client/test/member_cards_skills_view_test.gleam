import domain/remote.{Loaded, NotAsked}
import gleam/string
import gleeunit/should
import lustre/element
import scrumbringer_client/client_state
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/features/fichas/view as fichas_view
import scrumbringer_client/features/skills/view as skills_view
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/state/normalized_store
import scrumbringer_client/update_helpers

pub fn fichas_view_shows_empty_state_for_member_cards_test() {
  let model =
    client_state.default_model()
    |> client_state.update_member(fn(member) {
      member_state.MemberModel(
        ..member,
        member_cards_store: normalized_store.new(),
        member_cards: NotAsked,
      )
    })

  let html =
    fichas_view.view_fichas(model)
    |> element.to_document_string

  let expected = update_helpers.i18n_t(model, i18n_text.MemberFichasEmpty)
  string.contains(html, expected) |> should.be_true
}

pub fn skills_view_shows_empty_state_for_member_capabilities_test() {
  let model =
    client_state.default_model()
    |> client_state.update_member(fn(member) {
      member_state.MemberModel(..member, member_capabilities: Loaded([]))
    })

  let html =
    skills_view.view_skills(model)
    |> element.to_document_string

  let expected = update_helpers.i18n_t(model, i18n_text.NoCapabilitiesYet)
  string.contains(html, expected) |> should.be_true
}
