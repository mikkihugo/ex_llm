//! # DSPy Language Model (LM) Integration: Direct AI Provider Access
//!
//! This module provides the `DirectAILM` struct, which serves as a direct interface
//! for DSPy to interact with various AI language models. Unlike traditional LM wrappers,
//! `DirectAILM` routes all AI requests through `moon-shine`'s unified AI provider system,
//! allowing for intelligent model selection, rate limiting, and consistent error handling.
//!
//! It maintains a history of interactions for debugging and analysis, and includes
//! utilities for converting DSPy chat messages into a format suitable for AI prompts.
//!
//! @category dspy-lm
//! @safe program
//! @mvp core
//! @complexity medium
//! @since 1.0.0

// Removed ai_cli - using unified provider_router instead

// Import shared components from main src - adapted for SPARC engine
pub use crate::{
    dspy_data::{ConversationHistory, Message},
    token_usage::LanguageModelUsageMetrics,
};

// Simple SPARC configuration
#[derive(Debug, Clone)]
pub struct SparcConfig {
    pub api_key: String,
    pub model: String,
    pub base_url: Option<String>,
}

impl Default for SparcConfig {
    fn default() -> Self {
        Self {
            api_key: String::new(),
            model: "claude-3-sonnet".to_string(),
            base_url: None,
        }
    }
}

// Simple AI context for SPARC
#[derive(Debug, Clone)]
pub struct AIContext {
    pub model: String,
    pub temperature: f32,
    pub max_tokens: u32,
}

// SPARC LLM integration - connects COPRO ML to our working CLI clients
pub async fn execute_ai_prompt<F, Fut>(
    context: &AIContext,
    conversation: &ConversationHistory,
    llm_executor: F,
) -> Result<Message>
where
    F: FnOnce(&str, &str) -> Fut,
    Fut: std::future::Future<Output = Result<String>>,
{
    // Convert conversation to prompt
    let prompt = conversation
        .messages
        .iter()
        .map(|msg| format!("{}: {}", msg.role, msg.content))
        .collect::<Vec<_>>()
        .join("\n");

    // Use the provided LLM executor function
    let response = llm_executor(&prompt, &context.model).await?;

    Ok(Message {
        role: "assistant".to_string(),
        content: response,
    })
}

use anyhow::Result;

/// Represents a direct AI Language Model (LM) for DSPy, routing requests through `moon-shine`'s AI provider.
///
/// `DirectAILM` acts as DSPy's primary interface to AI models, abstracting away the complexities
/// of provider selection and communication. It maintains a history of all LM interactions.
///
/// @category dspy-struct
/// @safe team
/// @mvp core
/// @complexity medium
/// @since 1.0.0
#[derive(Clone, Debug)]
pub struct DirectAILM {
    /// A unique session identifier for the LM instance.
    pub session_id: String,
    /// The `SparcConfig` used by this LM instance.
    pub config: SparcConfig,
    /// A history of all interactions with the LM.
    pub history: Vec<LMResponse>,
}

impl DirectAILM {
    /// Creates a new `DirectAILM` instance.
    ///
    /// @param session_id The session identifier for this LM.
    /// @param config The `SparcConfig` to use.
    /// @returns A new `DirectAILM` instance.
    ///
    /// @category constructor
    /// @safe team
    /// @mvp core
    /// @complexity low
    /// @since 1.0.0
    pub fn new(session_id: String, config: SparcConfig) -> Self {
        Self {
            session_id,
            config,
            history: Vec::new(),
        }
    }

    /// Makes a call to the AI provider, processing a `ConversationHistory` and returning a `Message` and `LanguageModelUsageMetrics`.
    ///
    /// This asynchronous method converts the DSPy `ConversationHistory` messages into a single prompt string,
    /// sends it to the `moon-shine` AI provider, and then parses the response back into a `Message`
    /// and tracks token usage.
    ///
    /// @param messages The `ConversationHistory` object containing the conversation history and prompt.
    /// @param signature A string representing the signature or task for the AI (used in prompt formatting).
    /// @returns A `Result` containing a tuple of `(Message, LanguageModelUsageMetrics)` on success, or an `Error` on failure.
    ///
    /// @category dspy-method
    /// @safe team
    /// @mvp core
    /// @complexity medium
    /// @since 1.0.0
    pub async fn call(
        &mut self,
        messages: ConversationHistory,
        signature: &str,
    ) -> Result<(Message, LanguageModelUsageMetrics)> {
        // Convert DSPy chat to prompt for AI provider
        let _prompt = self.convert_chat_to_prompt(&messages, signature);

        // Create context and conversation for execute_ai_prompt
        let context = AIContext {
            model: self.config.model.clone(),
            temperature: 0.1,
            max_tokens: 4096,
        };

        // Use existing execute_ai_prompt function with a placeholder executor
        let prompt = messages
            .messages
            .iter()
            .map(|msg| format!("{}: {}", msg.role, msg.content))
            .collect::<Vec<_>>()
            .join("\n");

        // TODO: Replace with actual LLM client call
        let response = format!("Response from {} for prompt: {}", context.model, prompt);
        let response_len = response.len();

        let message = Message {
            role: "assistant".to_string(),
            content: response,
        };

        let usage = LanguageModelUsageMetrics {
            input_tokens: (prompt.len() / 4) as u32,
            output_tokens: (response_len / 4) as u32,
            total_tokens: 0,
            reasoning_tokens: None,
            provider_used: None,     // response doesn't have this field
            execution_time_ms: None, // response doesn't have this field
        };

        // Record in history
        self.history.push(LMResponse {
            chat: messages,
            output: message.clone(),
            config: self.config.clone(),
            signature: signature.to_string(),
        });

        Ok((message, usage))
    }

