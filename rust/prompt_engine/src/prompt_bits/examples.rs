//! Example prompt bits for common development scenarios
//!
//! These are hand-crafted, high-quality prompt bits that serve as:
//! 1. Built-in knowledge for immediate use
//! 2. Training examples for LLM-generated bits
//! 3. Reference implementations for quality standards

use chrono::Utc;

use super::database::*;

/// Get all built-in example prompt bits
pub fn builtin_prompt_bits() -> Vec<StoredPromptBit> {
  vec![
    // === TYPESCRIPT + PNPM MONOREPO ===
    typescript_pnpm_auth(),
    typescript_pnpm_service(),
    typescript_pnpm_database(),
    typescript_pnpm_message_broker(),
    // === RUST + CARGO WORKSPACE ===
    rust_cargo_service(),
    rust_cargo_cli_tool(),
    rust_cargo_async_task(),
    // === NODE.JS + EXPRESS ===
    nodejs_express_api(),
    nodejs_express_middleware(),
    // === REACT + NEXT.JS ===
    nextjs_api_route(),
    nextjs_page_component(),
    // === DOCKER + KUBERNETES ===
    docker_service(),
    kubernetes_deployment(),
  ]
}

// ============================================================================
// TypeScript + pnpm Monorepo Examples
// ============================================================================

fn typescript_pnpm_auth() -> StoredPromptBit {
  StoredPromptBit {
    id: "ts-pnpm-auth-001".to_string(),
    category: PromptBitCategory::BestPractices,
    trigger: PromptBitTrigger::CodePattern("Authentication".to_string()),
    content: r#"# Add Authentication Service (TypeScript + pnpm Monorepo)

## File Locations
```
packages/services/auth/
├── src/
│   ├── index.ts              # Main exports
│   ├── auth.service.ts       # Core service
│   ├── auth.controller.ts    # HTTP controllers
│   └── middleware/
│       └── verify-token.ts   # JWT verification
├── tests/
│   └── auth.service.test.ts
├── package.json
└── tsconfig.json
```

## Commands to Run
```bash
# Create package structure
mkdir -p packages/services/auth/src/middleware packages/services/auth/tests

# Add dependencies
cd packages/services/auth
pnpm add passport passport-jwt bcrypt jsonwebtoken
pnpm add -D @types/passport @types/passport-jwt @types/bcrypt @types/jsonwebtoken

# Run tests
pnpm --filter @yourorg/auth test
```

## Dependencies to Import
```typescript
import { EventBus } from '@yourorg/foundation';
import { DatabaseService } from '@yourorg/database';
import * as bcrypt from 'bcrypt';
import * as jwt from 'jsonwebtoken';
```

## Naming Conventions
- Package name: `@yourorg/auth` (match your org scope)
- Service class: `AuthenticationService`
- Controller class: `AuthenticationController`
- Events: `user.authenticated`, `user.logout`, `token.refreshed`

## Example Implementation
```typescript
// src/auth.service.ts
import { EventBus } from '@yourorg/foundation';

export class AuthenticationService {
  constructor(
    private readonly eventBus: EventBus,
    private readonly db: DatabaseService,
  ) {}

  async login(email: string, password: string) {
    const user = await this.db.findUserByEmail(email);
    if (!user || !await bcrypt.compare(password, user.passwordHash)) {
      throw new UnauthorizedError('Invalid credentials');
    }

    const token = jwt.sign({ userId: user.id }, process.env.JWT_SECRET);

    await this.eventBus.emit('user.authenticated', { userId: user.id });

    return { token, user };
  }
}
```

## Architecture Notes
- Use EventBus from @yourorg/foundation for all cross-package communication
- Store sensitive config in environment variables, never in code
- Emit events for login/logout for audit logging
- Use bcrypt with salt rounds >= 10 for password hashing
"#
    .to_string(),
    metadata: PromptBitMetadata {
      confidence: 0.95,
      last_updated: Utc::now(),
      versions: vec!["typescript@5".to_string(), "pnpm@9".to_string()],
      related_bits: vec!["ts-pnpm-database-001".to_string()],
    },
    source: PromptBitSource::Builtin,
    created_at: Utc::now(),
    usage_count: 0,
    success_rate: 0.0,
  }
}

