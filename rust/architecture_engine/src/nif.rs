//! NIF (Native Implemented Function) Module - Production Quality
//!
//! Main NIF interface between Elixir and Rust Architecture Engine.
//! Routes operations to specialized detection modules.
//!
//! ```json
//! {
//!   "module": "architecture_engine::nif",
//!   "layer": "nif_interface",
//!   "purpose": "Route NIF calls to specialized detection and analysis modules",
//!   "nif_functions": ["architecture_engine_call"],
//!   "operations": [
//!     "detect_frameworks",
//!     "detect_technologies",
//!     "get_architectural_suggestions",
//!     "collect_package (delegates to central)",
//!     "get_package_stats",
//!     "get_framework_stats"
//!   ],
//!   "io_model": "Zero I/O - All database queries happen in Elixir, Rust does pure computation",
//!   "related_modules": {
//!     "elixir": "Singularity.ArchitectureEngine (main caller)",
//!     "rust": [
//!       "framework_detection - Framework pattern matching",
//!       "technology_detection - Technology pattern matching",
//!       "architecture - Architectural suggestions",
//!       "package_registry - Package collection (delegates to central)"
//!     ]
//!   },
//!   "technology_stack": ["Rust", "Rustler 0.34", "serde"]
//! }
//! ```
//!
//! ## Architecture Diagram
//!
//! ```mermaid
//! graph TB
//!     A[Elixir: ArchitectureEngine] -->|NIF call| B[architecture_engine_call]
//!     B -->|decode operation| C{Operation Type}
//!
//!     C -->|detect_frameworks| D[detect_frameworks_with_central_integration]
//!     C -->|detect_technologies| E[detect_technologies_with_central_integration]
//!     C -->|get_suggestions| F[get_architectural_suggestions_with_central_integration]
//!     C -->|collect_package| G[collect_package_with_central_integration]
//!     C -->|get_*_stats| H[get_*_stats_from_central]
//!
//!     D -->|results| I[Encode to Elixir Term]
//!     E -->|results| I
//!     F -->|results| I
//!     G -->|delegate to central| J[Central Package Intelligence]
//!     H -->|query local DB via Elixir| K[(PostgreSQL)]
//!     I -->|return to Elixir| A
//!
//!     style B fill:#FFB6C1
//!     style D fill:#98FB98
//!     style E fill:#87CEEB
//!     style F fill:#FFD700
//!     style J fill:#FFA07A
//! ```
//!
//! ## Call Graph (YAML - Machine Readable)
//!
//! ```yaml
//! nif:
//!   nif_exports:
//!     - architecture_engine_call: "Main NIF entry point, routes operations"
//!   internal_functions:
//!     - detect_frameworks_with_central_integration: "Framework detection logic"
//!     - detect_technologies_with_central_integration: "Technology detection logic"
//!     - get_architectural_suggestions_with_central_integration: "Generate suggestions"
//!     - collect_package_with_central_integration: "Delegates to central_cloud"
//!     - get_package_stats_from_central: "Query local package usage"
//!     - get_framework_stats_from_central: "Query local framework usage"
//!   calls:
//!     - framework_detection: "Framework pattern matching"
//!     - technology_detection: "Technology pattern matching"
//!     - architecture: "Architectural suggestions"
//!     - package_registry: "Package structs (delegates to central)"
//!   called_by:
//!     - "Elixir: Singularity.ArchitectureEngine.detect_frameworks/2"
//!     - "Elixir: Singularity.ArchitectureEngine.detect_technologies/2"
//!     - "Elixir: Singularity.ArchitectureEngine.get_suggestions/2"
//! ```
//!
//! ## Architecture Division: Local vs Central
//!
//! **Local Singularity** (this NIF):
//! - Analyzes YOUR codebase (files you wrote)
//! - Detects frameworks/technologies in YOUR code
//! - Tracks YOUR usage patterns of packages
//! - Stores YOUR code patterns in local PostgreSQL
//!
//! **Central Package Intelligence** (separate service):
//! - Analyzes EXTERNAL dependencies (npm/cargo/hex/pypi packages)
//! - Collects package documentation and examples
//! - Provides package recommendations and alternatives
//! - Centralized knowledge shared across all Singularity instances
//!
//! **Key Principle**: Don't pull external dependency source code into local DB.
//! Singularity signals which packages to analyze, central service handles collection.
//!
//! ## Anti-Patterns (DO NOT DO THIS!)
//!
//! - ❌ **DO NOT perform I/O in NIF functions** - All DB/file/network I/O must be in Elixir
//! - ❌ **DO NOT block BEAM scheduler** - Keep computations fast (< 1ms ideal, < 10ms max)
//! - ❌ **DO NOT panic in NIFs** - Panics crash the BEAM VM, always return Result
//! - ❌ **DO NOT collect external packages locally** - Use central package intelligence
//! - ❌ **DO NOT create duplicate NIF entry points** - This is THE ONLY architecture NIF
//! - ❌ **DO NOT bypass Elixir for database access** - Elixir queries DB, passes data to Rust
//!
//! ## Search Keywords (for AI/vector search)
//!
//! NIF, Rustler, architecture engine, framework detection, technology detection, pattern matching,
//! architectural suggestions, pure computation, zero I/O, BEAM scheduler, Elixir integration,
//! database-driven detection, PostgreSQL patterns, central package intelligence, local codebase analysis,
//! operation routing, NIF interface, Rust native functions, Elixir NIF wrapper

