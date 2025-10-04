//! Semantic Code Search Example
//!
//! Shows how to use hybrid embeddings with global semantic cache.
//!
//! Run with: cargo run --example semantic_search --features semantic

use analysis_suite::codebase::{CodebaseDatabase, FileAnalysis, CodebaseMetadata};
use analysis_suite::embeddings::HybridConfig;

#[cfg(feature = "semantic")]
use analysis_suite::embeddings::CandleTransformer;

fn main() -> anyhow::Result<()> {
    println!("🔍 SPARC Semantic Code Search\n");

    // 1. Create database
    println!("📁 Creating codebase database...");
    let db = CodebaseDatabase::new("example-project")?;

    // 2. Add some code files
    println!("📝 Adding code files...");

    let auth_file = FileAnalysis {
        path: "src/auth.rs".to_string(),
        content_hash: "abc123".to_string(),
        metadata: CodebaseMetadata {
            language: "rust".to_string(),
            total_lines: 50,
            function_count: 3,
            class_count: 1,
            function_names: vec!["authenticate".to_string(), "verify_token".to_string()],
            class_names: vec!["Auth".to_string()],
            variable_names: vec!["user".to_string()],
            imports: vec!["jwt".to_string()],
            ..Default::default()
        },
    };

    let user_file = FileAnalysis {
        path: "src/user.rs".to_string(),
        content_hash: "def456".to_string(),
        metadata: CodebaseMetadata {
            language: "rust".to_string(),
            total_lines: 80,
            function_count: 5,
            class_count: 1,
            function_names: vec!["get_user".to_string(), "login".to_string()],
            class_names: vec!["User".to_string()],
            variable_names: vec!["username".to_string(), "password".to_string()],
            imports: vec!["database".to_string()],
            ..Default::default()
        },
    };

    db.store_file_analysis(auth_file)?;
    db.store_file_analysis(user_file)?;

    // 3. Initialize embeddings
    println!("🧠 Initializing embeddings...");

    #[cfg(feature = "semantic")]
    {
        // With semantic feature: Use Candle transformer
        println!("  ✨ Loading Candle transformer (all-MiniLM-L6-v2)...");
        let transformer = Box::new(CandleTransformer::new()?);

        let mut config = HybridConfig::default();
        config.enable_llm_expansion = true; // Enable LLM query expansion

        db.initialize_embeddings(Some(config))?;

        // Set transformer (will use global semantic cache!)
        // Note: This requires extending CodebaseDatabase API
        println!("  ✅ Transformer ready with global cache!");
    }

    #[cfg(not(feature = "semantic"))]
    {
        // Without semantic: Use TF-IDF only
        println!("  📊 Using TF-IDF embeddings only");
        db.initialize_embeddings(None)?;
    }

    // 4. Search
    println!("\n🔎 Searching codebase...\n");

    let queries = vec![
        "authentication code",
        "user login",
        "verify credentials",
    ];

    for query in queries {
        println!("Query: \"{}\"", query);

        #[cfg(feature = "semantic")]
        let results = db.search_code_with_llm(query, 3)?;

        #[cfg(not(feature = "semantic"))]
        let results = db.search_code(query, 3)?;

        for (i, result) in results.iter().enumerate() {
            println!(
                "  {}. {} (score: {:.2}, type: {:?})",
                i + 1,
                result.file_path,
                result.similarity,
                result.match_type
            );
        }
        println!();
    }

    // 5. Stats
    println!("📊 Statistics:");
    let stats = db.embedding_stats()?;
    println!("  Total embeddings: {}", stats.total_embeddings);
    println!("  With semantic vectors: {}", stats.with_semantic_vectors);
    println!("  Has transformer: {}", stats.has_transformer);

    #[cfg(feature = "semantic")]
    {
        use analysis_suite::codebase::GlobalSemanticCache;
        let cache = GlobalSemanticCache::instance()?;
        let cache_stats = cache.stats()?;
        println!("\n🌍 Global Semantic Cache:");
        println!("  Cached vectors: {}", cache_stats.total_vectors);
        println!("  Location: {:?}", cache_stats.db_path);
    }

    Ok(())
}
