//// Task claimability rules for the card hierarchy execution model.

import domain/card/activation.{type WorkTree}
import domain/card/entity as card_entity
import domain/task/entity as task_entity

pub fn card_is_claimable(_card: card_entity.Card) -> Bool {
  False
}

pub fn task_is_claimable(task: task_entity.Task, tree: WorkTree) -> Bool {
  activation.task_is_claimable_in_tree(task, tree)
}