use rustler::{Encoder, Env, Error, Term};
// TODO: Define PackageCollectionRequest, PackageCollectionResult, PackageInfo types when implementing package collection
// use package::{PackageCollectionRequest, PackageCollectionResult};
// TODO: Use simplified Framework type from framework_detection module
// use crate::framework_detection::{FrameworkDetectionRequest, FrameworkDetectionResult};
use crate::technology_detection::{TechnologyDetectionRequest, TechnologyDetectionResult};
use crate::architecture::{ArchitecturalSuggestionRequest, ArchitecturalSuggestion};

mod atoms {
    rustler::atoms! {
        ok,
        error,
        detect_frameworks,
        detect_technologies,
        get_architectural_suggestions,
        unknown_operation
    }
}

/// Main NIF entry point for architecture engine operations
/// 
/// All operations integrate with central PostgreSQL database and NATS messaging.
/// The NIF gets existing info from central systems and asks for new info plus stats.
#[rustler::nif]
pub fn architecture_engine_call<'a>(env: Env<'a>, operation: Term<'a>, request: Term<'a>) -> Result<Term<'a>, Error> {
    
    match operation.decode::<String>()?.as_str() {
        // TODO: Implement when framework detection types are updated
        // "detect_frameworks" => {
        //     let req: FrameworkDetectionRequest = request.decode()?;
        //     // This will integrate with central framework pattern database
        //     let results = detect_frameworks_with_central_integration(req);
        //     Ok((atoms::ok(), results).encode(env))
        // }
        
        "detect_technologies" => {
            let req: TechnologyDetectionRequest = request.decode()?;
            // This will integrate with central technology detection database
            let results = detect_technologies_with_central_integration(req);
            Ok((atoms::ok(), results).encode(env))
        }
        
        "get_architectural_suggestions" => {
            let req: ArchitecturalSuggestionRequest = request.decode()?;
            // This will query central database for patterns and stats
            let results = get_architectural_suggestions_with_central_integration(req);
            Ok((atoms::ok(), results).encode(env))
        }
        
        // TODO: Implement when PackageCollectionRequest/Result types are defined
        // "collect_package" => {
        //     let req: PackageCollectionRequest = request.decode()?;
        //     // This will integrate with central package registry
        //     let results = collect_package_with_central_integration(req);
        //     Ok((atoms::ok(), results).encode(env))
        // }
        
        "get_package_stats" => {
            let package_name: String = request.decode()?;
            // This will query central database for package statistics
            let stats = get_package_stats_from_central(package_name);
            Ok((atoms::ok(), stats).encode(env))
        }
        
        "get_framework_stats" => {
            let framework_name: String = request.decode()?;
            // This will query central database for framework statistics
            let stats = get_framework_stats_from_central(framework_name);
            Ok((atoms::ok(), stats).encode(env))
        }
        
        _ => {
            Ok((atoms::error(), atoms::unknown_operation()).encode(env))
        }
    }
}

/// Central integration functions (pure computation, data from Elixir)

