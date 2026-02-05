//// Member-specific client state model.

import scrumbringer_client/client_state/member/dependencies as member_dependencies
import scrumbringer_client/client_state/member/metrics as member_metrics
import scrumbringer_client/client_state/member/notes as member_notes
import scrumbringer_client/client_state/member/now_working as member_now_working
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/client_state/member/positions as member_positions
import scrumbringer_client/client_state/member/skills as member_skills
import scrumbringer_client/client_state/types as state_types

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
  )
}

/// Reset drag-related state on the member model.
pub fn reset_drag_state(member: MemberModel) -> MemberModel {
  let pool = member.pool

  MemberModel(
    ..member,
    pool: member_pool.Model(
      ..pool,
      member_drag: state_types.DragIdle,
      member_pool_drag: state_types.PoolDragIdle,
    ),
  )
}
