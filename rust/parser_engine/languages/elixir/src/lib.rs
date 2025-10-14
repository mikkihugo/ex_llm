//! Elixir parser implemented with tree-sitter and the parser-framework traits.

use parser_core::{
    Comment, FunctionInfo, Import, LanguageMetrics, LanguageParser, ParseError, AST,
    beam_analysis::{
        BeamAnalysisResult, OtpPatterns, GenServerInfo, SupervisorInfo, ApplicationInfo,
        ActorAnalysis, ProcessSpawningAnalysis, MessagePassingAnalysis, ConcurrencyPatterns,
        FaultToleranceAnalysis, BeamMetrics, LanguageFeatures, ElixirFeatures,
        PhoenixUsage, EctoUsage, LiveViewUsage, NervesUsage, BroadwayUsage,
    },
};
use std::sync::Mutex;
use tree_sitter::{Parser, Query, QueryCursor, StreamingIterator};

/// Elixir language parser backed by tree-sitter.
pub struct ElixirParser {
    parser: Mutex<Parser>,
}

impl ElixirParser {
    /// Create a new Elixir parser instance.
    pub fn new() -> Result<Self, ParseError> {
        let mut parser = Parser::new();
        parser
            .set_language(&tree_sitter_elixir::LANGUAGE.into())
            .map_err(|err| ParseError::TreeSitterError(err.to_string()))?;
        Ok(Self {
            parser: Mutex::new(parser),
        })
    }
}

impl Default for ElixirParser {
    fn default() -> Self {
        Self::new().expect("Elixir parser initialisation must succeed")
    }
}

impl LanguageParser for ElixirParser {
    fn parse(&self, content: &str) -> Result<AST, ParseError> {
        let mut parser = self.parser.lock().expect("parser mutex poisoned");
        let tree = parser
            .parse(content, None)
            .ok_or_else(|| ParseError::ParseError("failed to parse Elixir code".into()))?;

        Ok(AST::new(tree, content.to_owned()))
    }

    fn get_metrics(&self, ast: &AST) -> Result<LanguageMetrics, ParseError> {
        let functions = self.get_functions(ast)?;
        let imports = self.get_imports(ast)?;
        let comments = self.get_comments(ast)?;

        Ok(LanguageMetrics {
            lines_of_code: ast.content.lines().count() as u64,
            lines_of_comments: comments.len() as u64,
            blank_lines: 0, // TODO: implement blank line counting
            total_lines: ast.content.lines().count() as u64,
            functions: functions.len() as u64,
            classes: 0, // Elixir doesn't have classes
            complexity_score: 0.0, // TODO: implement complexity calculation
            ..LanguageMetrics::default()
        })
    }

    fn get_functions(&self, ast: &AST) -> Result<Vec<FunctionInfo>, ParseError> {
        let query = Query::new(
            &tree_sitter_elixir::LANGUAGE.into(),
            r#"
            (call
              target: (identifier) @func_name
            ) @function

            (def
              name: (identifier) @func_name
            ) @function

            (defp
              name: (identifier) @func_name
            ) @function
            "#,
        )
        .map_err(|err| ParseError::ParseError(err.to_string()))?;

        let mut cursor = QueryCursor::new();
        let root = ast.tree.root_node();
        let mut captures = cursor.captures(&query, root, ast.content.as_bytes());

        let mut functions = Vec::new();
        while let Some(&(ref m, _)) = captures.next() {
            for capture in m.captures {
                if capture.index == 1 {
                    let name = capture
                        .node
                        .utf8_text(ast.content.as_bytes())
                        .unwrap_or_default()
                        .to_owned();
                    let start = capture.node.start_position().row + 1;
                    let end = capture.node.end_position().row + 1;
                    functions.push(FunctionInfo {
                        name,
                        parameters: Vec::new(),
                        return_type: None,
                        line_start: start as u32,
                        line_end: end as u32,
                        complexity: 1, // TODO: implement complexity calculation
                    });
                }
            }
        }

        Ok(functions)
    }

    fn get_imports(&self, ast: &AST) -> Result<Vec<Import>, ParseError> {
        let query = Query::new(
            &tree_sitter_elixir::LANGUAGE.into(),
            r#"
            (alias
              (identifier) @module
            ) @import

            (import
              (identifier) @module
            ) @import

            (require
              (identifier) @module
            ) @import
            "#,
        )
        .map_err(|err| ParseError::ParseError(err.to_string()))?;

        let mut cursor = QueryCursor::new();
        let root = ast.tree.root_node();
        let mut captures = cursor.captures(&query, root, ast.content.as_bytes());

        let mut imports = Vec::new();
        while let Some(&(ref m, _)) = captures.next() {
            for capture in m.captures {
                if capture.index == 1 {
                    let path = capture
                        .node
                        .utf8_text(ast.content.as_bytes())
                        .unwrap_or_default()
                        .to_owned();
                    let start = capture.node.start_position().row + 1;
                    let end = capture.node.end_position().row + 1;
                    imports.push(Import {
                        module: path,
                        items: Vec::new(),
                        line: start as u32,
                    });
                }
            }
        }

        Ok(imports)
    }

