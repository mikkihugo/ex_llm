/// Inspects Erlang tree-sitter node types
use tree_sitter::Parser;

fn main() {
    let language = tree_sitter_erlang::LANGUAGE.into();
    let mut parser = Parser::new();
    parser.set_language(&language).unwrap();

    let source_code = r#"
-module(test_erlang).
-export([factorial/1, is_even/1]).

%% Calculate factorial
factorial(0) -> 1;
factorial(N) when N > 0 ->
    N * factorial(N - 1).

%% Check if number is even
is_even(N) ->
    case N rem 2 of
        0 -> true;
        _ -> false
    end.
"#;

    let tree = parser.parse(source_code, None).unwrap();
    let root = tree.root_node();

    println!("=== Erlang Tree-Sitter Node Types ===\n");
    print_node(&root, source_code.as_bytes(), 0);

    println!("\n=== All Named Node Kinds ===");
    for i in 0..language.node_kind_count() {
        if language.node_kind_is_named(i as u16) {
            if let Some(kind) = language.node_kind_for_id(i as u16) {
                println!("{:3}: {}", i, kind);
            }
        }
    }
}

fn print_node(node: &tree_sitter::Node, source: &[u8], depth: usize) {
    let indent = "  ".repeat(depth);
    let kind = node.kind();
    let id = node.kind_id();

    if node.is_named() {
        let text = if node.child_count() == 0 {
            let bytes = &source[node.start_byte()..node.end_byte()];
            String::from_utf8_lossy(bytes).to_string()
        } else {
            String::new()
        };

        if !text.is_empty() && text.len() < 30 {
            println!("{}{} [{}] = \"{}\"", indent, kind, id, text);
        } else {
            println!("{}{} [{}]", indent, kind, id);
        }

        for i in 0..node.child_count() {
            if let Some(child) = node.child(i) {
                print_node(&child, source, depth + 1);
            }
        }
    }
}
