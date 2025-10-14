//! BEAM Language Analysis - Comprehensive analysis for Elixir, Erlang, and Gleam
//!
//! This module provides BEAM-specific analysis capabilities including:
//! - OTP pattern detection (GenServer, Supervisor, Application)
//! - Actor model analysis (process spawning, message passing)
//! - Fault tolerance patterns (try/catch, rescue, let it crash)
//! - BEAM-specific metrics (process count, message queue analysis)

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// BEAM-specific analysis result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BeamAnalysisResult {
    /// OTP patterns detected in the code
    pub otp_patterns: OtpPatterns,
    /// Actor model analysis
    pub actor_analysis: ActorAnalysis,
    /// Fault tolerance patterns
    pub fault_tolerance: FaultToleranceAnalysis,
    /// BEAM-specific metrics
    pub beam_metrics: BeamMetrics,
    /// Language-specific features
    pub language_features: LanguageFeatures,
}

/// OTP (Open Telecom Platform) patterns
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OtpPatterns {
    /// GenServer implementations
    pub genservers: Vec<GenServerInfo>,
    /// Supervisor implementations
    pub supervisors: Vec<SupervisorInfo>,
    /// Application implementations
    pub applications: Vec<ApplicationInfo>,
    /// GenEvent implementations
    pub genevents: Vec<GenEventInfo>,
    /// GenStage implementations
    pub genstages: Vec<GenStageInfo>,
    /// DynamicSupervisor implementations
    pub dynamic_supervisors: Vec<DynamicSupervisorInfo>,
}

/// GenServer information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GenServerInfo {
    pub name: String,
    pub module: String,
    pub line_start: u32,
    pub line_end: u32,
    pub callbacks: Vec<String>, // init, handle_call, handle_cast, etc.
    pub state_type: Option<String>,
    pub message_types: Vec<String>,
}

/// Supervisor information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SupervisorInfo {
    pub name: String,
    pub module: String,
    pub line_start: u32,
    pub line_end: u32,
    pub strategy: Option<String>, // :one_for_one, :one_for_all, etc.
    pub children: Vec<ChildSpec>,
}

/// Child specification for supervisors
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChildSpec {
    pub id: String,
    pub module: String,
    pub start_function: String,
    pub restart: Option<String>, // :permanent, :temporary, :transient
    pub shutdown: Option<String>,
}

/// Application information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ApplicationInfo {
    pub name: String,
    pub module: String,
    pub line_start: u32,
    pub line_end: u32,
    pub r#mod: Option<String>, // Application module
    pub start_phases: Vec<String>,
    pub applications: Vec<String>, // Dependencies
}

/// GenEvent information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GenEventInfo {
    pub name: String,
    pub module: String,
    pub line_start: u32,
    pub line_end: u32,
    pub handlers: Vec<String>,
}

/// GenStage information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GenStageInfo {
    pub name: String,
    pub module: String,
    pub line_start: u32,
    pub line_end: u32,
    pub stage_type: String, // :producer, :consumer, :producer_consumer
    pub subscriptions: Vec<String>,
}

/// DynamicSupervisor information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DynamicSupervisorInfo {
    pub name: String,
    pub module: String,
    pub line_start: u32,
    pub line_end: u32,
    pub strategy: Option<String>,
    pub max_children: Option<u32>,
}

/// Actor model analysis
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ActorAnalysis {
    /// Process spawning patterns
    pub process_spawning: ProcessSpawningAnalysis,
    /// Message passing patterns
    pub message_passing: MessagePassingAnalysis,
    /// Concurrency patterns
    pub concurrency_patterns: ConcurrencyPatterns,
}

/// Process spawning analysis
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProcessSpawningAnalysis {
    /// spawn/1 calls
    pub spawn_calls: Vec<SpawnCall>,
    /// spawn_link/1 calls
    pub spawn_link_calls: Vec<SpawnCall>,
    /// Task.async calls (Elixir)
    pub task_async_calls: Vec<SpawnCall>,
    /// Process.flag usage
    pub process_flags: Vec<ProcessFlag>,
    /// Process registration
    pub process_registrations: Vec<ProcessRegistration>,
}

/// Spawn call information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SpawnCall {
    pub function: String,
    pub line: u32,
    pub is_linked: bool,
    pub is_monitored: bool,
}

/// Process flag information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProcessFlag {
    pub flag: String,
    pub value: String,
    pub line: u32,
}

/// Process registration information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProcessRegistration {
    pub name: String,
    pub pid: Option<String>,
    pub line: u32,
}

