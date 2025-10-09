//! OpenAI Tools Integration
//!
//! Exposes our search and analysis capabilities as OpenAI tools via NATS.

use anyhow::Result;
use async_nats::Client;
use serde::{Deserialize, Serialize};
use tracing::{info, error};

mod version_parser;
use version_parser::{VersionSpecifier, Version, VersionCompatibility};

/// OpenAI Tool Descriptor
#[derive(Debug, Serialize)]
pub struct OpenAIToolDescriptor {
    pub name: String,
    pub description: String,
    pub parameters: ToolParameters,
}

/// Tool Parameters Schema
#[derive(Debug, Serialize)]
pub struct ToolParameters {
    #[serde(rename = "type")]
    pub parameter_type: String,
    pub properties: std::collections::HashMap<String, PropertySchema>,
    pub required: Vec<String>,
}

/// Property Schema
#[derive(Debug, Serialize)]
pub struct PropertySchema {
    #[serde(rename = "type")]
    pub property_type: String,
    pub description: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub enum_values: Option<Vec<String>>,
}

/// Tool Call Request
#[derive(Debug, Deserialize)]
pub struct ToolCallRequest {
    pub tool_name: String,
    pub parameters: serde_json::Value,
}

/// Tool Call Response
#[derive(Debug, Serialize)]
pub struct ToolCallResponse {
    pub success: bool,
    pub result: serde_json::Value,
    pub error: Option<String>,
    pub warnings: Option<Vec<String>>,
}

/// OpenAI Tools Service
pub struct OpenAIToolsService {
    nats_client: Client,
}

impl OpenAIToolsService {
    /// Create new OpenAI tools service
    pub async fn new(nats_url: &str) -> Result<Self> {
        let nats_client = async_nats::connect(nats_url).await?;
        info!("OpenAI Tools Service connected to NATS: {}", nats_url);
        Ok(Self { nats_client })
    }

    /// Start the OpenAI tools service
    pub async fn start(&self) -> Result<()> {
        info!("Starting OpenAI Tools Service...");

        // Subscribe to tool call subjects
        let mut tool_call_sub = self.nats_client.subscribe("openai.tools.call").await?;
        let mut tool_descriptors_sub = self.nats_client.subscribe("openai.tools.descriptors").await?;

        // Handle tool calls
        let nats_client = self.nats_client.clone();
        tokio::spawn(async move {
            while let Some(msg) = tool_call_sub.next().await {
                if let Err(e) = Self::handle_tool_call(&nats_client, &msg).await {
                    error!("Failed to handle tool call: {}", e);
                }
            }
        });

        // Handle tool descriptors request
        let nats_client = self.nats_client.clone();
        tokio::spawn(async move {
            while let Some(msg) = tool_descriptors_sub.next().await {
                if let Err(e) = Self::handle_tool_descriptors(&nats_client, &msg).await {
                    error!("Failed to handle tool descriptors: {}", e);
                }
            }
        });

        info!("OpenAI Tools Service started successfully");
        Ok(())
    }

    /// Handle tool call
    async fn handle_tool_call(
        nats_client: &Client,
        msg: &async_nats::Message,
    ) -> Result<()> {
        let request: ToolCallRequest = serde_json::from_slice(&msg.payload)?;
        
        info!("Handling tool call: {}", request.tool_name);

        let result = match request.tool_name.as_str() {
            "search_packages" => Self::handle_search_packages(&request.parameters).await?,
            "analyze_package" => Self::handle_analyze_package(&request.parameters).await?,
            "get_package_versions" => Self::handle_get_package_versions(&request.parameters).await?,
            "get_package_info" => Self::handle_get_package_info(&request.parameters).await?,
            "check_version_compatibility" => Self::handle_check_version_compatibility(&request.parameters).await?,
            _ => {
                let response = ToolCallResponse {
                    success: false,
                    result: serde_json::Value::Null,
                    error: Some(format!("Unknown tool: {}", request.tool_name)),
                    warnings: None,
                };
                let response_json = serde_json::to_string(&response)?;
                if let Some(reply_to) = &msg.reply {
                    nats_client.publish(reply_to.clone(), response_json.into()).await?;
                }
                return Ok(());
            }
        };

        // Send response
        let response_json = serde_json::to_string(&result)?;
        if let Some(reply_to) = &msg.reply {
            nats_client.publish(reply_to.clone(), response_json.into()).await?;
        }

        Ok(())
    }

