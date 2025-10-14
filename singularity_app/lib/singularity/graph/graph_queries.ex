defmodule Singularity.Graph.GraphQueries do
  @moduledoc """
  Graph Query Helper - SQL-based graph queries

  **PURPOSE**: Provide convenient functions for querying the code graph
  using standard SQL (no AGE/Cypher required).

  ## Module Identity

  ```json
  {
    "module_name": "Singularity.Graph.GraphQueries",
    "purpose": "Query code graphs using SQL",
    "type": "Query helper module",
    "operates_on": "graph_nodes and graph_edges tables",
    "output": "Query results (callers, dependencies, etc.)"
  }
  ```

  ## Usage

      # Find who calls a function
      GraphQueries.find_callers("process_data/2")

      # Find what a function calls
      GraphQueries.find_callees("manager/0")

      # Find module dependencies
      GraphQueries.find_dependencies("Singularity.Manager")

      # Find circular dependencies
      GraphQueries.find_circular_dependencies()

      # Get graph statistics
      GraphQueries.stats()

  ## Search Keywords

  graph-queries, call-graph, import-graph, dependencies, code-navigation,
  sql-queries, graph-analysis, circular-dependencies
  """

  require Logger

  alias Singularity.{Repo, Schemas.GraphNode, Schemas.GraphEdge}
  alias Singularity.Graph.AgeQueries
  import Ecto.Query

  # ------------------------------------------------------------------------------
  # Call Graph Queries
  # ------------------------------------------------------------------------------

  @doc """
  Find all functions that call the given function.

  Tries Apache AGE (Cypher) first, falls back to SQL if AGE unavailable.

  Returns list of %{name: "...", file_path: "...", line: ...}
  """
  def find_callers(function_name, codebase_id \\ "singularity") do
    # Try AGE (Cypher) first - 5-20x faster for graph traversals
    case AgeQueries.find_callers_cypher(function_name) do
      {:ok, results} ->
        results

      {:error, reason} ->
        Logger.debug("AGE unavailable (#{inspect(reason)}), using SQL fallback")
        find_callers_sql(function_name, codebase_id)
    end
  end

  # SQL-based fallback implementation
  defp find_callers_sql(function_name, codebase_id) do
    from(gn1 in GraphNode,
      join: ge in GraphEdge,
      on: ge.from_node_id == gn1.node_id,
      join: gn2 in GraphNode,
      on: ge.to_node_id == gn2.node_id,
      where: gn2.name == ^function_name,
      where: ge.edge_type == "calls",
      where: gn1.codebase_id == ^codebase_id,
      select: %{
        name: gn1.name,
        file_path: gn1.file_path,
        line: gn1.line_number,
        node_type: gn1.node_type
      }
    )
    |> Repo.all()
  end

  @doc """
  Find all functions that the given function calls.

  Tries Apache AGE (Cypher) first, falls back to SQL if AGE unavailable.

  Returns list of %{name: "...", file_path: "...", line: ...}
  """
  def find_callees(function_name, codebase_id \\ "singularity") do
    # Try AGE (Cypher) first
    case AgeQueries.find_callees_cypher(function_name) do
      {:ok, results} ->
        results

      {:error, reason} ->
        Logger.debug("AGE unavailable (#{inspect(reason)}), using SQL fallback")
        find_callees_sql(function_name, codebase_id)
    end
  end

  # SQL-based fallback implementation
  defp find_callees_sql(function_name, codebase_id) do
    from(gn1 in GraphNode,
      join: ge in GraphEdge,
      on: ge.from_node_id == gn1.node_id,
      join: gn2 in GraphNode,
      on: ge.to_node_id == gn2.node_id,
      where: gn1.name == ^function_name,
      where: ge.edge_type == "calls",
      where: gn1.codebase_id == ^codebase_id,
      select: %{
        name: gn2.name,
        file_path: gn2.file_path,
        line: gn2.line_number,
        node_type: gn2.node_type
      }
    )
    |> Repo.all()
  end

  @doc """
  Find call chain (who calls who) up to N levels deep.

  Example: find_call_chain("process_data/2", depth: 2)
  Returns nested structure showing call hierarchy.
  """
  def find_call_chain(function_name, opts \\ []) do
    depth = Keyword.get(opts, :depth, 2)
    codebase_id = Keyword.get(opts, :codebase_id, "singularity")

    # Recursive query using PostgreSQL CTE
    query = """
    WITH RECURSIVE call_chain AS (
      -- Base case: Find the starting function
      SELECT
        gn.node_id,
        gn.name,
        gn.file_path,
        gn.line_number,
        0 as depth,
        ARRAY[gn.name] as path
      FROM graph_nodes gn
      WHERE gn.name = $1
        AND gn.codebase_id = $2
        AND gn.node_type = 'function'

      UNION ALL

      -- Recursive case: Find callers
      SELECT
        gn.node_id,
        gn.name,
        gn.file_path,
        gn.line_number,
        cc.depth + 1,
        cc.path || gn.name
      FROM graph_nodes gn
      JOIN graph_edges ge ON ge.from_node_id = gn.node_id
      JOIN call_chain cc ON ge.to_node_id = cc.node_id
      WHERE ge.edge_type = 'calls'
        AND gn.codebase_id = $2
        AND cc.depth < $3
        AND NOT (gn.name = ANY(cc.path))  -- Prevent cycles
    )
    SELECT * FROM call_chain
    ORDER BY depth, name;
    """

    case Repo.query(query, [function_name, codebase_id, depth]) do
      {:ok, result} ->
        rows =
          Enum.map(result.rows, fn [node_id, name, file_path, line, depth, path] ->
            %{
              node_id: node_id,
              name: name,
              file_path: file_path,
              line: line,
              depth: depth,
              path: path
            }
          end)

        {:ok, rows}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ------------------------------------------------------------------------------
  # Import Graph Queries
  # ------------------------------------------------------------------------------

  @doc """
  Find all modules that depend on (import) the given module.

  Returns list of %{name: "...", file_path: "...", dependency_type: "..."}
  """
  def find_dependents(module_name, codebase_id \\ "singularity") do
    target_node_id = "module::#{module_name}"

    from(gn1 in GraphNode,
      join: ge in GraphEdge,
      on: ge.from_node_id == gn1.node_id,
      where: ge.to_node_id == ^target_node_id,
      where: ge.edge_type == "imports",
      where: gn1.codebase_id == ^codebase_id,
      select: %{
        name: gn1.name,
        file_path: gn1.file_path,
        dependency_type: fragment("? -> 'dependency_type'", ge.metadata)
      }
    )
    |> Repo.all()
  end

  @doc """
  Find all modules that the given module depends on (imports).

  Returns list of %{name: "...", dependency_type: "..."}
  """
  def find_dependencies(module_name, codebase_id \\ "singularity") do
    source_node_id = "module::#{module_name}"

    from(gn2 in GraphNode,
      join: ge in GraphEdge,
      on: ge.to_node_id == gn2.node_id,
      where: ge.from_node_id == ^source_node_id,
      where: ge.edge_type == "imports",
      where: gn2.codebase_id == ^codebase_id,
      select: %{
        name: gn2.name,
        file_path: gn2.file_path,
        dependency_type: fragment("? -> 'dependency_type'", ge.metadata),
        weight: ge.weight
      }
    )
    |> Repo.all()
  end

  @doc """
  Find circular dependencies (import cycles).

  Returns list of cycles as arrays of module names.
  """
  def find_circular_dependencies(codebase_id \\ "singularity") do
    # Use recursive CTE to find cycles
    query = """
    WITH RECURSIVE dep_path AS (
      -- Base case: Start from each module
      SELECT
        gn.node_id as start_node,
        gn.node_id as current_node,
        gn.name as current_name,
        ARRAY[gn.name] as path,
        0 as depth
      FROM graph_nodes gn
      WHERE gn.codebase_id = $1
        AND gn.node_type = 'module'

      UNION ALL

      -- Recursive case: Follow imports
      SELECT
        dp.start_node,
        gn.node_id,
        gn.name,
        dp.path || gn.name,
        dp.depth + 1
      FROM dep_path dp
      JOIN graph_edges ge ON ge.from_node_id = dp.current_node
      JOIN graph_nodes gn ON ge.to_node_id = gn.node_id
      WHERE ge.edge_type = 'imports'
        AND gn.codebase_id = $1
        AND dp.depth < 10  -- Limit depth to prevent infinite loops
        AND NOT (gn.name = ANY(dp.path))  -- Don't revisit nodes in path
    )
    SELECT DISTINCT path || start_node.name as cycle
    FROM dep_path dp
    JOIN graph_nodes start_node ON dp.start_node = start_node.node_id
    WHERE dp.current_node = dp.start_node
      AND dp.depth > 0  -- Must have at least one hop
    ORDER BY array_length(cycle, 1), cycle;
    """

    case Repo.query(query, [codebase_id]) do
      {:ok, result} ->
        cycles = Enum.map(result.rows, fn [cycle] -> cycle end)
        {:ok, cycles}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ------------------------------------------------------------------------------
  # Graph Statistics
  # ------------------------------------------------------------------------------

  @doc """
  Get graph statistics.

  Returns %{nodes: %{total: ..., by_type: ...}, edges: %{total: ..., by_type: ...}}
  """
  def stats(codebase_id \\ "singularity") do
    # Node stats
    node_total =
      from(n in GraphNode, where: n.codebase_id == ^codebase_id, select: count())
      |> Repo.one()

    nodes_by_type =
      from(n in GraphNode,
        where: n.codebase_id == ^codebase_id,
        group_by: n.node_type,
        select: {n.node_type, count()}
      )
      |> Repo.all()
      |> Enum.into(%{})

    # Edge stats
    edge_total =
      from(e in GraphEdge, where: e.codebase_id == ^codebase_id, select: count())
      |> Repo.one()

    edges_by_type =
      from(e in GraphEdge,
        where: e.codebase_id == ^codebase_id,
        group_by: e.edge_type,
        select: {e.edge_type, count()}
      )
      |> Repo.all()
      |> Enum.into(%{})

    %{
      nodes: %{total: node_total, by_type: nodes_by_type},
      edges: %{total: edge_total, by_type: edges_by_type}
    }
  end

  @doc """
  Find most called functions (highest in-degree).

  Returns top N functions by number of callers.
  """
  def most_called_functions(limit \\ 10, codebase_id \\ "singularity") do
    from(gn in GraphNode,
      join: ge in GraphEdge,
      on: ge.to_node_id == gn.node_id,
      where: ge.edge_type == "calls",
      where: gn.codebase_id == ^codebase_id,
      group_by: [gn.node_id, gn.name, gn.file_path],
      select: %{
        name: gn.name,
        file_path: gn.file_path,
        caller_count: count(ge.id)
      },
      order_by: [desc: count(ge.id)],
      limit: ^limit
    )
    |> Repo.all()
  end

  @doc """
  Find most complex functions (highest out-degree).

  Returns top N functions by number of function calls they make.
  """
  def most_complex_functions(limit \\ 10, codebase_id \\ "singularity") do
    from(gn in GraphNode,
      join: ge in GraphEdge,
      on: ge.from_node_id == gn.node_id,
      where: ge.edge_type == "calls",
      where: gn.codebase_id == ^codebase_id,
      group_by: [gn.node_id, gn.name, gn.file_path],
      select: %{
        name: gn.name,
        file_path: gn.file_path,
        callee_count: count(ge.id)
      },
      order_by: [desc: count(ge.id)],
      limit: ^limit
    )
    |> Repo.all()
  end
end
