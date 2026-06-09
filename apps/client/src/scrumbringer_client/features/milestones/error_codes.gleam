import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
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
  locale: Locale,
  code: String,
  backend_message: String,
  fallback: i18n_text.Text,
) -> String {
  case decode_error_code(code) {
    MilestoneAlreadyActive -> i18n.t(locale, i18n_text.MilestoneAlreadyActive)
    MilestoneActivationIrreversible ->
      i18n.t(locale, i18n_text.MilestoneActivationIrreversible)
    MilestoneDeleteNotAllowed ->
      i18n.t(locale, i18n_text.MilestoneDeleteNotAllowed)
    UnknownMilestoneErrorCode ->
      case backend_message {
        "" -> i18n.t(locale, fallback)
        _ -> backend_message
      }
  }
}