    /// Handle tool descriptors request
    async fn handle_tool_descriptors(
        nats_client: &Client,
        msg: &async_nats::Message,
    ) -> Result<()> {
        info!("Sending tool descriptors");

        let descriptors = Self::get_tool_descriptors();
        let response_json = serde_json::to_string(&descriptors)?;
        
        if let Some(reply_to) = &msg.reply {
            nats_client.publish(reply_to.clone(), response_json.into()).await?;
        }

        Ok(())
    }

    /// Handle search packages tool call
    async fn handle_search_packages(parameters: &serde_json::Value) -> Result<ToolCallResponse> {
        let query = parameters.get("query")
            .and_then(|v| v.as_str())
            .ok_or_else(|| anyhow::anyhow!("Missing query parameter"))?;
        
        let page = parameters.get("page")
            .and_then(|v| v.as_u64())
            .unwrap_or(1) as usize;
        
        let per_page = parameters.get("per_page")
            .and_then(|v| v.as_u64())
            .unwrap_or(20) as usize;

        let filters = parameters.get("filters")
            .map(|f| serde_json::from_value(f.clone()))
            .transpose()?;

        // Create search request
        let search_request = crate::server::SearchRequest {
            query: query.to_string(),
            page: Some(page),
            per_page: Some(per_page),
            filters,
        };

        // Call our search service via NATS
        let search_response = Self::call_search_service(&search_request).await?;

        Ok(ToolCallResponse {
            success: true,
            result: serde_json::to_value(search_response)?,
            error: None,
            warnings: None,
        })
    }

    /// Handle analyze package tool call
    async fn handle_analyze_package(parameters: &serde_json::Value) -> Result<ToolCallResponse> {
        let package_name = parameters.get("package_name")
            .and_then(|v| v.as_str())
            .ok_or_else(|| anyhow::anyhow!("Missing package_name parameter"))?;
        
        let ecosystem = parameters.get("ecosystem")
            .and_then(|v| v.as_str())
            .ok_or_else(|| anyhow::anyhow!("Missing ecosystem parameter"))?;
        
        let version = parameters.get("version")
            .and_then(|v| v.as_str())
            .map(|s| s.to_string());

        // Parse version specifier and check for compatibility warnings
        let mut warnings = Vec::new();
        let parsed_version = if let Some(version_str) = &version {
            let specifier = VersionSpecifier::parse(version_str)?;
            
            // Check for compatibility warnings
            if let Some(current_version) = Self::get_current_project_version(ecosystem).await? {
                if let Some(warning) = specifier.get_compatibility_warning(&current_version) {
                    warnings.push(warning);
                }
            }
            
            Some(specifier)
        } else {
            None
        };

        // Create analysis request
        let analysis_request = crate::server::AnalysisRequest {
            package_name: package_name.to_string(),
            version: version,
            ecosystem: ecosystem.to_string(),
        };

        // Call our analysis service via NATS
        let analysis_response = Self::call_analysis_service(&analysis_request).await?;

        Ok(ToolCallResponse {
            success: true,
            result: serde_json::to_value(analysis_response)?,
            error: None,
            warnings: if warnings.is_empty() { None } else { Some(warnings) },
        })
    }

