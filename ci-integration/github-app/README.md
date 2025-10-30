# Singularity GitHub App
# Automated code quality analysis for GitHub repositories

## Overview
The Singularity GitHub App automatically analyzes code quality on every push and pull request, providing AI-powered insights directly in your GitHub workflow.

## Features
- 🤖 **Automatic Analysis**: Runs on every push and PR
- 📊 **Quality Scores**: Comprehensive code quality metrics
- 💡 **AI Recommendations**: Intelligent suggestions for improvement
- 🔍 **Pattern Detection**: Framework and architecture insights
- 📈 **Trend Analysis**: Code quality trends over time
- 🎯 **Check Runs**: GitHub status checks with pass/fail thresholds

## Installation
1. Visit the [GitHub Marketplace](https://github.com/marketplace/singularity)
2. Click "Install"
3. Select repositories to analyze
4. Configure settings (optional)

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

## Permissions Required
- **Read access** to code, metadata, pull requests, commits
- **Write access** to checks, pull request comments, statuses
- **No access** to private keys, secrets, or billing info

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
```

## Deployment
- **Docker**: Containerized deployment
- **Kubernetes**: Scalable orchestration
- **AWS/GCP**: Cloud hosting with auto-scaling

## Marketplace Listing
- **Name**: Singularity Code Quality
- **Description**: AI-powered code analysis for modern development teams
- **Categories**: Code Quality, Code Review, Developer Tools
- **Pricing**: Freemium with usage-based tiers