    fn get_comments(&self, ast: &AST) -> Result<Vec<Comment>, ParseError> {
        let query = Query::new(
            &tree_sitter_elixir::LANGUAGE.into(),
            r#"
            (comment) @comment
            "#,
        )
        .map_err(|err| ParseError::ParseError(err.to_string()))?;

        let mut cursor = QueryCursor::new();
        let root = ast.tree.root_node();
        let mut captures = cursor.captures(&query, root, ast.content.as_bytes());

        let mut comments = Vec::new();
        while let Some(&(ref m, _)) = captures.next() {
            for capture in m.captures {
                if capture.index == 0 {
                    let text = capture
                        .node
                        .utf8_text(ast.content.as_bytes())
                        .unwrap_or_default()
                        .to_owned();
                    let start = capture.node.start_position().row + 1;
                    let end = capture.node.end_position().row + 1;
                    comments.push(Comment {
                        content: text,
                        line: start as u32,
                        column: (capture.node.start_position().column + 1) as u32,
                    });
                }
            }
        }

        Ok(comments)
    }

    fn get_language(&self) -> &str {
        "elixir"
    }

    fn get_extensions(&self) -> Vec<&str> {
        vec!["ex", "exs"]
    }
}

impl ElixirParser {
    /// Perform comprehensive BEAM analysis for Elixir code
    pub fn analyze_beam_patterns(&self, ast: &AST) -> Result<BeamAnalysisResult, ParseError> {
        let otp_patterns = self.analyze_otp_patterns(ast)?;
        let actor_analysis = self.analyze_actor_patterns(ast)?;
        let fault_tolerance = self.analyze_fault_tolerance(ast)?;
        let beam_metrics = self.calculate_beam_metrics(ast, &otp_patterns, &actor_analysis)?;
        let language_features = self.analyze_elixir_features(ast)?;

        Ok(BeamAnalysisResult {
            otp_patterns,
            actor_analysis,
            fault_tolerance,
            beam_metrics,
            language_features: LanguageFeatures {
                elixir: Some(language_features),
                erlang: None,
                gleam: None,
            },
        })
    }

    /// Analyze OTP patterns (GenServer, Supervisor, Application, etc.)
    fn analyze_otp_patterns(&self, ast: &AST) -> Result<OtpPatterns, ParseError> {
        let genservers = self.detect_genservers(ast)?;
        let supervisors = self.detect_supervisors(ast)?;
        let applications = self.detect_applications(ast)?;

        Ok(OtpPatterns {
            genservers,
            supervisors,
            applications,
            genevents: Vec::new(), // TODO: implement GenEvent detection
            genstages: Vec::new(), // TODO: implement GenStage detection
            dynamic_supervisors: Vec::new(), // TODO: implement DynamicSupervisor detection
        })
    }

    /// Detect GenServer implementations
    fn detect_genservers(&self, ast: &AST) -> Result<Vec<GenServerInfo>, ParseError> {
        let query = Query::new(
            &tree_sitter_elixir::LANGUAGE.into(),
            r#"
            (call
              target: (identifier) @behavior
              arguments: (arguments (atom) @module_name)
            ) @call
            "#,
        )
        .map_err(|err| ParseError::ParseError(err.to_string()))?;

        let mut cursor = QueryCursor::new();
        let root = ast.tree.root_node();
        let mut matches = cursor.matches(&query, root, ast.content.as_bytes());

        let mut genservers = Vec::new();
        while let Some(m) = matches.next() {
            for capture in m.captures {
                if capture.index == 0 { // behavior name
                    let behavior = capture
                        .node
                        .utf8_text(ast.content.as_bytes())
                        .unwrap_or_default()
                        .to_owned();
                    
                    if behavior == "use" {
                        // Check if it's GenServer
                        if let Some(next_capture) = m.captures.get(1) {
                            let module_name = next_capture
                                .node
                                .utf8_text(ast.content.as_bytes())
                                .unwrap_or_default()
                                .to_owned();
                            
                            if module_name.contains("GenServer") {
                                let line = capture.node.start_position().row + 1;
                                genservers.push(GenServerInfo {
                                    name: format!("GenServer_{}", line),
                                    module: module_name,
                                    line_start: line as u32,
                                    line_end: line as u32,
                                    callbacks: vec![
                                        "init/1".to_string(),
                                        "handle_call/3".to_string(),
                                        "handle_cast/2".to_string(),
                                        "handle_info/2".to_string(),
                                        "terminate/2".to_string(),
                                        "code_change/3".to_string(),
                                    ],
                                    state_type: None,
                                    message_types: Vec::new(),
                                });
                            }
                        }
                    }
                }
            }
        }

        Ok(genservers)
    }

