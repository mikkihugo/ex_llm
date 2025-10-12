//! SPARC Coordinator - Manages multiple AI calls within SPARC phases
//!
//! Coordinates multiple AI runs that may all be part of one SPARC phase,
//! optimizing across the entire phase rather than individual calls.

use std::collections::HashMap;

use anyhow::Result;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use super::sparc_optimizer::{SPARCPhase, SparcMetrics, SparcOptimizer};
use crate::dspy_data::ConversationHistory;

/// Coordinates multiple AI calls within a single SPARC phase
#[derive(Debug)]
pub struct SPARCCoordinator {
    /// Current SPARC phase being coordinated
    pub current_phase: SPARCPhase,
    /// Phase-specific optimizer
    pub optimizer: SparcOptimizer,
    /// Active sessions within this phase
    pub active_sessions: HashMap<Uuid, PhaseSession>,
    /// Accumulated metrics across all calls in this phase
    pub phase_metrics: SparcMetrics,
    /// Number of AI calls made in current phase
    pub call_count: u32,
    /// Maximum calls allowed per phase
    pub max_calls_per_phase: u32,
}

/// Represents a single AI interaction session within a SPARC phase
#[derive(Debug, Clone)]
pub struct PhaseSession {
    /// Unique session identifier
    pub session_id: Uuid,
    /// Type of work being done in this session
    pub session_type: SessionType,
    /// Conversation history for this session
    pub conversation: ConversationHistory,
    /// Optimized prompt for this session type
    pub optimized_prompt: Option<String>,
    /// Performance metrics for this session
    pub session_metrics: SparcMetrics,
}

/// Types of AI sessions within a SPARC phase
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum SessionType {
    /// Initial analysis and planning
    Analysis,
    /// Detailed design work
    Design,
    /// Implementation and coding
    Implementation,
    /// Review and validation
    Review,
    /// Refinement and optimization
    Refinement,
}

/// Request for AI assistance within a SPARC phase
#[derive(Debug, Clone)]
pub struct SPARCRequest {
    /// What type of work is being requested
    pub session_type: SessionType,
    /// The specific task or prompt
    pub task: String,
    /// Context from previous work in this phase
    pub phase_context: HashMap<String, String>,
    /// Preferred model (opus/sonnet) or auto-select
    pub model_preference: Option<String>,
}

/// Response from coordinated AI call
#[derive(Debug, Clone)]
pub struct SparcResponse {
    /// The AI-generated response
    pub content: String,
    /// Model that was used
    pub model_used: String,
    /// Session ID for tracking
    pub session_id: Uuid,
    /// Performance metrics for this call
    pub metrics: SparcMetrics,
    /// Suggestions for next steps in the phase
    pub next_steps: Vec<String>,
}

impl Default for SPARCCoordinator {
    fn default() -> Self {
        Self::new(SPARCPhase::Specification)
    }
}

impl SPARCCoordinator {
    /// Create coordinator for a specific SPARC phase
    pub fn new(phase: SPARCPhase) -> Self {
        let optimizer = SparcOptimizer::for_phase(phase.clone());

        Self {
            current_phase: phase,
            optimizer,
            active_sessions: HashMap::new(),
            phase_metrics: SparcMetrics::default(),
            call_count: 0,
            max_calls_per_phase: 50, // Reasonable limit per phase
        }
    }

    /// Execute coordinated AI request within current SPARC phase
    pub async fn execute_request(&mut self, request: SPARCRequest) -> Result<SparcResponse> {
        // Check if we're within phase limits
        if self.call_count >= self.max_calls_per_phase {
            return Err(anyhow::anyhow!(
                "Maximum calls ({}) exceeded for {:?} phase",
                self.max_calls_per_phase,
                self.current_phase
            ));
        }

        // Get or create session for this type of work
        let session_id = self.get_or_create_session(request.session_type.clone());

        // Build optimized prompt for this request
        let optimized_prompt = self.build_coordinated_prompt(&request).await?;

        // Select optimal model for this request type and phase
        let model = self.select_model(&request);

        // Execute the AI call
        let response_content = self.execute_ai_call(&optimized_prompt, &model).await?;

        // Update session and phase tracking
        self.update_session(session_id, &request, &response_content);
        self.call_count += 1;

        // Analyze response and generate metrics
        let metrics = self.analyze_response(&response_content, &request);

        // Update accumulated phase metrics
        self.update_phase_metrics(&metrics);

        // Generate next steps suggestions
        let next_steps = self.suggest_next_steps(&request, &response_content);

        Ok(SparcResponse {
            content: response_content,
            model_used: model,
            session_id,
            metrics,
            next_steps,
        })
    }

