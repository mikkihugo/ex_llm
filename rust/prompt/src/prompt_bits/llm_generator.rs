//! LLM-powered prompt bit generator for missing tech

use anyhow::Result;

use super::database::*;

/// Template for LLM to generate new prompt bits
pub const PROMPT_BIT_GENERATION_TEMPLATE: &str = r#"
You are a technical documentation expert. Generate a prompt bit for AI agents.

## Task
Create documentation for: {trigger} in category: {category}

## Context
{context}

## Requirements
1. Be SPECIFIC and ACTIONABLE (not generic advice)
2. Include exact commands that work
3. Show code examples if relevant
4. Mention version-specific details if important
5. Include best practices
6. Keep it concise (200-400 words)

## Format
Use markdown with clear sections:
- Commands (if applicable)
- Code examples (if applicable)
- Configuration (if applicable)
- Best practices

## Example (for reference)
```markdown
## Next.js Commands

```bash
# Create new app
npx create-next-app@latest my-app

# Development
npm run dev

# Build for production
npm run build

# Start production server
npm start
```

Best practices:
- Use App Router (not Pages Router) for new projects
- Enable TypeScript
- Use Server Components by default
- Add error boundaries
```

## Now generate for:
Trigger: {trigger}
Category: {category}
Context: {context}

Generate the prompt bit:
"#;

/// Implementation of LLM client using sparc-engine's LLM system
pub struct SPARCEngineLLMClient {
    // Will use sparc-engine's LLM clients (Claude, Gemini, etc.)
}

impl Default for SPARCEngineLLMClient {
    fn default() -> Self {
        Self::new()
    }
}

impl SPARCEngineLLMClient {
    pub fn new() -> Self {
        Self {}
    }

    /// Generate prompt bit using LLM
    async fn generate_internal(
        &self,
        trigger: &PromptBitTrigger,
        category: &PromptBitCategory,
        context: &GenerationContext,
    ) -> Result<String> {
        // Build prompt from template
        let _prompt = PROMPT_BIT_GENERATION_TEMPLATE
            .replace("{trigger}", &format!("{:?}", trigger))
            .replace("{category}", &format!("{:?}", category))
            .replace("{context}", &context.repo_context);

        // Call real LLM engine for prompt generation
        let prompt = PROMPT_BIT_GENERATION_TEMPLATE
            .replace("{trigger}", &format!("{:?}", trigger))
            .replace("{category}", &format!("{:?}", category))
            .replace("{context}", &context.repo_context);

        // Use the DSPy LM integration to call Claude/Gemini
        let generated = self
            .call_llm_engine(&prompt, trigger.clone(), category.clone())
            .await?;

        Ok(generated)
    }

    /// Call the real LLM engine (Claude/Gemini) via sparc-engine integration
    async fn call_llm_engine(
        &self,
        prompt: &str,
        trigger: PromptBitTrigger,
        category: PromptBitCategory,
    ) -> Result<String> {
        // Call the actual sparc-engine LLM service
        let client = reqwest::Client::new();

        // Create the request payload for sparc-engine
        let payload = serde_json::json!({
          "model": "claude-3-sonnet-20240229",
          "messages": [
            {
              "role": "system",
              "content": "You are an expert AI assistant that generates high-quality prompt bits for development workflows. Always provide executable commands, proper configuration, and best practices."
            },
            {
              "role": "user",
              "content": format!(
                "Generate a comprehensive prompt bit for:\n\
                 Trigger: {:?}\n\
                 Category: {:?}\n\
                 Context: {}\n\n\
                 Requirements:\n\
                 - Provide executable commands\n\
                 - Include configuration steps\n\
                 - Add best practices\n\
                 - Make it specific to the context\n\
                 - Use proper markdown formatting\n\n\
                 Generate a comprehensive, actionable prompt bit:",
                trigger,
                category,
                prompt
              )
            }
          ],
          "max_tokens": 2000,
          "temperature": 0.7
        });

        // Make the actual API call to sparc-engine
        let response = client
            .post("http://localhost:3000/api/llm/generate")
            .header("Content-Type", "application/json")
            .header("Authorization", "Bearer sparc-engine-token")
            .json(&payload)
            .send()
            .await?;

        if !response.status().is_success() {
            return Err(anyhow::anyhow!(
                "LLM API call failed: {}",
                response.status()
            ));
        }

        let llm_response: serde_json::Value = response.json().await?;

        // Extract the generated content
        let generated_content = llm_response["choices"][0]["message"]["content"]
            .as_str()
            .ok_or_else(|| anyhow::anyhow!("Invalid LLM response format"))?;

        // Validate and clean the response
        let cleaned_response =
            self.validate_and_clean_response(generated_content, trigger, category)?;

        Ok(cleaned_response)
    }

    /// Validate and clean LLM response to ensure quality
    fn validate_and_clean_response(
        &self,
        response: &str,
        trigger: PromptBitTrigger,
        category: PromptBitCategory,
    ) -> Result<String> {
        // Ensure response contains required elements
        let mut cleaned = response.to_string();

        // Add header if missing
        if !cleaned.contains("##") {
            cleaned = format!("## {:?} for {:?}\n\n{}", trigger, category, cleaned);
        }

        // Ensure code blocks are properly formatted
        if cleaned.contains("```") && !cleaned.contains("```bash") && !cleaned.contains("```rust") {
            cleaned = cleaned.replace("```", "```bash");
        }

        // Add metadata if missing
        if !cleaned.contains("Best practices:") {
            cleaned.push_str("\n\nBest practices:\n- Follow project conventions\n- Test thoroughly\n- Document changes");
        }

        // Ensure minimum length
        if cleaned.len() < 100 {
            cleaned.push_str("\n\n*Note: This prompt bit was generated by AI. Please review and customize as needed.*");
        }

        Ok(cleaned)
    }
}

#[async_trait::async_trait]
impl LLMClient for SPARCEngineLLMClient {
    async fn generate_prompt_bit(
        &self,
        trigger: &PromptBitTrigger,
        category: &PromptBitCategory,
        context: &GenerationContext,
    ) -> Result<String> {
        self.generate_internal(trigger, category, context).await
    }
}

/// Helper to build generation context
pub fn build_generation_context(
    task: &str,
    similar_bits: Vec<String>,
    repo_info: &str,
) -> GenerationContext {
    let existing_bits = if similar_bits.is_empty() {
        "No similar examples available.".to_string()
    } else {
        format!("Similar examples:\n{}", similar_bits.join("\n---\n"))
    };

    GenerationContext {
        task_description: task.to_string(),
        existing_bits: similar_bits,
        repo_context: format!(
            "Repository context: {}\n\nSimilar bits: {}",
            repo_info, existing_bits
        ),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_llm_generation() {
        let client = SPARCEngineLLMClient::new();
        let trigger = PromptBitTrigger::Framework("Spring Boot".to_string());
        let category = PromptBitCategory::Commands;
        let context = build_generation_context(
            "Add Spring Boot service",
            vec![],
            "Monorepo with Maven build system",
        );

        let result = client
            .generate_prompt_bit(&trigger, &category, &context)
            .await;
        assert!(result.is_ok());
    }
}
