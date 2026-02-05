import domain/task.{Task, TaskPosition}
import domain/task_state
import domain/task_type.{TaskTypeInline}
import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{None}
import gleeunit/should
import scrumbringer_client/helpers/dicts as helpers_dicts

pub fn ids_to_bool_dict_sets_true_test() {
  let result = helpers_dicts.ids_to_bool_dict([1, 2])
  dict.get(result, 1)
  |> should.equal(Ok(True))
  dict.get(result, 2)
  |> should.equal(Ok(True))
}

pub fn bool_dict_to_ids_filters_false_test() {
  let values = dict.from_list([#(1, True), #(2, False), #(3, True)])
  helpers_dicts.bool_dict_to_ids(values)
  |> list.sort(int.compare)
  |> should.equal([1, 3])
}

pub fn positions_to_dict_maps_task_id_test() {
  let positions = [
    TaskPosition(
      task_id: 10,
      user_id: 1,
      x: 4,
      y: 8,
      updated_at: "2026-01-01T00:00:00Z",
    ),
  ]
  let result = helpers_dicts.positions_to_dict(positions)
  dict.get(result, 10)
  |> should.equal(Ok(#(4, 8)))
}

pub fn flatten_tasks_collects_all_tasks_test() {
  let state = task_state.Available
  let t1 =
    Task(
      id: 1,
      project_id: 1,
      type_id: 1,
      task_type: TaskTypeInline(id: 1, name: "Bug", icon: "bug"),
      ongoing_by: None,
      title: "A",
      description: None,
      priority: 1,
      state: state,
      status: task_state.to_status(state),
      work_state: task_state.to_work_state(state),
      created_by: 1,
      created_at: "2026-01-01T00:00:00Z",
      version: 1,
      card_id: None,
      card_title: None,
      card_color: None,
      has_new_notes: False,
      blocked_count: 0,
      dependencies: [],
    )
  let t2 = Task(..t1, id: 2, title: "B")
  let tasks = dict.from_list([#(1, [t1]), #(2, [t2])])
  helpers_dicts.flatten_tasks(tasks)
  |> list.map(fn(t) { t.id })
  |> list.sort(int.compare)
  |> should.equal([1, 2])
}