fn typescript_pnpm_service() -> StoredPromptBit {
  StoredPromptBit {
    id: "ts-pnpm-service-001".to_string(),
    category: PromptBitCategory::Examples,
    trigger: PromptBitTrigger::CodePattern("AddService".to_string()),
    content: r#"# Add New Service (TypeScript + pnpm Monorepo)

## File Location
```
packages/services/your-service/
├── src/
│   ├── index.ts              # Public API exports
│   ├── your-service.ts       # Main service class
│   └── types.ts              # TypeScript types
├── tests/
│   └── your-service.test.ts
├── package.json
└── tsconfig.json
```

## Commands
```bash
# Create from template or manually
mkdir -p packages/services/your-service/src packages/services/your-service/tests

# Add to package.json
cat > packages/services/your-service/package.json <<EOF
{
  "name": "@yourorg/your-service",
  "version": "0.1.0",
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "scripts": {
    "build": "tsc",
    "test": "vitest"
  },
  "dependencies": {
    "@yourorg/foundation": "workspace:*"
  }
}
EOF

# Install dependencies
pnpm install

# Build
pnpm --filter @yourorg/your-service build
```

## Dependencies
```typescript
import { EventBus } from '@yourorg/foundation';
import { Logger } from '@yourorg/foundation';
```

## Naming
- Package: `@yourorg/your-service` (kebab-case)
- Class: `YourService` (PascalCase)
- Files: `your-service.ts` (kebab-case)

## Warnings
- NEVER import from other services directly - use EventBus
- ALWAYS export types separately for consumers
- Use workspace:* protocol for local dependencies
"#
    .to_string(),
    metadata: PromptBitMetadata { confidence: 0.9, last_updated: Utc::now(), versions: vec!["typescript@5".to_string()], related_bits: vec![] },
    source: PromptBitSource::Builtin,
    created_at: Utc::now(),
    usage_count: 0,
    success_rate: 0.0,
  }
}

fn typescript_pnpm_database() -> StoredPromptBit {
  StoredPromptBit {
    id: "ts-pnpm-database-001".to_string(),
    category: PromptBitCategory::Integration,
    trigger: PromptBitTrigger::Infrastructure("PostgreSQL".to_string()),
    content: r#"# Add PostgreSQL Database (TypeScript + pnpm)

## Dependencies
```bash
pnpm add pg
pnpm add -D @types/pg
```

## Connection Configuration
```typescript
// src/database.service.ts
import { Pool } from 'pg';

export class DatabaseService {
  private pool: Pool;

  constructor() {
    this.pool = new Pool({
      host: process.env.DB_HOST,
      port: parseInt(process.env.DB_PORT || '5432'),
      database: process.env.DB_NAME,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      max: 20,
      idleTimeoutMillis: 30000,
    });
  }

  async query(text: string, params?: any[]) {
    const start = Date.now();
    const res = await this.pool.query(text, params);
    const duration = Date.now() - start;

    // Log slow queries
    if (duration > 1000) {
      console.warn('Slow query detected:', { text, duration });
    }

    return res;
  }
}
```

## Environment Variables
```bash
DB_HOST=localhost
DB_PORT=5432
DB_NAME=your_db
DB_USER=your_user
DB_PASSWORD=your_password
```

## Best Practices
- Use connection pooling (Pool, not Client)
- Set max connections based on load
- Log slow queries (>1s)
- Use parameterized queries to prevent SQL injection
- Close pool on shutdown: `await pool.end()`
"#
    .to_string(),
    metadata: PromptBitMetadata {
      confidence: 0.95,
      last_updated: Utc::now(),
      versions: vec!["pg@8".to_string()],
      related_bits: vec!["ts-pnpm-auth-001".to_string()],
    },
    source: PromptBitSource::Builtin,
    created_at: Utc::now(),
    usage_count: 0,
    success_rate: 0.0,
  }
}

