//// Pure helpers for admin lists split between organisation and project scope.

import gleam/list
import gleam/option as opt

import domain/remote.{type Remote, Loaded}

pub fn prepend_for_scope(
  org: Remote(List(a)),
  project: Remote(List(a)),
  project_id: opt.Option(Int),
  item: a,
) -> #(Remote(List(a)), Remote(List(a))) {
  case project_id {
    opt.Some(_) -> #(org, prepend_loaded_or_new(project, item))
    opt.None -> #(prepend_loaded_or_new(org, item), project)
  }
}

pub fn replace_by_id(
  remote: Remote(List(a)),
  updated: a,
  id: fn(a) -> Int,
) -> Remote(List(a)) {
  map_loaded(remote, fn(items) {
    list.map(items, fn(item) {
      case id(item) == id(updated) {
        True -> updated
        False -> item
      }
    })
  })
}

pub fn remove_by_id(
  remote: Remote(List(a)),
  target_id: Int,
  id: fn(a) -> Int,
) -> Remote(List(a)) {
  map_loaded(remote, fn(items) {
    list.filter(items, fn(item) { id(item) != target_id })
  })
}

fn prepend_loaded_or_new(remote: Remote(List(a)), item: a) -> Remote(List(a)) {
  case remote {
    Loaded(existing) -> Loaded([item, ..existing])
    _ -> Loaded([item])
  }
}

fn map_loaded(
  remote: Remote(List(a)),
  f: fn(List(a)) -> List(a),
) -> Remote(List(a)) {
  case remote {
    Loaded(items) -> Loaded(f(items))
    other -> other
  }
}
