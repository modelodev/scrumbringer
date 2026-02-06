import scrumbringer_client/client_state
import scrumbringer_client/helpers/i18n as helpers_i18n
import scrumbringer_client/i18n/text as i18n_text

pub type MilestoneErrorCode {
  MilestoneAlreadyActive
  MilestoneActivationIrreversible
  MilestoneDeleteNotAllowed
  UnknownMilestoneErrorCode
}

pub fn decode_error_code(code: String) -> MilestoneErrorCode {
  case code {
    "MILESTONE_ALREADY_ACTIVE" -> MilestoneAlreadyActive
    "MILESTONE_ACTIVATION_IRREVERSIBLE" -> MilestoneActivationIrreversible
    "MILESTONE_DELETE_NOT_ALLOWED" -> MilestoneDeleteNotAllowed
    _ -> UnknownMilestoneErrorCode
  }
}

pub fn to_user_message(
  model: client_state.Model,
  code: String,
  backend_message: String,
  fallback: i18n_text.Text,
) -> String {
  case decode_error_code(code) {
    MilestoneAlreadyActive ->
      helpers_i18n.i18n_t(model, i18n_text.MilestoneAlreadyActive)
    MilestoneActivationIrreversible ->
      helpers_i18n.i18n_t(model, i18n_text.MilestoneActivationIrreversible)
    MilestoneDeleteNotAllowed ->
      helpers_i18n.i18n_t(model, i18n_text.MilestoneDeleteNotAllowed)
    UnknownMilestoneErrorCode ->
      case backend_message {
        "" -> helpers_i18n.i18n_t(model, fallback)
        _ -> backend_message
      }
  }
}
