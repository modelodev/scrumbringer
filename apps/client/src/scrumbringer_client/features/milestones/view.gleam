import domain/card as card_domain
import domain/milestone.{
  type MilestoneProgress, type MilestoneState, Active, Completed, Ready,
}
import domain/org_role
import domain/remote.{Failed, Loaded, Loading, NotAsked}
import domain/task as task_domain
import domain/task_status
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option
import gleam/string
import lustre/attribute
import lustre/element.{type Element, none}
import lustre/element/html.{
  button, div, form, h3, input, p, span, text, textarea,
}
import lustre/element/keyed
import lustre/event

import scrumbringer_client/client_state
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/milestones/content_pane
import scrumbringer_client/features/milestones/context_pane
import scrumbringer_client/features/milestones/ids as milestone_ids
import scrumbringer_client/features/milestones/list_pane
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/helpers/i18n as helpers_i18n
import scrumbringer_client/helpers/selection as helpers_selection
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/permissions
import scrumbringer_client/ui/action_buttons
import scrumbringer_client/ui/action_row
import scrumbringer_client/ui/badge
import scrumbringer_client/ui/card_with_tasks_preview
import scrumbringer_client/ui/confirm_dialog
import scrumbringer_client/ui/detail_metrics
import scrumbringer_client/ui/dialog
import scrumbringer_client/ui/empty_state
import scrumbringer_client/ui/form_field
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/move_menu

pub fn view(model: client_state.Model) -> Element(client_state.Msg) {
  let content = case model.member.pool.member_milestones {
    NotAsked | Loading ->
      div([attribute.class("milestones-state milestones-loading")], [
        text(helpers_i18n.i18n_t(model, i18n_text.LoadingEllipsis)),
      ])

    Failed(_) ->
      div([attribute.class("milestones-state milestones-error")], [
        text(helpers_i18n.i18n_t(model, i18n_text.MilestonesLoadError)),
      ])

    Loaded(items) ->
      view_loaded(model, filter_for_selected_project(model, items))
  }

  div([], [
    content,
    view_create_dialog(model),
    view_activate_dialog(model),
    view_edit_dialog(model),
    view_delete_dialog(model),
  ])
}

fn filter_for_selected_project(
  model: client_state.Model,
  items: List(MilestoneProgress),
) -> List(MilestoneProgress) {
  case model.core.selected_project_id {
    option.Some(project_id) ->
      list.filter(items, fn(progress) {
        progress.milestone.project_id == project_id
      })
    option.None -> items
  }
}

fn view_loaded(
  model: client_state.Model,
  items: List(MilestoneProgress),
) -> Element(client_state.Msg) {
  let filtered = apply_filters(model, items)

  case items, filtered {
    [], _ -> view_empty_state(model, i18n_text.MilestonesEmpty)
    _, [] -> view_empty_state(model, i18n_text.MilestonesNoResults)
    _, _ -> view_master_detail(model, filtered)
  }
}

fn view_master_detail(
  model: client_state.Model,
  items: List(MilestoneProgress),
) -> Element(client_state.Msg) {
  let selected = selected_progress(model, items)

  div(
    [
      attribute.class("milestones-view milestones-master-detail"),
      attribute.attribute("data-testid", "milestones-view"),
    ],
    [
      div([attribute.class("milestones-header")], [
        div([attribute.class("milestones-header-main")], [
          h3([attribute.class("milestones-title")], [
            text(helpers_i18n.i18n_t(model, i18n_text.Milestones)),
          ]),
          div([attribute.class("milestones-toolbar-actions")], [
            view_create_button(model),
          ]),
        ]),
      ]),
      div([attribute.class("milestones-shell")], [
        view_milestone_list_pane(model, items, selected),
        view_milestone_detail_pane(model, selected),
      ]),
    ],
  )
}

fn view_milestone_list_pane(
  model: client_state.Model,
  items: List(MilestoneProgress),
  selected: option.Option(MilestoneProgress),
) -> Element(client_state.Msg) {
  list_pane.view(list_pane.Config(
    model: model,
    items: items,
    selected_id: selected |> option.map(fn(progress) { progress.milestone.id }),
    on_search_change: fn(value) {
      client_state.pool_msg(pool_messages.MemberMilestoneSearchChanged(value))
    },
    on_toggle_completed: client_state.pool_msg(
      pool_messages.MemberMilestonesShowCompletedToggled,
    ),
    on_toggle_empty: client_state.pool_msg(
      pool_messages.MemberMilestonesShowEmptyToggled,
    ),
    on_select: fn(milestone_id) {
      client_state.pool_msg(pool_messages.MemberMilestoneDetailsClicked(
        milestone_id,
      ))
    },
    loose_tasks_count: fn(milestone_id) {
      loose_tasks_count(model, milestone_id)
    },
    empty_cards_count: fn(milestone_id) {
      empty_cards_count(model, milestone_id)
    },
    milestone_state_label: fn(state) { milestone_state_label(model, state) },
    milestone_state_variant: milestone_state_variant,
  ))
}

