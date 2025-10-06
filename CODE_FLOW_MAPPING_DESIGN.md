# Code Flow Mapping & Process Completeness System

## Problem: How do you know if a feature is "complete"?

**Current State**: You have code scattered across files, but can't easily answer:
- ✅ Is the full signup flow implemented?
- ✅ Does payment processing have all error handling?
- ✅ Are all CRUD operations present for this entity?
- ✅ Is the end-to-end flow complete from HTTP request → DB → response?

## Solution: Code Flow Graphs + Process Completeness Detection

### What You Need:

1. **Map actual code flows** (what exists in codebase)
2. **Define expected process patterns** (what SHOULD exist)
3. **Compare** to find gaps
4. **Visualize** completeness

---

## Architecture

### Tables Needed

Following your naming conventions (`<What><How>`):

```elixir
# 1. Code execution flows discovered from your codebase
code_execution_flow_nodes
code_execution_flow_edges
code_execution_flow_metadata

# 2. Expected process patterns (templates)
expected_process_pattern_definitions
expected_process_pattern_steps
expected_process_pattern_transitions

# 3. Completeness analysis
process_completeness_analysis
process_gap_detection_results
process_coverage_metrics
```

---

## Database Schema

### 1. Code Execution Flow Tracking

**What**: Actual control flow paths discovered by analyzing YOUR code

```sql
-- Nodes = functions, API endpoints, database operations, etc.
CREATE TABLE code_execution_flow_nodes (
  id UUID PRIMARY KEY,
  codebase_name TEXT NOT NULL,

  -- What type of node?
  node_type TEXT NOT NULL, -- 'http_endpoint', 'function', 'db_query', 'external_api_call'

  -- Where is it?
  file_path TEXT NOT NULL,
  line_start INTEGER NOT NULL,
  line_end INTEGER NOT NULL,

  -- What is it?
  symbol_name TEXT NOT NULL, -- "create_user", "POST /api/users", "INSERT INTO users"
  module_name TEXT, -- "UserController", "UserService"

  -- Metadata
  language TEXT NOT NULL,
  signature TEXT, -- Full function signature
  source_code TEXT, -- Actual code

  -- Flow analysis
  is_entry_point BOOLEAN DEFAULT false, -- HTTP endpoint, scheduled job, etc.
  is_terminal_point BOOLEAN DEFAULT false, -- Return response, throw error, etc.

  -- Semantic search
  embedding vector(768),

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX ON code_execution_flow_nodes (codebase_name, node_type);
CREATE INDEX ON code_execution_flow_nodes (file_path);
CREATE INDEX ON code_execution_flow_nodes USING ivfflat (embedding vector_cosine_ops);

-- Edges = control flow (who calls who)
CREATE TABLE code_execution_flow_edges (
  id UUID PRIMARY KEY,
  codebase_name TEXT NOT NULL,

  -- Flow
  from_node_id UUID REFERENCES code_execution_flow_nodes(id) ON DELETE CASCADE,
  to_node_id UUID REFERENCES code_execution_flow_nodes(id) ON DELETE CASCADE,

  -- What kind of flow?
  edge_type TEXT NOT NULL, -- 'function_call', 'http_request', 'db_query', 'async_message', 'exception_throw'

  -- Conditions (if any)
  condition_code TEXT, -- "if user.admin?", "when :ok", "rescue SomeError"
  is_conditional BOOLEAN DEFAULT false,
  is_error_path BOOLEAN DEFAULT false,

  -- Data flow
  parameters_passed JSONB, -- What data flows through this edge

  -- Frequency (if you have runtime tracing)
  execution_count INTEGER DEFAULT 0,
  avg_execution_time_ms FLOAT,

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX ON code_execution_flow_edges (from_node_id);
CREATE INDEX ON code_execution_flow_edges (to_node_id);
CREATE INDEX ON code_execution_flow_edges (edge_type);

-- Flow metadata (properties of entire flows)
CREATE TABLE code_execution_flow_metadata (
  id UUID PRIMARY KEY,
  codebase_name TEXT NOT NULL,

  -- What flow?
  flow_name TEXT NOT NULL, -- "User Signup", "Payment Processing", "File Upload"
  flow_category TEXT, -- "CRUD", "Authentication", "Integration"

  -- Entry points
  entry_node_ids UUID[] NOT NULL,

  -- All nodes in this flow
  node_ids UUID[] NOT NULL,

  -- Completeness
  total_nodes INTEGER NOT NULL,
  total_edges INTEGER NOT NULL,

  -- Analysis
  has_error_handling BOOLEAN DEFAULT false,
  has_logging BOOLEAN DEFAULT false,
  has_validation BOOLEAN DEFAULT false,
  has_tests BOOLEAN DEFAULT false,

  -- Metrics
  cyclomatic_complexity INTEGER,
  max_depth INTEGER, -- Deepest call chain

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX ON code_execution_flow_metadata (codebase_name);
CREATE INDEX ON code_execution_flow_metadata (flow_name);
```

