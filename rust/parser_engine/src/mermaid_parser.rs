//! Mermaid diagram parsing using tree-sitter-little-mermaid
//!
//! Provides structured parsing of Mermaid diagram syntax including:
//! - Diagram type detection (flowchart, sequence, class, state, etc.)
//! - Node and edge extraction
//! - Relationships and metadata

use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::HashMap;

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

/// Diagram metadata
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MermaidMetadata {
    /// Total node count
    pub node_count: usize,
    /// Total edge count
    pub edge_count: usize,
    /// Diagram configuration
    pub config: HashMap<String, Value>,
}

impl Default for MermaidMetadata {
    fn default() -> Self {
        Self {
            node_count: 0,
            edge_count: 0,
            config: HashMap::new(),
        }
    }
}

/// Parse Mermaid diagram text into structured representation
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

    // Extract diagram type from first line
    let first_line = diagram_text
        .lines()
        .find(|line| !line.trim().is_empty() && !line.trim().starts_with("%%"))
        .unwrap_or("");

    if let Some(diagram_type) = extract_diagram_type(first_line) {
        diagram.diagram_type = diagram_type.to_string();
    }

    // Parse based on diagram type
    match diagram.diagram_type.as_str() {
        "flowchart" | "graph" => {
            parse_flowchart(&mut diagram);
        }
        "sequenceDiagram" => {
            parse_sequence(&mut diagram);
        }
        "classDiagram" => {
            parse_class(&mut diagram);
        }
        "stateDiagram" => {
            parse_state(&mut diagram);
        }
        _ => {
            // Generic diagram parsing
            parse_generic(&mut diagram);
        }
    }

    diagram.metadata.node_count = diagram.nodes.len();
    diagram.metadata.edge_count = diagram.edges.len();
    diagram.parsed = diagram.errors.is_empty();

    Ok(diagram)
}

/// Extract diagram type from diagram definition
fn extract_diagram_type(first_line: &str) -> Option<&str> {
    let line = first_line.trim();

    if line.starts_with("flowchart") {
        Some("flowchart")
    } else if line.starts_with("graph") {
        Some("graph")
    } else if line.starts_with("sequenceDiagram") {
        Some("sequenceDiagram")
    } else if line.starts_with("classDiagram") {
        Some("classDiagram")
    } else if line.starts_with("stateDiagram") {
        Some("stateDiagram")
    } else if line.starts_with("pie") {
        Some("pie")
    } else if line.starts_with("gantt") {
        Some("gantt")
    } else {
        None
    }
}

/// Parse flowchart/graph diagram
fn parse_flowchart(diagram: &mut MermaidDiagram) {
    for line in diagram.text.lines() {
        let trimmed = line.trim();

        // Skip comments and empty lines
        if trimmed.is_empty() || trimmed.starts_with("%%") || trimmed.starts_with("--") {
            continue;
        }

        // Node definitions: ID[Label] or ID{Label} or ID((Label)) etc.
        if let Some(node) = parse_node_definition(trimmed) {
            diagram.nodes.push(node);
            continue;
        }

        // Edge definitions: A --> B or A -->|label| B
        if let Some(edge) = parse_edge_definition(trimmed) {
            diagram.edges.push(edge);
        }
    }
}

/// Parse sequence diagram
fn parse_sequence(diagram: &mut MermaidDiagram) {
    let mut participants = Vec::new();

    for line in diagram.text.lines() {
        let trimmed = line.trim();

        if trimmed.is_empty() || trimmed.starts_with("%%") {
            continue;
        }

        // Participant declaration
        if trimmed.starts_with("participant") {
            if let Some(name) = trimmed.strip_prefix("participant").map(|s| s.trim()) {
                if !participants.contains(&name.to_string()) {
                    participants.push(name.to_string());
                    diagram.nodes.push(MermaidNode {
                        id: name.to_string(),
                        label: name.to_string(),
                        shape: "participant".to_string(),
                        properties: HashMap::new(),
                    });
                }
            }
        }

        // Message/interaction: A->>B: message
        if let Some((from, rest)) = trimmed.split_once("->>") {
            let from = from.trim().to_string();
            if let Some((to, _msg)) = rest.split_once(':') {
                let to = to.trim().to_string();
                diagram.edges.push(MermaidEdge {
                    from,
                    to,
                    label: Some(rest.split_once(':').map(|(_, m)| m.trim()).unwrap_or("").to_string()),
                    edge_type: "sync".to_string(),
                    properties: HashMap::new(),
                });
            }
        }
    }
}

/// Parse class diagram
fn parse_class(diagram: &mut MermaidDiagram) {
    for line in diagram.text.lines() {
        let trimmed = line.trim();

        if trimmed.is_empty() || trimmed.starts_with("%%") {
            continue;
        }

        // Class definition: class ClassName
        if trimmed.starts_with("class ") {
            if let Some(class_name) = trimmed.strip_prefix("class ").map(|s| s.trim().to_string()) {
                diagram.nodes.push(MermaidNode {
                    id: class_name.clone(),
                    label: class_name.clone(),
                    shape: "class".to_string(),
                    properties: HashMap::new(),
                });
            }
        }

        // Relationship: ClassA --|> ClassB
        if let Some((from, rest)) = trimmed.split_once("--|>") {
            let from = from.trim().to_string();
            let to = rest.trim().to_string();
            diagram.edges.push(MermaidEdge {
                from,
                to,
                label: None,
                edge_type: "inheritance".to_string(),
                properties: HashMap::new(),
            });
        }
    }
}

