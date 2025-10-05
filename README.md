# Singularity

> **LLM-Driven Autonomous Development Platform with GPU-Accelerated Semantic Code Search**

Singularity is a distributed, polyglot platform where **LLMs are the primary developers**. It combines Elixir, Gleam, and Rust to provide intelligent code analysis, AI agent orchestration, and semantic search capabilities. Built on BEAM's fault-tolerant architecture with NATS messaging and PostgreSQL vector storage, Singularity enables LLMs to autonomously develop, analyze, and improve code.

## 🌟 Key Features

- **LLM-First Development**: All development tasks performed by AI agents (Claude, Gemini, GPT-4, etc.)
- **Multi-Language Support**: Parse and analyze 30+ programming languages via Tree-sitter
- **Semantic Code Search**: GPU-accelerated embeddings with pgvector for intelligent code discovery
- **AI Agent Orchestration**: Autonomous agents with access to 67+ development tools
- **Distributed Architecture**: BEAM clustering with NATS messaging for scalability
- **Multiple AI Providers**: Unified interface for Claude, Gemini, OpenAI, GitHub Copilot, and Cursor
- **Real-time Code Analysis**: Pattern extraction, duplication detection, and architecture analysis
- **Template System**: Technology-specific templates for consistent code generation
- **Jules Integration**: Specialized AI agent for complex development tasks

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                   Client Applications                    │
└────────────────┬────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────┐
│                   NATS Message Bus                       │
│  Subjects: ai.*, code.*, agents.*, execution.*          │
└────────┬──────────────────┬──────────────┬─────────────┘
         │                  │              │
┌────────▼────────┐ ┌───────▼──────┐ ┌────▼─────────────┐
│  Elixir/BEAM    │ │   AI Server  │ │  Rust Services   │
│  - Orchestrator │ │  (TypeScript)│ │  - Parsers       │
│  - Agents       │ │  - Claude    │ │  - Analyzers     │
│  - Semantic     │ │  - Gemini    │ │  - DB Service    │
│    Search       │ │  - OpenAI    │ │  - Linting       │
│  - Templates    │ │  - Copilot   │ │                  │
│  - HybridAgent  │ │  - Cursor    │ │                  │
│                 │ │  - Jules     │ │                  │
└────────┬────────┘ └──────────────┘ └──────┬───────────┘
         │                                   │
