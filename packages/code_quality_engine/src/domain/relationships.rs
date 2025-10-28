//! Relationship types for file graphs
//!
//! This module defines the types of relationships between files
//! and their strengths in the code graph.

use serde::{Deserialize, Serialize};

/// Types of relationships between files
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum RelationshipType {
    /// Direct dependency (imports, includes)
    Dependency,
    /// Similar functionality
    Functional,
    /// Same domain/business area
    Domain,
    /// Architectural similarity
    Architectural,
    /// Data flow relationship
    DataFlow,
    /// Test relationship
    Test,
    /// Configuration relationship
    Configuration,
    /// Documentation relationship
    Documentation,
    /// Microservice communication
    MicroserviceCommunication,
    /// API dependency
    ApiDependency,
    /// Service discovery
    ServiceDiscovery,
    /// Message queue relationship
    MessageQueue,
    /// Database relationship
    DatabaseRelationship,
    /// Event streaming
    EventStreaming,
    /// Load balancer relationship
    LoadBalancer,
    /// Gateway relationship
    Gateway,
    /// Event-driven communication
    EventDriven,
    /// Shared data structure
    SharedData,
    /// Similar vector embedding
    VectorSimilarity,
    /// Depends on (explicit)
    DependsOn,
    /// Imported by
    ImportedBy,
    /// Semantically similar
    SemanticallySimilar,
    /// Shares domain concepts
    SharesDomain,
    /// Related by tests
    TestedWith,
}

/// Relationship strength between files
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum RelationshipStrength {
    /// Very strong relationship (0.8-1.0)
    VeryStrong,
    /// Strong relationship (0.6-0.8)
    Strong,
    /// Moderate relationship (0.4-0.6)
    Moderate,
    /// Weak relationship (0.2-0.4)
    Weak,
    /// Very weak relationship (0.0-0.2)
    VeryWeak,
}
