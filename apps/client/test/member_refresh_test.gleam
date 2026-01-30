import gleam/option as opt
import gleeunit/should
import lustre/effect

import scrumbringer_client/client_state
import scrumbringer_client/client_update
import scrumbringer_client/member_section

fn base_member_model() -> client_state.Model {
  client_state.default_model()
  |> client_state.update_core(fn(core) {
    client_state.CoreModel(..core, page: client_state.Member)
  })
}

pub fn member_refresh_fichas_fetches_cards_test() {
  let model =
    base_member_model()
    |> client_state.update_core(fn(core) {
      client_state.CoreModel(..core, selected_project_id: opt.None)
    })
    |> client_state.update_member(fn(member) {
      client_state.MemberModel(
        ..member,
        member_section: member_section.Fichas,
        member_cards: client_state.NotAsked,
      )
    })

  let #(next, fx) =
    client_update.update(model, client_state.ProjectSelected("2"))

  next.member.member_cards |> should.equal(client_state.Loading)
  fx |> should.not_equal(effect.none())
}

pub fn member_refresh_skills_fetches_capabilities_test() {
  let model =
    base_member_model()
    |> client_state.update_core(fn(core) {
      client_state.CoreModel(..core, selected_project_id: opt.None)
    })
    |> client_state.update_member(fn(member) {
      client_state.MemberModel(
        ..member,
        member_section: member_section.MySkills,
        member_capabilities: client_state.NotAsked,
      )
    })

  let #(next, fx) =
    client_update.update(model, client_state.ProjectSelected("2"))

  next.member.member_capabilities |> should.equal(client_state.Loading)
  fx |> should.not_equal(effect.none())
}
