//! NATS Service for Consolidated Detector
//!
//! Exposes framework detection via NATS subjects.

use anyhow::Result;
use async_nats::Client;
use futures::StreamExt;
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tracing::{info, warn, error};

use crate::layered_detector::{LayeredDetector, DetectedFramework, DetectionLevel};

#[derive(Debug, Deserialize)]
pub struct DetectionRequest {
    pub patterns: Vec<String>,
    pub context: String,
    pub codebase_id: Option<String>,
    pub correlation_id: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct DetectionResponse {
    pub frameworks: Vec<DetectedFramework>,
    pub confidence: f32,
    pub detection_level: String,
    pub llm_used: bool,
    pub correlation_id: Option<String>,
}

pub struct DetectorNatsService {
    nats_client: Client,
    detector: Arc<LayeredDetector>,
}

impl DetectorNatsService {
    pub fn new(nats_client: Client, detector: Arc<LayeredDetector>) -> Self {
        Self {
            nats_client,
            detector,
        }
    }

    pub async fn start(&self) -> Result<()> {
        info!("🚀 Starting Detector NATS Service...");

        // Subscribe to detection requests
        let mut detection_sub = self.nats_client
            .subscribe("detector.analyze")
            .await?;

        let mut simple_sub = self.nats_client
            .subscribe("detector.analyze.simple")
            .await?;

        let mut medium_sub = self.nats_client
            .subscribe("detector.analyze.medium")
            .await?;

        let mut complex_sub = self.nats_client
            .subscribe("detector.analyze.complex")
            .await?;

        // Subscribe to pattern matching requests
        let mut pattern_sub = self.nats_client
            .subscribe("detector.match.patterns")
            .await?;

        // Subscribe to LLM analysis requests
        let mut llm_sub = self.nats_client
            .subscribe("detector.llm.analyze")
            .await?;

        info!("✅ Subscribed to detector NATS subjects");

        // Handle detection requests
        let detector = self.detector.clone();
        let nats_client = self.nats_client.clone();
        tokio::spawn(async move {
            while let Some(msg) = detection_sub.next().await {
                if let Err(e) = Self::handle_detection_request(msg, &detector, &nats_client).await {
                    error!("Error handling detection request: {}", e);
                }
            }
        });

        // Handle simple detection requests
        let detector = self.detector.clone();
        let nats_client = self.nats_client.clone();
        tokio::spawn(async move {
            while let Some(msg) = simple_sub.next().await {
                if let Err(e) = Self::handle_detection_request(msg, &detector, &nats_client).await {
                    error!("Error handling simple detection request: {}", e);
                }
            }
        });

        // Handle medium detection requests
        let detector = self.detector.clone();
        let nats_client = self.nats_client.clone();
        tokio::spawn(async move {
            while let Some(msg) = medium_sub.next().await {
                if let Err(e) = Self::handle_detection_request(msg, &detector, &nats_client).await {
                    error!("Error handling medium detection request: {}", e);
                }
            }
        });

        // Handle complex detection requests
        let detector = self.detector.clone();
        let nats_client = self.nats_client.clone();
        tokio::spawn(async move {
            while let Some(msg) = complex_sub.next().await {
                if let Err(e) = Self::handle_detection_request(msg, &detector, &nats_client).await {
                    error!("Error handling complex detection request: {}", e);
                }
            }
        });

        // Handle pattern matching requests
        let detector = self.detector.clone();
        let nats_client = self.nats_client.clone();
        tokio::spawn(async move {
            while let Some(msg) = pattern_sub.next().await {
                if let Err(e) = Self::handle_pattern_request(msg, &detector, &nats_client).await {
                    error!("Error handling pattern request: {}", e);
                }
            }
        });

        // Handle LLM analysis requests
        let detector = self.detector.clone();
        let nats_client = self.nats_client.clone();
        tokio::spawn(async move {
            while let Some(msg) = llm_sub.next().await {
                if let Err(e) = Self::handle_llm_request(msg, &detector, &nats_client).await {
                    error!("Error handling LLM request: {}", e);
                }
            }
        });

        info!("🎯 Detector NATS Service running");
        Ok(())
    }