fn view_milestone_detail_pane(
  model: client_state.Model,
  selected: option.Option(MilestoneProgress),
) -> Element(client_state.Msg) {
  case selected {
    option.Some(progress) -> view_selected_milestone_detail(model, progress)
    option.None ->
      div([attribute.class("milestone-detail-pane milestone-detail-empty")], [
        h3([], [
          text(helpers_i18n.i18n_t(model, i18n_text.MilestoneNoSelection)),
        ]),
        p([], [
          text(helpers_i18n.i18n_t(model, i18n_text.MilestoneNoSelectionHint)),
        ]),
      ])
  }
}

fn view_selected_milestone_detail(
  model: client_state.Model,
  progress: MilestoneProgress,
) -> Element(client_state.Msg) {
  let milestone_id = progress.milestone.id
  let loose_tasks = loose_tasks_count(model, milestone_id)
  let tasks_in_cards = tasks_in_cards_count(model, milestone_id)
  let blocked_tasks = blocked_tasks_count(model, milestone_id)
  let empty_cards = empty_cards_count(model, milestone_id)

  div(
    [
      attribute.class("milestone-detail-pane"),
      attribute.attribute("data-testid", "milestone-detail-pane"),
    ],
    [
      content_pane.view(content_pane.Config(
        model: model,
        progress: progress,
        tasks_in_cards: tasks_in_cards,
        loose_tasks: loose_tasks,
        cards_section: view_cards_section(model, milestone_id),
        loose_tasks_panel: view_loose_tasks_panel(model, milestone_id),
        milestone_state_label: fn(state) { milestone_state_label(model, state) },
        milestone_state_variant: milestone_state_variant,
        progress_percentage: milestone_progress_percentage,
      )),
      context_pane.view(context_pane.Config(
        model: model,
        progress: progress,
        tasks_in_cards: tasks_in_cards,
        loose_tasks: loose_tasks,
        blocked_tasks: blocked_tasks,
        empty_cards: empty_cards,
        actions: action_row.view(
          [
            view_quick_create_card_button(model, milestone_id),
            view_quick_create_task_button(model, milestone_id),
          ],
          [view_activate_button(model, progress)],
          [
            view_edit_button(model, progress),
            view_delete_button(model, progress),
          ],
        ),
        milestone_state_label: milestone_state_label(
          model,
          progress.milestone.state,
        ),
        metrics_summary: view_milestone_metrics_summary(model),
      )),
    ],
  )
}

fn view_milestone_metrics_summary(
  model: client_state.Model,
) -> Element(client_state.Msg) {
  case model.member.pool.member_milestone_metrics {
    NotAsked | Loading ->
      p([attribute.class("milestone-metrics-loading")], [
        text(helpers_i18n.i18n_t(model, i18n_text.LoadingMetrics)),
      ])

    Failed(_) ->
      p([attribute.class("milestone-metrics-error")], [
        text(helpers_i18n.i18n_t(model, i18n_text.MetricsLoadError)),
      ])

    Loaded(metrics) ->
      div([attribute.class("milestone-planning-summary")], [
        detail_metrics.view_row(
          helpers_i18n.i18n_t(model, i18n_text.MilestoneCardsLabel),
          int.to_string(metrics.cards_completed)
            <> "/"
            <> int.to_string(metrics.cards_total),
        ),
        detail_metrics.view_row(
          helpers_i18n.i18n_t(model, i18n_text.MilestoneTasksLabel),
          int.to_string(metrics.tasks_completed)
            <> "/"
            <> int.to_string(metrics.tasks_total),
        ),
        detail_metrics.view_row(
          helpers_i18n.i18n_t(model, i18n_text.MetricsPoolLifetimeAvg),
          detail_metrics.format_duration_s(metrics.health.avg_pool_lifetime_s),
        ),
        detail_metrics.view_row(
          helpers_i18n.i18n_t(model, i18n_text.MetricsRebotesAvg),
          int.to_string(metrics.health.avg_rebotes),
        ),
      ])
  }
}

fn selected_progress(
  model: client_state.Model,
  items: List(MilestoneProgress),
) -> option.Option(MilestoneProgress) {
  case model.member.pool.member_selected_milestone_id {
    option.Some(selected_id) ->
      case
        list.find(items, fn(progress) { progress.milestone.id == selected_id })
      {
        Ok(progress) -> option.Some(progress)
        Error(_) -> default_selected_progress(items)
      }
    option.None -> default_selected_progress(items)
  }
}

