//! # AI Provider LM: Intelligent Multi-Provider Language Model for DSPy
//!
//! This module provides the `AIProviderLM` struct, an advanced Language Model (LM) adapter
//! for the DSPy framework. It intelligently routes AI requests to various underlying
//! AI providers (e.g., Claude, Gemini, OpenAI) based on task requirements, configured
//! preferences, and provider capabilities.
//!
//! `AIProviderLM` replaces hardcoded AI CLI calls with a flexible, multi-provider backend,
//! ensuring that DSPy can leverage the strengths of different AI models for diverse tasks
//! such as code fixing, DSPy optimization, code generation, and analysis.
//!
//! @category dspy-lm
//! @safe program
//! @mvp core
//! @complexity high
//! @since 1.0.0

use super::{ConversationHistory, LMResponse, Message};
// SparcConfig replaced with SparcConfig
use anyhow::Result;
use crate::provider_router::{get_ai_router, AIContext, AIRequest};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Multi-provider Language Model adapter for DSPy with intelligent routing.
///
/// This struct implements the core logic for selecting and interacting with various
/// AI providers based on the nature of the DSPy task. It handles prompt formatting,
/// response parsing, and maintains a history of interactions.
///
/// @category dspy-struct
/// @safe program
/// @mvp core
/// @complexity high
/// @since 1.0.0
#[derive(Clone, Debug)]
pub struct AIProviderLM {
    /// A unique session identifier for this LM instance.
    pub session_id: String,
    /// The `SparcConfig` used by this LM instance.
    pub config: SparcConfig,
    /// A history of all interactions with this LM instance.
    pub history: Vec<LMResponse>,
    /// An optional preference for a specific AI provider, overriding intelligent selection.
    pub provider_preference: Option<String>, // Optional provider override
}

impl AIProviderLM {
    /// Creates a new builder for `AIProviderLM`.
    ///
    /// @returns A new `AIProviderLMBuilder` instance.
    ///
    /// @category constructor
    /// @safe team
    /// @mvp core
    /// @complexity low
    /// @since 1.0.0
    pub fn builder() -> AIProviderLMBuilder {
        AIProviderLMBuilder::new()
    }

    /// Makes an asynchronous call to the AI provider, processing a `ConversationHistory` and returning a `Message` and `LanguageModelUsageMetrics`.
    ///
    /// This is the primary method for interacting with the AI. It converts DSPy chat messages
    /// into a prompt, infers the AI context, routes the request to the appropriate provider,
    /// and processes the AI's response.
    ///
    /// @param messages The `ConversationHistory` object containing the conversation history and prompt.
    /// @param signature A string representing the signature or task for the AI.
    /// @returns A `Result` containing a tuple of `(Message, LanguageModelUsageMetrics)` on success, or an `Error` on failure.
    ///
    /// @category dspy-method
    /// @safe team
    /// @mvp core
    /// @complexity high
    /// @since 1.0.0
    pub async fn call(&mut self, messages: ConversationHistory, signature: &str) -> Result<(Message, super::usage::LanguageModelUsageMetrics)> {
        let start_time = std::time::Instant::now();

        // Convert DSPy chat format to AI provider prompt
        let prompt = self.convert_chat_to_prompt(&messages, signature)?;

        // Determine the context for intelligent provider selection
        let context = self.infer_ai_context(&messages, signature);

        // Execute via intelligent AI provider selection
        let response = self.execute_with_ai_provider(&prompt, &context).await?;

        // Parse response back to DSPy format
        let message = Message::Assistant {
            content: response.content.clone(),
        };

        // Create usage metrics
        let usage = super::usage::LanguageModelUsageMetrics {
            prompt_tokens: (prompt.len() / 4) as u32, // Rough token estimate
            completion_tokens: (response.content.len() / 4) as u32,
            total_tokens: 0, // Will be calculated
            reasoning_tokens: None,
            provider_used: Some(response.provider_used.clone()),
            execution_time_ms: Some(response.execution_time_ms),
        };

        // Record in history for DSPy compatibility
        self.history.push(LMResponse {
            chat: messages.clone(),
            output: message.clone(),
            config: self.config.clone(),
            signature: signature.to_string(),
        });

        Ok((message, usage))
    }

    /// Inspects the LM's interaction history.
    ///
    /// @param n The number of most recent interactions to retrieve.
    /// @returns A vector of references to `LMResponse` objects from the history.
    ///
    /// @category utility
    /// @safe team
    /// @mvp core
    /// @complexity low
    /// @since 1.0.0
    pub fn inspect_history(&self, n: usize) -> Vec<&LMResponse> {
        self.history.iter().rev().take(n).collect()
    }

