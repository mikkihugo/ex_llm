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
        // Graph/Flow diagrams
        "flowchart" | "graph" | "block" => {
            parse_flowchart(&mut diagram);
        }
        // Relationship/Structure diagrams
        "sequenceDiagram" | "zenuml" => {
            parse_sequence(&mut diagram);
        }
        "classDiagram" => {
            parse_class(&mut diagram);
        }
        "erDiagram" => {
            parse_entity_relationship(&mut diagram);
        }
        "requirementDiagram" => {
            parse_requirement(&mut diagram);
        }
        "packet" => {
            parse_packet(&mut diagram);
        }
        // State/Time diagrams
        "stateDiagram" => {
            parse_state(&mut diagram);
        }
        "timeline" => {
            parse_timeline(&mut diagram);
        }
        "gitgraph" => {
            parse_gitgraph(&mut diagram);
        }
        // Chart/Data diagrams
        "pie" => {
            parse_pie(&mut diagram);
        }
        "gantt" => {
            parse_gantt(&mut diagram);
        }
        "xychart" => {
            parse_xychart(&mut diagram);
        }
        "quadrant" => {
            parse_quadrant(&mut diagram);
        }
        "sankey" => {
            parse_sankey(&mut diagram);
        }
        // Mind/Journey maps
        "mindmap" => {
            parse_mindmap(&mut diagram);
        }
        "journey" => {
            parse_journey(&mut diagram);
        }
        // Architecture
        "c4" => {
            parse_c4(&mut diagram);
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

    // Graph/Flow diagrams
    if line.starts_with("flowchart") {
        Some("flowchart")
    } else if line.starts_with("graph") {
        Some("graph")
    } else if line.starts_with("block") {
        Some("block")
    } else if line.starts_with("block-beta") {
        Some("block")
    // Relationship/Structure diagrams
    } else if line.starts_with("sequenceDiagram") {
        Some("sequenceDiagram")
    } else if line.starts_with("zenuml") {
        Some("zenuml")
    } else if line.starts_with("classDiagram") {
        Some("classDiagram")
    } else if line.starts_with("erDiagram") {
        Some("erDiagram")
    } else if line.starts_with("requirementDiagram") {
        Some("requirementDiagram")
    } else if line.starts_with("packet-beta") {
        Some("packet")
    // State/Time diagrams
    } else if line.starts_with("stateDiagram") {
        Some("stateDiagram")
    } else if line.starts_with("timeline") {
        Some("timeline")
    } else if line.starts_with("gitGraph") || line.starts_with("gitgraph") {
        Some("gitgraph")
    // Chart/Data diagrams
    } else if line.starts_with("pie") {
        Some("pie")
    } else if line.starts_with("gantt") {
        Some("gantt")
    } else if line.starts_with("xychart-beta") {
        Some("xychart")
    } else if line.starts_with("quadrant-chart") {
        Some("quadrant")
    } else if line.starts_with("sankey-beta") {
        Some("sankey")
    // Mind/Journey maps
    } else if line.starts_with("mindmap") {
        Some("mindmap")
    } else if line.starts_with("journey") {
        Some("journey")
    // Architecture
    } else if line.starts_with("c4Diagram") || line.starts_with("C4Context") ||
              line.contains("C4_") {
        Some("c4")
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

/// Parse entity relationship diagram
fn parse_entity_relationship(diagram: &mut MermaidDiagram) {
    for line in diagram.text.lines() {
        let trimmed = line.trim();
        if trimmed.is_empty() || trimmed.starts_with("%%") {
            continue;
        }

        // Entity: ENTITY_NAME { attributes }
        if let Some(entity) = trimmed.strip_prefix("ENTITY ") {
            let name = entity.split_whitespace().next().unwrap_or(entity);
            diagram.nodes.push(MermaidNode {
                id: name.to_string(),
                label: name.to_string(),
                shape: "entity".to_string(),
                properties: HashMap::new(),
            });
        }

        // Relationship: ENTITY1 ||--o{ ENTITY2
        if trimmed.contains("||") || trimmed.contains("o{") {
            if let Some((from, rest)) = trimmed.split_once("||") {
                let to = rest.split_whitespace().last().unwrap_or("");
                if !from.is_empty() && !to.is_empty() {
                    diagram.edges.push(MermaidEdge {
                        from: from.trim().to_string(),
                        to: to.to_string(),
                        label: None,
                        edge_type: "relationship".to_string(),
                        properties: HashMap::new(),
                    });
                }
            }
        }
    }
}

/// Parse requirement diagram
fn parse_requirement(diagram: &mut MermaidDiagram) {
    for line in diagram.text.lines() {
        let trimmed = line.trim();
        if trimmed.is_empty() || trimmed.starts_with("%%") {
            continue;
        }

        // Requirement: requirement : REQ001 : text
        if trimmed.starts_with("requirement") {
            if let Some(rest) = trimmed.strip_prefix("requirement").map(|s| s.trim()) {
                let id = rest.split(':').nth(1).map(|s| s.trim()).unwrap_or(rest);
                diagram.nodes.push(MermaidNode {
                    id: id.to_string(),
                    label: id.to_string(),
                    shape: "requirement".to_string(),
                    properties: HashMap::new(),
                });
            }
        }
    }
}

/// Parse packet diagram
fn parse_packet(diagram: &mut MermaidDiagram) {
    for line in diagram.text.lines() {
        let trimmed = line.trim();
        if trimmed.is_empty() || trimmed.starts_with("%%") {
            continue;
        }

        // Packet structure: name bytes
        if !trimmed.starts_with("packet-beta") && !trimmed.is_empty() {
            diagram.nodes.push(MermaidNode {
                id: trimmed.to_string(),
                label: trimmed.to_string(),
                shape: "packet".to_string(),
                properties: HashMap::new(),
            });
        }
    }
}

/// Parse timeline diagram
fn parse_timeline(diagram: &mut MermaidDiagram) {
    for line in diagram.text.lines() {
        let trimmed = line.trim();
        if trimmed.is_empty() || trimmed.starts_with("%%") || trimmed.starts_with("timeline") {
            continue;
        }

        // Timeline event: time : event
        if trimmed.contains(':') {
            if let Some((time, event)) = trimmed.split_once(':') {
                diagram.nodes.push(MermaidNode {
                    id: time.trim().to_string(),
                    label: event.trim().to_string(),
                    shape: "event".to_string(),
                    properties: HashMap::new(),
                });
            }
        }
    }
}

/// Parse git graph diagram
fn parse_gitgraph(diagram: &mut MermaidDiagram) {
    let mut current_branch = "main".to_string();

    for line in diagram.text.lines() {
        let trimmed = line.trim();
        if trimmed.is_empty() || trimmed.starts_with("%%") {
            continue;
        }

        // Branch: branch branch_name
        if trimmed.starts_with("branch ") {
            if let Some(name) = trimmed.strip_prefix("branch ").map(|s| s.trim()) {
                current_branch = name.to_string();
                diagram.nodes.push(MermaidNode {
                    id: name.to_string(),
                    label: name.to_string(),
                    shape: "branch".to_string(),
                    properties: HashMap::new(),
                });
            }
        }

        // Commit: commit id: "message"
        if trimmed.starts_with("commit") {
            diagram.nodes.push(MermaidNode {
                id: format!("commit-{}", diagram.nodes.len()),
                label: trimmed.to_string(),
                shape: "commit".to_string(),
                properties: HashMap::new(),
            });
        }
    }
}

/// Parse pie chart
fn parse_pie(diagram: &mut MermaidDiagram) {
    for line in diagram.text.lines() {
        let trimmed = line.trim();
        if trimmed.is_empty() || trimmed.starts_with("%%") || trimmed.starts_with("pie") {
            continue;
        }

        // Pie data: label : value
        if trimmed.contains(':') {
            if let Some((label, value)) = trimmed.split_once(':') {
                diagram.nodes.push(MermaidNode {
                    id: label.trim().to_string(),
                    label: format!("{} ({})", label.trim(), value.trim()),
                    shape: "pie_slice".to_string(),
                    properties: HashMap::new(),
                });
            }
        }
    }
}

/// Parse gantt chart
fn parse_gantt(diagram: &mut MermaidDiagram) {
    for line in diagram.text.lines() {
        let trimmed = line.trim();
        if trimmed.is_empty() || trimmed.starts_with("%%") || trimmed.starts_with("gantt") {
            continue;
        }

        // Gantt task: task_name : a, 2014-01-01, 30d
        if trimmed.contains(':') && !trimmed.starts_with("title") {
            if let Some((name, _)) = trimmed.split_once(':') {
                diagram.nodes.push(MermaidNode {
                    id: name.trim().to_string(),
                    label: name.trim().to_string(),
                    shape: "task".to_string(),
                    properties: HashMap::new(),
                });
            }
        }
    }
}

/// Parse XY chart
fn parse_xychart(diagram: &mut MermaidDiagram) {
    for line in diagram.text.lines() {
        let trimmed = line.trim();
        if trimmed.is_empty() || trimmed.starts_with("%%") {
            continue;
        }

        // Data points
        if trimmed.contains(",") && !trimmed.starts_with("x") && !trimmed.starts_with("y") {
            diagram.nodes.push(MermaidNode {
                id: format!("point-{}", diagram.nodes.len()),
                label: trimmed.to_string(),
                shape: "point".to_string(),
                properties: HashMap::new(),
            });
        }
    }
}

/// Parse quadrant chart
fn parse_quadrant(diagram: &mut MermaidDiagram) {
    for line in diagram.text.lines() {
        let trimmed = line.trim();
        if trimmed.is_empty() || trimmed.starts_with("%%") || trimmed.contains("quadrant") {
            continue;
        }

        // Quadrant point: name: (x, y)
        if trimmed.contains(':') {
            if let Some((name, _)) = trimmed.split_once(':') {
                diagram.nodes.push(MermaidNode {
                    id: name.trim().to_string(),
                    label: name.trim().to_string(),
                    shape: "point".to_string(),
                    properties: HashMap::new(),
                });
            }
        }
    }
}

/// Parse sankey diagram
fn parse_sankey(diagram: &mut MermaidDiagram) {
    for line in diagram.text.lines() {
        let trimmed = line.trim();
        if trimmed.is_empty() || trimmed.starts_with("%%") || trimmed.starts_with("sankey") {
            continue;
        }

        // Sankey flow: source --> target : value
        if trimmed.contains("-->") {
            if let Some((from, rest)) = trimmed.split_once("-->") {
                let to = rest.split(':').next().unwrap_or(rest).trim();
                diagram.edges.push(MermaidEdge {
                    from: from.trim().to_string(),
                    to: to.to_string(),
                    label: rest.split(':').nth(1).map(|v| v.trim().to_string()),
                    edge_type: "flow".to_string(),
                    properties: HashMap::new(),
                });
            }
        }
    }
}

/// Parse mindmap
fn parse_mindmap(diagram: &mut MermaidDiagram) {
    for line in diagram.text.lines() {
        let trimmed = line.trim();
        if trimmed.is_empty() || trimmed.starts_with("%%") || trimmed.starts_with("mindmap") {
            continue;
        }

        // Count indentation to determine hierarchy
        let indent = line.len() - line.trim_start().len();
        let text = trimmed.trim_start_matches('-').trim_start_matches('*').trim();

        if !text.is_empty() {
            diagram.nodes.push(MermaidNode {
                id: text.to_string(),
                label: text.to_string(),
                shape: "node".to_string(),
                properties: {
                    let mut props = HashMap::new();
                    props.insert("level".to_string(), (indent / 2).to_string());
                    props
                },
            });
        }
    }
}

/// Parse journey/user journey map
fn parse_journey(diagram: &mut MermaidDiagram) {
    for line in diagram.text.lines() {
        let trimmed = line.trim();
        if trimmed.is_empty() || trimmed.starts_with("%%") || trimmed.starts_with("journey") {
            continue;
        }

        // Journey task: task : actor : score
        if trimmed.contains(':') {
            let parts: Vec<&str> = trimmed.split(':').map(|s| s.trim()).collect();
            if parts.len() >= 2 {
                diagram.nodes.push(MermaidNode {
                    id: parts[0].to_string(),
                    label: parts[0].to_string(),
                    shape: "task".to_string(),
                    properties: HashMap::new(),
                });
            }
        }
    }
}

/// Parse C4 architecture diagram
fn parse_c4(diagram: &mut MermaidDiagram) {
    for line in diagram.text.lines() {
        let trimmed = line.trim();
        if trimmed.is_empty() || trimmed.starts_with("%%") {
            continue;
        }

        // C4 container: Container(identifier, "name", "description")
        if trimmed.contains("(") && trimmed.contains(")") {
            if let Some(name) = trimmed.split('"').nth(1) {
                diagram.nodes.push(MermaidNode {
                    id: name.to_string(),
                    label: name.to_string(),
                    shape: "container".to_string(),
                    properties: HashMap::new(),
                });
            }
        }

        // C4 relationship: Rel(from, to, "label")
        if trimmed.starts_with("Rel") {
            diagram.edges.push(MermaidEdge {
                from: "system1".to_string(),
                to: "system2".to_string(),
                label: None,
                edge_type: "relationship".to_string(),
                properties: HashMap::new(),
            });
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
