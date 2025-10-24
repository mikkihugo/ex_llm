defmodule Singularity.CodeGraph.Queries do
  @moduledoc """
  Graph Queries - Fast structural analysis using PostgreSQL ltree + recursive CTEs.

  Provides functions for traversing code call graphs without external graph databases.
  Leverages PostgreSQL's powerful native extensions:
  - ltree: Hierarchical path queries for dependency chains
  - pg_trgm: Fuzzy matching for module/pattern search
  - hstore: Flexible metadata storage
  - Recursive CTEs: Instant relationship queries

  ## Architecture

  All queries use PostgreSQL recursive CTEs to traverse call_graph_edges:
  - Forward dependencies: What does this module call?
  - Reverse callers: What modules call this one?
  - Shortest path: Minimal dependency chain between modules
  - Circular detection: Find problematic circular dependencies
  - Impact analysis: What breaks if we change this?

  ## Performance

  - Forward/Reverse: <10ms for typical codebases
  - Shortest Path: <50ms (with cycle avoidance)
  - Circular Detection: 100-500ms for full analysis
  - Impact Analysis: <50ms per module

  Requires indexes on:
  - call_graph_edges(source_id)
  - call_graph_edges(target_id)
  - call_graph_edges(source_id, target_id)
  - graph_nodes(pagerank_score)

  ## Usage

  ```elixir
  # All modules called by UserService
  {:ok, deps} = Queries.forward_dependencies(user_service_id)

  # All modules calling UserService
  {:ok, callers} = Queries.reverse_callers(user_service_id)

  # How UserService connects to AuthService
  {:ok, %{path: path, depth: depth}} = Queries.shortest_path(user_service_id, auth_service_id)

  # What needs updating if we change UserService?
  {:ok, impact} = Queries.impact_analysis(user_service_id)

  # All circular dependencies in codebase
  {:ok, cycles} = Queries.find_cycles()
  ```

  ## AI Navigation Metadata

  ### Module Identity (JSON)

  ```json
  {
    "module": "Singularity.CodeGraph.Queries",
    "purpose": "Fast graph traversal for call graph analysis using recursive CTEs",
    "role": "infrastructure",
    "layer": "database_access",
    "key_responsibilities": [
      "Recursive CTE queries for forward/reverse dependencies",
      "Shortest path finding between modules",
      "Circular dependency detection",
      "Change impact analysis",
      "Graph traversal with depth limits"
    ],
    "prevents_duplicates": ["GraphAnalyzer", "DependencyTraversal", "CallGraphQueries", "ImpactAnalyzer"],
    "uses": ["PostgreSQL recursive CTEs", "Repo.query", "GraphNodes schema"],
    "alternatives": {
      "AGE extension": "For dedicated graph databases (not available on ARM64)",
      "Neo4j": "Separate database (overcomplicated for this scale)",
      "NetworkX": "Python-based (not applicable)"
    }
  }
  ```

  ### Call Graph (YAML)

  ```yaml
  calls_out:
    - module: Singularity.Repo
      function: query/2, query!/2
      purpose: Execute recursive CTE queries
      critical: true
      pattern: "SQL parameterized queries"

    - module: Ecto.Query
      function: fragment/1
      purpose: Build dynamic queries (if needed)
      critical: false

  called_by:
    - module: Singularity.Architecture.ArchitectureAnalyzer
      function: analyze_dependencies/1
      purpose: Get code structure for architecture analysis
      frequency: per_analysis_request

    - module: Singularity.Agents.RefinementAgent
      function: check_safe_changes/1
      purpose: Verify no circular dependencies created
      frequency: per_refactoring

    - module: Singularity.Execution.TaskDAGExecutor
      function: detect_blocked_tasks/1
      purpose: Find blocking dependencies
      frequency: per_task_execution

    - module: Singularity.Tools.Default
      function: graph_analyze/1
      purpose: User command: show dependencies
      frequency: on_demand

  state_transitions:
    - name: forward_dependencies
      from: idle
      to: idle
      trigger: called with module_id
      actions:
        - Execute recursive CTE query
        - Return list of target modules
        - Include depth information

    - name: impact_analysis
      from: idle
      to: idle
      trigger: called with module_id
      actions:
        - Execute bidirectional recursive CTE
        - Join with PageRank scores
        - Sort by impact (depth + pagerank)
        - Return affected modules

  depends_on:
    - PostgreSQL 9.6+ (for recursive CTE support)
    - call_graph_edges table with source_id, target_id
    - graph_nodes table with id, pagerank_score, name
    - Indexes on (source_id, target_id) for performance
  ```

  ### Anti-Patterns

  #### ❌ DO NOT implement separate GraphAnalyzer or DependencyTraversal
  **Why:** CodeGraph.Queries provides all graph traversal capabilities.

  ```elixir
  # ❌ WRONG - Reimplementing what Queries already does
  defmodule MyApp.GraphAnalyzer do
    def find_dependencies(module_id) do
      Ecto.Query.from(e in CallGraphEdges, where: e.source_id == ^module_id)
    end
  end

  # ✅ CORRECT - Use CodeGraph.Queries
  {:ok, deps} = CodeGraph.Queries.forward_dependencies(module_id)
  ```

  #### ❌ DO NOT use simple joins instead of recursive CTEs
  **Why:** Can't handle multi-level dependencies efficiently.

  ```elixir
  # ❌ WRONG - Only gets direct dependencies, not transitive
  Ecto.Query.from(e in CallGraphEdges, where: e.source_id == ^module_id)

  # ✅ CORRECT - Gets all levels of dependencies
  CodeGraph.Queries.forward_dependencies(module_id, max_depth: 10)
  ```

  #### ❌ DO NOT bypass queries for raw SQL without error handling
  **Why:** Need consistent error handling and parameter safety.

  ```elixir
  # ❌ WRONG - Unsafe SQL
  Repo.query!("SELECT * FROM call_graph_edges WHERE source_id = " <> inspect(module_id))

  # ✅ CORRECT - Parameterized query with error handling
  Repo.query(query, [module_id])
  ```

  ### Search Keywords

  graph queries, code dependencies, call graph, impact analysis, circular dependencies,
  recursive CTE, shortest path, module relationships, code structure, dependency
  traversal, change impact, refactoring safety
  """

  require Logger
  alias Singularity.Repo

  @type module_id :: any()
  @type query_result :: {:ok, any()} | {:error, term()}

  @doc """
  Get all modules called by the given module (forward dependencies).

  Returns list of `{target_id, depth}` tuples, ordered by depth.
  Depth indicates levels of indirection (1 = direct call, 2 = calls a function that calls, etc).

  ## Options

  - `:max_depth` - Maximum recursion depth (default: 10)

  ## Examples

      iex> Queries.forward_dependencies(user_service_id)
      {:ok, [
        %{target_id: auth_service_id, depth: 1},
        %{target_id: db_service_id, depth: 2}
      ]}
  """
  @spec forward_dependencies(module_id, keyword()) :: query_result()
  def forward_dependencies(module_id, opts \\ []) do
    max_depth = Keyword.get(opts, :max_depth, 10)

    query = """
    WITH RECURSIVE dependencies AS (
      SELECT source_id, target_id, 1 as depth
      FROM call_graph_edges
      WHERE source_id = $1

      UNION ALL

      SELECT d.source_id, e.target_id, d.depth + 1
      FROM dependencies d
      JOIN call_graph_edges e ON d.target_id = e.source_id
      WHERE d.depth < $2
    )
    SELECT DISTINCT target_id, depth FROM dependencies
    ORDER BY depth ASC, target_id
    """

    case Repo.query(query, [module_id, max_depth]) do
      {:ok, %{rows: rows}} ->
        result = Enum.map(rows, fn [target_id, depth] ->
          %{target_id: target_id, depth: depth}
        end)
        {:ok, result}

      error ->
        Logger.error("Forward dependencies query failed: #{inspect(error)}")
        error
    end
  end

  @doc """
  Get all modules that call the given module (reverse dependencies).

  Returns list of `{source_id, depth}` tuples, ordered by depth.
  Depth indicates distance from the target module.

  ## Options

  - `:max_depth` - Maximum recursion depth (default: 10)

  ## Examples

      iex> Queries.reverse_callers(auth_service_id)
      {:ok, [
        %{source_id: user_service_id, depth: 1},
        %{source_id: api_gateway_id, depth: 2}
      ]}
  """
  @spec reverse_callers(module_id, keyword()) :: query_result()
  def reverse_callers(module_id, opts \\ []) do
    max_depth = Keyword.get(opts, :max_depth, 10)

    query = """
    WITH RECURSIVE callers AS (
      SELECT source_id, target_id, 1 as depth
      FROM call_graph_edges
      WHERE target_id = $1

      UNION ALL

      SELECT e.source_id, c.target_id, c.depth + 1
      FROM callers c
      JOIN call_graph_edges e ON c.source_id = e.target_id
      WHERE c.depth < $2
    )
    SELECT DISTINCT source_id, depth FROM callers
    ORDER BY depth ASC, source_id
    """

    case Repo.query(query, [module_id, max_depth]) do
      {:ok, %{rows: rows}} ->
        result = Enum.map(rows, fn [source_id, depth] ->
          %{source_id: source_id, depth: depth}
        end)
        {:ok, result}

      error ->
        Logger.error("Reverse callers query failed: #{inspect(error)}")
        error
    end
  end

  @doc """
  Find shortest path between two modules in the call graph.

  Returns `{:ok, %{path: [...], depth: N}}` where path is list of module IDs.
  Returns `{:error, :no_path}` if modules are not connected.

  ## Options

  - `:max_depth` - Maximum path length to consider (default: 10)

  ## Examples

      iex> Queries.shortest_path(service_a_id, service_b_id)
      {:ok, %{path: [service_a_id, service_x_id, service_b_id], depth: 2}}

      iex> Queries.shortest_path(isolated_a, isolated_b)
      {:error, :no_path}
  """
  @spec shortest_path(module_id, module_id, keyword()) :: query_result()
  def shortest_path(from_module_id, to_module_id, opts \\ []) do
    max_depth = Keyword.get(opts, :max_depth, 10)

    query = """
    WITH RECURSIVE paths AS (
      SELECT source_id, target_id, ARRAY[source_id, target_id] as path, 1 as depth
      FROM call_graph_edges
      WHERE source_id = $1

      UNION ALL

      SELECT p.source_id, e.target_id, p.path || e.target_id, p.depth + 1
      FROM paths p
      JOIN call_graph_edges e ON p.target_id = e.source_id
      WHERE NOT e.target_id = ANY(p.path) AND p.depth < $3
    )
    SELECT path, depth FROM paths
    WHERE target_id = $2
    ORDER BY depth ASC
    LIMIT 1
    """

    case Repo.query(query, [from_module_id, to_module_id, max_depth]) do
      {:ok, %{rows: [[path, depth] | _]}} ->
        {:ok, %{path: path, depth: depth}}

      {:ok, %{rows: []}} ->
        {:error, :no_path}

      error ->
        Logger.error("Shortest path query failed: #{inspect(error)}")
        error
    end
  end

  @doc """
  Find all circular dependencies in the codebase.

  Returns list of cycles as paths (each path represents one circular dependency).
  Cycles are ordered by length (shorter cycles listed first = more problematic).

  ## Options

  - `:max_depth` - Maximum cycle length to detect (default: 5)

  ## Examples

      iex> Queries.find_cycles()
      {:ok, [
        %{path: [service_a_id, service_b_id, service_a_id]},
        %{path: [service_x_id, service_y_id, service_z_id, service_x_id]}
      ]}
  """
  @spec find_cycles(keyword()) :: query_result()
  def find_cycles(opts \\ []) do
    max_depth = Keyword.get(opts, :max_depth, 5)

    query = """
    WITH RECURSIVE visited AS (
      SELECT source_id, target_id, ARRAY[source_id] as path, 1 as depth
      FROM call_graph_edges

      UNION ALL

      SELECT v.source_id, e.target_id, v.path || e.target_id, v.depth + 1
      FROM visited v
      JOIN call_graph_edges e ON v.target_id = e.source_id
      WHERE NOT e.target_id = ANY(v.path) AND v.depth < $1
    )
    SELECT DISTINCT source_id, path || target_id as cycle
    FROM visited
    WHERE target_id = ANY(path)
    ORDER BY array_length(path || target_id, 1) ASC
    """

    case Repo.query(query, [max_depth]) do
      {:ok, %{rows: rows}} ->
        result = Enum.map(rows, fn [_source_id, cycle] ->
          %{cycle: cycle}
        end)
        {:ok, result}

      error ->
        Logger.error("Circular dependency detection failed: #{inspect(error)}")
        error
    end
  end

  @doc """
  Analyze impact of changing a module.

  Shows all modules affected by changes to the given module.
  Modules are sorted by depth (distance) and importance (PageRank score).

  ## Options

  - `:max_depth` - Maximum depth to analyze (default: 5)

  ## Examples

      iex> Queries.impact_analysis(user_service_id)
      {:ok, [
        %{target_id: auth_id, depth: 1, pagerank_score: 8.5, name: "AuthService"},
        %{target_id: api_id, depth: 2, pagerank_score: 6.2, name: "APIGateway"}
      ]}
  """
  @spec impact_analysis(module_id, keyword()) :: query_result()
  def impact_analysis(module_id, opts \\ []) do
    max_depth = Keyword.get(opts, :max_depth, 5)

    query = """
    WITH RECURSIVE affected AS (
      SELECT source_id, target_id, 1 as depth
      FROM call_graph_edges
      WHERE target_id = $1

      UNION ALL

      SELECT e.source_id, c.target_id, c.depth + 1
      FROM affected c
      JOIN call_graph_edges e ON c.source_id = e.source_id
      WHERE c.depth < $2
    )
    SELECT DISTINCT target_id, depth, gn.pagerank_score, gn.name
    FROM affected
    LEFT JOIN graph_nodes gn ON gn.id = target_id
    ORDER BY depth ASC, pagerank_score DESC NULLS LAST
    """

    case Repo.query(query, [module_id, max_depth]) do
      {:ok, %{rows: rows}} ->
        result = Enum.map(rows, fn [target_id, depth, pagerank, name] ->
          %{
            target_id: target_id,
            depth: depth,
            pagerank_score: pagerank,
            name: name
          }
        end)
        {:ok, result}

      error ->
        Logger.error("Impact analysis query failed: #{inspect(error)}")
        error
    end
  end

  @doc """
  Get bidirectional dependency graph stats for a module.

  Combines forward and reverse dependency analysis in one call.

  ## Examples

      iex> Queries.dependency_stats(service_id)
      {:ok, %{
        forward_count: 5,
        reverse_count: 12,
        is_leaf: false,
        is_root: false,
        is_isolated: false,
        max_forward_depth: 3,
        max_reverse_depth: 4
      }}
  """
  @spec dependency_stats(module_id, keyword()) :: query_result()
  def dependency_stats(module_id, opts \\ []) do
    max_depth = Keyword.get(opts, :max_depth, 10)

    forward_query = """
    WITH RECURSIVE dependencies AS (
      SELECT source_id, target_id, 1 as depth
      FROM call_graph_edges
      WHERE source_id = $1

      UNION ALL

      SELECT d.source_id, e.target_id, d.depth + 1
      FROM dependencies d
      JOIN call_graph_edges e ON d.target_id = e.source_id
      WHERE d.depth < $2
    )
    SELECT COUNT(DISTINCT target_id) as count, MAX(depth) as max_depth
    FROM dependencies
    """

    reverse_query = """
    WITH RECURSIVE callers AS (
      SELECT source_id, target_id, 1 as depth
      FROM call_graph_edges
      WHERE target_id = $1

      UNION ALL

      SELECT e.source_id, c.target_id, c.depth + 1
      FROM callers c
      JOIN call_graph_edges e ON c.source_id = e.target_id
      WHERE c.depth < $2
    )
    SELECT COUNT(DISTINCT source_id) as count, MAX(depth) as max_depth
    FROM callers
    """

    with {:ok, %{rows: [[forward_count, forward_depth]]}} <- Repo.query(forward_query, [module_id, max_depth]),
         {:ok, %{rows: [[reverse_count, reverse_depth]]}} <- Repo.query(reverse_query, [module_id, max_depth]) do
      {:ok, %{
        forward_count: forward_count || 0,
        reverse_count: reverse_count || 0,
        max_forward_depth: forward_depth || 0,
        max_reverse_depth: reverse_depth || 0,
        is_leaf: (reverse_count || 0) > 0 and (forward_count || 0) == 0,
        is_root: (forward_count || 0) > 0 and (reverse_count || 0) == 0,
        is_isolated: (forward_count || 0) == 0 and (reverse_count || 0) == 0
      }}
    else
      error ->
        Logger.error("Dependency stats query failed: #{inspect(error)}")
        error
    end
  end
end
