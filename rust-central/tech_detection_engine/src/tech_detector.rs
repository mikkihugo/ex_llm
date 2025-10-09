//! Main TechDetector - Self-explanatory API!

use crate::detection_results::{
    DatabaseDetection, DetectionMethod, DetectionResults, FrameworkDetection, LanguageDetection,
};
use crate::ai_client::AIClient;
use anyhow::Result;
use dependency_parser::{DependencyParser, PackageDependency};
use source_code_parser::{AnalysisResult, ProgrammingLanguage, UniversalDependencies, UniversalParserFrameworkConfig};
use std::collections::{hash_map::Entry, HashMap, HashSet};
use std::fs;
use std::path::{Path, PathBuf};
use tokio::fs as tokio_fs;

/// Technology and Framework Detector
///
/// Multi-level detection system that tries methods from fast to slow:
/// 1. Config files (instant)
/// 2. Code patterns (fast)
/// 3. AST parsing (medium)
/// 4. Knowledge base (medium)
/// 5. AI analysis (slow)
pub struct TechDetector {
    parser: Option<UniversalDependencies>,
    dependency_parser: DependencyParser,
    ai_client: Option<AIClient>,
}

fn dedupe_frameworks(items: Vec<FrameworkDetection>) -> Vec<FrameworkDetection> {
    let mut map: HashMap<String, FrameworkDetection> = HashMap::new();

    for mut detection in items {
        let key = detection.name.to_lowercase();
        match map.entry(key) {
            Entry::Occupied(mut entry) => {
                let existing = entry.get_mut();
                if detection.confidence > existing.confidence {
                    existing.confidence = detection.confidence;
                    existing.detected_by = detection.detected_by;
                }
                if existing.version.is_none() {
                    existing.version = detection.version.clone();
                }
                existing
                    .evidence.append(&mut detection.evidence);
            }
            Entry::Vacant(entry) => {
                entry.insert(detection);
            }
        }
    }

    map.into_values().map(|mut detection| {
            detection.evidence.sort();
            detection.evidence.dedup();
            detection
        })
        .collect()
}

fn dedupe_languages(items: Vec<LanguageDetection>) -> Vec<LanguageDetection> {
    let mut map: HashMap<String, LanguageDetection> = HashMap::new();

    for detection in items {
        let key = detection.name.to_lowercase();
        match map.entry(key) {
            Entry::Occupied(mut entry) => {
                if detection.confidence > entry.get().confidence {
                    entry.insert(detection);
                }
            }
            Entry::Vacant(entry) => {
                entry.insert(detection);
            }
        }
    }

    map.into_values().collect()
}

fn dedupe_databases(items: Vec<DatabaseDetection>) -> Vec<DatabaseDetection> {
    let mut map: HashMap<String, DatabaseDetection> = HashMap::new();

    for detection in items {
        let key = detection.name.to_lowercase();
        match map.entry(key) {
            Entry::Occupied(mut entry) => {
                if detection.confidence > entry.get().confidence {
                    entry.insert(detection);
                }
            }
            Entry::Vacant(entry) => {
                entry.insert(detection);
            }
        }
    }

    map.into_values().collect()
}

fn is_package_manifest(path: &Path) -> bool {
    if let Some(file_name) = path.file_name().and_then(|n| n.to_str()) {
        return matches!(file_name, 
            "package.json"
            | "package-lock.json"
            | "pnpm-lock.yaml"
            | "yarn.lock"
            | "Cargo.toml"
            | "Cargo.lock"
            | "mix.exs"
            | "requirements.txt"
            | "pyproject.toml"
            | "go.mod"
            | "composer.json"
            | "Gemfile"
            | "pom.xml"
            | "build.gradle"
            | "build.gradle.kts"
            | "package.swift"
        );
    }

    matches!(path.extension().and_then(|e| e.to_str()), Some(ext) if ext.eq_ignore_ascii_case("csproj"))
}

