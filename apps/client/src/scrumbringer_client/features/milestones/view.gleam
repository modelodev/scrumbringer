import domain/card as card_domain
import domain/milestone.{
  type MilestoneProgress, type MilestoneState, Active, Completed, Ready,
}
import domain/org_role
import domain/remote.{Failed, Loaded, Loading, NotAsked}
import domain/task as task_domain
import domain/task_status
import gleam/dict
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option
import lustre/attribute
import lustre/element.{type Element, none}
import lustre/element/html.{
  button, div, form, h3, h4, input, label, p, span, text, textarea,
}
import lustre/element/keyed
import lustre/event

import scrumbringer_client/client_state
import scrumbringer_client/client_state/member/milestone_details_tab
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/milestones/ids as milestone_ids
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/helpers/i18n as helpers_i18n
import scrumbringer_client/helpers/selection as helpers_selection
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/permissions
import scrumbringer_client/ui/badge
import scrumbringer_client/ui/confirm_dialog
import scrumbringer_client/ui/dialog
import scrumbringer_client/ui/expand_toggle
import scrumbringer_client/ui/form_field
import scrumbringer_client/ui/tabs

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
    view_details_dialog(model),
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

  case items {
    [] ->
      div([attribute.class("milestones-state milestones-empty")], [
        text(helpers_i18n.i18n_t(model, i18n_text.MilestonesEmpty)),
      ])

    _ -> {
      let ready_items = by_state(filtered, Ready)
      let active_items = by_state(filtered, Active)
      let completed_items = by_state(filtered, Completed)

      let list_content = case filtered {
        [] ->
          div([attribute.class("milestones-state milestones-empty")], [
            text(helpers_i18n.i18n_t(model, i18n_text.MilestonesNoResults)),
          ])
        _ ->
          div([], [
            view_section_if_has_items(
              model,
              i18n_text.MilestonesReady,
              ready_items,
            ),
            view_section_if_has_items(
              model,
              i18n_text.MilestonesActive,
              active_items,
            ),
            case model.member.pool.member_milestones_show_completed {
              True ->
                view_section_if_has_items(
                  model,
                  i18n_text.MilestonesCompleted,
                  completed_items,
                )
              False -> none()
            },
          ])
      }

      div(
        [
          attribute.class("milestones-view"),
          attribute.attribute("data-testid", "milestones-view"),
        ],
        [
          div([attribute.class("milestones-toolbar")], [
            h3([attribute.class("milestones-title")], [
              text(helpers_i18n.i18n_t(model, i18n_text.Milestones)),
            ]),
            view_filters(model),
          ]),
          list_content,
        ],
      )
    }
  }
}

fn view_filters(model: client_state.Model) -> Element(client_state.Msg) {
  div(
    [
      attribute.class("milestones-filters"),
      attribute.attribute("data-testid", "milestones-filters"),
    ],
    [
      label([attribute.class("milestones-filter-chip")], [
        input([
          attribute.type_("checkbox"),
          attribute.class("milestones-filter-checkbox"),
          attribute.attribute("data-testid", "milestones-filter-completed"),
          attribute.checked(model.member.pool.member_milestones_show_completed),
          event.on_check(fn(_) {
            client_state.pool_msg(
              pool_messages.MemberMilestonesShowCompletedToggled,
            )
          }),
        ]),
        text(
          " " <> helpers_i18n.i18n_t(model, i18n_text.ShowCompletedMilestones),
        ),
      ]),
      label([attribute.class("milestones-filter-chip")], [
        input([
          attribute.type_("checkbox"),
          attribute.class("milestones-filter-checkbox"),
          attribute.attribute("data-testid", "milestones-filter-empty"),
          attribute.checked(model.member.pool.member_milestones_show_empty),
          event.on_check(fn(_) {
            client_state.pool_msg(
              pool_messages.MemberMilestonesShowEmptyToggled,
            )
          }),
        ]),
        text(" " <> helpers_i18n.i18n_t(model, i18n_text.ShowEmptyMilestones)),
      ]),
    ],
  )
}

