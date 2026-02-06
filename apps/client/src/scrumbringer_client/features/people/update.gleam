//// People feature update handlers.

import gleam/dict
import gleam/list
import gleam/option
import lustre/effect

import domain/api_error.{type ApiError}
import domain/project.{type ProjectMember}
import domain/remote
import scrumbringer_client/client_state
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/people/state as people_state

pub fn handle_roster_fetched_ok(
  model: client_state.Model,
  members: List(ProjectMember),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let valid_user_ids = list.map(members, fn(m) { m.user_id })
  let next_expansions =
    dict.filter(model.member.pool.people_expansions, fn(user_id, _expansion) {
      list.contains(valid_user_ids, user_id)
    })

  #(
    update_member_pool(model, fn(pool) {
      member_pool.Model(
        ..pool,
        people_roster: remote.Loaded(members),
        people_expansions: next_expansions,
      )
    }),
    effect.none(),
  )
}

pub fn handle_roster_fetched_error(
  model: client_state.Model,
  err: ApiError,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  #(
    update_member_pool(model, fn(pool) {
      member_pool.Model(..pool, people_roster: remote.Failed(err))
    }),
    effect.none(),
  )
}

pub fn handle_row_toggled(
  model: client_state.Model,
  user_id: Int,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let current =
    dict.get(model.member.pool.people_expansions, user_id)
    |> option.from_result
    |> option.unwrap(people_state.Collapsed)

  let next = people_state.toggle(current)
  let next_expansions =
    dict.insert(model.member.pool.people_expansions, user_id, next)

  #(
    update_member_pool(model, fn(pool) {
      member_pool.Model(..pool, people_expansions: next_expansions)
    }),
    effect.none(),
  )
}

fn update_member_pool(
  model: client_state.Model,
  f: fn(member_pool.Model) -> member_pool.Model,
) -> client_state.Model {
  client_state.update_member(model, fn(member) {
    let pool = member.pool
    member_state.MemberModel(..member, pool: f(pool))
  })
}