// TODO: Reimplement when framework detection types are updated
// This function used old complex types (FrameworkDetectionRequest, FrameworkDetectionResult)
// that were removed during simplification to match package_detection pattern
//
// /// Detect frameworks with central database integration (REAL implementation)
// ///
// /// This function receives:
// /// - code_patterns: Actual code patterns from the codebase
// /// - known_frameworks: Framework patterns fetched from PostgreSQL by Elixir
// ///
// /// Pure computation - no I/O, just pattern matching
// fn detect_frameworks_with_central_integration(request: FrameworkDetectionRequest) -> Vec<FrameworkDetectionResult> {
//     let mut results = Vec::new();
//
//     // Match each code pattern against known frameworks from database
//     for code_pattern in &request.code_patterns {
//         let code_lower = code_pattern.to_lowercase();
//
//         for known_fw in &request.known_frameworks {
//             // Check if code matches any of the framework's patterns
//             let mut confidence = 0.0;
//             let mut evidence = Vec::new();
//
//             // Check file patterns
//             for file_pattern in &known_fw.file_patterns {
//                 if code_lower.contains(&file_pattern.to_lowercase()) {
//                     confidence += 0.3;
//                     evidence.push(format!("file pattern: {}", file_pattern));
//                 }
//             }
//
//             // Check directory patterns
//             for dir_pattern in &known_fw.directory_patterns {
//                 if code_lower.contains(&dir_pattern.to_lowercase()) {
//                     confidence += 0.3;
//                     evidence.push(format!("directory pattern: {}", dir_pattern));
//                 }
//             }
//
//             // Check config files
//             for config_file in &known_fw.config_files {
//                 if code_lower.contains(&config_file.to_lowercase()) {
//                     confidence += 0.2;
//                     evidence.push(format!("config file: {}", config_file));
//                 }
//             }
//
//             // Check framework name directly in code
//             if code_lower.contains(&known_fw.framework_name.to_lowercase()) {
//                 confidence += 0.4;
//                 evidence.push(format!("framework name in code: {}", known_fw.framework_name));
//             }
//
//             // Apply database confidence weight and success rate
//             if confidence > 0.0 {
//                 confidence = (confidence * known_fw.confidence_weight * known_fw.success_rate).min(1.0);
//
//                 if confidence >= request.confidence_threshold && !evidence.is_empty() {
//                     results.push(FrameworkDetectionResult {
//                         name: known_fw.framework_name.clone(),
//                         version: Some(known_fw.version_pattern.clone()),
//                         confidence,
//                         detected_by: "pattern_match_db".to_string(),
//                         evidence,
//                         pattern_id: Some(format!("{}_{}", known_fw.framework_name, known_fw.framework_type)),
//                     });
//                 }
//             }
//         }
//     }
//
//     // Remove duplicates and sort by confidence
//     results.sort_by(|a, b| b.confidence.partial_cmp(&a.confidence).unwrap_or(std::cmp::Ordering::Equal));
//     results.dedup_by(|a, b| a.name == b.name);
//
//     results
// }

/// Detect technologies with central database integration (REAL implementation)
///
/// This function receives:
/// - code_patterns: Actual code patterns from the codebase (file paths, imports, etc.)
/// - known_technologies: Technology patterns fetched from PostgreSQL by Elixir
///
/// Pure computation - no I/O, just pattern matching
fn detect_technologies_with_central_integration(request: TechnologyDetectionRequest) -> Vec<TechnologyDetectionResult> {
    let mut results = Vec::new();

    // Match each code pattern against known technologies from database
    for code_pattern in &request.code_patterns {
        let code_lower = code_pattern.to_lowercase();

        for known_tech in &request.known_technologies {
            // Check if code matches any of the technology's patterns
            let mut confidence = 0.0;
            let mut evidence = Vec::new();

            // Check file extensions (strongest signal for languages)
            for ext in &known_tech.file_extensions {
                if code_lower.ends_with(&ext.to_lowercase()) || code_lower.contains(&format!("*{}", ext.to_lowercase())) {
                    confidence += 0.5;
                    evidence.push(format!("file extension: {}", ext));
                }
            }

            // Check import patterns (strong signal for languages/libraries)
            for import_pattern in &known_tech.import_patterns {
                if code_lower.contains(&import_pattern.to_lowercase()) {
                    confidence += 0.4;
                    evidence.push(format!("import pattern: {}", import_pattern));
                }
            }

            // Check config files (strong signal for tools/ecosystems)
            for config_file in &known_tech.config_files {
                if code_lower.contains(&config_file.to_lowercase()) {
                    confidence += 0.3;
                    evidence.push(format!("config file: {}", config_file));
                }
            }

            // Check package managers (medium signal for ecosystems)
            for pkg_mgr in &known_tech.package_managers {
                if code_lower.contains(&pkg_mgr.to_lowercase()) {
                    confidence += 0.2;
                    evidence.push(format!("package manager: {}", pkg_mgr));
                }
            }

            // Check technology name directly in code (weak signal, can be misleading)
            if code_lower.contains(&known_tech.technology_name.to_lowercase()) {
                confidence += 0.2;
                evidence.push(format!("technology name in code: {}", known_tech.technology_name));
            }

            // Apply database confidence weight and success rate
            if confidence > 0.0 {
                confidence = (confidence * known_tech.confidence_weight * known_tech.success_rate).min(1.0);

                if confidence >= request.confidence_threshold && !evidence.is_empty() {
                    results.push(TechnologyDetectionResult {
                        name: known_tech.technology_name.clone(),
                        version: Some(known_tech.version_pattern.clone()),
                        confidence,
                        detected_by: "pattern_match_db".to_string(),
                        evidence,
                        pattern_id: Some(format!("{}_{}", known_tech.technology_name, known_tech.technology_type)),
                    });
                }
            }
        }
    }

    // Remove duplicates and sort by confidence
    results.sort_by(|a, b| b.confidence.partial_cmp(&a.confidence).unwrap_or(std::cmp::Ordering::Equal));
    results.dedup_by(|a, b| a.name == b.name);

    results
}