    /// Handle get package versions tool call
    async fn handle_get_package_versions(parameters: &serde_json::Value) -> Result<ToolCallResponse> {
        let package_name = parameters.get("package_name")
            .and_then(|v| v.as_str())
            .ok_or_else(|| anyhow::anyhow!("Missing package_name parameter"))?;
        
        let ecosystem = parameters.get("ecosystem")
            .and_then(|v| v.as_str())
            .ok_or_else(|| anyhow::anyhow!("Missing ecosystem parameter"))?;

        // Get versions for package
        let versions = Self::get_package_versions(package_name, ecosystem).await?;

        Ok(ToolCallResponse {
            success: true,
            result: serde_json::to_value(versions)?,
            error: None,
            warnings: None,
        })
    }

    /// Handle get package info tool call
    async fn handle_get_package_info(parameters: &serde_json::Value) -> Result<ToolCallResponse> {
        let package_name = parameters.get("package_name")
            .and_then(|v| v.as_str())
            .ok_or_else(|| anyhow::anyhow!("Missing package_name parameter"))?;
        
        let ecosystem = parameters.get("ecosystem")
            .and_then(|v| v.as_str())
            .ok_or_else(|| anyhow::anyhow!("Missing ecosystem parameter"))?;

        // Get basic package info
        let package_info = Self::get_package_info(package_name, ecosystem).await?;

        Ok(ToolCallResponse {
            success: true,
            result: serde_json::to_value(package_info)?,
            error: None,
            warnings: None,
        })
    }

    /// Handle check version compatibility tool call
    async fn handle_check_version_compatibility(parameters: &serde_json::Value) -> Result<ToolCallResponse> {
        let package_name = parameters.get("package_name")
            .and_then(|v| v.as_str())
            .ok_or_else(|| anyhow::anyhow!("Missing package_name parameter"))?;
        
        let ecosystem = parameters.get("ecosystem")
            .and_then(|v| v.as_str())
            .ok_or_else(|| anyhow::anyhow!("Missing ecosystem parameter"))?;
        
        let version_spec = parameters.get("version_spec")
            .and_then(|v| v.as_str())
            .ok_or_else(|| anyhow::anyhow!("Missing version_spec parameter"))?;

        // Parse version specifier
        let specifier = VersionSpecifier::parse(version_spec)?;
        
        // Get current project version
        let current_version = Self::get_current_project_version(ecosystem).await?;
        
        let compatibility = if let Some(current) = current_version {
            // Check compatibility
            let target_version = Self::resolve_version_specifier(&specifier, package_name, ecosystem).await?;
            if let Some(target) = target_version {
                current.check_compatibility(&target)
            } else {
                VersionCompatibility {
                    is_compatible: false,
                    breaking_changes: vec!["Could not resolve version specifier".to_string()],
                    new_features: vec![],
                    bug_fixes: vec![],
                    migration_notes: vec![],
                }
            }
        } else {
            VersionCompatibility {
                is_compatible: true,
                breaking_changes: vec![],
                new_features: vec![],
                bug_fixes: vec![],
                migration_notes: vec!["No current project version found".to_string()],
            }
        };

        Ok(ToolCallResponse {
            success: true,
            result: serde_json::to_value(compatibility)?,
            error: None,
            warnings: None,
        })
    }

    /// Get current project version
    async fn get_current_project_version(ecosystem: &str) -> Result<Option<Version>> {
        // This would read from package.json, Cargo.toml, mix.exs, etc.
        // For now, return mock data
        match ecosystem {
            "npm" => Ok(Some(Version::parse("18.1.0")?)),
            "cargo" => Ok(Some(Version::parse("0.1.0")?)),
            "hex" => Ok(Some(Version::parse("1.0.0")?)),
            _ => Ok(None),
        }
    }

