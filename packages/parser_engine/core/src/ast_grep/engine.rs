use std::collections::{BTreeMap, HashMap};
use std::time::Instant;

use ast_grep_core::matcher::Pattern as CorePattern;
use ast_grep_core::meta_var::MetaVarEnv;
use ast_grep_core::tree_sitter::{LanguageExt, StrDoc};
use ast_grep_core::AstGrep as CoreAst;
use ast_grep_core::NodeMatch;

use super::config::AstGrepConfig;
use super::errors::AstGrepError;
use super::language::SupportedLanguage;
use super::languages::{
    BashLang, CLang, CppLang, DockerfileLang, ElixirLang, ErlangLang, GleamLang, GoLang, JavaLang,
    JavaScriptLang, JsonLang, LuaLang, MarkdownLang, PythonLang, RustLang, SqlLang, TomlLang,
    TypeScriptLang, YamlLang,
};
use super::lint::{LintRule, LintViolation};
use super::pattern::{Pattern, TransformOptions};
use super::result::{MatchContext, SearchResult};
use super::stats::SearchStats;

pub struct AstGrep {
    #[allow(dead_code)]
    language: SupportedLanguage,
    language_label: String,
    config: AstGrepConfig,
    stats: SearchStats,
}

impl AstGrep {
    pub fn new(language: impl AsRef<str>) -> Result<Self, AstGrepError> {
        Self::with_config(language, AstGrepConfig::default())
    }

    pub fn with_config(
        language: impl AsRef<str>,
        config: AstGrepConfig,
    ) -> Result<Self, AstGrepError> {
        let label = language.as_ref().trim();
        let resolved = SupportedLanguage::from_label(label)
            .ok_or_else(|| AstGrepError::UnsupportedLanguage(label.to_string()))?;

        Ok(Self {
            language: resolved,
            language_label: label.to_string(),
            config,
            stats: SearchStats::default(),
        })
    }

    pub fn language(&self) -> &str {
        &self.language_label
    }

    pub fn stats(&self) -> &SearchStats {
        &self.stats
    }

    pub fn reset_stats(&mut self) {
        self.stats = SearchStats::default();
    }

