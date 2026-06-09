//// Shared root helpers for pool adapters.

import scrumbringer_client/client_state
import scrumbringer_client/client_state/admin as admin_state
import scrumbringer_client/client_state/admin/cards as admin_cards
import scrumbringer_client/client_state/admin/rules as admin_rules
import scrumbringer_client/client_state/admin/task_templates as admin_task_templates
import scrumbringer_client/client_state/admin/workflows as admin_workflows
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/pool as member_pool

pub fn set_member_pool(
  model: client_state.Model,
  pool: member_pool.Model,
) -> client_state.Model {
  client_state.update_member(model, fn(member) {
    member_state.MemberModel(..member, pool: pool)
  })
}

pub fn set_admin_cards(
  model: client_state.Model,
  cards: admin_cards.Model,
) -> client_state.Model {
  client_state.update_admin(model, fn(admin) {
    admin_state.AdminModel(..admin, cards: cards)
  })
}

pub fn set_admin_rules(
  model: client_state.Model,
  rules: admin_rules.Model,
) -> client_state.Model {
  client_state.update_admin(model, fn(admin) {
    admin_state.AdminModel(..admin, rules: rules)
  })
}

pub fn set_admin_task_templates(
  model: client_state.Model,
  task_templates: admin_task_templates.Model,
) -> client_state.Model {
  client_state.update_admin(model, fn(admin) {
    admin_state.AdminModel(..admin, task_templates: task_templates)
  })
}

pub fn set_admin_workflows(
  model: client_state.Model,
  workflows: admin_workflows.Model,
) -> client_state.Model {
  client_state.update_admin(model, fn(admin) {
    admin_state.AdminModel(..admin, workflows: workflows)
  })
}
