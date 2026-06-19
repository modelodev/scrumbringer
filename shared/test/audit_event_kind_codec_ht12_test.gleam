import domain/audit_event/kind_codec
import gleam/list

pub fn audit_event_kind_codec_roundtrip_test() {
  let kinds = [
    kind_codec.TaskClaimed,
    kind_codec.TaskReleased,
    kind_codec.TaskDone,
    kind_codec.CardActivated,
    kind_codec.CardClosed,
  ]

  let assert True =
    list.all(kinds, fn(kind) {
      kind_codec.parse(kind_codec.to_string(kind)) == Ok(kind)
    })
}
