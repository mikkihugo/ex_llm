# Singularity GitHub Integration - Updated Architecture

## Overview
The Singularity GitHub integration now supports **three deployment models**:

1. **GitHub App** (SaaS) - Fully managed, automatic analysis
2. **GitHub Action** (Self-hosted) - CI/CD pipeline integration
3. **CLI Tool** (Local) - Development and manual analysis

All three share the same core analysis engine and contribute to the intelligence network.

## Architecture Update

### Shared Components
```
┌─────────────────────────────────────────────────────────────┐
│                    Singularity Core                         │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  packages/code_quality_engine/ (Rust Analysis)     │    │
│  ├─────────────────────────────────────────────────────┤    │
│  │  packages/quantum_flow/ (Workflow Orchestration)      │    │
│  ├─────────────────────────────────────────────────────┤    │
│  │  nexus/singularity/ (Elixir Services)              │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                              │
                    ┌─────────┼─────────┐
                    │         │         │
            ┌───────▼───┐ ┌───▼───┐ ┌───▼────┐
            │ GitHub App│ │GitHub │ │  CLI   │
            │  (SaaS)   │ │Action │ │ (Local)│
            └───────────┘ └───────┘ └────────┘
```

### Integration Points

#### 1. GitHub App (products/github-app/)
- **Webhook Handler**: Receives GitHub events
- **Analysis Orchestrator**: Uses quantum_flow workflows
- **Results Poster**: Comments on PRs, creates check runs
- **Intelligence Collector**: Anonymized data → main system

#### 2. GitHub Action (products/github-app/action/)
- **Docker-based**: Runs CLI tool in container
- **CI/CD Integration**: Workflow-based execution
- **Flexible Configuration**: Per-workflow settings
- **Self-hosted Option**: Run on your infrastructure

#### 3. CLI Tool (packages/code_quality_engine/)
- **Direct Analysis**: Local development usage
- **CI Integration**: Shell script integration
- **API Client**: Intelligence collection
- **Multiple Formats**: Text, JSON, GitHub output

## Deployment Comparison

| Feature | GitHub App | GitHub Action | CLI Tool |
|---------|------------|----------------|----------|
| **Setup** | Marketplace install | Add to workflow | Download binary |
| **Execution** | Automatic | CI/CD pipeline | Manual/Local |
| **Infrastructure** | Singularity-hosted | Your runners | Your machine |
| **Intelligence** | Global sharing | Per-workflow opt-in | Opt-in via API |
| **Customization** | Limited | Full control | Full control |
| **Cost** | Subscription | CI minutes | Free |
| **Use Case** | Teams wanting SaaS | Custom workflows | Development/CI |

## Business Model Integration

### Freemium Tiers
- **Free**: 100 analyses/month (all platforms)
- **Pro**: Unlimited + advanced features
- **Enterprise**: Custom deployment + white-label

### Intelligence Collection
- **Opt-in**: User consent required
- **Anonymized**: Repository hashes, no PII
- **Beneficial**: Improves analysis for all users
- **Multi-channel**: All platforms contribute

## Implementation Status

### ✅ Completed
- GitHub App with webhook handling
- Analysis workflows via quantum_flow
- Docker deployment and scaling
- CLI tool with multiple formats
- GitHub Action implementation
- Documentation and examples

### 🚧 Next Steps
- Publish GitHub Action to marketplace
- Register GitHub App for marketplace
- Add monitoring and alerting
- Implement advanced features (GraphQL API, custom rules)

## Usage Examples

### GitHub App (Automatic)
```yaml
# No configuration needed - just install from marketplace
# Analysis runs automatically on PRs/pushes
```

### GitHub Action (CI/CD)
```yaml
name: Quality Check
on: [push, pull_request]

jobs:
  analyze:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: singularity-incubation/code-quality-action@v1
        with:
          fail-on-quality-threshold: 7.5
```

### CLI (Local/CI)
```bash
# Install
curl -fsSL https://get.singularity.dev | bash

# Analyze
singularity-scanner analyze --path . --format github
```

## Scaling Strategy

### Horizontal Scaling
- **GitHub App**: Kubernetes deployment with auto-scaling
- **GitHub Action**: Scales with your CI/CD infrastructure
- **CLI**: Scales across development teams

### Intelligence Network
```
Analysis Results → Anonymized Patterns → Shared Learning →
Improved Engine → Better Results for All Users
```

This multi-platform approach maximizes adoption while maintaining the core value proposition: **provide developer value through code quality analysis while collecting intelligence to improve the system**. 

The GitHub Action option is particularly powerful for organizations that want full control over their CI/CD pipelines while still benefiting from the advanced analysis capabilities.