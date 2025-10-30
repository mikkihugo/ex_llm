# Singularity Code Quality Action

A GitHub Action for automated code quality analysis using the Singularity analysis engine.

## Features

- 🚀 **Fast Analysis**: Sub-second analysis using Rust-based engines
- 📊 **Comprehensive Metrics**: Code quality scores, security findings, architecture insights
- 🧠 **Intelligence Collection**: Optional anonymized pattern learning (opt-in)
- 🎯 **Flexible Configuration**: Customizable severity levels and exclusions
- 📋 **Multiple Formats**: Text, JSON, and GitHub-optimized output
- 🔧 **Self-Hosted**: Run on your own infrastructure

## Usage

### Basic Usage

```yaml
name: Code Quality
on: [push, pull_request]

jobs:
  analyze:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Analyze code quality
        uses: singularity-incubation/code-quality-action@v1
```

### Advanced Configuration

```yaml
name: Code Quality Analysis
on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  quality-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run Singularity Analysis
        uses: singularity-incubation/code-quality-action@v1
        id: analysis
        with:
          api-key: ${{ secrets.SINGULARITY_API_KEY }}
          enable-intelligence: true
          fail-on-quality-threshold: 7.5
          format: github
          exclude-patterns: '**/test/**,**/migrations/**,**/*.md'
          severity-threshold: medium
          working-directory: '.'

      - name: Comment PR with results
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: '## 🔍 Code Quality Analysis\n\n${{ steps.analysis.outputs.results }}'
            })
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `api-key` | Singularity API key for intelligence collection | No | - |
| `enable-intelligence` | Enable anonymized intelligence collection | No | `true` |
| `fail-on-quality-threshold` | Fail if quality score below threshold (0-10) | No | - |
| `format` | Output format: `text`, `json`, `github` | No | `github` |
| `exclude-patterns` | Comma-separated glob patterns to exclude | No | - |
| `severity-threshold` | Minimum severity: `low`, `medium`, `high`, `critical` | No | `low` |
| `working-directory` | Directory to analyze (relative to repo root) | No | `.` |

## Outputs

| Output | Description |
|--------|-------------|
| `results` | Analysis results in the specified format |
| `quality-score` | Overall quality score (0-10) |
| `issues-count` | Number of issues found |
| `passed` | Whether analysis passed threshold checks |

## Examples

### CI/CD Pipeline with Quality Gates

```yaml
name: Quality Assurance
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm test

  quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Code Quality Check
        uses: singularity-incubation/code-quality-action@v1
        with:
          fail-on-quality-threshold: 8.0
          severity-threshold: medium

  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Security Analysis
        uses: singularity-incubation/code-quality-action@v1
        with:
          severity-threshold: high
          format: json
```

### Monorepo Analysis

```yaml
name: Monorepo Analysis
on: [push, pull_request]

jobs:
  analyze:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        package: [api, web, mobile]
    steps:
      - uses: actions/checkout@v4
      - name: Analyze ${{ matrix.package }}
        uses: singularity-incubation/code-quality-action@v1
        with:
          working-directory: packages/${{ matrix.package }}
          exclude-patterns: '**/node_modules/**,**/dist/**'
```

### Intelligence Collection

```yaml
name: Analysis with Intelligence
on:
  push:
    branches: [main]

jobs:
  analyze:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Contribute to Singularity Intelligence
        uses: singularity-incubation/code-quality-action@v1
        with:
          api-key: ${{ secrets.SINGULARITY_API_KEY }}
          enable-intelligence: true
```

## Self-Hosted Runners

For enhanced security or custom infrastructure:

```yaml
jobs:
  analyze:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v4
      - name: Run on self-hosted runner
        uses: singularity-incubation/code-quality-action@v1
        with:
          enable-intelligence: false  # Disable for air-gapped environments
```

## Integration with Singularity Ecosystem

This GitHub Action is part of the broader Singularity ecosystem:

- **Shared Analysis Engine**: Uses the same Rust-based analysis as CLI and GitHub App
- **Intelligence Network**: Contributes to improving analysis quality for all users
- **Unified Configuration**: Same settings work across all Singularity tools
- **Business Model**: Supports freemium model with optional intelligence collection

## Comparison with GitHub App

| Feature | GitHub Action | GitHub App |
|---------|---------------|------------|
| **Setup** | Add to workflow | Install from Marketplace |
| **Execution** | CI/CD pipeline | Automatic on events |
| **Infrastructure** | Your runners | Singularity-hosted |
| **Intelligence** | Opt-in per workflow | Automatic (opt-in globally) |
| **Customization** | Full control | Limited configuration |
| **Cost** | CI minutes | Subscription-based |

## Troubleshooting

### Common Issues

**Analysis fails with "binary not found"**
```bash
# The action should handle this automatically, but if not:
- name: Debug
  run: which singularity-scanner || echo "Binary missing"
```

**Permission denied on self-hosted runners**
```yaml
# Ensure proper permissions
runs-on: self-hosted
permissions:
  contents: read
  pull-requests: write
```

**Large repository timeout**
```yaml
# Exclude unnecessary files
- uses: singularity-incubation/code-quality-action@v1
  with:
    exclude-patterns: '**/node_modules/**,**/vendor/**,**/*.log'
```

## Contributing

This action is part of the Singularity monorepo. To contribute:

1. Make changes to the action files
2. Test locally with `act` or in a workflow
3. Submit a pull request

## License

This action is part of the Singularity project and follows the same licensing terms.