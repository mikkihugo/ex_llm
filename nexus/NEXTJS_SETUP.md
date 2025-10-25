# Nexus Control Panel (Next.js)

Unified web control panel for Singularity, Genesis, and CentralCloud systems.
Built with Next.js, React, and Vercel AI SDK v5.

## Architecture

```
nexus/
├── src/
│   ├── server.ts              # Legacy Bun server (keep for now)
│   ├── providers/             # AI provider implementations
│   └── ...
├── app/                       # Next.js App Router
│   ├── layout.tsx             # Root layout
│   ├── page.tsx               # Main dashboard
│   ├── api/
│   │   ├── chat/route.ts      # Chat streaming endpoint
│   │   ├── system-status/     # System health endpoints
│   │   └── health/            # Service health checks
│   └── components/
│       ├── dashboard.tsx      # Dashboard overview
│       ├── chat-panel.tsx     # Chat interface with streaming
│       └── system-status.tsx  # System health monitoring
├── lib/
│   └── use-chat.ts            # Custom hook for chat with AI SDK
├── package.json               # Updated with Next.js deps
├── next.config.ts             # Next.js configuration
├── tailwind.config.ts         # Tailwind CSS config
└── tsconfig.json              # Updated for Next.js + Bun
```

## Key Features

### 1. Chat Panel
- Real-time streaming via Vercel AI SDK v5
- Support for multiple providers (Claude, Gemini, Copilot)
- Message history

### 2. Dashboard
- System status overview (Singularity, Genesis, CentralCloud)
- Real-time health monitoring
- Recent activity feed

### 3. System Status
- Service health checks
- Performance metrics
- Latency monitoring

## API Endpoints

### Chat
**POST** `/api/chat`
- Stream chat responses using Vercel AI SDK
- Input: `{ messages, provider, model }`
- Returns: Server-sent events stream

### System Status
**GET** `/api/system-status/[system]`
- Get status of a specific system (singularity, genesis, centralcloud)
- Returns: System info with status, agents, mode, etc.

### Health Checks
**GET** `/api/health/[service]`
- Health check for services (singularity, genesis, centralcloud, nats, postgresql, rust-nifs)
- Returns: Service status, latency, timestamp

## Running

```bash
# Development
npm run dev
# Visit http://localhost:3000

# Production build
npm run build
npm start

# Run legacy Bun server alongside (for API bridging)
npm run server:dev
```

## Architecture Overview

**Nexus is now the unified web control panel:**
- ✅ Next.js + React (modern web framework)
- ✅ Vercel AI SDK v5 for chat streaming
- ✅ Tailwind CSS for styling
- ✅ TypeScript across frontend and API routes

**What stays the same:**
- NATS messaging layer
- Singularity OTP core
- CentralCloud learning
- AI provider integrations

## Integration Points

### With Singularity
The control panel calls Singularity via HTTP endpoints:
- `http://localhost:4000/health` - Health check
- Future: NATS bridges for system commands

### With Existing llm-server
- Reuses AI provider implementations from `src/providers/`
- Chat API uses existing provider logic
- NATS integration via ElixirBridge

## Environment Variables

Required for AI providers (already set in .env):
- `ANTHROPIC_API_KEY` - Claude
- `GOOGLE_AUTH_TYPE` - Gemini
- `OPENAI_API_KEY` - OpenAI
- `GITHUB_TOKEN` - Copilot

Optional:
- `NEXT_PUBLIC_API_BASE_URL` - API base URL (default: http://localhost:3000)
- `PORT` - Server port (default: 3000)

## Development Notes

1. **AI SDK Integration**: Uses Vercel AI SDK v5 with streaming support
2. **TypeScript**: Full type safety across frontend and API routes
3. **Tailwind CSS**: Dark mode dark theme (gray-950 background)
4. **Custom Hook**: `useChat()` handles message streaming and state
5. **Modular Components**: Dashboard, Chat, SystemStatus are separate components

## Next Steps

1. Implement actual NATS integration for system commands
2. Add real health check endpoints to Singularity
3. Create genesis.ex (experimentation engine)
4. Deprecate Nexus Phoenix app
5. Deploy to Vercel (Next.js native hosting)
