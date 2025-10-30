//! Webhook notifications for scanner results

use anyhow::Result;
use serde::Serialize;
use reqwest::Client;

#[derive(Debug, Serialize)]
struct WebhookPayload {
    quality_score: f64,
    issues_count: usize,
    recommendations: Vec<WebhookRecommendation>,
    url: Option<String>,
}

#[derive(Debug, Serialize)]
struct WebhookRecommendation {
    r#type: String,
    severity: String,
    message: String,
    file: Option<String>,
}

/// Send scanner results to webhook (Slack, Teams, etc.)
pub async fn send_webhook(url: &str, results: &crate::formatter::AnalysisResult) -> Result<()> {
    let payload = WebhookPayload {
        quality_score: results.quality_score,
        issues_count: results.issues_count,
        recommendations: results.recommendations.iter().map(|r| WebhookRecommendation {
            r#type: r.r#type.clone(),
            severity: r.severity.clone(),
            message: r.message.clone(),
            file: r.file.clone(),
        }).collect(),
        url: None,
    };
    
    let client = Client::new();
    client.post(url)
        .json(&payload)
        .send()
        .await?;
    
    Ok(())
}
