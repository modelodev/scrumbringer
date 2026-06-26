//// Card seed scenarios.
////
//// Creates base project cards with color/profile coverage for product
//// validation surfaces.

import domain/card
import gleam/int
import gleam/list
import gleam/option.{Some}
import gleam/result
import pog
import scrumbringer_server/seed_db
import scrumbringer_server/seed_pools

pub type Context {
  Context(
    admin_id: Int,
    user_ids: List(Int),
    active_project_ids: List(Int),
    cards_per_project: Int,
    date_range_days: Int,
  )
}

pub type CardResult {
  CardResult(card_ids: List(Int), card_ids_by_project: List(#(Int, List(Int))))
}

/// Card profile colors stay in this scenario because HT-12 seed coverage gates
/// verify card-profile coverage directly against seed scenario sources.
fn card_color_pool() -> List(card.CardColor) {
  [
    card.Gray,
    card.Red,
    card.Orange,
    card.Yellow,
    card.Green,
    card.Blue,
    card.Purple,
    card.Pink,
  ]
}

pub fn build(db: pog.Connection, context: Context) -> Result(CardResult, String) {
  let titles = seed_pools.card_titles()
  let colors = card_color_pool()

  use card_ids_by_project <- result.try(
    list.try_map(context.active_project_ids, fn(project_id) {
      use card_ids <- result.try(
        list.range(0, context.cards_per_project - 1)
        |> list.try_map(fn(idx) {
          let base_title =
            list_at(titles, idx, "Card " <> int.to_string(idx + 1))
          let title =
            "P"
            <> int.to_string(project_id)
            <> " - "
            <> base_title
            <> " #"
            <> int.to_string(idx + 1)
          let color = Some(list_at_helper(colors, idx, card.Gray))
          let creator_idx = idx % list.length(context.user_ids)
          let creator_id =
            list_at_int(context.user_ids, creator_idx, context.admin_id)

          seed_db.insert_card(
            db,
            seed_db.CardInsertOptions(
              project_id: project_id,
              title: title,
              description: "Seeded card",
              color: color,
              created_by: creator_id,
              created_at: Some(days_ago_timestamp(context.date_range_days - idx)),
            ),
          )
        }),
      )
      use _ <- result.try(activate_seed_cards(db, card_ids))
      use _ <- result.try(assign_seed_hierarchy(db, card_ids))
      Ok(#(project_id, card_ids))
    }),
  )

  Ok(CardResult(
    card_ids: flatten_ids(card_ids_by_project),
    card_ids_by_project: card_ids_by_project,
  ))
}

fn activate_seed_cards(
  db: pog.Connection,
  card_ids: List(Int),
) -> Result(Nil, String) {
  card_ids
  |> list.try_map(fn(card_id) { seed_db.activate_card_for_seed(db, card_id) })
  |> result.map(fn(_) { Nil })
}

fn assign_seed_hierarchy(
  db: pog.Connection,
  card_ids: List(Int),
) -> Result(Nil, String) {
  case card_ids {
    [
      root_card_id,
      branch_card_id,
      first_leaf_id,
      second_leaf_id,
      ..root_child_ids
    ] -> {
      use _ <- result.try(seed_db.assign_card_to_parent_card(
        db,
        branch_card_id,
        root_card_id,
      ))
      use _ <- result.try(seed_db.assign_card_to_parent_card(
        db,
        first_leaf_id,
        branch_card_id,
      ))
      use _ <- result.try(seed_db.assign_card_to_parent_card(
        db,
        second_leaf_id,
        branch_card_id,
      ))

      root_child_ids
      |> list.try_map(fn(card_id) {
        seed_db.assign_card_to_parent_card(db, card_id, root_card_id)
      })
      |> result.map(fn(_) { Nil })
    }
    [root_card_id, ..child_card_ids] ->
      child_card_ids
      |> list.try_map(fn(card_id) {
        seed_db.assign_card_to_parent_card(db, card_id, root_card_id)
      })
      |> result.map(fn(_) { Nil })
    _ -> Ok(Nil)
  }
}

fn flatten_ids(ids_by_project: List(#(Int, List(Int)))) -> List(Int) {
  ids_by_project
  |> list.map(fn(pair) {
    let #(_project_id, ids) = pair
    ids
  })
  |> list.flatten
}

fn days_ago_timestamp(days: Int) -> String {
  "NOW() - INTERVAL '" <> int.to_string(days) <> " days'"
}

fn list_at(items: List(String), idx: Int, default: String) -> String {
  list_at_helper(items, idx, default)
}

fn list_at_int(items: List(Int), idx: Int, default: Int) -> Int {
  list_at_helper(items, idx, default)
}

fn list_at_helper(items: List(a), idx: Int, default: a) -> a {
  case idx, items {
    _, [] -> default
    0, [first, ..] -> first
    n, [_, ..rest] -> list_at_helper(rest, n - 1, default)
  }
}