fn framework_from_dependency(dep: &PackageDependency, file_path: &Path) -> Option<FrameworkDetection> {
    let dep_lower = dep.name.to_lowercase();
    let framework = if dep_lower.contains("phoenix") {
        Some("Phoenix")
    } else if dep_lower.contains("rails") {
        Some("Rails")
    } else if dep_lower.contains("django") {
        Some("Django")
    } else if dep_lower.contains("flask") {
        Some("Flask")
    } else if dep_lower.contains("fastapi") {
        Some("FastAPI")
    } else if dep_lower.contains("react") {
        Some("React")
    } else if dep_lower.contains("next") {
        Some("Next.js")
    } else if dep_lower.contains("vue") {
        Some("Vue.js")
    } else if dep_lower.contains("express") {
        Some("Express")
    } else if dep_lower.contains("nestjs") {
        Some("NestJS")
    } else if dep_lower.contains("laravel") || dep_lower.contains("illuminate") {
        Some("Laravel")
    } else if dep_lower.contains("spring-boot") || dep_lower.contains("springboot") {
        Some("Spring Boot")
    } else if dep_lower.contains("aspnetcore") || dep_lower.contains("microsoft.aspnetcore") {
        Some("ASP.NET Core")
    } else {
        None
    }?;

    Some(FrameworkDetection {
        name: framework.to_string(),
        version: if dep.version.is_empty() {
            None
        } else {
            Some(dep.version.clone())
        },
        confidence: 0.85,
        detected_by: DetectionMethod::FoundInConfigFiles,
        evidence: vec![format!("Dependency '{}' in {}", dep.name, file_path.display())],
    })
}

fn database_from_dependency(dep: &PackageDependency, _file_path: &Path) -> Option<DatabaseDetection> {
    let dep_lower = dep.name.to_lowercase();
    let database = if dep_lower.contains("postgres") || dep_lower.contains("pg") {
        Some("PostgreSQL")
    } else if dep_lower.contains("mysql") || dep_lower.contains("mariadb") {
        Some("MySQL")
    } else if dep_lower.contains("redis") {
        Some("Redis")
    } else if dep_lower.contains("mongo") {
        Some("MongoDB")
    } else if dep_lower.contains("sqlite") {
        Some("SQLite")
    } else {
        None
    }?;

    Some(DatabaseDetection {
        name: database.to_string(),
        version: if dep.version.is_empty() {
            None
        } else {
            Some(dep.version.clone())
        },
        confidence: 0.6,
        detected_by: DetectionMethod::FoundInConfigFiles,
        // DatabaseDetection lacks evidence, keep simple
    })
}

fn languages_for_dependency(dep: &PackageDependency) -> Vec<&'static str> {
    let mut languages = Vec::new();
    let ecosystem = dep.ecosystem.to_lowercase();

    match ecosystem.as_str() {
        "npm" | "yarn" | "pnpm" => languages.extend(["javascript", "typescript"]),
        "crates" => languages.push("rust"),
        "hex" => languages.push("elixir"),
        "pypi" => languages.push("python"),
        "go" => languages.push("go"),
        "composer" => languages.push("php"),
        "gem" => languages.push("ruby"),
        "maven" | "gradle" => languages.extend(["java", "kotlin"]),
        "nuget" => languages.push("csharp"),
        _ => {}
    }

    if languages.is_empty() {
        let dep_lower = dep.name.to_lowercase();
        if dep_lower.contains("django") || dep_lower.contains("flask") || dep_lower.contains("fastapi") {
            languages.push("python");
        } else if dep_lower.contains("rails") || dep_lower.contains("sinatra") {
            languages.push("ruby");
        } else if dep_lower.contains("phoenix") {
            languages.push("elixir");
        } else if dep_lower.contains("spring") {
            languages.push("java");
        }
    }

    languages
}

const KNOWLEDGE_BASE_LANGUAGES: &[(&str, &[&str])] = &[
    ("Phoenix", &["elixir"]),
    ("Rails", &["ruby"]),
    ("Django", &["python"]),
    ("Flask", &["python"]),
    ("FastAPI", &["python"]),
    ("React", &["javascript", "typescript"]),
    ("Next.js", &["javascript", "typescript"]),
    ("Vue.js", &["javascript", "typescript"]),
    ("Express", &["javascript", "typescript"]),
    ("NestJS", &["typescript"]),
    ("Laravel", &["php"]),
    ("Spring Boot", &["java"]),
    ("ASP.NET Core", &["csharp"]),
];

