import gleam/string
import lustre/element

import scrumbringer_client/features/layout/work_surface
import scrumbringer_client/features/pool/chrome
import scrumbringer_client/i18n/locale

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

pub fn pool_chrome_renders_no_projects_without_root_model_test() {
  let html =
    chrome.no_projects(locale.En)
    |> element.to_document_string

  assert_contains(html, "No projects yet")
  assert_contains(html, "Ask an admin to add you to a project.")
}

pub fn pool_chrome_renders_header_without_root_model_test() {
  let html =
    chrome.header(locale.En, "new-task", [
      work_surface.summary_chip("Available", "2", work_surface.Available),
    ])
    |> element.to_document_string

  assert_contains(html, "work-surface-header")
  assert_contains(html, "pool-header")
  assert_contains(html, "Choose the next personal task to claim.")
  assert_contains(html, "work-surface-chip available")
  assert_contains(html, "btn-primary pool-header-action")
  assert_contains(html, "btn-new-task-pool-header")
  assert_contains(html, ">Pool<")
  assert_contains(html, ">2<")
  assert_contains(html, ">Available<")
  assert_contains(html, "New task")
}

pub fn pool_chrome_renders_task_states_without_root_model_test() {
  let loading =
    chrome.tasks_loading(locale.En)
    |> element.to_document_string

  let no_matches =
    chrome.tasks_no_matches(locale.En)
    |> element.to_document_string

  let onboarding =
    chrome.tasks_onboarding(locale.En, "new-task")
    |> element.to_document_string

  assert_contains(loading, "Loading")
  assert_contains(no_matches, "No tasks match your filters")
  assert_contains(onboarding, "No available tasks right now")
  assert_contains(onboarding, "Create your first task")
  assert_contains(onboarding, "New task")
}

pub fn pool_chrome_renders_my_tasks_states_without_root_model_test() {
  let heading =
    chrome.my_tasks_heading(locale.En)
    |> element.to_document_string

  let hint =
    chrome.my_tasks_dropzone_hint(locale.En)
    |> element.to_document_string

  let empty =
    chrome.no_claimed_tasks(locale.En)
    |> element.to_document_string

  assert_contains(heading, "My tasks")
  assert_contains(hint, "Claim: My tasks")
  assert_contains(empty, "No tasks in My Tasks yet")
}
