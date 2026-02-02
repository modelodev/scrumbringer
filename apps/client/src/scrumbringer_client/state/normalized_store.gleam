//// Normalized store for member card caching.
////
//// Provides a compact normalized cache with per-project ordering and
//// a pending counter for multi-project refreshes.

import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option, None, Some}

pub opaque type NormalizedStore(id, data) {
  NormalizedStore(
    items: Dict(id, data),
    project_index: Dict(id, List(id)),
    project_order: List(id),
    pending: Int,
  )
}

pub fn new() -> NormalizedStore(id, data) {
  NormalizedStore(
    items: dict.new(),
    project_index: dict.new(),
    project_order: [],
    pending: 0,
  )
}

pub fn with_pending(
  store: NormalizedStore(id, data),
  pending: Int,
) -> NormalizedStore(id, data) {
  let NormalizedStore(
    items: items,
    project_index: project_index,
    project_order: project_order,
    pending: _,
  ) = store

  NormalizedStore(
    items: items,
    project_index: project_index,
    project_order: project_order,
    pending: pending,
  )
}

pub fn pending(store: NormalizedStore(id, data)) -> Int {
  let NormalizedStore(pending: pending, ..) = store
  pending
}

pub fn decrement_pending(
  store: NormalizedStore(id, data),
) -> NormalizedStore(id, data) {
  let NormalizedStore(
    items: items,
    project_index: project_index,
    project_order: project_order,
    pending: pending,
  ) = store

  let next_pending = case pending <= 0 {
    True -> 0
    False -> pending - 1
  }

  NormalizedStore(
    items: items,
    project_index: project_index,
    project_order: project_order,
    pending: next_pending,
  )
}

pub fn upsert(
  store: NormalizedStore(id, data),
  project_id: id,
  items: List(data),
  to_id: fn(data) -> id,
) -> NormalizedStore(id, data) {
  case list.is_empty(items) {
    True -> store
    False -> {
      let NormalizedStore(
        items: current_items,
        project_index: project_index,
        project_order: project_order,
        pending: pending,
      ) = store

      let #(next_items, ordered_ids) =
        list.fold(items, #(current_items, []), fn(state, item) {
          let #(acc_items, acc_ids) = state
          let id = to_id(item)
          let next_items = dict.insert(acc_items, id, item)
          let next_ids = case
            list.any(acc_ids, fn(existing) { existing == id })
          {
            True -> acc_ids
            False -> list.append(acc_ids, [id])
          }
          #(next_items, next_ids)
        })

      let next_index = dict.insert(project_index, project_id, ordered_ids)
      let next_order = case
        list.any(project_order, fn(id) { id == project_id })
      {
        True -> project_order
        False -> list.append(project_order, [project_id])
      }

      NormalizedStore(
        items: next_items,
        project_index: next_index,
        project_order: next_order,
        pending: pending,
      )
    }
  }
}

pub fn get_by_id(store: NormalizedStore(id, data), item_id: id) -> Option(data) {
  let NormalizedStore(items: items, ..) = store
  case dict.get(items, item_id) {
    Ok(item) -> Some(item)
    Error(_) -> None
  }
}

pub fn get_by_project(
  store: NormalizedStore(id, data),
  project_id: id,
) -> List(data) {
  let NormalizedStore(items: items, project_index: project_index, ..) = store

  case dict.get(project_index, project_id) {
    Ok(ids) ->
      ids
      |> list.filter_map(fn(item_id) {
        case dict.get(items, item_id) {
          Ok(item) -> Ok(item)
          Error(_) -> Error(Nil)
        }
      })
    Error(_) -> []
  }
}

pub fn to_list(store: NormalizedStore(id, data)) -> List(data) {
  let NormalizedStore(project_order: project_order, ..) = store

  project_order
  |> list.fold([], fn(acc, project_id) {
    list.append(acc, get_by_project(store, project_id))
  })
}

pub fn is_ready(store: NormalizedStore(id, data)) -> Bool {
  pending(store) <= 0
}
