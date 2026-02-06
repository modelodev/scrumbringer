//// Pool feature messages.

import domain/api_error.{type ApiError, type ApiResult}
import domain/capability.{type Capability}
import domain/card.{type Card}
import domain/metrics.{
  type MyMetrics, type OrgMetricsOverview, type OrgMetricsProjectTasksPayload,
  type OrgMetricsUserOverview,
}
import domain/milestone.{type Milestone, type MilestoneProgress}
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

import scrumbringer_client/api/workflows as api_workflows
import scrumbringer_client/client_state/types as state_types
import scrumbringer_client/pool_prefs
import scrumbringer_client/ui/task_tabs

/// Represents PoolMsg.
pub type Msg {
  MemberPoolMyTasksRectFetched(Int, Int, Int, Int)
  MemberPoolDragToClaimArmed(Bool)
  MemberPoolStatusChanged(String)
  MemberPoolTypeChanged(String)
  MemberPoolCapabilityChanged(String)
  MemberPoolSearchChanged(String)
  MemberPoolSearchDebounced(String)
  MemberToggleMyCapabilitiesQuick
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
  MemberListHideCompletedToggled
  MemberListCardToggled(Int)
  ViewModeChanged(view_mode.ViewMode)
  GlobalKeyDown(pool_prefs.KeyEvent)
  MemberProjectTasksFetched(Int, ApiResult(List(Task)))
  MemberPeopleRosterFetched(ApiResult(List(ProjectMember)))
  MemberPeopleRowToggled(Int)
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
  MemberCreateCardIdChanged(String)
  MemberCreateSubmitted
  MemberTaskCreated(ApiResult(Task))
  MemberTaskCreatedFeedback(Int)
  MemberHighlightExpired(Int)
  MemberClaimClicked(Int, Int)
  MemberReleaseClicked(Int, Int)
  MemberCompleteClicked(Int, Int)
  MemberTaskClaimed(ApiResult(Task))
  MemberTaskReleased(ApiResult(Task))
  MemberTaskCompleted(ApiResult(Task))
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
  MemberProjectMilestonesFetched(Int, ApiResult(List(MilestoneProgress)))
  MemberMilestonesShowCompletedToggled
  MemberMilestonesShowEmptyToggled
  MemberMilestoneRowToggled(Int)
  MemberMilestoneDetailsClicked(Int)
  MemberMilestoneActivatePromptClicked(Int)
  MemberMilestoneActivateClicked(Int)
  MemberMilestoneActivated(Int, ApiResult(Nil))
  MemberMilestoneEditClicked(Int)
  MemberMilestoneDeleteClicked(Int)
  MemberMilestoneDialogClosed
  MemberMilestoneNameChanged(String)
  MemberMilestoneDescriptionChanged(String)
  MemberMilestoneEditSubmitted(Int)
  MemberMilestoneDeleteSubmitted(Int)
  MemberMilestoneUpdated(ApiResult(Milestone))
  MemberMilestoneDeleted(Int, ApiResult(Nil))
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
  MemberBlockedClaimCancelled
  MemberBlockedClaimConfirmed
  MemberNotesFetched(ApiResult(List(TaskNote)))
  MemberNoteContentChanged(String)
  MemberNoteDialogOpened
  MemberNoteDialogClosed
  MemberNoteSubmitted
  MemberNoteAdded(ApiResult(TaskNote))
  AdminMetricsOverviewFetched(ApiResult(OrgMetricsOverview))
  AdminMetricsProjectTasksFetched(ApiResult(OrgMetricsProjectTasksPayload))
  AdminMetricsUsersFetched(ApiResult(List(OrgMetricsUserOverview)))
  AdminRuleMetricsFetched(
    ApiResult(List(api_workflows.OrgWorkflowMetricsSummary)),
  )
  AdminRuleMetricsFromChanged(String)
  AdminRuleMetricsToChanged(String)
  AdminRuleMetricsFromChangedAndRefresh(String)
  AdminRuleMetricsToChangedAndRefresh(String)
  AdminRuleMetricsRefreshClicked
  AdminRuleMetricsQuickRangeClicked(String, String)
  AdminRuleMetricsWorkflowExpanded(Int)
  AdminRuleMetricsWorkflowDetailsFetched(
    ApiResult(api_workflows.WorkflowMetrics),
  )
  AdminRuleMetricsDrilldownClicked(Int)
  AdminRuleMetricsDrilldownClosed
  AdminRuleMetricsRuleDetailsFetched(
    ApiResult(api_workflows.RuleMetricsDetailed),
  )
  AdminRuleMetricsExecutionsFetched(
    ApiResult(api_workflows.RuleExecutionsResponse),
  )
  AdminRuleMetricsExecPageChanged(Int)
  CardsFetched(ApiResult(List(Card)))
  OpenCardDialog(state_types.CardDialogMode)
  CloseCardDialog
  CardCrudCreated(Card)
  CardCrudUpdated(Card)
  CardCrudDeleted(Int)
  CardsShowEmptyToggled
  CardsShowCompletedToggled
  CardsStateFilterChanged(String)
  CardsSearchChanged(String)
  OpenCardDetail(Int)
  CloseCardDetail
  WorkflowsProjectFetched(ApiResult(List(Workflow)))
  OpenWorkflowDialog(state_types.WorkflowDialogMode)
  CloseWorkflowDialog
  WorkflowCrudCreated(Workflow)
  WorkflowCrudUpdated(Workflow)
  WorkflowCrudDeleted(Int)
  WorkflowRulesClicked(Int)
  RulesFetched(ApiResult(List(Rule)))
  RulesBackClicked
  OpenRuleDialog(state_types.RuleDialogMode)
  CloseRuleDialog
  RuleCrudCreated(Rule)
  RuleCrudUpdated(Rule)
  RuleCrudDeleted(Int)
  RuleTemplatesClicked(Int)
  RuleTemplatesFetched(ApiResult(List(RuleTemplate)))
  RuleAttachTemplateSelected(String)
  RuleAttachTemplateSubmitted
  RuleTemplateAttached(ApiResult(List(RuleTemplate)))
  RuleTemplateDetachClicked(Int)
  RuleTemplateDetached(ApiResult(Nil))
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
  RuleMetricsFetched(ApiResult(api_workflows.WorkflowMetrics))
  TaskTemplatesProjectFetched(ApiResult(List(TaskTemplate)))
  OpenTaskTemplateDialog(state_types.TaskTemplateDialogMode)
  CloseTaskTemplateDialog
  TaskTemplateCrudCreated(TaskTemplate)
  TaskTemplateCrudUpdated(TaskTemplate)
  TaskTemplateCrudDeleted(Int)
}