    /// Resolve version specifier to actual version
    async fn resolve_version_specifier(
        specifier: &VersionSpecifier,
        package_name: &str,
        ecosystem: &str,
    ) -> Result<Option<Version>> {
        match specifier {
            VersionSpecifier::Exact(version) => Ok(Some(Version::parse(version)?)),
            VersionSpecifier::Latest => {
                // Get latest version from package registry
                let versions = Self::get_package_versions(package_name, ecosystem).await?;
                Ok(versions.versions.first().map(|v| Version::parse(&v.version)).transpose()?)
            },
            VersionSpecifier::Lts => {
                // Get LTS version from package registry
                let versions = Self::get_package_versions(package_name, ecosystem).await?;
                Ok(versions.versions.iter()
                    .find(|v| v.is_lts)
                    .map(|v| Version::parse(&v.version))
                    .transpose()?)
            },
            _ => Ok(None),
        }
    }

    /// Get package versions
    async fn get_package_versions(package_name: &str, ecosystem: &str) -> Result<PackageVersions> {
        // Mock version data
        let versions = match ecosystem {
            "npm" => vec![
                VersionInfo {
                    version: "18.2.0".to_string(),
                    release_type: "stable".to_string(),
                    published_date: "2024-01-15".to_string(),
                    is_latest: true,
                    is_lts: false,
                },
                VersionInfo {
                    version: "18.1.0".to_string(),
                    release_type: "stable".to_string(),
                    published_date: "2023-12-01".to_string(),
                    is_latest: false,
                    is_lts: true,
                },
                VersionInfo {
                    version: "19.0.0-beta.1".to_string(),
                    release_type: "beta".to_string(),
                    published_date: "2024-01-20".to_string(),
                    is_latest: false,
                    is_lts: false,
                },
            ],
            "cargo" => vec![
                VersionInfo {
                    version: "1.0.0".to_string(),
                    release_type: "stable".to_string(),
                    published_date: "2024-01-10".to_string(),
                    is_latest: true,
                    is_lts: false,
                },
                VersionInfo {
                    version: "0.9.0".to_string(),
                    release_type: "stable".to_string(),
                    published_date: "2023-12-15".to_string(),
                    is_latest: false,
                    is_lts: true,
                },
            ],
            _ => vec![],
        };

        Ok(PackageVersions {
            package_name: package_name.to_string(),
            ecosystem: ecosystem.to_string(),
            versions,
        })
    }

    /// Get package info
    async fn get_package_info(package_name: &str, ecosystem: &str) -> Result<PackageInfo> {
        // Mock package info
        Ok(PackageInfo {
            package_name: package_name.to_string(),
            ecosystem: ecosystem.to_string(),
            description: "A sample package".to_string(),
            latest_version: "18.2.0".to_string(),
            lts_version: Some("18.1.0".to_string()),
            downloads: 15000000,
            stars: Some(200000),
            license: Some("MIT".to_string()),
            repository: Some("https://github.com/example/package".to_string()),
            homepage: Some("https://example.com".to_string()),
            keywords: vec!["javascript".to_string(), "react".to_string()],
        })
    }

    /// Call search service via NATS
    async fn call_search_service(request: &crate::server::SearchRequest) -> Result<crate::server::SearchResponse> {
        // This would make a NATS request to our search service
        // For now, return mock data
        Ok(crate::server::SearchResponse {
            query: request.query.clone(),
            total_results: 0,
            page: request.page.unwrap_or(1),
            per_page: request.per_page.unwrap_or(20),
            results: Vec::new(),
            facets: crate::server::SearchFacets {
                ecosystems: std::collections::HashMap::new(),
                categories: std::collections::HashMap::new(),
                quality_ranges: std::collections::HashMap::new(),
                security_levels: std::collections::HashMap::new(),
            },
            suggestions: Vec::new(),
            next_page: None,
            prev_page: None,
        })
    }