fn default_selected_progress(
  items: List(MilestoneProgress),
) -> option.Option(MilestoneProgress) {
  case list.find(items, fn(progress) { progress.milestone.state == Active }) {
    Ok(progress) -> option.Some(progress)
    Error(_) ->
      case
        list.find(items, fn(progress) { progress.milestone.state == Ready })
      {
        Ok(progress) -> option.Some(progress)
        Error(_) -> list.first(items) |> option.from_result
      }
  }
}

fn view_empty_state(
  model: client_state.Model,
  message: i18n_text.Text,
) -> Element(client_state.Msg) {
  div([attribute.class("milestones-state milestones-empty")], [
    empty_state.simple(icons.Clipboard, helpers_i18n.i18n_t(model, message)),
    case can_manage_milestones(model) {
      True ->
        div([attribute.class("milestones-empty-actions")], [
          button(
            [
              attribute.class("btn btn-sm btn-primary"),
              attribute.attribute("type", "button"),
              attribute.attribute("data-testid", "milestones-create-empty"),
              attribute.id(milestone_ids.create_empty_button_id()),
              event.on_click(client_state.pool_msg(
                pool_messages.MemberMilestoneCreateClicked,
              )),
            ],
            [text(helpers_i18n.i18n_t(model, i18n_text.CreateFirstMilestone))],
          ),
        ])
      False -> none()
    },
  ])
}

fn view_create_button(model: client_state.Model) -> Element(client_state.Msg) {
  case can_manage_milestones(model) {
    True ->
      button(
        [
          attribute.class("btn btn-sm btn-primary"),
          attribute.attribute("type", "button"),
          attribute.attribute("data-testid", "milestones-create-button"),
          attribute.id(milestone_ids.create_button_id()),
          event.on_click(client_state.pool_msg(
            pool_messages.MemberMilestoneCreateClicked,
          )),
        ],
        [text("+ " <> helpers_i18n.i18n_t(model, i18n_text.CreateMilestone))],
      )
    False -> none()
  }
}

fn view_quick_create_card_button(
  model: client_state.Model,
  milestone_id: Int,
) -> Element(client_state.Msg) {
  case can_manage_milestones(model) {
    True ->
      button(
        [
          attribute.class("btn btn-sm btn-primary"),
          attribute.attribute("type", "button"),
          attribute.attribute(
            "data-testid",
            "milestone-quick-new-card:" <> int.to_string(milestone_id),
          ),
          event.on_click(
            client_state.pool_msg(
              pool_messages.MemberMilestoneCreateCardClicked(milestone_id),
            ),
          ),
        ],
        [text("+ " <> helpers_i18n.i18n_t(model, i18n_text.QuickCard))],
      )
    False -> none()
  }
}

fn view_quick_create_task_button(
  model: client_state.Model,
  milestone_id: Int,
) -> Element(client_state.Msg) {
  case can_manage_milestones(model) {
    True ->
      button(
        [
          attribute.class("btn btn-sm btn-secondary"),
          attribute.attribute("type", "button"),
          attribute.attribute(
            "data-testid",
            "milestone-quick-new-task:" <> int.to_string(milestone_id),
          ),
          event.on_click(
            client_state.pool_msg(
              pool_messages.MemberMilestoneCreateTaskClicked(milestone_id),
            ),
          ),
        ],
        [text("+ " <> helpers_i18n.i18n_t(model, i18n_text.QuickTask))],
      )
    False -> none()
  }
}

fn view_activate_button(
  model: client_state.Model,
  progress: MilestoneProgress,
) -> Element(client_state.Msg) {
  let milestone_id = progress.milestone.id
  let in_flight =
    model.member.pool.member_milestone_activate_in_flight_id
    == option.Some(milestone_id)

  case
    can_manage_milestones(model),
    progress.milestone.state,
    has_other_active_milestone(model, milestone_id)
  {
    True, Ready, False ->
      button(
        [
          attribute.class("btn btn-sm btn-primary"),
          attribute.attribute("type", "button"),
          attribute.attribute(
            "data-testid",
            "milestone-activate-button:" <> int.to_string(milestone_id),
          ),
          attribute.disabled(in_flight),
          event.on_click(
            client_state.pool_msg(
              pool_messages.MemberMilestoneActivatePromptClicked(milestone_id),
            ),
          ),
        ],
        [
          text(case in_flight {
            True -> helpers_i18n.i18n_t(model, i18n_text.ActivatingMilestone)
            False -> helpers_i18n.i18n_t(model, i18n_text.ActivateMilestone)
          }),
        ],
      )
    _, _, _ -> none()
  }
}