    async fn handle_detection_request(
        msg: async_nats::Message,
        detector: &LayeredDetector,
        nats_client: &Client,
    ) -> Result<()> {
        let request: DetectionRequest = serde_json::from_slice(&msg.payload)?;
        
        info!("🔍 Processing detection request for {} patterns", request.patterns.len());

        // Detect frameworks using layered approach
        let frameworks = detector.detect_frameworks(&request.patterns, &request.context).await?;

        // Calculate overall confidence
        let confidence = if frameworks.is_empty() {
            0.0
        } else {
            frameworks.iter().map(|f| f.confidence).sum::<f32>() / frameworks.len() as f32
        };

        // Check if LLM was used
        let llm_used = frameworks.iter().any(|f| matches!(f.detection_level, DetectionLevel::LlmAnalysis));

        // Determine detection level
        let detection_level = if frameworks.is_empty() {
            "none"
        } else {
            // Use the highest level achieved
            if frameworks.iter().any(|f| matches!(f.detection_level, DetectionLevel::LlmAnalysis)) {
                "llm"
            } else if frameworks.iter().any(|f| matches!(f.detection_level, DetectionLevel::FactValidation)) {
                "fact_validation"
            } else if frameworks.iter().any(|f| matches!(f.detection_level, DetectionLevel::AstAnalysis)) {
                "ast_analysis"
            } else if frameworks.iter().any(|f| matches!(f.detection_level, DetectionLevel::PatternMatch)) {
                "pattern_match"
            } else {
                "file_detection"
            }
        };

        let response = DetectionResponse {
            frameworks,
            confidence,
            detection_level: detection_level.to_string(),
            llm_used,
            correlation_id: request.correlation_id,
        };

        // Send response
        let response_json = serde_json::to_vec(&response)?;
        nats_client.publish(msg.reply.unwrap(), response_json.into()).await?;

        info!("✅ Detection response sent ({} frameworks, confidence: {:.2})", 
              response.frameworks.len(), confidence);

        Ok(())
    }

    async fn handle_pattern_request(
        msg: async_nats::Message,
        detector: &LayeredDetector,
        nats_client: &Client,
    ) -> Result<()> {
        let patterns: Vec<String> = serde_json::from_slice(&msg.payload)?;
        
        info!("🔍 Processing pattern matching for {} patterns", patterns.len());

        // Use pattern matching only (Level 2)
        let frameworks = detector.detect_frameworks(&patterns, "").await?;

        let response = DetectionResponse {
            frameworks,
            confidence: 0.7, // Pattern matching confidence
            detection_level: "pattern_match".to_string(),
            llm_used: false,
            correlation_id: None,
        };

        let response_json = serde_json::to_vec(&response)?;
        nats_client.publish(msg.reply.unwrap(), response_json.into()).await?;

        Ok(())
    }

    async fn handle_llm_request(
        msg: async_nats::Message,
        detector: &LayeredDetector,
        nats_client: &Client,
    ) -> Result<()> {
        let request: DetectionRequest = serde_json::from_slice(&msg.payload)?;
        
        info!("🤖 Processing LLM analysis for unknown patterns");

        // Use the layered detector's LLM analysis
        let frameworks = detector.detect_frameworks(&request.patterns, &request.context).await?;

        // Filter to only LLM-detected frameworks
        let llm_frameworks: Vec<DetectedFramework> = frameworks
            .into_iter()
            .filter(|f| matches!(f.detection_level, DetectionLevel::LlmAnalysis))
            .collect();

        let confidence = if llm_frameworks.is_empty() {
            0.0
        } else {
            llm_frameworks.iter().map(|f| f.confidence).sum::<f32>() / llm_frameworks.len() as f32
        };

        let response = DetectionResponse {
            frameworks: llm_frameworks,
            confidence,
            detection_level: "llm".to_string(),
            llm_used: true,
            correlation_id: request.correlation_id,
        };

        let response_json = serde_json::to_vec(&response)?;
        nats_client.publish(msg.reply.unwrap(), response_json.into()).await?;

        info!("✅ LLM analysis completed: {} frameworks detected", response.frameworks.len());

        Ok(())
    }
}