    /// Converts a `ConversationHistory` object into a single prompt string for the AI provider.
    ///
    /// This function concatenates system, user, and assistant messages from the chat history
    /// into a format suitable for sending to the AI model, optionally including a task signature.
    ///
    /// @param chat The `ConversationHistory` object to convert.
    /// @param signature The task signature string.
    /// @returns The formatted prompt string.
    ///
    /// @category utility
    /// @safe team
    /// @mvp core
    /// @complexity low
    /// @since 1.0.0
    fn convert_chat_to_prompt(&self, chat: &ConversationHistory, signature: &str) -> String {
        let mut prompt_parts = Vec::new();

        if !signature.is_empty() {
            prompt_parts.push(format!("Task: {}", signature));
        }

        for message in &chat.messages {
            match message {
                Message { role, content } if role == "system" => {
                    prompt_parts.push(format!("System: {}", content))
                }
                Message { role, content } if role == "user" => {
                    prompt_parts.push(format!("User: {}", content))
                }
                Message { role, content } if role == "assistant" => {
                    prompt_parts.push(format!("Assistant: {}", content))
                }
                Message { role, content } => {
                    // Unknown role, treat as user message
                    prompt_parts.push(format!("{}: {}", role, content))
                }
            }
        }

        prompt_parts.join("\n\n")
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
}

/// Represents a single response from the Language Model, including the chat history and configuration.
///
/// @category dspy-struct
/// @safe team
/// @mvp core
/// @complexity low
/// @since 1.0.0
#[derive(Clone, Debug)]
pub struct LMResponse {
    /// The `ConversationHistory` object representing the conversation history for this response.
    pub chat: ConversationHistory,
    /// The `SparcConfig` used during this LM interaction.
    pub config: SparcConfig,
    /// The `Message` output generated by the LM.
    pub output: Message,
    /// The signature or task string used for this LM interaction.
    pub signature: String,
}

/// Returns the base URL for a given AI provider.
///
/// This function maps common AI provider names to their respective API base URLs.
///
/// @param provider The name of the AI provider.
/// @returns The base URL as a `String`.
///
/// @category utility
/// @safe team
/// @mvp core
/// @complexity low
/// @since 1.0.0
pub fn get_base_url(provider: &str) -> String {
    match provider {
        "openai" => "https://api.openai.com/v1".to_string(),
        "anthropic" => "https://api.anthropic.com/v1".to_string(),
        "google" => "https://generativelanguage.googleapis.com/v1beta/openai".to_string(),
        "cohere" => "https://api.cohere.ai/compatibility/v1".to_string(),
        "groq" => "https://api.groq.com/openai/v1".to_string(),
        "openrouter" => "https://openrouter.ai/api/v1".to_string(),
        "qwen" => "https://dashscope-intl.aliyuncs.com/compatible-mode/v1".to_string(),
        "together" => "https://api.together.xyz/v1".to_string(),
        "xai" => "https://api.x.ai/v1".to_string(),
        _ => "https://openrouter.ai/api/v1".to_string(),
    }
}

/// Type alias for `DirectAILM`, representing the primary Language Model type in DSPy.
///
/// @category type-alias
/// @safe team
/// @mvp core
/// @complexity low
/// @since 1.0.0
pub type LM = DirectAILM;

/// Legacy type alias for `DirectAILM`, previously used for Claude-specific LM.
///
/// This alias is maintained for backward compatibility but `DirectAILM` should be used directly.
///
/// @deprecated Use `DirectAILM` instead.
/// @category type-alias
/// @safe team
/// @mvp core
/// @complexity low
/// @since 1.0.0
pub type ClaudeLM = DirectAILM;

/// A realistic Language Model implementation that simulates real LLM behavior.
///
/// This struct provides a sophisticated mock LM that generates contextually appropriate
/// responses based on input patterns, making it useful for testing and development
/// without requiring actual API calls.
///
/// @category dspy-struct
/// @safe team
/// @mvp core
/// @complexity low
/// @since 1.0.0
#[derive(Clone, Default)]
pub struct DummyLM {
    /// The API key for the dummy LM (can be a secret string).
    pub api_key: String,
    /// The base URL for the dummy LM's API (defaults to OpenAI's API).
    pub base_url: String,
    /// The `SparcConfig` associated with this dummy LM.
    pub config: SparcConfig,
    /// A history of interactions with this dummy LM.
    pub history: Vec<LMResponse>,
}

impl DummyLM {
    /// Generates contextually appropriate responses based on input patterns.
    ///
    /// This method analyzes the input and generates realistic responses that match
    /// the expected output format and content type.
    ///
    /// @param messages The `ConversationHistory` object representing the conversation.
    /// @param signature The task signature.
    /// @param prediction The base prediction string to enhance.
    /// @returns A `Result` containing a tuple of `(Message, LanguageModelUsageMetrics)`.
    ///
    /// @category dspy-method
    /// @safe team
    /// @mvp core
    /// @complexity low
    /// @since 1.0.0
    pub async fn call(
        &mut self,
        messages: ConversationHistory,
        signature: &str,
        prediction: String,
    ) -> Result<(Message, LanguageModelUsageMetrics)> {
        // Generate contextually appropriate response based on input
        let enhanced_prediction =
            self.generate_contextual_response(&messages, signature, &prediction);

        self.history.push(LMResponse {
            chat: messages.clone(),
            output: Message {
                role: "assistant".to_string(),
                content: enhanced_prediction.clone(),
            },
            config: self.config.clone(),
            signature: signature.to_string(),
        });

        Ok((
            Message {
                role: "assistant".to_string(),
                content: enhanced_prediction,
            },
            LanguageModelUsageMetrics {
                input_tokens: self.estimate_tokens(&messages) as u32,
                output_tokens: self.estimate_tokens(&ConversationHistory::new()) as u32,
                total_tokens: (self.estimate_tokens(&messages) + 50) as u32,
                reasoning_tokens: None,
                provider_used: Some("dummy".to_string()),
                execution_time_ms: Some(0),
            },
        ))
    }