const KNOWLEDGE_BASE_DATABASES: &[(&str, &[&str])] = &[
    ("Phoenix", &["PostgreSQL"]),
    ("Rails", &["PostgreSQL", "MySQL"]),
    ("Django", &["PostgreSQL", "SQLite"]),
    ("Flask", &["PostgreSQL", "SQLite"]),
    ("FastAPI", &["PostgreSQL"]),
    ("Laravel", &["MySQL", "PostgreSQL"]),
    ("Spring Boot", &["PostgreSQL", "MySQL"]),
    ("Express", &["MongoDB", "PostgreSQL"]),
    ("NestJS", &["PostgreSQL", "MongoDB"]),
];

fn knowledge_base_languages(framework_name: &str) -> Option<&'static [&'static str]> {
    let name_lower = framework_name.to_lowercase();
    KNOWLEDGE_BASE_LANGUAGES
        .iter()
        .find(|(name, _)| name.to_lowercase() == name_lower)
        .map(|(_, languages)| *languages)
}

fn knowledge_base_databases(framework_name: &str) -> Option<&'static [&'static str]> {
    let name_lower = framework_name.to_lowercase();
    KNOWLEDGE_BASE_DATABASES
        .iter()
        .find(|(name, _)| name.to_lowercase() == name_lower)
        .map(|(_, databases)| *databases)
}

fn frameworks_from_identifier(
    identifier: &str,
    method: DetectionMethod,
    evidence: String,
) -> Vec<FrameworkDetection> {
    let identifier_lower = identifier.to_lowercase();
    let mut detections = Vec::new();

    for hint in FRAMEWORK_HINTS {
        let keyword = hint.name.to_lowercase();
        if hint.patterns.iter().any(|pattern| identifier_lower.contains(pattern))
            || identifier_lower.contains(&keyword)
        {
            detections.push(FrameworkDetection {
                name: hint.name.to_string(),
                version: None,
                confidence: 0.55,
                detected_by: method,
                evidence: vec![evidence.clone()],
            });
        }
    }

    detections
}

fn databases_from_identifier(
    identifier: &str,
    method: DetectionMethod,
) -> Vec<DatabaseDetection> {
    let identifier_lower = identifier.to_lowercase();
    let mut detections = Vec::new();

    for hint in DATABASE_HINTS {
        if hint
            .patterns
            .iter()
            .any(|pattern| identifier_lower.contains(pattern))
        {
            detections.push(DatabaseDetection {
                name: hint.name.to_string(),
                version: None,
                confidence: 0.45,
                detected_by: method,
            });
        }
    }

    detections
}

fn languages_from_identifier(identifier: &str) -> Vec<&'static str> {
    let identifier_lower = identifier.to_lowercase();
    let mut languages = Vec::new();

    for hint in FRAMEWORK_HINTS {
        if hint.patterns.iter().any(|p| identifier_lower.contains(p))
            || identifier_lower.contains(&hint.name.to_lowercase())
        {
            languages.extend(hint.languages);
        }
    }

    languages
}

fn language_from_extension(extension: &str) -> Option<&'static str> {
    match extension {
        "js" | "jsx" | "mjs" | "cjs" => Some("javascript"),
        "ts" | "tsx" | "mts" | "cts" => Some("typescript"),
        "py" | "pyw" | "pyi" => Some("python"),
        "rs" => Some("rust"),
        "go" => Some("go"),
        "java" => Some("java"),
        "kt" | "kts" => Some("kotlin"),
        "php" | "phtml" => Some("php"),
        "rb" => Some("ruby"),
        "ex" | "exs" => Some("elixir"),
        "erl" => Some("erlang"),
        "cs" => Some("csharp"),
        "swift" => Some("swift"),
        "lua" => Some("lua"),
        "html" | "htm" => Some("html"),
        "css" | "scss" | "less" => Some("css"),
        "json" => Some("json"),
        "yaml" | "yml" => Some("yaml"),
        "sh" | "bash" => Some("bash"),
        _ => None,
    }
}

fn normalize_language_label(label: &str) -> Option<&'static str> {
    let normalized = label.trim().to_lowercase();
    if normalized.is_empty() || normalized == "unknown" {
        return None;
    }

    Some(match normalized.as_str() {
        "js" | "javascript" => "javascript",
        "ts" | "typescript" => "typescript",
        "python" => "python",
        "rust" => "rust",
        "go" => "go",
        "elixir" => "elixir",
        "erlang" => "erlang",
        "gleam" => "gleam",
        "java" => "java",
        "c" => "c",
        "cpp" | "c++" => "cpp",
        "csharp" | "c#" => "csharp",
        "swift" => "swift",
        "kotlin" => "kotlin",
        "php" => "php",
        "ruby" => "ruby",
        "lua" => "lua",
        _ => return None,
    })
}
#[derive(Debug, Clone, Copy)]
struct FrameworkHint {
    name: &'static str,
    patterns: &'static [&'static str],
    languages: &'static [&'static str],
    databases: &'static [&'static str],
}

