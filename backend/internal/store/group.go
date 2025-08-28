package store

import (
	"context"
	"database/sql"
	"errors"
	"time"

	"github.com/jmoiron/sqlx"
)

type Group struct {
	ID               int64      `db:"id"`
	Name             string     `db:"name"`
	OwnerID          int64      `db:"owner_id"`
	Type             string     `db:"type"`
	MaxMembers       int        `db:"max_members"`
	EncryptedKey     string     `db:"encrypted_group_key"`
	KeyNonce         string     `db:"key_nonce"`
	CreatedAt        time.Time  `db:"created_at"`
	DeletedAt        *time.Time `db:"deleted_at"`
}

type GroupMember struct {
	GroupID   int64      `db:"group_id"`
	UserID    int64      `db:"user_id"`
	JoinedAt  time.Time  `db:"joined_at"`
	LastLeftAt *time.Time `db:"last_left_at"`
}

type JoinRequest struct {
	ID          int64     `db:"id"`
	GroupID     int64     `db:"group_id"`
	RequesterID int64     `db:"requester_id"`
	Status      string    `db:"status"`
	CreatedAt   time.Time `db:"created_at"`
}

type Ban struct {
	GroupID   int64     `db:"group_id"`
	UserID    int64     `db:"user_id"`
	Reason    *string   `db:"reason"`
	CreatedAt time.Time `db:"created_at"`
}

type GroupStore struct{ db *sqlx.DB }

func NewGroupStore(db *sqlx.DB) *GroupStore { return &GroupStore{db: db} }

func (s *GroupStore) CreateGroup(ctx context.Context, name string, ownerID int64, typ string, maxMembers int, encKey, nonce string) (*Group, error) {
	g := &Group{}
	err := s.db.QueryRowxContext(ctx, `
		INSERT INTO groups (name, owner_id, type, max_members, encrypted_group_key, key_nonce)
		VALUES ($1,$2,$3,$4,$5,$6)
		RETURNING id, name, owner_id, type, max_members, encrypted_group_key, key_nonce, created_at, deleted_at
	`, name, ownerID, typ, maxMembers, encKey, nonce).StructScan(g)
	return g, err
}

func (s *GroupStore) GetGroup(ctx context.Context, id int64) (*Group, error) {
	g := &Group{}
	err := s.db.GetContext(ctx, g, `SELECT id, name, owner_id, type, max_members, encrypted_group_key, key_nonce, created_at, deleted_at FROM groups WHERE id=$1 AND deleted_at IS NULL`, id)
	return g, err
}

func (s *GroupStore) ListPublicGroups(ctx context.Context, limit int) ([]Group, error) {
	if limit <= 0 || limit > 100 { limit = 50 }
	rows := []Group{}
	err := s.db.SelectContext(ctx, &rows, `SELECT id, name, owner_id, type, max_members, encrypted_group_key, key_nonce, created_at, deleted_at FROM groups WHERE type='open' AND deleted_at IS NULL ORDER BY id DESC LIMIT $1`, limit)
	return rows, err
}

func (s *GroupStore) ListOwnedGroups(ctx context.Context, ownerID int64) ([]Group, error) {
	rows := []Group{}
	err := s.db.SelectContext(ctx, &rows, `SELECT id, name, owner_id, type, max_members, encrypted_group_key, key_nonce, created_at, deleted_at FROM groups WHERE owner_id=$1 AND deleted_at IS NULL ORDER BY id DESC`, ownerID)
	return rows, err
}

func (s *GroupStore) CountMembers(ctx context.Context, groupID int64) (int, error) {
	var n int
	err := s.db.GetContext(ctx, &n, `SELECT COUNT(*) FROM group_members WHERE group_id=$1`, groupID)
	return n, err
}

func (s *GroupStore) IsMember(ctx context.Context, groupID, userID int64) (bool, error) {
	var exists bool
	err := s.db.GetContext(ctx, &exists, `SELECT EXISTS(SELECT 1 FROM group_members WHERE group_id=$1 AND user_id=$2)`, groupID, userID)
	return exists, err
}

func (s *GroupStore) AddMember(ctx context.Context, groupID, userID int64) error {
	_, err := s.db.ExecContext(ctx, `INSERT INTO group_members (group_id, user_id) VALUES ($1,$2) ON CONFLICT (group_id, user_id) DO NOTHING`, groupID, userID)
	return err
}

func (s *GroupStore) RemoveMember(ctx context.Context, groupID, userID int64) error {
	_, err := s.db.ExecContext(ctx, `DELETE FROM group_members WHERE group_id=$1 AND user_id=$2`, groupID, userID)
	return err
}

