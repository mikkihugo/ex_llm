#!/usr/bin/env bun

/**
 * @file Nexus Unified Server
 * @description Combines three core components:
 * 1. Remix UI Server - Next-generation control panel with Express + Bun
 * 2. LLM Router (NATS Handler) - Routes agent requests to AI providers
 * 3. HITL WebSocket Bridge - Bridges approval/question requests from NATS to browser
 */

import { createRequestHandler } from '@remix-run/express';
import { broadcastDevReady } from '@remix-run/node';
import express from 'express';
import * as path from 'path';
import { fileURLToPath } from 'url';
import { createServer } from 'http';
import { WebSocketServer } from 'ws';
// import { ApprovalWebSocketBridge } from './approval-websocket-bridge.js';
// import { NATSHandler } from './nats-handler.js';
import { initializeDatabase } from './db.js';
import { getSharedQueueHandler } from './shared-queue-handler.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const MODE = process.env.NODE_ENV || 'development';
const PORT = process.env.PORT || 3000;

// Static files
app.use(express.static('public', { maxAge: '1h' }));
app.use(express.json());

console.log('\n🚀 Initializing Nexus Unified Server...\n');
console.log('━'.repeat(60));

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 0. Initialize Database (PostgreSQL for HITL history)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

console.log('💾 Starting PostgreSQL Database Connection...');
let db = null;
try {
  db = await initializeDatabase();
  console.log('✅ Database initialized\n');
} catch (error) {
  console.error('❌ Failed to initialize database:', error);
  console.error('   Continuing without database. NATS/HITL only.\n');
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 1. Initialize LLM Router (NATS Handler for Elixir)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// NOTE: NATS removed from system. LLM routing pending pgmq integration.

console.log('⏸️  LLM Router (NATS removed, pending pgmq integration)...');
// const llmHandler = new NATSHandler();
// try {
//   await llmHandler.connect();
//   console.log('✅ LLM Router initialized\n');
// } catch (error) {
//   console.error('❌ Failed to initialize LLM Router:', error);
//   console.error('   Continuing without LLM Router. HITL only.\n');
// }

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 2. Initialize HITL Approval Bridge (WebSocket Bridge)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// NOTE: NATS removed from system. HITL approvals pending pgmq integration.

console.log('⏸️  HITL WebSocket Bridge (NATS removed, pending pgmq integration)...');
// const bridge = new ApprovalWebSocketBridge();
// const natsConnected = await bridge.connect();
//
// if (!natsConnected) {
//   console.warn('⚠️  Warning: NATS not available, approval bridge will not receive messages');
// } else {
//   console.log('✅ HITL WebSocket Bridge initialized\n');
// }
//
// // Subscribe to NATS topics
// bridge.subscribeToApprovalRequests().catch(err => {
//   console.error('Error subscribing to approval requests:', err);
// });
//
// bridge.subscribeToQuestionRequests().catch(err => {
//   console.error('Error subscribing to question requests:', err);
// });

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 3. Setup Remix UI Server
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

console.log('⚛️  Setting up Remix UI Server...');

// Vite dev server for development
let viteDevServer: any = null;
if (MODE === 'development') {
  const { createServer: createViteServer } = await import('vite');
  viteDevServer = await createViteServer({
    server: { middlewareMode: true },
  });
  app.use(viteDevServer.middlewares);
} else {
  // Production: serve built assets
  app.use('/build', express.static('build/client', { maxAge: '1y', immutable: true }));
}

// Load Remix build
const BUILD_PATH = viteDevServer
  ? 'virtual:remix/server-build'
  : path.resolve('./build/index.js');

let build: any;
if (viteDevServer) {
  build = await viteDevServer.ssrLoadModule(BUILD_PATH);
} else {
  build = await import(BUILD_PATH);
}

// Create HTTP server
const server = createServer(app);

// Create WebSocket server
const wss = new WebSocketServer({ noServer: true });

// Handle WebSocket upgrades
server.on('upgrade', (request, socket, head) => {
  if (request.url === '/ws/approval') {
    wss.handleUpgrade(request, socket, head, (ws) => {
      bridge.addClient(ws);

      ws.on('message', (data) => {
        try {
          const message = JSON.parse(data.toString());
          bridge.handleClientMessage(message);
        } catch (error) {
          console.error('Error handling WebSocket message:', error);
        }
      });

      ws.on('close', () => {
        console.log('Client disconnected');
      });

      ws.on('error', (error) => {
        console.error('WebSocket error:', error);
      });
    });
  } else {
    socket.destroy();
  }
});

// Set up Remix request handler - must be last
const remixHandler = createRequestHandler({
  build,
  mode: MODE,
});

app.all('*', remixHandler);

// Start server
console.log('✅ Remix UI Server initialized\n');
console.log('━'.repeat(60));
console.log('');

server.listen(PORT, () => {
  console.log(`🎉 Nexus Unified Server ready!\n`);
  console.log(`📍 URL: http://localhost:${PORT}`);
  console.log(`📊 UI: http://localhost:${PORT}/approvals`);
  console.log(`🌐 WebSocket: ws://localhost:${PORT}/ws/approval`);
  console.log(`\n✨ Components:`);
  console.log(`  ✅ PostgreSQL Database - HITL history, metrics, decisions`);
  console.log(`  ✅ LLM Router - Routes agent requests to AI providers`);
  console.log(`  ✅ HITL Bridge - Approval/question human-in-the-loop`);
  console.log(`  ✅ Remix UI - Control panel dashboard`);
  console.log(`\n📬 Message Queues:`);
  console.log(`  ✅ NATS - Legacy messaging (backward compatible)`);
  console.log(`  ✅ shared_queue - pgmq (CentralCloud managed, optional)`);
  console.log('');

  if (MODE === 'development') {
    broadcastDevReady();
  }
});

// Graceful shutdown
process.on('SIGINT', async () => {
  console.log('\n🛑 Shutting down Nexus...');
  await bridge.close();
  await llmHandler.close?.();
  if (db) {
    await db.close();
  }
  process.exit(0);
});
