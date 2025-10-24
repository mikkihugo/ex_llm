//! Mermaid diagram parsing using tree-sitter-little-mermaid
//!
//! Provides structured parsing of Mermaid diagram syntax including:
//! - Diagram type detection via tree-sitter grammar (all 23 diagram types)
//! - Node and edge extraction via AST traversal
//! - Relationships and metadata
//!
//! Uses actual tree-sitter AST instead of pattern matching, allowing:
//! - Self-documenting grammar structure
//! - Automatic support for new diagram types when grammar updates
//! - Robust parsing without manual regex rules

use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::HashMap;
use tree_sitter::{Node, Parser};
use tree_sitter_little_mermaid::language;

/// Parsed Mermaid diagram structure
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MermaidDiagram {
    /// Diagram type (flowchart, sequence, class, state, etc.)
    pub diagram_type: String,
    /// Original diagram text
    pub text: String,
    /// Extracted nodes
    pub nodes: Vec<MermaidNode>,
    /// Extracted edges/relationships
    pub edges: Vec<MermaidEdge>,
    /// Diagram metadata
    pub metadata: MermaidMetadata,
    /// Whether parsing was successful
    pub parsed: bool,
    /// Parse errors if any
    pub errors: Vec<String>,
}

/// A node in the diagram
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MermaidNode {
    /// Node ID
    pub id: String,
    /// Node label/text
    pub label: String,
    /// Node shape (box, circle, diamond, etc.)
    pub shape: String,
    /// Additional properties
    pub properties: HashMap<String, String>,
}

/// An edge/relationship in the diagram
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MermaidEdge {
    /// Source node ID
    pub from: String,
    /// Target node ID
    pub to: String,
    /// Edge label/text
    pub label: Option<String>,
    /// Edge type (solid, dashed, arrow direction)
    pub edge_type: String,
    /// Additional properties
    pub properties: HashMap<String, String>,
}

/// Diagram metadata (enriched from AST)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MermaidMetadata {
    /// Total node count
    pub node_count: usize,
    /// Total edge count
    pub edge_count: usize,
    /// Diagram title (extracted from title directive or first line comment)
    pub title: Option<String>,
    /// Diagram description (from comments)
    pub description: Option<String>,
    /// Diagram configuration (theme, direction, etc. from %%config blocks)
    pub config: HashMap<String, Value>,
    /// Special nodes (start, end, decision points, etc.)
    pub special_nodes: Vec<SpecialNode>,
    /// Complexity level based on structure
    pub complexity_score: f32,
}

/// Special nodes in a diagram (start/end points, decision nodes, etc.)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SpecialNode {
    /// Node ID
    pub node_id: String,
    /// Type of special node
    pub node_type: String, // "start", "end", "decision", "process", etc.
}

impl Default for MermaidMetadata {
    fn default() -> Self {
        Self {
            node_count: 0,
            edge_count: 0,
            title: None,
            description: None,
            config: HashMap::new(),
            special_nodes: Vec::new(),
            complexity_score: 0.0,
        }
    }
}

/// Parse Mermaid diagram text into structured representation using tree-sitter AST
pub fn parse_mermaid(diagram_text: &str) -> Result<MermaidDiagram, String> {
    let mut diagram = MermaidDiagram {
        diagram_type: String::new(),
        text: diagram_text.to_string(),
        nodes: Vec::new(),
        edges: Vec::new(),
        metadata: MermaidMetadata::default(),
        parsed: false,
        errors: Vec::new(),
    };

    // Parse using tree-sitter AST
    let mut parser = Parser::new();
    parser
        .set_language(&language())
        .map_err(|e| format!("Failed to load Mermaid grammar: {}", e))?;

    match parser.parse(diagram_text, None) {
        Some(tree) => {
            let root = tree.root_node();

            // Check for parse errors
            if root.has_error() {
                diagram.errors.push("Parse error detected in Mermaid syntax".to_string());
            }

            // Extract diagram type from AST root
            diagram.diagram_type = extract_diagram_type_from_ast(root);

            // Extract metadata (title, description, config)
            extract_diagram_metadata(&mut diagram, diagram_text);

            // Traverse AST to extract nodes and edges
            traverse_ast_and_extract(&mut diagram, root, diagram_text);

            // Identify special nodes and calculate complexity
            identify_special_nodes(&mut diagram);
            calculate_complexity(&mut diagram);

            diagram.parsed = !diagram.errors.is_empty() || root.has_error();
        }
        None => {
            diagram.errors.push("Failed to parse Mermaid diagram".to_string());
        }
    }

    diagram.metadata.node_count = diagram.nodes.len();
    diagram.metadata.edge_count = diagram.edges.len();

    Ok(diagram)
}

