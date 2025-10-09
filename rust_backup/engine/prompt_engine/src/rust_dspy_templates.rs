//! DSPy-integrated Rust templates for LLM code generation
//! 
//! These templates are specifically designed for DSPy integration with the prompt-engine
//! and optimized for LLM coders with dynamic context injection.

use super::{PromptTemplate, RegistryTemplate};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// DSPy signature for Rust microservice generation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RustMicroserviceSignature {
    pub name: String,
    pub inputs: HashMap<String, String>,
    pub outputs: HashMap<String, String>,
    pub instruction: String,
}

impl RustMicroserviceSignature {
    pub fn new() -> Self {
        Self {
            name: "rust_microservice_generator".to_string(),
            inputs: HashMap::from([
                ("business_domain".to_string(), "The business domain context (e.g., e-commerce, finance)".to_string()),
                ("entity_name".to_string(), "The entity name in snake_case (e.g., user, product)".to_string()),
                ("security_level".to_string(), "Security requirements (low, medium, high)".to_string()),
                ("performance_profile".to_string(), "Performance characteristics (low-latency, high-throughput)".to_string()),
                ("architecture_pattern".to_string(), "Architecture pattern (microservice, monolith, event-driven)".to_string()),
            ]),
            outputs: HashMap::from([
                ("rust_code".to_string(), "Generated Rust microservice code with annotations".to_string()),
                ("dependencies".to_string(), "Required Cargo dependencies".to_string()),
                ("tests".to_string(), "Generated test code".to_string()),
                ("documentation".to_string(), "Code documentation and comments".to_string()),
            ]),
            instruction: "Generate a complete Rust microservice with business domain annotations, security validation, performance optimization, error handling, logging, and comprehensive tests. The code should be production-ready and optimized for LLM coders.".to_string(),
        }
    }
}

/// DSPy signature for Rust API endpoint generation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RustApiEndpointSignature {
    pub name: String,
    pub inputs: HashMap<String, String>,
    pub outputs: HashMap<String, String>,
    pub instruction: String,
}

impl RustApiEndpointSignature {
    pub fn new() -> Self {
        Self {
            name: "rust_api_endpoint_generator".to_string(),
            inputs: HashMap::from([
                ("entity_name".to_string(), "The entity name in snake_case (e.g., user, product)".to_string()),
                ("api_version".to_string(), "API version (v1, v2, etc.)".to_string()),
                ("endpoint_type".to_string(), "Endpoint type (rest, graphql, grpc)".to_string()),
                ("authentication".to_string(), "Authentication method (jwt, api_key, oauth)".to_string()),
                ("validation_rules".to_string(), "Input validation rules (required, optional, constraints)".to_string()),
            ]),
            outputs: HashMap::from([
                ("rust_code".to_string(), "Generated Rust API endpoint code with Axum".to_string()),
                ("routes".to_string(), "API route definitions".to_string()),
                ("middleware".to_string(), "Authentication and validation middleware".to_string()),
                ("tests".to_string(), "API endpoint tests".to_string()),
            ]),
            instruction: "Generate a complete Rust API endpoint using Axum framework with proper request/response handling, validation, authentication, error handling, and comprehensive tests. The code should be production-ready and optimized for LLM coders.".to_string(),
        }
    }
}

/// DSPy signature for Rust repository pattern generation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RustRepositorySignature {
    pub name: String,
    pub inputs: HashMap<String, String>,
    pub outputs: HashMap<String, String>,
    pub instruction: String,
}

impl RustRepositorySignature {
    pub fn new() -> Self {
        Self {
            name: "rust_repository_generator".to_string(),
            inputs: HashMap::from([
                ("entity_name".to_string(), "The entity name in snake_case (e.g., user, product)".to_string()),
                ("database_type".to_string(), "Database type (postgresql, mysql, sqlite, mongodb)".to_string()),
                ("crud_operations".to_string(), "CRUD operations needed (create, read, update, delete, list)".to_string()),
                ("query_patterns".to_string(), "Query patterns (simple, complex, paginated, filtered)".to_string()),
                ("transaction_support".to_string(), "Transaction support (single, batch, distributed)".to_string()),
            ]),
            outputs: HashMap::from([
                ("rust_code".to_string(), "Generated Rust repository pattern code".to_string()),
                ("trait_definition".to_string(), "Repository trait definition".to_string()),
                ("implementation".to_string(), "Concrete repository implementation".to_string()),
                ("tests".to_string(), "Repository tests with mocking".to_string()),
            ]),
            instruction: "Generate a complete Rust repository pattern with async traits, database abstraction, CRUD operations, error handling, and comprehensive tests. The code should be production-ready and optimized for LLM coders.".to_string(),
        }
    }
}