fn typescript_pnpm_message_broker() -> StoredPromptBit {
  StoredPromptBit {
    id: "ts-pnpm-nats-001".to_string(),
    category: PromptBitCategory::Integration,
    trigger: PromptBitTrigger::Infrastructure("NATS".to_string()),
    content: r#"# Add NATS Message Broker (TypeScript + pnpm)

## Dependencies
```bash
pnpm add nats
```

## Connection
```typescript
import { connect, StringCodec } from 'nats';

export class NatsService {
  private nc: NatsConnection;
  private sc = StringCodec();

  async connect() {
    this.nc = await connect({
      servers: process.env.NATS_URL || 'nats://localhost:4222'
    });
  }

  async publish(subject: string, data: any) {
    this.nc.publish(subject, this.sc.encode(JSON.stringify(data)));
  }

  async subscribe(subject: string, handler: (data: any) => Promise<void>) {
    const sub = this.nc.subscribe(subject);
    for await (const msg of sub) {
      const data = JSON.parse(this.sc.decode(msg.data));
      await handler(data);
    }
  }
}
```

## Naming Conventions
- Subjects: `domain.entity.action` (e.g., `user.auth.login`)
- Use dots for hierarchy, not slashes

## Environment
```bash
NATS_URL=nats://localhost:4222
```
"#
    .to_string(),
    metadata: PromptBitMetadata { confidence: 0.9, last_updated: Utc::now(), versions: vec!["nats@2".to_string()], related_bits: vec![] },
    source: PromptBitSource::Builtin,
    created_at: Utc::now(),
    usage_count: 0,
    success_rate: 0.0,
  }
}

// ============================================================================
// Rust + Cargo Workspace Examples
// ============================================================================

fn rust_cargo_service() -> StoredPromptBit {
  StoredPromptBit {
    id: "rust-cargo-service-001".to_string(),
    category: PromptBitCategory::Examples,
    trigger: PromptBitTrigger::Language("Rust".to_string()),
    content: r#"# Add Rust Service (Cargo Workspace)

## File Location
```
crates/your-service/
├── src/
│   ├── lib.rs
│   ├── service.rs
│   └── error.rs
├── tests/
│   └── integration_test.rs
└── Cargo.toml
```

## Commands
```bash
# Create new crate
cargo new --lib crates/your-service

# Add to workspace Cargo.toml
[workspace]
members = ["crates/*"]

# Add dependencies
cd crates/your-service
cargo add tokio --features full
cargo add anyhow
cargo add serde --features derive

# Build
cargo build --package your-service

# Test
cargo test --package your-service
```

## Example Service
```rust
// src/lib.rs
pub mod service;
pub mod error;

pub use service::YourService;
pub use error::ServiceError;

// src/service.rs
use anyhow::Result;

pub struct YourService {
    config: ServiceConfig,
}

impl YourService {
    pub fn new(config: ServiceConfig) -> Self {
        Self { config }
    }

    pub async fn start(&self) -> Result<()> {
        // Implementation
        Ok(())
    }
}
```

## Best Practices
- Use `anyhow::Result` for application code
- Use `thiserror` for library errors
- Prefer `async fn` with tokio runtime
- Use workspace dependencies for consistency
"#
    .to_string(),
    metadata: PromptBitMetadata { confidence: 0.95, last_updated: Utc::now(), versions: vec!["rust@1.75".to_string()], related_bits: vec![] },
    source: PromptBitSource::Builtin,
    created_at: Utc::now(),
    usage_count: 0,
    success_rate: 0.0,
  }
}