fn view_edit_button(
  model: client_state.Model,
  progress: MilestoneProgress,
) -> Element(client_state.Msg) {
  case can_manage_milestones(model) {
    True ->
      action_buttons.edit_button_with_testid(
        helpers_i18n.i18n_t(model, i18n_text.EditMilestone),
        client_state.pool_msg(pool_messages.MemberMilestoneEditClicked(
          progress.milestone.id,
        )),
        "milestone-edit-button:" <> int.to_string(progress.milestone.id),
      )
    False -> none()
  }
}

fn view_delete_button(
  model: client_state.Model,
  progress: MilestoneProgress,
) -> Element(client_state.Msg) {
  case can_manage_milestones(model), progress.milestone.state {
    True, Ready ->
      action_buttons.delete_button_with_testid(
        helpers_i18n.i18n_t(model, i18n_text.DeleteMilestone),
        client_state.pool_msg(pool_messages.MemberMilestoneDeleteClicked(
          progress.milestone.id,
        )),
        "milestone-delete-button:" <> int.to_string(progress.milestone.id),
      )
    _, _ -> none()
  }
}

fn apply_filters(
  model: client_state.Model,
  items: List(MilestoneProgress),
) -> List(MilestoneProgress) {
  items
  |> list.filter(fn(progress) {
    case string.trim(model.member.pool.member_milestones_search_query) {
      "" -> True
      query ->
        string.contains(
          string.lowercase(progress.milestone.name),
          string.lowercase(query),
        )
    }
  })
  |> list.filter(fn(progress) {
    case model.member.pool.member_milestones_show_completed {
      True -> True
      False -> progress.milestone.state != Completed
    }
  })
  |> list.filter(fn(progress) {
    case model.member.pool.member_milestones_show_empty {
      True -> True
      False ->
        case progress.cards_total == 0 {
          True -> progress.tasks_total != 0
          False -> True
        }
    }
  })
}

fn view_cards_section(
  model: client_state.Model,
  milestone_id: Int,
) -> Element(client_state.Msg) {
  let cards = cards_for_milestone(model, milestone_id)
  let destinations = ready_destination_milestones(model, milestone_id)
  let can_move =
    can_manage_milestones(model) && is_ready_milestone(model, milestone_id)
  let can_drag = can_move && destinations != []

  case cards {
    [] -> none()
    _ ->
      div([attribute.class("milestone-content-section detail-section")], [
        p([attribute.class("milestone-subsection-title detail-section-title")], [
          text(helpers_i18n.i18n_t(model, i18n_text.MilestoneCardsLabel)),
        ]),
        keyed.div(
          [attribute.class("milestone-cards-list")],
          list.map(cards, fn(card) {
            let card_domain.Card(id: card_id, ..) = card
            let card_tasks = tasks_for_card(model, card_id)
            let org_users = case model.admin.members.org_users_cache {
              Loaded(users) -> users
              _ -> []
            }
            let row_testid =
              "milestone-card-row:"
              <> int.to_string(milestone_id)
              <> ":"
              <> int.to_string(card_id)

            #(int.to_string(card_id), {
              let preview =
                card_with_tasks_preview.view(card_with_tasks_preview.Config(
                  locale: model.ui.locale,
                  theme: model.ui.theme,
                  card: card,
                  tasks: card_tasks,
                  org_users: org_users,
                  preview_limit: 3,
                  variant: card_with_tasks_preview.Milestone,
                  on_card_click: option.None,
                  on_task_click: fn(task_id) {
                    client_state.pool_msg(pool_messages.MemberTaskDetailsOpened(
                      task_id,
                    ))
                  },
                  on_task_claim: fn(task_id, version) {
                    client_state.pool_msg(pool_messages.MemberClaimClicked(
                      task_id,
                      version,
                    ))
                  },
                  footer_actions: case can_move {
                    True -> [
                      view_move_card_actions(
                        model,
                        card_id,
                        milestone_id,
                        destinations,
                      ),
                    ]
                    False -> []
                  },
                  testid: option.None,
                ))

              let attrs = [
                attribute.class("milestone-card-wrapper"),
                attribute.attribute("data-testid", row_testid),
              ]
              let attrs = case can_drag {
                True ->
                  list.append(attrs, [
                    attribute.attribute("draggable", "true"),
                    event.on(
                      "dragstart",
                      decode.success(
                        client_state.pool_msg(
                          pool_messages.MemberMilestoneCardDragStarted(
                            card_id,
                            milestone_id,
                          ),
                        ),
                      ),
                    ),
                    event.on(
                      "dragend",
                      decode.success(client_state.pool_msg(
                        pool_messages.MemberMilestoneDragEnded,
                      )),
                    ),
                  ])
                False -> attrs
              }

              div(attrs, [preview])
            })
          }),
        ),
      ])
  }
}

