//! Luerl Runtime Analysis - Comprehensive analysis for Lua-on-BEAM integration
//!
//! This module provides Luerl-specific analysis capabilities including:
//! - Luerl runtime pattern detection (Lua.new(), Lua.eval!, etc.)
//! - Lua script quality and safety analysis
//! - BEAM ↔ Luerl integration patterns
//! - Security and sandboxing verification
//! - Performance and complexity metrics
//!
//! ## Use Cases
//!
//! 1. **Rule Engine Quality Assurance**: Validate Lua rules before storing in DB
//! 2. **HTDAG Script Validation**: Ensure decomposition scripts are safe and efficient
//! 3. **Runtime Pattern Detection**: Track Luerl usage across Elixir codebase
//! 4. **Security Auditing**: Verify sandboxing and timeout patterns

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Comprehensive Luerl runtime analysis result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LuerlAnalysisResult {
    /// Luerl runtime patterns detected in Elixir code
    pub runtime_patterns: LuerlRuntimePatterns,
    /// Lua script characteristics and quality metrics
    pub script_analysis: LuaScriptAnalysis,
    /// BEAM integration analysis
    pub beam_integration: BeamIntegrationAnalysis,
    /// Security and safety checks
    pub safety_analysis: SafetyAnalysis,
    /// Performance analysis
    pub performance_analysis: PerformanceAnalysis,
}

/// Luerl runtime patterns in Elixir code
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LuerlRuntimePatterns {
    /// Lua.new() state creation calls
    pub state_creations: Vec<StateCreationInfo>,
    /// Lua.eval! script executions
    pub script_executions: Vec<ScriptExecutionInfo>,
    /// Lua.set! context injections
    pub context_injections: Vec<ContextInjectionInfo>,
    /// Lua.load_api API loading
    pub api_loads: Vec<ApiLoadInfo>,
    /// Pattern summary statistics
    pub pattern_stats: PatternStatistics,
}

/// Lua state creation information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StateCreationInfo {
    pub location: String, // Module + function
    pub line: u32,
    pub state_variable: String,
    pub initialization_chain: Vec<String>, // Chained operations
}

/// Script execution information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScriptExecutionInfo {
    pub location: String,
    pub line: u32,
    pub script_source: ScriptSource,
    pub has_error_handling: bool,
    pub has_timeout: bool,
    pub execution_context: Option<String>,
}

/// Script source type
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ScriptSource {
    /// Embedded in code via ~LUA sigil
    Embedded { content: String },
    /// Loaded from database
    Database { reference: String },
    /// From variable
    Variable { name: String },
    /// From function argument
    Argument { name: String },
}

/// Context injection information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ContextInjectionInfo {
    pub location: String,
    pub line: u32,
    pub key: String,
    pub value_type: String,
    pub is_safe: bool, // Safe value injection (no secrets, etc.)
}

/// API loading information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ApiLoadInfo {
    pub location: String,
    pub line: u32,
    pub api_module: String,
    pub api_functions: Vec<String>,
}

/// Pattern statistics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PatternStatistics {
    pub total_lua_states: u32,
    pub total_executions: u32,
    pub executions_with_error_handling: u32,
    pub executions_with_timeout: u32,
    pub total_api_loads: u32,
    pub unique_apis_loaded: u32,
}

/// Lua script analysis
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LuaScriptAnalysis {
    /// Embedded Lua scripts (via ~LUA sigil)
    pub embedded_scripts: Vec<EmbeddedScriptInfo>,
    /// Database-stored script references
    pub db_script_references: Vec<DbScriptReference>,
    /// Script quality metrics
    pub script_metrics: Vec<ScriptMetrics>,
    /// Script categories
    pub script_categories: ScriptCategories,
}

/// Embedded script information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EmbeddedScriptInfo {
    pub location: String,
    pub line_start: u32,
    pub line_end: u32,
    pub script_type: EmbeddedScriptType,
    pub complexity: f64,
    pub safety_score: f64,
    pub has_documentation: bool,
}

/// Embedded script type
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum EmbeddedScriptType {
    RuleEngine,
    HTDAGDecomposition,
    HTDAGAgentSpawning,
    HTDAGOrchestration,
    HTDAGCompletion,
    PromptBuilding,
    CustomLogic,
}