### 2. Expected Process Patterns

**What**: Templates for "complete" processes (like CRUD, auth flows, etc.)

```sql
-- Pattern definitions
CREATE TABLE expected_process_pattern_definitions (
  id UUID PRIMARY KEY,

  -- What pattern?
  pattern_name TEXT NOT NULL UNIQUE, -- "REST CRUD", "OAuth2 Flow", "Event-Sourced Aggregate"
  pattern_category TEXT NOT NULL, -- "Data Access", "Authentication", "Integration"

  -- Description
  description TEXT NOT NULL,

  -- Which frameworks/technologies?
  applicable_languages TEXT[], -- ["elixir", "rust"]
  applicable_frameworks TEXT[], -- ["phoenix", "axum"]

  -- Expected completeness
  required_steps JSONB NOT NULL, -- List of required steps
  optional_steps JSONB, -- Nice-to-have steps

  -- Validation rules
  must_have_error_handling BOOLEAN DEFAULT true,
  must_have_tests BOOLEAN DEFAULT true,
  must_have_logging BOOLEAN DEFAULT false,

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Steps within a pattern
CREATE TABLE expected_process_pattern_steps (
  id UUID PRIMARY KEY,
  pattern_id UUID REFERENCES expected_process_pattern_definitions(id) ON DELETE CASCADE,

  -- Step details
  step_name TEXT NOT NULL, -- "Validate Input", "Check Authorization", "Save to DB"
  step_order INTEGER NOT NULL,
  is_required BOOLEAN DEFAULT true,

  -- What to look for in code
  detection_patterns JSONB NOT NULL, -- Regex, AST patterns, function names

  -- Example implementations
  example_code TEXT,

  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Transitions between steps
CREATE TABLE expected_process_pattern_transitions (
  id UUID PRIMARY KEY,
  pattern_id UUID REFERENCES expected_process_pattern_definitions(id) ON DELETE CASCADE,

  from_step_id UUID REFERENCES expected_process_pattern_steps(id),
  to_step_id UUID REFERENCES expected_process_pattern_steps(id),

  -- Transition type
  transition_type TEXT NOT NULL, -- 'success', 'error', 'conditional'
  is_required BOOLEAN DEFAULT true,

  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### 3. Completeness Analysis

**What**: Compare actual flows to expected patterns

```sql
-- Analysis results
CREATE TABLE process_completeness_analysis (
  id UUID PRIMARY KEY,

  -- What are we analyzing?
  codebase_name TEXT NOT NULL,
  flow_metadata_id UUID REFERENCES code_execution_flow_metadata(id),
  pattern_id UUID REFERENCES expected_process_pattern_definitions(id),

  -- Overall completeness
  completeness_score FLOAT NOT NULL, -- 0.0 to 1.0
  is_complete BOOLEAN DEFAULT false,

  -- Breakdown
  required_steps_found INTEGER NOT NULL,
  required_steps_total INTEGER NOT NULL,
  optional_steps_found INTEGER NOT NULL,
  optional_steps_total INTEGER NOT NULL,

  -- Quality checks
  has_required_error_handling BOOLEAN,
  has_required_tests BOOLEAN,
  has_required_logging BOOLEAN,

  -- Results
  analysis_result JSONB NOT NULL, -- Detailed breakdown

  analyzed_at TIMESTAMPTZ DEFAULT NOW()
);

