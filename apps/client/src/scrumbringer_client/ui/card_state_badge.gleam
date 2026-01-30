import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{span, text}

import domain/card.{type CardState, Cerrada, EnCurso, Pendiente}

pub type Variant {
  Table
  Ficha
  Detail
}

pub fn view(state: CardState, label: String, variant: Variant) -> Element(msg) {
  let class = case variant {
    Table -> "state-badge " <> table_class(state)
    Ficha -> "ficha-state-badge " <> ficha_class(state)
    Detail -> "card-state-badge " <> detail_class(state)
  }

  span([attribute.class(class)], [text(label)])
}

fn table_class(state: CardState) -> String {
  case state {
    Pendiente -> "state-pending"
    EnCurso -> "state-active"
    Cerrada -> "state-completed"
  }
}

fn ficha_class(state: CardState) -> String {
  case state {
    Pendiente -> "ficha-state-pendiente"
    EnCurso -> "ficha-state-en_curso"
    Cerrada -> "ficha-state-cerrada"
  }
}

fn detail_class(state: CardState) -> String {
  case state {
    Pendiente -> "card-state-pendiente"
    EnCurso -> "card-state-en_curso"
    Cerrada -> "card-state-cerrada"
  }
}