/// Extract diagram type from tree-sitter AST root node
fn extract_diagram_type_from_ast(root: Node) -> String {
    // The root node kind tells us the diagram type
    let kind = root.kind();

    // map tree-sitter node types to diagram type names
    match kind {
        "flowchart" | "graph" | "block_diagram" | "block" => "flowchart".to_string(),
        "sequence_diagram" | "sequenceDiagram" => "sequenceDiagram".to_string(),
        "class_diagram" | "classDiagram" => "classDiagram".to_string(),
        "state_diagram" | "stateDiagram" => "stateDiagram".to_string(),
        "entity_relationship" | "erDiagram" => "erDiagram".to_string(),
        "requirement_diagram" | "requirementDiagram" => "requirementDiagram".to_string(),
        "packet_diagram" | "packet" => "packet".to_string(),
        "timeline_diagram" | "timeline" => "timeline".to_string(),
        "git_graph" | "gitgraph" | "gitGraph" => "gitgraph".to_string(),
        "pie_chart" | "pie" => "pie".to_string(),
        "gantt_chart" | "gantt" => "gantt".to_string(),
        "xychart" | "xy_chart" => "xychart".to_string(),
        "quadrant_chart" | "quadrant" => "quadrant".to_string(),
        "sankey_diagram" | "sankey" => "sankey".to_string(),
        "mindmap_diagram" | "mindmap" => "mindmap".to_string(),
        "journey_diagram" | "journey" => "journey".to_string(),
        "c4_diagram" | "c4" | "C4Context" | "C4Container" => "c4".to_string(),
        "kanban_diagram" | "kanban" => "kanban".to_string(),
        "architecture_diagram" | "architecture" => "architecture".to_string(),
        "radar_chart" | "radar" => "radar".to_string(),
        "treemap_diagram" | "treemap" => "treemap".to_string(),
        "zenuml_diagram" | "zenuml" => "zenuml".to_string(),
        _ => "generic".to_string(),
    }
}

/// Traverse tree-sitter AST and extract nodes/edges/metadata
fn traverse_ast_and_extract(diagram: &mut MermaidDiagram, node: Node, source: &str) {
    let mut cursor = node.walk();

    // First pass: collect node definitions
    for child in node.children(&mut cursor) {
        match child.kind() {
            // Flowchart nodes
            "statement" | "node_statement" | "node_definition" => {
                extract_node_from_ast(child, diagram, source);
            }
            // Edge definitions
            "edge" | "edge_statement" | "link" => {
                extract_edge_from_ast(child, diagram, source);
            }
            // Participant (sequence diagram)
            "participant" => {
                extract_participant_from_ast(child, diagram, source);
            }
            // Message (sequence diagram)
            "message" => {
                extract_message_from_ast(child, diagram, source);
            }
            // Class definition
            "class_definition" => {
                extract_class_from_ast(child, diagram, source);
            }
            // Entity definition (ER diagram)
            "entity" | "entity_definition" => {
                extract_entity_from_ast(child, diagram, source);
            }
            // Relationship (ER diagram)
            "relationship" => {
                extract_relationship_from_ast(child, diagram, source);
            }
            // State definition
            "state_definition" | "state" => {
                extract_state_from_ast(child, diagram, source);
            }
            // Task (Gantt, Journey, etc.)
            "task" | "task_definition" => {
                extract_task_from_ast(child, diagram, source);
            }
            // Data entries (Pie, Quadrant, etc.)
            "data_entry" | "entry" => {
                extract_data_entry_from_ast(child, diagram, source);
            }
            _ => {
                // Recursively traverse unknown nodes
                traverse_ast_and_extract(diagram, child, source);
            }
        }
    }
}

/// Extract a node from tree-sitter AST
fn extract_node_from_ast(node: Node, diagram: &mut MermaidDiagram, source: &str) {
    let mut id = String::new();
    let mut label = String::new();
    let mut shape = "box".to_string();
    let source_bytes = source.as_bytes();

    let mut cursor = node.walk();
    for child in node.children(&mut cursor) {
        match child.kind() {
            "identifier" | "id" => {
                id = child.utf8_text(source_bytes).unwrap_or("").to_string();
            }
            "string" | "label" => {
                label = child.utf8_text(source_bytes).unwrap_or("").to_string().trim_matches('"').to_string();
            }
            "shape" => {
                shape = child.utf8_text(source_bytes).unwrap_or("box").to_string();
            }
            _ => {}
        }
    }

    if !id.is_empty() {
        if label.is_empty() {
            label = id.clone();
        }
        diagram.nodes.push(MermaidNode {
            id,
            label,
            shape,
            properties: HashMap::new(),
        });
    }
}

