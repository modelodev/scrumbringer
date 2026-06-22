//// JSON presenters for work session endpoints.

import gleam/json
import scrumbringer_server/use_case/work_sessions_db

pub fn state(state: work_sessions_db.WorkSessionsState) -> json.Json {
  let work_sessions_db.WorkSessionsState(
    active_sessions: sessions,
    as_of: as_of,
  ) = state

  let sessions_json =
    sessions
    |> json.array(of: fn(session) {
      let work_sessions_db.ActiveSession(
        task_id: task_id,
        started_at: started_at,
        accumulated_s: accumulated_s,
      ) = session

      json.object([
        #("task_id", json.int(task_id)),
        #("started_at", json.string(started_at)),
        #("accumulated_s", json.int(accumulated_s)),
      ])
    })

  json.object([
    #("active_sessions", sessions_json),
    #("as_of", json.string(as_of)),
  ])
}