    /// Build coordinated prompt that considers phase context
    async fn build_coordinated_prompt(&mut self, request: &SPARCRequest) -> Result<String> {
        // Start with base optimization for the phase
        let base_optimized = self.optimizer.optimize_prompt(&request.task).await?;

        let mut coordinated_prompt = String::new();

        // Add phase context header
        coordinated_prompt.push_str(&format!(
            "🎯 SPARC {:?} Phase - {:?} Work (Call #{}/{})\n\n",
            self.current_phase,
            request.session_type,
            self.call_count + 1,
            self.max_calls_per_phase
        ));

        // Add context from previous work in this phase
        if !request.phase_context.is_empty() {
            coordinated_prompt.push_str("Phase Context:\n");
            for (key, value) in &request.phase_context {
                coordinated_prompt.push_str(&format!("- {}: {}\n", key, value));
            }
            coordinated_prompt.push('\n');
        }

        // Add session-specific context
        if let Some(session) = self
            .active_sessions
            .values()
            .find(|s| s.session_type == request.session_type)
        {
            if !session.conversation.messages.is_empty() {
                coordinated_prompt.push_str("Previous work in this session:\n");
                for message in session.conversation.messages.iter().rev().take(3) {
                    coordinated_prompt.push_str(&format!(
                        "- {}\n",
                        message.content.chars().take(100).collect::<String>()
                    ));
                }
                coordinated_prompt.push('\n');
            }
        }

        // Add the optimized task prompt
        coordinated_prompt.push_str(&base_optimized);

        // Add coordination guidance
        coordinated_prompt.push_str("\n\nCoordination Notes:\n");
        coordinated_prompt.push_str(&format!(
            "- This is part of SPARC {} phase\n",
            format!("{:?}", self.current_phase).to_lowercase()
        ));
        coordinated_prompt
            .push_str("- Consider how this work fits with other tasks in this phase\n");
        coordinated_prompt.push_str("- Maintain consistency with previous phase outputs\n");
        coordinated_prompt.push_str("- Suggest logical next steps for phase completion\n");

        Ok(coordinated_prompt)
    }

    /// Select optimal model based on request type and phase
    fn select_model(&self, request: &SPARCRequest) -> String {
        // Use explicit preference if provided
        if let Some(model) = &request.model_preference {
            return model.clone();
        }

        // Auto-select based on session type and phase
        match (&self.current_phase, &request.session_type) {
            // Deep reasoning phases with analysis work - use Opus
            (
                SPARCPhase::Specification | SPARCPhase::Architecture | SPARCPhase::Refinement,
                SessionType::Analysis | SessionType::Design | SessionType::Review,
            ) => "opus".to_string(),

            // Implementation work - use Sonnet
            (_, SessionType::Implementation) => "sonnet".to_string(),

            // Code-focused phases - use Sonnet
            (SPARCPhase::Pseudocode | SPARCPhase::Completion, _) => "sonnet".to_string(),

            // Default to Opus for complex reasoning
            _ => "opus".to_string(),
        }
    }

    /// Execute AI call with selected model
    /// This will be called with the actual LLM function from sparc-engine
    async fn execute_ai_call(&self, prompt: &str, model: &str) -> Result<String> {
        // Placeholder - actual LLM call will be provided by sparc-engine
        Ok(format!("AI response from {} for: {}", model, prompt))
    }

    /// Get or create session for this type of work
    fn get_or_create_session(&mut self, session_type: SessionType) -> Uuid {
        // Look for existing session of this type
        for (id, session) in &self.active_sessions {
            if session.session_type == session_type {
                return *id;
            }
        }

        // Create new session
        let session_id = Uuid::new_v4();
        let session = PhaseSession {
            session_id,
            session_type,
            conversation: ConversationHistory::new(),
            optimized_prompt: None,
            session_metrics: SparcMetrics::default(),
        };

        self.active_sessions.insert(session_id, session);
        session_id
    }

