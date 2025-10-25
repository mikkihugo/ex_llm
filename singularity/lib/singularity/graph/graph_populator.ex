defmodule Singularity.Graph.GraphPopulator do
  @moduledoc """
  Graph Populator - Populate graph tables from enhanced code metadata

  **PURPOSE**: Build code graphs (call graph, import graph) from the enhanced
  metadata extracted by AstExtractor and stored in code_files.metadata.

  ## Module Identity

  ```json
  {
    "module_name": "Singularity.Graph.GraphPopulator",
    "purpose": "Populate graph_nodes and graph_edges from code_files metadata",
    "type": "Service module",
    "operates_on": "code_files.metadata (dependencies, call_graph)",
    "output": "graph_nodes and graph_edges tables"
  }
  ```

  ## What It Does

  1. **Reads** enhanced metadata from code_files table
  2. **Creates** graph nodes for functions, modules, classes
  3. **Creates** graph edges for calls, imports, dependencies
  4. **Stores** in graph_nodes and graph_edges tables

  ## Usage

      # Populate call graph for all files
      GraphPopulator.populate_call_graph("singularity")

      # Populate import graph
      GraphPopulator.populate_import_graph("singularity")

      # Populate both
      GraphPopulator.populate_all("singularity")

      # Clear and rebuild
      GraphPopulator.rebuild_all("singularity")

  ## Search Keywords

  graph-population, call-graph, import-graph, dependencies, code-relationships,
  graph-nodes, graph-edges, metadata-extraction, postgresql-graphs
  """

  require Logger

  alias Singularity.{Repo, Schemas.CodeFile, Schemas.GraphNode, Schemas.GraphEdge}
  import Ecto.Query

  # ------------------------------------------------------------------------------
  # Public API
  # ------------------------------------------------------------------------------

  @doc """
  Populate all graph tables (call graph + import graph).

  Also populates intarray fields (dependency_node_ids, dependent_node_ids) for fast queries.
  """
  def populate_all(codebase_id \\ "singularity") do
    Logger.info("Populating all graphs for #{codebase_id}...")

    with {:ok, call_stats} <- populate_call_graph(codebase_id),
         {:ok, import_stats} <- populate_import_graph(codebase_id),
         {:ok, array_stats} <- populate_dependency_arrays(codebase_id) do
      total_nodes = call_stats.nodes + import_stats.nodes
      total_edges = call_stats.edges + import_stats.edges

      Logger.info("✓ Graph population complete: #{total_nodes} nodes, #{total_edges} edges")

      Logger.info(
        "✓ Dependency arrays populated: #{array_stats.dependency_updates} nodes updated"
      )

      {:ok,
       %{
         nodes: total_nodes,
         edges: total_edges,
         arrays_populated: array_stats.dependency_updates,
         call_graph: call_stats,
         import_graph: import_stats
       }}
    end
  end

  @doc """
  Clear all graph data and rebuild from scratch.
  """
  def rebuild_all(codebase_id \\ "singularity") do
    Logger.info("Rebuilding all graphs for #{codebase_id}...")

    # Clear existing graph data
    clear_graph_data(codebase_id)

    # Rebuild
    populate_all(codebase_id)
  end

  @doc """
  Populate call graph from code_files.metadata.call_graph.

  Creates:
  - Nodes: One node per function
  - Edges: Function call relationships
  """
  def populate_call_graph(codebase_id \\ "singularity") do
    Logger.info("Populating call graph for #{codebase_id}...")

    # Get all files with call_graph metadata
    files =
      from(c in CodeFile,
        where: c.project_name == ^codebase_id,
        where: not is_nil(fragment("? -> 'call_graph'", c.metadata))
      )
      |> Repo.all()

    results =
      Enum.map(files, fn file ->
        call_graph = file.metadata["call_graph"] || %{}
        process_call_graph(codebase_id, file, call_graph)
      end)

    # Sum up results
    totals =
      Enum.reduce(results, %{nodes: 0, edges: 0}, fn result, acc ->
        %{nodes: acc.nodes + result.nodes, edges: acc.edges + result.edges}
      end)

    Logger.info("✓ Call graph: #{totals.nodes} function nodes, #{totals.edges} call edges")

    {:ok, totals}
  end

  @doc """
  Populate import graph from code_files.metadata.dependencies.

  Creates:
  - Nodes: One node per module/file
  - Edges: Import/dependency relationships
  """
  def populate_import_graph(codebase_id \\ "singularity") do
    Logger.info("Populating import graph for #{codebase_id}...")

    # Get all files with dependencies metadata
    files =
      from(c in CodeFile,
        where: c.project_name == ^codebase_id,
        where: not is_nil(fragment("? -> 'dependencies'", c.metadata))
      )
      |> Repo.all()

    results =
      Enum.map(files, fn file ->
        dependencies = file.metadata["dependencies"] || %{}
        process_dependencies(codebase_id, file, dependencies)
      end)

    # Sum up results
    totals =
      Enum.reduce(results, %{nodes: 0, edges: 0}, fn result, acc ->
        %{nodes: acc.nodes + result.nodes, edges: acc.edges + result.edges}
      end)

    Logger.info("✓ Import graph: #{totals.nodes} module nodes, #{totals.edges} import edges")

    {:ok, totals}
  end

  @doc """
  Clear all graph data for a codebase.
  """
  def clear_graph_data(codebase_id) do
    Logger.info("Clearing graph data for #{codebase_id}...")

    # Delete edges first (may reference nodes)
    {edges_deleted, _} =
      from(e in GraphEdge, where: e.codebase_id == ^codebase_id)
      |> Repo.delete_all()

    # Delete nodes
    {nodes_deleted, _} =
      from(n in GraphNode, where: n.codebase_id == ^codebase_id)
      |> Repo.delete_all()

    Logger.info("✓ Cleared #{nodes_deleted} nodes, #{edges_deleted} edges")

    {:ok, %{nodes_deleted: nodes_deleted, edges_deleted: edges_deleted}}
  end

  # ------------------------------------------------------------------------------
  # Private Functions - Call Graph
  # ------------------------------------------------------------------------------

  defp process_call_graph(codebase_id, file, call_graph) do
    # Create node for each function
    Enum.each(call_graph, fn {func_name, func_data} ->
      node_id = "#{file.file_path}::#{func_name}"

      # Create/update function node
      %GraphNode{}
      |> GraphNode.changeset(%{
        codebase_id: codebase_id,
        node_id: node_id,
        node_type: "function",
        name: func_name,
        file_path: file.file_path,
        line_number: func_data["line"],
        metadata: %{
          language: file.language,
          calls: func_data["calls"] || [],
          file_hash: file.hash
        }
      })
      |> Repo.insert(
        on_conflict: {:replace_all_except, [:id, :created_at]},
        conflict_target: [:codebase_id, :node_id]
      )

      # Create edges for each function call
      calls = func_data["calls"] || []

      Enum.each(calls, fn called_func ->
        edge_id = "call::#{node_id}->#{called_func}"

        %GraphEdge{}
        |> GraphEdge.changeset(%{
          codebase_id: codebase_id,
          edge_id: edge_id,
          from_node_id: node_id,
          to_node_id: called_func,
          edge_type: "calls",
          weight: 1.0,
          metadata: %{
            source_file: file.file_path,
            source_line: func_data["line"]
          }
        })
        |> Repo.insert(
          on_conflict: :nothing,
          conflict_target: [:codebase_id, :edge_id]
        )
      end)
    end)

    # Return stats
    %{nodes: map_size(call_graph), edges: count_total_calls(call_graph)}
  end

  defp count_total_calls(call_graph) do
    call_graph
    |> Enum.reduce(0, fn {_func, data}, acc ->
      calls = data["calls"] || []
      acc + length(calls)
    end)
  end

  # ------------------------------------------------------------------------------
  # Private Functions - Import Graph
  # ------------------------------------------------------------------------------

  defp process_dependencies(codebase_id, file, dependencies) do
    # Create node for this file/module
    module_name = file.metadata["module_name"] || extract_module_name(file.file_path)
    node_id = "module::#{module_name}"

    %GraphNode{}
    |> GraphNode.changeset(%{
      codebase_id: codebase_id,
      node_id: node_id,
      node_type: "module",
      name: module_name,
      file_path: file.file_path,
      metadata: %{
        language: file.language,
        internal_deps: dependencies["internal"] || [],
        external_deps: dependencies["external"] || [],
        file_hash: file.hash
      }
    })
    |> Repo.insert(
      on_conflict: {:replace_all_except, [:id, :created_at]},
      conflict_target: [:codebase_id, :node_id]
    )

    # Create edges for internal dependencies
    internal_deps = dependencies["internal"] || []
    external_deps = dependencies["external"] || []

    Enum.each(internal_deps, fn dep_module ->
      edge_id = "import::#{node_id}->module::#{dep_module}"

      %GraphEdge{}
      |> GraphEdge.changeset(%{
        codebase_id: codebase_id,
        edge_id: edge_id,
        from_node_id: node_id,
        to_node_id: "module::#{dep_module}",
        edge_type: "imports",
        weight: 1.0,
        metadata: %{
          dependency_type: "internal",
          source_file: file.file_path
        }
      })
      |> Repo.insert(
        on_conflict: :nothing,
        conflict_target: [:codebase_id, :edge_id]
      )
    end)

    # Create edges for external dependencies (lighter weight)
    Enum.each(external_deps, fn dep_module ->
      edge_id = "import::#{node_id}->module::#{dep_module}"

      %GraphEdge{}
      |> GraphEdge.changeset(%{
        codebase_id: codebase_id,
        edge_id: edge_id,
        from_node_id: node_id,
        to_node_id: "module::#{dep_module}",
        edge_type: "imports",
        weight: 0.5,
        metadata: %{
          dependency_type: "external",
          source_file: file.file_path
        }
      })
      |> Repo.insert(
        on_conflict: :nothing,
        conflict_target: [:codebase_id, :edge_id]
      )
    end)

    # Return stats
    %{nodes: 1, edges: length(internal_deps) + length(external_deps)}
  end

  # ------------------------------------------------------------------------------
  # Dependency Array Population (intarray optimization)
  # ------------------------------------------------------------------------------

  @doc """
  Populate dependency_node_ids and dependent_node_ids arrays from edges.

  Uses intarray GIN indexes for fast dependency lookups (10-100x faster).
  Must be called AFTER all nodes and edges are created.
  """
  def populate_dependency_arrays(codebase_id \\ "singularity") do
    Logger.info("Populating dependency arrays for #{codebase_id}...")

    # Get all nodes for this codebase
    nodes =
      from(gn in GraphNode,
        where: gn.codebase_id == ^codebase_id,
        select: %{id: gn.id, node_id: gn.node_id}
      )
      |> Repo.all()
      |> Map.new(&{&1.node_id, &1.id})

    # Get all edges
    edges =
      from(ge in GraphEdge,
        where: ge.codebase_id == ^codebase_id
      )
      |> Repo.all()

    # Build maps of node_id -> [dependency_ids] and reverse
    dependency_map = build_dependency_map(edges, nodes)
    dependent_map = build_dependent_map(edges, nodes)

    # Update nodes with arrays
    update_count =
      Enum.reduce(nodes, 0, fn {node_id, db_id}, acc ->
        deps = Map.get(dependency_map, node_id, [])
        dependents = Map.get(dependent_map, node_id, [])

        if Enum.empty?(deps) and Enum.empty?(dependents) do
          acc
        else
          update_node_arrays(db_id, deps, dependents)
          acc + 1
        end
      end)

    Logger.info("✓ Updated #{update_count} nodes with dependency arrays")
    {:ok, %{dependency_updates: update_count}}
  end

  defp build_dependency_map(edges, nodes) do
    Enum.reduce(edges, %{}, fn edge, acc ->
      from_id = edge.from_node_id
      to_id = edge.to_node_id

      if Map.has_key?(nodes, to_id) do
        to_db_id = nodes[to_id]
        deps = Map.get(acc, from_id, [])
        Map.put(acc, from_id, [to_db_id | deps])
      else
        acc
      end
    end)
  end

  defp build_dependent_map(edges, nodes) do
    Enum.reduce(edges, %{}, fn edge, acc ->
      from_id = edge.from_node_id
      to_id = edge.to_node_id

      if Map.has_key?(nodes, from_id) do
        from_db_id = nodes[from_id]
        dependents = Map.get(acc, to_id, [])
        Map.put(acc, to_id, [from_db_id | dependents])
      else
        acc
      end
    end)
  end

  defp update_node_arrays(node_id, dependency_ids, dependent_ids) do
    # Only update if there are actual dependencies
    from(gn in GraphNode, where: gn.id == ^node_id)
    |> Repo.update_all(
      set: [
        dependency_node_ids: Enum.uniq(dependency_ids),
        dependent_node_ids: Enum.uniq(dependent_ids)
      ]
    )
  end

  defp extract_module_name(file_path) do
    # Extract module name from file path
    # lib/singularity/foo/bar.ex -> Singularity.Foo.Bar
    file_path
    |> String.replace(~r/^.*\/lib\//, "")
    |> String.replace(".ex", "")
    |> String.split("/")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(".")
  end
end