┌────────▼───────────────────────────────────▼───────────┐
│              PostgreSQL 17 with Extensions              │
│  - pgvector (embeddings)                                │
│  - TimescaleDB (time-series)                            │
│  - PostGIS (spatial data)                               │
└─────────────────────────────────────────────────────────┘
```

## 🤖 LLM Development Philosophy

Singularity is designed for **LLM-first development** where AI agents are the primary developers:

- **Autonomous Coding**: LLMs write, review, and refactor code without human intervention
- **Self-Improvement**: Agents can modify their own code and improve their capabilities
- **Tool Integration**: Direct access to 67+ development tools via MCP protocol
- **Semantic Understanding**: Code is stored with embeddings for semantic reasoning
- **Template Evolution**: LLMs learn and create new templates from analyzed codebases

### Current Status (After Recent Updates)

- ✅ **NATS Orchestrator**: Enhanced with semantic caching and HybridAgent integration
- ✅ **Multiple AI Models**: Support for latest models including GPT-5, o1, o3, Grok
- ✅ **Jules Integration**: Specialized agent for complex development tasks
- ⚠️ **NatsOrchestrator**: Temporarily disabled in application.ex pending HybridAgent API updates
- ✅ **Nix Flake**: Updated with NATS server, container tools, and multiple dev shells

## 📦 Codebase Structure

```
singularity/
├── singularity_app/          # Main Elixir/Phoenix application
│   ├── lib/
│   │   ├── singularity/     # Core modules
│   │   │   ├── application.ex        # OTP application supervisor
│   │   │   ├── nats_orchestrator.ex  # NATS messaging handler
│   │   │   ├── agents/              # Autonomous agent system
│   │   │   ├── llm/                 # LLM provider integrations
│   │   │   ├── semantic_code_search.ex # Vector search
│   │   │   └── patterns/            # Pattern extraction
│   │   └── mix/tasks/       # Custom Mix tasks
│   ├── gleam/              # Gleam modules
│   │   └── src/
│   │       ├── singularity/ # Type-safe rule engine
│   │       └── seed/        # Agent improvement logic
│   └── mix.exs             # Project configuration
│
├── rust/                    # High-performance Rust components
│   ├── universal_parser/    # Tree-sitter based parser
│   ├── analysis_suite/      # Code analysis tools
│   ├── db_service/         # Database service
│   └── linting_engine/     # Custom linting rules
│
├── ai-server/              # TypeScript AI provider server
│   ├── src/
│   │   ├── providers/      # AI provider implementations
│   │   └── server.ts       # Main server
│   └── package.json
│
├── flake.nix              # Nix development environment
├── start-all.sh           # System startup script
└── stop-all.sh            # System shutdown script
```

## 🚀 Quick Start

### Prerequisites

- Nix package manager with flakes enabled
- PostgreSQL 17+
- CUDA-capable GPU (optional, for accelerated embeddings)

### Installation

1. **Clone and enter the repository**:
```bash
git clone https://github.com/yourusername/singularity.git
cd singularity
```

2. **Enter the Nix development shell**:
```bash
nix develop
# Or with direnv:
direnv allow
```

3. **Set up the database**:
```bash
createdb singularity_dev
cd singularity_app
mix ecto.create
mix ecto.migrate
```

4. **Install dependencies**:
```bash
# Elixir dependencies
cd singularity_app
mix setup  # Runs mix deps.get && mix gleam.deps.get

# AI Server dependencies
cd ../ai-server
bun install
```

5. **Configure environment variables**:
```bash
# Copy example env file
cp .env.example .env

# Add your API keys:
# ANTHROPIC_API_KEY=your-key
# OPENAI_API_KEY=your-key
# GOOGLE_AI_STUDIO_API_KEY=your-key
```

6. **Start all services**:
```bash
./start-all.sh
```

The system will start:
- NATS server on port 4222
- Elixir application on port 4000
- AI server on port 3000
- Rust DB service

## 💻 Development

### Running Tests

```bash
cd singularity_app
mix test                    # Run all tests
mix test.ci                 # Run with coverage
mix coverage                # Generate HTML report
```

### Code Quality

```bash
cd singularity_app
mix quality  # Runs format, credo, dialyzer, sobelow, deps.audit
```

### Building for Production

```bash
# Using Nix
nix build .#singularity-integrated

# Using Mix
cd singularity_app
MIX_ENV=prod mix release
```

## 🔧 Importing Code into Singularity (For LLM Analysis)

### 1. Import a New Codebase for LLM Development

```elixir
# LLMs import and analyze external codebases
iex> Singularity.CodebaseRegistry.import_project("/path/to/project", "my_project")

# Via Mix task (typically called by AI agents)
mix singularity.import /path/to/project --name my_project
```

### 2. Generate Embeddings for Semantic Search

```elixir
# Process all files in the imported project
iex> Singularity.SemanticCodeSearch.index_project("my_project")

# Or selectively index specific languages
iex> Singularity.SemanticCodeSearch.index_project("my_project", languages: ["rust", "elixir"])
```

### 3. Extract Patterns and Templates

```elixir
# Extract reusable patterns
iex> Singularity.CodePatternExtractor.extract_from_project("my_project")

