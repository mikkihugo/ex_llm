//! Rust Feature Extractor
//!
//! Uses existing rust-parser to extract features from Rust code

use super::extractor::{ExtractedFeature, FeatureExtractor, FeatureType};
use anyhow::Result;
use std::path::Path;
use syn::{parse_file, File, Item, Visibility};

/// Rust feature extractor using syn parser
pub struct RustFeatureExtractor {}

impl RustFeatureExtractor {
    pub fn new() -> Result<Self> {
        Ok(Self {})
    }
}

impl FeatureExtractor for RustFeatureExtractor {
    fn extract_features(&self, source: &str, file_path: &Path) -> Result<Vec<ExtractedFeature>> {
        let mut features = Vec::new();

        // Parse with syn (same as rust-parser uses)
        let ast = parse_file(source)?;

        // Extract module path from file path
        let module_path = extract_module_path(file_path);

        // Walk the AST and extract public items
        for item in &ast.items {
            match item {
                // Extract public functions
                Item::Fn(func) => {
                    if is_public(&func.vis) {
                        features.push(ExtractedFeature {
                            name: func.sig.ident.to_string(),
                            feature_type: FeatureType::Function,
                            is_public: true,
                            documentation: extract_doc_comment(&func.attrs),
                            file_path: file_path.display().to_string(),
                            line_number: None, // syn doesn't easily give line numbers
                            signature: Some(quote::quote!(#func.sig).to_string()),
                            module_path: module_path.clone(),
                            metadata: serde_json::json!({
                                "is_async": func.sig.asyncness.is_some(),
                                "is_unsafe": func.sig.unsafety.is_some(),
                            }),
                        });
                    }
                }

                // Extract public structs
                Item::Struct(struct_item) => {
                    if is_public(&struct_item.vis) {
                        features.push(ExtractedFeature {
                            name: struct_item.ident.to_string(),
                            feature_type: FeatureType::Struct,
                            is_public: true,
                            documentation: extract_doc_comment(&struct_item.attrs),
                            file_path: file_path.display().to_string(),
                            line_number: None,
                            signature: Some(quote::quote!(#struct_item).to_string()),
                            module_path: module_path.clone(),
                            metadata: serde_json::json!({}),
                        });
                    }
                }

                // Extract public enums
                Item::Enum(enum_item) => {
                    if is_public(&enum_item.vis) {
                        features.push(ExtractedFeature {
                            name: enum_item.ident.to_string(),
                            feature_type: FeatureType::Enum,
                            is_public: true,
                            documentation: extract_doc_comment(&enum_item.attrs),
                            file_path: file_path.display().to_string(),
                            line_number: None,
                            signature: None,
                            module_path: module_path.clone(),
                            metadata: serde_json::json!({
                                "variant_count": enum_item.variants.len(),
                            }),
                        });
                    }
                }

                // Extract public traits
                Item::Trait(trait_item) => {
                    if is_public(&trait_item.vis) {
                        features.push(ExtractedFeature {
                            name: trait_item.ident.to_string(),
                            feature_type: FeatureType::Trait,
                            is_public: true,
                            documentation: extract_doc_comment(&trait_item.attrs),
                            file_path: file_path.display().to_string(),
                            line_number: None,
                            signature: None,
                            module_path: module_path.clone(),
                            metadata: serde_json::json!({
                                "method_count": trait_item.items.len(),
                            }),
                        });
                    }
                }

                // Could also extract: impls, constants, modules, etc.
                _ => {}
            }
        }

        Ok(features)
    }

    fn name(&self) -> &str {
        "RustFeatureExtractor"
    }
}

/// Check if visibility is public
fn is_public(vis: &Visibility) -> bool {
    matches!(vis, Visibility::Public(_))
}

/// Extract documentation from attributes
fn extract_doc_comment(attrs: &[syn::Attribute]) -> Option<String> {
    let mut docs = Vec::new();

    for attr in attrs {
        if attr.path().is_ident("doc") {
            if let syn::Meta::NameValue(meta) = &attr.meta {
                if let syn::Expr::Lit(expr_lit) = &meta.value {
                    if let syn::Lit::Str(lit_str) = &expr_lit.lit {
                        docs.push(lit_str.value());
                    }
                }
            }
        }
    }

    if docs.is_empty() {
        None
    } else {
        Some(docs.join("\n").trim().to_string())
    }
}

/// Extract module path from file path
/// e.g., "crates/code-engine/src/feature/extractor.rs" -> "code_engine::feature::extractor"
fn extract_module_path(file_path: &Path) -> String {
    let path_str = file_path.display().to_string();

    // Extract from "src/" onwards
    if let Some(src_idx) = path_str.find("/src/") {
        let after_src = &path_str[src_idx + 5..]; // +5 to skip "/src/"
        let without_ext = after_src.strip_suffix(".rs").unwrap_or(after_src);

        // Convert path to module path
        let module = without_ext.replace("/", "::").replace("-", "_");

        return module;
    }

    // Fallback
    "unknown".to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_extract_public_function() {
        let extractor = RustFeatureExtractor::new().unwrap();

        let source = r#"
/// This is a public function
pub fn hello_world() -> String {
    "Hello, world!".to_string()
}

fn private_function() {
    // Not extracted
}
"#;

        let features = extractor
            .extract_features(source, Path::new("test.rs"))
            .unwrap();

        assert_eq!(features.len(), 1);
        assert_eq!(features[0].name, "hello_world");
        assert_eq!(features[0].feature_type, FeatureType::Function);
        assert!(features[0].is_public);
        assert!(features[0].documentation.is_some());
    }

    #[test]
    fn test_extract_public_struct() {
        let extractor = RustFeatureExtractor::new().unwrap();

        let source = r#"
/// A public struct
pub struct MyStruct {
    pub field: String,
}
"#;

        let features = extractor
            .extract_features(source, Path::new("test.rs"))
            .unwrap();

        assert_eq!(features.len(), 1);
        assert_eq!(features[0].name, "MyStruct");
        assert_eq!(features[0].feature_type, FeatureType::Struct);
    }

    #[test]
    fn test_extract_module_path() {
        let path = Path::new("crates/analysis-suite/src/feature/extractor.rs");
        let module_path = extract_module_path(path);

        assert_eq!(module_path, "feature::extractor");
    }
}
