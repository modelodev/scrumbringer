//// Member-specific client state model.

import gleam/option.{type Option}

import scrumbringer_client/client_state/member/dependencies as member_dependencies
import scrumbringer_client/client_state/member/metrics as member_metrics
import scrumbringer_client/client_state/member/notes as member_notes
import scrumbringer_client/client_state/member/now_working as member_now_working
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/client_state/member/positions as member_positions
import scrumbringer_client/client_state/member/skills as member_skills
import scrumbringer_client/features/cards/show as card_show
import scrumbringer_client/features/tasks/show/model as task_show_model

/// Represents pool member slice.
pub type PoolModel =
  member_pool.Model

/// Represents now-working member slice.
pub type NowWorkingModel =
  member_now_working.Model

/// Represents metrics member slice.
pub type MetricsModel =
  member_metrics.Model

/// Represents skills member slice.
pub type SkillsModel =
  member_skills.Model

/// Represents positions member slice.
pub type PositionsModel =
  member_positions.Model

/// Represents notes member slice.
pub type NotesModel =
  member_notes.Model

/// Represents dependencies member slice.
pub type DependenciesModel =
  member_dependencies.Model

/// Represents card show member slice.
pub type CardShowModel =
  card_show.Model

/// Represents task show member slice.
pub type TaskShowModel =
  task_show_model.Model

/// Represents MemberModel.
pub type MemberModel {
  MemberModel(
    pool: PoolModel,
    now_working: NowWorkingModel,
    metrics: MetricsModel,
    skills: SkillsModel,
    positions: PositionsModel,
    notes: NotesModel,
    dependencies: DependenciesModel,
    card_show_open: Option(Int),
    card_show_model: CardShowModel,
    task_show: TaskShowModel,
  )
}

/// Provides default member state.
pub fn default_model() -> MemberModel {
  MemberModel(
    pool: member_pool.default_model(),
    now_working: member_now_working.default_model(),
    metrics: member_metrics.default_model(),
    skills: member_skills.default_model(),
    positions: member_positions.default_model(),
    notes: member_notes.default_model(),
    dependencies: member_dependencies.default_model(),
    card_show_open: option.None,
    card_show_model: card_show.init_model(),
    task_show: task_show_model.default(),
  )
}

/// Reset drag-related state on the member model.
pub fn reset_drag_state(member: MemberModel) -> MemberModel {
  let pool = member.pool

  MemberModel(
    ..member,
    pool: member_pool.Model(
      ..pool,
      member_drag: member_pool.DragIdle,
      member_pool_drag: member_pool.PoolDragIdle,
    ),
  )
}