fn rust_cargo_cli_tool() -> StoredPromptBit {
  StoredPromptBit {
    id: "rust-cargo-cli-001".to_string(),
    category: PromptBitCategory::Examples,
    trigger: PromptBitTrigger::CodePattern("CLI Tool".to_string()),
    content: r#"# Add Rust CLI Tool (Cargo)

## Dependencies
```bash
cargo add clap --features derive
cargo add anyhow
cargo add tokio --features full
```

## Example Implementation
```rust
// src/main.rs
use clap::{Parser, Subcommand};
use anyhow::Result;

#[derive(Parser)]
#[command(name = "your-tool")]
#[command(about = "Your CLI tool description")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Run the tool
    Run {
        /// Input file
        #[arg(short, long)]
        input: String,
    },
}

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Run { input } => {
            println!("Running with input: {}", input);
            // Implementation
        }
    }

    Ok(())
}
```

## Best Practices
- Use clap's derive API for type safety
- Use anyhow for error handling in main
- Use tokio for async operations
- Add `--version` and `--help` (automatic with clap)
"#
    .to_string(),
    metadata: PromptBitMetadata { confidence: 0.9, last_updated: Utc::now(), versions: vec!["clap@4".to_string()], related_bits: vec![] },
    source: PromptBitSource::Builtin,
    created_at: Utc::now(),
    usage_count: 0,
    success_rate: 0.0,
  }
}

fn rust_cargo_async_task() -> StoredPromptBit {
  StoredPromptBit {
    id: "rust-tokio-async-001".to_string(),
    category: PromptBitCategory::Examples,
    trigger: PromptBitTrigger::CodePattern("Async Task".to_string()),
    content: r#"# Rust Async Task CodePattern (Tokio)

## Dependencies
```bash
cargo add tokio --features full
cargo add futures
```

## Example CodePattern
```rust
use tokio::task;
use std::time::Duration;

#[tokio::main]
async fn main() {
    // Spawn background task
    let handle = task::spawn(async {
        loop {
            println!("Background task running");
            tokio::time::sleep(Duration::from_secs(1)).await;
        }
    });

    // Do other work
    tokio::time::sleep(Duration::from_secs(5)).await;

    // Cancel background task
    handle.abort();
}
```

## CodePatterns
- Use `tokio::spawn` for concurrent tasks
- Use `tokio::select!` for racing futures
- Use `tokio::join!` for parallel futures
- Use channels for communication: `tokio::sync::mpsc`

## Common Pitfalls
- Don't use std::thread::sleep in async code (blocks executor)
- Use tokio::time::sleep instead
- Don't hold locks across await points
- Use tokio::sync::Mutex instead of std::sync::Mutex
"#
    .to_string(),
    metadata: PromptBitMetadata {
      confidence: 0.95,
      last_updated: Utc::now(),
      versions: vec!["tokio@1".to_string()],
      related_bits: vec!["rust-cargo-service-001".to_string()],
    },
    source: PromptBitSource::Builtin,
    created_at: Utc::now(),
    usage_count: 0,
    success_rate: 0.0,
  }
}

// ============================================================================
// Node.js + Express Examples
// ============================================================================

fn nodejs_express_api() -> StoredPromptBit {
  StoredPromptBit {
    id: "nodejs-express-api-001".to_string(),
    category: PromptBitCategory::Examples,
    trigger: PromptBitTrigger::Framework("Express".to_string()),
    content: r#"# Express.js API Route (Node.js)

## Dependencies
```bash
npm install express
npm install --save-dev @types/express
```

## Example Route
```typescript
import express from 'express';

const router = express.Router();

// GET /api/users
router.get('/users', async (req, res) => {
  try {
    const users = await userService.findAll();
    res.json(users);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// POST /api/users
router.post('/users', async (req, res) => {
  try {
    const user = await userService.create(req.body);
    res.status(201).json(user);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

export default router;
```

## Best Practices
- Use async/await for all async operations
- Always wrap route handlers in try/catch
- Return appropriate status codes (200, 201, 400, 404, 500)
- Validate input with middleware (e.g., express-validator)
"#
    .to_string(),
    metadata: PromptBitMetadata { confidence: 0.9, last_updated: Utc::now(), versions: vec!["express@4".to_string()], related_bits: vec![] },
    source: PromptBitSource::Builtin,
    created_at: Utc::now(),
    usage_count: 0,
    success_rate: 0.0,
  }
}