    /// Detect Supervisor implementations
    fn detect_supervisors(&self, ast: &AST) -> Result<Vec<SupervisorInfo>, ParseError> {
        let query = Query::new(
            &tree_sitter_elixir::LANGUAGE.into(),
            r#"
            (call
              target: (identifier) @behavior
              arguments: (arguments (atom) @module_name)
            ) @call
            "#,
        )
        .map_err(|err| ParseError::ParseError(err.to_string()))?;

        let mut cursor = QueryCursor::new();
        let root = ast.tree.root_node();
        let mut matches = cursor.matches(&query, root, ast.content.as_bytes());

        let mut supervisors = Vec::new();
        while let Some(m) = matches.next() {
            for capture in m.captures {
                if capture.index == 0 { // behavior name
                    let behavior = capture
                        .node
                        .utf8_text(ast.content.as_bytes())
                        .unwrap_or_default()
                        .to_owned();
                    
                    if behavior == "use" {
                        if let Some(next_capture) = m.captures.get(1) {
                            let module_name = next_capture
                                .node
                                .utf8_text(ast.content.as_bytes())
                                .unwrap_or_default()
                                .to_owned();
                            
                            if module_name.contains("Supervisor") {
                                let line = capture.node.start_position().row + 1;
                                supervisors.push(SupervisorInfo {
                                    name: format!("Supervisor_{}", line),
                                    module: module_name,
                                    line_start: line as u32,
                                    line_end: line as u32,
                                    strategy: Some(":one_for_one".to_string()),
                                    children: Vec::new(),
                                });
                            }
                        }
                    }
                }
            }
        }

        Ok(supervisors)
    }

    /// Detect Application implementations
    fn detect_applications(&self, ast: &AST) -> Result<Vec<ApplicationInfo>, ParseError> {
        let query = Query::new(
            &tree_sitter_elixir::LANGUAGE.into(),
            r#"
            (call
              target: (identifier) @behavior
              arguments: (arguments (atom) @module_name)
            ) @call
            "#,
        )
        .map_err(|err| ParseError::ParseError(err.to_string()))?;

        let mut cursor = QueryCursor::new();
        let root = ast.tree.root_node();
        let mut matches = cursor.matches(&query, root, ast.content.as_bytes());

        let mut applications = Vec::new();
        while let Some(m) = matches.next() {
            for capture in m.captures {
                if capture.index == 0 { // behavior name
                    let behavior = capture
                        .node
                        .utf8_text(ast.content.as_bytes())
                        .unwrap_or_default()
                        .to_owned();
                    
                    if behavior == "use" {
                        if let Some(next_capture) = m.captures.get(1) {
                            let module_name = next_capture
                                .node
                                .utf8_text(ast.content.as_bytes())
                                .unwrap_or_default()
                                .to_owned();
                            
                            if module_name.contains("Application") {
                                let line = capture.node.start_position().row + 1;
                                applications.push(ApplicationInfo {
                                    name: format!("Application_{}", line),
                                    module: module_name,
                                    line_start: line as u32,
                                    line_end: line as u32,
                                    r#mod: None,
                                    start_phases: Vec::new(),
                                    applications: Vec::new(),
                                });
                            }
                        }
                    }
                }
            }
        }

        Ok(applications)
    }

    /// Analyze actor patterns (process spawning, message passing)
    fn analyze_actor_patterns(&self, ast: &AST) -> Result<ActorAnalysis, ParseError> {
        let process_spawning = self.analyze_process_spawning(ast)?;
        let message_passing = self.analyze_message_passing(ast)?;
        let concurrency_patterns = self.analyze_concurrency_patterns(ast)?;

        Ok(ActorAnalysis {
            process_spawning,
            message_passing,
            concurrency_patterns,
        })
    }

    /// Analyze process spawning patterns
    fn analyze_process_spawning(&self, ast: &AST) -> Result<ProcessSpawningAnalysis, ParseError> {
        // TODO: Implement comprehensive process spawning analysis
        Ok(ProcessSpawningAnalysis::default())
    }