#[derive(Debug, Clone, Copy)]
struct DatabaseHint {
    name: &'static str,
    patterns: &'static [&'static str],
}

const FRAMEWORK_HINTS: &[FrameworkHint] = &[
    FrameworkHint {
        name: "Phoenix",
        patterns: &["use phoenix", "phoenix.controller", "phoenix.endpoint", "phoenix.liveview"],
        languages: &["elixir"],
        databases: &["PostgreSQL"],
    },
    FrameworkHint {
        name: "Rails",
        patterns: &["rails::", "activerecord::", "actioncontroller::", "config/application.rb"],
        languages: &["ruby"],
        databases: &["PostgreSQL", "MySQL"],
    },
    FrameworkHint {
        name: "Django",
        patterns: &["from django", "django.apps", "django.conf", "django.urls"],
        languages: &["python"],
        databases: &["PostgreSQL"],
    },
    FrameworkHint {
        name: "Flask",
        patterns: &["from flask", "flask import", "app = flask("],
        languages: &["python"],
        databases: &[],
    },
    FrameworkHint {
        name: "FastAPI",
        patterns: &["from fastapi", "fastapi import", "fastapi.responses"],
        languages: &["python"],
        databases: &[],
    },
    FrameworkHint {
        name: "React",
        patterns: &["from \"react\"", "from 'react'", "import react", "reactdom.render"],
        languages: &["javascript", "typescript"],
        databases: &[],
    },
    FrameworkHint {
        name: "Next.js",
        patterns: &["from \"next\"", "getserversideprops", "getstaticprops"],
        languages: &["javascript", "typescript"],
        databases: &[],
    },
    FrameworkHint {
        name: "Angular",
        patterns: &["@ngmodule", "platformbrowserdynamic", "angular/core"],
        languages: &["typescript"],
        databases: &[],
    },
    FrameworkHint {
        name: "Vue.js",
        patterns: &["from \"vue\"", "vue.createapp", "new vue({"],
        languages: &["javascript", "typescript"],
        databases: &[],
    },
    FrameworkHint {
        name: "Express",
        patterns: &["require(\"express\")", "require('express')", "from \"express\"", "const express ="],
        languages: &["javascript", "typescript"],
        databases: &[],
    },
    FrameworkHint {
        name: "NestJS",
        patterns: &["@nestjs", "nestjs/common", "nestjs/core"],
        languages: &["typescript"],
        databases: &[],
    },
    FrameworkHint {
        name: "Laravel",
        patterns: &["use illuminate\\", "route::", "artisan::call"],
        languages: &["php"],
        databases: &["MySQL"],
    },
    FrameworkHint {
        name: "Spring Boot",
        patterns: &["@springbootapplication", "springapplication.run", "springframework.boot"],
        languages: &["java"],
        databases: &["PostgreSQL"],
    },
    FrameworkHint {
        name: "ASP.NET Core",
        patterns: &["microsoft.aspnetcore", "webapplication.createbuilder", "app.mapcontrollers"],
        languages: &["csharp"],
        databases: &["SQL Server"],
    },
];

const DATABASE_HINTS: &[DatabaseHint] = &[
    DatabaseHint {
        name: "PostgreSQL",
        patterns: &["postgresql", "ecto.adapters.postgres", "psycopg2"],
    },
    DatabaseHint {
        name: "MySQL",
        patterns: &["mysql", "mariadb"],
    },
    DatabaseHint {
        name: "MongoDB",
        patterns: &["mongodb", "mongoose"],
    },
    DatabaseHint {
        name: "Redis",
        patterns: &["redis", "ioredis"],
    },
    DatabaseHint {
        name: "SQLite",
        patterns: &["sqlite", "sqlite3"],
    },
];