    /// Converts a DSPy `ConversationHistory` object into a single prompt string for the AI provider.
    ///
    /// This function formats the conversation history and signature into a coherent
    /// prompt that can be sent to the AI model.
    ///
    /// @param chat The `ConversationHistory` object to convert.
    /// @param signature The task signature string.
    /// @returns A `Result` containing the formatted prompt string.
    ///
    /// @category utility
    /// @safe team
    /// @mvp core
    /// @complexity low
    /// @since 1.0.0
    fn convert_chat_to_prompt(&self, chat: &ConversationHistory, signature: &str) -> Result<String> {
        let mut prompt_parts = Vec::new();

        // Add signature as system instruction for DSPy optimization
        if !signature.is_empty() {
            prompt_parts.push(format!("Task Signature: {}", signature));
            prompt_parts.push("Please follow the signature specification precisely.".to_string());
        }

        // Convert messages to provider-agnostic prompt format
        for message in &chat.messages {
            match message {
                Message::System { content } => {
                    prompt_parts.push(format!("System Instructions: {}", content));
                }
                Message::User { content } => {
                    prompt_parts.push(format!("User: {}", content));
                }
                Message::Assistant { content } => {
                    prompt_parts.push(format!("Assistant: {}", content));
                }
            }
        }

        // Add optimization instruction for DSPy
        if signature.contains("COPRO") || signature.contains("optimize") {
            prompt_parts.push("Provide an optimized response that improves upon previous attempts.".to_string());
        }

        Ok(prompt_parts.join("\n\n"))
    }

    /// Infers the AI context from DSPy chat messages and signature.
    ///
    /// This function analyzes the content of the chat and the task signature
    /// to determine the most appropriate `AIContext` (e.g., CodeFix, DSPyOptimization)
    /// for intelligent AI provider selection.
    ///
    /// @param chat The `ConversationHistory` object to infer context from.
    /// @param signature The task signature string.
    /// @returns The inferred `AIContext`.
    ///
    /// @category utility
    /// @safe team
    /// @mvp core
    /// @complexity medium
    /// @since 1.0.0
    fn infer_ai_context(&self, chat: &ConversationHistory, signature: &str) -> AIContext {
        // Analyze signature and messages to determine the best context
        let signature_lower = signature.to_lowercase();
        let messages_text = chat.messages.iter()
            .map(|m| match m {
                Message::System { content } => content,
                Message::User { content } => content,
                Message::Assistant { content } => content,
            })
            .collect::<Vec<&String>>()
            .join(" ")
            .to_lowercase();

        // DSPy optimization context
        if signature_lower.contains("copro") || signature_lower.contains("optimize")
            || messages_text.contains("optimize") {
            return AIContext::DSPyOptimization {
                signature: signature.to_string(),
                messages: chat.messages.iter().map(|m| format!("{:?}", m)).collect(),
            };
        }

        // Code-related contexts
        if signature_lower.contains("code") || messages_text.contains("code")
            || messages_text.contains("function") || messages_text.contains("class") {
            if signature_lower.contains("generate") || messages_text.contains("generate") {
                return AIContext::CodeGeneration {
                    language: self.detect_language(&messages_text),
                    specification: signature.to_string(),
                };
            } else if signature_lower.contains("analyze") || messages_text.contains("analyze") {
                return AIContext::CodeAnalysis {
                    language: self.detect_language(&messages_text),
                    content: messages_text,
                };
            } else {
                return AIContext::CodeFix {
                    language: self.detect_language(&messages_text),
                    content: messages_text,
                };
            }
        }

        // Default to general context
        AIContext::General
    }

    /// Detects the programming language from a given text.
    ///
    /// This function uses keyword matching to infer the language, providing a basic
    /// language detection mechanism for AI context inference.
    ///
    /// @param text The text content to analyze for language detection.
    /// @returns The detected language as a `String` (e.g., "typescript", "python").
    ///
    /// @category utility
    /// @safe team
    /// @mvp core
    /// @complexity low
    /// @since 1.0.0
    fn detect_language(&self, text: &str) -> String {
        let text_lower = text.to_lowercase();

        if text_lower.contains("typescript") || text_lower.contains(".ts") {
            "typescript".to_string()
        } else if text_lower.contains("javascript") || text_lower.contains(".js") {
            "javascript".to_string()
        } else if text_lower.contains("python") || text_lower.contains(".py") {
            "python".to_string()
        } else if text_lower.contains("rust") || text_lower.contains(".rs") {
            "rust".to_string()
        } else if text_lower.contains("java") {
            "java".to_string()
        } else {
            "general".to_string()
        }
    }

    /// Executes the AI request via the intelligent AI provider router.
    ///
    /// This function sends the formatted prompt and inferred context to the `moon-shine`
    /// AI provider system, which handles provider selection and communication.
    ///
    /// @param prompt The formatted prompt string to send to the AI.
    /// @param context The inferred `AIContext` for the request.
    /// @returns A `Result` containing an `AIResponse` on success, or an `Error` on failure.
    ///
    /// @category dspy-method
    /// @safe team
    /// @mvp core
    /// @complexity medium
    /// @since 1.0.0
    async fn execute_with_ai_provider(&self, prompt: &str, context: &AIContext) -> Result<crate::provider_router::AIResponse> {
        let router = get_ai_router();

        let request = AIRequest {
            prompt: prompt.to_string(),
            session_id: self.session_id.clone(),
            file_path: None,
            context: context.clone(),
        };

        router.execute(request).await
    }