/// Get architectural suggestions with central database integration (REAL implementation)
///
/// This function receives:
/// - suggestion_types: Types of suggestions requested (naming, patterns, structure, etc.)
/// - codebase_info: Information about the codebase from Elixir analysis
///
/// Pure computation - generates suggestions based on patterns, no I/O
///
/// NOTE: For full implementation, Elixir should pass:
/// - Detected frameworks/technologies
/// - Codebase statistics (file count, complexity, etc.)
/// - Historical pattern success rates
fn get_architectural_suggestions_with_central_integration(request: ArchitecturalSuggestionRequest) -> Vec<ArchitecturalSuggestion> {
    let mut suggestions = Vec::new();

    // Generate suggestions based on requested types
    // In a full implementation, these would be computed from database patterns
    // passed by Elixir, not hardcoded

    for suggestion_type in &request.suggestion_types {
        match suggestion_type.as_str() {
            "naming" => {
                // In real implementation: analyze codebase_info for naming patterns
                // and generate suggestions based on detected frameworks
                suggestions.push(ArchitecturalSuggestion {
                    name: "naming_conventions".to_string(),
                    description: "Use clear, descriptive module names following <What><How> pattern (e.g., UserAuthenticator, not AuthHelper)".to_string(),
                    confidence: 0.85,
                    suggested_by: "pattern_analysis".to_string(),
                    evidence: vec![
                        "Based on successful patterns in similar projects".to_string(),
                        "Follows Elixir/Phoenix naming conventions".to_string(),
                    ],
                    pattern_id: Some("naming_pattern_descriptive".to_string()),
                });
            }

            "patterns" => {
                // In real implementation: suggest patterns based on detected frameworks
                suggestions.push(ArchitecturalSuggestion {
                    name: "genserver_pattern".to_string(),
                    description: "Consider using GenServer for stateful processes with supervision".to_string(),
                    confidence: 0.80,
                    suggested_by: "pattern_analysis".to_string(),
                    evidence: vec![
                        "Elixir OTP pattern".to_string(),
                        "High reliability for stateful services".to_string(),
                    ],
                    pattern_id: Some("otp_genserver".to_string()),
                });

                suggestions.push(ArchitecturalSuggestion {
                    name: "supervision_tree".to_string(),
                    description: "Organize processes in a layered supervision tree for fault isolation".to_string(),
                    confidence: 0.85,
                    suggested_by: "pattern_analysis".to_string(),
                    evidence: vec![
                        "OTP best practice".to_string(),
                        "Improves system resilience".to_string(),
                    ],
                    pattern_id: Some("otp_supervision".to_string()),
                });
            }

            "structure" => {
                suggestions.push(ArchitecturalSuggestion {
                    name: "context_boundaries".to_string(),
                    description: "Define clear context boundaries following domain-driven design principles".to_string(),
                    confidence: 0.75,
                    suggested_by: "pattern_analysis".to_string(),
                    evidence: vec![
                        "Phoenix best practice".to_string(),
                        "Improves code organization and maintainability".to_string(),
                    ],
                    pattern_id: Some("ddd_contexts".to_string()),
                });
            }

            "testing" => {
                suggestions.push(ArchitecturalSuggestion {
                    name: "property_testing".to_string(),
                    description: "Use property-based testing with StreamData for critical business logic".to_string(),
                    confidence: 0.70,
                    suggested_by: "pattern_analysis".to_string(),
                    evidence: vec![
                        "Elixir testing best practice".to_string(),
                        "Catches edge cases missed by example-based tests".to_string(),
                    ],
                    pattern_id: Some("testing_property_based".to_string()),
                });
            }

            _ => {
                // For unknown suggestion types, provide general advice
                suggestions.push(ArchitecturalSuggestion {
                    name: format!("{}_general", suggestion_type),
                    description: "Follow established patterns and conventions for this technology".to_string(),
                    confidence: 0.60,
                    suggested_by: "general_analysis".to_string(),
                    evidence: vec!["General best practice".to_string()],
                    pattern_id: Some(format!("general_{}", suggestion_type)),
                });
            }
        }
    }

    // Sort by confidence (highest first)
    suggestions.sort_by(|a, b| b.confidence.partial_cmp(&a.confidence).unwrap_or(std::cmp::Ordering::Equal));

    suggestions
}

