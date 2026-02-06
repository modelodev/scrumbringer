//// Toast effect helpers.

import lustre/effect.{type Effect}

import scrumbringer_client/client_state.{
  type Msg, ToastShow, ToastShowWithAction,
}
import scrumbringer_client/ui/toast

/// Build a toast effect to show a message with a variant.
pub fn toast_effect(message: String, variant: toast.ToastVariant) -> Effect(Msg) {
  effect.from(fn(dispatch) { dispatch(ToastShow(message, variant)) })
}

/// Build a toast effect with an action button.
pub fn toast_effect_with_action(
  message: String,
  variant: toast.ToastVariant,
  action: toast.ToastAction,
) -> Effect(Msg) {
  effect.from(fn(dispatch) {
    dispatch(ToastShowWithAction(message, variant, action))
  })
}

/// Provides toast success.
pub fn toast_success(message: String) -> Effect(Msg) {
  toast_effect(message, toast.Success)
}

/// Provides toast error.
pub fn toast_error(message: String) -> Effect(Msg) {
  toast_effect(message, toast.Error)
}

/// Provides toast warning.
pub fn toast_warning(message: String) -> Effect(Msg) {
  toast_effect(message, toast.Warning)
}
