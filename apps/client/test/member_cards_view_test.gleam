import domain/remote.{NotAsked}
import gleam/option as opt
import lustre/element
import scrumbringer_client/client_state
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/cards/view as cards_view
import scrumbringer_client/features/cards/view_config as cards_view_config
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/state/normalized_store
import support/render_assertions

fn cards_config(model: client_state.Model) {
  cards_view_config.from_state(
    model.ui.locale,
    [],
    model.member.pool,
    model.member.card_show_model,
    model.member.card_show_open,
    opt.None,
    model.core.user,
    opt.None,
    fn(_) { "open" },
    fn(_) { "card-show-msg" },
  )
}

pub fn cards_view_shows_empty_state_for_member_cards_test() {
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
    |> cards_config
    |> cards_view.view_cards
    |> element.to_document_string

  let expected = i18n.t(model.ui.locale, i18n_text.MemberCardsEmpty)
  render_assertions.contains(html, expected)
}
