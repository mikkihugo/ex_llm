//! AI Client for Tech Detector
//!
//! Provides AI-powered framework detection via NATS calls to the AI server.

use anyhow::Result;
use async_nats::Client;
use serde::{Deserialize, Serialize};
use tracing::{info, warn};

/// AI analysis request for framework detection
#[derive(Debug, Serialize)]
pub struct AIAnalysisRequest {
    pub code_sample: String,
    pub patterns: Vec<String>,
    pub context: String,
}

/// AI analysis response with detected framework
#[derive(Debug, Deserialize)]
pub struct AIAnalysisResponse {
    pub framework_name: String,
    pub version: Option<String>,
    pub confidence: f32,
    pub evidence: Vec<String>,
    pub reasoning: String,
}

/// AI Client for calling LLM services via NATS
pub struct AIClient {
    nats_client: Client,
}

impl AIClient {
    /// Create new AI client
    pub async fn new(nats_url: &str) -> Result<Self> {
        let nats_client = async_nats::connect(nats_url).await?;
        info!("AI Client connected to NATS at {}", nats_url);
        
        Ok(Self { nats_client })
    }

    /// Analyze code sample for framework detection using AI
    pub async fn analyze_framework(
        &self,
        code_sample: &str,
        patterns: &[String],
        context: &str,
    ) -> Result<AIAnalysisResponse> {
        let request = AIAnalysisRequest {
            code_sample: code_sample.to_string(),
            patterns: patterns.to_vec(),
            context: context.to_string(),
        };

        info!("Calling AI for framework analysis on {} characters of code", code_sample.len());

        // Call AI provider via NATS
        let response = self.call_ai_provider(request).await?;
        
        info!("AI analysis completed with confidence: {:.2}", response.confidence);
        Ok(response)
    }

    /// Call AI provider via NATS
    async fn call_ai_provider(&self, request: AIAnalysisRequest) -> Result<AIAnalysisResponse> {
        // Try different AI providers in order of preference
        let providers = ["gemini", "claude", "codex"];
        
        for provider in &providers {
            let subject = format!("ai.provider.{}", provider);
            
            match self.try_provider(subject, &request).await {
                Ok(response) => {
                    info!("Successfully used {} provider for AI analysis", provider);
                    return Ok(response);
                }
                Err(e) => {
                    warn!("Provider {} failed: {}, trying next", provider, e);
                    continue;
                }
            }
        }
        
        Err(anyhow::anyhow!("All AI providers failed"))
    }

    /// Try a specific AI provider
    async fn try_provider(
        &self,
        subject: String,
        request: &AIAnalysisRequest,
    ) -> Result<AIAnalysisResponse> {
        let prompt = self.build_analysis_prompt(request);
        
        let messages = vec![
            serde_json::json!({
                "role": "system",
                "content": "You are an expert software engineer specializing in technology and framework detection. Analyze the provided code sample and patterns to identify the most likely framework, version, and confidence level. Respond with a JSON object containing framework_name, version (optional), confidence (0.0-1.0), evidence (array of strings), and reasoning (explanation)."
            }),
            serde_json::json!({
                "role": "user", 
                "content": prompt
            })
        ];

        let llm_request = serde_json::json!({
            "messages": messages,
            "complexity": "medium", // Framework analysis is medium complexity
            "max_tokens": 1000,
            "temperature": 0.1
        });

        // Send request to AI provider
        let response = self.nats_client
            .request(subject, serde_json::to_vec(&llm_request)?.into())
            .await?;

        let response_text = String::from_utf8(response.payload.to_vec())?;
        
        // Parse the response
        let ai_response: AIAnalysisResponse = serde_json::from_str(&response_text)?;
        
        Ok(ai_response)
    }

    /// Build analysis prompt for AI
    fn build_analysis_prompt(&self, request: &AIAnalysisRequest) -> String {
        format!(
            "Analyze this code sample and detected patterns to identify the framework:\n\n\
            **Code Sample:**\n```\n{}\n```\n\n\
            **Detected Patterns:**\n{}\n\n\
            **Context:**\n{}\n\n\
            Please identify the most likely framework, provide version if detectable, \
            confidence level (0.0-1.0), evidence that led to this conclusion, and your reasoning.\n\n\
            Respond with valid JSON in this exact format:\n\
            {{\n\
              \"framework_name\": \"FrameworkName\",\n\
              \"version\": \"1.2.3\",\n\
              \"confidence\": 0.85,\n\
              \"evidence\": [\"pattern1\", \"pattern2\"],\n\
              \"reasoning\": \"Explanation of detection\"\n\
            }}",
            request.code_sample,
            request.patterns.join(", "),
            request.context
        )
    }
}