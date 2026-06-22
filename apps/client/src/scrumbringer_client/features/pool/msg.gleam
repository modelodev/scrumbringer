//// Pool feature messages.

import api/cards/contracts as card_contracts
import domain/api_error.{type ApiError, type ApiResult}
import domain/capability.{type Capability}
import domain/card.{type Card}
import domain/metrics.{
  type CardModalMetrics, type MyMetrics, type OrgMetricsOverview,
  type OrgMetricsProjectTasksPayload, type OrgMetricsUserOverview,
  type TaskModalMetrics,
}
import domain/project.{type ProjectMember}
import domain/task.{
  type Task, type TaskDependency, type TaskNote, type TaskPosition,
  type WorkSessionsPayload,
}
import domain/task_type.{type TaskType}
import domain/view_mode
import domain/workflow.{
  type Rule, type RuleTemplate, type TaskTemplate, type Workflow,
}

import scrumbringer_client/api/workflows/rule_metrics as api_rule_metrics
import scrumbringer_client/client_state/admin/cards as admin_cards
import scrumbringer_client/client_state/admin/rules as admin_rules
import scrumbringer_client/client_state/admin/task_templates as admin_task_templates
import scrumbringer_client/client_state/admin/workflows as admin_workflows
import scrumbringer_client/features/cards/move_target.{type MoveTarget}
import scrumbringer_client/pool_prefs
import scrumbringer_client/ui/task_tabs

