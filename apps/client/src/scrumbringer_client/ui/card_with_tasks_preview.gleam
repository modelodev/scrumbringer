import domain/card.{type Card}
import domain/org.{type OrgUser}
import domain/task.{type Task}
import gleam/option
import lustre/attribute
import lustre/element.{type Element}

import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/theme.{type Theme}
import scrumbringer_client/ui/card_with_tasks_surface

pub type Variant {
  Milestone
}

pub type Config(msg) {
  Config(
    locale: Locale,
    theme: Theme,
    card: Card,
    tasks: List(Task),
    org_users: List(OrgUser),
    preview_limit: Int,
    variant: Variant,
    on_card_click: option.Option(msg),
    on_task_click: fn(Int) -> msg,
    on_task_claim: fn(Int, Int) -> msg,
    header_actions: List(Element(msg)),
    footer_actions: List(Element(msg)),
    testid: option.Option(String),
  )
}

pub fn view(config: Config(msg)) -> Element(msg) {
  let root_attributes = case config.testid {
    option.Some(value) -> [attribute.attribute("data-testid", value)]
    option.None -> []
  }

  card_with_tasks_surface.view(card_with_tasks_surface.Config(
    locale: config.locale,
    theme: config.theme,
    card: config.card,
    tasks: config.tasks,
    org_users: config.org_users,
    preview_limit: config.preview_limit,
    surface_variant: to_surface_variant(config.variant),
    task_density: card_with_tasks_surface.Comfortable,
    progress_completed: config.card.completed_count,
    progress_total: config.card.task_count,
    description: option.None,
    on_card_click: config.on_card_click,
    on_task_click: config.on_task_click,
    on_task_claim: config.on_task_claim,
    header_actions: config.header_actions,
    footer_actions: config.footer_actions,
    root_attributes: root_attributes,
    task_item_testid: option.Some("card-preview-task-item"),
  ))
}

fn to_surface_variant(
  variant: Variant,
) -> card_with_tasks_surface.SurfaceVariant {
  case variant {
    Milestone -> card_with_tasks_surface.Milestone
  }
}
