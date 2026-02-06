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
import lustre/element/html.{button, div, input, span, text}
import lustre/event

import scrumbringer_client/client_state.{type Model, type Msg, pool_msg}
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/helpers/i18n as helpers_i18n
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/empty_state
import scrumbringer_client/ui/error_notice
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/info_callout
import scrumbringer_client/ui/loading
import scrumbringer_client/ui/remote as ui_remote
import scrumbringer_client/ui/section_header

/// Renders the My Skills section.
pub fn view_skills(model: Model) -> Element(Msg) {
  div([attribute.class("section")], [
    section_header.view(
      icons.Crosshairs,
      helpers_i18n.i18n_t(model, i18n_text.MySkills),
    ),
    // MS01: Helper text explaining the section
    info_callout.simple(helpers_i18n.i18n_t(model, i18n_text.MySkillsHelp)),
    case model.member.skills.member_my_capabilities_error {
      opt.Some(err) -> error_notice.view(err)
      opt.None -> element.none()
    },
    view_skills_list(model),
    button(
      [
        attribute.type_("submit"),
        event.on_click(pool_msg(pool_messages.MemberSaveCapabilitiesClicked)),
        attribute.disabled(model.member.skills.member_my_capabilities_in_flight),
        attribute.class(
          case model.member.skills.member_my_capabilities_in_flight {
            True -> "btn-loading"
            False -> ""
          },
        ),
      ],
      [
        text(case model.member.skills.member_my_capabilities_in_flight {
          True -> helpers_i18n.i18n_t(model, i18n_text.Saving)
          False -> helpers_i18n.i18n_t(model, i18n_text.Save)
        }),
      ],
    ),
  ])
}

/// Renders the list of capabilities with checkboxes.
fn view_skills_list(model: Model) -> Element(Msg) {
  ui_remote.view_remote(
    model.member.skills.member_capabilities,
    loading: fn() {
      loading.loading(helpers_i18n.i18n_t(model, i18n_text.LoadingEllipsis))
    },
    error: fn(err) { error_notice.view(err.message) },
    loaded: fn(capabilities) {
      case list.is_empty(capabilities) {
        True ->
          empty_state.simple(
            icons.UsersEmoji,
            helpers_i18n.i18n_t(model, i18n_text.NoCapabilitiesYet),
          )
        False ->
          div(
            [attribute.class("skills-list")],
            list.map(capabilities, fn(c) {
              let selected = case
                dict.get(
                  model.member.skills.member_my_capability_ids_edit,
                  c.id,
                )
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
                  event.on_click(
                    pool_msg(pool_messages.MemberToggleCapability(c.id)),
                  ),
                ]),
              ])
            }),
          )
      }
    },
  )
}
