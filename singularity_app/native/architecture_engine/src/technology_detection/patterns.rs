//! Framework Pattern Definitions
//!
//! Predefined patterns for common frameworks and libraries.

use super::detector::{FrameworkCategory, FrameworkPattern};

/// Built-in framework patterns
pub struct BuiltinPatterns;

impl BuiltinPatterns {
    /// Get all built-in patterns
    pub fn get_all() -> Vec<FrameworkPattern> {
        vec![
            Self::react_pattern(),
            Self::vue_pattern(),
            Self::angular_pattern(),
            Self::express_pattern(),
            Self::spring_pattern(),
            Self::django_pattern(),
            Self::phoenix_pattern(),
            Self::fastapi_pattern(),
            Self::flask_pattern(),
            Self::rails_pattern(),
        ]
    }

    fn react_pattern() -> FrameworkPattern {
        FrameworkPattern {
            name: "react".to_string(),
            patterns: vec![
                r#"import.*from.*["']react["']"#.to_string(),
                r"React\.Component".to_string(),
                r"useState|useEffect|useContext".to_string(),
                r"<[A-Z][a-zA-Z]*".to_string(), // JSX components
            ],
            category: FrameworkCategory::WebFramework,
            weight: 1.0,
            version_patterns: vec![
                r#"react["']?\s*:\s*["']([^"']+)["']"#.to_string(),
                r#"@types/react["']?\s*:\s*["']([^"']+)["']"#.to_string(),
            ],
        }
    }

    fn vue_pattern() -> FrameworkPattern {
        FrameworkPattern {
            name: "vue".to_string(),
            patterns: vec![
                r#"import.*from.*["']vue["']"#.to_string(),
                r"Vue\.component".to_string(),
                r"export default".to_string(),
                r"<template>".to_string(),
                r#"<script.*lang=["']ts["']"#.to_string(),
            ],
            category: FrameworkCategory::WebFramework,
            weight: 1.0,
            version_patterns: vec![
                r#"vue["']?\s*:\s*["']([^"']+)["']"#.to_string(),
                r#"@vue/cli-service["']?\s*:\s*["']([^"']+)["']"#.to_string(),
            ],
        }
    }

    fn angular_pattern() -> FrameworkPattern {
        FrameworkPattern {
            name: "angular".to_string(),
            patterns: vec![
                r"@Component".to_string(),
                r"@Injectable".to_string(),
                r"import.*@angular".to_string(),
                r"NgModule".to_string(),
                r"@angular/core".to_string(),
            ],
            category: FrameworkCategory::WebFramework,
            weight: 1.0,
            version_patterns: vec![
                r#"@angular/core["']?\s*:\s*["']([^"']+)["']"#.to_string(),
                r#"@angular/cli["']?\s*:\s*["']([^"']+)["']"#.to_string(),
            ],
        }
    }

    fn express_pattern() -> FrameworkPattern {
        FrameworkPattern {
            name: "express".to_string(),
            patterns: vec![
                r#"require\(["']express["']\)"#.to_string(),
                r"app\.get|app\.post|app\.put|app\.delete".to_string(),
                r"express\.Router".to_string(),
                r"app\.use".to_string(),
            ],
            category: FrameworkCategory::WebFramework,
            weight: 1.0,
            version_patterns: vec![r#"express["']?\s*:\s*["']([^"']+)["']"#.to_string()],
        }
    }

    fn spring_pattern() -> FrameworkPattern {
        FrameworkPattern {
            name: "spring".to_string(),
            patterns: vec![
                r"@SpringBootApplication".to_string(),
                r"@RestController".to_string(),
                r"@Service".to_string(),
                r"@Repository".to_string(),
                r"@Autowired".to_string(),
            ],
            category: FrameworkCategory::WebFramework,
            weight: 1.0,
            version_patterns: vec![r#"spring-boot-starter["']?\s*:\s*["']([^"']+)["']"#.to_string()],
        }
    }

    fn django_pattern() -> FrameworkPattern {
        FrameworkPattern {
            name: "django".to_string(),
            patterns: vec![
                r"from django".to_string(),
                r"class.*View".to_string(),
                r"urlpatterns".to_string(),
                r"django\.conf".to_string(),
                r"models\.Model".to_string(),
            ],
            category: FrameworkCategory::WebFramework,
            weight: 1.0,
            version_patterns: vec![r#"Django["']?\s*==\s*([^"']+)"#.to_string()],
        }
    }

    fn phoenix_pattern() -> FrameworkPattern {
        FrameworkPattern {
            name: "phoenix".to_string(),
            patterns: vec![
                r"use Phoenix".to_string(),
                r"defmodule.*Controller".to_string(),
                r"plug".to_string(),
                r"Phoenix\.Controller".to_string(),
                r"Phoenix\.LiveView".to_string(),
            ],
            category: FrameworkCategory::WebFramework,
            weight: 1.0,
            version_patterns: vec![r"phoenix['\']?\s*:\s*['\']([^\'\']+)['\']".to_string()],
        }
    }

    fn fastapi_pattern() -> FrameworkPattern {
        FrameworkPattern {
            name: "fastapi".to_string(),
            patterns: vec![
                r"from fastapi".to_string(),
                r"@app\.get|@app\.post|@app\.put|@app\.delete".to_string(),
                r"FastAPI\(".to_string(),
                r"APIRouter".to_string(),
            ],
            category: FrameworkCategory::WebFramework,
            weight: 1.0,
            version_patterns: vec![r"fastapi['\']?\s*==\s*([^\'\']+)".to_string()],
        }
    }

    fn flask_pattern() -> FrameworkPattern {
        FrameworkPattern {
            name: "flask".to_string(),
            patterns: vec![
                r"from flask".to_string(),
                r"@app\.route".to_string(),
                r"Flask\(".to_string(),
                r"request\.json".to_string(),
            ],
            category: FrameworkCategory::WebFramework,
            weight: 1.0,
            version_patterns: vec![r"Flask['\']?\s*==\s*([^\'\']+)".to_string()],
        }
    }

    fn rails_pattern() -> FrameworkPattern {
        FrameworkPattern {
            name: "rails".to_string(),
            patterns: vec![
                r"class.*Controller".to_string(),
                r"ApplicationController".to_string(),
                r"ActiveRecord::Base".to_string(),
                r"rails generate".to_string(),
            ],
            category: FrameworkCategory::WebFramework,
            weight: 1.0,
            version_patterns: vec![r"rails['\']?\s*['\']([^\'\']+)['\']".to_string()],
        }
    }
}