-- Gap detection
CREATE TABLE process_gap_detection_results (
  id UUID PRIMARY KEY,
  analysis_id UUID REFERENCES process_completeness_analysis(id) ON DELETE CASCADE,

  -- What's missing?
  gap_type TEXT NOT NULL, -- 'missing_step', 'missing_transition', 'missing_error_handling', 'missing_test'
  severity TEXT NOT NULL, -- 'critical', 'high', 'medium', 'low'

  -- Details
  missing_step_name TEXT,
  description TEXT NOT NULL,
  recommendation TEXT NOT NULL, -- What to do to fix it

  -- Where to add it?
  suggested_file_path TEXT,
  suggested_location TEXT,
  example_code TEXT,

  -- Status
  is_acknowledged BOOLEAN DEFAULT false,
  is_fixed BOOLEAN DEFAULT false,
  fixed_at TIMESTAMPTZ,

  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX ON process_gap_detection_results (analysis_id);
CREATE INDEX ON process_gap_detection_results (gap_type);
CREATE INDEX ON process_gap_detection_results (severity);
CREATE INDEX ON process_gap_detection_results (is_fixed);

-- Coverage metrics (aggregate view)
CREATE TABLE process_coverage_metrics (
  id UUID PRIMARY KEY,
  codebase_name TEXT NOT NULL,

  -- When?
  measured_at TIMESTAMPTZ DEFAULT NOW(),

  -- Overall metrics
  total_flows_detected INTEGER NOT NULL,
  total_flows_analyzed INTEGER NOT NULL,

  -- Completeness
  complete_flows INTEGER NOT NULL,
  incomplete_flows INTEGER NOT NULL,
  avg_completeness_score FLOAT NOT NULL,

  -- By category
  completeness_by_category JSONB NOT NULL, -- {"CRUD": 0.95, "Auth": 0.80, ...}

  -- Gap summary
  critical_gaps INTEGER NOT NULL,
  high_priority_gaps INTEGER NOT NULL,
  medium_priority_gaps INTEGER NOT NULL,
  low_priority_gaps INTEGER NOT NULL,

  -- Trends (if comparing over time)
  previous_measurement_id UUID REFERENCES process_coverage_metrics(id),
  trend TEXT, -- 'improving', 'declining', 'stable'

  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX ON process_coverage_metrics (codebase_name);
CREATE INDEX ON process_coverage_metrics (measured_at DESC);
```

---

## How It Works

### Phase 1: Discover Flows (Automated)

Use existing Rust parsers + new flow analysis:

```rust
// rust/code_flow_analyzer/src/flow_extractor.rs

pub struct FlowExtractor {
    // Uses tree-sitter AST
    parser: LanguageParser,
    // Tracks call graph
    call_graph: CallGraph,
}

impl FlowExtractor {
    pub fn extract_flows(&self, codebase: &Codebase) -> Vec<CodeFlow> {
        // 1. Find entry points (HTTP routes, scheduled jobs, etc.)
        let entry_points = self.find_entry_points(codebase);

        // 2. For each entry point, trace execution
        entry_points.into_iter().map(|entry| {
            self.trace_execution_flow(entry)
        }).collect()
    }

    fn trace_execution_flow(&self, entry: Node) -> CodeFlow {
        // DFS/BFS through function calls
        // Build graph of: entry → function → db → response
    }

    fn find_entry_points(&self, codebase: &Codebase) -> Vec<Node> {
        // Phoenix: routes.ex, controllers
        // Axum: route definitions
        // Scheduled: cron, Oban jobs
    }
}
```

### Phase 2: Define Expected Patterns

Seed database with common patterns:

```elixir
# lib/singularity/process_patterns/seed_patterns.ex

defmodule Singularity.ProcessPatterns.SeedPatterns do
  @moduledoc """
  Seed expected process patterns for completeness checking
  """

  def seed_rest_crud_pattern do
    pattern = %{
      pattern_name: "REST CRUD (Phoenix)",
      pattern_category: "Data Access",
      description: "Complete CRUD operations for a REST API resource",
      applicable_languages: ["elixir"],
      applicable_frameworks: ["phoenix"],
      required_steps: [
        %{name: "List All", http_method: "GET", path: "/:resource"},
        %{name: "Get One", http_method: "GET", path: "/:resource/:id"},
        %{name: "Create", http_method: "POST", path: "/:resource"},
        %{name: "Update", http_method: "PUT/PATCH", path: "/:resource/:id"},
        %{name: "Delete", http_method: "DELETE", path: "/:resource/:id"},

        # Each endpoint should have:
        %{name: "Input Validation", for: :all},
        %{name: "Authorization Check", for: :all},
        %{name: "Error Handling", for: :all},
        %{name: "Database Transaction", for: [:create, :update, :delete]},
        %{name: "Return Proper Status", for: :all}
      ],
      optional_steps: [
        %{name: "Pagination", for: :list},
        %{name: "Filtering", for: :list},
        %{name: "Sorting", for: :list},
        %{name: "Rate Limiting", for: :all},
        %{name: "Caching", for: [:list, :get]}
      ]
    }

    # Insert into expected_process_pattern_definitions
  end

  def seed_authentication_flow_pattern do
    pattern = %{
      pattern_name: "OAuth2 Authorization Code Flow",
      pattern_category: "Authentication",
      required_steps: [
        %{name: "Authorization Request", order: 1},
        %{name: "User Login", order: 2},
        %{name: "User Consent", order: 3},
        %{name: "Authorization Code Generation", order: 4},
        %{name: "Token Exchange", order: 5},
        %{name: "Token Storage", order: 6},
        %{name: "Token Refresh", order: 7}
      ],
      # ... transitions between steps
    }
  end

  def seed_payment_processing_pattern do
    # Stripe/payment flow with all required steps
  end

  def seed_event_sourcing_pattern do
    # Event sourcing aggregate pattern
  end
end
```

### Phase 3: Analyze Completeness

```elixir
# lib/singularity/process_patterns/completeness_analyzer.ex

defmodule Singularity.ProcessPatterns.CompletenessAnalyzer do
  @moduledoc """
  Analyze if discovered code flows match expected patterns
  """

  def analyze_flow(flow_id, pattern_id) do
    flow = load_flow(flow_id)
    pattern = load_pattern(pattern_id)

    # Compare
    {found_steps, missing_steps} = match_steps(flow, pattern)
    {found_transitions, missing_transitions} = match_transitions(flow, pattern)

    # Calculate score
    completeness_score = calculate_completeness(
      found_steps,
      pattern.required_steps,
      found_transitions,
      pattern.required_transitions
    )

    # Detect gaps
    gaps = detect_gaps(missing_steps, missing_transitions, flow, pattern)

    # Store results
    save_analysis(%{
      flow_id: flow_id,
      pattern_id: pattern_id,
      completeness_score: completeness_score,
      is_complete: completeness_score >= 0.95,
      gaps: gaps
    })
  end

  defp match_steps(flow, pattern) do
    # Use semantic similarity + keyword matching
    # to find which required steps are implemented

    found = Enum.filter(pattern.required_steps, fn required_step ->
      # Check if flow has a node matching this step
      Enum.any?(flow.nodes, fn node ->
        step_matches_node?(required_step, node)
      end)
    end)

    missing = pattern.required_steps -- found

    {found, missing}
  end

  defp step_matches_node?(step, node) do
    # Semantic similarity (embeddings)
    similarity = vector_similarity(step.embedding, node.embedding)

    # Keyword matching
    keyword_match = step.detection_patterns
    |> Enum.any?(fn pattern ->
      Regex.match?(pattern, node.source_code)
    end)

    similarity > 0.8 || keyword_match
  end
end
```

### Phase 4: Visualize & Report

```elixir
# lib/singularity/process_patterns/flow_visualizer.ex

defmodule Singularity.ProcessPatterns.FlowVisualizer do
  @moduledoc """
  Generate visual flow diagrams + completeness reports
  """

  def generate_flow_diagram(flow_id) do
    flow = load_flow(flow_id)

    # Generate Mermaid diagram
    """
    flowchart TD
      A[POST /api/users] --> B{Validate Input}
      B -->|Valid| C[Check Authorization]
      B -->|Invalid| E[Return 400]
      C -->|Authorized| D[Create User in DB]
      C -->|Unauthorized| F[Return 403]
      D --> G{Success?}
      G -->|OK| H[Return 201]
      G -->|Error| I[Return 500]

      style B fill:#90EE90
      style C fill:#90EE90
      style D fill:#FFB6C1
      style H fill:#90EE90

      %% Legend:
      %% Green = Present
      %% Pink = Missing error handling
    """
  end

  def generate_completeness_report(codebase_name) do
    metrics = get_latest_metrics(codebase_name)
    gaps = get_critical_gaps(codebase_name)

    """
    # Process Completeness Report

    **Codebase**: #{codebase_name}
    **Date**: #{metrics.measured_at}
    **Overall Completeness**: #{Float.round(metrics.avg_completeness_score * 100, 1)}%

    ## Summary

    - Total Flows: #{metrics.total_flows_detected}
    - Complete: #{metrics.complete_flows} ✅
    - Incomplete: #{metrics.incomplete_flows} ⚠️

    ## By Category

    #{format_category_breakdown(metrics.completeness_by_category)}

    ## Critical Gaps (Needs Immediate Attention)

    #{format_gaps(gaps)}

    ## Recommendations

    #{generate_recommendations(gaps)}
    """
  end
end
```

---

## Tools & Databases You Can Use

### For Flow Extraction:

1. **Tree-sitter** (already using!) - AST parsing
2. **rust-analyzer** - Rust code intelligence
3. **ElixirSense** - Elixir code intelligence
4. **CodeQL** - Query-based code analysis (Microsoft)
5. **Semgrep** - Pattern matching for code

### For Visualization:

1. **Mermaid.js** - Flowchart generation (markdown-based)
2. **Graphviz DOT** - Graph visualization
3. **D3.js** - Interactive graphs
4. **Cytoscape.js** - Graph analysis + viz

### For Storage:

1. **PostgreSQL** (you already have!) - Store flows + patterns
2. **Neo4j** (optional) - Graph database for complex flow queries
3. **pgvector** (already using!) - Semantic similarity for step matching

### For Analysis:

1. **Your Rust parsers** (already built!) - Parse code
2. **Bumblebee** (already using!) - Embeddings for semantic matching
3. **Custom Elixir** - Pattern matching + analysis logic

---

## Example Queries

### Find incomplete CRUD operations:

```sql
SELECT
  flow.flow_name,
  flow.codebase_name,
  analysis.completeness_score,
  array_agg(gaps.missing_step_name) as missing_steps
FROM code_execution_flow_metadata flow
JOIN process_completeness_analysis analysis
  ON flow.id = analysis.flow_metadata_id
JOIN expected_process_pattern_definitions pattern
  ON analysis.pattern_id = pattern.id
  AND pattern.pattern_name = 'REST CRUD (Phoenix)'
LEFT JOIN process_gap_detection_results gaps
  ON analysis.id = gaps.analysis_id
WHERE analysis.completeness_score < 1.0
GROUP BY flow.flow_name, flow.codebase_name, analysis.completeness_score
ORDER BY analysis.completeness_score ASC;
```

### Find flows missing error handling:

```sql
SELECT
  flow.flow_name,
  flow.file_path,
  gaps.description,
  gaps.recommendation
FROM code_execution_flow_metadata flow
JOIN process_completeness_analysis analysis
  ON flow.id = analysis.flow_metadata_id
JOIN process_gap_detection_results gaps
  ON analysis.id = gaps.analysis_id
WHERE gaps.gap_type = 'missing_error_handling'
  AND gaps.is_fixed = false
  AND gaps.severity IN ('critical', 'high')
ORDER BY gaps.severity DESC;
```

---

## Next Steps

Want me to:

1. ✅ Create the database migrations for these tables?
2. ✅ Build the Rust flow extractor?
3. ✅ Implement the Elixir completeness analyzer?
4. ✅ Seed common process patterns (CRUD, Auth, Payment)?
5. ✅ Build visualization tools?

This would give you **full process completeness tracking** - like having a checklist that automatically validates your code! 🎯
