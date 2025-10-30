//! Benchmarks for Code Quality Engine performance testing

use criterion::{black_box, criterion_group, criterion_main, Criterion};
use code_quality_engine::analyzer::CodebaseAnalyzer;

fn bench_analyze_rust_code(c: &mut Criterion) {
    let analyzer = CodebaseAnalyzer::new();
    let rust_code = include_str!("../examples/sample_rust_code.rs");

    c.bench_function("analyze_rust_code", |b| {
        b.iter(|| {
            let _result = analyzer.analyze_language(black_box(rust_code), black_box("rust"));
        })
    });
}

fn bench_extract_functions(c: &mut Criterion) {
    let analyzer = CodebaseAnalyzer::new();
    let rust_code = include_str!("../examples/sample_rust_code.rs");

    c.bench_function("extract_functions", |b| {
        b.iter(|| {
            let _functions = analyzer.extract_functions(black_box(rust_code), black_box("rust"));
        })
    });
}

fn bench_language_detection(c: &mut Criterion) {
    let analyzer = CodebaseAnalyzer::new();
    let languages = vec!["rust", "python", "javascript", "typescript", "go", "java"];

    c.bench_function("language_support_check", |b| {
        b.iter(|| {
            for lang in &languages {
                let _supported = analyzer.is_language_supported(black_box(lang));
            }
        })
    });
}

fn bench_cross_language_patterns(c: &mut Criterion) {
    let analyzer = CodebaseAnalyzer::new();
    let files = vec![
        ("rust".to_string(), include_str!("../examples/sample_rust_code.rs").to_string()),
        ("python".to_string(), include_str!("../examples/sample_python_code.py").to_string()),
    ];

    c.bench_function("cross_language_patterns", |b| {
        b.iter(|| {
            let _patterns = analyzer.detect_cross_language_patterns(black_box(&files));
        })
    });
}

fn bench_language_rules(c: &mut Criterion) {
    let analyzer = CodebaseAnalyzer::new();
    let rust_code = include_str!("../examples/sample_rust_code.rs");

    c.bench_function("language_rules_check", |b| {
        b.iter(|| {
            let _violations = analyzer.check_language_rules(black_box(rust_code), black_box("rust"));
        })
    });
}

criterion_group!(
    benches,
    bench_analyze_rust_code,
    bench_extract_functions,
    bench_language_detection,
    bench_cross_language_patterns,
    bench_language_rules
);
criterion_main!(benches);