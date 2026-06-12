//// Milestone detail header actions.

import gleam/int
import gleam/option
import lustre/element.{type Element, none}

import domain/milestone.{type MilestoneProgress, Ready}
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/action_buttons
import scrumbringer_client/ui/button
import scrumbringer_client/ui/icons

/// Data and parent callbacks needed to render milestone detail actions.
pub type Config(msg) {
  Config(
    locale: Locale,
    progress: MilestoneProgress,
    can_manage: Bool,
    activation_in_flight: Bool,
    has_other_active: Bool,
    on_quick_create_card: fn(Int) -> msg,
    on_quick_create_task: fn(Int) -> msg,
    on_activate_prompt: fn(Int) -> msg,
    on_edit: fn(Int) -> msg,
    on_delete: fn(Int) -> msg,
  )
}

/// Render all actions shown in the milestone detail header.
pub fn view(config: Config(msg)) -> List(Element(msg)) {
  let milestone_id = config.progress.milestone.id

  [
    quick_create_card_button(config, milestone_id),
    quick_create_task_button(config, milestone_id),
    activate_button(config, milestone_id),
    edit_button(config, milestone_id),
    delete_button(config, milestone_id),
  ]
}

fn quick_create_card_button(
  config: Config(msg),
  milestone_id: Int,
) -> Element(msg) {
  case config.can_manage {
    True ->
      action_buttons.add_icon_button_with_size_and_testid(
        i18n.t(config.locale, i18n_text.QuickCard),
        config.on_quick_create_card(milestone_id),
        action_buttons.SizeXs,
        icons.Cards,
        option.Some("milestone-quick-new-card:" <> int.to_string(milestone_id)),
        option.Some("btn-create-card"),
      )
    False -> none()
  }
}

fn quick_create_task_button(
  config: Config(msg),
  milestone_id: Int,
) -> Element(msg) {
  case config.can_manage {
    True ->
      action_buttons.add_icon_button_with_size_and_testid(
        i18n.t(config.locale, i18n_text.NewTask),
        config.on_quick_create_task(milestone_id),
        action_buttons.SizeXs,
        icons.Plus,
        option.Some("milestone-quick-new-task:" <> int.to_string(milestone_id)),
        option.Some("btn-create-task"),
      )
    False -> none()
  }
}

fn activate_button(config: Config(msg), milestone_id: Int) -> Element(msg) {
  case
    config.can_manage,
    config.progress.milestone.state,
    config.has_other_active
  {
    True, Ready, False ->
      button.text(
        case config.activation_in_flight {
          True -> i18n.t(config.locale, i18n_text.ActivatingMilestone)
          False -> i18n.t(config.locale, i18n_text.ActivateMilestone)
        },
        config.on_activate_prompt(milestone_id),
        button.Primary,
        button.EntityAction,
      )
      |> button.with_disabled(config.activation_in_flight)
      |> button.with_testid(
        "milestone-activate-button:" <> int.to_string(milestone_id),
      )
      |> button.view
    _, _, _ -> none()
  }
}

fn edit_button(config: Config(msg), milestone_id: Int) -> Element(msg) {
  case config.can_manage {
    True ->
      action_buttons.edit_button_with_testid(
        i18n.t(config.locale, i18n_text.EditMilestone),
        config.on_edit(milestone_id),
        "milestone-edit-button:" <> int.to_string(milestone_id),
      )
    False -> none()
  }
}

fn delete_button(config: Config(msg), milestone_id: Int) -> Element(msg) {
  case config.can_manage, config.progress.milestone.state {
    True, Ready ->
      action_buttons.delete_button_with_testid(
        i18n.t(config.locale, i18n_text.DeleteMilestone),
        config.on_delete(milestone_id),
        "milestone-delete-button:" <> int.to_string(milestone_id),
      )
    _, _ -> none()
  }
}
