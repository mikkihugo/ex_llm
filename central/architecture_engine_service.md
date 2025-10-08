# Architecture Engine Service - NATS API Specification

## Overview
The Architecture Engine Service manages the meta-registry of all repositories and provides intelligent naming suggestions with violation detection.

## NATS Subjects

### Repository Management
- `architecture.registry.register` - Register new repository
- `architecture.registry.list` - List all registered repositories  
- `architecture.registry.get` - Get specific repository info
- `architecture.registry.update` - Update repository architecture
- `architecture.registry.delete` - Remove repository from registry

### Naming Services
- `architecture.naming.suggest` - Get naming suggestions
- `architecture.naming.validate` - Validate naming convention
- `architecture.naming.best` - Get best naming suggestion

### Violation Detection
- `architecture.violations.check` - Check naming violations
- `architecture.violations.list` - List violations for repository
- `architecture.violations.fixes` - Get suggested fixes
- `architecture.violations.report` - Generate violation report

### Standards Enforcement
- `architecture.standards.enforce` - Enforce standards (sends to planning)
- `architecture.standards.report` - Generate compliance report
- `architecture.standards.get` - Get standards for language/framework

### Architecture Detection
- `architecture.detect.patterns` - Detect architecture patterns
- `architecture.detect.services` - Detect service structure
- `architecture.detect.technology` - Detect technology stack

## Request/Response Formats

### Register Repository
```json
// Request: architecture.registry.register
{
  "repo_id": "singularity",
  "repo_path": "/home/mhugo/code/singularity",
  "architecture": "microservices",
  "metadata": {
    "language": "elixir",
    "framework": "phoenix",
    "database": "postgresql"
  }
}

// Response
{
  "status": "success",
  "repo_id": "singularity",
  "detected_at": "2024-01-15T10:30:00Z",
  "architecture": "microservices"
}
```

### Naming Suggestions
```json
// Request: architecture.naming.suggest
{
  "description": "user authentication service",
  "element_type": "function",
  "language": "elixir",
  "context": {
    "repo_id": "singularity",
    "file_path": "lib/auth/",
    "architecture": "microservices"
  }
}

// Response
{
  "suggestions": [
    "authenticate_user",
    "user_authentication",
    "auth_user"
  ],
  "best_suggestion": "authenticate_user",
  "confidence": 0.95
}
```

### Violation Check
```json
// Request: architecture.violations.check
{
  "repo_id": "singularity",
  "file_paths": ["lib/auth/user_service.ex"],
  "check_types": ["function_naming", "module_naming"]
}

// Response
{
  "violations": [
    {
      "type": "function_naming",
      "name": "getUserData",
      "line": 15,
      "file": "lib/auth/user_service.ex",
      "severity": "warning",
      "message": "Function name 'getUserData' doesn't follow snake_case convention",
      "suggested_fix": "get_user_data"
    }
  ],
  "total_violations": 1,
  "checked_files": 1
}
```

### Architecture Detection
```json
// Request: architecture.detect.patterns
{
  "repo_id": "singularity",
  "repo_path": "/home/mhugo/code/singularity"
}

// Response
{
  "architecture_patterns": [
    "microservices",
    "event_driven",
    "hexagonal"
  ],
  "service_structure": {
    "architecture": "microservices",
    "services": [
      "user-service",
      "auth-service", 
      "payment-service"
    ],
    "messaging": "nats"
  },
  "confidence": 0.92
}
```

## Error Responses
```json
{
  "status": "error",
  "error": "REPOSITORY_NOT_FOUND",
  "message": "Repository 'unknown' not found in registry",
  "timestamp": "2024-01-15T10:30:00Z"
}
```

## Usage Examples

### Register Repository
```elixir
# Register new repository
ArchitectureEngine.register_repository("my-project", "/path/to/project", "monolith")

# Via NATS
NatsClient.publish("architecture.registry.register", %{
  repo_id: "my-project",
  repo_path: "/path/to/project", 
  architecture: "monolith"
})
```

### Check Violations
```elixir
# Check all repositories
violations = ArchitectureEngine.check_all_naming_violations()

# Check specific repository
violations = ArchitectureEngine.check_repository_violations("singularity", "/path/to/singularity")

# Get suggested fixes
fixes = ArchitectureEngine.suggest_violation_fixes("singularity")
```

### Enforce Standards (via NATS to Planning)
```elixir
# Enforce standards - sends violations to planning system
ArchitectureEngine.enforce_standards("singularity", min_severity: "warning")

# Get compliance report
report = ArchitectureEngine.get_standards_compliance_report("singularity")

# Get standards for specific language
standards = ArchitectureEngine.get_standards("elixir", "phoenix")
```

### Get Naming Suggestions
```elixir
# Basic naming
suggestions = ArchitectureEngine.suggest_function_names("calculate total price")

# Architecture-aware naming
suggestions = ArchitectureEngine.suggest_names_with_architecture("user service", "singularity")

# Context-aware naming
suggestions = ArchitectureEngine.suggest_names_with_context("payment handler", "singularity", "lib/payment/")
```

## Database Schema

### technology_detections table
- `id` - Primary key
- `codebase_id` - Repository identifier
- `repo_path` - File system path
- `summary` - JSONB with architecture patterns
- `inserted_at` - Creation timestamp
- `updated_at` - Last update timestamp

### naming_violations table (to be created)
- `id` - Primary key
- `repo_id` - Repository identifier
- `file_path` - File with violation
- `line_number` - Line number
- `violation_type` - Type of violation
- `element_name` - Name that violates convention
- `severity` - Violation severity
- `message` - Human readable message
- `suggested_fix` - Suggested correction
- `detected_at` - When violation was found
- `fixed_at` - When violation was fixed (nullable)

## Integration Points

### With Other Services
- **Code Parser**: Feeds parsed code structure
- **Quality Engine**: Receives violation reports
- **Generation Engine**: Uses naming suggestions
- **Analysis Engine**: Provides architecture context

### With External Tools
- **Git Hooks**: Pre-commit violation checking
- **CI/CD**: Automated violation detection
- **IDE Plugins**: Real-time naming suggestions
- **Code Review**: Violation reports in PRs