const MAX_PATTERN_SCAN_FILES: usize = 200;
const MAX_PATTERN_FILE_SIZE: u64 = 256 * 1024; // 256 KB
const MAX_AST_FILES: usize = 25;
const MAX_AST_FILE_SIZE: u64 = 256 * 1024; // 256 KB

impl TechDetector {
    /// Create new detector
    pub async fn new() -> Result<Self> {
        // Initialize universal parser for AST analysis
        let parser = UniversalDependencies::new()
            .or_else(|_| UniversalDependencies::new_with_config(UniversalParserFrameworkConfig::default()))
            .ok();
        
        // Initialize dependency parser for config file analysis
        let dependency_parser = DependencyParser::new();
        
        Ok(Self { 
            parser, 
            dependency_parser,
            ai_client: None,
        })
    }

    /// Create new detector with AI client for advanced analysis
    pub async fn new_with_ai(nats_url: &str) -> Result<Self> {
        // Initialize universal parser for AST analysis
        let parser = UniversalDependencies::new()
            .or_else(|_| UniversalDependencies::new_with_config(UniversalParserFrameworkConfig::default()))
            .ok();
        
        // Initialize dependency parser for config file analysis
        let dependency_parser = DependencyParser::new();
        
        // Initialize AI client for advanced analysis
        let ai_client = AIClient::new(nats_url).await.ok();
        
        Ok(Self { 
            parser, 
            dependency_parser,
            ai_client,
        })
    }

    /// Detect all frameworks and languages in a codebase
    ///
    /// Tries multiple detection methods in order of speed.
    /// Stops early if confidence is high enough.
    ///
    /// # Example
    ///
    /// ```no_run
    /// # use tech_detector::TechDetector;
    /// # async fn example() -> anyhow::Result<()> {
    /// let detector = TechDetector::new().await?;
    /// let results = detector.detect_frameworks_and_languages("/path/to/code").await?;
    ///
    /// for framework in results.frameworks {
    ///     println!("Found {} (confidence: {})", framework.name, framework.confidence);
    /// }
    /// # Ok(())
    /// # }
    /// ```
    pub async fn detect_frameworks_and_languages<P: AsRef<Path>>(
        &self,
        codebase_path: P,
    ) -> Result<DetectionResults> {
        let path = codebase_path.as_ref();

        // Implement detection methods in order of speed
        let mut frameworks = Vec::new();
        let mut languages = Vec::new();
        let mut databases = Vec::new();
        let mut confidence_score: f32 = 0.0;

        // Level 1: Config file detection (instant)
        if let Ok(config_results) = self.scan_config_files_for_dependencies(path).await {
            frameworks.extend(config_results.frameworks);
            languages.extend(config_results.languages);
            databases.extend(config_results.databases);
            confidence_score += config_results.confidence_score * 0.4; // 40% weight
        }

        // Level 2: Pattern matching (fast)
        if confidence_score < 0.7 {
            if let Ok(pattern_results) = self.match_code_patterns_against_templates(path).await {
                frameworks.extend(pattern_results.frameworks);
                languages.extend(pattern_results.languages);
                databases.extend(pattern_results.databases);
                confidence_score += pattern_results.confidence_score * 0.3; // 30% weight
            }
        }

        // Level 3: AST analysis (medium) - Use source-code-parser
        if confidence_score < 0.8 && self.parser.is_some() {
            if let Ok(ast_results) = self.parse_code_structure_with_tree_sitter(path).await {
                frameworks.extend(ast_results.frameworks);
                languages.extend(ast_results.languages);
                databases.extend(ast_results.databases);
                confidence_score += ast_results.confidence_score * 0.2; // 20% weight
            }
        }

        // Level 4: Knowledge base lookup (medium)
        if confidence_score < 0.9 {
            if let Ok(kb_results) = self.cross_reference_with_knowledge_base(&frameworks).await {
                frameworks.extend(kb_results.frameworks);
                languages.extend(kb_results.languages);
                databases.extend(kb_results.databases);
                confidence_score += kb_results.confidence_score * 0.1; // 10% weight
            }
        }

        Ok(DetectionResults {
            frameworks: dedupe_frameworks(frameworks),
            languages: dedupe_languages(languages),
            databases: dedupe_databases(databases),
            confidence_score: confidence_score.min(1.0),
        })
    }

