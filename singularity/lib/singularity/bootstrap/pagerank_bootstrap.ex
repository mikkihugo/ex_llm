defmodule Singularity.Bootstrap.PageRankBootstrap do
  @moduledoc """
  PageRank Bootstrap - Automatically calculate PageRank on startup and schedule refreshes.

  ## Purpose

  Ensures PageRank scores are always available for module importance queries.
  - Calculates on application startup (background job)
  - Refreshes daily via Oban scheduler
  - No manual intervention needed

  ## Automatic Flow

  ```
  Application Startup
    ↓
  PageRankBootstrap.ensure_initialized()
    ├─ Check if pagerank_score column exists
    ├─ If no scores exist, enqueue calculation job
    └─ Schedule daily refresh (via Oban)
    ↓
  Daily Refresh (4:00 AM UTC)
    ├─ Recalculate PageRank scores
    └─ Log results for monitoring
  ```

  ## Configuration

  Add to `config.exs`:
  ```elixir
  config :singularity, Singularity.Bootstrap.PageRankBootstrap,
    enabled: true,
    refresh_schedule: "0 4 * * *",  # 4 AM UTC daily
    auto_init: true                  # Calculate on startup
  ```

  ## Module Identity

  ```json
  {
    "module": "Singularity.Bootstrap.PageRankBootstrap",
    "purpose": "Auto-initialize and schedule PageRank calculations",
    "type": "bootstrap_service",
    "layer": "infrastructure",
    "startup_order": "after_repo",
    "dependencies": ["Repo", "JobOrchestrator"]
  }
  ```

  ## Search Keywords

  pagerank-bootstrap, automatic-scheduling, startup-initialization,
  background-jobs, infrastructure-setup
  """

  require Logger
  alias Singularity.Repo
  alias Singularity.Schemas.GraphNode
  alias Singularity.Jobs.JobOrchestrator

  import Ecto.Query

  @doc """
  Initialize PageRank on application startup.

  Called once during application startup to:
  - Check if PageRank column exists
  - Check if scores are populated
  - Enqueue initial calculation if needed
  - Schedule daily refresh
  """
  def ensure_initialized do
    config = Application.get_env(:singularity, __MODULE__, [])
    enabled = Keyword.get(config, :enabled, true)
    auto_init = Keyword.get(config, :auto_init, true)

    unless enabled do
      Logger.info("PageRank bootstrap disabled in configuration")
      return :ok
    end

    Logger.info("🚀 PageRank Bootstrap: Checking initialization status...")

    try do
      # Check if column exists
      case check_column_exists?() do
        false ->
          Logger.warning("⚠️  PageRank column not found - run migrations first")
          Logger.warning("   Run: mix ecto.migrate")
          :ok

        true ->
          # Check if scores are populated
          score_count = count_scores()

          cond do
            score_count == 0 and auto_init ->
              Logger.info("📊 No PageRank scores found - enqueuing initial calculation...")
              enqueue_calculation("startup")

            score_count > 0 ->
              Logger.info("✅ PageRank scores present (#{score_count} modules)")

            true ->
              Logger.info("⏭️  PageRank auto-init disabled in config")
          end

          # Schedule daily refresh (whether or not we just calculated)
          schedule_daily_refresh(config)
          :ok
      end
    rescue
      e ->
        Logger.error("❌ PageRank bootstrap error: #{inspect(e)}")
        # Don't crash app startup - just log and continue
        :ok
    end
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  @doc false
  defp check_column_exists? do
    try do
      # Try to query the column
      Repo.exists?(from(n in GraphNode, where: n.pagerank_score >= 0.0))
      true
    rescue
      _e -> false
    end
  end

  @doc false
  defp count_scores do
    try do
      Repo.aggregate(
        from(n in GraphNode, where: n.pagerank_score > 0.0),
        :count
      )
    rescue
      _e -> 0
    end
  end

  @doc false
  defp enqueue_calculation(context) do
    case JobOrchestrator.enqueue(:pagerank_calculation, %{
      "codebase_id" => "singularity",
      "context" => context
    }) do
      {:ok, job} ->
        Logger.info("✅ PageRank calculation job enqueued (ID: #{job.id})")
        {:ok, job}

      {:error, reason} ->
        Logger.warning("⚠️  Failed to enqueue PageRank job: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc false
  defp schedule_daily_refresh(config) do
    schedule = Keyword.get(config, :refresh_schedule, "0 4 * * *")

    Logger.info("📅 PageRank daily refresh scheduled: #{schedule}")

    # Note: Daily refresh is handled by pg_cron (database-native scheduling)
    # See migration: add_pagerank_pg_cron_schedule.exs
    # This is just for logging/documentation purposes
  end

  @doc """
  Manually trigger PageRank calculation (for use in iex or when needed).

  Returns {:ok, job} or {:error, reason}.
  """
  def recalculate_now do
    Logger.info("🔄 Manually triggering PageRank recalculation...")
    enqueue_calculation("manual")
  end
end