fn cards_for_milestone(
  model: client_state.Model,
  milestone_id: Int,
) -> List(card_domain.Card) {
  case model.member.pool.member_cards {
    Loaded(cards) ->
      list.filter(cards, fn(card) {
        card.milestone_id == option.Some(milestone_id)
      })
    _ -> []
  }
}

fn tasks_for_card(
  model: client_state.Model,
  card_id: Int,
) -> List(task_domain.Task) {
  case model.member.pool.member_tasks {
    Loaded(tasks) ->
      list.filter(tasks, fn(task) { task.card_id == option.Some(card_id) })
    _ -> []
  }
}

fn view_loose_tasks_section(
  model: client_state.Model,
  milestone_id: Int,
) -> Element(client_state.Msg) {
  let tasks = loose_tasks_for_milestone(model, milestone_id)
  let destinations = ready_destination_milestones(model, milestone_id)
  let can_move =
    can_manage_milestones(model) && is_ready_milestone(model, milestone_id)
  let can_drag = can_move && destinations != []

  case tasks {
    [] -> none()
    _ ->
      div([attribute.class("milestone-content-section detail-section")], [
        p([attribute.class("milestone-subsection-title detail-section-title")], [
          text(helpers_i18n.i18n_t(model, i18n_text.MilestoneTasksLabel)),
        ]),
        keyed.div(
          [attribute.class("milestone-cards-list")],
          list.map(tasks, fn(task) {
            let task_domain.Task(id: task_id, title: title, status: status, ..) =
              task

            #(int.to_string(task_id), {
              let attrs = [
                attribute.class("milestone-card-row detail-item-row"),
                attribute.attribute(
                  "data-testid",
                  "milestone-task-row:"
                    <> int.to_string(milestone_id)
                    <> ":"
                    <> int.to_string(task_id),
                ),
              ]

              let attrs = case can_drag {
                True ->
                  attrs
                  |> list.append([
                    attribute.attribute("draggable", "true"),
                    event.on(
                      "dragstart",
                      decode.success(
                        client_state.pool_msg(
                          pool_messages.MemberMilestoneTaskDragStarted(
                            task_id,
                            milestone_id,
                          ),
                        ),
                      ),
                    ),
                    event.on(
                      "dragend",
                      decode.success(client_state.pool_msg(
                        pool_messages.MemberMilestoneDragEnded,
                      )),
                    ),
                  ])
                False -> attrs
              }

              div(attrs, [
                p([attribute.class("milestone-card-title")], [text(title)]),
                div([attribute.class("milestone-card-actions")], [
                  span([attribute.class("milestone-card-progress")], [
                    text(task_status_to_short(model, status)),
                  ]),
                  case can_move {
                    True ->
                      view_move_task_actions(
                        model,
                        task_id,
                        milestone_id,
                        destinations,
                      )
                    False -> none()
                  },
                ]),
              ])
            })
          }),
        ),
      ])
  }
}

fn view_loose_tasks_panel(
  model: client_state.Model,
  milestone_id: Int,
) -> Element(client_state.Msg) {
  let tasks = loose_tasks_for_milestone(model, milestone_id)

  case tasks {
    [] -> none()
    _ ->
      div([attribute.class("milestone-loose-tasks-panel")], [
        div([attribute.class("milestone-content-note")], [
          p([attribute.class("milestone-subsection-title")], [
            text(helpers_i18n.i18n_t(model, i18n_text.MilestoneLooseTasksNotice)),
          ]),
          p([attribute.class("milestone-item-description")], [
            text(helpers_i18n.i18n_t(model, i18n_text.MilestoneLooseTasksHint)),
          ]),
        ]),
        view_loose_tasks_section(model, milestone_id),
      ])
  }
}

fn loose_tasks_for_milestone(
  model: client_state.Model,
  milestone_id: Int,
) -> List(task_domain.Task) {
  case model.member.pool.member_tasks {
    Loaded(tasks) ->
      list.filter(tasks, fn(task) {
        task.milestone_id == option.Some(milestone_id)
        && task.card_id == option.None
      })
    _ -> []
  }
}

fn loose_tasks_count(model: client_state.Model, milestone_id: Int) -> Int {
  loose_tasks_for_milestone(model, milestone_id) |> list.length
}

fn tasks_in_cards_count(model: client_state.Model, milestone_id: Int) -> Int {
  case model.member.pool.member_tasks {
    Loaded(tasks) ->
      list.count(tasks, fn(task) {
        task.card_id != option.None
        && effective_milestone_id(model, task) == option.Some(milestone_id)
      })
    _ -> 0
  }
}