func (s *GroupStore) UpdateLastLeft(ctx context.Context, groupID, userID int64, t time.Time) error {
	res, err := s.db.ExecContext(ctx, `UPDATE group_members SET last_left_at=$3 WHERE group_id=$1 AND user_id=$2`, groupID, userID, t)
	if err != nil { return err }
	affected, _ := res.RowsAffected()
	if affected == 0 {
		// if not a member row exists, create a tombstone row? We'll ignore.
	}
	return nil
}

func (s *GroupStore) OwnerLeaveAllowed(ctx context.Context, groupID int64) (bool, error) {
	var n int
	err := s.db.GetContext(ctx, &n, `SELECT COUNT(*) FROM group_members WHERE group_id=$1`, groupID)
	if err != nil { return false, err }
	return n <= 1, nil
}

func (s *GroupStore) TransferOwner(ctx context.Context, groupID, newOwnerID int64) error {
	_, err := s.db.ExecContext(ctx, `UPDATE groups SET owner_id=$2 WHERE id=$1`, groupID, newOwnerID)
	return err
}

func (s *GroupStore) DeleteGroup(ctx context.Context, groupID int64) error {
	_, err := s.db.ExecContext(ctx, `UPDATE groups SET deleted_at=now() WHERE id=$1 AND deleted_at IS NULL`, groupID)
	return err
}

func (s *GroupStore) IsBanned(ctx context.Context, groupID, userID int64) (bool, error) {
	var exists bool
	err := s.db.GetContext(ctx, &exists, `SELECT EXISTS(SELECT 1 FROM bans WHERE group_id=$1 AND user_id=$2)`, groupID, userID)
	return exists, err
}

func (s *GroupStore) AddBan(ctx context.Context, groupID, userID int64, reason *string) error {
	_, err := s.db.ExecContext(ctx, `INSERT INTO bans (group_id, user_id, reason) VALUES ($1,$2,$3) ON CONFLICT (group_id, user_id) DO NOTHING`, groupID, userID, reason)
	return err
}

func (s *GroupStore) GetLastLeft(ctx context.Context, groupID, userID int64) (*time.Time, error) {
	gm := &GroupMember{}
	err := s.db.GetContext(ctx, gm, `SELECT group_id, user_id, joined_at, last_left_at FROM group_members WHERE group_id=$1 AND user_id=$2`, groupID, userID)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) { return nil, nil }
		return nil, err
	}
	return gm.LastLeftAt, nil
}

func (s *GroupStore) CreateJoinRequest(ctx context.Context, groupID, userID int64) (*JoinRequest, error) {
	jr := &JoinRequest{}
	err := s.db.QueryRowxContext(ctx, `
		INSERT INTO join_requests (group_id, requester_id, status)
		VALUES ($1,$2,'pending')
		RETURNING id, group_id, requester_id, status, created_at
	`, groupID, userID).StructScan(jr)
	return jr, err
}

func (s *GroupStore) ListPendingJoinRequests(ctx context.Context, groupID int64) ([]JoinRequest, error) {
	rows := []JoinRequest{}
	err := s.db.SelectContext(ctx, &rows, `
		SELECT id, group_id, requester_id, status, created_at
		FROM join_requests WHERE group_id=$1 AND status='pending'
		ORDER BY created_at ASC
	`, groupID)
	return rows, err
}

func (s *GroupStore) GetJoinRequestByID(ctx context.Context, id int64) (*JoinRequest, error) {
	jr := &JoinRequest{}
	err := s.db.GetContext(ctx, jr, `SELECT id, group_id, requester_id, status, created_at FROM join_requests WHERE id=$1`, id)
	return jr, err
}

func (s *GroupStore) SetJoinRequestStatus(ctx context.Context, id int64, status string) error {
	_, err := s.db.ExecContext(ctx, `UPDATE join_requests SET status=$2 WHERE id=$1`, id, status)
	return err
}

func (s *GroupStore) ApproveJoinRequest(ctx context.Context, id int64) error {
	_, err := s.db.ExecContext(ctx, `UPDATE join_requests SET status='approved' WHERE id=$1`, id)
	if err != nil { return err }
	jr := &JoinRequest{}
	err = s.db.GetContext(ctx, jr, `SELECT group_id, requester_id FROM join_requests WHERE id=$1`, id)
	if err != nil { return err }
	return s.AddMember(ctx, jr.GroupID, jr.RequesterID)
}
