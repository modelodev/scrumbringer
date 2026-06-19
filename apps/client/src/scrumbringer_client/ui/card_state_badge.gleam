import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{span, text}

import domain/card.{type CardPhase, Active, Closed, Draft}

pub type Variant {
  Table
  Ficha
  Detail
}

pub fn view(state: CardPhase, label: String, variant: Variant) -> Element(msg) {
  let class = case variant {
    Table -> "state-badge " <> table_class(state)
    Ficha -> "ficha-state-badge " <> ficha_class(state)
    Detail -> "card-state-badge " <> detail_class(state)
  }

  span([attribute.class(class)], [text(label)])
}

fn table_class(state: CardPhase) -> String {
  case state {
    Draft -> "state-pending"
    Active -> "state-active"
    Closed -> "state-completed"
  }
}

fn ficha_class(state: CardPhase) -> String {
  case state {
    Draft -> "ficha-state-pendiente"
    Active -> "ficha-state-en_curso"
    Closed -> "ficha-state-cerrada"
  }
}

fn detail_class(state: CardPhase) -> String {
  case state {
    Draft -> "card-state-pendiente"
    Active -> "card-state-en_curso"
    Closed -> "card-state-cerrada"
  }
}
