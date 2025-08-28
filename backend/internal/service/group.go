package service

import (
	"context"
	"crypto/rand"
	"errors"
	"fmt"
	"time"

	appcrypto "secure-messaging-backend/internal/crypto"
	"secure-messaging-backend/internal/store"
)

type GroupService struct {
	groups *store.GroupStore
	users  *store.UserStore
	master []byte
}

func NewGroupService(groups *store.GroupStore, users *store.UserStore, masterKey string) *GroupService {
	return &GroupService{groups: groups, users: users, master: []byte(masterKey)}
}

const cooldownPrivateLeave = 48 * time.Hour

func (s *GroupService) CreateGroup(ctx context.Context, name string, ownerID int64, typ string, maxMembers int) (*store.Group, error) {
	if name == "" { return nil, errors.New("name required") }
	if typ != "open" && typ != "private" { return nil, errors.New("type must be open or private") }
	if maxMembers <= 0 || maxMembers > 1000 { maxMembers = 100 }
	// generate AES-128 key
	gk := make([]byte, 16)
	if _, err := rand.Read(gk); err != nil { return nil, err }
	ct, nonce, err := appcrypto.WrapKey(s.master, gk)
	if err != nil { return nil, err }
	g, err := s.groups.CreateGroup(ctx, name, ownerID, typ, maxMembers, ct, nonce)
	if err != nil { return nil, err }
	// owner becomes member
	if err := s.groups.AddMember(ctx, g.ID, ownerID); err != nil { return nil, err }
	return g, nil
}

func (s *GroupService) ListPublic(ctx context.Context, limit int) ([]store.Group, error) {
	return s.groups.ListPublicGroups(ctx, limit)
}

func (s *GroupService) ListOwned(ctx context.Context, ownerID int64) ([]store.Group, error) {
	return s.groups.ListOwnedGroups(ctx, ownerID)
}

func (s *GroupService) Join(ctx context.Context, groupID, userID int64) (string, error) {
	g, err := s.groups.GetGroup(ctx, groupID)
	if err != nil { return "", err }
	if banned, err := s.groups.IsBanned(ctx, groupID, userID); err != nil { return "", err } else if banned { return "", errors.New("user is banned") }
	isMember, err := s.groups.IsMember(ctx, groupID, userID)
	if err != nil { return "", err }
	if isMember { return "member", nil }
	if g.Type == "open" {
		count, err := s.groups.CountMembers(ctx, groupID)
		if err != nil { return "", err }
		if count >= g.MaxMembers { return "", errors.New("group full") }
		if err := s.groups.AddMember(ctx, groupID, userID); err != nil { return "", err }
		return "joined", nil
	}
	// private: enforce 48h cooldown from last_left_at
	if last, err := s.groups.GetLastLeft(ctx, groupID, userID); err != nil { return "", err } else if last != nil {
		if time.Since(*last) < cooldownPrivateLeave { return "", fmt.Errorf("cooldown active: try after %s", last.Add(cooldownPrivateLeave).Format(time.RFC3339)) }
	}
	jr, err := s.groups.CreateJoinRequest(ctx, groupID, userID)
	if err != nil { return "", err }
	return fmt.Sprintf("join_requested:%d", jr.ID), nil
}

func (s *GroupService) Leave(ctx context.Context, groupID, userID int64) error {
	g, err := s.groups.GetGroup(ctx, groupID)
	if err != nil { return err }
	if g.OwnerID == userID {
		ok, err := s.groups.OwnerLeaveAllowed(ctx, groupID)
		if err != nil { return err }
		if !ok { return errors.New("owner cannot leave unless sole member; transfer ownership or delete group") }
	}
	if err := s.groups.RemoveMember(ctx, groupID, userID); err != nil { return err }
	// mark last_left_at
	_ = s.groups.UpdateLastLeft(ctx, groupID, userID, time.Now())
	return nil
}

func (s *GroupService) TransferOwner(ctx context.Context, groupID, currentOwner, newOwner int64) error {
	g, err := s.groups.GetGroup(ctx, groupID)
	if err != nil { return err }
	if g.OwnerID != currentOwner { return errors.New("only owner can transfer") }
	isMember, err := s.groups.IsMember(ctx, groupID, newOwner)
	if err != nil { return err }
	if !isMember { return errors.New("new owner must be a member") }
	return s.groups.TransferOwner(ctx, groupID, newOwner)
}

func (s *GroupService) Delete(ctx context.Context, groupID, ownerID int64) error {
	g, err := s.groups.GetGroup(ctx, groupID)
	if err != nil { return err }
	if g.OwnerID != ownerID { return errors.New("only owner can delete") }
	ok, err := s.groups.OwnerLeaveAllowed(ctx, groupID)
	if err != nil { return err }
	if !ok { return errors.New("owner can delete only when sole member") }
	return s.groups.DeleteGroup(ctx, groupID)
}

func (s *GroupService) Banish(ctx context.Context, groupID, ownerID, targetUser int64, reason *string) error {
	g, err := s.groups.GetGroup(ctx, groupID)
	if err != nil { return err }
	if g.OwnerID != ownerID { return errors.New("only owner can banish") }
	if targetUser == ownerID { return errors.New("cannot banish owner") }
	if err := s.groups.AddBan(ctx, groupID, targetUser, reason); err != nil { return err }
	_ = s.groups.RemoveMember(ctx, groupID, targetUser)
	_ = s.groups.UpdateLastLeft(ctx, groupID, targetUser, time.Now())
	return nil
}
