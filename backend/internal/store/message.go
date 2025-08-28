package store

import (
	"context"
	"time"

	"github.com/jmoiron/sqlx"
)

type Message struct {
	ID        int64     `db:"id"`
	GroupID   int64     `db:"group_id"`
	SenderID  int64     `db:"sender_id"`
	Ciphertext string   `db:"ciphertext"`
	IV        string    `db:"iv"`
	CreatedAt time.Time `db:"created_at"`
}

type MessageStore struct{ db *sqlx.DB }

func NewMessageStore(db *sqlx.DB) *MessageStore { return &MessageStore{db: db} }

func (s *MessageStore) Create(ctx context.Context, groupID, senderID int64, ciphertext, iv string) (*Message, error) {
	m := &Message{}
	err := s.db.QueryRowxContext(ctx, `
		INSERT INTO messages (group_id, sender_id, ciphertext, iv)
		VALUES ($1,$2,$3,$4)
		RETURNING id, group_id, sender_id, ciphertext, iv, created_at
	`, groupID, senderID, ciphertext, iv).StructScan(m)
	return m, err
}

func (s *MessageStore) List(ctx context.Context, groupID int64, limit int, before *time.Time) ([]Message, error) {
	if limit <= 0 || limit > 100 { limit = 50 }
	msgs := []Message{}
	if before != nil {
		err := s.db.SelectContext(ctx, &msgs, `
			SELECT id, group_id, sender_id, ciphertext, iv, created_at
			FROM messages WHERE group_id=$1 AND created_at < $2
			ORDER BY created_at DESC LIMIT $3
		`, groupID, *before, limit)
		return msgs, err
	}
	err := s.db.SelectContext(ctx, &msgs, `
		SELECT id, group_id, sender_id, ciphertext, iv, created_at
		FROM messages WHERE group_id=$1
		ORDER BY created_at DESC LIMIT $2
	`, groupID, limit)
	return msgs, err
}
