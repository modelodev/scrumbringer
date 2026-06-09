import scrumbringer_client/client_state/ui
import scrumbringer_client/storage

pub fn decode_sidebar_state_storage_parses_valid_values_test() {
  let assert storage.SidebarStateStored(ui.BothCollapsed) =
    storage.decode_sidebar_state_storage("1,1")
  let assert storage.SidebarStateStored(ui.ConfigCollapsed) =
    storage.decode_sidebar_state_storage("1,0")
  let assert storage.SidebarStateStored(ui.OrgCollapsed) =
    storage.decode_sidebar_state_storage("0,1")
  let assert storage.SidebarStateStored(ui.NoneCollapsed) =
    storage.decode_sidebar_state_storage("0,0")
}

pub fn decode_sidebar_state_storage_marks_invalid_values_test() {
  let assert storage.SidebarStateInvalid("unknown") =
    storage.decode_sidebar_state_storage("unknown")
}

pub fn encode_sidebar_state_storage_roundtrip_test() {
  let assert storage.SidebarStateStored(ui.ConfigCollapsed) =
    ui.ConfigCollapsed
    |> storage.encode_sidebar_state_storage
    |> storage.decode_sidebar_state_storage
}
