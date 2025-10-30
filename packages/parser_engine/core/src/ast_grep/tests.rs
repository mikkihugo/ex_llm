use super::engine::AstGrep;
use super::lint::{LintRule, Severity};
use super::pattern::{Pattern, TransformOptions};

#[test]
fn new_accepts_supported_language() {
    let grep = AstGrep::new("rust");
    assert!(grep.is_ok());
}

#[test]
fn new_rejects_unknown_language() {
    let grep = AstGrep::new("klingon");
    assert!(grep.is_err());
}

#[test]
fn structural_search_finds_console_log() {
    let mut grep = AstGrep::new("javascript").unwrap();
    let source = "console.log(\"hello\", user);";
    let pattern = Pattern::new("console.log($$$ARGS)");

    let matches = grep.search(source, &pattern).unwrap();
    assert_eq!(matches.len(), 1);
    assert_eq!(matches[0].text.trim(), "console.log(\"hello\", user)");
}

#[test]
fn replace_transforms_source() {
    let mut grep = AstGrep::new("javascript").unwrap();
    let source = "console.log(message);";
    let find = Pattern::new("console.log($MSG)");
    let replace = Pattern::new("logger.debug($MSG)");

    let replaced = grep.replace(source, &find, &replace).unwrap();
    assert!(replaced.contains("logger.debug"));
    assert!(!replaced.contains("console.log"));
}

#[test]
fn replace_respects_transform_options() {
    let mut grep = AstGrep::new("javascript").unwrap();
    let source = "    console.log(value); // keep\n";
    let find = Pattern::new("console.log($VAL)");
    let replace = Pattern::new("logger.debug($VAL)");
    let options = TransformOptions {
        preserve_whitespace: true,
        preserve_comments: true,
        ..Default::default()
    };

    let replaced = grep
        .replace_with_options(source, &find, &replace, &options)
        .unwrap();

    assert!(
        replaced.contains("    logger.debug(value); // keep"),
        "replacement should keep indentation and comment, got: {replaced}"
    );
}

#[test]
fn replace_with_backup_appends_original_block() {
    let mut grep = AstGrep::new("javascript").unwrap();
    let source = "console.log('backup test');";
    let find = Pattern::new("console.log($MSG)");
    let replace = Pattern::new("logger.debug($MSG)");
    let options = TransformOptions {
        backup_original: true,
        ..Default::default()
    };

    let replaced = grep
        .replace_with_options(source, &find, &replace, &options)
        .unwrap();

    assert!(
        replaced.contains("/* original:"),
        "replacement should include backup block, got: {replaced}"
    );
}

#[test]
fn lint_reports_violations() {
    let mut grep = AstGrep::new("javascript").unwrap();
    let source = "console.log('hello');";
    let rule = LintRule::new(
        "no-console",
        "Avoid using console.log",
        Pattern::new("console.log($$$ARGS)"),
    )
    .with_severity(Severity::Warning)
    .with_fix(Pattern::new("logger.debug($$$ARGS)").as_str());

    let violations = grep.lint(source, &[rule]).unwrap();
    assert_eq!(violations.len(), 1);
    assert_eq!(violations[0].text.trim(), "console.log('hello')");
}
