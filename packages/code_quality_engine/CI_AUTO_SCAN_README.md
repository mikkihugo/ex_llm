# Scanner CI Auto-Run Configuration

## Status: Ready for CI

The scanner is configured to automatically run in GitHub Actions with:
- ✅ All analyzers enabled (Quality, Security, Performance)
- ✅ Auto-fix enabled by default
- ✅ JSON output for artifacts
- ✅ Auto-commits fixes on PRs

## Current Workflow

The `.github/workflows/code-scan.yml` workflow:

1. **Builds the scanner** with all features
2. **Runs analysis** on `nexus/singularity` with:
   - All analyzers (quality, security, performance)
   - Auto-fix enabled (formats code automatically)
   - JSON output saved to `scan-results.json`
3. **Commits fixes** on pull requests (if in PR context)

## What Gets Detected

### Security Analyzer
- Hardcoded secrets (API keys, passwords, tokens)
- SQL injection vulnerabilities
- XSS vulnerabilities (JavaScript/TypeScript)

### Performance Analyzer  
- N+1 query patterns
- Inefficient algorithms
- Multiple unnecessary sorts/filters

### Quality Analyzer
- Code complexity issues
- Maintainability metrics
- Long files/lines
- Documentation gaps

## Auto-Fix Capabilities

The scanner automatically fixes:
- **Rust**: `cargo fmt` formatting
- **Elixir**: `mix format` formatting
- **JavaScript**: `prettier` formatting (if available)
- **Python**: `black` formatting (if available)
- **Go**: `gofmt` formatting (if available)

## Usage in CI

The workflow runs automatically on:
- Push to `main` branch
- Pull requests to `main`
- Manual workflow dispatch

Fixes are automatically committed on PRs with message:
```
chore: auto-format code [skip ci]
```

## Manual Run

To run locally:
```bash
# Build scanner
cargo build --release -p code_quality_engine --features cli

# Run with all analyzers and auto-fix
./target/release/singularity-scanner analyze \
  --path nexus/singularity \
  --format json \
  --output scan-results.json

# Or disable auto-fix
./target/release/singularity-scanner analyze \
  --path nexus/singularity \
  --no-fix
```

## Combining with Other Tools

The scanner can be combined with:
- Formatters (already integrated)
- Linters (via limits in analyzer patterns)
- Security scanners (OSV, Snyk via dependency module - TODO)
- Trend tracking (via trends module - TODO)

All improvements are implemented and ready for CI/CD integration!