/// DSPy signature for Rust test generation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RustTestSignature {
    pub name: String,
    pub inputs: HashMap<String, String>,
    pub outputs: HashMap<String, String>,
    pub instruction: String,
}

impl RustTestSignature {
    pub fn new() -> Self {
        Self {
            name: "rust_test_generator".to_string(),
            inputs: HashMap::from([
                ("entity_name".to_string(), "The entity name in snake_case (e.g., user, product)".to_string()),
                ("test_scenarios".to_string(), "Test scenarios (happy_path, error_handling, edge_cases)".to_string()),
                ("test_type".to_string(), "Test type (unit, integration, api, performance)".to_string()),
                ("mocking_required".to_string(), "Mocking requirements (database, external_apis, services)".to_string()),
                ("coverage_target".to_string(), "Coverage target (80%, 90%, 95%)".to_string()),
            ]),
            outputs: HashMap::from([
                ("rust_code".to_string(), "Generated Rust test code".to_string()),
                ("test_cases".to_string(), "Individual test cases".to_string()),
                ("mocks".to_string(), "Mock implementations".to_string()),
                ("fixtures".to_string(), "Test fixtures and data".to_string()),
            ]),
            instruction: "Generate comprehensive Rust tests with proper mocking, error handling, edge cases, and integration tests. The tests should be production-ready and optimized for LLM coders.".to_string(),
        }
    }
}

/// Rust DSPy template generator for LLM coders
pub struct RustDspyTemplateGenerator {
    /// Template registry
    registry: RegistryTemplate,
}

impl RustDspyTemplateGenerator {
    /// Create new Rust DSPy template generator
    pub fn new() -> Self {
        let mut registry = RegistryTemplate::new();

        // Register Rust DSPy templates
        Self::register_rust_dspy_templates(&mut registry);

        Self { registry }
    }

