import domain/audit_event/kind_codec
import gleam/list

pub fn audit_event_kind_codec_roundtrip_test() {
  let kinds = [
    kind_codec.TaskCreated,
    kind_codec.TaskClaimed,
    kind_codec.TaskReleased,
    kind_codec.TaskClosed,
    kind_codec.CardActivated,
    kind_codec.CardClosed,
    kind_codec.CardMoved,
    kind_codec.TaskDependencyAdded,
    kind_codec.TaskDependencyRemoved,
  ]

  let assert True =
    list.all(kinds, fn(kind) {
      kind_codec.parse(kind_codec.to_string(kind)) == Ok(kind)
    })
}

pub fn audit_event_kind_rejects_unknown_values_test() {
  let assert Error("workflow_rule_ran") = kind_codec.parse("workflow_rule_ran")
}