fn blocked_tasks_count(model: client_state.Model, milestone_id: Int) -> Int {
  case model.member.pool.member_tasks {
    Loaded(tasks) ->
      list.count(tasks, fn(task) {
        effective_milestone_id(model, task) == option.Some(milestone_id)
        && task.blocked_count > 0
      })
    _ -> 0
  }
}

fn effective_milestone_id(
  model: client_state.Model,
  task: task_domain.Task,
) -> option.Option(Int) {
  case task.milestone_id {
    option.Some(id) -> option.Some(id)
    option.None ->
      case task.card_id {
        option.Some(card_id) ->
          case model.member.pool.member_cards {
            Loaded(cards) ->
              list.find(cards, fn(card) { card.id == card_id })
              |> option.from_result
              |> option.map(fn(card) { card.milestone_id })
              |> option.flatten
            _ -> option.None
          }
        option.None -> option.None
      }
  }
}

fn empty_cards_count(model: client_state.Model, milestone_id: Int) -> Int {
  cards_for_milestone(model, milestone_id)
  |> list.count(fn(card) { card.task_count == 0 })
}

fn ready_destination_milestones(
  model: client_state.Model,
  current_milestone_id: Int,
) -> List(milestone.Milestone) {
  case model.member.pool.member_milestones {
    Loaded(items) ->
      items
      |> list.filter(fn(progress) {
        progress.milestone.state == Ready
        && progress.milestone.id != current_milestone_id
      })
      |> list.map(fn(progress) { progress.milestone })
    _ -> []
  }
}

fn is_ready_milestone(model: client_state.Model, milestone_id: Int) -> Bool {
  case model.member.pool.member_milestones {
    Loaded(items) ->
      items
      |> list.any(fn(progress) {
        progress.milestone.id == milestone_id
        && progress.milestone.state == Ready
      })
    _ -> False
  }
}

fn view_move_card_actions(
  model: client_state.Model,
  card_id: Int,
  from_milestone_id: Int,
  destinations: List(milestone.Milestone),
) -> Element(client_state.Msg) {
  move_menu.view(
    helpers_i18n.i18n_t(model, i18n_text.MilestoneMoveTo),
    "milestone-move-menu-card:"
      <> int.to_string(from_milestone_id)
      <> ":"
      <> int.to_string(card_id),
    list.map(destinations, fn(dest) {
      move_menu.option(
        dest.name,
        "milestone-move-card:"
          <> int.to_string(from_milestone_id)
          <> ":"
          <> int.to_string(card_id)
          <> ":"
          <> int.to_string(dest.id),
        client_state.pool_msg(pool_messages.MemberMilestoneCardMoveClicked(
          card_id,
          from_milestone_id,
          dest.id,
        )),
      )
    }),
  )
}

fn view_move_task_actions(
  model: client_state.Model,
  task_id: Int,
  from_milestone_id: Int,
  destinations: List(milestone.Milestone),
) -> Element(client_state.Msg) {
  move_menu.view(
    helpers_i18n.i18n_t(model, i18n_text.MilestoneMoveTo),
    "milestone-move-menu-task:"
      <> int.to_string(from_milestone_id)
      <> ":"
      <> int.to_string(task_id),
    list.map(destinations, fn(dest) {
      move_menu.option(
        dest.name,
        "milestone-move-task:"
          <> int.to_string(from_milestone_id)
          <> ":"
          <> int.to_string(task_id)
          <> ":"
          <> int.to_string(dest.id),
        client_state.pool_msg(pool_messages.MemberMilestoneTaskMoveClicked(
          task_id,
          from_milestone_id,
          dest.id,
        )),
      )
    }),
  )
}

fn task_status_to_short(
  model: client_state.Model,
  status: task_status.TaskStatus,
) -> String {
  case status {
    task_status.Available ->
      helpers_i18n.i18n_t(model, i18n_text.MilestoneTaskStatusAvailable)
    task_status.Claimed(_) ->
      helpers_i18n.i18n_t(model, i18n_text.MilestoneTaskStatusClaimed)
    task_status.Completed ->
      helpers_i18n.i18n_t(model, i18n_text.MilestoneTaskStatusCompleted)
  }
}

fn milestone_progress_percentage(progress: MilestoneProgress) -> Int {
  let total = progress.cards_total + progress.tasks_total
  let done = progress.cards_completed + progress.tasks_completed

  case total <= 0 {
    True -> 0
    False -> done * 100 / total
  }
}

fn milestone_state_label(
  model: client_state.Model,
  state: MilestoneState,
) -> String {
  helpers_i18n.i18n_t(model, case state {
    Ready -> i18n_text.MilestonesReady
    Active -> i18n_text.MilestonesActive
    Completed -> i18n_text.MilestonesCompleted
  })
}