    /// Match patterns against known frameworks (no file scanning)
    ///
    /// Useful when you already have patterns extracted.
    pub async fn match_patterns_against_known_frameworks(
        &self,
        patterns: &[String],
    ) -> Result<Vec<FrameworkDetection>> {
        let mut detections = Vec::new();
        let mut seen = HashSet::new();

        for pattern in patterns {
            let pattern_lower = pattern.to_lowercase();
            for hint in FRAMEWORK_HINTS {
                if hint.patterns.iter().any(|p| pattern_lower.contains(p)) && seen.insert(hint.name) {
                    detections.push(FrameworkDetection {
                        name: hint.name.to_string(),
                        version: None,
                        confidence: 0.6,
                        detected_by: DetectionMethod::MatchedCodePattern,
                        evidence: vec![format!("Matched external pattern '{}'", pattern)],
                    });
                }
            }
        }

        Ok(detections)
    }

    /// Force AI analysis of unknown framework (expensive!)
    ///
    /// Only use this when other methods fail.
    /// Costs tokens/money!
    pub async fn identify_unknown_framework_with_ai(
        &self,
        code_sample: &str,
        patterns: &[String],
    ) -> Result<FrameworkDetection> {
        let ai_client = self.ai_client.as_ref()
            .ok_or_else(|| anyhow::anyhow!("AI analysis not available - no NATS connection"))?;

        // Build context from available information
        let context = format!(
            "Code sample length: {} characters\n\
            Detected patterns: {}\n\
            Analysis context: Unknown framework detection",
            code_sample.len(),
            patterns.join(", ")
        );

        // Call AI for analysis
        let ai_response = ai_client.analyze_framework(code_sample, patterns, &context).await?;

        // Convert AI response to FrameworkDetection
        Ok(FrameworkDetection {
            name: ai_response.framework_name,
            version: ai_response.version,
            confidence: ai_response.confidence,
            detected_by: DetectionMethod::AiAnalysis,
            evidence: ai_response.evidence,
        })
    }

    // Level 1: Config file detection
    async fn scan_config_files_for_dependencies(&self, path: &Path) -> Result<DetectionResults> {
        use walkdir::WalkDir;

        let mut frameworks = Vec::new();
        let mut languages = Vec::new();
        let mut databases = Vec::new();
        let mut confidence_score: f32 = 0.0;

        for entry in WalkDir::new(path).max_depth(4) {
            let entry = entry?;
            if !entry.file_type().is_file() {
                continue;
            }

            let file_path = entry.path();
            if !is_package_manifest(file_path) {
                continue;
            }

            if let Ok(deps) = self.dependency_parser.parse_package_file(file_path) {
                if deps.is_empty() {
                    continue;
                }

                confidence_score += 0.1;
                for dep in deps {
                    if let Some(framework) = framework_from_dependency(&dep, file_path) {
                        frameworks.push(framework);
                        confidence_score += 0.05;
                    }

                    if let Some(db) = database_from_dependency(&dep, file_path) {
                        databases.push(db);
                    }

                    for lang in languages_for_dependency(&dep) {
                        languages.push(LanguageDetection {
                            name: lang.to_string(),
                            version: None,
                            confidence: 0.65,
                            detected_by: DetectionMethod::FoundInConfigFiles,
                        });
                    }
                }
            }
        }

        Ok(DetectionResults {
            frameworks,
            languages,
            databases,
            confidence_score: confidence_score.min(1.0),
        })
    }