fn apply_filters(
  model: client_state.Model,
  items: List(MilestoneProgress),
) -> List(MilestoneProgress) {
  items
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

fn by_state(
  items: List(MilestoneProgress),
  state: MilestoneState,
) -> List(MilestoneProgress) {
  list.filter(items, fn(progress) { progress.milestone.state == state })
}

fn view_section(
  model: client_state.Model,
  title: i18n_text.Text,
  items: List(MilestoneProgress),
) -> Element(client_state.Msg) {
  div([attribute.class("milestones-section")], [
    h4([attribute.class("milestones-section-title")], [
      text(helpers_i18n.i18n_t(model, title)),
    ]),
    case items {
      [] -> p([attribute.class("milestones-section-empty")], [text("-")])

      _ ->
        keyed.div(
          [attribute.class("milestones-items")],
          list.map(items, fn(item) {
            #(int.to_string(item.milestone.id), view_item(model, item))
          }),
        )
    },
  ])
}

fn view_section_if_has_items(
  model: client_state.Model,
  title: i18n_text.Text,
  items: List(MilestoneProgress),
) -> Element(client_state.Msg) {
  case items {
    [] -> none()
    _ -> view_section(model, title, items)
  }
}

fn view_item(
  model: client_state.Model,
  progress: MilestoneProgress,
) -> Element(client_state.Msg) {
  let milestone_id = progress.milestone.id
  let expanded = is_expanded(model, milestone_id)
  let can_manage = can_manage_milestones(model)
  let blocked_by_active = has_other_active_milestone(model, milestone_id)
  let in_flight =
    model.member.pool.member_milestone_activate_in_flight_id
    == option.Some(milestone_id)

  let state_badge =
    badge.quick(
      milestone_state_label(model, progress.milestone.state),
      milestone_state_variant(progress.milestone.state),
    )

  let progress_percentage = milestone_progress_percentage(progress)
  let region_id = milestone_ids.region_id(milestone_id)
  let header_id = milestone_ids.details_button_id(milestone_id)

  let activate_button = case
    can_manage,
    progress.milestone.state,
    blocked_by_active
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
          attribute.id(milestone_ids.activate_button_id(milestone_id)),
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

  let details_button =
    button(
      [
        attribute.class("btn btn-sm btn-link milestone-details-link"),
        attribute.id(header_id),
        attribute.attribute("type", "button"),
        attribute.attribute(
          "data-testid",
          "milestone-details-button:" <> int.to_string(milestone_id),
        ),
        event.on_click(
          client_state.pool_msg(pool_messages.MemberMilestoneDetailsClicked(
            milestone_id,
          )),
        ),
      ],
      [text(helpers_i18n.i18n_t(model, i18n_text.MilestoneOpenDetails))],
    )

  let edit_button = case can_manage {
    True ->
      button(
        [
          attribute.class("btn btn-sm btn-secondary"),
          attribute.attribute("type", "button"),
          attribute.attribute(
            "data-testid",
            "milestone-edit-button:" <> int.to_string(milestone_id),
          ),
          attribute.id(milestone_ids.edit_button_id(milestone_id)),
          event.on_click(
            client_state.pool_msg(pool_messages.MemberMilestoneEditClicked(
              milestone_id,
            )),
          ),
        ],
        [text(helpers_i18n.i18n_t(model, i18n_text.EditMilestone))],
      )
    False -> none()
  }

  let delete_button = case can_manage, progress.milestone.state {
    True, Ready ->
      button(
        [
          attribute.class("btn btn-sm btn-danger"),
          attribute.attribute("type", "button"),
          attribute.attribute(
            "data-testid",
            "milestone-delete-button:" <> int.to_string(milestone_id),
          ),
          attribute.id(milestone_ids.delete_button_id(milestone_id)),
          event.on_click(
            client_state.pool_msg(pool_messages.MemberMilestoneDeleteClicked(
              milestone_id,
            )),
          ),
        ],
        [text(helpers_i18n.i18n_t(model, i18n_text.DeleteMilestone))],
      )
    _, _ -> none()
  }

  let toggle_label = case expanded {
    True ->
      helpers_i18n.i18n_t(
        model,
        i18n_text.CollapseMilestone(progress.milestone.name),
      )
    False ->
      helpers_i18n.i18n_t(
        model,
        i18n_text.ExpandMilestone(progress.milestone.name),
      )
  }

  let row_attrs =
    [
      attribute.class("milestone-item"),
      attribute.attribute(
        "data-testid",
        "milestone-row:" <> int.to_string(milestone_id),
      ),
    ]
    |> list.append(milestone_drop_target_attrs(model, milestone_id))

  div(row_attrs, [
    div([attribute.class("milestone-item-header")], [
      button(
        [
          attribute.class("milestone-row-toggle"),
          attribute.attribute("type", "button"),
          attribute.attribute(
            "data-testid",
            "milestone-toggle:" <> int.to_string(milestone_id),
          ),
          attribute.id(milestone_ids.toggle_id(milestone_id)),
          attribute.attribute("aria-label", toggle_label),
          attribute.attribute("aria-controls", region_id),
          attribute.attribute("aria-expanded", case expanded {
            True -> "true"
            False -> "false"
          }),
          event.on_click(
            client_state.pool_msg(pool_messages.MemberMilestoneRowToggled(
              milestone_id,
            )),
          ),
        ],
        [
          expand_toggle.view(expanded),
          span([attribute.class("milestone-row-toggle-label")], [
            text(progress.milestone.name),
          ]),
        ],
      ),
      div([attribute.class("milestone-item-meta")], [
        state_badge,
        span([attribute.class("milestone-progress-percent")], [
          text(int.to_string(progress_percentage) <> "%"),
        ]),
        div([attribute.class("milestone-progress-bar")], [
          div(
            [
              attribute.class("milestone-progress-fill"),
              attribute.attribute(
                "style",
                "width: " <> int.to_string(progress_percentage) <> "%",
              ),
            ],
            [],
          ),
        ]),
        div(
          [
            attribute.class("milestone-item-stats"),
            attribute.attribute(
              "data-testid",
              "milestone-progress:" <> int.to_string(milestone_id),
            ),
          ],
          [
            span([attribute.class("milestone-stat-pill")], [
              text(
                "Cards "
                <> int.to_string(progress.cards_completed)
                <> "/"
                <> int.to_string(progress.cards_total),
              ),
            ]),
            span([attribute.class("milestone-stat-pill")], [
              text(
                "Tasks "
                <> int.to_string(progress.tasks_completed)
                <> "/"
                <> int.to_string(progress.tasks_total),
              ),
            ]),
          ],
        ),
      ]),
    ]),
    div(
      [
        attribute.id(region_id),
        attribute.attribute("aria-labelledby", header_id),
        attribute.attribute("aria-hidden", case expanded {
          True -> "false"
          False -> "true"
        }),
        attribute.class(
          "milestone-item-body"
          <> case expanded {
            True -> ""
            False -> " hidden"
          },
        ),
      ],
      [
        view_cards_section(model, milestone_id),
        view_loose_tasks_section(model, milestone_id),
        case progress.milestone.description {
          option.Some(description) if description != "" ->
            p([attribute.class("milestone-item-description")], [
              text(description),
            ])
          _ -> none()
        },
        div(
          [
            attribute.class("milestone-item-actions milestone-item-actions-row"),
          ],
          [
            details_button,
            activate_button,
            edit_button,
            view_row_more_actions(
              model,
              can_manage,
              progress.milestone.state,
              delete_button,
            ),
          ],
        ),
      ],
    ),
  ])
}

fn view_row_more_actions(
  model: client_state.Model,
  can_manage: Bool,
  state: MilestoneState,
  delete_button: Element(client_state.Msg),
) -> Element(client_state.Msg) {
  case can_manage, state {
    True, Ready ->
      div([attribute.class("milestone-more-actions")], [
        button(
          [
            attribute.class("btn btn-sm btn-ghost"),
            attribute.attribute("type", "button"),
            attribute.attribute(
              "aria-label",
              helpers_i18n.i18n_t(model, i18n_text.MilestoneMoreActions),
            ),
          ],
          [text("...")],
        ),
        div([attribute.class("milestone-more-actions-menu")], [delete_button]),
      ])
    _, _ -> none()
  }
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
      div([attribute.class("milestone-subsection")], [
        p([attribute.class("milestone-subsection-title")], [text("Cards")]),
        keyed.div(
          [attribute.class("milestone-cards-list")],
          list.map(cards, fn(card) {
            let card_domain.Card(
              id: card_id,
              title: title,
              task_count: task_count,
              completed_count: completed_count,
              ..,
            ) = card

            #(int.to_string(card_id), {
              let attrs = [
                attribute.class("milestone-card-row"),
                attribute.attribute(
                  "data-testid",
                  "milestone-card-row:"
                    <> int.to_string(milestone_id)
                    <> ":"
                    <> int.to_string(card_id),
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

              div(attrs, [
                p([attribute.class("milestone-card-title")], [text(title)]),
                div([attribute.class("milestone-card-actions")], [
                  span([attribute.class("milestone-card-progress")], [
                    text(
                      "Tasks "
                      <> int.to_string(completed_count)
                      <> "/"
                      <> int.to_string(task_count),
                    ),
                  ]),
                  case can_move {
                    True ->
                      view_move_card_actions(
                        model,
                        card_id,
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
      div([attribute.class("milestone-subsection")], [
        p([attribute.class("milestone-subsection-title")], [text("Tasks")]),
        keyed.div(
          [attribute.class("milestone-cards-list")],
          list.map(tasks, fn(task) {
            let task_domain.Task(id: task_id, title: title, status: status, ..) =
              task

            #(int.to_string(task_id), {
              let attrs = [
                attribute.class("milestone-card-row"),
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
                    text(task_status_to_short(status)),
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
  case destinations {
    [] -> none()
    _ ->
      div([attribute.class("milestone-context-menu")], [
        button(
          [
            attribute.class("btn btn-xs btn-ghost"),
            attribute.attribute("type", "button"),
            attribute.attribute(
              "data-testid",
              "milestone-move-menu-card:"
                <> int.to_string(from_milestone_id)
                <> ":"
                <> int.to_string(card_id),
            ),
          ],
          [text(helpers_i18n.i18n_t(model, i18n_text.MilestoneMoveTo))],
        ),
        div(
          [attribute.class("milestone-move-actions")],
          list.map(destinations, fn(dest) {
            button(
              [
                attribute.class("btn btn-xs btn-ghost"),
                attribute.attribute(
                  "data-testid",
                  "milestone-move-card:"
                    <> int.to_string(from_milestone_id)
                    <> ":"
                    <> int.to_string(card_id)
                    <> ":"
                    <> int.to_string(dest.id),
                ),
                attribute.attribute("type", "button"),
                event.on_click(
                  client_state.pool_msg(
                    pool_messages.MemberMilestoneCardMoveClicked(
                      card_id,
                      from_milestone_id,
                      dest.id,
                    ),
                  ),
                ),
              ],
              [text(dest.name)],
            )
          }),
        ),
      ])
  }
}

fn view_move_task_actions(
  model: client_state.Model,
  task_id: Int,
  from_milestone_id: Int,
  destinations: List(milestone.Milestone),
) -> Element(client_state.Msg) {
  case destinations {
    [] -> none()
    _ ->
      div([attribute.class("milestone-context-menu")], [
        button(
          [
            attribute.class("btn btn-xs btn-ghost"),
            attribute.attribute("type", "button"),
            attribute.attribute(
              "data-testid",
              "milestone-move-menu-task:"
                <> int.to_string(from_milestone_id)
                <> ":"
                <> int.to_string(task_id),
            ),
          ],
          [text(helpers_i18n.i18n_t(model, i18n_text.MilestoneMoveTo))],
        ),
        div(
          [attribute.class("milestone-move-actions")],
          list.map(destinations, fn(dest) {
            button(
              [
                attribute.class("btn btn-xs btn-ghost"),
                attribute.attribute(
                  "data-testid",
                  "milestone-move-task:"
                    <> int.to_string(from_milestone_id)
                    <> ":"
                    <> int.to_string(task_id)
                    <> ":"
                    <> int.to_string(dest.id),
                ),
                attribute.attribute("type", "button"),
                event.on_click(
                  client_state.pool_msg(
                    pool_messages.MemberMilestoneTaskMoveClicked(
                      task_id,
                      from_milestone_id,
                      dest.id,
                    ),
                  ),
                ),
              ],
              [text(dest.name)],
            )
          }),
        ),
      ])
  }
}

fn task_status_to_short(status: task_status.TaskStatus) -> String {
  case status {
    task_status.Available -> "available"
    task_status.Claimed(_) -> "claimed"
    task_status.Completed -> "completed"
  }
}

fn milestone_drop_target_attrs(
  model: client_state.Model,
  milestone_id: Int,
) -> List(attribute.Attribute(client_state.Msg)) {
  let can_receive_drop =
    can_manage_milestones(model) && is_ready_milestone(model, milestone_id)

  case can_receive_drop {
    True -> [
      attribute.attribute("data-drop-target", int.to_string(milestone_id)),
      event.advanced("dragover", {
        decode.success(event.handler(
          client_state.NoOp,
          prevent_default: True,
          stop_propagation: False,
        ))
      }),
      event.advanced("drop", {
        decode.success(event.handler(
          client_state.pool_msg(pool_messages.MemberMilestoneDroppedOn(
            milestone_id,
          )),
          prevent_default: True,
          stop_propagation: False,
        ))
      }),
    ]
    False -> []
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

fn is_expanded(model: client_state.Model, milestone_id: Int) -> Bool {
  dict.get(model.member.pool.member_milestones_expanded, milestone_id)
  |> option.from_result
  |> option.unwrap(False)
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

fn view_details_dialog(model: client_state.Model) -> Element(client_state.Msg) {
  let maybe_progress = case model.member.pool.member_milestone_dialog {
    member_pool.MilestoneDialogView(id: id) ->
      find_milestone_progress(model, id)
    _ -> option.None
  }

  case maybe_progress {
    option.Some(progress) -> {
      let milestone_id = progress.milestone.id
      let can_manage = can_manage_milestones(model)
      let blocked_by_active = has_other_active_milestone(model, milestone_id)
      let in_flight =
        model.member.pool.member_milestone_activate_in_flight_id
        == option.Some(milestone_id)

      let state_badge =
        badge.quick(
          milestone_state_label(model, progress.milestone.state),
          milestone_state_variant(progress.milestone.state),
        )

      let activate_button = case
        can_manage,
        progress.milestone.state,
        blocked_by_active
      {
        True, Ready, False ->
          button(
            [
              attribute.class("btn btn-danger"),
              attribute.attribute("type", "button"),
              attribute.attribute(
                "data-testid",
                "milestone-details-activate:" <> int.to_string(milestone_id),
              ),
              attribute.disabled(in_flight),
              event.on_click(
                client_state.pool_msg(
                  pool_messages.MemberMilestoneActivatePromptClicked(
                    milestone_id,
                  ),
                ),
              ),
            ],
            [
              text(case in_flight {
                True ->
                  helpers_i18n.i18n_t(model, i18n_text.ActivatingMilestone)
                False -> helpers_i18n.i18n_t(model, i18n_text.ActivateMilestone)
              }),
            ],
          )
        _, _, _ -> none()
      }

      let create_actions = case can_manage {
        True ->
          div(
            [
              attribute.class(
                "milestone-item-actions milestone-item-actions-row",
              ),
            ],
            [
              button(
                [
                  attribute.class("btn btn-sm btn-secondary"),
                  attribute.attribute("type", "button"),
                  attribute.attribute(
                    "data-testid",
                    "milestone-details-new-card:" <> int.to_string(milestone_id),
                  ),
                  event.on_click(
                    client_state.pool_msg(
                      pool_messages.MemberMilestoneCreateCardClicked(
                        milestone_id,
                      ),
                    ),
                  ),
                ],
                [text("+ " <> helpers_i18n.i18n_t(model, i18n_text.NewCard))],
              ),
              button(
                [
                  attribute.class("btn btn-sm btn-secondary"),
                  attribute.attribute("type", "button"),
                  attribute.attribute(
                    "data-testid",
                    "milestone-details-new-task:" <> int.to_string(milestone_id),
                  ),
                  event.on_click(
                    client_state.pool_msg(
                      pool_messages.MemberMilestoneCreateTaskClicked(
                        milestone_id,
                      ),
                    ),
                  ),
                ],
                [text("+ " <> helpers_i18n.i18n_t(model, i18n_text.NewTask))],
              ),
            ],
          )
        False -> none()
      }

      let details_tabs =
        tabs.config(
          tabs: [
            tabs.TabItem(
              id: milestone_details_tab.MilestoneOverviewTab,
              label: helpers_i18n.i18n_t(model, i18n_text.MilestoneTabOverview),
              count: option.None,
              has_indicator: False,
            ),
            tabs.TabItem(
              id: milestone_details_tab.MilestoneContentTab,
              label: helpers_i18n.i18n_t(model, i18n_text.MilestoneTabContent),
              count: option.Some(progress.cards_total + progress.tasks_total),
              has_indicator: False,
            ),
          ],
          active: model.member.pool.member_milestone_details_tab,
          container_class: "modal-tabs milestone-details-tabs",
          tab_class: "modal-tab",
          on_click: fn(tab) {
            client_state.pool_msg(
              pool_messages.MemberMilestoneDetailsTabSelected(tab),
            )
          },
        )

      let tab_content = case model.member.pool.member_milestone_details_tab {
        milestone_details_tab.MilestoneOverviewTab ->
          div([attribute.class("milestone-details-overview")], [
            case progress.milestone.description {
              option.Some(description) if description != "" ->
                p([], [text(description)])
              _ -> none()
            },
            p([attribute.class("milestone-item-description")], [
              text(
                "Cards: "
                <> int.to_string(progress.cards_total)
                <> " · Tasks: "
                <> int.to_string(progress.tasks_total),
              ),
            ]),
          ])

        milestone_details_tab.MilestoneContentTab ->
          div([attribute.class("milestone-details-content")], [
            create_actions,
            view_cards_section(model, milestone_id),
            view_loose_tasks_section(model, milestone_id),
          ])
      }

      dialog.view(
        dialog.DialogConfig(
          title: helpers_i18n.i18n_t(model, i18n_text.MilestoneDetails),
          icon: option.None,
          size: dialog.DialogLg,
          on_close: client_state.pool_msg(
            pool_messages.MemberMilestoneDialogClosed,
          ),
        ),
        True,
        model.member.pool.member_milestone_dialog_error,
        [
          div([attribute.attribute("data-testid", "milestone-details-dialog")], [
            h4([], [text(progress.milestone.name)]),
            div([attribute.class("milestone-item-meta")], [
              state_badge,
              div([attribute.class("milestone-progress-bar")], [
                div(
                  [
                    attribute.class("milestone-progress-fill"),
                    attribute.attribute(
                      "style",
                      "width: "
                        <> int.to_string(milestone_progress_percentage(progress))
                        <> "%",
                    ),
                  ],
                  [],
                ),
              ]),
              div(
                [
                  attribute.class("milestone-item-stats"),
                  attribute.attribute(
                    "data-testid",
                    "milestone-details-progress:" <> int.to_string(milestone_id),
                  ),
                ],
                [
                  span([attribute.class("milestone-stat-pill")], [
                    text(
                      "Cards "
                      <> int.to_string(progress.cards_completed)
                      <> "/"
                      <> int.to_string(progress.cards_total),
                    ),
                  ]),
                  span([attribute.class("milestone-stat-pill")], [
                    text(
                      "Tasks "
                      <> int.to_string(progress.tasks_completed)
                      <> "/"
                      <> int.to_string(progress.tasks_total),
                    ),
                  ]),
                ],
              ),
            ]),
            activate_button,
            tabs.view(details_tabs),
            tab_content,
          ]),
        ],
        [
          dialog.cancel_button(
            model,
            client_state.pool_msg(pool_messages.MemberMilestoneDialogClosed),
          ),
        ],
      )
    }
    option.None -> none()
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