fn nodejs_express_middleware() -> StoredPromptBit {
  StoredPromptBit {
    id: "nodejs-express-middleware-001".to_string(),
    category: PromptBitCategory::Examples,
    trigger: PromptBitTrigger::CodePattern("Middleware".to_string()),
    content: r#"# Express.js Middleware CodePattern

## Example Middleware
```typescript
import { Request, Response, NextFunction } from 'express';

// Logging middleware
export function loggingMiddleware(req: Request, res: Response, next: NextFunction) {
  const start = Date.now();

  res.on('finish', () => {
    const duration = Date.now() - start;
    console.log(`${req.method} ${req.path} ${res.statusCode} ${duration}ms`);
  });

  next();
}

// Authentication middleware
export function authMiddleware(req: Request, res: Response, next: NextFunction) {
  const token = req.headers.authorization?.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'No token provided' });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded;
    next();
  } catch (error) {
    res.status(401).json({ error: 'Invalid token' });
  }
}
```

## Usage
```typescript
app.use(loggingMiddleware);
app.use('/api/protected', authMiddleware);
```

## Best Practices
- Always call next() or send a response
- Place error-handling middleware last
- Use next(error) to pass errors to error handlers
"#
    .to_string(),
    metadata: PromptBitMetadata {
      confidence: 0.9,
      last_updated: Utc::now(),
      versions: vec!["express@4".to_string()],
      related_bits: vec!["nodejs-express-api-001".to_string()],
    },
    source: PromptBitSource::Builtin,
    created_at: Utc::now(),
    usage_count: 0,
    success_rate: 0.0,
  }
}

// ============================================================================
// Next.js Examples
// ============================================================================

fn nextjs_api_route() -> StoredPromptBit {
  StoredPromptBit {
    id: "nextjs-api-route-001".to_string(),
    category: PromptBitCategory::Examples,
    trigger: PromptBitTrigger::Framework("Next.js".to_string()),
    content: r#"# Next.js API Route (App Router)

## File Location
```
app/api/users/route.ts
```

## Example Implementation
```typescript
import { NextRequest, NextResponse } from 'next/server';

export async function GET(request: NextRequest) {
  try {
    const users = await prisma.user.findMany();
    return NextResponse.json(users);
  } catch (error) {
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const user = await prisma.user.create({ data: body });
    return NextResponse.json(user, { status: 201 });
  } catch (error) {
    return NextResponse.json(
      { error: 'Bad request' },
      { status: 400 }
    );
  }
}
```

## Best Practices
- Use App Router (app/) not Pages Router (pages/)
- Export GET, POST, PUT, DELETE, PATCH as named exports
- Use NextResponse.json() for responses
- Handle errors with appropriate status codes
"#
    .to_string(),
    metadata: PromptBitMetadata { confidence: 0.95, last_updated: Utc::now(), versions: vec!["next@14".to_string()], related_bits: vec![] },
    source: PromptBitSource::Builtin,
    created_at: Utc::now(),
    usage_count: 0,
    success_rate: 0.0,
  }
}

