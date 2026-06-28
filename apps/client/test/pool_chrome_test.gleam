import lustre/element
import support/render_assertions

import scrumbringer_client/features/layout/work_surface
import scrumbringer_client/features/pool/chrome
import scrumbringer_client/i18n/locale
import scrumbringer_client/ui/tone

pub fn pool_chrome_renders_no_projects_without_root_model_test() {
  let html =
    chrome.no_projects(locale.En)
    |> element.to_document_string

  render_assertions.contains(html, "No projects yet")
  render_assertions.contains(html, "Ask an admin to add you to a project.")
}

pub fn pool_chrome_renders_header_without_root_model_test() {
  let html =
    chrome.header(locale.En, "new-task", [
      work_surface.summary_chip("Available", "2", tone.Available),
    ])
    |> element.to_document_string

  render_assertions.contains(html, "work-surface-header")
  render_assertions.contains(html, "pool-header")
  render_assertions.contains(
    html,
    "Active tasks available for the team to claim.",
  )
  render_assertions.contains(html, "work-surface-chip available")
  render_assertions.contains(html, "btn-primary pool-header-action")
  render_assertions.contains(html, "btn-new-task-pool-header")
  render_assertions.contains(html, ">Pool<")
  render_assertions.contains(html, ">2<")
  render_assertions.contains(html, ">Available<")
  render_assertions.contains(html, "New task")
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

  render_assertions.contains(loading, "Loading")
  render_assertions.contains(no_matches, "No tasks match your filters")
  render_assertions.contains(onboarding, "No available tasks right now")
  render_assertions.contains(onboarding, "Create your first task")
  render_assertions.contains(onboarding, "New task")
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

  render_assertions.contains(heading, "My tasks")
  render_assertions.contains(hint, "Claim: My tasks")
  render_assertions.contains(empty, "No tasks in My Tasks yet")
}
