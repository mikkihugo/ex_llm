# Singularity Code Quality API
# REST API for code analysis service

## Authentication
All requests require Bearer token authentication:
```
Authorization: Bearer <your-api-key>
```

## Endpoints

### POST /analyze
Analyze a codebase and return quality metrics.

**Request:**
```json
{
  "repository_id": "owner/repo",
  "commit_sha": "abc123...",
  "branch": "main",
  "analysis_config": {
    "include_patterns": ["*.rs", "*.ex", "*.js"],
    "exclude_patterns": ["target/", "node_modules/"],
    "enable_intelligence": true,
    "anonymize_data": true
  }
}
```

**Response:**
```json
{
  "analysis_id": "analysis_123",
  "quality_score": 8.5,
  "issues_count": 12,
  "recommendations": [
    {
      "type": "security",
      "severity": "high",
      "message": "Consider using prepared statements for SQL queries",
      "file": "src/database.rs",
      "line": 45
    }
  ],
  "metrics": {
    "complexity": 3.2,
    "maintainability": 7.8,
    "test_coverage": 0.85,
    "patterns_detected": ["microservice", "rust", "postgresql"]
  },
  "intelligence_collected": true
}
```

### GET /analysis/{analysis_id}
Get detailed analysis results.

### GET /repos/{repo_id}/history
Get analysis history for a repository.

### POST /feedback
Submit feedback on analysis results (helps improve the AI).

**Request:**
```json
{
  "analysis_id": "analysis_123",
  "rating": 4,
  "comments": "Good analysis, but missed some edge cases",
  "useful_recommendations": ["rec_1", "rec_3"]
}
```

## Intelligence Collection (Opt-in)

When `enable_intelligence: true`, we collect anonymized data to improve our AI:

- **Pattern Usage**: Framework/library usage patterns
- **Code Quality Trends**: Industry-wide quality metrics
- **Architecture Patterns**: Common architectural decisions
- **Technology Adoption**: Language/framework popularity

**Data is always anonymized:**
- Repository names → hashed IDs
- Code snippets → structural patterns only
- No sensitive business logic exposed

## Pricing Tiers

### Free Tier
- 100 analyses/month
- Basic quality metrics
- Community support

### Developer ($9/month)
- Unlimited analyses
- Advanced metrics + recommendations
- Priority support
- Custom rule configuration

### Team ($29/month)
- Everything in Developer
- Team analytics dashboard
- Integration with project management tools
- SLA guarantees

### Enterprise (Custom)
- On-premise deployment
- Custom AI training
- White-label options
- Dedicated support

## Example Usage

```bash
# CLI usage
singularity-scan --repo myorg/myrepo --api-key $API_KEY

# Docker usage
docker run -v $(pwd):/code singularity/scanner analyze /code

# GitHub Actions
- uses: singularity/scan-action@v1
  with:
    api-key: ${{ secrets.SINGULARITY_API_KEY }}
```