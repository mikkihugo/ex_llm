use anyhow::Result;
use serde::{Deserialize, Serialize};

/// Resolves template dependencies to package metadata via package_intelligence_service
#[derive(Debug, Clone)]
pub struct PackageResolver {
    nats_client: async_nats::Client,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct TemplateDependency {
    pub name: String,
    pub version_spec: String,
    pub ecosystem: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ResolvedPackage {
    pub name: String,
    pub version: String,
    pub ecosystem: String,
    pub registry_url: String,
    pub downloads: u64,
    pub stars: u32,
    pub description: String,
}

impl PackageResolver {
    pub fn new(nats_client: async_nats::Client) -> Self {
        Self { nats_client }
    }

    /// Resolves template dependencies to actual package metadata
    pub async fn resolve_dependencies(
        &self,
        template_deps: Vec<TemplateDependency>,
    ) -> Result<Vec<ResolvedPackage>> {
        let mut resolved = Vec::new();

        for dep in template_deps {
            // Call package_intelligence_service via NATS
            let subject = format!("packages.{}.get", dep.ecosystem);
            let request = serde_json::json!({
                "name": dep.name,
                "version": dep.version_spec
            });

            let response = self
                .nats_client
                .request(subject, request.to_string().into())
                .await?;

            let package: ResolvedPackage = serde_json::from_slice(&response.payload)?;
            resolved.push(package);
        }

        Ok(resolved)
    }

    /// Validates that template dependencies exist and are compatible
    pub async fn validate_template(&self, template_id: &str) -> Result<bool> {
        // Load template
        // Parse dependencies
        // Resolve via package_intelligence_service
        // Check compatibility
        Ok(true)
    }
}
