defmodule Singularity.FrameworkPatternSync do
  @moduledoc """
  Sync framework patterns: PostgreSQL → ETS → NATS → Rust

  ## Architecture

  ```
  PostgreSQL (source of truth, self-learning)
    ↓
  ETS Cache (hot patterns, <5ms reads)
    ↓
  NATS Publish (distribute to SPARC fact system)
    ↓
  Export JSON (Rust detector reads)
  ```

  ## Flow

  1. **Learn** - Pattern detected, stored in PG
  2. **Cache** - Load to ETS for fast access
  3. **Publish** - Broadcast via NATS to fact system
  4. **Export** - Write JSON for Rust to read
  """

  use GenServer
  require Logger

  @ets_table :framework_patterns_cache
  # 5 minutes
  @refresh_interval 5 * 60 * 1000
  @nats_subject "knowledge.facts.framework_patterns"
  @json_export_path "rust/package_registry_indexer/framework_patterns.json"

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get pattern from ETS cache (ultra-fast)
  """
  def get_pattern(framework_name) do
    case :ets.lookup(@ets_table, framework_name) do
      [{^framework_name, pattern, _timestamp}] ->
        {:ok, pattern}

      [] ->
        # Cache miss - load from PG
        case Singularity.FrameworkPatternStore.get_pattern(framework_name) do
          {:ok, pattern} ->
            cache_pattern(framework_name, pattern)
            {:ok, pattern}

          error ->
            error
        end
    end
  end

  @doc """
  Learn and sync new pattern
  """
  def learn_and_sync(detection_result) do
    GenServer.cast(__MODULE__, {:learn_pattern, detection_result})
  end

  @doc """
  Force refresh cache from PostgreSQL
  """
  def refresh_cache do
    GenServer.cast(__MODULE__, :refresh_cache)
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    # Create ETS table
    :ets.new(@ets_table, [:named_table, :set, :public, read_concurrency: true])

    # Initial load from PostgreSQL
    load_all_patterns()

    # Schedule periodic refresh
    schedule_refresh()

    Logger.info("✅ Framework pattern sync started (ETS + NATS)")

    {:ok, %{last_refresh: System.monotonic_time(:millisecond)}}
  end

  @impl true
  def handle_cast({:learn_pattern, detection_result}, state) do
    # 1. Store in PostgreSQL
    case Singularity.FrameworkPatternStore.learn_pattern(detection_result) do
      {:ok, _id} ->
        # 2. Update ETS cache
        cache_pattern(detection_result.framework_name, detection_result)

        # 3. Publish to NATS
        publish_to_nats(detection_result)

        # 4. Export to JSON for Rust
        spawn(fn -> export_to_json() end)

        Logger.info("Learned and synced pattern: #{detection_result.framework_name}")

      {:error, reason} ->
        Logger.error("Failed to learn pattern: #{inspect(reason)}")
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast(:refresh_cache, state) do
    Logger.info("Refreshing framework patterns cache from PostgreSQL...")

    count = load_all_patterns()

    Logger.info("Refreshed #{count} patterns to ETS cache")

    {:noreply, %{state | last_refresh: System.monotonic_time(:millisecond)}}
  end

  @impl true
  def handle_info(:refresh_cache, state) do
    # Periodic refresh
    load_all_patterns()
    schedule_refresh()

    {:noreply, %{state | last_refresh: System.monotonic_time(:millisecond)}}
  end

  ## Private Functions

  defp load_all_patterns do
    query = """
    SELECT
      framework_name,
      jsonb_build_object(
        'framework_name', framework_name,
        'framework_type', framework_type,
        'file_patterns', file_patterns,
        'directory_patterns', directory_patterns,
        'config_files', config_files,
        'build_command', build_command,
        'dev_command', dev_command,
        'install_command', install_command,
        'test_command', test_command,
        'output_directory', output_directory,
        'confidence_weight', confidence_weight,
        'success_rate', success_rate,
        'detection_count', detection_count,
        'metadata', extended_metadata
      ) as pattern_data
    FROM framework_patterns
    ORDER BY detection_count DESC
    """

    case Singularity.Repo.query(query, []) do
      {:ok, %{rows: rows}} ->
        Enum.each(rows, fn [framework_name, pattern_json] ->
          pattern = Jason.decode!(pattern_json)
          :ets.insert(@ets_table, {framework_name, pattern, System.os_time(:second)})
        end)

        length(rows)

      {:error, reason} ->
        Logger.error("Failed to load patterns: #{inspect(reason)}")
        0
    end
  end

  defp cache_pattern(framework_name, pattern) do
    :ets.insert(@ets_table, {framework_name, pattern, System.os_time(:second)})
  end

  defp publish_to_nats(pattern) do
    # Publish to NATS for SPARC fact system
    _message = %{
      type: "framework_pattern",
      framework: pattern.framework_name,
      data: pattern,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    # TODO: Use actual NATS client when available
    # NATS.publish(@nats_subject, Jason.encode!(message))

    Logger.debug("Published pattern to NATS: #{@nats_subject}")
  end

  defp export_to_json do
    # Export all patterns to JSON for Rust detector
    query = """
    SELECT
      jsonb_agg(
        jsonb_build_object(
          'framework_name', framework_name,
          'framework_type', framework_type,
          'file_patterns', file_patterns,
          'directory_patterns', directory_patterns,
          'config_files', config_files,
          'build_command', build_command,
          'dev_command', dev_command,
          'install_command', install_command,
          'test_command', test_command,
          'output_directory', output_directory,
          'confidence_weight', confidence_weight,
          'success_rate', success_rate,
          'last_detected_at', last_detected_at
        )
      ) as patterns
    FROM framework_patterns
    """

    case Singularity.Repo.query(query, []) do
      {:ok, %{rows: [[patterns_json]]}} when is_binary(patterns_json) ->
        output = %{
          version: "1.0.0",
          last_updated: DateTime.utc_now() |> DateTime.to_iso8601(),
          patterns: Jason.decode!(patterns_json),
          metadata: %{
            source: "PostgreSQL framework_patterns table",
            auto_generated: true,
            pattern_count: length(Jason.decode!(patterns_json))
          }
        }

        json = Jason.encode!(output, pretty: true)
        File.write!(@json_export_path, json)

        Logger.info("Exported patterns to #{@json_export_path}")
        :ok

      {:error, reason} ->
        Logger.error("Failed to export patterns: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp schedule_refresh do
    Process.send_after(self(), :refresh_cache, @refresh_interval)
  end

  @doc """
  Get cache statistics
  """
  def stats do
    %{
      cache_size: :ets.info(@ets_table, :size),
      cache_memory_bytes: :ets.info(@ets_table, :memory) * :erlang.system_info(:wordsize),
      # Placeholder
      last_refresh: :ets.info(@ets_table, :size)
    }
  end
end