fn nextjs_page_component() -> StoredPromptBit {
  StoredPromptBit {
    id: "nextjs-page-001".to_string(),
    category: PromptBitCategory::Examples,
    trigger: PromptBitTrigger::CodePattern("Next.js Page".to_string()),
    content: r#"# Next.js Page Component (App Router)

## File Location
```
app/users/page.tsx
```

## Example Implementation
```typescript
// Server Component (default)
export default async function UsersPage() {
  const users = await fetch('http://localhost:3000/api/users').then(r => r.json());

  return (
    <div>
      <h1>Users</h1>
      <ul>
        {users.map(user => (
          <li key={user.id}>{user.name}</li>
        ))}
      </ul>
    </div>
  );
}
```

## Client Component Example
```typescript
'use client';

import { useState, useEffect } from 'react';

export default function UsersPage() {
  const [users, setUsers] = useState([]);

  useEffect(() => {
    fetch('/api/users')
      .then(r => r.json())
      .then(setUsers);
  }, []);

  return <div>{/* ... */}</div>;
}
```

## Best Practices
- Default to Server Components (no 'use client')
- Only use 'use client' when you need interactivity
- Fetch data in Server Components (faster, no client bundle)
- Use loading.tsx for loading states
- Use error.tsx for error boundaries
"#
    .to_string(),
    metadata: PromptBitMetadata {
      confidence: 0.95,
      last_updated: Utc::now(),
      versions: vec!["next@14".to_string(), "react@18".to_string()],
      related_bits: vec!["nextjs-api-route-001".to_string()],
    },
    source: PromptBitSource::Builtin,
    created_at: Utc::now(),
    usage_count: 0,
    success_rate: 0.0,
  }
}

// ============================================================================
// Docker + Kubernetes Examples
// ============================================================================

fn docker_service() -> StoredPromptBit {
  StoredPromptBit {
    id: "docker-service-001".to_string(),
    category: PromptBitCategory::Deployment,
    trigger: PromptBitTrigger::Infrastructure("Docker".to_string()),
    content: r#"# Dockerfile for Node.js Service

## File: Dockerfile
```dockerfile
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files
COPY package.json pnpm-lock.yaml ./
RUN npm install -g pnpm && pnpm install --frozen-lockfile

# Copy source
COPY . .
RUN pnpm build

# Production image
FROM node:20-alpine

WORKDIR /app

# Copy built files
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY package.json ./

# Run as non-root
USER node

EXPOSE 3000
CMD ["node", "dist/index.js"]
```

## Build & Run
```bash
docker build -t your-service:latest .
docker run -p 3000:3000 your-service:latest
```

## Best Practices
- Use multi-stage builds to reduce image size
- Use alpine for smaller images
- Run as non-root user
- Copy only what's needed
- Use .dockerignore to exclude files
"#
    .to_string(),
    metadata: PromptBitMetadata {
      confidence: 0.95,
      last_updated: Utc::now(),
      versions: vec!["docker@24".to_string()],
      related_bits: vec!["kubernetes-deployment-001".to_string()],
    },
    source: PromptBitSource::Builtin,
    created_at: Utc::now(),
    usage_count: 0,
    success_rate: 0.0,
  }
}

fn kubernetes_deployment() -> StoredPromptBit {
  StoredPromptBit {
    id: "kubernetes-deployment-001".to_string(),
    category: PromptBitCategory::Deployment,
    trigger: PromptBitTrigger::Infrastructure("Kubernetes".to_string()),
    content: r#"# Kubernetes Deployment for Service

## File: k8s/deployment.yaml
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: your-service
  labels:
    app: your-service
spec:
  replicas: 3
  selector:
    matchLabels:
      app: your-service
  template:
    metadata:
      labels:
        app: your-service
    spec:
      containers:
      - name: your-service
        image: your-service:latest
        ports:
        - containerPort: 3000
        env:
        - name: NODE_ENV
          value: "production"
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: your-service
spec:
  selector:
    app: your-service
  ports:
  - port: 80
    targetPort: 3000
  type: ClusterIP
```

## Apply
```bash
kubectl apply -f k8s/deployment.yaml
kubectl get pods
kubectl logs -f deployment/your-service
```

## Best Practices
- Set resource requests and limits
- Add liveness and readiness probes
- Use ConfigMaps for configuration
- Use Secrets for sensitive data
- Set replica count based on load
"#
    .to_string(),
    metadata: PromptBitMetadata {
      confidence: 0.9,
      last_updated: Utc::now(),
      versions: vec!["kubernetes@1.28".to_string()],
      related_bits: vec!["docker-service-001".to_string()],
    },
    source: PromptBitSource::Builtin,
    created_at: Utc::now(),
    usage_count: 0,
    success_rate: 0.0,
  }
}
