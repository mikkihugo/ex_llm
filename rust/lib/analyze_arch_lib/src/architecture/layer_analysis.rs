//! Layer Analysis
//!
//! This module provides architectural layer analysis.

use std::collections::HashMap;

use serde::{Deserialize, Serialize};

/// Architectural layer
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ArchitecturalLayer {
  /// Layer name
  pub name: String,
  /// Layer description
  pub description: String,
  /// Layer type
  pub layer_type: LayerType,
  /// Components in this layer
  pub components: Vec<String>,
  /// Dependencies
  pub dependencies: Vec<String>,
}

/// Layer type
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum LayerType {
  /// Presentation layer
  Presentation,
  /// Business logic layer
  BusinessLogic,
  /// Data access layer
  DataAccess,
  /// Service layer
  Service,
  /// Domain layer
  Domain,
  /// Infrastructure layer
  Infrastructure,
}

/// Layer analyzer
#[derive(Debug, Clone, Default)]
pub struct LayerAnalyzer {
  /// Layers detected
  pub layers: Vec<ArchitecturalLayer>,
}

impl LayerAnalyzer {
  /// Create a new layer analyzer
  pub fn new() -> Self {
    Self::default()
  }

  /// Analyze architectural layers
  pub fn analyze_layers(&self, codebase: &str) -> Vec<ArchitecturalLayer> {
    // TODO: Implement layer analysis
    vec![]
  }

  /// Add a layer
  pub fn add_layer(&mut self, layer: ArchitecturalLayer) {
    self.layers.push(layer);
  }

  /// Get all layers
  pub fn get_layers(&self) -> &Vec<ArchitecturalLayer> {
    &self.layers
  }

  /// Get layers grouped by type
  pub fn get_layers_by_type(&self) -> HashMap<LayerType, Vec<&ArchitecturalLayer>> {
    let mut grouped = HashMap::new();
    for layer in &self.layers {
      grouped.entry(layer.layer_type.clone()).or_insert_with(Vec::new).push(layer);
    }
    grouped
  }
}
