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

// Note: Dockerfile, TOML, and SQL use C bindings instead of direct Rust crates
use core::ffi::c_void;
use tree_sitter::Language as TsLanguage;
use tree_sitter_language::LanguageFn;

extern "C" {
    fn tree_sitter_dockerfile() -> *const c_void;
    fn tree_sitter_toml() -> *const c_void;
    fn tree_sitter_sql() -> *const c_void;
}

unsafe extern "C" fn dockerfile_language_raw() -> *const () {
    tree_sitter_dockerfile().cast()
}

unsafe extern "C" fn toml_language_raw() -> *const () {
    tree_sitter_toml().cast()
}

unsafe extern "C" fn sql_language_raw() -> *const () {
    tree_sitter_sql().cast()
}

fn dockerfile_language() -> TsLanguage {
    TsLanguage::new(unsafe { LanguageFn::from_raw(dockerfile_language_raw) })
}

fn toml_language() -> TsLanguage {
    TsLanguage::new(unsafe { LanguageFn::from_raw(toml_language_raw) })
}

fn sql_language() -> TsLanguage {
    TsLanguage::new(unsafe { LanguageFn::from_raw(sql_language_raw) })
}

#[derive(Clone, Default)]
pub struct DockerfileLang;

impl Language for DockerfileLang {
    fn kind_to_id(&self, kind: &str) -> u16 {
        dockerfile_language().id_for_node_kind(kind, true)
    }

    fn field_to_id(&self, field: &str) -> Option<u16> {
        dockerfile_language().field_id_for_name(field).map(|id| id.get())
    }

    fn build_pattern(&self, builder: &PatternBuilder) -> Result<Pattern, PatternError> {
        builder.build(|src| StrDoc::try_new(src, self.clone()))
    }
}

impl LanguageExt for DockerfileLang {
    fn get_ts_language(&self) -> TSLanguage {
        dockerfile_language()
    }
}

#[derive(Clone, Default)]
pub struct TomlLang;

impl Language for TomlLang {
    fn kind_to_id(&self, kind: &str) -> u16 {
        toml_language().id_for_node_kind(kind, true)
    }

    fn field_to_id(&self, field: &str) -> Option<u16> {
        toml_language().field_id_for_name(field).map(|id| id.get())
    }

    fn build_pattern(&self, builder: &PatternBuilder) -> Result<Pattern, PatternError> {
        builder.build(|src| StrDoc::try_new(src, self.clone()))
    }
}

impl LanguageExt for TomlLang {
    fn get_ts_language(&self) -> TSLanguage {
        toml_language()
    }
}

#[derive(Clone, Default)]
pub struct SqlLang;

impl Language for SqlLang {
    fn kind_to_id(&self, kind: &str) -> u16 {
        sql_language().id_for_node_kind(kind, true)
    }

    fn field_to_id(&self, field: &str) -> Option<u16> {
        sql_language().field_id_for_name(field).map(|id| id.get())
    }

    fn build_pattern(&self, builder: &PatternBuilder) -> Result<Pattern, PatternError> {
        builder.build(|src| StrDoc::try_new(src, self.clone()))
    }
}

impl LanguageExt for SqlLang {
    fn get_ts_language(&self) -> TSLanguage {
        sql_language()
    }
}
