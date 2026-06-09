import lustre/element.{type Element}

import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/action_buttons

pub type Config(msg) {
  Config(
    locale: Locale,
    card_id: Int,
    card_title: String,
    can_manage: Bool,
    on_create_task: msg,
    on_edit: msg,
    on_delete: msg,
  )
}

pub fn view(config: Config(msg)) -> List(Element(msg)) {
  let create_task_action =
    action_buttons.create_task_in_card_button(
      i18n.t(config.locale, i18n_text.NewTaskInCard(config.card_title)),
      config.on_create_task,
    )

  case config.can_manage {
    True -> [
      create_task_action,
      action_buttons.edit_button_with_size(
        i18n.t(config.locale, i18n_text.EditCardTooltip),
        config.on_edit,
        action_buttons.SizeXs,
      ),
      action_buttons.delete_button_with_size(
        i18n.t(config.locale, i18n_text.DeleteCardTooltip),
        config.on_delete,
        action_buttons.SizeXs,
      ),
    ]
    False -> [create_task_action]
  }
}