# Learn framework patterns
iex> Singularity.FrameworkPatternStore.learn_from_project("my_project")
```

### 4. Analyze Architecture

```elixir
# Generate architecture report
iex> Singularity.ArchitectureAnalyzer.analyze_project("my_project")
```

## 🧠 How LLMs Interact with Singularity

### Autonomous Development Workflow

1. **Task Reception**: LLM receives development task via NATS (`execution.request`)
2. **Semantic Cache Check**: System checks if similar task was already completed
3. **Template Selection**: TemplateOptimizer selects optimal code template
4. **Code Generation**: HybridAgent generates code using selected AI model
5. **Quality Assurance**: Generated code passes through quality checks
6. **Learning**: System extracts patterns for future use

### LLM Agent Capabilities

```elixir
# LLMs can spawn specialized agents
{:ok, agent} = Singularity.Agents.HybridAgent.start_link(
  id: "code_architect_001",
  specialization: :architecture
)

# Agents have access to all development tools
HybridAgent.process_task(agent, %{
  prompt: "Refactor the authentication system for better security",
  tools: ["rust_analyzer", "cargo_audit", "sobelow"],
  context: %{project: "my_app"}
})
```

## 📡 NATS Message Patterns

### AI Provider Requests
```json
// Subject: ai.provider.claude
{
  "model": "claude-3-opus",
  "messages": [{"role": "user", "content": "Hello"}],
  "temperature": 0.7
}
```

### Code Analysis
```json
// Subject: code.analysis.parse
{
  "file_path": "/src/main.rs",
  "language": "rust"
}
```

### Agent Orchestration
```json
// Subject: agents.spawn
{
  "role": "code_reviewer",
  "task": "Review PR #123",
  "tools": ["rust_analyzer", "cargo_clippy"]
}
```

## 🛠️ Available Mix Tasks

```bash
# Code analysis
mix analyze.rust         # Analyze Rust codebase
mix analyze.query        # Query analysis results

# Gleam integration
mix gleam.deps.get      # Fetch Gleam dependencies
mix compile.gleam       # Compile Gleam modules

# Registry management
mix registry.sync       # Sync MCP tool registry
mix registry.report     # Generate registry report

# Quality checks
mix quality             # Run all quality checks
```

## 🌐 API Endpoints

### Health Check
```bash
curl http://localhost:4000/health
```

### Semantic Search
```bash
curl -X POST http://localhost:4000/api/search \
  -H "Content-Type: application/json" \
  -d '{"query": "authentication middleware", "limit": 10}'
```

### Code Analysis
```bash
curl -X POST http://localhost:4000/api/analyze \
  -H "Content-Type: application/json" \
  -d '{"file_path": "/src/main.rs", "analysis_type": "complexity"}'
```

## 🐳 Docker Deployment

```bash
# Build Docker image
docker build -t singularity:latest .

# Run with Docker Compose
docker-compose up -d
```

## ☁️ Cloud Deployment (Fly.io)

```bash
# Deploy to Fly.io
flyctl deploy --app singularity --config fly-integrated.toml

# View logs
flyctl logs --app singularity

# Scale instances
flyctl scale count 3 --app singularity
```

## 🔐 Security

- Credentials are encrypted using `age` encryption
- API keys stored in environment variables
- PostgreSQL connections use SSL in production
- NATS supports TLS for secure messaging

## 📊 Performance

- **LLM Response Caching**: <10ms for cached semantic queries
- **Embedding Generation**: ~1000 files/minute with GPU acceleration
- **Semantic Search**: <50ms for vector similarity search
- **Code Parsing**: 10,000+ lines/second with Tree-sitter
- **NATS Throughput**: 1M+ messages/second capability
- **Concurrent Agents**: 100+ simultaneous LLM agents supported
- **Model Selection**: Automatic cost/performance optimization across 15+ models

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📚 Documentation

- [Quick Start Guide](QUICKSTART.md)
- [Agent System](AGENTS.md)
- [NATS Integration](NATS_SUBJECTS.md)
- [Deployment Guide](DEPLOYMENT_GUIDE.md)
- [Claude Code Guide](CLAUDE.md)

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- Built with Elixir, Gleam, and Rust
- Powered by BEAM VM for fault-tolerance
- Uses Tree-sitter for universal parsing
- PostgreSQL with pgvector for embeddings
- NATS for distributed messaging