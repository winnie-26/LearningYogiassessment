package service

import (
	"context"
	"errors"
	"time"

	"github.com/rs/zerolog"
	"secure-messaging-backend/internal/config"
	appcrypto "secure-messaging-backend/internal/crypto"
	"secure-messaging-backend/internal/store"
)

type MessageService struct {
	cfg    *config.Config
	groups *store.GroupStore
	msgs   *store.MessageStore
	log    zerolog.Logger
}

func NewMessageService(cfg *config.Config, groups *store.GroupStore, msgs *store.MessageStore, log zerolog.Logger) *MessageService {
	return &MessageService{cfg: cfg, groups: groups, msgs: msgs, log: log}
}

type SendMessageInput struct {
	GroupID  int64
	SenderID int64
	Plain    []byte
}

type MessageDTO struct {
	ID        int64
	GroupID   int64
	SenderID  int64
	Plain     []byte
	CreatedAt time.Time
}

func (s *MessageService) ensureMember(ctx context.Context, groupID, userID int64) error {
	isMember, err := s.groups.IsMember(ctx, groupID, userID)
	if err != nil { return err }
	if !isMember { return errors.New("not a group member") }
	return nil
}

func (s *MessageService) unwrapKey(ctx context.Context, groupID int64) ([]byte, error) {
	g, err := s.groups.GetGroup(ctx, groupID)
	if err != nil { return nil, err }
	return appcrypto.UnwrapKey([]byte(s.cfg.MasterKey), g.EncryptedKey, g.KeyNonce)
}

func (s *MessageService) Send(ctx context.Context, in SendMessageInput) (*MessageDTO, error) {
	if err := s.ensureMember(ctx, in.GroupID, in.SenderID); err != nil { return nil, err }
	key, err := s.unwrapKey(ctx, in.GroupID)
	if err != nil { return nil, err }
	ct, iv, err := appcrypto.EncryptMessage(key, in.Plain)
	if err != nil { return nil, err }
	m, err := s.msgs.Create(ctx, in.GroupID, in.SenderID, ct, iv)
	if err != nil { return nil, err }
	// Simulated notification via log
	s.log.Info().Int64("group_id", in.GroupID).Int64("sender_id", in.SenderID).Int64("message_id", m.ID).Msg("Message sent")
	return &MessageDTO{ID: m.ID, GroupID: m.GroupID, SenderID: m.SenderID, Plain: in.Plain, CreatedAt: m.CreatedAt}, nil
}

func (s *MessageService) List(ctx context.Context, groupID, requesterID int64, limit int, before *time.Time) ([]MessageDTO, error) {
	if err := s.ensureMember(ctx, groupID, requesterID); err != nil { return nil, err }
	key, err := s.unwrapKey(ctx, groupID)
	if err != nil { return nil, err }
	rows, err := s.msgs.List(ctx, groupID, limit, before)
	if err != nil { return nil, err }
	out := make([]MessageDTO, 0, len(rows))
	for _, r := range rows {
		pt, err := appcrypto.DecryptMessage(key, r.Ciphertext, r.IV)
		if err != nil { return nil, err }
		out = append(out, MessageDTO{ID: r.ID, GroupID: r.GroupID, SenderID: r.SenderID, Plain: pt, CreatedAt: r.CreatedAt})
	}
	return out, nil
}