fn milestone_state_variant(state: MilestoneState) -> badge.BadgeVariant {
  case state {
    Ready -> badge.Warning
    Active -> badge.Primary
    Completed -> badge.Success
  }
}

fn can_manage_milestones(model: client_state.Model) -> Bool {
  case model.core.user {
    option.Some(user) if user.org_role == org_role.Admin -> True
    option.Some(_) ->
      case helpers_selection.selected_project(model) {
        option.Some(project) -> permissions.is_project_manager(project)
        option.None -> False
      }
    option.None -> False
  }
}

fn has_other_active_milestone(
  model: client_state.Model,
  milestone_id: Int,
) -> Bool {
  case model.member.pool.member_milestones {
    Loaded(milestones) ->
      list.any(milestones, fn(progress) {
        progress.milestone.id != milestone_id
        && progress.milestone.state == Active
      })
    _ -> False
  }
}

fn find_milestone_progress(
  model: client_state.Model,
  milestone_id: Int,
) -> option.Option(MilestoneProgress) {
  case model.member.pool.member_milestones {
    Loaded(milestones) ->
      list.find_map(milestones, fn(progress) {
        case progress.milestone.id == milestone_id {
          True -> Ok(progress)
          False -> Error(Nil)
        }
      })
      |> option.from_result
    _ -> option.None
  }
}

fn view_activate_dialog(model: client_state.Model) -> Element(client_state.Msg) {
  let maybe_progress = case model.member.pool.member_milestone_dialog {
    member_pool.MilestoneDialogActivate(id: id) ->
      find_milestone_progress(model, id)
    _ -> option.None
  }

  case maybe_progress {
    option.Some(progress) ->
      dialog.view(
        dialog.DialogConfig(
          title: helpers_i18n.i18n_t(model, i18n_text.MilestoneActivationTitle),
          icon: option.None,
          size: dialog.DialogSm,
          on_close: client_state.pool_msg(
            pool_messages.MemberMilestoneDialogClosed,
          ),
        ),
        True,
        model.member.pool.member_milestone_dialog_error,
        [
          p([], [
            text(helpers_i18n.i18n_t(
              model,
              i18n_text.MilestoneActivationBody(
                cards_count: progress.cards_total,
                tasks_count: progress.tasks_total,
              ),
            )),
          ]),
          p([], [
            text(helpers_i18n.i18n_t(
              model,
              i18n_text.MilestoneActivationWarning,
            )),
          ]),
        ],
        [
          button(
            [
              attribute.type_("button"),
              attribute.autofocus(True),
              attribute.disabled(
                model.member.pool.member_milestone_dialog_in_flight,
              ),
              event.on_click(client_state.pool_msg(
                pool_messages.MemberMilestoneDialogClosed,
              )),
            ],
            [text(helpers_i18n.i18n_t(model, i18n_text.Cancel))],
          ),
          button(
            [
              attribute.type_("button"),
              attribute.class("btn btn-danger"),
              attribute.disabled(
                model.member.pool.member_milestone_dialog_in_flight,
              ),
              event.on_click(
                client_state.pool_msg(
                  pool_messages.MemberMilestoneActivateClicked(
                    progress.milestone.id,
                  ),
                ),
              ),
            ],
            [
              text(case model.member.pool.member_milestone_dialog_in_flight {
                True ->
                  helpers_i18n.i18n_t(model, i18n_text.ActivatingMilestone)
                False -> helpers_i18n.i18n_t(model, i18n_text.ActivateMilestone)
              }),
            ],
          ),
        ],
      )
    option.None -> none()
  }
}

fn view_create_dialog(model: client_state.Model) -> Element(client_state.Msg) {
  let #(is_open, name, description) = case
    model.member.pool.member_milestone_dialog
  {
    member_pool.MilestoneDialogCreate(name: name, description: description) -> #(
      True,
      name,
      description,
    )
    _ -> #(False, "", "")
  }

  dialog.view(
    dialog.DialogConfig(
      title: helpers_i18n.i18n_t(model, i18n_text.CreateMilestone),
      icon: option.None,
      size: dialog.DialogSm,
      on_close: client_state.pool_msg(pool_messages.MemberMilestoneDialogClosed),
    ),
    is_open,
    model.member.pool.member_milestone_dialog_error,
    [
      form(
        [
          event.on_submit(fn(_) {
            client_state.pool_msg(pool_messages.MemberMilestoneCreateSubmitted)
          }),
          attribute.id("milestone-create-form"),
        ],
        [
          form_field.view_required(
            helpers_i18n.i18n_t(model, i18n_text.Name),
            input([
              attribute.type_("text"),
              attribute.value(name),
              attribute.required(True),
              event.on_input(fn(value) {
                client_state.pool_msg(pool_messages.MemberMilestoneNameChanged(
                  value,
                ))
              }),
            ]),
          ),
          form_field.view(
            helpers_i18n.i18n_t(model, i18n_text.Description),
            textarea(
              [
                attribute.rows(4),
                attribute.value(description),
                event.on_input(fn(value) {
                  client_state.pool_msg(
                    pool_messages.MemberMilestoneDescriptionChanged(value),
                  )
                }),
              ],
              description,
            ),
          ),
        ],
      ),
    ],
    [
      dialog.cancel_button(
        model,
        client_state.pool_msg(pool_messages.MemberMilestoneDialogClosed),
      ),
      button(
        [
          attribute.type_("submit"),
          attribute.form("milestone-create-form"),
          attribute.disabled(
            model.member.pool.member_milestone_dialog_in_flight,
          ),
        ],
        [
          text(case model.member.pool.member_milestone_dialog_in_flight {
            True -> helpers_i18n.i18n_t(model, i18n_text.Creating)
            False -> helpers_i18n.i18n_t(model, i18n_text.Create)
          }),
        ],
      ),
    ],
  )
}

