//// Pure loaded-data derivations for the center navigation panel.

import domain/capability.{type Capability}
import domain/org.{type OrgUser}
import domain/remote.{type Remote, unwrap}
import domain/task.{type Task}
import domain/task_type.{type TaskType}

pub type Data {
  Data(
    tasks: List(Task),
    task_types: List(TaskType),
    capabilities: List(Capability),
    org_users: List(OrgUser),
    my_capability_ids: List(Int),
  )
}

pub fn from_remotes(
  tasks: Remote(List(Task)),
  task_types: Remote(List(TaskType)),
  capabilities: Remote(List(Capability)),
  org_users: Remote(List(OrgUser)),
  my_capability_ids: Remote(List(Int)),
) -> Data {
  Data(
    tasks: unwrap(tasks, []),
    task_types: unwrap(task_types, []),
    capabilities: unwrap(capabilities, []),
    org_users: unwrap(org_users, []),
    my_capability_ids: unwrap(my_capability_ids, []),
  )
}
