const store = require('../data/store');

async function add(groupId, userId, text) {
  return store.addMessage(groupId, userId, text);
}

async function list(groupId, { limit } = {}) {
  return store.listMessages(groupId, { limit });
}

module.exports = { add, list };