    pub fn supported_languages() -> Vec<&'static str> {
        super::language::supported_language_aliases().to_vec()
    }

    pub fn search(
        &mut self,
        source: &str,
        pattern: &Pattern,
    ) -> Result<Vec<SearchResult>, AstGrepError> {
        self.ensure_within_limits(source.len())?;

        let start = Instant::now();
        let results = self.dispatch_search(source, pattern)?;

        self.update_stats(
            results.len(),
            1,
            source.len(),
            start.elapsed().as_millis() as u64,
        );
        Ok(results)
    }

    pub fn search_multiple(
        &mut self,
        source: &str,
        patterns: &[Pattern],
    ) -> Result<HashMap<String, Vec<SearchResult>>, AstGrepError> {
        self.ensure_within_limits(source.len())?;

        let start = Instant::now();
        let results = self.dispatch_search_multiple(source, patterns)?;
        let total_matches = results.values().map(|v| v.len()).sum();

        self.update_stats(
            total_matches,
            patterns.len(),
            source.len(),
            start.elapsed().as_millis() as u64,
        );
        Ok(results)
    }

    pub fn replace(
        &mut self,
        source: &str,
        pattern: &Pattern,
        replacement: &Pattern,
    ) -> Result<String, AstGrepError> {
        self.replace_with_options(source, pattern, replacement, &TransformOptions::default())
    }

    pub fn replace_with_options(
        &mut self,
        source: &str,
        pattern: &Pattern,
        replacement: &Pattern,
        options: &TransformOptions,
    ) -> Result<String, AstGrepError> {
        self.ensure_within_limits(source.len())?;

        let start = Instant::now();
        let (result, replacements) =
            self.dispatch_replace(source, pattern, replacement, options)?;

        self.update_stats(
            replacements,
            1,
            source.len(),
            start.elapsed().as_millis() as u64,
        );
        Ok(result)
    }

    pub fn lint(
        &mut self,
        source: &str,
        rules: &[LintRule],
    ) -> Result<Vec<LintViolation>, AstGrepError> {
        self.ensure_within_limits(source.len())?;

        let start = Instant::now();
        let violations = self.dispatch_lint(source, rules)?;

        self.update_stats(
            violations.len(),
            rules.len(),
            source.len(),
            start.elapsed().as_millis() as u64,
        );
        Ok(violations)
    }

    fn dispatch_search(
        &self,
        source: &str,
        pattern: &Pattern,
    ) -> Result<Vec<SearchResult>, AstGrepError> {
        match self.language {
            SupportedLanguage::Elixir => self.search_with::<ElixirLang>(source, pattern),
            SupportedLanguage::Erlang => self.search_with::<ErlangLang>(source, pattern),
            SupportedLanguage::Gleam => self.search_with::<GleamLang>(source, pattern),
            SupportedLanguage::Rust => self.search_with::<RustLang>(source, pattern),
            SupportedLanguage::JavaScript => self.search_with::<JavaScriptLang>(source, pattern),
            SupportedLanguage::TypeScript => self.search_with::<TypeScriptLang>(source, pattern),
            SupportedLanguage::Python => self.search_with::<PythonLang>(source, pattern),
            SupportedLanguage::Java => self.search_with::<JavaLang>(source, pattern),
            SupportedLanguage::Go => self.search_with::<GoLang>(source, pattern),
            SupportedLanguage::C => self.search_with::<CLang>(source, pattern),
            SupportedLanguage::Cpp => self.search_with::<CppLang>(source, pattern),
            SupportedLanguage::Bash => self.search_with::<BashLang>(source, pattern),
            SupportedLanguage::Json => self.search_with::<JsonLang>(source, pattern),
            SupportedLanguage::Yaml => self.search_with::<YamlLang>(source, pattern),
            SupportedLanguage::Lua => self.search_with::<LuaLang>(source, pattern),
            SupportedLanguage::Markdown => self.search_with::<MarkdownLang>(source, pattern),
            SupportedLanguage::Dockerfile => self.search_with::<DockerfileLang>(source, pattern),
            SupportedLanguage::Toml => self.search_with::<TomlLang>(source, pattern),
            SupportedLanguage::Sql => self.search_with::<SqlLang>(source, pattern),
        }
    }

    fn dispatch_search_multiple(
        &self,
        source: &str,
        patterns: &[Pattern],
    ) -> Result<HashMap<String, Vec<SearchResult>>, AstGrepError> {
        match self.language {
            SupportedLanguage::Elixir => self.search_multiple_with::<ElixirLang>(source, patterns),
            SupportedLanguage::Erlang => self.search_multiple_with::<ErlangLang>(source, patterns),
            SupportedLanguage::Gleam => self.search_multiple_with::<GleamLang>(source, patterns),
            SupportedLanguage::Rust => self.search_multiple_with::<RustLang>(source, patterns),
            SupportedLanguage::JavaScript => {
                self.search_multiple_with::<JavaScriptLang>(source, patterns)
            }
            SupportedLanguage::TypeScript => {
                self.search_multiple_with::<TypeScriptLang>(source, patterns)
            }
            SupportedLanguage::Python => self.search_multiple_with::<PythonLang>(source, patterns),
            SupportedLanguage::Java => self.search_multiple_with::<JavaLang>(source, patterns),
            SupportedLanguage::Go => self.search_multiple_with::<GoLang>(source, patterns),
            SupportedLanguage::C => self.search_multiple_with::<CLang>(source, patterns),
            SupportedLanguage::Cpp => self.search_multiple_with::<CppLang>(source, patterns),
            SupportedLanguage::Bash => self.search_multiple_with::<BashLang>(source, patterns),
            SupportedLanguage::Json => self.search_multiple_with::<JsonLang>(source, patterns),
            SupportedLanguage::Yaml => self.search_multiple_with::<YamlLang>(source, patterns),
            SupportedLanguage::Lua => self.search_multiple_with::<LuaLang>(source, patterns),
            SupportedLanguage::Markdown => {
                self.search_multiple_with::<MarkdownLang>(source, patterns)
            }
            SupportedLanguage::Dockerfile => {
                self.search_multiple_with::<DockerfileLang>(source, patterns)
            }
            SupportedLanguage::Toml => self.search_multiple_with::<TomlLang>(source, patterns),
            SupportedLanguage::Sql => self.search_multiple_with::<SqlLang>(source, patterns),
        }
    }

    fn dispatch_replace(
        &self,
        source: &str,
        pattern: &Pattern,
        replacement: &Pattern,
        options: &TransformOptions,
    ) -> Result<(String, usize), AstGrepError> {
        match self.language {
            SupportedLanguage::Elixir => {
                self.replace_with::<ElixirLang>(source, pattern, replacement, options)
            }
            SupportedLanguage::Erlang => {
                self.replace_with::<ErlangLang>(source, pattern, replacement, options)
            }
            SupportedLanguage::Gleam => {
                self.replace_with::<GleamLang>(source, pattern, replacement, options)
            }
            SupportedLanguage::Rust => {
                self.replace_with::<RustLang>(source, pattern, replacement, options)
            }
            SupportedLanguage::JavaScript => {
                self.replace_with::<JavaScriptLang>(source, pattern, replacement, options)
            }
            SupportedLanguage::TypeScript => {
                self.replace_with::<TypeScriptLang>(source, pattern, replacement, options)
            }
            SupportedLanguage::Python => {
                self.replace_with::<PythonLang>(source, pattern, replacement, options)
            }
            SupportedLanguage::Java => {
                self.replace_with::<JavaLang>(source, pattern, replacement, options)
            }
            SupportedLanguage::Go => {
                self.replace_with::<GoLang>(source, pattern, replacement, options)
            }
            SupportedLanguage::C => {
                self.replace_with::<CLang>(source, pattern, replacement, options)
            }
            SupportedLanguage::Cpp => {
                self.replace_with::<CppLang>(source, pattern, replacement, options)
            }
            SupportedLanguage::Bash => {
                self.replace_with::<BashLang>(source, pattern, replacement, options)
            }
            SupportedLanguage::Json => {
                self.replace_with::<JsonLang>(source, pattern, replacement, options)
            }
            SupportedLanguage::Yaml => {
                self.replace_with::<YamlLang>(source, pattern, replacement, options)
            }
            SupportedLanguage::Lua => {
                self.replace_with::<LuaLang>(source, pattern, replacement, options)
            }
            SupportedLanguage::Markdown => {
                self.replace_with::<MarkdownLang>(source, pattern, replacement, options)
            }
            SupportedLanguage::Dockerfile => {
                self.replace_with::<DockerfileLang>(source, pattern, replacement, options)
            }
            SupportedLanguage::Toml => {
                self.replace_with::<TomlLang>(source, pattern, replacement, options)
            }
            SupportedLanguage::Sql => {
                self.replace_with::<SqlLang>(source, pattern, replacement, options)
            }
        }
    }

    fn dispatch_lint(
        &self,
        source: &str,
        rules: &[LintRule],
    ) -> Result<Vec<LintViolation>, AstGrepError> {
        match self.language {
            SupportedLanguage::Elixir => self.lint_with::<ElixirLang>(source, rules),
            SupportedLanguage::Erlang => self.lint_with::<ErlangLang>(source, rules),
            SupportedLanguage::Gleam => self.lint_with::<GleamLang>(source, rules),
            SupportedLanguage::Rust => self.lint_with::<RustLang>(source, rules),
            SupportedLanguage::JavaScript => self.lint_with::<JavaScriptLang>(source, rules),
            SupportedLanguage::TypeScript => self.lint_with::<TypeScriptLang>(source, rules),
            SupportedLanguage::Python => self.lint_with::<PythonLang>(source, rules),
            SupportedLanguage::Java => self.lint_with::<JavaLang>(source, rules),
            SupportedLanguage::Go => self.lint_with::<GoLang>(source, rules),
            SupportedLanguage::C => self.lint_with::<CLang>(source, rules),
            SupportedLanguage::Cpp => self.lint_with::<CppLang>(source, rules),
            SupportedLanguage::Bash => self.lint_with::<BashLang>(source, rules),
            SupportedLanguage::Json => self.lint_with::<JsonLang>(source, rules),
            SupportedLanguage::Yaml => self.lint_with::<YamlLang>(source, rules),
            SupportedLanguage::Lua => self.lint_with::<LuaLang>(source, rules),
            SupportedLanguage::Markdown => self.lint_with::<MarkdownLang>(source, rules),
            SupportedLanguage::Dockerfile => self.lint_with::<DockerfileLang>(source, rules),
            SupportedLanguage::Toml => self.lint_with::<TomlLang>(source, rules),
            SupportedLanguage::Sql => self.lint_with::<SqlLang>(source, rules),
        }
    }

    fn search_with<L>(
        &self,
        source: &str,
        pattern: &Pattern,
    ) -> Result<Vec<SearchResult>, AstGrepError>
    where
        L: LanguageExt + Default + Clone,
    {
        pattern.validate()?;
        let lang = L::default();
        let matcher = compile_pattern(pattern, &lang)?;
        let constraint_patterns = compile_constraints(pattern, &lang)?;

        let root =
            CoreAst::try_new(source, lang.clone()).map_err(|err| AstGrepError::ParseError {
                language: self.language.primary_alias().to_string(),
                details: err,
            })?;

        let mut results = Vec::new();
        for node_match in root.root().find_all(matcher.clone()) {
            let match_clone = node_match.clone();
            let mut env = match_clone.get_env().clone();
            if !constraint_patterns.is_empty() && !env.match_constraints(&constraint_patterns) {
                continue;
            }
            results.push(build_search_result(match_clone, env, source, pattern));
        }
        Ok(results)
    }

    fn search_multiple_with<L>(
        &self,
        source: &str,
        patterns: &[Pattern],
    ) -> Result<HashMap<String, Vec<SearchResult>>, AstGrepError>
    where
        L: LanguageExt + Default + Clone,
    {
        let mut result = HashMap::with_capacity(patterns.len());
        for pattern in patterns {
            let matches = self.search_with::<L>(source, pattern)?;
            result.insert(pattern.as_str().to_string(), matches);
        }
        Ok(result)
    }

    fn replace_with<L>(
        &self,
        source: &str,
        pattern: &Pattern,
        replacement: &Pattern,
        options: &TransformOptions,
    ) -> Result<(String, usize), AstGrepError>
    where
        L: LanguageExt + Default + Clone,
    {
        pattern.validate()?;
        replacement.validate()?;

        let lang = L::default();
        let matcher = compile_pattern(pattern, &lang)?;
        let constraint_patterns = compile_constraints(pattern, &lang)?;
        let mut root =
            CoreAst::try_new(source, lang.clone()).map_err(|err| AstGrepError::ParseError {
                language: self.language.primary_alias().to_string(),
                details: err,
            })?;

        let replacement_text = replacement.as_str();
        let mut edits = Vec::new();

        for node_match in root.root().find_all(matcher.clone()) {
            let mut env = node_match.get_env().clone();
            if !constraint_patterns.is_empty() && !env.match_constraints(&constraint_patterns) {
                continue;
            }

            let original_text = node_match.text().to_string();
            let mut edit = node_match.make_edit(&matcher, &replacement_text);

            if let Ok(mut replacement_str) = String::from_utf8(edit.inserted_text.clone()) {
                let indent = leading_indent(&original_text);

                if options.preserve_whitespace {
                    replacement_str = apply_indent(&replacement_str, &indent);
                }

                if options.preserve_comments {
                    if let Some((comment_indent, comment_body)) =
                        extract_trailing_comment(&original_text)
                    {
                        if !replacement_str
                            .trim_end()
                            .ends_with(comment_body.trim_end())
                        {
                            if replacement_str.ends_with('\n') {
                                replacement_str.push_str(&comment_indent);
                                replacement_str.push_str(&comment_body);
                                replacement_str.push('\n');
                            } else {
                                replacement_str.push(' ');
                                replacement_str.push_str(comment_body.trim_start());
                            }
                        }
                    }
                }

                if options.backup_original {
                    replacement_str.push_str(&build_backup_block(
                        &original_text,
                        &indent,
                        replacement_str.ends_with('\n'),
                    ));
                }

                edit.inserted_text = replacement_str.into_bytes();
            }

            edits.push(edit);
        }

        if let Some(limit) = options.max_replacements {
            if edits.len() > limit {
                edits.truncate(limit);
            }
        }

        let replacement_count = edits.len();

        if replacement_count == 0 || options.dry_run {
            return Ok((source.to_string(), replacement_count));
        }

        for edit in edits.into_iter().rev() {
            root.edit(edit)
                .map_err(AstGrepError::ReplacementError)?;
        }

        Ok((root.generate(), replacement_count))
    }

    fn lint_with<L>(
        &self,
        source: &str,
        rules: &[LintRule],
    ) -> Result<Vec<LintViolation>, AstGrepError>
    where
        L: LanguageExt + Default + Clone,
    {
        let mut violations = Vec::new();
        for rule in rules {
            let matches = self.search_with::<L>(source, &rule.pattern)?;
            for entry in matches {
                violations.push(LintViolation {
                    rule_id: rule.id.clone(),
                    message: rule.message.clone(),
                    location: entry.start,
                    text: entry.text.clone(),
                    fix: rule.fix.clone(),
                    severity: rule.severity,
                });
            }
        }
        Ok(violations)
    }

    fn ensure_within_limits(&self, len: usize) -> Result<(), AstGrepError> {
        if len > self.config.max_file_size {
            return Err(AstGrepError::FileTooLarge {
                size: len,
                max: self.config.max_file_size,
            });
        }
        Ok(())
    }

    fn update_stats(&mut self, matches: usize, patterns: usize, bytes: usize, elapsed_ms: u64) {
        self.stats.total_matches = matches;
        self.stats.unique_patterns = patterns;
        self.stats.languages_searched = 1;
        self.stats.execution_time_ms = elapsed_ms;
        self.stats.memory_usage_bytes = bytes;
    }
}