/// Database script reference
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DbScriptReference {
    pub location: String,
    pub line: u32,
    pub table: String,
    pub field: String,
    pub script_id: Option<String>,
}

/// Script quality metrics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScriptMetrics {
    pub script_id: String,
    pub location: String,
    /// Lines of code
    pub loc: u32,
    /// Cyclomatic complexity
    pub complexity: f64,
    /// Halstead volume
    pub halstead_volume: f64,
    /// Maintainability index
    pub maintainability_index: f64,
    /// Number of functions
    pub function_count: u32,
    /// Safety score (0-100)
    pub safety_score: f64,
    /// Performance score (0-100)
    pub performance_score: f64,
}

/// Script categories
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScriptCategories {
    pub rule_engine_scripts: u32,
    pub htdag_scripts: u32,
    pub prompt_scripts: u32,
    pub custom_scripts: u32,
}

/// BEAM integration analysis
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BeamIntegrationAnalysis {
    /// LuaRunner.execute calls
    pub execute_calls: Vec<ExecuteCallInfo>,
    /// LuaRunner.execute_rule calls
    pub rule_executions: Vec<RuleExecutionInfo>,
    /// LuaAPI usage patterns
    pub api_usage: Vec<ApiUsageInfo>,
    /// Cross-language call patterns
    pub call_patterns: CallPatterns,
}

/// Execute call information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExecuteCallInfo {
    pub location: String,
    pub line: u32,
    pub script_source: ScriptSource,
    pub context_provided: bool,
    pub error_handling_strategy: ErrorHandlingStrategy,
}

/// Rule execution information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RuleExecutionInfo {
    pub location: String,
    pub line: u32,
    pub rule_type: RuleType,
    pub script_source: ScriptSource,
    pub context_provided: bool,
    pub result_validation: bool,
}

/// Rule type
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum RuleType {
    ConfidenceBasedDecision,
    ValidationRule,
    TransformationRule,
    CustomRule,
}

/// API usage information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ApiUsageInfo {
    pub api_module: String,
    pub functions_used: Vec<String>,
    pub usage_count: u32,
    pub locations: Vec<String>,
}

/// Call patterns
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CallPatterns {
    /// Elixir → Lua calls
    pub elixir_to_lua: Vec<CrossLanguageCall>,
    /// Lua → Elixir callbacks
    pub lua_to_elixir: Vec<CrossLanguageCall>,
    /// Call graph complexity
    pub call_graph_complexity: f64,
}

/// Cross-language call
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CrossLanguageCall {
    pub from_location: String,
    pub to_location: String,
    pub call_type: String,
    pub data_marshaling: bool,
}

/// Error handling strategy
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ErrorHandlingStrategy {
    TryRescue,
    CaseMatch,
    WithClause,
    NoHandling,
}

/// Security and safety analysis
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SafetyAnalysis {
    /// Sandboxing patterns
    pub sandbox_usage: Vec<SandboxInfo>,
    /// Timeout usage
    pub timeout_patterns: Vec<TimeoutInfo>,
    /// Error handling coverage
    pub error_handling: ErrorHandlingCoverage,
    /// Security risks detected
    pub security_risks: Vec<SecurityRisk>,
    /// Safety recommendations
    pub recommendations: Vec<SafetyRecommendation>,
    /// Overall safety score (0-100)
    pub overall_safety_score: f64,
}

/// Sandboxing information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SandboxInfo {
    pub location: String,
    pub line: u32,
    pub sandbox_type: SandboxType,
    pub restricted_functions: Vec<String>,
    pub allowed_apis: Vec<String>,
    pub is_properly_configured: bool,
}

/// Sandbox type
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum SandboxType {
    LuerlDefault,
    CustomSandbox,
    NoSandbox,
}

/// Timeout information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TimeoutInfo {
    pub location: String,
    pub line: u32,
    pub timeout_ms: Option<u32>,
    pub timeout_handling: TimeoutHandling,
}

/// Timeout handling
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum TimeoutHandling {
    ExplicitTimeout { duration_ms: u32 },
    DefaultTimeout,
    NoTimeout,
}

