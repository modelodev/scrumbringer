import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{span, text}

import domain/card.{type CardPhase, Active, Closed, Draft}

pub type Variant {
  Table
  Detail
}

pub fn view(state: CardPhase, label: String, variant: Variant) -> Element(msg) {
  let class = case variant {
    Table -> "state-badge " <> table_class(state)
    Detail -> "card-state-badge " <> detail_class(state)
  }

  span([attribute.class(class)], [text(label)])
}

fn table_class(state: CardPhase) -> String {
  case state {
    Draft -> "state-pending"
    Active -> "state-active"
    Closed -> "state-closed"
  }
}

fn detail_class(state: CardPhase) -> String {
  case state {
    Draft -> "card-state-pendiente"
    Active -> "card-state-en_curso"
    Closed -> "card-state-cerrada"
  }
}