fn compile_pattern<L>(pattern: &Pattern, lang: &L) -> Result<CorePattern, AstGrepError>
where
    L: LanguageExt + Clone,
{
    CorePattern::try_new(pattern.as_str(), lang.clone()).map_err(|source| {
        AstGrepError::PatternCompilation {
            pattern: pattern.as_str().to_string(),
            source,
        }
    })
}

fn compile_constraints<L>(
    pattern: &Pattern,
    lang: &L,
) -> Result<HashMap<String, CorePattern>, AstGrepError>
where
    L: LanguageExt + Clone,
{
    let mut compiled = HashMap::new();
    for (var, constraint) in &pattern.constraints {
        let core = CorePattern::try_new(constraint, lang.clone()).map_err(|source| {
            AstGrepError::ConstraintCompilation {
                variable: var.clone(),
                source,
            }
        })?;
        compiled.insert(var.clone(), core);
    }
    Ok(compiled)
}

fn build_search_result<L>(
    node_match: NodeMatch<StrDoc<L>>,
    env: MetaVarEnv<StrDoc<L>>,
    source: &str,
    pattern: &Pattern,
) -> SearchResult
where
    L: LanguageExt,
{
    let start_pos = node_match.start_pos();
    let end_pos = node_match.end_pos();
    let range = node_match.range();
    let range_len = range.end.saturating_sub(range.start);
    let text = node_match.text().to_string();

    let captures_map: HashMap<String, String> = {
        let map: HashMap<String, String> = env.into();
        map.into_iter()
            .collect::<BTreeMap<_, _>>()
            .into_iter()
            .collect()
    };

    SearchResult {
        text,
        start: (start_pos.line() + 1, start_pos.column(&node_match) + 1),
        end: (end_pos.line() + 1, end_pos.column(&node_match) + 1),
        byte_range: range,
        captures: captures_map,
        node_type: node_match.kind().to_string(),
        confidence: calculate_confidence(pattern, range_len),
        context: extract_context(&node_match, source),
    }
}

