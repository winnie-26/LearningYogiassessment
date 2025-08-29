require('dotenv').config();
const app = require('./app');
const { migrate, isDbEnabled } = require('./data/db');

async function start() {
  try {
    await migrate();
    // eslint-disable-next-line no-console
    console.log(`[server] DB ${isDbEnabled() ? 'enabled' : 'disabled'} — migrations complete`);
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error('[server] migration failed:', e);
  }
  const PORT = process.env.PORT || 8080;
  app.listen(PORT, () => {
    // eslint-disable-next-line no-console
    console.log(`[server] listening on port ${PORT}`);
  });
}

start();
