use std::fs;
use std::path::Path;

fn main() {
  // NOTE: Template generation moved to unified system (templates_data + PostgreSQL)
  // All templates are now loaded at runtime via Singularity.TemplateStore
  // See: templates_data/ directory and TemplateStore implementation

  let out_dir = std::env::var("OUT_DIR").unwrap();
  let generated_file = Path::new(&out_dir).join("ai_templates.rs");

  // Generate empty stub - templates are loaded at runtime from the unified system
  let stub_code = r#"
// Template loading is handled by the unified system
// See: Singularity.TemplateStore in nexus/singularity/lib/singularity/templates/
// Source: templates_data/ directory
// Storage: PostgreSQL code_generation_templates table
// Runtime: TemplateCache (ETS) + TemplateStore API

/// Legacy stub - do not use
/// Use Singularity.TemplateStore for runtime template access instead
pub fn get_ai_templates() -> Vec<std::string::String> {
    vec![]  // All templates loaded via TemplateStore at runtime
}
"#;

  fs::write(&generated_file, stub_code)
    .expect("Failed to write generated template stub");

  println!("cargo:warning=Using unified template system (templates_data + TemplateStore + PostgreSQL)");
}
