import lustre/attribute
import lustre/element.{type Element, none}
import lustre/element/html.{div}

import scrumbringer_client/features/milestones/ids as milestone_ids
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/button
import scrumbringer_client/ui/empty_state as ui_empty_state
import scrumbringer_client/ui/icons

pub type EmptyConfig(msg) {
  EmptyConfig(
    locale: Locale,
    message: i18n_text.Text,
    can_manage: Bool,
    on_create: msg,
  )
}

pub type CreateButtonConfig(msg) {
  CreateButtonConfig(locale: Locale, can_manage: Bool, on_create: msg)
}

pub fn view(config: EmptyConfig(msg)) -> Element(msg) {
  div([attribute.class("milestones-state milestones-empty")], [
    ui_empty_state.simple(
      "clipboard-document-list",
      i18n.t(config.locale, config.message),
    ),
    case config.can_manage {
      True ->
        div([attribute.class("milestones-empty-actions")], [
          button.icon_text(
            i18n.t(config.locale, i18n_text.CreateFirstMilestone),
            config.on_create,
            icons.Plus,
            button.Primary,
            button.GlobalAction,
          )
          |> button.with_id(milestone_ids.create_empty_button_id())
          |> button.with_testid("milestones-create-empty")
          |> button.view,
        ])
      False -> none()
    },
  ])
}

pub fn create_button(config: CreateButtonConfig(msg)) -> Element(msg) {
  case config.can_manage {
    True ->
      button.icon_text(
        i18n.t(config.locale, i18n_text.CreateMilestone),
        config.on_create,
        icons.Plus,
        button.Primary,
        button.GlobalAction,
      )
      |> button.with_id(milestone_ids.create_button_id())
      |> button.with_testid("milestones-create-button")
      |> button.view
    False -> none()
  }
}
