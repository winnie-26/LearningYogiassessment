const store = require('../data/store');

async function createUser(email, passwordHash) {
  return store.createUser(email, passwordHash);
}

async function findUserByEmail(email) {
  return store.findUserByEmail(email);
}

async function findUserById(id) {
  return store.findUserById(id);
}

module.exports = { createUser, findUserByEmail, findUserById };