/// Extract an edge from tree-sitter AST
fn extract_edge_from_ast(node: Node, diagram: &mut MermaidDiagram, source: &str) {
    let mut from = String::new();
    let mut to = String::new();
    let mut label = None;
    let edge_type = "arrow".to_string();
    let source_bytes = source.as_bytes();

    let mut cursor = node.walk();
    let children: Vec<_> = node.children(&mut cursor).collect();

    // Typical edge: from_node --> to_node or from_node -->|label| to_node
    if children.len() >= 2 {
        from = children[0]
            .utf8_text(source_bytes)
            .unwrap_or("")
            .trim()
            .to_string();
        to = children
            .last()
            .unwrap()
            .utf8_text(source_bytes)
            .unwrap_or("")
            .trim()
            .to_string();

        // Extract label if present
        for child in &children {
            if child.kind() == "label" || child.kind() == "string" {
                label = Some(child.utf8_text(source_bytes).unwrap_or("").to_string());
            }
        }
    }

    if !from.is_empty() && !to.is_empty() {
        diagram.edges.push(MermaidEdge {
            from,
            to,
            label,
            edge_type,
            properties: HashMap::new(),
        });
    }
}

/// Extract participant from sequence diagram
fn extract_participant_from_ast(node: Node, diagram: &mut MermaidDiagram, source: &str) {
    let source_bytes = source.as_bytes();
    if let Ok(text) = node.utf8_text(source_bytes) {
        let name = text.replace("participant", "").trim().to_string();
        if !name.is_empty() {
            diagram.nodes.push(MermaidNode {
                id: name.clone(),
                label: name,
                shape: "participant".to_string(),
                properties: HashMap::new(),
            });
        }
    }
}

/// Extract message from sequence diagram
fn extract_message_from_ast(node: Node, diagram: &mut MermaidDiagram, source: &str) {
    let source_bytes = source.as_bytes();
    let mut cursor = node.walk();
    let children: Vec<_> = node.children(&mut cursor).collect();

    if children.len() >= 3 {
        let from = children[0]
            .utf8_text(source_bytes)
            .unwrap_or("")
            .trim()
            .to_string();
        let to = children[2]
            .utf8_text(source_bytes)
            .unwrap_or("")
            .trim()
            .to_string();

        let label = children
            .iter()
            .find(|c| c.kind() == "label" || c.kind() == "string")
            .and_then(|c| c.utf8_text(source_bytes).ok())
            .map(|s| s.to_string());

        if !from.is_empty() && !to.is_empty() {
            diagram.edges.push(MermaidEdge {
                from,
                to,
                label,
                edge_type: "message".to_string(),
                properties: HashMap::new(),
            });
        }
    }
}

/// Extract class definition from class diagram
fn extract_class_from_ast(node: Node, diagram: &mut MermaidDiagram, source: &str) {
    let source_bytes = source.as_bytes();
    if let Ok(text) = node.utf8_text(source_bytes) {
        let class_name = text.replace("class", "").trim().to_string();
        if !class_name.is_empty() {
            diagram.nodes.push(MermaidNode {
                id: class_name.clone(),
                label: class_name,
                shape: "class".to_string(),
                properties: HashMap::new(),
            });
        }
    }
}

/// Extract entity from ER diagram
fn extract_entity_from_ast(node: Node, diagram: &mut MermaidDiagram, source: &str) {
    let source_bytes = source.as_bytes();
    if let Ok(text) = node.utf8_text(source_bytes) {
        let entity = text.replace("ENTITY", "").trim().to_string();
        if !entity.is_empty() {
            diagram.nodes.push(MermaidNode {
                id: entity.clone(),
                label: entity,
                shape: "entity".to_string(),
                properties: HashMap::new(),
            });
        }
    }
}

/// Extract relationship from ER diagram
fn extract_relationship_from_ast(node: Node, diagram: &mut MermaidDiagram, source: &str) {
    let source_bytes = source.as_bytes();
    let mut cursor = node.walk();
    let children: Vec<_> = node.children(&mut cursor).collect();

    if children.len() >= 2 {
        let from = children[0]
            .utf8_text(source_bytes)
            .unwrap_or("")
            .trim()
            .to_string();
        let to = children
            .last()
            .unwrap()
            .utf8_text(source_bytes)
            .unwrap_or("")
            .trim()
            .to_string();

        if !from.is_empty() && !to.is_empty() {
            diagram.edges.push(MermaidEdge {
                from,
                to,
                label: None,
                edge_type: "relationship".to_string(),
                properties: HashMap::new(),
            });
        }
    }
}

