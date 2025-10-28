//! Erlang parser implemented with tree-sitter.

use parser_core::{
    beam_analysis::{
        ActorAnalysis, ApplicationInfo, BeamAnalysisResult, BeamMetrics, CommonTestUsage,
        ConcurrencyPatterns, DialyzerUsage, ErlangFeatures, FaultToleranceAnalysis, GenServerInfo,
        LanguageFeatures, MessagePassingAnalysis, OtpPatterns, ProcessSpawningAnalysis,
        SupervisorInfo,
    },
    Comment, FunctionInfo, Import, LanguageMetrics, LanguageParser, ParseError, AST,
};
use std::sync::Mutex;
use tree_sitter::{Parser, Query, QueryCursor, StreamingIterator};

/// Erlang language parser backed by tree-sitter.
pub struct ErlangParser {
    parser: Mutex<Parser>,
}

impl ErlangParser {
    pub fn new() -> Result<Self, ParseError> {
        let mut parser = Parser::new();
        parser
            .set_language(&tree_sitter_erlang::LANGUAGE.into())
            .map_err(|err| ParseError::TreeSitterError(err.to_string()))?;
        Ok(Self {
            parser: Mutex::new(parser),
        })
    }
}

impl Default for ErlangParser {
    fn default() -> Self {
        Self::new().expect("Erlang parser initialisation must succeed")
    }
}

impl LanguageParser for ErlangParser {
    fn parse(&self, content: &str) -> Result<AST, ParseError> {
        let mut parser = self.parser.lock().expect("parser mutex poisoned");
        let tree = parser
            .parse(content, None)
            .ok_or_else(|| ParseError::ParseError("failed to parse Erlang code".into()))?;
        Ok(AST::new(tree, content.to_owned()))
    }

    fn get_metrics(&self, ast: &AST) -> Result<LanguageMetrics, ParseError> {
        let functions = self.get_functions(ast)?;
        let imports = self.get_imports(ast)?;
        let comments = self.get_comments(ast)?;

        // Use RCA for real complexity and accurate LOC metrics
        let (complexity_score, _sloc, ploc, cloc, blank_lines) =
            parser_core::calculate_rca_complexity(&ast.content, "erlang").unwrap_or((
                1.0,
                ast.content.lines().count() as u64,
                ast.content.lines().count() as u64,
                comments.len() as u64,
                0,
            ));

        Ok(LanguageMetrics {
            lines_of_code: ploc.saturating_sub(blank_lines + cloc),
            lines_of_comments: cloc,
            blank_lines,
            total_lines: ast.content.lines().count() as u64,
            functions: functions.len() as u64,
            classes: 0,       // Erlang doesn't have classes
            complexity_score, // Real cyclomatic complexity from RCA!
            imports: imports.len() as u64,
        })
    }

    fn get_functions(&self, ast: &AST) -> Result<Vec<FunctionInfo>, ParseError> {
        let query = Query::new(
            &tree_sitter_erlang::LANGUAGE.into(),
            r#"
            (function_clause
                name: (atom) @function_name
                arguments: (arguments)? @arguments
            ) @function
            "#,
        )
        .map_err(|err| ParseError::ParseError(err.to_string()))?;

        let mut cursor = QueryCursor::new();
        let root = ast.tree.root_node();
        let mut matches = cursor.matches(&query, root, ast.content.as_bytes());

        let mut functions = Vec::new();
        while let Some(m) = matches.next() {
            for capture in m.captures {
                if capture.index == 1 {
                    let name = capture
                        .node
                        .utf8_text(ast.content.as_bytes())
                        .unwrap_or_default()
                        .to_owned();
                    let start = capture.node.start_position().row + 1;
                    let _end = capture.node.end_position().row + 1;
                    functions.push(FunctionInfo {
                        name,
                        parameters: Vec::new(),
                        return_type: None,
                        line_start: start as u32,
                        line_end: _end as u32,
                        complexity: 1, // TODO: implement complexity calculation
                        decorators: Vec::new(),
                        docstring: None,
                        is_async: false,
                        is_generator: false,
                        signature: None,
                        body: None,
                    });
                }
            }
        }

        Ok(functions)
    }