/// Message passing analysis
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MessagePassingAnalysis {
    /// send/2 calls
    pub send_calls: Vec<SendCall>,
    /// receive expressions
    pub receive_expressions: Vec<ReceiveExpression>,
    /// message patterns
    pub message_patterns: Vec<MessagePattern>,
    /// mailbox analysis
    pub mailbox_analysis: MailboxAnalysis,
}

/// Send call information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SendCall {
    pub target: String,
    pub message: String,
    pub line: u32,
}

/// Receive expression information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ReceiveExpression {
    pub patterns: Vec<String>,
    pub after_clause: Option<String>,
    pub line: u32,
    pub line_end: u32,
}

/// Message pattern information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MessagePattern {
    pub pattern: String,
    pub guard: Option<String>,
    pub line: u32,
}

/// Mailbox analysis
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MailboxAnalysis {
    /// Estimated message queue size
    pub estimated_queue_size: u32,
    /// Message processing patterns
    pub processing_patterns: Vec<String>,
    /// Potential bottlenecks
    pub bottlenecks: Vec<String>,
}

/// Concurrency patterns
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConcurrencyPatterns {
    /// Agent usage (Elixir)
    pub agents: Vec<AgentInfo>,
    /// ETS table usage
    pub ets_tables: Vec<EtsTableInfo>,
    /// Mnesia usage
    pub mnesia_usage: Vec<MnesiaUsage>,
    /// Port usage
    pub port_usage: Vec<PortUsage>,
}

/// Agent information (Elixir)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AgentInfo {
    pub name: String,
    pub module: String,
    pub line_start: u32,
    pub line_end: u32,
    pub state_type: Option<String>,
    pub update_functions: Vec<String>,
}

/// ETS table information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EtsTableInfo {
    pub name: String,
    pub r#type: String, // :set, :ordered_set, :bag, :duplicate_bag
    pub protection: String, // :public, :protected, :private
    pub line: u32,
}

/// Mnesia usage information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MnesiaUsage {
    pub operation: String,
    pub table: String,
    pub line: u32,
}

/// Port usage information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PortUsage {
    pub port_name: String,
    pub command: String,
    pub line: u32,
}

/// Fault tolerance analysis
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FaultToleranceAnalysis {
    /// try/catch expressions
    pub try_catch_expressions: Vec<TryCatchExpression>,
    /// rescue clauses
    pub rescue_clauses: Vec<RescueClause>,
    /// let it crash patterns
    pub let_it_crash_patterns: Vec<LetItCrashPattern>,
    /// supervision tree depth
    pub supervision_tree_depth: u32,
    /// error handling strategies
    pub error_handling_strategies: Vec<String>,
}

/// Try/catch expression information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TryCatchExpression {
    pub line: u32,
    pub line_end: u32,
    pub catch_clauses: Vec<String>,
    pub rescue_clauses: Vec<String>,
    pub after_clause: Option<String>,
}

/// Rescue clause information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RescueClause {
    pub exception_type: String,
    pub pattern: String,
    pub line: u32,
}

/// Let it crash pattern information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LetItCrashPattern {
    pub function: String,
    pub line: u32,
    pub reason: String,
}

/// BEAM-specific metrics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BeamMetrics {
    /// Process count estimation
    pub estimated_process_count: u32,
    /// Message queue size estimation
    pub estimated_message_queue_size: u32,
    /// Memory usage estimation (in bytes)
    pub estimated_memory_usage: u64,
    /// Garbage collection pressure
    pub gc_pressure: f64,
    /// Supervision tree complexity
    pub supervision_complexity: f64,
    /// Actor model complexity
    pub actor_complexity: f64,
    /// Fault tolerance score (0-100)
    pub fault_tolerance_score: f64,
}

/// Language-specific features
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LanguageFeatures {
    /// Elixir-specific features
    pub elixir: Option<ElixirFeatures>,
    /// Erlang-specific features
    pub erlang: Option<ErlangFeatures>,
    /// Gleam-specific features
    pub gleam: Option<GleamFeatures>,
}

/// Elixir-specific features
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ElixirFeatures {
    /// Phoenix framework usage
    pub phoenix_usage: PhoenixUsage,
    /// Ecto usage
    pub ecto_usage: EctoUsage,
    /// LiveView usage
    pub liveview_usage: LiveViewUsage,
    /// Nerves usage
    pub nerves_usage: NervesUsage,
    /// Broadway usage
    pub broadway_usage: BroadwayUsage,
}