    /// Retrieves statistics about AI provider usage from the LM's history.
    ///
    /// @returns A `HashMap` where keys are provider names and values are the count of requests.
    ///
    /// @category utility
    /// @safe team
    /// @mvp core
    /// @complexity low
    /// @since 1.0.0
    pub fn get_provider_stats(&self) -> HashMap<String, u32> {
        let mut stats = HashMap::new();

        for response in &self.history {
            // Extract provider from history if available
            let provider = "unknown"; // Would need to add provider tracking to LMResponse
            *stats.entry(provider.to_string()).or_insert(0) += 1;
        }

        stats
    }

    /// Resets the LM's interaction history.
    ///
    /// This is useful for DSPy optimization cycles where a fresh history is desired.
    ///
    /// @category utility
    /// @safe team
    /// @mvp core
    /// @complexity low
    /// @since 1.0.0
    pub fn reset_history(&mut self) {
        self.history.clear();
    }

    /// Sets an optional provider preference for specific DSPy tasks.
    ///
    /// This allows overriding the intelligent provider selection for certain operations.
    ///
    /// @param provider An `Option<String>` representing the preferred provider name.
    ///
    /// @category configuration
    /// @safe team
    /// @mvp core
    /// @complexity low
    /// @since 1.0.0
    pub fn set_provider_preference(&mut self, provider: Option<String>) {
        self.provider_preference = provider;
    }
}

/// Builder for `AIProviderLM`.
///
/// This struct provides a fluent API for constructing `AIProviderLM` instances
/// with optional session ID, configuration, and provider preferences.
///
/// @category dspy-builder
/// @safe team
/// @mvp core
/// @complexity low
/// @since 1.0.0
#[derive(Debug)]
pub struct AIProviderLMBuilder {
    /// Optional session ID for the LM.
    session_id: Option<String>,
    /// Optional `SparcConfig` for the LM.
    config: Option<SparcConfig>,
    /// Optional preferred provider name.
    provider_preference: Option<String>,
}

impl Default for AIProviderLMBuilder {
    fn default() -> Self {
        Self::new()
    }
}

impl AIProviderLMBuilder {
    /// Creates a new `AIProviderLMBuilder` instance.
    ///
    /// @returns A new `AIProviderLMBuilder`.
    ///
    /// @category constructor
    /// @safe team
    /// @mvp core
    /// @complexity low
    /// @since 1.0.0
    pub fn new() -> Self {
        Self {
            session_id: None,
            config: None,
            provider_preference: None,
        }
    }

    /// Sets the session ID for the `AIProviderLM`.
    ///
    /// @param session_id The session ID string.
    /// @returns The builder instance for chaining.
    ///
    /// @category builder-method
    /// @safe team
    /// @mvp core
    /// @complexity low
    /// @since 1.0.0
    pub fn session_id(mut self, session_id: String) -> Self {
        self.session_id = Some(session_id);
        self
    }

    /// Sets the `SparcConfig` for the `AIProviderLM`.
    ///
    /// @param config The `SparcConfig` instance.
    /// @returns The builder instance for chaining.
    ///
    /// @category builder-method
    /// @safe team
    /// @mvp core
    /// @complexity low
    /// @since 1.0.0
    pub fn config(mut self, config: SparcConfig) -> Self {
        self.config = Some(config);
        self
    }

    /// Sets the preferred AI provider for the `AIProviderLM`.
    ///
    /// This is an optional override for the intelligent provider selection.
    ///
    /// @param provider The name of the preferred provider.
    /// @returns The builder instance for chaining.
    ///
    /// @category builder-method
    /// @safe team
    /// @mvp core
    /// @complexity low
    /// @since 1.0.0
    pub fn prefer_provider(mut self, provider: String) -> Self {
        self.provider_preference = Some(provider);
        self
    }

    /// Builds the `AIProviderLM` instance.
    ///
    /// @returns The constructed `AIProviderLM` instance.
    ///
    /// @category builder-method
    /// @safe team
    /// @mvp core
    /// @complexity low
    /// @since 1.0.0
    pub fn build(self) -> AIProviderLM {
        AIProviderLM {
            session_id: self.session_id.unwrap_or_else(|| uuid::Uuid::new_v4().to_string()),
            config: self.config.unwrap_or_default(),
            history: Vec::new(),
            provider_preference: self.provider_preference,
        }
    }
}

// Note: LanguageModelUsageMetrics is imported from super:: to avoid naming conflicts with existing usage module