    /// Call analysis service via NATS
    async fn call_analysis_service(request: &crate::server::AnalysisRequest) -> Result<crate::server::AnalysisResponse> {
        // This would make a NATS request to our analysis service
        // For now, return mock data
        Ok(crate::server::AnalysisResponse {
            package_name: request.package_name.clone(),
            ecosystem: request.ecosystem.clone(),
            version: request.version.clone().unwrap_or_else(|| "latest".to_string()),
            full_analysis: crate::server::FullAnalysis {
                cves: Vec::new(),
                dependencies: Vec::new(),
                architecture: crate::server::ArchitectureAnalysis {
                    patterns: Vec::new(),
                    complexity: "Unknown".to_string(),
                    modularity: 0.0,
                    maintainability: 0.0,
                },
                performance: crate::server::PerformanceAnalysis {
                    bundle_size: None,
                    load_time: None,
                    memory_usage: None,
                    performance_score: 0.0,
                },
                insights: Vec::new(),
                recommendations: Vec::new(),
                warnings: Vec::new(),
            },
        })
    }

    /// Get tool descriptors
    fn get_tool_descriptors() -> Vec<OpenAIToolDescriptor> {
        vec![
            OpenAIToolDescriptor {
                name: "search_packages".to_string(),
                description: "Search for packages and repositories across multiple ecosystems (npm, cargo, hex, pypi, github, etc.) with pagination and filtering".to_string(),
                parameters: ToolParameters {
                    parameter_type: "object".to_string(),
                    properties: {
                        let mut props = std::collections::HashMap::new();
                        props.insert("query".to_string(), PropertySchema {
                            property_type: "string".to_string(),
                            description: "Search query. Can include ecosystem hints like /npm/react or /github/facebook/react".to_string(),
                            enum_values: None,
                        });
                        props.insert("page".to_string(), PropertySchema {
                            property_type: "integer".to_string(),
                            description: "Page number for pagination (default: 1)".to_string(),
                            enum_values: None,
                        });
                        props.insert("per_page".to_string(), PropertySchema {
                            property_type: "integer".to_string(),
                            description: "Number of results per page (default: 20)".to_string(),
                            enum_values: None,
                        });
                        props.insert("filters".to_string(), PropertySchema {
                            property_type: "object".to_string(),
                            description: "Optional filters for ecosystem, quality, security, category".to_string(),
                            enum_values: None,
                        });
                        props
                    },
                    required: vec!["query".to_string()],
                },
            },
            OpenAIToolDescriptor {
                name: "analyze_package".to_string(),
                description: "Perform deep analysis of a specific package including CVE data, dependencies, architecture, performance, and insights. Includes version compatibility warnings for code snippets.".to_string(),
                parameters: ToolParameters {
                    parameter_type: "object".to_string(),
                    properties: {
                        let mut props = std::collections::HashMap::new();
                        props.insert("package_name".to_string(), PropertySchema {
                            property_type: "string".to_string(),
                            description: "Name of the package to analyze".to_string(),
                            enum_values: None,
                        });
                        props.insert("ecosystem".to_string(), PropertySchema {
                            property_type: "string".to_string(),
                            description: "Ecosystem the package belongs to".to_string(),
                            enum_values: Some(vec!["npm".to_string(), "cargo".to_string(), "hex".to_string(), "pypi".to_string(), "github".to_string(), "gitlab".to_string()]),
                        });
                        props.insert("version".to_string(), PropertySchema {
                            property_type: "string".to_string(),
                            description: "Version specifier: @latest, @lts, @stable, @beta, @alpha, @next, or semantic version range like >=1.0.0 <2.0.0, ^1.2.3, ~1.2.3".to_string(),
                            enum_values: Some(vec!["@latest".to_string(), "@lts".to_string(), "@stable".to_string(), "@beta".to_string(), "@alpha".to_string(), "@next".to_string()]),
                        });
                        props
                    },
                    required: vec!["package_name".to_string(), "ecosystem".to_string()],
                },
            },
            OpenAIToolDescriptor {
                name: "get_package_versions".to_string(),
                description: "Get all available versions for a package including release types (stable, beta, alpha) and LTS information".to_string(),
                parameters: ToolParameters {
                    parameter_type: "object".to_string(),
                    properties: {
                        let mut props = std::collections::HashMap::new();
                        props.insert("package_name".to_string(), PropertySchema {
                            property_type: "string".to_string(),
                            description: "Name of the package".to_string(),
                            enum_values: None,
                        });
                        props.insert("ecosystem".to_string(), PropertySchema {
                            property_type: "string".to_string(),
                            description: "Ecosystem the package belongs to".to_string(),
                            enum_values: Some(vec!["npm".to_string(), "cargo".to_string(), "hex".to_string(), "pypi".to_string(), "github".to_string(), "gitlab".to_string()]),
                        });
                        props
                    },
                    required: vec!["package_name".to_string(), "ecosystem".to_string()],
                },
            },
            OpenAIToolDescriptor {
                name: "get_package_info".to_string(),
                description: "Get basic information about a package including description, latest version, LTS version, downloads, stars, license, and repository".to_string(),
                parameters: ToolParameters {
                    parameter_type: "object".to_string(),
                    properties: {
                        let mut props = std::collections::HashMap::new();
                        props.insert("package_name".to_string(), PropertySchema {
                            property_type: "string".to_string(),
                            description: "Name of the package".to_string(),
                            enum_values: None,
                        });
                        props.insert("ecosystem".to_string(), PropertySchema {
                            property_type: "string".to_string(),
                            description: "Ecosystem the package belongs to".to_string(),
                            enum_values: Some(vec!["npm".to_string(), "cargo".to_string(), "hex".to_string(), "pypi".to_string(), "github".to_string(), "gitlab".to_string()]),
                        });
                        props
                    },
                    required: vec!["package_name".to_string(), "ecosystem".to_string()],
                },
            },
            OpenAIToolDescriptor {
                name: "check_version_compatibility".to_string(),
                description: "Check if a version specifier is compatible with your current project version. Warns about major version mismatches that could break code snippets.".to_string(),
                parameters: ToolParameters {
                    parameter_type: "object".to_string(),
                    properties: {
                        let mut props = std::collections::HashMap::new();
                        props.insert("package_name".to_string(), PropertySchema {
                            property_type: "string".to_string(),
                            description: "Name of the package".to_string(),
                            enum_values: None,
                        });
                        props.insert("ecosystem".to_string(), PropertySchema {
                            property_type: "string".to_string(),
                            description: "Ecosystem the package belongs to".to_string(),
                            enum_values: Some(vec!["npm".to_string(), "cargo".to_string(), "hex".to_string(), "pypi".to_string(), "github".to_string(), "gitlab".to_string()]),
                        });
                        props.insert("version_spec".to_string(), PropertySchema {
                            property_type: "string".to_string(),
                            description: "Version specifier to check: @latest, @lts, @stable, or semantic version range like >=1.0.0 <2.0.0, ^1.2.3, ~1.2.3".to_string(),
                            enum_values: None,
                        });
                        props
                    },
                    required: vec!["package_name".to_string(), "ecosystem".to_string(), "version_spec".to_string()],
                },
            },
        ]
    }
}

/// Package versions response
#[derive(Debug, Serialize)]
pub struct PackageVersions {
    pub package_name: String,
    pub ecosystem: String,
    pub versions: Vec<VersionInfo>,
}

/// Version information
#[derive(Debug, Serialize)]
pub struct VersionInfo {
    pub version: String,
    pub release_type: String, // stable, beta, alpha, rc
    pub published_date: String,
    pub is_latest: bool,
    pub is_lts: bool,
}

/// Package info response
#[derive(Debug, Serialize)]
pub struct PackageInfo {
    pub package_name: String,
    pub ecosystem: String,
    pub description: String,
    pub latest_version: String,
    pub lts_version: Option<String>,
    pub downloads: u64,
    pub stars: Option<u64>,
    pub license: Option<String>,
    pub repository: Option<String>,
    pub homepage: Option<String>,
    pub keywords: Vec<String>,
}
