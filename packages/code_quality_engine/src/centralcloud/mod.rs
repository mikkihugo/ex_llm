//! CentralCloud Integration via NATS
//!
//! All code analysis features query CentralCloud for shared intelligence:
//! - CVE database (vulnerabilities)
//! - Security patterns (SQL injection, XSS, etc.)
//! - Performance patterns (optimization opportunities)
//! - Bottleneck patterns (static analysis hints)
//! - Framework compliance rules (best practices)
//! - Dependency health data (package quality)
//!
//! ## Design Philosophy
//!
//! - **No local databases** - Query CentralCloud on-demand
//! - **Graceful degradation** - Return empty results if unavailable
//! - **Shared learning** - All instances contribute and benefit
//! - **Auto-updating** - CentralCloud syncs with external sources

use anyhow::{anyhow, Result};
use serde_json::{json, Value};

/// Query CentralCloud via NATS with timeout
///
/// # Arguments
/// * `subject` - NATS subject (e.g., "intelligence_hub.vulnerability.query")
/// * `request` - JSON request payload
/// * `timeout_ms` - Timeout in milliseconds
///
/// # Returns
/// JSON response from CentralCloud
///
/// # Errors
/// Returns error if NATS unavailable or timeout, but analysis continues
///
/// # Examples
///
/// ```
/// # use serde_json::json;
/// # use code_engine::centralcloud::query_centralcloud;
/// let request = json!({
///     "dependencies": [{"name": "tokio", "version": "1.35.0"}]
/// });
/// let response = query_centralcloud(
///     "intelligence_hub.vulnerability.query",
///     &request,
///     5000
/// );
/// ```
pub fn query_centralcloud(subject: &str, request: &Value, timeout_ms: u64) -> Result<Value> {
    // Try NATS query
    match nats_request(subject, request, timeout_ms) {
        Ok(response) => Ok(response),
        Err(e) => {
            // Log warning but don't fail - graceful degradation
            eprintln!("Warning: CentralCloud unavailable ({}): {}", subject, e);

            // Return empty response (degraded mode - analysis continues)
            Ok(json!({
                "status": "unavailable",
                "reason": format!("{}", e),
                "data": [],
                "degraded_mode": true
            }))
        }
    }
}

/// Low-level NATS request (placeholder - will be implemented with async-nats)
///
/// # Implementation Note
///
/// This will use async-nats crate for actual NATS communication.
/// For now returns placeholder to fix compilation.
fn nats_request(_subject: &str, _request: &Value, _timeout_ms: u64) -> Result<Value> {
    // TODO: Implement actual NATS client
    // let client = async_nats::connect("nats://localhost:4222").await?;
    // let response = client.request(subject, request.to_string()).await?;
    // let data: Value = serde_json::from_slice(&response.payload)?;
    // Ok(data)

    // Placeholder for compilation
    Err(anyhow!("NATS not yet implemented - using degraded mode"))
}

/// Publish detection result to CentralCloud for collective learning
///
/// Fire-and-forget publish - does not block on failure
///
/// # Arguments
/// * `subject` - NATS subject (e.g., "intelligence_hub.detection.stats")
/// * `detection` - JSON detection data
///
/// # Examples
///
/// ```
/// # use serde_json::json;
/// # use code_engine::centralcloud::publish_detection;
/// let detection = json!({
///     "type": "vulnerability",
///     "cve_id": "CVE-2024-12345",
///     "package": "tokio",
///     "detected_at": "2025-01-15T10:30:00Z"
/// });
/// publish_detection("intelligence_hub.vulnerability.detected", &detection).ok();
/// ```
pub fn publish_detection(subject: &str, detection: &Value) -> Result<()> {
    // Fire-and-forget publish (async, doesn't block)
    match nats_publish(subject, detection) {
        Ok(_) => Ok(()),
        Err(e) => {
            // Don't fail on publish errors - just log
            eprintln!(
                "Warning: Failed to publish to CentralCloud ({}): {}",
                subject, e
            );
            Ok(())
        }
    }
}

/// Low-level NATS publish (placeholder)
fn nats_publish(_subject: &str, _message: &Value) -> Result<()> {
    // TODO: Implement actual NATS publish
    // let client = async_nats::connect("nats://localhost:4222").await?;
    // client.publish(subject, message.to_string().into()).await?;
    // Ok(())

    // Placeholder for compilation
    Err(anyhow!("NATS publish not yet implemented"))
}

/// Helper to extract data from CentralCloud response
///
/// # Arguments
/// * `response` - CentralCloud JSON response
/// * `key` - Data key to extract (e.g., "vulnerabilities", "patterns")
///
/// # Returns
/// Extracted data array, or empty vec if unavailable
pub fn extract_data<T>(response: &Value, key: &str) -> Vec<T>
where
    T: serde::de::DeserializeOwned,
{
    // Check if degraded mode
    if response
        .get("degraded_mode")
        .and_then(|v| v.as_bool())
        .unwrap_or(false)
    {
        return vec![]; // Empty in degraded mode
    }

    // Extract data
    response
        .get(key)
        .and_then(|v| serde_json::from_value(v.clone()).ok())
        .unwrap_or_else(Vec::new)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_extract_data_degraded_mode() {
        let response = json!({
            "status": "unavailable",
            "degraded_mode": true,
            "data": []
        });

        let data: Vec<String> = extract_data(&response, "data");
        assert_eq!(data.len(), 0);
    }

    #[test]
    fn test_extract_data_success() {
        let response = json!({
            "status": "ok",
            "vulnerabilities": [
                {"cve_id": "CVE-2024-1", "severity": "high"},
                {"cve_id": "CVE-2024-2", "severity": "medium"}
            ]
        });

        let data: Vec<Value> = extract_data(&response, "vulnerabilities");
        assert_eq!(data.len(), 2);
    }
}
