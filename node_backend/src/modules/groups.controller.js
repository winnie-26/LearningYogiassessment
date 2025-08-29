const svc = require('./groups.service');
const groupInviteService = require('./groupInvites.service');
const { InviteError } = groupInviteService;

async function list(req, res, next) {
  try {
    const limit = req.query.limit ? Number(req.query.limit) : undefined;
    const userId = req.user && req.user.sub ? Number(req.user.sub) : undefined;
    const items = await svc.list({ limit, userId });
    res.json(items);
  } catch (e) { next(e); }
}

async function canJoin(req, res, next) {
  try {
    const groupId = req.params.id;
    const userId = req.user?.sub;
    
    if (!userId) {
      return res.status(401).json({ 
        canJoin: false, 
        reason: 'authentication_required',
        message: 'You need to be logged in to join a group'
      });
    }
    
    // Check if user is already a member
    const { rows: memberCheck } = await svc.checkMembership(groupId, userId);
    if (memberCheck.length > 0) {
      return res.json({ 
        canJoin: true, 
        isMember: true,
        message: 'You are already a member of this group'
      });
    }
    
    // Check group type and permissions
    const group = await svc.getGroup(groupId);
    if (!group) {
      return res.status(404).json({
        canJoin: false,
        reason: 'not_found',
        message: 'Group not found'
      });
    }
    
    // For private groups, check for pending invites
    if (group.type === 'private') {
      const { rows: inviteCheck } = await groupInviteService.findInvite(groupId, userId);
      const hasPendingInvite = inviteCheck.some(invite => invite.status === 'pending');
      
      if (!hasPendingInvite) {
        return res.json({
          canJoin: false,
          isPrivate: true,
          reason: 'invitation_required',
          message: 'This is a private group. You need an invitation to join.'
        });
      }
    }
    
    // Check group capacity
    const { rows: countRows } = await svc.getMemberCount(groupId);
    const memberCount = countRows[0]?.count || 0;
    
    if (memberCount >= group.max_members) {
      return res.json({
        canJoin: false,
        reason: 'group_full',
        message: 'This group has reached its maximum capacity.'
      });
    }
    
    // All checks passed
    res.json({ 
      canJoin: true,
      requiresInvite: group.type === 'private',
      message: group.type === 'private' 
        ? 'You have a pending invitation to join this private group' 
        : 'You can join this group'
    });
    
  } catch (error) {
    next(error);
  }
}

async function create(req, res, next) {
  try {
    const payload = req.body || {};
    const group = await svc.create(payload, req.user.sub);
    res.status(201).json(group);
  } catch (e) { next(e); }
}

async function join(req, res, next) {
  try {
    const g = await svc.join(req.params.id, req.user.sub);
    res.json({ ok: true, group_id: g.id, members: g.members_count });
  } catch (e) { next(e); }
}

async function leave(req, res, next) {
  try {
    const g = await svc.leave(req.params.id, req.user.sub);
    res.json({ ok: true, group_id: g.id, members: g.members_count });
  } catch (e) { next(e); }
}

async function transferOwner(req, res, next) {
  try {
    const { new_owner_id } = req.body || {};
    const g = await svc.transferOwner(req.params.id, new_owner_id);
    res.json({ ok: true, group_id: g.id, owner_id: g.owner_id });
  } catch (e) { next(e); }
}

async function destroy(req, res, next) {
  try {
    const out = await svc.destroy(req.params.id);
    res.json(out);
  } catch (e) { next(e); }
}

async function update(req, res, next) {
  try {
    const groupId = req.params.id;
    const userId = req.user?.sub;
    const payload = req.body || {};

    // Ensure user is authenticated
    if (!userId) {
      return res.status(401).json({ code: 'unauthorized', message: 'Login required' });
    }

    // Only owner can update the group
    const group = await svc.getGroup(groupId);
    if (!group) return res.status(404).json({ code: 'not_found', message: 'Group not found' });
    if (String(group.owner_id) !== String(userId)) {
      return res.status(403).json({ code: 'forbidden', message: 'Only the owner can update this group' });
    }

    // Allowed fields
    const { name, type, max_members } = payload;
    const updated = await svc.update(groupId, { name, type, max_members });
    return res.json(updated);
  } catch (e) {
    next(e);
  }
}

// Add the missing methods to the service if they don't exist
if (!svc.checkMembership) {
  svc.checkMembership = async (groupId, userId) => {
    const pool = require('../data/db').getPool();
    return pool.query(
      'SELECT 1 FROM group_members WHERE group_id = $1 AND user_id = $2',
      [groupId, userId]
    );
  };
}

if (!svc.getGroup) {
  svc.getGroup = async (groupId) => {
    const pool = require('../data/db').getPool();
    const { rows } = await pool.query(
      'SELECT * FROM groups WHERE id = $1',
      [groupId]
    );
    return rows[0];
  };
}

if (!svc.getMemberCount) {
  svc.getMemberCount = async (groupId) => {
    const pool = require('../data/db').getPool();
    return pool.query(
      'SELECT COUNT(*) FROM group_members WHERE group_id = $1',
      [groupId]
    );
  };
}

// Export all controller functions
module.exports = { 
  list, 
  create, 
  join, 
  leave, 
  transferOwner, 
  destroy, 
  canJoin,
  update,
};