/// Error handling coverage
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ErrorHandlingCoverage {
    pub total_lua_calls: u32,
    pub calls_with_error_handling: u32,
    pub coverage_percentage: f64,
    pub unhandled_locations: Vec<String>,
}

/// Security risk
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SecurityRisk {
    pub risk_type: SecurityRiskType,
    pub severity: Severity,
    pub location: String,
    pub line: u32,
    pub description: String,
    pub remediation: String,
}

/// Security risk type
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum SecurityRiskType {
    NoSandboxing,
    NoTimeout,
    UnvalidatedInput,
    SecretLeakage,
    FileSystemAccess,
    NetworkAccess,
    CodeInjection,
    ResourceExhaustion,
}

/// Severity level
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum Severity {
    Critical,
    High,
    Medium,
    Low,
    Info,
}

/// Safety recommendation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SafetyRecommendation {
    pub category: RecommendationCategory,
    pub priority: Priority,
    pub title: String,
    pub description: String,
    pub example: String,
}

/// Recommendation category
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum RecommendationCategory {
    Sandboxing,
    Timeout,
    ErrorHandling,
    InputValidation,
    ScriptQuality,
    Performance,
}

/// Priority level
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum Priority {
    Critical,
    High,
    Medium,
    Low,
}

/// Performance analysis
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PerformanceAnalysis {
    /// Script execution hotspots
    pub hotspots: Vec<PerformanceHotspot>,
    /// Estimated performance impact
    pub performance_metrics: PerformanceMetrics,
    /// Optimization opportunities
    pub optimizations: Vec<OptimizationOpportunity>,
}

/// Performance hotspot
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PerformanceHotspot {
    pub location: String,
    pub line: u32,
    pub hotspot_type: HotspotType,
    pub estimated_frequency: ExecutionFrequency,
    pub estimated_cost_ms: f64,
}

/// Hotspot type
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum HotspotType {
    FrequentScriptExecution,
    ComplexScriptLogic,
    LargeContextInjection,
    MultipleApiLoads,
}

/// Execution frequency
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ExecutionFrequency {
    PerRequest,
    PerTask,
    PerMinute,
    PerHour,
    OnDemand,
}

/// Performance metrics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PerformanceMetrics {
    /// Average script complexity
    pub avg_script_complexity: f64,
    /// Total Lua state creations
    pub total_state_creations: u32,
    /// Estimated total execution time (ms)
    pub estimated_total_exec_time_ms: f64,
    /// Performance score (0-100)
    pub performance_score: f64,
}

/// Optimization opportunity
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OptimizationOpportunity {
    pub location: String,
    pub line: u32,
    pub optimization_type: OptimizationType,
    pub potential_impact: ImpactLevel,
    pub description: String,
    pub example: String,
}

/// Optimization type
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum OptimizationType {
    CacheLuaState,
    PrecompileScript,
    ReduceContextSize,
    MinimizeApiLoads,
    SimplifyLogic,
}

/// Impact level
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ImpactLevel {
    High,
    Medium,
    Low,
}

// ============================================================================
// Default Implementations
// ============================================================================

impl Default for LuerlAnalysisResult {
    fn default() -> Self {
        Self {
            runtime_patterns: LuerlRuntimePatterns::default(),
            script_analysis: LuaScriptAnalysis::default(),
            beam_integration: BeamIntegrationAnalysis::default(),
            safety_analysis: SafetyAnalysis::default(),
            performance_analysis: PerformanceAnalysis::default(),
        }
    }
}

impl Default for LuerlRuntimePatterns {
    fn default() -> Self {
        Self {
            state_creations: Vec::new(),
            script_executions: Vec::new(),
            context_injections: Vec::new(),
            api_loads: Vec::new(),
            pattern_stats: PatternStatistics::default(),
        }
    }
}

impl Default for PatternStatistics {
    fn default() -> Self {
        Self {
            total_lua_states: 0,
            total_executions: 0,
            executions_with_error_handling: 0,
            executions_with_timeout: 0,
            total_api_loads: 0,
            unique_apis_loaded: 0,
        }
    }
}

impl Default for LuaScriptAnalysis {
    fn default() -> Self {
        Self {
            embedded_scripts: Vec::new(),
            db_script_references: Vec::new(),
            script_metrics: Vec::new(),
            script_categories: ScriptCategories::default(),
        }
    }
}

