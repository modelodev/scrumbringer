//// Skills View
////
//// View functions for the member skills (My Skills) section where users
//// can select their capabilities.
////
//// ## Responsibilities
////
//// - Skills list with checkboxes for capability selection
//// - Save button for persisting capability changes

import gleam/dict
import gleam/list
import gleam/option as opt

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, h2, input, span, text}
import lustre/event

import scrumbringer_client/client_state.{
  type Model, type Msg, Loaded, MemberSaveCapabilitiesClicked,
  MemberToggleCapability,
}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/info_callout
import scrumbringer_client/update_helpers

/// Renders the My Skills section.
pub fn view_skills(model: Model) -> Element(Msg) {
  div([attribute.class("section")], [
    h2([], [text(update_helpers.i18n_t(model, i18n_text.MySkills))]),
    // MS01: Helper text explaining the section
    info_callout.simple(update_helpers.i18n_t(model, i18n_text.MySkillsHelp)),
    case model.member_my_capabilities_error {
      opt.Some(err) ->
        div([attribute.class("error-banner")], [
          span([attribute.class("error-banner-icon")], [icons.nav_icon(icons.Warning, icons.Small)]),
          span([], [text(err)]),
        ])
      opt.None -> element.none()
    },
    view_skills_list(model),
    button(
      [
        attribute.type_("submit"),
        event.on_click(MemberSaveCapabilitiesClicked),
        attribute.disabled(model.member_my_capabilities_in_flight),
        attribute.class(case model.member_my_capabilities_in_flight {
          True -> "btn-loading"
          False -> ""
        }),
      ],
      [
        text(case model.member_my_capabilities_in_flight {
          True -> update_helpers.i18n_t(model, i18n_text.Saving)
          False -> update_helpers.i18n_t(model, i18n_text.Save)
        }),
      ],
    ),
  ])
}

/// Renders the list of capabilities with checkboxes.
fn view_skills_list(model: Model) -> Element(Msg) {
  case model.capabilities {
    Loaded(capabilities) ->
      div(
        [attribute.class("skills-list")],
        list.map(capabilities, fn(c) {
          let selected = case
            dict.get(model.member_my_capability_ids_edit, c.id)
          {
            Ok(v) -> v
            Error(_) -> False
          }

          div([attribute.class("skill-row")], [
            span([attribute.class("skill-name")], [text(c.name)]),
            input([
              attribute.type_("checkbox"),
              attribute.attribute("checked", case selected {
                True -> "true"
                False -> "false"
              }),
              event.on_click(MemberToggleCapability(c.id)),
            ]),
          ])
        }),
      )

    _ ->
      div(
        [
          attribute.class("empty"),
        ],
        [text(update_helpers.i18n_t(model, i18n_text.LoadingEllipsis))],
      )
  }
}