    /// Update session with new interaction
    fn update_session(&mut self, session_id: Uuid, request: &SPARCRequest, response: &str) {
        if let Some(session) = self.active_sessions.get_mut(&session_id) {
            // Add user request to conversation
            session.conversation.add_user_message(&request.task);

            // Add AI response to conversation
            session.conversation.add_assistant_message(response);
        }
    }

    /// Analyze response quality and generate metrics
    fn analyze_response(&self, response: &str, request: &SPARCRequest) -> SparcMetrics {
        SparcMetrics {
            methodology_adherence: self.measure_methodology_adherence(response),
            output_quality: match request.session_type {
                SessionType::Analysis => self.measure_analysis_quality(response),
                SessionType::Design => self.measure_design_quality(response),
                SessionType::Implementation => self.measure_implementation_quality(response),
                SessionType::Review => self.measure_review_quality(response),
                SessionType::Refinement => self.measure_refinement_quality(response),
            },
            primecode_compliance: self.measure_primecode_compliance(response),
            model_efficiency: 1.0, // Assume optimal since we auto-select
        }
    }

    /// Measure how well response follows SPARC methodology
    fn measure_methodology_adherence(&self, response: &str) -> f64 {
        let mut score = 0.0_f64;

        // Check for systematic approach
        if response.contains("systematic") || response.contains("step-by-step") {
            score += 0.2;
        }

        // Check for phase awareness
        if response.contains("phase") || response.contains("SPARC") {
            score += 0.2;
        }

        // Check for proper structure
        if response.contains("requirements") || response.contains("analysis") {
            score += 0.3;
        }

        // Check for quality considerations
        if response.contains("quality") || response.contains("standards") {
            score += 0.3;
        }

        f64::min(score, 1.0)
    }

    /// Measure analysis quality
    fn measure_analysis_quality(&self, response: &str) -> f64 {
        let mut score = 0.5;

        if response.contains("requirements") {
            score += 0.15;
        }
        if response.contains("constraints") {
            score += 0.15;
        }
        if response.contains("assumptions") {
            score += 0.1;
        }
        if response.len() > 800 {
            score += 0.1;
        }

        f64::min(score, 1.0)
    }

    /// Measure design quality
    fn measure_design_quality(&self, response: &str) -> f64 {
        let mut score = 0.5;

        if response.contains("architecture") {
            score += 0.15;
        }
        if response.contains("components") {
            score += 0.15;
        }
        if response.contains("interfaces") {
            score += 0.1;
        }
        if response.contains("patterns") {
            score += 0.1;
        }

        f64::min(score, 1.0)
    }

    /// Measure implementation quality
    fn measure_implementation_quality(&self, response: &str) -> f64 {
        let mut score = 0.5;

        if response.contains("```") {
            score += 0.2;
        } // Contains code blocks
        if response.contains("error handling") {
            score += 0.15;
        }
        if response.contains("type") {
            score += 0.1;
        }
        if response.contains("test") {
            score += 0.05;
        }

        f64::min(score, 1.0)
    }

    /// Measure review quality
    fn measure_review_quality(&self, response: &str) -> f64 {
        let mut score = 0.5;

        if response.contains("issues") || response.contains("problems") {
            score += 0.2;
        }
        if response.contains("suggestions") || response.contains("recommendations") {
            score += 0.15;
        }
        if response.contains("compliance") {
            score += 0.15;
        }

        f64::min(score, 1.0)
    }

    /// Measure refinement quality
    fn measure_refinement_quality(&self, response: &str) -> f64 {
        let mut score = 0.5;

        if response.contains("improved") || response.contains("optimized") {
            score += 0.2;
        }
        if response.contains("performance") {
            score += 0.15;
        }
        if response.contains("maintainability") {
            score += 0.15;
        }

        f64::min(score, 1.0)
    }