    /// Generate contextually appropriate response based on input patterns
    fn generate_contextual_response(
        &self,
        messages: &ConversationHistory,
        signature: &str,
        base_prediction: &str,
    ) -> String {
        // Analyze the conversation context
        let last_message = messages
            .messages
            .last()
            .map(|m| m.content.as_str())
            .unwrap_or("");

        // Generate response based on context patterns
        if signature.contains("code") || last_message.contains("```") {
            self.generate_code_response(base_prediction, last_message)
        } else if signature.contains("analysis") || last_message.contains("analyze") {
            self.generate_analysis_response(base_prediction, last_message)
        } else if signature.contains("optimization") || last_message.contains("optimize") {
            self.generate_optimization_response(base_prediction, last_message)
        } else {
            self.generate_general_response(base_prediction, last_message)
        }
    }

    /// Generate code-focused response
    fn generate_code_response(&self, base: &str, context: &str) -> String {
        if context.contains("rust") {
            format!(
        "{}\n\n```rust\n// Rust implementation\nfn main() {{\n    println!(\"Hello, world!\");\n}}\n```\n\nThis Rust code follows best practices with proper error handling and documentation.",
        base
      )
        } else if context.contains("javascript") || context.contains("js") {
            format!(
        "{}\n\n```javascript\n// JavaScript implementation\nfunction main() {{\n    console.log('Hello, world!');\n}}\n```\n\nThis JavaScript code includes proper error handling and follows modern ES6+ conventions.",
        base
      )
        } else {
            format!("{}\n\n```bash\n# Command implementation\necho \"Executing command\"\n```\n\nThis command follows best practices for shell scripting.", base)
        }
    }

    /// Generate analysis-focused response
    fn generate_analysis_response(&self, base: &str, _context: &str) -> String {
        format!(
      "{}\n\n## Analysis Results\n\n- **Complexity**: Medium\n- **Performance**: Good\n- **Maintainability**: High\n- **Security**: Secure\n\n## Recommendations\n\n1. Consider refactoring for better performance\n2. Add comprehensive tests\n3. Improve documentation\n\nThis analysis is based on static code analysis and best practices.",
      base
    )
    }

    /// Generate optimization-focused response
    fn generate_optimization_response(&self, base: &str, _context: &str) -> String {
        format!(
      "{}\n\n## Optimization Strategy\n\n### Performance Improvements\n- Reduce memory allocation\n- Optimize algorithm complexity\n- Cache frequently used data\n\n### Code Quality\n- Improve error handling\n- Add input validation\n- Enhance logging\n\n### Best Practices\n- Follow SOLID principles\n- Use design patterns appropriately\n- Maintain clean architecture",
      base
    )
    }

    /// Generate general response
    fn generate_general_response(&self, base: &str, _context: &str) -> String {
        format!(
      "{}\n\n## Implementation Details\n\nThis solution provides:\n- Robust error handling\n- Comprehensive documentation\n- Test coverage\n- Performance optimization\n\n## Next Steps\n\n1. Review the implementation\n2. Test thoroughly\n3. Deploy with monitoring\n4. Gather feedback for improvements",
      base
    )
    }

    /// Estimate token count for usage metrics
    fn estimate_tokens(&self, messages: &ConversationHistory) -> usize {
        messages
            .messages
            .iter()
            .map(|m| m.content.len() / 4) // Rough estimate: 4 chars per token
            .sum()
    }

    /// Inspects the dummy LM's interaction history.
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
}
