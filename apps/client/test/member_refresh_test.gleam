import domain/remote.{Loading, NotAsked}
import gleam/option as opt
import lustre/effect

import scrumbringer_client/client_state
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/client_state/member/skills as member_skills
import scrumbringer_client/client_update
import scrumbringer_client/member_section
import scrumbringer_client/state/normalized_store

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
      let pool = member.pool

      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_section: member_section.Fichas,
          member_cards: NotAsked,
        ),
      )
    })

  let #(next, fx) =
    client_update.update(model, client_state.ProjectSelected("2"))

  let assert Loading = next.member.pool.member_cards
  let assert 1 = normalized_store.pending(next.member.pool.member_cards_store)
  let assert False = fx == effect.none()
}

pub fn member_refresh_skills_fetches_capabilities_test() {
  let model =
    base_member_model()
    |> client_state.update_core(fn(core) {
      client_state.CoreModel(..core, selected_project_id: opt.None)
    })
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      let skills = member.skills

      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(..pool, member_section: member_section.MySkills),
        skills: member_skills.Model(..skills, member_capabilities: NotAsked),
      )
    })

  let #(next, fx) =
    client_update.update(model, client_state.ProjectSelected("2"))

  let assert Loading = next.member.skills.member_capabilities
  let assert False = fx == effect.none()
}

pub fn member_refresh_pool_fetches_org_users_cache_for_people_labels_test() {
  let model =
    base_member_model()
    |> client_state.update_core(fn(core) {
      client_state.CoreModel(..core, selected_project_id: opt.None)
    })
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(..pool, member_section: member_section.Pool),
      )
    })

  let #(next, _fx) =
    client_update.update(model, client_state.ProjectSelected("2"))

  let assert Loading = next.admin.members.org_users_cache
}
