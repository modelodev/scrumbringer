import domain/card.{type Card, Active, Closed, Draft}

pub fn ready_to_close(card: Card) -> Bool {
  case card.state {
    Draft -> card.task_count > 0 && card.closed_count == card.task_count
    Active | Closed -> False
  }
}
