import gleam/option as opt
import gleam/string
import lustre/element

import domain/milestone.{
  type MilestoneProgress, Active, Milestone, MilestoneProgress,
}
import domain/remote
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/milestones/dialogs
import scrumbringer_client/i18n/locale

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

fn progress() -> MilestoneProgress {
  MilestoneProgress(
    milestone: Milestone(
      id: 42,
      project_id: 1,
      name: "Launch",
      description: opt.None,
      state: Active,
      position: 1,
      created_by: 1,
      created_at: "2026-02-06T00:00:00Z",
      activated_at: opt.None,
      completed_at: opt.None,
    ),
    cards_total: 3,
    cards_completed: 1,
    tasks_total: 5,
    tasks_completed: 2,
  )
}

fn config(dialog_state: member_pool.MilestoneDialog) -> dialogs.Config(String) {
  dialogs.Config(
    locale: locale.En,
    milestones: remote.Loaded([progress()]),
    dialog: dialog_state,
    in_flight: False,
    error: opt.None,
    on_close: "close",
    on_activate_clicked: fn(_) { "activate" },
    on_create_submitted: "create",
    on_edit_submitted: fn(_) { "edit" },
    on_delete_submitted: fn(_) { "delete" },
    on_name_changed: fn(value) { "name:" <> value },
    on_description_changed: fn(value) { "description:" <> value },
  )
}

pub fn create_dialog_renders_from_config_without_root_model_test() {
  let html =
    dialogs.view(
      config(member_pool.MilestoneDialogCreate(
        name: "New milestone",
        description: "Plan",
      )),
    )
    |> element.to_document_string

  assert_contains(html, "Create milestone")
  assert_contains(html, "New milestone")
  assert_contains(html, "Plan")
}

pub fn activate_dialog_renders_counts_from_config_test() {
  let html =
    dialogs.view(config(member_pool.MilestoneDialogActivate(42)))
    |> element.to_document_string

  assert_contains(html, "Activate milestone")
  assert_contains(html, "3")
  assert_contains(html, "5")
  assert_contains(html, "btn-secondary")
  assert_contains(html, "btn-danger")
  assert_contains(html, "autofocus")
}

pub fn delete_dialog_renders_from_config_without_root_model_test() {
  let html =
    dialogs.view(
      config(member_pool.MilestoneDialogDelete(id: 42, name: "Launch")),
    )
    |> element.to_document_string

  assert_contains(html, "Delete milestone")
  assert_contains(html, "Launch")
}