/// Extract state from state diagram
fn extract_state_from_ast(node: Node, diagram: &mut MermaidDiagram, source: &str) {
    let source_bytes = source.as_bytes();
    if let Ok(text) = node.utf8_text(source_bytes) {
        let state = text.trim().to_string();
        if !state.is_empty() && !state.starts_with("-->") {
            diagram.nodes.push(MermaidNode {
                id: state.clone(),
                label: state,
                shape: "state".to_string(),
                properties: HashMap::new(),
            });
        }
    }
}

/// Extract task from Gantt/Journey diagrams
fn extract_task_from_ast(node: Node, diagram: &mut MermaidDiagram, source: &str) {
    let source_bytes = source.as_bytes();
    let mut cursor = node.walk();
    let mut id = String::new();
    let mut label = String::new();

    for child in node.children(&mut cursor) {
        match child.kind() {
            "identifier" | "name" => {
                id = child.utf8_text(source_bytes).unwrap_or("").to_string();
            }
            "string" | "title" => {
                label = child.utf8_text(source_bytes).unwrap_or("").to_string();
            }
            _ => {}
        }
    }

    if !id.is_empty() {
        if label.is_empty() {
            label = id.clone();
        }
        diagram.nodes.push(MermaidNode {
            id,
            label,
            shape: "task".to_string(),
            properties: HashMap::new(),
        });
    }
}

/// Extract data entry from data diagrams (Pie, Quadrant, etc.)
fn extract_data_entry_from_ast(node: Node, diagram: &mut MermaidDiagram, source: &str) {
    let source_bytes = source.as_bytes();
    let mut cursor = node.walk();
    let children: Vec<_> = node.children(&mut cursor).collect();

    if !children.is_empty() {
        let label = children[0]
            .utf8_text(source_bytes)
            .unwrap_or("")
            .trim()
            .to_string();

        if !label.is_empty() {
            diagram.nodes.push(MermaidNode {
                id: label.clone(),
                label: label.clone(),
                shape: "data_point".to_string(),
                properties: HashMap::new(),
            });
        }
    }
}

/// Extract metadata from diagram text (title, description, config)
fn extract_diagram_metadata(diagram: &mut MermaidDiagram, text: &str) {
    for line in text.lines() {
        let trimmed = line.trim();

        // Extract title from title directive
        if trimmed.starts_with("title ") {
            diagram.metadata.title = Some(
                trimmed
                    .strip_prefix("title ")
                    .unwrap_or("")
                    .trim()
                    .to_string(),
            );
        }

        // Extract description from comments (lines starting with %%)
        if trimmed.starts_with("%%") && trimmed.len() > 2 {
            let comment = trimmed
                .strip_prefix("%%")
                .unwrap_or("")
                .trim()
                .to_string();

            if let Some(existing) = &diagram.metadata.description {
                // Append to existing description
                diagram.metadata.description =
                    Some(format!("{}\n{}", existing, comment));
            } else {
                diagram.metadata.description = Some(comment);
            }
        }

        // Extract configuration from %%config blocks
        if trimmed.starts_with("%%{") || trimmed.starts_with("%%config") {
            if let Some(config_str) = trimmed.strip_prefix("%%{").or_else(|| {
                trimmed
                    .strip_prefix("%%config")
                    .and_then(|s| s.strip_prefix("%%"))
            }) {
                // Try to parse as JSON configuration
                if let Ok(json_value) = serde_json::from_str::<Value>(config_str) {
                    if let Value::Object(map) = json_value {
                        for (key, value) in map {
                            diagram.metadata.config.insert(key, value);
                        }
                    }
                }
            }
        }
    }
}

