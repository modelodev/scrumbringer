//// Pure project-list transformations over remote core projects.

import gleam/list
import gleam/option as opt

import domain/project.{type Project, Project}
import domain/remote.{type Remote, Loaded}

pub fn prepend_or_single(
  projects: Remote(List(Project)),
  project: Project,
) -> Remote(List(Project)) {
  case projects {
    Loaded(items) -> Loaded([project, ..items])
    _ -> Loaded([project])
  }
}

pub fn update_name(
  projects: Remote(List(Project)),
  project: Project,
) -> Remote(List(Project)) {
  case projects {
    Loaded(items) ->
      Loaded(
        items
        |> list.map(fn(existing) {
          case existing.id == project.id {
            True -> Project(..existing, name: project.name)
            False -> existing
          }
        }),
      )
    _ -> Loaded([])
  }
}

pub fn remove(
  projects: Remote(List(Project)),
  deleted_id: opt.Option(Int),
) -> Remote(List(Project)) {
  case projects {
    Loaded(items) ->
      Loaded(
        items
        |> list.filter(fn(project) {
          case deleted_id {
            opt.Some(id) -> project.id != id
            opt.None -> True
          }
        }),
      )
    _ -> Loaded([])
  }
}

pub fn selected_after_delete(
  selected_project_id: opt.Option(Int),
  deleted_id: opt.Option(Int),
) -> opt.Option(Int) {
  case selected_project_id, deleted_id {
    opt.Some(selected_id), opt.Some(removed_id) if selected_id == removed_id ->
      opt.None
    _, _ -> selected_project_id
  }
}