/// Parse state diagram
fn parse_state(diagram: &mut MermaidDiagram) {
    for line in diagram.text.lines() {
        let trimmed = line.trim();

        if trimmed.is_empty() || trimmed.starts_with("%%") {
            continue;
        }

        // State definition: [*] or state_name
        if trimmed.contains("[*]") {
            diagram.nodes.push(MermaidNode {
                id: "[*]".to_string(),
                label: trimmed.to_string(),
                shape: "state".to_string(),
                properties: HashMap::new(),
            });
        }

        // Transition: StateA --> StateB
        if let Some((from, to)) = trimmed.split_once("-->") {
            let from = from.trim().to_string();
            let to = to.trim().split_whitespace().next().unwrap_or("").to_string();
            if !from.is_empty() && !to.is_empty() {
                diagram.edges.push(MermaidEdge {
                    from,
                    to,
                    label: trimmed.split_once(':').map(|(_, l)| l.trim().to_string()),
                    edge_type: "transition".to_string(),
                    properties: HashMap::new(),
                });
            }
        }
    }
}

/// Generic diagram parsing (fallback)
fn parse_generic(diagram: &mut MermaidDiagram) {
    // Try to extract basic nodes and edges from generic syntax
    for line in diagram.text.lines() {
        let trimmed = line.trim();

        if trimmed.is_empty() || trimmed.starts_with("%%") {
            continue;
        }

        // Try flowchart node pattern first
        if let Some(node) = parse_node_definition(trimmed) {
            diagram.nodes.push(node);
        } else if let Some(edge) = parse_edge_definition(trimmed) {
            diagram.edges.push(edge);
        }
    }
}

/// Parse node definition: ID[Label] ID{Label} ID((Label)) etc.
fn parse_node_definition(line: &str) -> Option<MermaidNode> {
    let line = line.trim();

    // Match patterns like: id[label], id{label}, id((label)), id([label]), id([/label/])
    if let Some(idx) = line.find(|c| c == '[' || c == '{' || c == '(') {
        let id = line[..idx].trim();
        let close_char = match line.chars().nth(idx) {
            Some('[') => ']',
            Some('{') => '}',
            Some('(') => ')',
            _ => return None,
        };

        if let Some(close_idx) = line[idx..].find(close_char) {
            let label = line[idx + 1..idx + close_idx].to_string();
            let shape = match line.chars().nth(idx) {
                Some('[') => {
                    if line[idx..idx + 2] == *"[/" {
                        "parallelogram"
                    } else if line[idx..idx + 2] == *"[(" {
                        "trapezoid"
                    } else {
                        "box"
                    }
                }
                Some('{') => "diamond",
                Some('(') => "circle",
                _ => "unknown",
            };

            return Some(MermaidNode {
                id: id.to_string(),
                label,
                shape: shape.to_string(),
                properties: HashMap::new(),
            });
        }
    }

    None
}

/// Parse edge definition: A --> B, A -->|label| B, A -.-> B, etc.
fn parse_edge_definition(line: &str) -> Option<MermaidEdge> {
    let line = line.trim();

    // Common edge patterns
    let patterns = vec![
        ("-->", "arrow"),
        ("-.->", "dashed"),
        ("==", "thick"),
        ("-->|", "arrow_label"),
        ("-.", "dotted"),
        ("-.->", "dashed"),
    ];

    for (pattern, edge_type) in patterns {
        if line.contains(pattern) {
            if let Some(idx) = line.find(pattern) {
                let from = line[..idx].trim().to_string();
                let rest = &line[idx + pattern.len()..];

                // Extract label if present (e.g., "label| to_node")
                let (label, to) = if pattern.ends_with('|') {
                    let after_pipe = &rest[1..];
                    if let Some(close_idx) = after_pipe.find('|') {
                        let lbl = &after_pipe[..close_idx].trim();
                        let to = after_pipe[close_idx + 1..].trim();
                        (Some(lbl.to_string()), to.to_string())
                    } else {
                        (None, rest.trim().to_string())
                    }
                } else {
                    (None, rest.trim().to_string())
                };

                if !from.is_empty() && !to.is_empty() {
                    return Some(MermaidEdge {
                        from,
                        to,
                        label,
                        edge_type: edge_type.to_string(),
                        properties: HashMap::new(),
                    });
                }
            }
        }
    }

    None
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_simple_flowchart() {
        let mermaid = r#"
flowchart LR
    A[Start]
    B{Decision}
    C[End]
    A --> B
    B -->|Yes| C
    B -->|No| A
        "#;

        let result = parse_mermaid(mermaid).unwrap();
        assert_eq!(result.diagram_type, "flowchart");
        assert_eq!(result.nodes.len(), 3);
        assert_eq!(result.edges.len(), 3);
        assert!(result.parsed);
    }

    #[test]
    fn test_extract_diagram_type() {
        assert_eq!(extract_diagram_type("flowchart LR"), Some("flowchart"));
        assert_eq!(extract_diagram_type("sequenceDiagram"), Some("sequenceDiagram"));
        assert_eq!(extract_diagram_type("classDiagram"), Some("classDiagram"));
    }

    #[test]
    fn test_parse_node_definition() {
        let node = parse_node_definition("A[Hello World]").unwrap();
        assert_eq!(node.id, "A");
        assert_eq!(node.label, "Hello World");
        assert_eq!(node.shape, "box");

        let node = parse_node_definition("B{Decision}").unwrap();
        assert_eq!(node.shape, "diamond");

        let node = parse_node_definition("C((Center))").unwrap();
        assert_eq!(node.shape, "circle");
    }

    #[test]
    fn test_parse_edge_definition() {
        let edge = parse_edge_definition("A --> B").unwrap();
        assert_eq!(edge.from, "A");
        assert_eq!(edge.to, "B");
        assert_eq!(edge.edge_type, "arrow");

        let edge = parse_edge_definition("A -->|label| B").unwrap();
        assert!(edge.label.is_some());
    }
}