fn calculate_confidence(pattern: &Pattern, match_len: usize) -> f64 {
    let base = 0.6;
    let metavars = pattern.metavariables().len();
    let capture_factor = (metavars as f64 * 0.08).min(0.25);
    let length_factor = (match_len as f64 / 160.0).min(0.15);
    (base + capture_factor + length_factor).min(1.0)
}

fn extract_context<L>(node_match: &NodeMatch<StrDoc<L>>, source: &str) -> MatchContext
where
    L: LanguageExt,
{
    let range = node_match.range();
    let (before, after) = surrounding_lines(source, range, 2, 2);
    let parent_node = node_match.parent().map(|p| p.kind().to_string());
    let sibling_nodes = parent_node
        .as_ref()
        .and_then(|_| node_match.parent())
        .map(|parent| {
            parent
                .children()
                .filter(|child| child.node_id() != node_match.node_id())
                .take(6)
                .map(|child| child.kind().to_string())
                .collect()
        })
        .unwrap_or_default();

    MatchContext {
        before,
        after,
        parent_node,
        sibling_nodes,
    }
}

fn surrounding_lines(
    source: &str,
    range: std::ops::Range<usize>,
    before: usize,
    after: usize,
) -> (String, String) {
    let before_slice = &source[..range.start];
    let after_slice = &source[range.end.min(source.len())..];

    let before_text = before_slice
        .rsplitn(before + 1, '\n')
        .skip(1)
        .collect::<Vec<_>>()
        .into_iter()
        .rev()
        .collect::<Vec<_>>()
        .join("\n");

    let after_text = after_slice
        .splitn(after + 1, '\n')
        .take(after)
        .collect::<Vec<_>>()
        .join("\n");

    (before_text, after_text)
}

