defmodule Singularity.Agents.Coordination.CentralCloudSyncWorker do
  @moduledoc """
  CentralCloud Sync Worker - Periodic syncing of agent capabilities.

  GenServer that runs on a configurable interval (default 5 minutes)
  to push local learnings and pull aggregated insights from CentralCloud.

  ## Responsibility

  - Push local agent capabilities to CentralCloud every N minutes
  - Pull aggregated capabilities from other instances every N minutes
  - Handle sync failures gracefully (logs but doesn't crash)

  ## Configuration

  Set via environment:
  - `CENTRALCLOUD_SYNC_INTERVAL_MS` - Interval in milliseconds (default: 300000 = 5 minutes)
  - `CENTRALCLOUD_SYNC_ENABLED` - Enable/disable syncing (default: "true")

  ## Example

      # In supervision tree
      Singularity.Agents.Coordination.CentralCloudSyncWorker

      # Or with custom options
      {Singularity.Agents.Coordination.CentralCloudSyncWorker, interval_ms: 120000}
  """

  use GenServer
  require Logger
  alias Singularity.Agents.Coordination.CentralCloudSync

  @default_interval_ms 300_000  # 5 minutes
  @sync_enabled System.get_env("CENTRALCLOUD_SYNC_ENABLED", "true") == "true"

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    interval_ms = Keyword.get(opts, :interval_ms, @default_interval_ms)

    if @sync_enabled do
      Logger.info("[CentralCloudSyncWorker] Starting CentralCloud sync worker",
        interval_ms: interval_ms
      )

      # Schedule first sync in 5 seconds (give system time to stabilize)
      schedule_next_sync(5000)
    else
      Logger.info("[CentralCloudSyncWorker] CentralCloud sync is disabled")
    end

    {:ok,
     %{
       interval_ms: interval_ms,
       enabled: @sync_enabled
     }}
  end

  @impl true
  def handle_info(:sync, state) do
    # Perform both push and pull operations
    try do
      Logger.debug("[CentralCloudSyncWorker] Starting sync cycle")

      # Push local capabilities
      CentralCloudSync.push_local_capabilities()

      # Pull and merge aggregated capabilities
      CentralCloudSync.sync_with_centralcloud()

      Logger.debug("[CentralCloudSyncWorker] Sync cycle completed")
    rescue
      e ->
        Logger.warning("[CentralCloudSyncWorker] Exception during sync",
          error: inspect(e)
        )
    end

    # Schedule next sync
    schedule_next_sync(state.interval_ms)

    {:noreply, state}
  end

  defp schedule_next_sync(interval_ms) do
    Process.send_after(self(), :sync, interval_ms)
  end
end
