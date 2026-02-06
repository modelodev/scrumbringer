//// Task API decoders.
////
//// Delegates JSON decoding to shared domain codecs.

import domain/task/codec as task_codec
import domain/task_status

// Re-export parse_task_status for backwards compatibility.
pub const parse_task_status = task_status.parse_task_status

// Re-export decoders from shared domain.
pub const task_type_decoder = task_codec.task_type_decoder

pub const task_type_inline_decoder = task_codec.task_type_inline_decoder

pub const ongoing_by_decoder = task_codec.ongoing_by_decoder

pub const work_state_decoder = task_codec.work_state_decoder

pub const task_decoder = task_codec.task_decoder

pub const task_dependency_decoder = task_codec.task_dependency_decoder

pub const note_decoder = task_codec.note_decoder

pub const position_decoder = task_codec.position_decoder

pub const work_session_decoder = task_codec.work_session_decoder

pub const work_sessions_payload_decoder = task_codec.work_sessions_payload_decoder
