package service

import (
	"context"
	"errors"
	"strconv"

	"secure-messaging-backend/internal/store"
)

type JoinRequestService struct {
	groups *store.GroupStore
}

func NewJoinRequestService(groups *store.GroupStore) *JoinRequestService {
	return &JoinRequestService{groups: groups}
}

func (s *JoinRequestService) ListPending(ctx context.Context, groupID, ownerID int64) ([]store.JoinRequest, error) {
	g, err := s.groups.GetGroup(ctx, groupID)
	if err != nil { return nil, err }
	if g.OwnerID != ownerID { return nil, errors.New("only owner can view join requests") }
	return s.groups.ListPendingJoinRequests(ctx, groupID)
}

func (s *JoinRequestService) Approve(ctx context.Context, groupID, ownerID, reqID int64) error {
	g, err := s.groups.GetGroup(ctx, groupID)
	if err != nil { return err }
	if g.OwnerID != ownerID { return errors.New("only owner can approve") }
	jr, err := s.groups.GetJoinRequestByID(ctx, reqID)
	if err != nil { return err }
	if jr.GroupID != groupID { return errors.New("request not in this group: " + strconv.FormatInt(jr.GroupID, 10)) }
	return s.groups.ApproveJoinRequest(ctx, reqID)
}

func (s *JoinRequestService) Decline(ctx context.Context, groupID, ownerID, reqID int64) error {
	g, err := s.groups.GetGroup(ctx, groupID)
	if err != nil { return err }
	if g.OwnerID != ownerID { return errors.New("only owner can decline") }
	jr, err := s.groups.GetJoinRequestByID(ctx, reqID)
	if err != nil { return err }
	if jr.GroupID != groupID { return errors.New("request not in this group") }
	return s.groups.SetJoinRequestStatus(ctx, reqID, "declined")
}
