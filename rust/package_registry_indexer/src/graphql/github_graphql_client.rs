//! GitHub GraphQL Client for repository analysis and dependency discovery.
//!
//! Provides direct GraphQL API access without generated types for flexibility.

use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// GitHub GraphQL client for repository analysis and dependency discovery.
pub struct GitHubGraphQLClient {
  client: reqwest::Client,
  token: Option<String>,
}

/// GitHub version-specific repository analysis result.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GitHubVersionAnalysis {
  pub metadata: RepoMetadata,
  pub file_contents: Vec<FileContent>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RepoMetadata {
  pub name: String,
  pub description: Option<String>,
  pub stars: u32,
  pub primary_language: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FileContent {
  pub file_path: String,
  pub content: String,
}

/// Repository information from organization discovery
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OrganizationRepo {
  pub name: String,
  pub description: Option<String>,
  pub url: String,
  pub stars: u32,
  pub primary_language: Option<String>,
  pub default_branch: String,
  pub dependencies: Vec<DependencyInfo>,
  pub languages: Vec<String>,
  pub created_at: String,
  pub updated_at: String,
}

/// Dependency information extracted from manifests
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DependencyInfo {
  pub name: String,
  pub version_constraint: String,
  pub ecosystem: String,
  pub manifest_file: String,
}

impl GitHubGraphQLClient {
  pub fn new(token: Option<String>) -> Self {
    // Try to get token from gh CLI first, then fall back to provided token
    let final_token = token.or_else(|| Self::get_gh_token().ok());

    Self {
      client: reqwest::Client::new(),
      token: final_token,
    }
  }

  /// Get GitHub token from gh CLI
  fn get_gh_token() -> Result<String> {
    use std::process::Command;

    let output = Command::new("gh")
      .args(&["auth", "token"])
      .output()
      .context("Failed to run 'gh auth token' command")?;

    if !output.status.success() {
      anyhow::bail!(
        "gh auth token command failed: {}",
        String::from_utf8_lossy(&output.stderr)
      );
    }

    let token = String::from_utf8(output.stdout)
      .context("Invalid UTF-8 in gh token output")?
      .trim()
      .to_string();

    if token.is_empty() {
      anyhow::bail!("gh CLI returned empty token");
    }

    Ok(token)
  }

  /// Get current user's username from gh CLI
  pub fn get_gh_username() -> Result<String> {
    use std::process::Command;

    let output = Command::new("gh")
      .args(&["api", "user", "--jq", ".login"])
      .output()
      .context("Failed to run 'gh api user' command")?;

    if !output.status.success() {
      anyhow::bail!(
        "gh api user command failed: {}",
        String::from_utf8_lossy(&output.stderr)
      );
    }

    let username = String::from_utf8(output.stdout)
      .context("Invalid UTF-8 in gh username output")?
      .trim()
      .trim_matches('"')
      .to_string();

    if username.is_empty() {
      anyhow::bail!("gh CLI returned empty username");
    }

    Ok(username)
  }

  /// Get user's organizations from gh CLI
  pub fn get_gh_organizations() -> Result<Vec<String>> {
    use std::process::Command;

    let output = Command::new("gh")
      .args(&["api", "user/orgs", "--jq", ".[].login"])
      .output()
      .context("Failed to run 'gh api user/orgs' command")?;

    if !output.status.success() {
      anyhow::bail!(
        "gh api user/orgs command failed: {}",
        String::from_utf8_lossy(&output.stderr)
      );
    }

    let orgs_json = String::from_utf8(output.stdout)
      .context("Invalid UTF-8 in gh orgs output")?;

    // Parse JSON array of organization names
    let orgs: Vec<String> = serde_json::from_str(&orgs_json)
      .context("Failed to parse organizations JSON")?;

    Ok(orgs)
  }

  /// Analyze version-specific repository with direct GraphQL queries.
  pub async fn analyze_version_specific(
    &self,
    analysis: &super::VersionSpecificAnalysis,
  ) -> Result<GitHubVersionAnalysis> {
    // For now, use a simplified query that works
    let query = format!(
      r#"
        {{
            repository(owner: "{}", name: "{}") {{
                name
                description
                stargazers {{
                    totalCount
                }}
                primaryLanguage {{
                    name
                }}
            }}
        }}
        "#,
      analysis.owner, analysis.name
    );

    let response = self.execute_query(&query).await?;

    // Parse basic repository information
    let repo_data = response
      .get("data")
      .and_then(|d| d.get("repository"))
      .ok_or_else(|| anyhow::anyhow!("No repository data found"))?;

    let metadata = RepoMetadata {
      name: repo_data
        .get("name")
        .and_then(|v| v.as_str())
        .unwrap_or_default()
        .to_string(),
      description: repo_data
        .get("description")
        .and_then(|v| v.as_str())
        .map(|s| s.to_string()),
      stars: repo_data
        .get("stargazers")
        .and_then(|s| s.get("totalCount"))
        .and_then(|c| c.as_u64())
        .unwrap_or(0) as u32,
      primary_language: repo_data
        .get("primaryLanguage")
        .and_then(|l| l.get("name"))
        .and_then(|n| n.as_str())
        .map(|s| s.to_string()),
    };

    // Fetch specific package files if requested
    let mut file_contents = Vec::new();

    // If analysis specifies target files, fetch them
    for target_file in &analysis.target_files {
      if let Ok(file_content) = self
        .fetch_file_content(
          &analysis.owner,
          &analysis.name,
          &analysis.ref_name,
          target_file,
        )
        .await
      {
        file_contents.push(FileContent {
          file_path: target_file.clone(),
          content: file_content,
        });
      }
    }

    Ok(GitHubVersionAnalysis {
      metadata,
      file_contents,
    })
  }

  async fn execute_query(&self, query: &str) -> Result<serde_json::Value> {
    let mut request_body = HashMap::new();
    request_body.insert("query", query);

    let mut request = self
      .client
      .post("https://api.github.com/graphql")
      .json(&request_body);

    if let Some(ref token) = self.token {
      request = request.header("Authorization", format!("Bearer {}", token));
    }
    request = request.header("User-Agent", "fact-tools/1.1.0");

    let response = request
      .send()
      .await
      .context("Failed to send GraphQL request")?;

    if !response.status().is_success() {
      let status = response.status();
      let text = response.text().await.unwrap_or_default();
      anyhow::bail!("GraphQL request failed with status {}: {}", status, text);
    }

    let json: serde_json::Value = response
      .json()
      .await
      .context("Failed to parse GraphQL response")?;

    if let Some(errors) = json.get("errors") {
      anyhow::bail!("GraphQL errors: {:?}", errors);
    }

    Ok(json)
  }

  /// Discover repositories in an organization using GraphQL
  pub async fn discover_organization_repos(
    &self,
    org_name: &str,
    limit: usize,
  ) -> Result<Vec<OrganizationRepo>> {
    let query = format!(
      r#"
        {{
            organization(login: "{}") {{
                repositories(first: {}, orderBy: {{field: UPDATED_AT, direction: DESC}}) {{
                    nodes {{
                        name
                        description
                        url
                        stargazers {{
                            totalCount
                        }}
                        primaryLanguage {{
                            name
                        }}
                        defaultBranchRef {{
                            name
                        }}
                        dependencyGraphManifests(first: 10) {{
                            nodes {{
                                filename
                                dependencies(first: 50) {{
                                    nodes {{
                                        packageName
                                        requirements
                                    }}
                                }}
                            }}
                        }}
                        languages(first: 10) {{
                            nodes {{
                                name
                            }}
                        }}
                        createdAt
                        updatedAt
                    }}
                }}
            }}
        }}
        "#,
      org_name, limit
    );

    let response = self.execute_query(&query).await?;

    let repos_data = response
      .get("data")
      .and_then(|d| d.get("organization"))
      .and_then(|o| o.get("repositories"))
      .and_then(|r| r.get("nodes"))
      .and_then(|n| n.as_array())
      .ok_or_else(|| anyhow::anyhow!("No repositories found"))?;

    let mut repos = Vec::new();
    for repo_data in repos_data {
      let dependencies = self.extract_dependencies_from_manifests(repo_data);

      repos.push(OrganizationRepo {
        name: repo_data
          .get("name")
          .and_then(|v| v.as_str())
          .unwrap_or_default()
          .to_string(),
        description: repo_data
          .get("description")
          .and_then(|v| v.as_str())
          .map(|s| s.to_string()),
        url: repo_data
          .get("url")
          .and_then(|v| v.as_str())
          .unwrap_or_default()
          .to_string(),
        stars: repo_data
          .get("stargazers")
          .and_then(|s| s.get("totalCount"))
          .and_then(|c| c.as_u64())
          .unwrap_or(0) as u32,
        primary_language: repo_data
          .get("primaryLanguage")
          .and_then(|l| l.get("name"))
          .and_then(|n| n.as_str())
          .map(|s| s.to_string()),
        default_branch: repo_data
          .get("defaultBranchRef")
          .and_then(|b| b.get("name"))
          .and_then(|n| n.as_str())
          .unwrap_or("main")
          .to_string(),
        dependencies,
        languages: self.extract_languages(repo_data),
        created_at: repo_data
          .get("createdAt")
          .and_then(|v| v.as_str())
          .unwrap_or_default()
          .to_string(),
        updated_at: repo_data
          .get("updatedAt")
          .and_then(|v| v.as_str())
          .unwrap_or_default()
          .to_string(),
      });
    }

    Ok(repos)
  }

  /// Extract dependencies from dependency graph manifests
  fn extract_dependencies_from_manifests(
    &self,
    repo_data: &serde_json::Value,
  ) -> Vec<DependencyInfo> {
    let mut dependencies = Vec::new();

    if let Some(manifests) = repo_data
      .get("dependencyGraphManifests")
      .and_then(|m| m.get("nodes"))
      .and_then(|n| n.as_array())
    {
      for manifest in manifests {
        let filename = manifest
          .get("filename")
          .and_then(|v| v.as_str())
          .unwrap_or_default();

        let ecosystem = self.determine_ecosystem_from_filename(filename);

        if let Some(deps) = manifest
          .get("dependencies")
          .and_then(|d| d.get("nodes"))
          .and_then(|n| n.as_array())
        {
          for dep in deps {
            dependencies.push(DependencyInfo {
              name: dep
                .get("packageName")
                .and_then(|v| v.as_str())
                .unwrap_or_default()
                .to_string(),
              version_constraint: dep
                .get("requirements")
                .and_then(|v| v.as_str())
                .unwrap_or_default()
                .to_string(),
              ecosystem: ecosystem.clone(),
              manifest_file: filename.to_string(),
            });
          }
        }
      }
    }

    dependencies
  }

  /// Determine ecosystem from manifest filename
  fn determine_ecosystem_from_filename(&self, filename: &str) -> String {
    match filename {
      f if f.ends_with("package.json") => "npm".to_string(),
      f if f.ends_with("Cargo.toml") => "cargo".to_string(),
      f if f.ends_with("mix.exs") => "hex".to_string(),
      f if f.ends_with("requirements.txt") => "pypi".to_string(),
      f if f.ends_with("pyproject.toml") => "pypi".to_string(),
      f if f.ends_with("go.mod") => "go".to_string(),
      f if f.ends_with("composer.json") => "packagist".to_string(),
      _ => "unknown".to_string(),
    }
  }

  /// Extract languages from repository data
  fn extract_languages(&self, repo_data: &serde_json::Value) -> Vec<String> {
    if let Some(languages) = repo_data
      .get("languages")
      .and_then(|l| l.get("nodes"))
      .and_then(|n| n.as_array())
    {
      languages
        .iter()
        .filter_map(|lang| lang.get("name").and_then(|n| n.as_str()))
        .map(|s| s.to_string())
        .collect()
    } else {
      Vec::new()
    }
  }

  /// Fetch individual file content using GraphQL
  async fn fetch_file_content(
    &self,
    owner: &str,
    name: &str,
    ref_name: &str,
    file_path: &str,
  ) -> Result<String> {
    let query = format!(
      r#"
        {{
            repository(owner: "{}", name: "{}") {{
                object(expression: "{}:{}") {{
                    ... on Blob {{
                        text
                    }}
                }}
            }}
        }}
        "#,
      owner, name, ref_name, file_path
    );

    let response = self.execute_query(&query).await?;

    let file_content = response
      .get("data")
      .and_then(|d| d.get("repository"))
      .and_then(|r| r.get("object"))
      .and_then(|o| o.get("text"))
      .and_then(|t| t.as_str())
      .unwrap_or_default();

    Ok(file_content.to_string())
  }
}