/// Represents PoolMsg.
pub type Msg {
  MemberPoolMyTasksRectFetched(Int, Int, Int, Int)
  MemberPoolDragToClaimArmed(Bool)
  MemberPoolStatusChanged(String)
  MemberPoolTypeChanged(String)
  MemberPoolCapabilityChanged(String)
  MemberPoolCapabilityScopeChanged(String)
  MemberPoolSearchChanged(String)
  MemberPoolSearchDebounced(String)
  MemberPlanScopeKindChanged(String)
  MemberPlanModeChanged(String)
  MemberPlanCapabilityModeChanged(String)
  MemberPlanScopeDepthChanged(String)
  MemberPlanScopeCardChanged(String)
  MemberPlanScopeCardSearchChanged(String)
  MemberPlanClosedToggled(Bool)
  MemberPlanStatusChanged(String)
  MemberPlanSortChanged(String)
  MemberPlanCardToggled(Int)
  MemberPlanMoveRequested(Int)
  MemberPlanMoveCancelled
  MemberPlanMoveDestinationSearchChanged(String)
  MemberPlanMoveDestinationSelected(MoveTarget)
  MemberPlanMoveDragStarted(Int)
  MemberPlanMoveDragEntered(MoveTarget)
  MemberPlanMoveDroppedOn(MoveTarget)
  MemberPlanMoveDragEnded
  MemberPlanCardMoved(ApiResult(card_contracts.CardActionResponse))
  MemberPoolFiltersToggled
  MemberClearFilters
  MemberPoolViewModeSet(pool_prefs.ViewMode)
  MemberPoolTouchStarted(Int, Int, Int)
  MemberPoolTouchEnded(Int)
  MemberPoolLongPressCheck(Int)
  MemberTaskHoverOpened(Int)
  MemberTaskHoverClosed
  MemberTaskFocused(Int)
  MemberTaskBlurred
  MemberTaskHoverNotesFetched(Int, ApiResult(List(TaskNote)))
  MemberListHideDoneToggled
  MemberListCardToggled(Int)
  ViewModeChanged(view_mode.ViewMode)
  GlobalKeyDown(pool_prefs.KeyEvent)
  MemberProjectTasksFetched(Int, ApiResult(List(Task)))
  MemberPeopleRosterFetched(ApiResult(List(ProjectMember)))
  MemberPeopleRowToggled(Int)
  MemberPeopleSearchChanged(String)
  MemberPeopleFilterChanged(String)
  MemberPeopleSortChanged(String)
  MemberTaskTypesFetched(Int, ApiResult(List(TaskType)))
  MemberCanvasRectFetched(Int, Int)
  MemberDragStarted(Int, Int, Int)
  MemberDragOffsetResolved(Int, Int, Int)
  MemberDragMoved(Int, Int)
  MemberDragEnded
  MemberCreateDialogOpened
  MemberCreateDialogOpenedWithCard(Int)
  MemberCreateDialogClosed
  MemberCreateTitleChanged(String)
  MemberCreateDescriptionChanged(String)
  MemberCreatePriorityChanged(String)
  MemberCreateTypeIdChanged(String)
  MemberCreateTypeOptionsRetryClicked
  MemberCreateSubmitted
  MemberTaskCreated(ApiResult(Task))
  MemberTaskCreatedFeedback(Int)
  MemberHighlightExpired(Int)
  MemberClaimClicked(Int, Int)
  MemberReleaseClicked(Int, Int)
  MemberCompleteClicked(Int, Int)
  MemberDeleteTaskClicked(Int)
  MemberTaskClaimed(ApiResult(Task))
  MemberTaskReleased(ApiResult(Task))
  MemberTaskDone(ApiResult(Task))
  MemberTaskDeleted(Int, ApiResult(Nil))
  MemberNowWorkingStartClicked(Int)
  MemberNowWorkingPauseClicked
  MemberWorkSessionsFetched(ApiResult(WorkSessionsPayload))
  MemberWorkSessionStarted(ApiResult(WorkSessionsPayload))
  MemberWorkSessionPaused(ApiResult(WorkSessionsPayload))
  MemberWorkSessionHeartbeated(ApiResult(WorkSessionsPayload))
  MemberMetricsFetched(ApiResult(MyMetrics))
  NowWorkingTicked
  MemberMyCapabilityIdsFetched(ApiResult(List(Int)))
  MemberProjectCapabilitiesFetched(ApiResult(List(Capability)))
  MemberToggleCapability(Int)
  MemberSaveCapabilitiesClicked
  MemberMyCapabilityIdsSaved(ApiResult(List(Int)))
  MemberProjectCardsFetched(Int, ApiResult(List(Card)))
  MemberPositionsFetched(ApiResult(List(TaskPosition)))
  MemberPositionEditOpened(Int)
  MemberPositionEditClosed
  MemberPositionEditXChanged(String)
  MemberPositionEditYChanged(String)
  MemberPositionEditSubmitted
  MemberPositionSaved(ApiResult(TaskPosition))
  MemberTaskDetailsOpened(Int)
  MemberTaskDetailsClosed
  MemberTaskDetailTabClicked(task_tabs.Tab)
  MemberTaskDetailEditStarted
  MemberTaskDetailEditCancelled
  MemberTaskDetailEditTitleChanged(String)
  MemberTaskDetailEditDescriptionChanged(String)
  MemberTaskDetailEditPriorityChanged(String)
  MemberTaskDetailEditTypeIdChanged(String)
  MemberTaskDetailEditCardIdChanged(String)
  MemberTaskDetailEditSubmitted
  MemberTaskUpdated(ApiResult(Task))
  MemberTaskMetricsFetched(ApiResult(TaskModalMetrics))
  MemberDependenciesFetched(ApiResult(List(TaskDependency)))
  MemberDependencyDialogOpened
  MemberDependencyDialogClosed
  MemberDependencySearchChanged(String)
  MemberDependencyCandidatesFetched(ApiResult(List(Task)))
  MemberDependencySelected(Int)
  MemberDependencyAddSubmitted
  MemberDependencyAdded(ApiResult(TaskDependency))
  MemberDependencyRemoveClicked(Int)
  MemberDependencyRemoved(Int, ApiResult(Nil))
  MemberNotesFetched(ApiResult(List(TaskNote)))
  MemberNoteContentChanged(String)
  MemberNoteDialogOpened
  MemberNoteDialogClosed
  MemberNoteSubmitted
  MemberNoteAdded(ApiResult(TaskNote))
  MemberNoteDeleteClicked(Int)
  MemberNoteDeleted(Int, ApiResult(Nil))
  AdminMetricsOverviewFetched(ApiResult(OrgMetricsOverview))
  AdminMetricsProjectTasksFetched(ApiResult(OrgMetricsProjectTasksPayload))
  AdminMetricsUsersFetched(ApiResult(List(OrgMetricsUserOverview)))
  AdminRuleMetricsFetched(
    ApiResult(List(api_rule_metrics.OrgWorkflowMetricsSummary)),
  )
  AdminRuleMetricsFromChanged(String)
  AdminRuleMetricsToChanged(String)
  AdminRuleMetricsFromChangedAndRefresh(String)
  AdminRuleMetricsToChangedAndRefresh(String)
  AdminRuleMetricsRefreshClicked
  AdminRuleMetricsQuickRangeClicked(String, String)
  AdminRuleMetricsWorkflowExpanded(Int)
  AdminRuleMetricsWorkflowDetailsFetched(
    ApiResult(api_rule_metrics.WorkflowMetrics),
  )
  AdminRuleMetricsDrilldownClicked(Int)
  AdminRuleMetricsDrilldownClosed
  AdminRuleMetricsRuleDetailsFetched(
    ApiResult(api_rule_metrics.RuleMetricsDetailed),
  )
  AdminRuleMetricsExecutionsFetched(
    ApiResult(api_rule_metrics.RuleExecutionsResponse),
  )
  AdminRuleMetricsExecPageChanged(Int)
  CardsFetched(ApiResult(List(Card)))
  OpenCardDialog(admin_cards.CardDialogMode)
  CloseCardDialog
  CardCrudCreated(Card)
  CardCrudUpdated(Card)
  CardCrudDeleted(Int)
  CardsShowEmptyToggled
  CardsShowDoneToggled
  CardsStateFilterChanged(String)
  CardsSearchChanged(String)
  OpenCardDetail(Int)
  CloseCardDetail
  CardMetricsFetched(ApiResult(CardModalMetrics))
  CardActivateRequested(Int)
  CardActivated(ApiResult(card_contracts.CardActionResponse))
  WorkflowsProjectFetched(ApiResult(List(Workflow)))
  OpenWorkflowDialog(admin_workflows.WorkflowDialogMode)
  CloseWorkflowDialog
  WorkflowCrudCreated(Workflow)
  WorkflowCrudUpdated(Workflow)
  WorkflowCrudDeleted(Int)
  WorkflowRulesClicked(Int)
  RulesFetched(ApiResult(List(Rule)))
  RulesBackClicked
  OpenRuleDialog(admin_rules.RuleDialogMode)
  CloseRuleDialog
  RuleCrudCreated(Rule)
  RuleCrudUpdated(Rule)
  RuleCrudDeleted(Int)
  RuleExpandToggled(Int)
  AttachTemplateModalOpened(Int)
  AttachTemplateModalClosed
  AttachTemplateSelected(Int)
  AttachTemplateSubmitted
  AttachTemplateSucceeded(Int, List(RuleTemplate))
  AttachTemplateFailed(ApiError)
  TemplateDetachClicked(Int, Int)
  TemplateDetachSucceeded(Int, Int)
  TemplateDetachFailed(Int, Int, ApiError)
  RuleMetricsFetched(ApiResult(api_rule_metrics.WorkflowMetrics))
  TaskTemplatesProjectFetched(ApiResult(List(TaskTemplate)))
  OpenTaskTemplateDialog(admin_task_templates.TaskTemplateDialogMode)
  CloseTaskTemplateDialog
  TaskTemplateCrudCreated(TaskTemplate)
  TaskTemplateCrudUpdated(TaskTemplate)
  TaskTemplateCrudDeleted(Int)
}
