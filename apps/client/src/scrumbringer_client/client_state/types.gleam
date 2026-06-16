//// Shared client state types for scrumbringer_client.

/// Represents a generic async operation state.
pub type OperationState {
  Idle
  InFlight
  Error(String)
}

/// Represents a dialog with form state and operation state.
pub type DialogState(form) {
  DialogClosed(operation: OperationState)
  DialogOpen(form: form, operation: OperationState)
}
