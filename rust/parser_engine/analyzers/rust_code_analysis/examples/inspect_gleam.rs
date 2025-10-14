/// Inspects Gleam tree-sitter node types
use tree_sitter::Parser;

fn main() {
    let language = tree_sitter_gleam::LANGUAGE.into();
    let mut parser = Parser::new();
    parser.set_language(&language).unwrap();

    let source_code = r#"
import gleam/io

pub fn add(a: Int, b: Int) -> Int {
  a + b
}

pub fn greet(name: String) -> String {
  case name {
    "" -> "Hello, stranger!"
    _ -> "Hello, " <> name <> "!"
  }
}

fn private_function(x: Int) -> String {
  case x {
    1 -> "one"
    2 -> "two"
    _ -> "other"
  }
}
"#;

    let tree = parser.parse(source_code, None).unwrap();
    let root = tree.root_node();

    println!("=== Gleam Tree-Sitter Node Types ===\n");
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
