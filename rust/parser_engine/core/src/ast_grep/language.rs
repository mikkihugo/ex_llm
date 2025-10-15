#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum SupportedLanguage {
    Elixir,
    Erlang,
    Gleam,
    Rust,
    JavaScript,
    TypeScript,
    Python,
    Java,
    Go,
    C,
    Cpp,
    Bash,
    Json,
    Yaml,
    Lua,
    Markdown,
    Dockerfile,
    Toml,
    Sql,
}

const LANGUAGE_ALIASES: &[(&str, SupportedLanguage)] = &[
    ("elixir", SupportedLanguage::Elixir),
    ("erlang", SupportedLanguage::Erlang),
    ("gleam", SupportedLanguage::Gleam),
    ("rust", SupportedLanguage::Rust),
    ("javascript", SupportedLanguage::JavaScript),
    ("js", SupportedLanguage::JavaScript),
    ("typescript", SupportedLanguage::TypeScript),
    ("ts", SupportedLanguage::TypeScript),
    ("python", SupportedLanguage::Python),
    ("py", SupportedLanguage::Python),
    ("java", SupportedLanguage::Java),
    ("go", SupportedLanguage::Go),
    ("golang", SupportedLanguage::Go),
    ("c", SupportedLanguage::C),
    ("cpp", SupportedLanguage::Cpp),
    ("c++", SupportedLanguage::Cpp),
    ("bash", SupportedLanguage::Bash),
    ("sh", SupportedLanguage::Bash),
    ("json", SupportedLanguage::Json),
    ("yaml", SupportedLanguage::Yaml),
    ("yml", SupportedLanguage::Yaml),
    ("lua", SupportedLanguage::Lua),
    ("markdown", SupportedLanguage::Markdown),
    ("md", SupportedLanguage::Markdown),
];

pub fn supported_language_aliases() -> &'static [&'static str] {
    const ALIASES: &[&str] = &[
        "elixir",
        "erlang",
        "gleam",
        "rust",
        "javascript",
        "js",
        "typescript",
        "ts",
        "python",
        "py",
        "java",
        "go",
        "golang",
        "c",
        "cpp",
        "c++",
        "bash",
        "sh",
        "json",
        "yaml",
        "yml",
        "lua",
        "markdown",
        "md",
    ];
    ALIASES
}

impl SupportedLanguage {
    pub fn from_label(label: &str) -> Option<Self> {
        LANGUAGE_ALIASES
            .iter()
            .find_map(|(alias, lang)| (alias.eq_ignore_ascii_case(label)).then_some(*lang))
    }

    pub fn primary_alias(self) -> &'static str {
        match self {
            SupportedLanguage::Elixir => "elixir",
            SupportedLanguage::Erlang => "erlang",
            SupportedLanguage::Gleam => "gleam",
            SupportedLanguage::Rust => "rust",
            SupportedLanguage::JavaScript => "javascript",
            SupportedLanguage::TypeScript => "typescript",
            SupportedLanguage::Python => "python",
            SupportedLanguage::Java => "java",
            SupportedLanguage::Go => "go",
            SupportedLanguage::C => "c",
            SupportedLanguage::Cpp => "cpp",
            SupportedLanguage::Bash => "bash",
            SupportedLanguage::Json => "json",
            SupportedLanguage::Yaml => "yaml",
            SupportedLanguage::Lua => "lua",
            SupportedLanguage::Markdown => "markdown",
            SupportedLanguage::Dockerfile => "dockerfile",
            SupportedLanguage::Toml => "toml",
            SupportedLanguage::Sql => "sql",
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn resolves_aliases_case_insensitive() {
        assert_eq!(SupportedLanguage::from_label("TS"), Some(SupportedLanguage::TypeScript));
        assert_eq!(SupportedLanguage::from_label("Markdown"), Some(SupportedLanguage::Markdown));
        assert!(SupportedLanguage::from_label("unknown").is_none());
    }
}
