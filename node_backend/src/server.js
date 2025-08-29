require('dotenv').config();
const http = require('http');
const app = require('./app');
const { migrate, isDbEnabled } = require('./data/db');
const WebSocketServer = require('./websocket/websocket-server');

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
  
  // Create HTTP server
  const server = http.createServer(app);
  
  // Initialize WebSocket server
  const wsServer = new WebSocketServer(server);
  wsServer.startHeartbeat();
  
  // Make WebSocket server available globally for message broadcasting
  global.wsServer = wsServer;
  
  server.listen(PORT, () => {
    // eslint-disable-next-line no-console
    console.log(`[server] HTTP and WebSocket server listening on port ${PORT}`);
  });
}

start();