/// Phoenix framework usage
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PhoenixUsage {
    pub controllers: Vec<ControllerInfo>,
    pub views: Vec<ViewInfo>,
    pub templates: Vec<TemplateInfo>,
    pub channels: Vec<ChannelInfo>,
    pub live_views: Vec<LiveViewInfo>,
}

/// Controller information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ControllerInfo {
    pub name: String,
    pub module: String,
    pub actions: Vec<String>,
    pub line_start: u32,
    pub line_end: u32,
}

/// View information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ViewInfo {
    pub name: String,
    pub module: String,
    pub functions: Vec<String>,
    pub line_start: u32,
    pub line_end: u32,
}

/// Template information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TemplateInfo {
    pub name: String,
    pub path: String,
    pub line_count: u32,
}

/// Channel information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChannelInfo {
    pub name: String,
    pub module: String,
    pub join_handlers: Vec<String>,
    pub handle_in_handlers: Vec<String>,
    pub line_start: u32,
    pub line_end: u32,
}

/// LiveView information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LiveViewInfo {
    pub name: String,
    pub module: String,
    pub mount_handlers: Vec<String>,
    pub handle_event_handlers: Vec<String>,
    pub line_start: u32,
    pub line_end: u32,
}

/// Ecto usage
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EctoUsage {
    pub schemas: Vec<SchemaInfo>,
    pub migrations: Vec<MigrationInfo>,
    pub queries: Vec<QueryInfo>,
}

/// Schema information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SchemaInfo {
    pub name: String,
    pub module: String,
    pub fields: Vec<FieldInfo>,
    pub line_start: u32,
    pub line_end: u32,
}

/// Field information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FieldInfo {
    pub name: String,
    pub r#type: String,
    pub required: bool,
    pub line: u32,
}

/// Migration information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MigrationInfo {
    pub version: String,
    pub name: String,
    pub operations: Vec<String>,
    pub line_start: u32,
    pub line_end: u32,
}

/// Query information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct QueryInfo {
    pub name: String,
    pub query_type: String, // :select, :insert, :update, :delete
    pub line: u32,
}

/// LiveView usage
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LiveViewUsage {
    pub live_views: Vec<LiveViewInfo>,
    pub live_components: Vec<LiveComponentInfo>,
}

/// Live component information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LiveComponentInfo {
    pub name: String,
    pub module: String,
    pub update_handlers: Vec<String>,
    pub line_start: u32,
    pub line_end: u32,
}

/// Nerves usage
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NervesUsage {
    pub target: Option<String>,
    pub system: Option<String>,
    pub configs: Vec<String>,
}

/// Broadway usage
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BroadwayUsage {
    pub producers: Vec<ProducerInfo>,
    pub processors: Vec<ProcessorInfo>,
    pub batchers: Vec<BatcherInfo>,
}

/// Producer information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProducerInfo {
    pub name: String,
    pub module: String,
    pub line_start: u32,
    pub line_end: u32,
}

/// Processor information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProcessorInfo {
    pub name: String,
    pub module: String,
    pub line_start: u32,
    pub line_end: u32,
}

/// Batcher information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BatcherInfo {
    pub name: String,
    pub module: String,
    pub line_start: u32,
    pub line_end: u32,
}

/// Erlang-specific features
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ErlangFeatures {
    /// OTP behaviors
    pub otp_behaviors: Vec<OtpBehavior>,
    /// Common Test usage
    pub common_test_usage: CommonTestUsage,
    /// Dialyzer usage
    pub dialyzer_usage: DialyzerUsage,
}

/// OTP behavior information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OtpBehavior {
    pub behavior: String,
    pub module: String,
    pub callbacks: Vec<String>,
    pub line_start: u32,
    pub line_end: u32,
}

/// Common Test usage
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CommonTestUsage {
    pub test_suites: Vec<TestSuiteInfo>,
    pub test_cases: Vec<TestCaseInfo>,
}

/// Test suite information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TestSuiteInfo {
    pub name: String,
    pub module: String,
    pub line_start: u32,
    pub line_end: u32,
}

/// Test case information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TestCaseInfo {
    pub name: String,
    pub module: String,
    pub line: u32,
}

/// Dialyzer usage
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DialyzerUsage {
    pub type_specs: Vec<TypeSpec>,
    pub contracts: Vec<Contract>,
}

/// Type specification
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TypeSpec {
    pub name: String,
    pub spec: String,
    pub line: u32,
}

/// Contract information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Contract {
    pub name: String,
    pub contract: String,
    pub line: u32,
}