impl Default for ScriptCategories {
    fn default() -> Self {
        Self {
            rule_engine_scripts: 0,
            htdag_scripts: 0,
            prompt_scripts: 0,
            custom_scripts: 0,
        }
    }
}

impl Default for BeamIntegrationAnalysis {
    fn default() -> Self {
        Self {
            execute_calls: Vec::new(),
            rule_executions: Vec::new(),
            api_usage: Vec::new(),
            call_patterns: CallPatterns::default(),
        }
    }
}

impl Default for CallPatterns {
    fn default() -> Self {
        Self {
            elixir_to_lua: Vec::new(),
            lua_to_elixir: Vec::new(),
            call_graph_complexity: 0.0,
        }
    }
}

impl Default for SafetyAnalysis {
    fn default() -> Self {
        Self {
            sandbox_usage: Vec::new(),
            timeout_patterns: Vec::new(),
            error_handling: ErrorHandlingCoverage::default(),
            security_risks: Vec::new(),
            recommendations: Vec::new(),
            overall_safety_score: 0.0,
        }
    }
}

impl Default for ErrorHandlingCoverage {
    fn default() -> Self {
        Self {
            total_lua_calls: 0,
            calls_with_error_handling: 0,
            coverage_percentage: 0.0,
            unhandled_locations: Vec::new(),
        }
    }
}

impl Default for PerformanceAnalysis {
    fn default() -> Self {
        Self {
            hotspots: Vec::new(),
            performance_metrics: PerformanceMetrics::default(),
            optimizations: Vec::new(),
        }
    }
}

impl Default for PerformanceMetrics {
    fn default() -> Self {
        Self {
            avg_script_complexity: 0.0,
            total_state_creations: 0,
            estimated_total_exec_time_ms: 0.0,
            performance_score: 100.0,
        }
    }
}

// ============================================================================
// Analysis Functions
// ============================================================================

/// Analyze Luerl usage in Elixir codebase
pub fn analyze_luerl_usage(elixir_source: &str) -> LuerlAnalysisResult {
    let mut result = LuerlAnalysisResult::default();

    // TODO: Implement analysis using tree-sitter-elixir
    // - Detect Lua.new(), Lua.eval!, Lua.set!, Lua.load_api patterns
    // - Extract embedded ~LUA sigils
    // - Find LuaRunner.execute/execute_rule calls
    // - Analyze error handling and timeout patterns

    result
}

/// Analyze single Lua script for quality and safety
pub fn analyze_lua_script(lua_source: &str) -> ScriptMetrics {
    // TODO: Implement using RCA metrics
    // - Calculate complexity, halstead, maintainability
    // - Detect unsafe patterns
    // - Estimate performance

    ScriptMetrics {
        script_id: "unknown".to_string(),
        location: "unknown".to_string(),
        loc: 0,
        complexity: 0.0,
        halstead_volume: 0.0,
        maintainability_index: 0.0,
        function_count: 0,
        safety_score: 0.0,
        performance_score: 0.0,
    }
}

/// Calculate safety score based on sandboxing, timeouts, error handling
pub fn calculate_safety_score(analysis: &LuerlAnalysisResult) -> f64 {
    let sandbox_score = if analysis.safety_analysis.sandbox_usage.is_empty() {
        0.0
    } else {
        let properly_configured = analysis
            .safety_analysis
            .sandbox_usage
            .iter()
            .filter(|s| s.is_properly_configured)
            .count();
        (properly_configured as f64 / analysis.safety_analysis.sandbox_usage.len() as f64) * 30.0
    };

    let timeout_score = if analysis.runtime_patterns.pattern_stats.total_executions == 0 {
        0.0
    } else {
        (analysis.runtime_patterns.pattern_stats.executions_with_timeout as f64
            / analysis.runtime_patterns.pattern_stats.total_executions as f64)
            * 30.0
    };

    let error_handling_score =
        analysis.safety_analysis.error_handling.coverage_percentage * 0.30;

    let risk_penalty = analysis.safety_analysis.security_risks.len() as f64 * 5.0;

    (sandbox_score + timeout_score + error_handling_score - risk_penalty).max(0.0)
}
