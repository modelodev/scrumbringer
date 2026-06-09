import gleam/list
import gleam/option

import lustre/attribute
import lustre/element.{type Element, none}
import lustre/element/html.{button, form, input, p, text, textarea}
import lustre/event

import domain/milestone.{type MilestoneProgress}
import domain/remote.{type Remote, Loaded}
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/confirm_dialog
import scrumbringer_client/ui/dialog
import scrumbringer_client/ui/form_field

pub type Config(msg) {
  Config(
    locale: Locale,
    milestones: Remote(List(MilestoneProgress)),
    dialog: member_pool.MilestoneDialog,
    in_flight: Bool,
    error: option.Option(String),
    on_close: msg,
    on_activate_clicked: fn(Int) -> msg,
    on_create_submitted: msg,
    on_edit_submitted: fn(Int) -> msg,
    on_delete_submitted: fn(Int) -> msg,
    on_name_changed: fn(String) -> msg,
    on_description_changed: fn(String) -> msg,
  )
}

pub fn view(config: Config(msg)) -> Element(msg) {
  element.fragment([
    view_create_dialog(config),
    view_activate_dialog(config),
    view_edit_dialog(config),
    view_delete_dialog(config),
  ])
}

fn view_activate_dialog(config: Config(msg)) -> Element(msg) {
  let maybe_progress = case config.dialog {
    member_pool.MilestoneDialogActivate(id: id) ->
      find_milestone_progress(config.milestones, id)
    _ -> option.None
  }

  case maybe_progress {
    option.Some(progress) ->
      dialog.view(
        dialog.DialogConfig(
          title: t(config, i18n_text.MilestoneActivationTitle),
          icon: option.None,
          size: dialog.DialogSm,
          on_close: config.on_close,
        ),
        True,
        config.error,
        [
          p([], [
            text(t(
              config,
              i18n_text.MilestoneActivationBody(
                cards_count: progress.cards_total,
                tasks_count: progress.tasks_total,
              ),
            )),
          ]),
          p([], [text(t(config, i18n_text.MilestoneActivationWarning))]),
        ],
        [
          button(
            [
              attribute.type_("button"),
              attribute.autofocus(True),
              attribute.disabled(config.in_flight),
              event.on_click(config.on_close),
            ],
            [text(t(config, i18n_text.Cancel))],
          ),
          button(
            [
              attribute.type_("button"),
              attribute.class("btn btn-danger"),
              attribute.disabled(config.in_flight),
              event.on_click(config.on_activate_clicked(progress.milestone.id)),
            ],
            [
              text(case config.in_flight {
                True -> t(config, i18n_text.ActivatingMilestone)
                False -> t(config, i18n_text.ActivateMilestone)
              }),
            ],
          ),
        ],
      )
    option.None -> none()
  }
}

fn view_create_dialog(config: Config(msg)) -> Element(msg) {
  let #(is_open, name, description) = case config.dialog {
    member_pool.MilestoneDialogCreate(name: name, description: description) -> #(
      True,
      name,
      description,
    )
    _ -> #(False, "", "")
  }

  dialog.view(
    dialog.DialogConfig(
      title: t(config, i18n_text.CreateMilestone),
      icon: option.None,
      size: dialog.DialogSm,
      on_close: config.on_close,
    ),
    is_open,
    config.error,
    [
      milestone_form(
        "milestone-create-form",
        name,
        description,
        fn(_) { config.on_create_submitted },
        config.on_name_changed,
        config.on_description_changed,
        config,
      ),
    ],
    [
      dialog.cancel_button_with_locale(config.locale, config.on_close),
      dialog.submit_button_with_locale_attrs(
        config.locale,
        [attribute.form("milestone-create-form")],
        config.in_flight,
        False,
        i18n_text.Create,
        i18n_text.Creating,
      ),
    ],
  )
}

fn view_edit_dialog(config: Config(msg)) -> Element(msg) {
  let #(is_open, id, name, description) = case config.dialog {
    member_pool.MilestoneDialogEdit(
      id: id,
      name: name,
      description: description,
    ) -> #(True, id, name, description)
    _ -> #(False, 0, "", "")
  }

  dialog.view(
    dialog.DialogConfig(
      title: t(config, i18n_text.EditMilestone),
      icon: option.None,
      size: dialog.DialogSm,
      on_close: config.on_close,
    ),
    is_open,
    config.error,
    [
      milestone_form(
        "milestone-edit-form",
        name,
        description,
        fn(_) { config.on_edit_submitted(id) },
        config.on_name_changed,
        config.on_description_changed,
        config,
      ),
    ],
    [
      dialog.cancel_button_with_locale(config.locale, config.on_close),
      dialog.submit_button_with_locale_attrs(
        config.locale,
        [attribute.form("milestone-edit-form")],
        config.in_flight,
        False,
        i18n_text.Save,
        i18n_text.Saving,
      ),
    ],
  )
}

fn view_delete_dialog(config: Config(msg)) -> Element(msg) {
  let #(is_open, id, name) = case config.dialog {
    member_pool.MilestoneDialogDelete(id: id, name: name) -> #(True, id, name)
    _ -> #(False, 0, "")
  }

  confirm_dialog.view(confirm_dialog.ConfirmConfig(
    title: t(config, i18n_text.DeleteMilestoneTitle),
    body: [
      p([], [text(t(config, i18n_text.DeleteMilestoneConfirm(name)))]),
    ],
    confirm_label: t(config, i18n_text.Delete),
    cancel_label: t(config, i18n_text.Cancel),
    on_confirm: config.on_delete_submitted(id),
    on_cancel: config.on_close,
    is_open: is_open,
    is_loading: config.in_flight,
    error: config.error,
    confirm_class: "btn-danger",
  ))
}

fn milestone_form(
  form_id: String,
  name: String,
  description: String,
  on_submit: fn(List(#(String, String))) -> msg,
  on_name_changed: fn(String) -> msg,
  on_description_changed: fn(String) -> msg,
  config: Config(msg),
) -> Element(msg) {
  form(
    [
      event.on_submit(on_submit),
      attribute.id(form_id),
    ],
    [
      form_field.view_required(
        t(config, i18n_text.Name),
        input([
          attribute.type_("text"),
          attribute.value(name),
          attribute.required(True),
          event.on_input(on_name_changed),
        ]),
      ),
      form_field.view(
        t(config, i18n_text.Description),
        textarea(
          [
            attribute.rows(4),
            attribute.value(description),
            event.on_input(on_description_changed),
          ],
          description,
        ),
      ),
    ],
  )
}

fn find_milestone_progress(
  milestones: Remote(List(MilestoneProgress)),
  milestone_id: Int,
) -> option.Option(MilestoneProgress) {
  case milestones {
    Loaded(items) ->
      list.find(items, fn(progress) { progress.milestone.id == milestone_id })
      |> option.from_result
    _ -> option.None
  }
}

fn t(config: Config(msg), key: i18n_text.Text) -> String {
  i18n.t(config.locale, key)
}