    /// Register Rust DSPy templates
    fn register_rust_dspy_templates(registry: &mut RegistryTemplate) {
        // Rust microservice template
        registry.register(PromptTemplate {
            name: "rust_microservice_dspy".to_string(),
            template: r#"🚀 **RUST MICROSERVICE GENERATION**

Generate a complete Rust microservice with the following specifications:

**Input Context:**
- Business Domain: {business_domain}
- Entity Name: {entity_name}
- Security Level: {security_level}
- Performance Profile: {performance_profile}
- Architecture Pattern: {architecture_pattern}

**Requirements:**
1. **Business Domain Annotations**: Use @business-domain, @business-entity, @business-operation annotations
2. **Architecture Patterns**: Implement {architecture_pattern} with proper separation of concerns
3. **Security Validation**: Include {security_level} security measures with input sanitization
4. **Performance Optimization**: Optimize for {performance_profile} with connection pooling
5. **Error Handling**: Comprehensive error handling with anyhow::Result
6. **Logging**: Structured logging with tracing crate
7. **Tests**: Comprehensive test suite with happy path, error handling, and edge cases

**Output Format:**
```rust
//! @business-domain {business_domain}
//! @architecture-pattern {architecture_pattern}
//! @security-level {security_level}
//! @performance-profile {performance_profile}
//! @dspy-signature rust_microservice_generator
//! @llm-coder-optimized true

use serde::{{Deserialize, Serialize}};
use anyhow::Result;
use tracing::{{info, error, warn}};
use uuid::Uuid;
use chrono::{{DateTime, Utc}};

/// @business-entity {entity_name}
/// @architecture-component {architecture_pattern}
/// @security-pattern authentication
/// @performance-optimization connection-pooling
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct {{EntityName}} {{
    /// @business-field {entity_name}_id
    /// @security-validation input-sanitization
    pub id: String,
    pub name: String,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}}

// ... rest of implementation
```

**DSPy Signature Fields:**
- rust_code: Complete Rust microservice implementation
- dependencies: Required Cargo.toml dependencies
- tests: Comprehensive test suite
- documentation: Code documentation and comments

Generate production-ready Rust code optimized for LLM coders."#
                .to_string(),
            language: "rust".to_string(),
            domain: "rust_microservice_generation".to_string(),
            quality_score: 0.95,
        });

        // Rust API endpoint template
        registry.register(PromptTemplate {
            name: "rust_api_endpoint_dspy".to_string(),
            template: r#"🌐 **RUST API ENDPOINT GENERATION**

Generate a complete Rust API endpoint using Axum framework:

**Input Context:**
- Entity Name: {entity_name}
- API Version: {api_version}
- Endpoint Type: {endpoint_type}
- Authentication: {authentication}
- Validation Rules: {validation_rules}

**Requirements:**
1. **Axum Framework**: Use Axum for HTTP handling and routing
2. **Request/Response DTOs**: Proper serialization with serde
3. **Validation**: Input validation with appropriate error responses
4. **Authentication**: Implement {authentication} authentication
5. **Error Handling**: HTTP status codes and error responses
6. **Tests**: API endpoint tests with request/response validation

**Output Format:**
```rust
//! @business-domain {business_domain}
//! @architecture-pattern api-endpoint
//! @security-level {security_level}
//! @dspy-signature rust_api_endpoint_generator
//! @llm-coder-optimized true

use axum::{{extract::Path, http::StatusCode, response::Json, routing::get, Router}};
use serde::{{Deserialize, Serialize}};
use tracing::{{info, error}};

/// @business-entity {{EntityName}}Response
/// @architecture-pattern response-dto
#[derive(Debug, Serialize)]
pub struct {{EntityName}}Response {{
    pub id: String,
    pub name: String,
    pub status: String,
    pub created_at: String,
}}

// ... rest of implementation
```

**DSPy Signature Fields:**
- rust_code: Complete Rust API endpoint implementation
- routes: API route definitions
- middleware: Authentication and validation middleware
- tests: API endpoint tests

Generate production-ready Rust API code optimized for LLM coders."#
                .to_string(),
            language: "rust".to_string(),
            domain: "rust_api_generation".to_string(),
            quality_score: 0.95,
        });

        // Rust repository template
        registry.register(PromptTemplate {
            name: "rust_repository_dspy".to_string(),
            template: r#"🗄️ **RUST REPOSITORY PATTERN GENERATION**

Generate a complete Rust repository pattern with database abstraction:

**Input Context:**
- Entity Name: {entity_name}
- Database Type: {database_type}
- CRUD Operations: {crud_operations}
- Query Patterns: {query_patterns}
- Transaction Support: {transaction_support}

**Requirements:**
1. **Async Traits**: Use async_trait for repository interface
2. **Database Abstraction**: Support for {database_type} with sqlx
3. **CRUD Operations**: Implement {crud_operations} operations
4. **Error Handling**: Proper error handling with anyhow::Result
5. **Tests**: Repository tests with database mocking

**Output Format:**
```rust
//! @business-domain {business_domain}
//! @architecture-pattern repository
//! @dspy-signature rust_repository_generator
//! @llm-coder-optimized true

use async_trait::async_trait;
use anyhow::Result;
use serde::{{Deserialize, Serialize}};
use sqlx::PgPool;

/// @architecture-pattern repository-trait
/// @architecture-boundary data-access
#[async_trait]
pub trait {{EntityName}}Repository: Send + Sync {{
    /// @business-operation create-{entity_name}
    async fn create(&self, data: {{EntityName}}Create) -> Result<{{EntityName}}>;
    
    /// @business-operation get-{entity_name}-by-id
    async fn get_by_id(&self, id: &str) -> Result<Option<{{EntityName}}>>;
    
    // ... rest of trait methods
}}

// ... rest of implementation
```

**DSPy Signature Fields:**
- rust_code: Complete Rust repository implementation
- trait_definition: Repository trait definition
- implementation: Concrete repository implementation
- tests: Repository tests with mocking

Generate production-ready Rust repository code optimized for LLM coders."#
                .to_string(),
            language: "rust".to_string(),
            domain: "rust_repository_generation".to_string(),
            quality_score: 0.95,
        });

        // Rust test template
        registry.register(PromptTemplate {
            name: "rust_test_dspy".to_string(),
            template: r#"🧪 **RUST TEST GENERATION**

Generate comprehensive Rust tests with proper mocking:

**Input Context:**
- Entity Name: {entity_name}
- Test Scenarios: {test_scenarios}
- Test Type: {test_type}
- Mocking Required: {mocking_required}
- Coverage Target: {coverage_target}

**Requirements:**
1. **Test Scenarios**: Cover {test_scenarios} scenarios
2. **Test Type**: Generate {test_type} tests
3. **Mocking**: Use mockall for {mocking_required}
4. **Coverage**: Target {coverage_target} coverage
5. **Fixtures**: Test fixtures and data setup

**Output Format:**
```rust
//! @business-domain {business_domain}
//! @architecture-pattern test-suite
//! @dspy-signature rust_test_generator
//! @llm-coder-optimized true

use super::*;
use mockall::mock;
use tokio_test;

#[cfg(test)]
mod {entity_name}_tests {{
    use super::*;
    use mockall::predicate::*;

    /// @test-scenario happy-path
    #[tokio::test]
    async fn test_create_{entity_name}_success() {{
        // @test-setup
        let test_data = {{EntityName}}Create {{
            name: "test_{entity_name}".to_string(),
        }};
        
        // @test-execution
        let result = {entity_name}_service::create(test_data).await;
        
        // @test-assertion
        assert!(result.is_ok());
        let entity = result.unwrap();
        assert_eq!(entity.name, "test_{entity_name}");
        assert!(!entity.id.is_empty());
    }}

    // ... rest of tests
}}
```

**DSPy Signature Fields:**
- rust_code: Complete Rust test implementation
- test_cases: Individual test cases
- mocks: Mock implementations
- fixtures: Test fixtures and data

Generate production-ready Rust tests optimized for LLM coders."#
                .to_string(),
            language: "rust".to_string(),
            domain: "rust_test_generation".to_string(),
            quality_score: 0.95,
        });
    }