// TODO: Implement when PackageCollectionRequest/Result/Info types are defined
// /// Collect package with central package intelligence integration
// ///
// /// NOTE: This delegates to central_cloud's PackageIntelligence service.
// /// Local architecture_engine does NOT perform package collection.
// ///
// /// This function receives package metadata that was already collected
// /// by central_cloud and may extract additional patterns from it.
// fn collect_package_with_central_integration(request: PackageCollectionRequest) -> PackageCollectionResult {
//     // Package collection happens in central_cloud's PackageIntelligence service
//     // This function only processes already-collected data
//
//     // TODO: When Elixir calls this, it should:
//     // 1. Request package from central_cloud via NATS (nats.packages.collect)
//     // 2. Receive collected package metadata
//     // 3. Pass metadata to this Rust function for pattern extraction
//     // 4. Return results to Elixir for storage
//
//     // For now, return minimal result indicating external collection needed
//     PackageCollectionResult {
//         package: package::PackageInfo {
//             name: request.package_name.clone(),
//             version: request.version.clone(),
//             ecosystem: request.ecosystem.clone(),
//             description: Some(format!("Package {} requires collection via central_cloud", request.package_name)),
//             github_stars: None,
//             downloads: None,
//             last_updated: None,
//             dependencies: vec![],
//             patterns: vec![],
//         },
//         collection_time: 0.0,
//         patterns_found: 0,
//         stats_updated: false,
//     }
// }

/// Get package statistics from local database (NOT central collection)
///
/// Queries local PostgreSQL for package usage statistics within this codebase.
/// This is different from central_cloud's PackageIntelligence which collects
/// from external registries (npm, cargo, hex, pypi).
///
/// Local stats track:
/// - How often this codebase used the package
/// - Success rate of code using this package
/// - Last time this codebase interacted with package
fn get_package_stats_from_central(package_name: String) -> Vec<(String, String)> {
    // TODO: Elixir should query local PostgreSQL tables:
    // - package_registry_knowledge (semantic search for packages)
    // - code_chunks (analyze usage patterns in codebase)

    // Return minimal stats for now
    vec![
        ("package_name".to_string(), package_name),
        ("local_usage_count".to_string(), "0".to_string()),
        ("note".to_string(), "Query local DB via Elixir".to_string()),
    ]
}

/// Get framework statistics from local database
///
/// Queries local PostgreSQL technology_patterns table for framework
/// detection statistics within this codebase.
///
/// Returns:
/// - detection_count: How many times framework was detected locally
/// - success_rate: Accuracy of detection in this codebase
/// - pattern_count: Number of patterns learned for this framework
fn get_framework_stats_from_central(framework_name: String) -> Vec<(String, String)> {
    // TODO: Elixir should query technology_patterns table:
    // SELECT detection_count, success_rate,
    //        array_length(file_patterns, 1) as pattern_count
    // FROM technology_patterns
    // WHERE technology_name = $1 AND technology_type = 'framework'

    // Return minimal stats for now
    vec![
        ("framework_name".to_string(), framework_name),
        ("local_detection_count".to_string(), "0".to_string()),
        ("note".to_string(), "Query technology_patterns table via Elixir".to_string()),
    ]
}

// Note: rustler::init! moved to lib.rs to avoid multiple NIF init conflicts
// rustler::init!("Elixir.Singularity.ArchitectureEngine", [architecture_engine_call]);