/// Gleam-specific features
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GleamFeatures {
    /// Type system analysis
    pub type_analysis: TypeAnalysis,
    /// Functional programming features
    pub functional_analysis: FunctionalAnalysis,
    /// BEAM integration patterns
    pub beam_integration: BeamIntegration,
    /// Modern language features
    pub modern_features: ModernFeatures,
    /// Web development patterns
    pub web_patterns: WebPatterns,
}

/// Type system analysis
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TypeAnalysis {
    /// Custom types defined
    pub custom_types: Vec<CustomType>,
    /// Type aliases
    pub type_aliases: Vec<TypeAlias>,
    /// Type features used
    pub type_features: HashMap<String, bool>,
}

/// Custom type information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CustomType {
    pub name: String,
    pub module: String,
    pub constructors: Vec<String>,
    pub line_start: u32,
    pub line_end: u32,
}

/// Type alias information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TypeAlias {
    pub name: String,
    pub module: String,
    pub aliased_type: String,
    pub line: u32,
}

/// Functional programming analysis
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FunctionalAnalysis {
    /// Immutability score (0-100)
    pub immutability_score: f64,
    /// Pattern matching complexity
    pub pattern_match_complexity: f64,
    /// Higher-order function usage
    pub functional_features: HashMap<String, bool>,
}

/// BEAM integration analysis
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BeamIntegration {
    /// Interop patterns with BEAM
    pub interop_patterns: Vec<String>,
    /// OTP usage
    pub otp_usage: Vec<String>,
}

/// Modern language features
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ModernFeatures {
    /// Language features used
    pub language_features: HashMap<String, bool>,
}

/// Web development patterns
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WebPatterns {
    /// HTTP patterns
    pub http_patterns: Vec<String>,
    /// Web safety features
    pub web_safety_features: Vec<String>,
}

impl Default for BeamAnalysisResult {
    fn default() -> Self {
        Self {
            otp_patterns: OtpPatterns::default(),
            actor_analysis: ActorAnalysis::default(),
            fault_tolerance: FaultToleranceAnalysis::default(),
            beam_metrics: BeamMetrics::default(),
            language_features: LanguageFeatures::default(),
        }
    }
}

impl Default for OtpPatterns {
    fn default() -> Self {
        Self {
            genservers: Vec::new(),
            supervisors: Vec::new(),
            applications: Vec::new(),
            genevents: Vec::new(),
            genstages: Vec::new(),
            dynamic_supervisors: Vec::new(),
        }
    }
}

impl Default for ActorAnalysis {
    fn default() -> Self {
        Self {
            process_spawning: ProcessSpawningAnalysis::default(),
            message_passing: MessagePassingAnalysis::default(),
            concurrency_patterns: ConcurrencyPatterns::default(),
        }
    }
}

impl Default for ProcessSpawningAnalysis {
    fn default() -> Self {
        Self {
            spawn_calls: Vec::new(),
            spawn_link_calls: Vec::new(),
            task_async_calls: Vec::new(),
            process_flags: Vec::new(),
            process_registrations: Vec::new(),
        }
    }
}

impl Default for MessagePassingAnalysis {
    fn default() -> Self {
        Self {
            send_calls: Vec::new(),
            receive_expressions: Vec::new(),
            message_patterns: Vec::new(),
            mailbox_analysis: MailboxAnalysis::default(),
        }
    }
}

impl Default for MailboxAnalysis {
    fn default() -> Self {
        Self {
            estimated_queue_size: 0,
            processing_patterns: Vec::new(),
            bottlenecks: Vec::new(),
        }
    }
}

impl Default for ConcurrencyPatterns {
    fn default() -> Self {
        Self {
            agents: Vec::new(),
            ets_tables: Vec::new(),
            mnesia_usage: Vec::new(),
            port_usage: Vec::new(),
        }
    }
}

impl Default for FaultToleranceAnalysis {
    fn default() -> Self {
        Self {
            try_catch_expressions: Vec::new(),
            rescue_clauses: Vec::new(),
            let_it_crash_patterns: Vec::new(),
            supervision_tree_depth: 0,
            error_handling_strategies: Vec::new(),
        }
    }
}

impl Default for BeamMetrics {
    fn default() -> Self {
        Self {
            estimated_process_count: 0,
            estimated_message_queue_size: 0,
            estimated_memory_usage: 0,
            gc_pressure: 0.0,
            supervision_complexity: 0.0,
            actor_complexity: 0.0,
            fault_tolerance_score: 0.0,
        }
    }
}

impl Default for LanguageFeatures {
    fn default() -> Self {
        Self {
            elixir: None,
            erlang: None,
            gleam: None,
        }
    }
}