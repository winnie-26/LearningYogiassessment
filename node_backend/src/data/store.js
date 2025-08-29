// In-memory store (for demo/dev)
let userIdSeq = 1;
let groupIdSeq = 1;
let messageIdSeq = 1;
let joinReqIdSeq = 1;

const users = new Map(); // id -> {id, email, passwordHash}
const usersByEmail = new Map();

const groups = new Map(); // id -> {id, name, type, max_members, owner_id, members: Set<userId>}

const messages = new Map(); // groupId -> [{id, group_id, user_id, text, created_at}]

const joinRequests = new Map(); // groupId -> [{id, group_id, user_id, status: 'pending'|'approved'|'declined'}]

module.exports = {
  // users
  createUser(email, passwordHash) {
    if (usersByEmail.has(email)) throw Object.assign(new Error('email_taken'), { status: 400, code: 'email_taken' });
    const user = { id: userIdSeq++, email, passwordHash };
    users.set(user.id, user);
    usersByEmail.set(email, user);
    return user;
  },
  findUserByEmail(email) { return usersByEmail.get(email) || null; },
  findUserById(id) { return users.get(id) || null; },
  listUsers({ q, limit } = {}) {
    let arr = Array.from(users.values()).map(u => ({ id: u.id, email: u.email }));
    if (q && typeof q === 'string' && q.trim()) {
      const qc = q.toLowerCase();
      arr = arr.filter(u => u.email.toLowerCase().includes(qc));
    }
    if (typeof limit === 'number') return arr.slice(0, limit);
    return arr;
  },

  // groups
  createGroup(name, type, max_members, owner_id, member_ids = []) {
    const g = { id: groupIdSeq++, name, type, max_members, owner_id, members: new Set([owner_id]) };
    // Add initial members (excluding duplicates and owner)
    if (Array.isArray(member_ids)) {
      for (const uid of member_ids) {
        if (typeof uid !== 'number') continue;
        if (g.members.size >= max_members) break;
        if (uid !== owner_id) g.members.add(uid);
      }
    }
    groups.set(g.id, g);
    return g;
  },
  getGroup(id) { return groups.get(id) || null; },
  listGroups({ limit, userId } = {}) {
    const arr = Array.from(groups.values()).map(g => ({
      id: g.id,
      name: g.name,
      type: g.type,
      max_members: g.max_members,
      owner_id: g.owner_id,
      members: g.members.size,
      is_member: userId ? g.members.has(userId) : undefined,
    }));
    if (typeof limit === 'number') return arr.slice(0, limit);
    return arr;
  },
  joinGroup(groupId, userId) {
    const g = groups.get(groupId);
    if (!g) throw Object.assign(new Error('not_found'), { status: 404, code: 'not_found' });
    if (g.members.size >= g.max_members) throw Object.assign(new Error('full'), { status: 400, code: 'group_full' });
    g.members.add(userId);
    return g;
  },
  leaveGroup(groupId, userId) {
    const g = groups.get(groupId);
    if (!g) throw Object.assign(new Error('not_found'), { status: 404, code: 'not_found' });
    g.members.delete(userId);
    return g;
  },
  transferOwner(groupId, newOwnerId) {
    const g = groups.get(groupId);
    if (!g) throw Object.assign(new Error('not_found'), { status: 404, code: 'not_found' });
    g.owner_id = newOwnerId;
    return g;
  },
  deleteGroup(groupId) { return groups.delete(groupId); },

  // join requests
  createJoinRequest(groupId, userId) {
    const jr = { id: joinReqIdSeq++, group_id: groupId, user_id: userId, status: 'pending' };
    if (!joinRequests.has(groupId)) joinRequests.set(groupId, []);
    joinRequests.get(groupId).push(jr);
    return jr;
  },
  listJoinRequests(groupId) { return joinRequests.get(groupId) || []; },
  setJoinRequestStatus(groupId, reqId, status) {
    const list = joinRequests.get(groupId) || [];
    const jr = list.find(j => j.id === reqId);
    if (!jr) throw Object.assign(new Error('not_found'), { status: 404, code: 'not_found' });
    jr.status = status;
    if (status === 'approved') {
      const g = groups.get(groupId); if (g) g.members.add(jr.user_id);
    }
    return jr;
  },

  // messages
  addMessage(groupId, userId, text) {
    const msg = { id: messageIdSeq++, group_id: groupId, user_id: userId, text, created_at: new Date().toISOString() };
    if (!messages.has(groupId)) messages.set(groupId, []);
    messages.get(groupId).push(msg);
    return msg;
  },
  listMessages(groupId, { limit } = {}) {
    const list = messages.get(groupId) || [];
    if (typeof limit === 'number') return list.slice(-limit);
    return list;
  },
};
