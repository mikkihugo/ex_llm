# SingularityLLM Architecture

This document describes SingularityLLM's layered architecture and namespace organization, designed for clarity, maintainability, and scalability.

## Overview

SingularityLLM follows a **Clean Layered Architecture** pattern that separates concerns into distinct layers with clear dependency rules:

```
┌─────────────────────────────────────────────────────┐
│                    Public API                       │
│                   (lib/singularity_llm.ex)                   │
└─────────────────────────────────────────────────────┘
                           │
┌─────────────────────────────────────────────────────┐
│                  Core Layer                         │
│                (lib/singularity_llm/core/)                   │
│          • Business Logic                           │
│          • Domain Concepts                          │
│          • Pure Functions                           │
└─────────────────────────────────────────────────────┘
                           │
┌─────────────────────────────────────────────────────┐
│              Infrastructure Layer                   │
│            (lib/singularity_llm/infrastructure/)             │
│          • Technical Implementation                 │
│          • Configuration                            │
│          • Caching, Streaming, Telemetry           │
└─────────────────────────────────────────────────────┘
                           │
┌─────────────────────────────────────────────────────┐
│               Providers Layer                       │
│              (lib/singularity_llm/providers/)                │
│          • External Service Integrations           │
│          • API Adapters                            │
│          • Protocol Implementations                │
└─────────────────────────────────────────────────────┘
```

## Namespace Organization

### Core Layer (`lib/singularity_llm/core/`)

The core layer contains pure business logic and domain concepts. These modules represent the core value propositions of SingularityLLM.

```elixir
# Business domain modules
SingularityLLM.Core.Chat             # Primary chat functionality
SingularityLLM.Session               # Conversation state management
SingularityLLM.Context               # Message context management
SingularityLLM.Core.Embeddings       # Text vectorization
SingularityLLM.Core.FunctionCalling  # Tool/function calling
SingularityLLM.Core.StructuredOutputs # Schema validation
SingularityLLM.Core.Vision           # Multimodal support
SingularityLLM.Core.Capabilities     # Model capability queries
SingularityLLM.Core.Models           # Model discovery and management

# Cost tracking (core business value)
SingularityLLM.Core.Cost             # Cost calculation
SingularityLLM.Core.Cost.Display     # Cost formatting
SingularityLLM.Core.Cost.Session     # Session-level cost tracking
```

**Design Principles:**
- No dependencies on infrastructure or providers
- Pure functions where possible
- Domain-driven design
- Business logic only

### Infrastructure Layer (`lib/singularity_llm/infrastructure/`)

The infrastructure layer provides technical services that support the core business logic.

```elixir
# Configuration management
SingularityLLM.Infrastructure.Config.ModelConfig         # Model configuration
SingularityLLM.Infrastructure.Config.ModelCapabilities   # Model capability metadata
SingularityLLM.Infrastructure.Config.ProviderCapabilities # Provider capability metadata

# Technical services
SingularityLLM.Infrastructure.Cache               # Response caching
SingularityLLM.Infrastructure.Logger             # Logging infrastructure
SingularityLLM.Infrastructure.Retry              # Retry logic
SingularityLLM.Infrastructure.Error              # Error handling
SingularityLLM.Infrastructure.ConfigProvider     # Configuration providers

# Advanced infrastructure
SingularityLLM.Infrastructure.Streaming          # Streaming infrastructure
SingularityLLM.Infrastructure.CircuitBreaker     # Circuit breaker patterns
SingularityLLM.Infrastructure.Telemetry          # Observability and metrics
```

**Design Principles:**
- Provides technical services to core layer
- No business logic
- Reusable across different domains
- Infrastructure concerns only

### Providers Layer (`lib/singularity_llm/providers/`)

The providers layer handles all external service integrations and API communication.

```elixir
# Provider implementations
SingularityLLM.Providers.Anthropic     # Claude API integration
SingularityLLM.Providers.OpenAI        # GPT API integration
SingularityLLM.Providers.Gemini        # Google Gemini API
SingularityLLM.Providers.Groq          # Groq API integration
SingularityLLM.Providers.OpenRouter    # OpenRouter API
# ... and 9 more providers

# Shared provider utilities
SingularityLLM.Providers.Shared.HTTPClient           # HTTP communication
SingularityLLM.Providers.Shared.MessageFormatter    # Message formatting
SingularityLLM.Providers.Shared.StreamingCoordinator # Unified streaming
SingularityLLM.Providers.Shared.ErrorHandler        # Provider error handling
```

