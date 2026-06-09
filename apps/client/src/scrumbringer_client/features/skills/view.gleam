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

import domain/capability.{type Capability}
import domain/remote.{type Remote}
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/attribute_value
import scrumbringer_client/ui/empty_state
import scrumbringer_client/ui/error_notice
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/info_callout
import scrumbringer_client/ui/loading
import scrumbringer_client/ui/remote as ui_remote
import scrumbringer_client/ui/section_header

pub type Config(msg) {
  Config(
    locale: Locale,
    capabilities: Remote(List(Capability)),
    selected_capability_ids: dict.Dict(Int, Bool),
    error: opt.Option(String),
    in_flight: Bool,
    on_save: msg,
    on_capability_toggle: fn(Int) -> msg,
  )
}

/// Renders the My Skills section.
pub fn view_skills(config: Config(msg)) -> Element(msg) {
  div([attribute.class("section")], [
    section_header.view(
      icons.Crosshairs,
      i18n.t(config.locale, i18n_text.MySkills),
    ),
    // MS01: Helper text explaining the section
    info_callout.simple(i18n.t(config.locale, i18n_text.MySkillsHelp)),
    case config.error {
      opt.Some(err) -> error_notice.view(err)
      opt.None -> element.none()
    },
    view_skills_list(config),
    button(
      [
        attribute.type_("submit"),
        event.on_click(config.on_save),
        attribute.disabled(config.in_flight),
        attribute.class(case config.in_flight {
          True -> "btn-loading"
          False -> ""
        }),
      ],
      [
        text(case config.in_flight {
          True -> i18n.t(config.locale, i18n_text.Saving)
          False -> i18n.t(config.locale, i18n_text.Save)
        }),
      ],
    ),
  ])
}

/// Renders the list of capabilities with checkboxes.
fn view_skills_list(config: Config(msg)) -> Element(msg) {
  ui_remote.view_remote(
    config.capabilities,
    loading: fn() {
      loading.loading(i18n.t(config.locale, i18n_text.LoadingEllipsis))
    },
    error: fn(err) { error_notice.view(err.message) },
    loaded: fn(capabilities) {
      case list.is_empty(capabilities) {
        True ->
          empty_state.simple(
            "user-group",
            i18n.t(config.locale, i18n_text.NoCapabilitiesYet),
          )
        False ->
          div(
            [attribute.class("skills-list")],
            list.map(capabilities, fn(c) {
              let selected = case
                dict.get(config.selected_capability_ids, c.id)
              {
                Ok(v) -> v
                Error(_) -> False
              }

              div([attribute.class("skill-row")], [
                span([attribute.class("skill-name")], [text(c.name)]),
                input([
                  attribute.type_("checkbox"),
                  attribute.attribute(
                    "checked",
                    attribute_value.boolean(selected),
                  ),
                  event.on_click(config.on_capability_toggle(c.id)),
                ]),
              ])
            }),
          )
      }
    },
  )
}
