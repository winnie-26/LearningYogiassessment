const invitesService = require('./groupInvites.service');
const { InviteError } = invitesService;

async function createInvite(req, res, next) {
  try {
    const { groupId } = req.params;
    const { user_id: userId } = req.body;
    const inviterId = req.user.sub; // From auth middleware

    if (!userId) {
      return res.status(400).json({ 
        error: 'user_id is required' 
      });
    }

    const invite = await invitesService.createInvite(
      groupId, 
      userId, 
      inviterId
    );
    
    res.status(201).json(invite);
  } catch (error) {
    if (error instanceof InviteError) {
      return res.status(error.status || 400).json({ 
        error: error.message,
        code: error.code
      });
    }
    next(error);
  }
}

async function getInvite(req, res, next) {
  try {
    const { inviteId } = req.params;
    const invite = await invitesService.getInvite(inviteId);
    res.json(invite);
  } catch (error) {
    if (error instanceof InviteError) {
      return res.status(error.status || 400).json({ 
        error: error.message,
        code: error.code
      });
    }
    next(error);
  }
}

async function listGroupInvites(req, res, next) {
  try {
    const { groupId } = req.params;
    const { status = 'pending' } = req.query;
    
    const invites = await invitesService.listGroupInvites(groupId, status);
    res.json(invites);
  } catch (error) {
    if (error instanceof InviteError) {
      return res.status(error.status || 400).json({ 
        error: error.message,
        code: error.code
      });
    }
    next(error);
  }
}

async function respondToInvite(req, res, next) {
  try {
    const { inviteId } = req.params;
    const { action } = req.body; // 'accept' or 'decline'
    const userId = req.user.sub;

    if (!['accept', 'decline'].includes(action)) {
      return res.status(400).json({ 
        error: 'Invalid action. Must be "accept" or "decline"' 
      });
    }

    const status = action === 'accept' ? 'accepted' : 'declined';
    const invite = await invitesService.updateInviteStatus(inviteId, status, userId);
    
    res.json({
      message: `Invite ${status} successfully`,
      invite
    });
  } catch (error) {
    if (error instanceof InviteError) {
      return res.status(error.status || 400).json({ 
        error: error.message,
        code: error.code
      });
    }
    next(error);
  }
}

async function revokeInvite(req, res, next) {
  try {
    const { inviteId } = req.params;
    const userId = req.user.sub;
    
    const invite = await invitesService.updateInviteStatus(
      inviteId, 
      'revoked', 
      userId
    );
    
    res.json({
      message: 'Invite revoked successfully',
      invite
    });
  } catch (error) {
    if (error instanceof InviteError) {
      return res.status(error.status || 400).json({ 
        error: error.message,
        code: error.code
      });
    }
    next(error);
  }
}

module.exports = {
  createInvite,
  getInvite,
  listGroupInvites,
  respondToInvite,
  revokeInvite
};
