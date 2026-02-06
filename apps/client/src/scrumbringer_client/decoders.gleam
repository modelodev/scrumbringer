//// Shared JSON decoders for client domain types.

import gleam/dynamic/decode

import domain/card
import domain/card/codec as card_codec
import domain/project_role
import domain/project_role/codec as project_role_codec

/// Decoder for ProjectRole.
pub fn project_role_decoder() -> decode.Decoder(project_role.ProjectRole) {
  project_role_codec.project_role_decoder()
}

/// Decoder for CardState.
pub fn card_state_decoder() -> decode.Decoder(card.CardState) {
  card_codec.card_state_decoder()
}