**Design Principles:**
- External service communication only
- Implements common adapter interface
- Uses infrastructure services
- No direct business logic

### Testing Layer (`lib/singularity_llm/testing/`)

Specialized testing utilities and infrastructure.

```elixir
SingularityLLM.Testing.Cache         # Test response caching
SingularityLLM.Testing.Helpers       # Test utilities
SingularityLLM.Testing.Interceptor   # Request interception
```

## Dependency Rules

The architecture enforces strict dependency rules to maintain clean separation:

### ✅ **Allowed Dependencies:**

```
Core → Infrastructure → Providers
  ↓         ↓              ↓
Testing ←───┴──────────────┘
```

- **Core** may depend on **Infrastructure**
- **Infrastructure** may depend on **Providers** (for shared utilities)
- **Providers** may depend on **Infrastructure** and **Core**
- **Testing** may depend on any layer

### ❌ **Forbidden Dependencies:**

- **Infrastructure** → **Core** (would create circular dependencies)
- **Core** → **Providers** (would couple business logic to external services)
- **Core** → **Testing** (business logic should not depend on test utilities)

## Module Import Patterns

The new architecture enables clear, intuitive imports:

```elixir
# Business logic imports
alias SingularityLLM.Core.{Chat, Session, Cost, Context}

# Infrastructure imports  
alias SingularityLLM.Infrastructure.{Config, Cache, Logger}
alias SingularityLLM.Infrastructure.Config.{ModelConfig, ProviderCapabilities}

# Provider imports
alias SingularityLLM.Providers.{Anthropic, OpenAI, Gemini}
alias SingularityLLM.Providers.Shared.{HTTPClient, MessageFormatter}

# Testing imports
alias SingularityLLM.Testing.{Helpers, Cache}
```

## Benefits

### 1. **Developer Experience**
- **Intuitive Organization**: Easy to find related functionality
- **Clear Mental Model**: Layers have distinct purposes
- **Reduced Cognitive Load**: Know where to look for specific concerns

### 2. **Maintainability**
- **Separation of Concerns**: Each layer has a single responsibility
- **Loose Coupling**: Changes in one layer don't cascade to others
- **Testability**: Each layer can be tested independently

### 3. **Scalability**
- **Easy Extension**: Add new features in the appropriate layer
- **Team Collaboration**: Teams can work on different layers independently
- **Refactoring**: Layer boundaries make refactoring safer

### 4. **Code Quality**
- **Dependency Direction**: Enforced dependency rules prevent architectural decay
- **Interface Clarity**: Layer boundaries define clear interfaces
- **Single Responsibility**: Each module has a focused purpose

## Migration from Previous Structure

The reorganization moved modules to their logical homes:

```elixir
# Before: Flat organization
SingularityLLM.Cost.* → SingularityLLM.Core.Cost.*           # Cost is core business logic
SingularityLLM.Config.* → SingularityLLM.Infrastructure.Config.* # Config is infrastructure

# Result: Clear layered architecture
Core/          # Business domain
Infrastructure/ # Technical services  
Providers/     # External integrations
Testing/       # Test utilities
```

## Future Architecture Considerations

As SingularityLLM grows, consider these architectural patterns:

### 1. **Domain-Driven Design**
- Group related core modules into subdomains
- Consider bounded contexts for large features

### 2. **Hexagonal Architecture**
- Core as the hexagon center
- Providers as external adapters
- Infrastructure as ports

### 3. **Microkernel Architecture**
- Core as the microkernel
- Providers as plugins
- Infrastructure as shared services

## Conclusion

SingularityLLM's layered architecture provides a solid foundation for growth while maintaining clarity and simplicity. The clear separation of concerns, enforced dependency rules, and intuitive namespace organization make the codebase easier to understand, maintain, and extend.

This architecture positions SingularityLLM to scale from a unified LLM client to a comprehensive AI development platform while maintaining architectural integrity.