use ast_grep_core::{language::Language, matcher::PatternBuilder, Pattern, PatternError};
use ast_grep_core::tree_sitter::{LanguageExt, StrDoc, TSLanguage};

macro_rules! impl_language {
    ($name:ident, $lang:expr) => {
        #[derive(Clone, Default)]
        pub struct $name;

        impl Language for $name {
            fn kind_to_id(&self, kind: &str) -> u16 {
                let lang: TSLanguage = $lang.into();
                lang.id_for_node_kind(kind, true)
            }

            fn field_to_id(&self, field: &str) -> Option<u16> {
                let lang: TSLanguage = $lang.into();
                lang.field_id_for_name(field).map(|id| id.get())
            }

            fn build_pattern(&self, builder: &PatternBuilder) -> Result<Pattern, PatternError> {
                builder.build(|src| StrDoc::try_new(src, self.clone()))
            }
        }

        impl LanguageExt for $name {
            fn get_ts_language(&self) -> TSLanguage {
                $lang.into()
            }
        }
    };
}

impl_language!(ElixirLang, tree_sitter_elixir::LANGUAGE);
impl_language!(ErlangLang, tree_sitter_erlang::LANGUAGE);
impl_language!(GleamLang, tree_sitter_gleam::LANGUAGE);
impl_language!(RustLang, tree_sitter_rust::LANGUAGE);
impl_language!(JavaScriptLang, tree_sitter_javascript::LANGUAGE);
impl_language!(TypeScriptLang, tree_sitter_typescript::LANGUAGE_TYPESCRIPT);
impl_language!(PythonLang, tree_sitter_python::LANGUAGE);
impl_language!(JavaLang, tree_sitter_java::LANGUAGE);
impl_language!(GoLang, tree_sitter_go::LANGUAGE);
impl_language!(CLang, tree_sitter_c::LANGUAGE);
impl_language!(CppLang, tree_sitter_cpp::LANGUAGE);
impl_language!(BashLang, tree_sitter_bash::LANGUAGE);
impl_language!(JsonLang, tree_sitter_json::LANGUAGE);
impl_language!(YamlLang, tree_sitter_yaml::LANGUAGE);
impl_language!(LuaLang, tree_sitter_lua::LANGUAGE);
impl_language!(MarkdownLang, tree_sitter_md::LANGUAGE);

// Updated tree-sitter 0.25 compatible versions
impl_language!(SqlLang, tree_sitter_sequel::LANGUAGE);
impl_language!(DockerfileLang, tree_sitter_dockerfile_updated::language());  // Uses function, not constant
impl_language!(TomlLang, tree_sitter_toml_ng::LANGUAGE);