    /// Generate Rust microservice with DSPy signature
    pub fn generate_rust_microservice(
        &self,
        business_domain: &str,
        entity_name: &str,
        security_level: &str,
        performance_profile: &str,
        architecture_pattern: &str,
    ) -> Result<PromptTemplate, String> {
        let template = self.registry.get("rust_microservice_dspy")
            .ok_or_else(|| "Template not found".to_string())?;

        let enhanced_template = PromptTemplate {
            name: format!("rust_microservice_{}", entity_name),
            template: template.template
                .replace("{business_domain}", business_domain)
                .replace("{entity_name}", entity_name)
                .replace("{security_level}", security_level)
                .replace("{performance_profile}", performance_profile)
                .replace("{architecture_pattern}", architecture_pattern),
            language: "rust".to_string(),
            domain: "rust_microservice_generation".to_string(),
            quality_score: 0.95,
        };

        Ok(enhanced_template)
    }

    /// Generate Rust API endpoint with DSPy signature
    pub fn generate_rust_api_endpoint(
        &self,
        entity_name: &str,
        api_version: &str,
        endpoint_type: &str,
        authentication: &str,
        validation_rules: &str,
    ) -> Result<PromptTemplate, String> {
        let template = self.registry.get("rust_api_endpoint_dspy")
            .ok_or_else(|| "Template not found".to_string())?;

        let enhanced_template = PromptTemplate {
            name: format!("rust_api_endpoint_{}", entity_name),
            template: template.template
                .replace("{entity_name}", entity_name)
                .replace("{api_version}", api_version)
                .replace("{endpoint_type}", endpoint_type)
                .replace("{authentication}", authentication)
                .replace("{validation_rules}", validation_rules),
            language: "rust".to_string(),
            domain: "rust_api_generation".to_string(),
            quality_score: 0.95,
        };

        Ok(enhanced_template)
    }

    /// Generate Rust repository with DSPy signature
    pub fn generate_rust_repository(
        &self,
        entity_name: &str,
        database_type: &str,
        crud_operations: &str,
        query_patterns: &str,
        transaction_support: &str,
    ) -> Result<PromptTemplate, String> {
        let template = self.registry.get("rust_repository_dspy")
            .ok_or_else(|| "Template not found".to_string())?;

        let enhanced_template = PromptTemplate {
            name: format!("rust_repository_{}", entity_name),
            template: template.template
                .replace("{entity_name}", entity_name)
                .replace("{database_type}", database_type)
                .replace("{crud_operations}", crud_operations)
                .replace("{query_patterns}", query_patterns)
                .replace("{transaction_support}", transaction_support),
            language: "rust".to_string(),
            domain: "rust_repository_generation".to_string(),
            quality_score: 0.95,
        };

        Ok(enhanced_template)
    }

    /// Generate Rust tests with DSPy signature
    pub fn generate_rust_tests(
        &self,
        entity_name: &str,
        test_scenarios: &str,
        test_type: &str,
        mocking_required: &str,
        coverage_target: &str,
    ) -> Result<PromptTemplate, String> {
        let template = self.registry.get("rust_test_dspy")
            .ok_or_else(|| "Template not found".to_string())?;

        let enhanced_template = PromptTemplate {
            name: format!("rust_tests_{}", entity_name),
            template: template.template
                .replace("{entity_name}", entity_name)
                .replace("{test_scenarios}", test_scenarios)
                .replace("{test_type}", test_type)
                .replace("{mocking_required}", mocking_required)
                .replace("{coverage_target}", coverage_target),
            language: "rust".to_string(),
            domain: "rust_test_generation".to_string(),
            quality_score: 0.95,
        };

        Ok(enhanced_template)
    }

    /// Get DSPy signature for Rust microservice
    pub fn get_microservice_signature(&self) -> RustMicroserviceSignature {
        RustMicroserviceSignature::new()
    }

    /// Get DSPy signature for Rust API endpoint
    pub fn get_api_endpoint_signature(&self) -> RustApiEndpointSignature {
        RustApiEndpointSignature::new()
    }

    /// Get DSPy signature for Rust repository
    pub fn get_repository_signature(&self) -> RustRepositorySignature {
        RustRepositorySignature::new()
    }

    /// Get DSPy signature for Rust tests
    pub fn get_test_signature(&self) -> RustTestSignature {
        RustTestSignature::new()
    }
}

impl Default for RustDspyTemplateGenerator {
    fn default() -> Self {
        Self::new()
    }
}