    // Level 2: Pattern matching
    async fn match_code_patterns_against_templates(&self, path: &Path) -> Result<DetectionResults> {
        use walkdir::WalkDir;

        let mut frameworks = Vec::new();
        let mut languages = Vec::new();
        let mut databases = Vec::new();
        let mut confidence_hits: f32 = 0.0;
        let mut files_scanned = 0usize;

        for entry in WalkDir::new(path).max_depth(8).into_iter().filter_map(|e| e.ok()) {
            if files_scanned >= MAX_PATTERN_SCAN_FILES {
                break;
            }

            if !entry.file_type().is_file() {
                continue;
            }

            let meta = match entry.metadata() {
                Ok(meta) => meta,
                Err(_) => continue,
            };

            if meta.len() > MAX_PATTERN_FILE_SIZE {
                continue;
            }

            let file_path = entry.path().to_path_buf();
            let extension = file_path
                .extension()
                .and_then(|e| e.to_str())
                .unwrap_or("")
                .to_lowercase();

            if let Some(language) = language_from_extension(&extension) {
                languages.push(LanguageDetection {
                    name: language.to_string(),
                    version: None,
                    confidence: 0.5,
                    detected_by: DetectionMethod::MatchedCodePattern,
                });
            }

            let content = match fs::read_to_string(&file_path) {
                Ok(content) => content,
                Err(_) => continue,
            };
            let content_lower = content.to_lowercase();

            for hint in FRAMEWORK_HINTS {
                if hint.patterns.iter().any(|pattern| content_lower.contains(pattern)) {
                    frameworks.push(FrameworkDetection {
                        name: hint.name.to_string(),
                        version: None,
                        confidence: 0.65,
                        detected_by: DetectionMethod::MatchedCodePattern,
                        evidence: vec![format!(
                            "Matched pattern in {}",
                            file_path.display()
                        )],
                    });

                    for language in hint.languages {
                        languages.push(LanguageDetection {
                            name: (*language).to_string(),
                            version: None,
                            confidence: 0.55,
                            detected_by: DetectionMethod::MatchedCodePattern,
                        });
                    }

                    for database in hint.databases {
                        databases.push(DatabaseDetection {
                            name: (*database).to_string(),
                            version: None,
                            confidence: 0.5,
                            detected_by: DetectionMethod::MatchedCodePattern,
                        });
                    }

                    confidence_hits += 0.1;
                }
            }

            for db_hint in DATABASE_HINTS {
                if db_hint.patterns.iter().any(|pattern| content_lower.contains(pattern)) {
                    databases.push(DatabaseDetection {
                        name: db_hint.name.to_string(),
                        version: None,
                        confidence: 0.45,
                        detected_by: DetectionMethod::MatchedCodePattern,
                    });
                    confidence_hits += 0.05;
                }
            }

            files_scanned += 1;
        }

        Ok(DetectionResults {
            frameworks,
            languages,
            databases,
            confidence_score: confidence_hits.min(0.9),
        })
    }

    // Level 3: AST analysis using source-code-parser
    async fn parse_code_structure_with_tree_sitter(&self, path: &Path) -> Result<DetectionResults> {
        use walkdir::WalkDir;

        let Some(parser) = &self.parser else {
            return Ok(DetectionResults {
                frameworks: vec![],
                languages: vec![],
                databases: vec![],
                confidence_score: 0.0,
            });
        };

        let mut frameworks = Vec::new();
        let mut languages = Vec::new();
        let mut databases = Vec::new();
        let mut files_processed = 0usize;
        let mut confidence_total = 0.0f32;

        let mut candidate_files: Vec<(PathBuf, ProgrammingLanguage)> = Vec::new();
        for entry in WalkDir::new(path).max_depth(8).into_iter().filter_map(|e| e.ok()) {
            if files_processed >= MAX_AST_FILES {
                break;
            }

            if !entry.file_type().is_file() {
                continue;
            }

            let meta = match entry.metadata() {
                Ok(meta) => meta,
                Err(_) => continue,
            };

            if meta.len() > MAX_AST_FILE_SIZE {
                continue;
            }

            let extension = entry
                .path()
                .extension()
                .and_then(|e| e.to_str())
                .unwrap_or("")
                .to_lowercase();

            let language = ProgrammingLanguage::from_extension(&extension);
            if matches!(
                language,
                ProgrammingLanguage::LanguageNotSupported | ProgrammingLanguage::Unknown
            ) {
                continue;
            }

            candidate_files.push((entry.path().to_path_buf(), language));
        }

        for (file_path, language) in candidate_files.into_iter().take(MAX_AST_FILES) {
            files_processed += 1;
            let content = match tokio_fs::read_to_string(&file_path).await {
                Ok(content) => content,
                Err(_) => continue,
            };

            let analysis = match parser
                .analyze_with_all_tools(&content, language, file_path.to_string_lossy().as_ref())
                .await
            {
                Ok(result) => result,
                Err(_) => continue,
            };

            let mut stage_confidence = 0.0f32;

            let mut file_frameworks = self.extract_frameworks_from_ast(&analysis);
            if !file_frameworks.is_empty() {
                stage_confidence += 0.2;
                frameworks.append(&mut file_frameworks);
            }

            let mut file_languages = self.extract_languages_from_ast(&analysis);
            if !file_languages.is_empty() {
                stage_confidence += 0.1;
                languages.append(&mut file_languages);
            }

            let mut file_databases = self.extract_databases_from_ast(&analysis);
            if !file_databases.is_empty() {
                stage_confidence += 0.1;
                databases.append(&mut file_databases);
            }

            confidence_total += stage_confidence;
        }

        if files_processed == 0 {
            return Ok(DetectionResults {
                frameworks,
                languages,
                databases,
                confidence_score: 0.0,
            });
        }

        Ok(DetectionResults {
            frameworks,
            languages,
            databases,
            confidence_score: (confidence_total / files_processed as f32).min(0.8),
        })
    }