fn view_edit_dialog(model: client_state.Model) -> Element(client_state.Msg) {
  let #(is_open, id, name, description) = case
    model.member.pool.member_milestone_dialog
  {
    member_pool.MilestoneDialogEdit(
      id: id,
      name: name,
      description: description,
    ) -> #(True, id, name, description)
    _ -> #(False, 0, "", "")
  }

  dialog.view(
    dialog.DialogConfig(
      title: helpers_i18n.i18n_t(model, i18n_text.EditMilestone),
      icon: option.None,
      size: dialog.DialogSm,
      on_close: client_state.pool_msg(pool_messages.MemberMilestoneDialogClosed),
    ),
    is_open,
    model.member.pool.member_milestone_dialog_error,
    [
      form(
        [
          event.on_submit(fn(_) {
            client_state.pool_msg(pool_messages.MemberMilestoneEditSubmitted(id))
          }),
          attribute.id("milestone-edit-form"),
        ],
        [
          form_field.view_required(
            helpers_i18n.i18n_t(model, i18n_text.Name),
            input([
              attribute.type_("text"),
              attribute.value(name),
              attribute.required(True),
              event.on_input(fn(value) {
                client_state.pool_msg(pool_messages.MemberMilestoneNameChanged(
                  value,
                ))
              }),
            ]),
          ),
          form_field.view(
            helpers_i18n.i18n_t(model, i18n_text.Description),
            textarea(
              [
                attribute.rows(4),
                attribute.value(description),
                event.on_input(fn(value) {
                  client_state.pool_msg(
                    pool_messages.MemberMilestoneDescriptionChanged(value),
                  )
                }),
              ],
              description,
            ),
          ),
        ],
      ),
    ],
    [
      dialog.cancel_button(
        model,
        client_state.pool_msg(pool_messages.MemberMilestoneDialogClosed),
      ),
      button(
        [
          attribute.type_("submit"),
          attribute.form("milestone-edit-form"),
          attribute.disabled(
            model.member.pool.member_milestone_dialog_in_flight,
          ),
        ],
        [
          text(case model.member.pool.member_milestone_dialog_in_flight {
            True -> helpers_i18n.i18n_t(model, i18n_text.Saving)
            False -> helpers_i18n.i18n_t(model, i18n_text.Save)
          }),
        ],
      ),
    ],
  )
}

fn view_delete_dialog(model: client_state.Model) -> Element(client_state.Msg) {
  let #(is_open, id, name) = case model.member.pool.member_milestone_dialog {
    member_pool.MilestoneDialogDelete(id: id, name: name) -> #(True, id, name)
    _ -> #(False, 0, "")
  }

  confirm_dialog.view(confirm_dialog.ConfirmConfig(
    title: helpers_i18n.i18n_t(model, i18n_text.DeleteMilestoneTitle),
    body: [
      p([], [
        text(helpers_i18n.i18n_t(model, i18n_text.DeleteMilestoneConfirm(name))),
      ]),
    ],
    confirm_label: helpers_i18n.i18n_t(model, i18n_text.Delete),
    cancel_label: helpers_i18n.i18n_t(model, i18n_text.Cancel),
    on_confirm: client_state.pool_msg(
      pool_messages.MemberMilestoneDeleteSubmitted(id),
    ),
    on_cancel: client_state.pool_msg(pool_messages.MemberMilestoneDialogClosed),
    is_open: is_open,
    is_loading: model.member.pool.member_milestone_dialog_in_flight,
    error: model.member.pool.member_milestone_dialog_error,
    confirm_class: "btn-danger",
  ))
}
