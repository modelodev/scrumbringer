//// Pool feature messages.

import api/cards/contracts as card_contracts
import domain/api_error.{type ApiResult}
import domain/capability.{type Capability}
import domain/card.{type Card}
import domain/metrics.{
  type MyMetrics, type OrgMetricsOverview, type OrgMetricsProjectTasksPayload,
  type OrgMetricsUserOverview,
}
import domain/note/entity as note_entity
import domain/project.{type ProjectMember}
import domain/task.{
  type Task, type TaskDependency, type TaskPosition, type WorkSessionsPayload,
}
import domain/task_type.{type TaskType}
import domain/view_mode
import domain/workflow.{type Rule, type TaskTemplate, type Workflow}
import gleam/option.{type Option}
import scrumbringer_client/api/activity as api_activity

import scrumbringer_client/api/workflows/rule_metrics as api_rule_metrics
import scrumbringer_client/client_state/admin/cards as admin_cards
import scrumbringer_client/client_state/admin/rules as admin_rules
import scrumbringer_client/client_state/admin/task_templates as admin_task_templates
import scrumbringer_client/client_state/admin/workflows as admin_workflows
import scrumbringer_client/components/card_show
import scrumbringer_client/features/cards/move_target.{type MoveTarget}
import scrumbringer_client/pool_prefs
import scrumbringer_client/ui/show_tabs

/// Represents PoolMsg.
pub type Msg {
  MemberPoolMyTasksRectFetched(Int, Int, Int, Int)
  MemberPoolDragToClaimArmed(Bool)
  MemberPoolVisibilityChanged(String)
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
  MemberClearFilters
  MemberPoolViewModeSet(pool_prefs.ViewMode)
  MemberPoolTouchStarted(Int, Int, Int)
  MemberPoolTouchEnded(Int)
  MemberPoolLongPressCheck(Int)
  MemberTaskHoverOpened(Int)
  MemberTaskHoverClosed
  MemberTaskFocused(Int)
  MemberTaskBlurred
  MemberTaskHoverNotesFetched(Int, ApiResult(List(note_entity.Note)))
  MemberListHideClosedToggled
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
  MemberCloseClicked(Int, Int)
  MemberDeleteTaskClicked(Int)
  MemberTaskClaimed(ApiResult(Task))
  MemberTaskReleased(ApiResult(Task))
  MemberTaskClosed(ApiResult(Task))
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
  MemberTaskShowOpened(Int)
  MemberTaskShowClosed
  MemberTaskShowTabClicked(show_tabs.TaskShowTab)
  MemberTaskShowEditStarted
  MemberTaskShowEditCancelled
  MemberTaskShowEditTitleChanged(String)
  MemberTaskShowEditDescriptionChanged(String)
  MemberTaskShowEditPriorityChanged(String)
  MemberTaskShowEditTypeIdChanged(String)
  MemberTaskShowEditCardIdChanged(String)
  MemberTaskShowEditSubmitted
  MemberTaskUpdated(ApiResult(Task))
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
  MemberNotesFetched(ApiResult(List(note_entity.Note)))
  MemberNoteContentChanged(String)
  MemberNoteDialogOpened
  MemberNoteDialogClosed
  MemberNoteSubmitted
  MemberNoteAdded(ApiResult(note_entity.Note))
  MemberNoteDeleteClicked(Int)
  MemberNoteDeleted(Int, ApiResult(Nil))
  MemberNotePinClicked(Int, Bool)
  MemberNotePinned(Int, ApiResult(note_entity.Note))
  MemberActivityMoreClicked
  MemberActivityFetched(ApiResult(api_activity.ActivityPage))
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
  AdminRuleMetricsEngineExpanded(Int)
  AdminRuleMetricsEngineDetailsFetched(
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
  AdminProjectRuleExecutionsFetched(
    ApiResult(api_rule_metrics.ProjectRuleExecutionsResponse),
  )
  AdminRuleMetricsExecPageChanged(Int)
  AdminProjectRuleExecutionsPageChanged(Int)
  CardsFetched(ApiResult(List(Card)))
  OpenCardDialog(admin_cards.CardDialogMode)
  CloseCardDialog
  CardCrudCreated(Card)
  CardCrudUpdated(Card)
  CardCrudDeleted(Int)
  CardsShowEmptyToggled
  CardsShowClosedToggled
  CardsStateFilterChanged(String)
  CardsSearchChanged(String)
  OpenCardShow(Int)
  CloseCardShow
  CardShowMsg(card_show.Msg)
  CardActivateRequested(Int)
  CardActivated(ApiResult(card_contracts.CardActionResponse))
  EnginesProjectFetched(ApiResult(List(Workflow)))
  EnginesSearchChanged(String)
  EnginesStatusFilterChanged(String)
  OpenEngineDialog(admin_workflows.EngineDialogMode)
  CloseEngineDialog
  EngineNameChanged(String)
  EngineDescriptionChanged(String)
  EngineActiveChanged(Bool)
  EngineFormSubmitted(Option(Int))
  EngineSaved(ApiResult(Workflow))
  EngineDeleteConfirmed
  EngineDeleteFinished(Int, ApiResult(Nil))
  EngineRulesClicked(Int)
  RulesFetched(ApiResult(List(Rule)))
  RulesBackClicked
  OpenRuleDialog(admin_rules.RuleDialogMode)
  CloseRuleDialog
  RuleNameChanged(String)
  RuleGoalChanged(String)
  RuleSubjectChanged(String)
  RuleTaskTypeChanged(String)
  RuleEventChanged(String)
  RuleCardScopeChanged(String)
  RuleTemplateSearchChanged(String)
  RuleTemplateChanged(String)
  RuleActiveChanged(Bool)
  RuleFormSubmitted
  RuleSaved(ApiResult(Rule))
  RuleDeleteConfirmed
  RuleDeleteFinished(Int, ApiResult(Nil))
  RuleExpandToggled(Int)
  RuleMetricsFetched(ApiResult(api_rule_metrics.WorkflowMetrics))
  TaskTemplatesProjectFetched(ApiResult(List(TaskTemplate)))
  TaskTemplatesSearchChanged(String)
  OpenTaskTemplateDialog(admin_task_templates.TaskTemplateDialogMode)
  CloseTaskTemplateDialog
  TaskTemplateNameChanged(String)
  TaskTemplateDescriptionChanged(String)
  TaskTemplateTypeChanged(String)
  TaskTemplatePriorityChanged(String)
  TaskTemplateFormSubmitted(Option(Int))
  TaskTemplateSaved(ApiResult(TaskTemplate))
  TaskTemplateDeleteConfirmed
  TaskTemplateDeleteFinished(Int, ApiResult(Nil))
}
