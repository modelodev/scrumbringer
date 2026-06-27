//// Pure Task Inspector action policy.

import gleam/option as opt

import domain/task.{type Task, claimed_by}
import domain/task/state as task_state

import scrumbringer_client/features/tasks/claimability

pub type PrimaryAction {
  ClaimTask(task_id: Int, version: Int)
  StartWork(task_id: Int)
  CloseTask(task_id: Int, version: Int)
  NoPrimaryAction(reason: NoPrimaryReason)
}

pub type NoPrimaryReason {
  LoadingTask
  ActionsDisabled
  BlockedByDependencies
  ClaimedByAnotherUser
  ClosedTask
  NoCurrentUser
}

pub fn primary_action(
  task: opt.Option(Task),
  current_user_id: opt.Option(Int),
  disable_actions: Bool,
) -> PrimaryAction {
  case disable_actions {
    True -> NoPrimaryAction(ActionsDisabled)
    False -> primary_action_for_task(task, current_user_id)
  }
}

fn primary_action_for_task(
  task: opt.Option(Task),
  current_user_id: opt.Option(Int),
) -> PrimaryAction {
  case task {
    opt.None -> NoPrimaryAction(LoadingTask)
    opt.Some(task) ->
      case task.state {
        task_state.Available ->
          case current_user_id, claimability.can_claim(task) {
            opt.None, _ -> NoPrimaryAction(NoCurrentUser)
            _, True -> ClaimTask(task.id, task.version)
            _, False -> NoPrimaryAction(BlockedByDependencies)
          }

        task_state.Claimed(mode: task_state.Taken, ..) ->
          case claimed_by(task) == current_user_id {
            True -> StartWork(task.id)
            False -> NoPrimaryAction(ClaimedByAnotherUser)
          }

        task_state.Claimed(mode: task_state.Ongoing, ..) ->
          case claimed_by(task) == current_user_id {
            True -> CloseTask(task.id, task.version)
            False -> NoPrimaryAction(ClaimedByAnotherUser)
          }

        task_state.Closed(..) -> NoPrimaryAction(ClosedTask)
      }
  }
}

pub fn can_release(task: Task, current_user_id: opt.Option(Int)) -> Bool {
  case task.state {
    task_state.Claimed(..) -> claimed_by(task) == current_user_id
    _ -> False
  }
}
