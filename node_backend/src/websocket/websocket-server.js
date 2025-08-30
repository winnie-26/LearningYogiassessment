const WebSocket = require('ws');
const jwt = require('jsonwebtoken');
const { StatusCodes } = require('http-status-codes');

class WebSocketServer {
  constructor(server) {
    this.wss = new WebSocket.Server({ 
      server,
      path: '/ws'
    });
    
    // Store connections by group ID
    this.groupConnections = new Map();
    
    this.wss.on('connection', (ws, request) => {
      this.handleConnection(ws, request);
    });
    
    console.log('[WebSocket] Server initialized');
  }

  handleConnection(ws, request) {
    console.log('[WebSocket] New connection attempt');
    
    ws.isAlive = true;
    ws.groupId = null;
    ws.userId = null;

    ws.on('pong', () => {
      ws.isAlive = true;
    });

    ws.on('message', async (data) => {
      try {
        const message = JSON.parse(data.toString());
        await this.handleMessage(ws, message);
      } catch (error) {
        console.error('[WebSocket] Error parsing message:', error);
        this.sendError(ws, 'Invalid message format');
      }
    });

    ws.on('close', () => {
      this.handleDisconnection(ws);
    });

    ws.on('error', (error) => {
      console.error('[WebSocket] Connection error:', error);
    });
  }

  async handleMessage(ws, message) {
    const { type } = message;
    console.log(`[WebSocket] Received message type: ${type}`, message);

    try {
      switch (type) {
        case 'auth':
          await this.handleAuth(ws, message);
          break;
        case 'join_group':
          await this.handleJoinGroup(ws, message);
          break;
        case 'message':
          await this.handleChatMessage(ws, message);
          break;
        case 'ping':
          console.log('[WebSocket] Received ping, sending pong');
          this.sendMessage(ws, { type: 'pong' });
          break;
        default:
          console.log(`[WebSocket] Unknown message type: ${type}`);
          this.sendError(ws, 'Unknown message type');
      }
    } catch (error) {
      console.error(`[WebSocket] Error handling message type ${type}:`, error);
      this.sendError(ws, `Error processing message: ${error.message}`);
    }
  }

  async handleAuth(ws, message) {
    console.log('[WebSocket] Handling auth message:', message);
    const { token, groupId } = message;

    if (!token) {
      const error = 'Token required';
      console.error(`[WebSocket] ${error}`);
      this.sendError(ws, error);
      return ws.close(StatusCodes.UNAUTHORIZED);
    }

    try {
      let decoded;
      
      // Handle test tokens for development
      if (token.startsWith('test-token-')) {
        decoded = { sub: token.replace('test-token-', 'user-') };
        console.log('[WebSocket] Using test token for development');
      } else {
        decoded = jwt.verify(token, process.env.JWT_SECRET);
      }
      
      ws.userId = decoded.sub || decoded.user_id || decoded.id;
      ws.groupId = groupId;

      // Add to group connections
      if (!this.groupConnections.has(groupId)) {
        this.groupConnections.set(groupId, new Set());
      }
      this.groupConnections.get(groupId).add(ws);

      this.sendMessage(ws, { 
        type: 'auth_success', 
        userId: ws.userId,
        groupId: ws.groupId
      });

      console.log(`[WebSocket] User ${ws.userId} authenticated for group ${groupId}`);
    } catch (error) {
      console.error('[WebSocket] Auth error:', error);
      this.sendError(ws, 'Invalid token');
      ws.close(StatusCodes.UNAUTHORIZED);
    }
  }

  async handleJoinGroup(ws, message) {
    console.log('[WebSocket] Handling join group:', message);
    const { groupId } = message;
    
    if (!ws.userId) {
      const error = 'Not authenticated';
      console.error(`[WebSocket] ${error}`);
      this.sendError(ws, error);
      return;
    }

    // Remove from previous group if any
    if (ws.groupId && this.groupConnections.has(ws.groupId)) {
      this.groupConnections.get(ws.groupId).delete(ws);
    }

    // Add to new group
    ws.groupId = groupId;
    if (!this.groupConnections.has(groupId)) {
      this.groupConnections.set(groupId, new Set());
    }
    this.groupConnections.get(groupId).add(ws);

    this.sendMessage(ws, { 
      type: 'joined_group', 
      groupId 
    });

    console.log(`[WebSocket] User ${ws.userId} joined group ${groupId}`);
  }

