import gleam/dict
import gleam/option.{None, Some}
import lustre/effect

import domain/api_error.{ApiError}
import domain/project.{type ProjectMember, ProjectMember}
import domain/project_role
import domain/remote
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/people/state as people_state
import scrumbringer_client/features/people/update as people_update
import scrumbringer_client/features/pool/msg as pool_messages

fn member(user_id: Int) -> ProjectMember {
  ProjectMember(
    user_id: user_id,
    role: project_role.Member,
    created_at: "2026-02-01T10:00:00Z",
    claimed_count: 0,
  )
}

pub fn roster_success_filters_expansions_for_missing_members_test() {
  let pool =
    member_pool.default_model()
    |> fn(pool) {
      member_pool.Model(
        ..pool,
        people_expansions: dict.from_list([
          #(10, people_state.Expanded),
          #(20, people_state.Expanded),
        ]),
      )
    }

  let assert Some(#(next_pool, fx)) =
    people_update.try_update(
      pool,
      pool_messages.MemberPeopleRosterFetched(Ok([member(10)])),
    )

  let expected_roster = remote.Loaded([member(10)])
  let assert True = next_pool.people_roster == expected_roster
  let assert Ok(people_state.Expanded) =
    dict.get(next_pool.people_expansions, 10)
  let assert Error(_) = dict.get(next_pool.people_expansions, 20)
  let assert True = fx == effect.none()
}

pub fn try_update_handles_roster_success_test() {
  let assert Some(#(next_pool, fx)) =
    people_update.try_update(
      member_pool.default_model(),
      pool_messages.MemberPeopleRosterFetched(Ok([member(10)])),
    )

  let assert True = next_pool.people_roster == remote.Loaded([member(10)])
  let assert True = fx == effect.none()
}

pub fn row_toggle_uses_collapsed_default_test() {
  let assert Some(#(next_pool, fx)) =
    people_update.try_update(
      member_pool.default_model(),
      pool_messages.MemberPeopleRowToggled(10),
    )

  let assert Ok(people_state.Expanded) =
    dict.get(next_pool.people_expansions, 10)
  let assert True = fx == effect.none()
}

pub fn try_update_handles_row_toggle_test() {
  let assert Some(#(next_pool, fx)) =
    people_update.try_update(
      member_pool.default_model(),
      pool_messages.MemberPeopleRowToggled(10),
    )

  let assert Ok(people_state.Expanded) =
    dict.get(next_pool.people_expansions, 10)
  let assert True = fx == effect.none()
}

pub fn roster_error_sets_failed_state_test() {
  let err = ApiError(status: 500, code: "E_PEOPLE", message: "Server error")
  let assert Some(#(next_pool, fx)) =
    people_update.try_update(
      member_pool.default_model(),
      pool_messages.MemberPeopleRosterFetched(Error(err)),
    )

  let assert True = next_pool.people_roster == remote.Failed(err)
  let assert True = fx == effect.none()
}

pub fn try_update_handles_roster_error_test() {
  let err = ApiError(status: 500, code: "E_PEOPLE", message: "Server error")

  let assert Some(#(next_pool, fx)) =
    people_update.try_update(
      member_pool.default_model(),
      pool_messages.MemberPeopleRosterFetched(Error(err)),
    )

  let assert True = next_pool.people_roster == remote.Failed(err)
  let assert True = fx == effect.none()
}

pub fn try_update_ignores_non_people_messages_test() {
  let assert None =
    people_update.try_update(
      member_pool.default_model(),
      pool_messages.MemberPoolSearchChanged("qa"),
    )
}
