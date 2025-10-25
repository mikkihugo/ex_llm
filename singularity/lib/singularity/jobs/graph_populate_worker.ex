defmodule Singularity.Jobs.GraphPopulateWorker do
  @moduledoc """
  Populate dependency arrays in graph database (one-time + periodic)

  Populates:
  - dependency_node_ids (what each node depends on)
  - dependent_node_ids (what depends on each node)

  Runs on startup and after major codebase changes.
  Makes dependency queries 5-100x faster (GIN index vs JOINs).

  Previously manual: `mix graph.populate`
  """

  use Oban.Worker, queue: :maintenance

  require Logger

  @impl Oban.Worker
  def perform(_job) do
    Logger.info("Populating graph dependencies...")

    case Singularity.Graph.GraphPopulator.populate_all(Singularity.Repo) do
      {:ok, stats} ->
        Logger.info("✅ Graph populated")
        Logger.info("  - Nodes: #{stats[:nodes_processed]}")
        Logger.info("  - Edges: #{stats[:edges_processed]}")
        Logger.info("  - Arrays updated: #{stats[:arrays_populated]}")
        :ok

      {:error, reason} ->
        Logger.error("❌ Graph populate failed: #{reason}")
        {:error, reason}
    end
  rescue
    e ->
      Logger.error("Exception during graph populate: #{inspect(e)}")
      {:error, "Exception: #{inspect(e)}"}
  end
end
