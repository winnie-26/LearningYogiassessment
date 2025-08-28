const repo = require('./messages.repository');

async function send(groupId, userId, text) {
  if (!text || typeof text !== 'string') {
    const err = new Error('invalid_payload'); err.status = 400; err.code = 'invalid_payload'; throw err;
  }
  return repo.add(Number(groupId), userId, text);
}

async function list(groupId, { limit } = {}) {
  const lim = typeof limit === 'number' ? limit : (limit ? Number(limit) : undefined);
  return repo.list(Number(groupId), { limit: lim });
}

module.exports = { send, list };