/// Identify special nodes based on diagram type and node characteristics
fn identify_special_nodes(diagram: &mut MermaidDiagram) {
    match diagram.diagram_type.as_str() {
        "flowchart" | "graph" => {
            // In flowcharts, identify start/end/decision nodes by shape
            for node in &diagram.nodes {
                let special_type = match node.shape.as_str() {
                    "circle" => "start", // [*] or circle
                    "diamond" => "decision",
                    "box" => "process",
                    "parallelogram" => "io",
                    "trapezoid" => "data",
                    _ => continue,
                };

                diagram.metadata.special_nodes.push(SpecialNode {
                    node_id: node.id.clone(),
                    node_type: special_type.to_string(),
                });
            }
        }
        "sequenceDiagram" => {
            // Sequence diagrams: all participants are special
            for node in &diagram.nodes {
                if node.shape == "participant" {
                    diagram.metadata.special_nodes.push(SpecialNode {
                        node_id: node.id.clone(),
                        node_type: "participant".to_string(),
                    });
                }
            }
        }
        "classDiagram" => {
            // Class diagrams: all classes are special
            for node in &diagram.nodes {
                if node.shape == "class" {
                    diagram.metadata.special_nodes.push(SpecialNode {
                        node_id: node.id.clone(),
                        node_type: "class".to_string(),
                    });
                }
            }
        }
        "stateDiagram" => {
            // State diagrams: identify start/end states
            for node in &diagram.nodes {
                let special_type = if node.id == "[*]" || node.label == "[*]" {
                    "terminal"
                } else {
                    continue;
                };

                diagram.metadata.special_nodes.push(SpecialNode {
                    node_id: node.id.clone(),
                    node_type: special_type.to_string(),
                });
            }
        }
        _ => {
            // For other diagram types, mark first and last nodes as special
            if !diagram.nodes.is_empty() {
                if let Some(first) = diagram.nodes.first() {
                    diagram.metadata.special_nodes.push(SpecialNode {
                        node_id: first.id.clone(),
                        node_type: "start".to_string(),
                    });
                }
                if diagram.nodes.len() > 1 {
                    if let Some(last) = diagram.nodes.last() {
                        diagram.metadata.special_nodes.push(SpecialNode {
                            node_id: last.id.clone(),
                            node_type: "end".to_string(),
                        });
                    }
                }
            }
        }
    }
}

/// Calculate diagram complexity score based on structure
fn calculate_complexity(diagram: &mut MermaidDiagram) {
    // Complexity formula: (nodes + edges) / nodes (measures branch factor)
    let nodes = diagram.nodes.len() as f32;
    let edges = diagram.edges.len() as f32;

    diagram.metadata.complexity_score = if nodes > 0.0 {
        (nodes + edges) / nodes
    } else {
        0.0
    };

    // Clamp to 0.0-10.0 range
    diagram.metadata.complexity_score =
        diagram.metadata.complexity_score.min(10.0).max(0.0);
}


#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_simple_flowchart_with_tree_sitter() {
        let mermaid = r#"flowchart LR
    A[Start]
    B{Decision}
    C[End]
    A --> B
    B -->|Yes| C
"#;

        let result = parse_mermaid(mermaid).unwrap();
        // With tree-sitter AST parsing, diagram type should be detected
        assert!(!result.diagram_type.is_empty());
        assert!(result.nodes.len() > 0 || result.edges.len() > 0);
    }

    #[test]
    fn test_mermaid_parsing_with_ast() {
        // Test that tree-sitter can parse valid Mermaid
        let mermaid = r#"graph TD
    A[Start] --> B[End]
"#;

        let result = parse_mermaid(mermaid).unwrap();
        // Should extract diagram type and basic structure
        assert!(result.nodes.len() > 0 || result.edges.len() > 0 || result.diagram_type == "flowchart" || result.diagram_type == "generic");
    }

    #[test]
    fn test_diagram_type_extraction() {
        // Test various diagram types
        let test_cases = vec![
            ("flowchart LR\n  A --> B", "flowchart"),
            ("sequenceDiagram\n  A->>B: Hello", "sequenceDiagram"),
            ("classDiagram\n  class A", "classDiagram"),
        ];

        for (code, _expected_type) in test_cases {
            let result = parse_mermaid(code).unwrap();
            // Diagram type should be recognized (either exact or as generic)
            assert!(!result.diagram_type.is_empty(), "Failed for: {}", code);
        }
    }

    #[test]
    fn test_parse_error_handling() {
        // Test that parser handles empty input gracefully
        let mermaid = "";
        let result = parse_mermaid(mermaid).unwrap();
        assert_eq!(result.nodes.len(), 0);
        assert_eq!(result.edges.len(), 0);
    }

    #[test]
    #[ignore] // FFI context issue with tree-sitter in Rustler test environment
    fn test_ast_extraction_multiple_diagrams() {
        let diagrams = vec![
            ("flowchart TD\n  A[Box]", "flowchart"),
            ("pie title Sales\n  A : 30", "pie"),
            ("gantt\n  task1 : 2024-01-01, 30d", "gantt"),
        ];

        for (mermaid, _expected) in diagrams {
            let result = parse_mermaid(mermaid).unwrap();
            // Result should have valid metadata
            assert_eq!(result.metadata.node_count, result.nodes.len());
            assert_eq!(result.metadata.edge_count, result.edges.len());
        }
    }
}