fn leading_indent(text: &str) -> String {
    text.lines()
        .next()
        .map(|line| line.chars().take_while(|c| c.is_whitespace()).collect())
        .unwrap_or_default()
}

fn apply_indent(content: &str, indent: &str) -> String {
    if indent.is_empty() || content.is_empty() {
        return content.to_string();
    }

    let lines: Vec<&str> = content.lines().collect();
    if lines.is_empty() {
        return content.to_string();
    }

    let min_existing_indent = lines
        .iter()
        .filter_map(|line| {
            if line.trim().is_empty() {
                None
            } else {
                Some(line.chars().take_while(|c| c.is_whitespace()).count())
            }
        })
        .min()
        .unwrap_or(0);

    let mut adjusted = String::with_capacity(content.len() + indent.len() * lines.len());
    for (idx, line) in lines.iter().enumerate() {
        if idx > 0 {
            adjusted.push('\n');
        }
        adjusted.push_str(indent);
        adjusted.push_str(strip_leading_whitespace(line, min_existing_indent));
    }
    if content.ends_with('\n') {
        adjusted.push('\n');
    }
    adjusted
}

fn strip_leading_whitespace(line: &str, mut count: usize) -> &str {
    if count == 0 || line.is_empty() {
        return line;
    }

    let mut byte_idx = 0;
    for (idx, ch) in line.char_indices() {
        if count == 0 {
            byte_idx = idx;
            break;
        }
        if ch.is_whitespace() {
            count -= 1;
            byte_idx = idx + ch.len_utf8();
        } else {
            byte_idx = idx;
            break;
        }
    }

    if count > 0 {
        ""
    } else {
        &line[byte_idx..]
    }
}

fn extract_trailing_comment(text: &str) -> Option<(String, String)> {
    for line in text.lines().rev() {
        let trimmed = line.trim_end();
        if trimmed.is_empty() {
            continue;
        }

        for marker in ["//", "#", "--"].iter() {
            if let Some(idx) = trimmed.find(marker) {
                let indent: String = line.chars().take_while(|c| c.is_whitespace()).collect();
                let comment = trimmed[idx..].to_string();
                return Some((indent, comment));
            }
        }
        break;
    }
    None
}

fn build_backup_block(original: &str, indent: &str, replacement_ends_with_newline: bool) -> String {
    let mut block = String::new();
    if !replacement_ends_with_newline {
        block.push('\n');
    }
    block.push_str(indent);
    block.push_str("/* original:\n");
    for line in original.trim_end().lines() {
        block.push_str(indent);
        block.push_str(" * ");
        block.push_str(line);
        block.push('\n');
    }
    block.push_str(indent);
    block.push_str(" */\n");
    block
}
