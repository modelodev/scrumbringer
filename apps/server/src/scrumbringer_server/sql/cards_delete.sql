-- name: delete_card
DELETE FROM cards WHERE id = $1;