    // Level 4: Knowledge base lookup
    async fn cross_reference_with_knowledge_base(
        &self,
        frameworks: &[FrameworkDetection],
    ) -> Result<DetectionResults> {
        let mut languages = Vec::new();
        let mut databases = Vec::new();

        for framework in frameworks {
            if let Some(extra_languages) = knowledge_base_languages(&framework.name) {
                for language in extra_languages {
                    languages.push(LanguageDetection {
                        name: language.to_string(),
                        version: None,
                        confidence: 0.5,
                        detected_by: DetectionMethod::KnowledgeBaseMatch,
                    });
                }
            }

            if let Some(extra_databases) = knowledge_base_databases(&framework.name) {
                for database in extra_databases {
                    databases.push(DatabaseDetection {
                        name: database.to_string(),
                        version: None,
                        confidence: 0.45,
                        detected_by: DetectionMethod::KnowledgeBaseMatch,
                    });
                }
            }
        }

        let confidence = if languages.is_empty() && databases.is_empty() {
            0.0
        } else {
            0.3
        };

        Ok(DetectionResults {
            frameworks: vec![],
            languages,
            databases,
            confidence_score: confidence,
        })
    }

    // Helper methods for AST analysis
    fn extract_frameworks_from_ast(&self, analysis: &AnalysisResult) -> Vec<FrameworkDetection> {
        let mut detections = Vec::new();

        if let Some(ts) = &analysis.tree_sitter_analysis {
            for import in &ts.imports {
                detections.extend(frameworks_from_identifier(
                    import,
                    DetectionMethod::ParsedCodeStructure,
                    format!("Import '{}'", import),
                ));
            }

            for class in &ts.classes {
                detections.extend(frameworks_from_identifier(
                    &class.name,
                    DetectionMethod::ParsedCodeStructure,
                    format!("Class '{}'", class.name),
                ));
            }
        }

        if let Some(dependencies) = &analysis.dependency_analysis {
            for dep in &dependencies.dependencies {
                detections.extend(frameworks_from_identifier(
                    dep,
                    DetectionMethod::ParsedCodeStructure,
                    format!("Dependency '{}'", dep),
                ));
            }
        }

        detections
    }

    fn extract_languages_from_ast(&self, analysis: &AnalysisResult) -> Vec<LanguageDetection> {
        let mut detections = Vec::new();

        if let Some(language) = normalize_language_label(&analysis.language) {
            detections.push(LanguageDetection {
                name: language.to_string(),
                version: None,
                confidence: 0.7,
                detected_by: DetectionMethod::ParsedCodeStructure,
            });
        }

        if let Some(ts) = &analysis.tree_sitter_analysis {
            for import in &ts.imports {
                for language in languages_from_identifier(import) {
                    detections.push(LanguageDetection {
                        name: language.to_string(),
                        version: None,
                        confidence: 0.55,
                        detected_by: DetectionMethod::ParsedCodeStructure,
                    });
                }
            }
        }

        detections
    }

    fn extract_databases_from_ast(&self, analysis: &AnalysisResult) -> Vec<DatabaseDetection> {
        let mut detections = Vec::new();

        if let Some(ts) = &analysis.tree_sitter_analysis {
            for import in &ts.imports {
                detections.extend(databases_from_identifier(
                    import,
                    DetectionMethod::ParsedCodeStructure,
                ));
            }
        }

        if let Some(dependencies) = &analysis.dependency_analysis {
            for dep in &dependencies.dependencies {
                detections.extend(databases_from_identifier(
                    dep,
                    DetectionMethod::ParsedCodeStructure,
                ));
            }
        }

        detections
    }
}