    /// Measure PrimeCode compliance
    fn measure_primecode_compliance(&self, response: &str) -> f64 {
        let mut score = 0.0_f64;

        if response.contains("EventBus") {
            score += 0.25;
        }
        if response.contains("TypeScript") {
            score += 0.25;
        }
        if response.contains("coordination") {
            score += 0.25;
        }
        if response.contains("enterprise") {
            score += 0.25;
        }

        f64::min(score, 1.0)
    }

    /// Update accumulated phase metrics
    fn update_phase_metrics(&mut self, session_metrics: &SparcMetrics) {
        // Simple averaging for now - could be more sophisticated
        let total_calls = self.call_count as f64 + 1.0;
        let prev_weight = self.call_count as f64 / total_calls;
        let new_weight = 1.0 / total_calls;

        self.phase_metrics.methodology_adherence = self.phase_metrics.methodology_adherence
            * prev_weight
            + session_metrics.methodology_adherence * new_weight;

        self.phase_metrics.output_quality = self.phase_metrics.output_quality * prev_weight
            + session_metrics.output_quality * new_weight;

        self.phase_metrics.primecode_compliance = self.phase_metrics.primecode_compliance
            * prev_weight
            + session_metrics.primecode_compliance * new_weight;

        self.phase_metrics.model_efficiency = self.phase_metrics.model_efficiency * prev_weight
            + session_metrics.model_efficiency * new_weight;
    }

    /// Suggest next steps based on current work
    fn suggest_next_steps(&self, request: &SPARCRequest, _response: &str) -> Vec<String> {
        let mut suggestions = Vec::new();

        match (&self.current_phase, &request.session_type) {
            (SPARCPhase::Specification, SessionType::Analysis) => {
                suggestions.push("Consider detailed requirements breakdown".to_string());
                suggestions.push("Identify potential risks and constraints".to_string());
                suggestions.push("Move to design session for architectural planning".to_string());
            }
            (SPARCPhase::Architecture, SessionType::Design) => {
                suggestions.push("Detail component interfaces".to_string());
                suggestions.push("Consider scalability and performance".to_string());
                suggestions.push("Plan implementation approach".to_string());
            }
            (SPARCPhase::Completion, SessionType::Implementation) => {
                suggestions.push("Add comprehensive error handling".to_string());
                suggestions.push("Include unit tests".to_string());
                suggestions.push("Prepare for integration testing".to_string());
            }
            _ => {
                suggestions.push("Continue systematic SPARC progression".to_string());
                suggestions.push("Consider phase transition readiness".to_string());
            }
        }

        suggestions
    }

    /// Get current phase metrics
    pub fn get_phase_metrics(&self) -> &SparcMetrics {
        &self.phase_metrics
    }

    /// Get call count for current phase
    pub fn get_call_count(&self) -> u32 {
        self.call_count
    }

    /// Check if phase is ready for transition
    pub fn is_phase_ready_for_transition(&self) -> bool {
        // Phase is ready if we have good metrics and at least some work done
        self.call_count > 0
            && self.phase_metrics.methodology_adherence > 0.7
            && self.phase_metrics.output_quality > 0.7
    }

    /// Reset for new phase
    pub fn transition_to_phase(&mut self, new_phase: SPARCPhase) {
        self.current_phase = new_phase.clone();
        self.optimizer = SparcOptimizer::for_phase(new_phase);
        self.active_sessions.clear();
        self.phase_metrics = SparcMetrics::default();
        self.call_count = 0;
    }
}

/// Create SPARC coordinator for a phase
pub fn create_sparc_coordinator(phase: SPARCPhase) -> SPARCCoordinator {
    SPARCCoordinator::new(phase)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_coordinator_creation() {
        let coordinator = create_sparc_coordinator(SPARCPhase::Specification);
        assert!(matches!(
            coordinator.current_phase,
            SPARCPhase::Specification
        ));
        assert_eq!(coordinator.call_count, 0);
    }

    #[test]
    fn test_model_selection() {
        let coordinator = SPARCCoordinator::new(SPARCPhase::Architecture);

        let request = SPARCRequest {
            session_type: SessionType::Analysis,
            task: "Analyze requirements".to_string(),
            phase_context: HashMap::new(),
            model_preference: None,
        };

        let model = coordinator.select_model(&request);
        assert_eq!(model, "opus"); // Architecture + Analysis should use Opus
    }
}