    fn get_imports(&self, ast: &AST) -> Result<Vec<Import>, ParseError> {
        let query = Query::new(
            &tree_sitter_erlang::LANGUAGE.into(),
            r#"
            (import_attribute
                module: (atom) @module
            ) @import
            "#,
        )
        .map_err(|err| ParseError::ParseError(err.to_string()))?;

        let mut cursor = QueryCursor::new();
        let root = ast.tree.root_node();
        let mut matches = cursor.matches(&query, root, ast.content.as_bytes());

        let mut imports = Vec::new();
        while let Some(m) = matches.next() {
            for capture in m.captures {
                if capture.index == 1 {
                    let path = capture
                        .node
                        .utf8_text(ast.content.as_bytes())
                        .unwrap_or_default()
                        .to_owned();
                    let start = capture.node.start_position().row + 1;
                    let _end = capture.node.end_position().row + 1;
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
            &tree_sitter_erlang::LANGUAGE.into(),
            r#"
            (comment) @comment
            "#,
        )
        .map_err(|err| ParseError::ParseError(err.to_string()))?;

        let mut cursor = QueryCursor::new();
        let root = ast.tree.root_node();
        let mut matches = cursor.matches(&query, root, ast.content.as_bytes());

        let mut comments = Vec::new();
        while let Some(m) = matches.next() {
            for capture in m.captures {
                if capture.index == 0 {
                    let text = capture
                        .node
                        .utf8_text(ast.content.as_bytes())
                        .unwrap_or_default()
                        .to_owned();
                    let start = capture.node.start_position().row + 1;
                    let _end = capture.node.end_position().row + 1;
                    comments.push(Comment {
                        content: text,
                        line: start as u32,
                        column: (capture.node.start_position().column + 1) as u32,
                        kind: "line".to_string(), // Erlang comments are always line comments
                    });
                }
            }
        }

        Ok(comments)
    }

    fn get_language(&self) -> &str {
        "erlang"
    }

    fn get_extensions(&self) -> Vec<&str> {
        vec!["erl", "hrl"]
    }
}

impl ErlangParser {
    /// Perform comprehensive BEAM analysis for Erlang code
    pub fn analyze_beam_patterns(&self, ast: &AST) -> Result<BeamAnalysisResult, ParseError> {
        let otp_patterns = self.analyze_otp_patterns(ast)?;
        let actor_analysis = self.analyze_actor_patterns(ast)?;
        let fault_tolerance = self.analyze_fault_tolerance(ast)?;
        let beam_metrics = self.calculate_beam_metrics(ast, &otp_patterns, &actor_analysis)?;
        let language_features = self.analyze_erlang_features(ast)?;

        Ok(BeamAnalysisResult {
            otp_patterns,
            actor_analysis,
            fault_tolerance,
            beam_metrics,
            language_features: LanguageFeatures {
                elixir: None,
                erlang: Some(language_features),
                gleam: None,
            },
        })
    }

    /// Analyze OTP patterns (gen_server, supervisor, application, etc.)
    fn analyze_otp_patterns(&self, ast: &AST) -> Result<OtpPatterns, ParseError> {
        let genservers = self.detect_gen_servers(ast)?;
        let supervisors = self.detect_supervisors(ast)?;
        let applications = self.detect_applications(ast)?;

        Ok(OtpPatterns {
            genservers,
            supervisors,
            applications,
            genevents: Vec::new(), // TODO: implement gen_event detection
            genstages: Vec::new(), // TODO: implement gen_stage detection
            dynamic_supervisors: Vec::new(), // TODO: implement dynamic_supervisor detection
        })
    }

    /// Detect gen_server implementations
    fn detect_gen_servers(&self, ast: &AST) -> Result<Vec<GenServerInfo>, ParseError> {
        let query = Query::new(
            &tree_sitter_erlang::LANGUAGE.into(),
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
                if capture.index == 0 {
                    // behavior name
                    let behavior = capture
                        .node
                        .utf8_text(ast.content.as_bytes())
                        .unwrap_or_default()
                        .to_owned();

                    if behavior == "behaviour" {
                        if let Some(next_capture) = m.captures.get(1) {
                            let module_name = next_capture
                                .node
                                .utf8_text(ast.content.as_bytes())
                                .unwrap_or_default()
                                .to_owned();

                            if module_name.contains("gen_server") {
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

    /// Detect supervisor implementations
    fn detect_supervisors(&self, ast: &AST) -> Result<Vec<SupervisorInfo>, ParseError> {
        let query = Query::new(
            &tree_sitter_erlang::LANGUAGE.into(),
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
                if capture.index == 0 {
                    // behavior name
                    let behavior = capture
                        .node
                        .utf8_text(ast.content.as_bytes())
                        .unwrap_or_default()
                        .to_owned();

                    if behavior == "behaviour" {
                        if let Some(next_capture) = m.captures.get(1) {
                            let module_name = next_capture
                                .node
                                .utf8_text(ast.content.as_bytes())
                                .unwrap_or_default()
                                .to_owned();

                            if module_name.contains("supervisor") {
                                let line = capture.node.start_position().row + 1;
                                supervisors.push(SupervisorInfo {
                                    name: format!("Supervisor_{}", line),
                                    module: module_name,
                                    line_start: line as u32,
                                    line_end: line as u32,
                                    strategy: Some("one_for_one".to_string()),
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

    /// Detect application implementations
    fn detect_applications(&self, ast: &AST) -> Result<Vec<ApplicationInfo>, ParseError> {
        let query = Query::new(
            &tree_sitter_erlang::LANGUAGE.into(),
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
                if capture.index == 0 {
                    // behavior name
                    let behavior = capture
                        .node
                        .utf8_text(ast.content.as_bytes())
                        .unwrap_or_default()
                        .to_owned();

                    if behavior == "behaviour" {
                        if let Some(next_capture) = m.captures.get(1) {
                            let module_name = next_capture
                                .node
                                .utf8_text(ast.content.as_bytes())
                                .unwrap_or_default()
                                .to_owned();

                            if module_name.contains("application") {
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
    fn analyze_process_spawning(&self, _ast: &AST) -> Result<ProcessSpawningAnalysis, ParseError> {
        // TODO: Implement comprehensive process spawning analysis
        Ok(ProcessSpawningAnalysis::default())
    }

    /// Analyze message passing patterns
    fn analyze_message_passing(&self, _ast: &AST) -> Result<MessagePassingAnalysis, ParseError> {
        // TODO: Implement comprehensive message passing analysis
        Ok(MessagePassingAnalysis::default())
    }

    /// Analyze concurrency patterns
    fn analyze_concurrency_patterns(&self, _ast: &AST) -> Result<ConcurrencyPatterns, ParseError> {
        // TODO: Implement comprehensive concurrency pattern analysis
        Ok(ConcurrencyPatterns::default())
    }

    /// Analyze fault tolerance patterns
    fn analyze_fault_tolerance(&self, _ast: &AST) -> Result<FaultToleranceAnalysis, ParseError> {
        // TODO: Implement comprehensive fault tolerance analysis
        Ok(FaultToleranceAnalysis::default())
    }

    /// Calculate BEAM-specific metrics
    fn calculate_beam_metrics(
        &self,
        _ast: &AST,
        otp_patterns: &OtpPatterns,
        actor_analysis: &ActorAnalysis,
    ) -> Result<BeamMetrics, ParseError> {
        let estimated_process_count = otp_patterns.genservers.len() as u32
            + otp_patterns.supervisors.len() as u32
            + otp_patterns.applications.len() as u32;

        let supervision_complexity = otp_patterns.supervisors.len() as f64 * 2.0
            + otp_patterns.genservers.len() as f64 * 1.5;

        let actor_complexity = actor_analysis.process_spawning.spawn_calls.len() as f64
            + actor_analysis.message_passing.send_calls.len() as f64;

        Ok(BeamMetrics {
            estimated_process_count,
            estimated_message_queue_size: 0, // TODO: implement queue size estimation
            estimated_memory_usage: 0,       // TODO: implement memory usage estimation
            gc_pressure: 0.0,                // TODO: implement GC pressure calculation
            supervision_complexity,
            actor_complexity,
            fault_tolerance_score: 0.0, // TODO: implement fault tolerance scoring
        })
    }

    /// Analyze Erlang-specific features (OTP behaviors, Common Test, Dialyzer, etc.)
    fn analyze_erlang_features(&self, _ast: &AST) -> Result<ErlangFeatures, ParseError> {
        let otp_behaviors = Vec::new(); // TODO: implement OTP behavior analysis
        let common_test_usage = CommonTestUsage {
            test_suites: Vec::new(),
            test_cases: Vec::new(),
        };
        let dialyzer_usage = DialyzerUsage {
            type_specs: Vec::new(),
            contracts: Vec::new(),
        };

        Ok(ErlangFeatures {
            otp_behaviors,
            common_test_usage,
            dialyzer_usage,
        })
    }
}
