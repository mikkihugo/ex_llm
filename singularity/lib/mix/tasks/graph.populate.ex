defmodule Mix.Tasks.Graph.Populate do
  @moduledoc """
  Populate graph tables from code metadata.

  ## Usage

      # Populate all graphs (call graph + import graph)
      mix graph.populate

      # Rebuild from scratch (clear and repopulate)
      mix graph.populate --rebuild

      # Populate only call graph
      mix graph.populate --only call

      # Populate only import graph
      mix graph.populate --only import

      # Use different codebase ID
      mix graph.populate --codebase my-project

  ## What It Does

  1. Reads enhanced metadata from code_files table
  2. Creates graph nodes (functions, modules)
  3. Creates graph edges (calls, imports)
  4. Stores in graph_nodes and graph_edges tables

  ## Examples

      # After code ingestion, populate graphs
      mix graph.populate

      # If you changed metadata, rebuild
      mix graph.populate --rebuild

      # Check graphs in IEx
      iex> alias Singularity.Graph.GraphQueries
      iex> GraphQueries.find_callers("process_data/2")
      iex> GraphQueries.find_dependencies("Singularity.SystemStatusMonitor")
  """

  use Mix.Task

  @shortdoc "Populate graph tables from code metadata"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} =
      OptionParser.parse(args,
        switches: [rebuild: :boolean, only: :string, codebase: :string],
        aliases: [r: :rebuild, o: :only, c: :codebase]
      )

    codebase_id = opts[:codebase] || "singularity"
    rebuild = opts[:rebuild] || false
    only = opts[:only]

    alias Singularity.Graph.GraphPopulator

    Mix.shell().info("Populating graph for codebase: #{codebase_id}")

    result =
      cond do
        rebuild ->
          Mix.shell().info("Rebuilding graphs (clearing old data)...")
          GraphPopulator.rebuild_all(codebase_id)

        only == "call" ->
          Mix.shell().info("Populating call graph only...")
          GraphPopulator.populate_call_graph(codebase_id)

        only == "import" ->
          Mix.shell().info("Populating import graph only...")
          GraphPopulator.populate_import_graph(codebase_id)

        true ->
          Mix.shell().info("Populating all graphs...")
          GraphPopulator.populate_all(codebase_id)
      end

    case result do
      {:ok, stats} ->
        Mix.shell().info("")
        Mix.shell().info("✓ Graph population complete!")
        Mix.shell().info("")
        Mix.shell().info("Statistics:")
        Mix.shell().info("  Nodes created: #{stats.nodes}")
        Mix.shell().info("  Edges created: #{stats.edges}")

        if Map.has_key?(stats, :call_graph) do
          Mix.shell().info("")
          Mix.shell().info("Call Graph:")
          Mix.shell().info("  Function nodes: #{stats.call_graph.nodes}")
          Mix.shell().info("  Call edges: #{stats.call_graph.edges}")
        end

        if Map.has_key?(stats, :import_graph) do
          Mix.shell().info("")
          Mix.shell().info("Import Graph:")
          Mix.shell().info("  Module nodes: #{stats.import_graph.nodes}")
          Mix.shell().info("  Import edges: #{stats.import_graph.edges}")
        end

        Mix.shell().info("")
        Mix.shell().info("Query examples:")
        Mix.shell().info("  iex> alias Singularity.Graph.GraphQueries")
        Mix.shell().info("  iex> GraphQueries.find_callers(\"my_function/2\")")
        Mix.shell().info("  iex> GraphQueries.find_dependencies(\"Singularity.SystemStatusMonitor\")")

      {:error, reason} ->
        Mix.shell().error("✗ Graph population failed: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end
end
