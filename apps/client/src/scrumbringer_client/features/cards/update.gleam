//// Cards feature update handlers.
////
//// Re-exported from admin cards handlers (Phase 1 modularization).

import scrumbringer_client/features/admin/cards as admin_cards

pub const handle_cards_fetched_ok = admin_cards.handle_cards_fetched_ok

pub const handle_cards_fetched_error = admin_cards.handle_cards_fetched_error

pub const handle_open_card_dialog = admin_cards.handle_open_card_dialog

pub const handle_close_card_dialog = admin_cards.handle_close_card_dialog

pub const handle_card_crud_created = admin_cards.handle_card_crud_created

pub const handle_card_crud_updated = admin_cards.handle_card_crud_updated

pub const handle_card_crud_deleted = admin_cards.handle_card_crud_deleted

pub const fetch_cards_for_project = admin_cards.fetch_cards_for_project
