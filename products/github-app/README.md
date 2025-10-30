# Singularity GitHub App
# Automated code quality analysis for GitHub repositories

## Overview
The Singularity GitHub App automatically analyzes code quality on every push and pull request, providing AI-powered insights directly in your GitHub workflow.

**Part of the Singularity Monorepo**: This GitHub App is fully integrated with the existing Singularity system, leveraging the same core Rust analysis engines, PostgreSQL workflow orchestration (ex_quantum_flow), and intelligence collection infrastructure used across all Singularity services.

## Integration with Singularity Ecosystem

This GitHub App shares infrastructure with:
- **Core Analysis Engine**: Uses `packages/code_quality_engine/` (Rust NIF)
- **Workflow Orchestration**: Leverages `packages/ex_quantum_flow/` for async processing
- **Intelligence Collection**: Feeds anonymized patterns back to main Singularity system
- **Database**: Shares PostgreSQL instance with main Singularity services
- **Business Logic**: Same analysis modules as CLI and CI/CD integrations

### Architecture Flow
```
GitHub Webhook → GitHub App → ex_quantum_flow Workflows → Rust Analysis Engine → Results → Intelligence Database
                                      ↓
                            Shared with CLI & CI/CD tools
```

## Features
- 🤖 **Automatic Analysis**: Runs on every push and PR
- 📊 **Quality Scores**: Comprehensive code quality metrics
- 💡 **AI Recommendations**: Intelligent suggestions for improvement
- 🔍 **Pattern Detection**: Framework and architecture insights
- 📈 **Trend Analysis**: Code quality trends over time
- 🎯 **Check Runs**: GitHub status checks with pass/fail thresholds

## Installation Options

### Option 1: GitHub App (Recommended)
1. Visit the [GitHub Marketplace](https://github.com/marketplace/singularity)
2. Click "Install"
3. Select repositories to analyze
4. Configure settings (optional)

### Option 2: GitHub Action
For self-hosted or custom workflows, use the Singularity GitHub Action:

```yaml
# .github/workflows/singularity-analysis.yml
name: Code Quality Analysis
on: [push, pull_request]

jobs:
  analyze:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run Singularity Analysis
        uses: singularity-incubation/code-quality-action@v1
        with:
          api-key: ${{ secrets.SINGULARITY_API_KEY }}
          enable-intelligence: true
```

### Option 3: CLI Tool
```bash
# Install CLI
curl -fsSL https://get.singularity.dev | bash

# Run analysis
singularity-scanner analyze --path . --format github
```

## How It Works

### On Pull Requests
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Developer     │    │   GitHub App     │    │   Analysis      │
│   opens PR      │───▶│   receives       │───▶│   Engine runs   │
│                 │    │   webhook        │    │   (Rust)        │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                        │
┌─────────────────┐    ┌──────────────────┐             │
│   AI Analysis   │◀───│   Results        │◀────────────┘
│   Complete      │    │   posted as      │
│                 │    │   PR comment     │
└─────────────────┘    └──────────────────┘
```

### On Pushes
- Creates GitHub Check Runs with quality scores
- Updates repository dashboard with trends
- Collects anonymized intelligence data (opt-in)

## GitHub Action Alternative

For users who prefer running analysis in their own CI/CD pipelines rather than using the GitHub App, we provide a **GitHub Action** that delivers the same analysis capabilities:

### Key Differences

| Aspect | GitHub App | GitHub Action |
|--------|------------|----------------|
| **Execution** | Automatic on GitHub events | Manual in CI workflows |
| **Infrastructure** | Singularity-hosted | Your GitHub runners |
| **Intelligence** | Shared across all users | Per-workflow opt-in |
| **Setup** | One-click install | Add to workflow YAML |
| **Cost** | Subscription-based | GitHub Actions minutes |

### GitHub Action Usage

```yaml
name: Code Quality
on: [push, pull_request]

jobs:
  analyze:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run Singularity Analysis
        uses: singularity-incubation/code-quality-action@v1
        with:
          api-key: ${{ secrets.SINGULARITY_API_KEY }}
          enable-intelligence: true
          fail-on-quality-threshold: 7.5
```

See [`action/README.md`](action/README.md) for complete GitHub Action documentation and [workflow examples](.github/workflows/examples.yml) for common use cases.

## Pricing
- **Free**: 100 analyses/month per repository
- **Pro**: $9/month - Unlimited analyses, advanced metrics
- **Team**: $29/month - Team dashboard, custom rules
- **Enterprise**: Custom - On-premise deployment, white-label

## Architecture

### Components
1. **Webhook Handler** (Elixir/Phoenix) - Receives GitHub events
2. **Analysis Engine** (Rust) - Core code quality analysis
3. **GitHub API Client** - Posts results, creates checks
4. **Database** (PostgreSQL) - Stores results, user data
5. **Web Dashboard** - User-facing analytics

### Data Flow
```
GitHub Webhook → Phoenix App → Queue (pgmq) → Rust Analyzer → Results → GitHub API
```

## Example Usage

### Automatic PR Analysis
```yaml
# No configuration needed! Just install the app
# Analysis runs automatically on PRs
```

### Custom Configuration (Optional)
```yaml
# .singularity.yml in repository root
analysis:
  languages: ["rust", "elixir", "javascript"]
  exclude_patterns: ["target/", "node_modules/"]
  quality_threshold: 7.5
  enable_intelligence: true
```

## API Endpoints

### Webhook Endpoints
- `POST /webhooks/github` - GitHub webhook handler
- `GET /health` - Health check

### User Endpoints
- `GET /repos/{owner}/{repo}/analysis` - Repository analysis history
- `GET /repos/{owner}/{repo}/trends` - Quality trends
- `POST /repos/{owner}/{repo}/config` - Update settings

## Security
- **Webhook Verification**: Validates GitHub webhook signatures
- **OAuth**: Secure GitHub App authentication
- **Data Encryption**: All data encrypted at rest
- **Privacy**: Intelligence data collection is opt-in and anonymized

## Development

### Local Setup
```bash
# Clone and setup
git clone https://github.com/singularity/singularity-github-app
cd singularity-github-app

# Install dependencies
mix deps.get
npm install

# Setup database
mix ecto.setup

# Start development server
mix phx.server
```

### Testing
```bash
# Run tests
mix test

# Test webhook handling
curl -X POST localhost:4000/webhooks/github \
  -H "X-GitHub-Event: pull_request" \
  -d @test/fixtures/pr_webhook.json
```yes

## Deployment
- **Docker**: Containerized deployment
- **Kubernetes**: Scalable orchestration
- **AWS/GCP**: Cloud hosting with auto-scaling

## Marketplace Listing
- **Name**: Singularity Code Quality
- **Description**: AI-powered code analysis for modern development teams
- **Categories**: Code Quality, Code Review, Developer Tools
- **Pricing**: Freemium with usage-based tiers