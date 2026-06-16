//// People feature update handlers.

import gleam/dict
import gleam/list
import gleam/option
import lustre/effect

import domain/api_error.{type ApiError}
import domain/project.{type ProjectMember}
import domain/remote
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/people/state as people_state
import scrumbringer_client/features/pool/msg as pool_messages

pub fn try_update(
  model: member_pool.Model,
  inner: pool_messages.Msg,
) -> option.Option(#(member_pool.Model, effect.Effect(parent_msg))) {
  case inner {
    pool_messages.MemberPeopleRosterFetched(Ok(members)) ->
      option.Some(handle_roster_fetched_ok(model, members))
    pool_messages.MemberPeopleRosterFetched(Error(err)) ->
      option.Some(handle_roster_fetched_error(model, err))
    pool_messages.MemberPeopleRowToggled(user_id) ->
      option.Some(handle_row_toggled(model, user_id))
    _ -> option.None
  }
}

fn handle_roster_fetched_ok(
  model: member_pool.Model,
  members: List(ProjectMember),
) -> #(member_pool.Model, effect.Effect(parent_msg)) {
  let valid_user_ids = list.map(members, fn(m) { m.user_id })
  let next_expansions =
    dict.filter(model.people_expansions, fn(user_id, _expansion) {
      list.contains(valid_user_ids, user_id)
    })

  #(
    member_pool.Model(
      ..model,
      people_roster: remote.Loaded(members),
      people_expansions: next_expansions,
    ),
    effect.none(),
  )
}

fn handle_roster_fetched_error(
  model: member_pool.Model,
  err: ApiError,
) -> #(member_pool.Model, effect.Effect(parent_msg)) {
  #(
    member_pool.Model(..model, people_roster: remote.Failed(err)),
    effect.none(),
  )
}

fn handle_row_toggled(
  model: member_pool.Model,
  user_id: Int,
) -> #(member_pool.Model, effect.Effect(parent_msg)) {
  let current =
    dict.get(model.people_expansions, user_id)
    |> option.from_result
    |> people_expansion_or_default

  let next = people_state.toggle(current)
  let next_expansions = dict.insert(model.people_expansions, user_id, next)

  #(
    member_pool.Model(..model, people_expansions: next_expansions),
    effect.none(),
  )
}

fn people_expansion_or_default(
  expansion: option.Option(people_state.RowExpansion),
) -> people_state.RowExpansion {
  case expansion {
    option.None -> people_state.Collapsed
    option.Some(value) -> value
  }
}