  async handleChatMessage(ws, message) {
    const { text, group_id, sender_id } = message;
    const userId = sender_id || ws.userId;

    if (!ws.userId || !ws.groupId) {
      this.sendError(ws, 'Not authenticated or not in a group');
      return;
    }

    try {
      // Get user details from the database
      const userRepo = require('../modules/users.repository');
      const user = await userRepo.findById(userId);
      
      if (!user) {
        console.error(`[WebSocket] User ${userId} not found`);
        this.sendError(ws, 'User not found');
        return;
      }

      // Create message object to broadcast with proper format matching API response
      const broadcastMessage = {
        type: 'new_message',
        id: Date.now(), // Simple ID generation
        text: text || '',
        sender: {
          id: user.id || userId,
          // Use username if available, otherwise use the first part of the email
          name: user.username || (user.email ? user.email.split('@')[0] : `User${userId}`),
          email: user.email || `user${userId}@example.com`,
          username: user.username || null
        },
        group_id: group_id || ws.groupId,
        user_id: userId,
        created_at: new Date().toISOString()
      };
      
      console.log('Broadcasting message with sender:', broadcastMessage.sender);

      // Broadcast to all clients in the group
      this.broadcastToGroup(ws.groupId, broadcastMessage);
      console.log(`[WebSocket] Message broadcasted to group ${ws.groupId}`);
    } catch (error) {
      console.error('[WebSocket] Error handling chat message:', error);
      this.sendError(ws, 'Error processing message');
    }
  }

  handleDisconnection(ws) {
    if (ws.groupId && this.groupConnections.has(ws.groupId)) {
      this.groupConnections.get(ws.groupId).delete(ws);
      
      // Clean up empty groups
      if (this.groupConnections.get(ws.groupId).size === 0) {
        this.groupConnections.delete(ws.groupId);
      }
    }

    console.log(`[WebSocket] User ${ws.userId} disconnected from group ${ws.groupId}`);
  }

  broadcastToGroup(groupId, message) {
    const connections = this.groupConnections.get(groupId);
    if (!connections) return;

    connections.forEach(client => {
      if (client.readyState === WebSocket.OPEN) {
        this.sendMessage(client, message);
      }
    });
  }

  sendMessage(ws, message) {
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify(message));
    }
  }

  sendError(ws, error) {
    this.sendMessage(ws, { type: 'error', message: error });
  }

  // Broadcast new message from API to WebSocket clients
  broadcastNewMessage(groupId, message) {
    const groupConnections = this.groupConnections.get(parseInt(groupId));
    if (!groupConnections) {
      console.log(`[WebSocket] No connections found for group ${groupId}`);
      return;
    }

    // Ensure the message has the correct type field for frontend filtering
    const messageToSend = {
      ...message,
      type: 'new_message', // This must match what frontend expects
    };

    console.log('[WebSocket] Broadcasting message:', messageToSend);
    const messageString = JSON.stringify(messageToSend);

    groupConnections.forEach((ws) => {
      if (ws.readyState === WebSocket.OPEN) {
        ws.send(messageString);
      }
    });

    console.log(`[WebSocket] Broadcasted message to ${groupConnections.size} clients in group ${groupId}`);
  }

  // Heartbeat to keep connections alive
  startHeartbeat() {
    setInterval(() => {
      this.wss.clients.forEach(ws => {
        if (!ws.isAlive) {
          return ws.terminate();
        }
        
        ws.isAlive = false;
        ws.ping();
      });
    }, 30000); // 30 seconds
  }

  // Broadcast new message from API to WebSocket clients
  broadcastNewMessage(groupId, message) {
    const broadcastMessage = {
      type: 'new_message',
      ...message
    };
    
    this.broadcastToGroup(groupId.toString(), broadcastMessage);
  }
}

module.exports = WebSocketServer;
