pub mod config;
pub mod engine;
pub mod errors;
pub mod language;
pub mod languages;
pub mod lint;
pub mod pattern;
pub mod result;
pub mod stats;

pub use config::AstGrepConfig;
pub use engine::AstGrep;
pub use errors::AstGrepError;
pub use language::{supported_language_aliases, SupportedLanguage};
pub use lint::{LintRule, LintViolation, Severity};
pub use pattern::{Pattern, PatternFlags, TransformOptions};
pub use result::{MatchContext, SearchResult};
pub use stats::SearchStats;

#[cfg(test)]
mod tests;