    /// Analyze message passing patterns
    fn analyze_message_passing(&self, ast: &AST) -> Result<MessagePassingAnalysis, ParseError> {
        // TODO: Implement comprehensive message passing analysis
        Ok(MessagePassingAnalysis::default())
    }

    /// Analyze concurrency patterns
    fn analyze_concurrency_patterns(&self, ast: &AST) -> Result<ConcurrencyPatterns, ParseError> {
        // TODO: Implement comprehensive concurrency pattern analysis
        Ok(ConcurrencyPatterns::default())
    }

    /// Analyze fault tolerance patterns
    fn analyze_fault_tolerance(&self, ast: &AST) -> Result<FaultToleranceAnalysis, ParseError> {
        // TODO: Implement comprehensive fault tolerance analysis
        Ok(FaultToleranceAnalysis::default())
    }

    /// Calculate BEAM-specific metrics
    fn calculate_beam_metrics(
        &self,
        ast: &AST,
        otp_patterns: &OtpPatterns,
        actor_analysis: &ActorAnalysis,
    ) -> Result<BeamMetrics, ParseError> {
        let estimated_process_count = otp_patterns.genservers.len() as u32 + 
                                    otp_patterns.supervisors.len() as u32 +
                                    otp_patterns.applications.len() as u32;
        
        let supervision_complexity = otp_patterns.supervisors.len() as f64 * 2.0 +
                                   otp_patterns.genservers.len() as f64 * 1.5;
        
        let actor_complexity = actor_analysis.process_spawning.spawn_calls.len() as f64 +
                             actor_analysis.message_passing.send_calls.len() as f64;

        Ok(BeamMetrics {
            estimated_process_count,
            estimated_message_queue_size: 0, // TODO: implement queue size estimation
            estimated_memory_usage: 0, // TODO: implement memory usage estimation
            gc_pressure: 0.0, // TODO: implement GC pressure calculation
            supervision_complexity,
            actor_complexity,
            fault_tolerance_score: 0.0, // TODO: implement fault tolerance scoring
        })
    }

    /// Analyze Elixir-specific features (Phoenix, Ecto, LiveView, etc.)
    fn analyze_elixir_features(&self, ast: &AST) -> Result<ElixirFeatures, ParseError> {
        let phoenix_usage = self.analyze_phoenix_usage(ast)?;
        let ecto_usage = self.analyze_ecto_usage(ast)?;
        let liveview_usage = self.analyze_liveview_usage(ast)?;
        let nerves_usage = self.analyze_nerves_usage(ast)?;
        let broadway_usage = self.analyze_broadway_usage(ast)?;

        Ok(ElixirFeatures {
            phoenix_usage,
            ecto_usage,
            liveview_usage,
            nerves_usage,
            broadway_usage,
        })
    }

    /// Analyze Phoenix framework usage
    fn analyze_phoenix_usage(&self, ast: &AST) -> Result<PhoenixUsage, ParseError> {
        // TODO: Implement Phoenix usage analysis
        Ok(PhoenixUsage {
            controllers: Vec::new(),
            views: Vec::new(),
            templates: Vec::new(),
            channels: Vec::new(),
            live_views: Vec::new(),
        })
    }

    /// Analyze Ecto usage
    fn analyze_ecto_usage(&self, ast: &AST) -> Result<EctoUsage, ParseError> {
        // TODO: Implement Ecto usage analysis
        Ok(EctoUsage {
            schemas: Vec::new(),
            migrations: Vec::new(),
            queries: Vec::new(),
        })
    }

    /// Analyze LiveView usage
    fn analyze_liveview_usage(&self, ast: &AST) -> Result<LiveViewUsage, ParseError> {
        // TODO: Implement LiveView usage analysis
        Ok(LiveViewUsage {
            live_views: Vec::new(),
            live_components: Vec::new(),
        })
    }

    /// Analyze Nerves usage
    fn analyze_nerves_usage(&self, ast: &AST) -> Result<NervesUsage, ParseError> {
        // TODO: Implement Nerves usage analysis
        Ok(NervesUsage {
            target: None,
            system: None,
            configs: Vec::new(),
        })
    }

    /// Analyze Broadway usage
    fn analyze_broadway_usage(&self, ast: &AST) -> Result<BroadwayUsage, ParseError> {
        // TODO: Implement Broadway usage analysis
        Ok(BroadwayUsage {
            producers: Vec::new(),
            processors: Vec::new(),
            batchers: Vec::new(),
        })
    }
}
