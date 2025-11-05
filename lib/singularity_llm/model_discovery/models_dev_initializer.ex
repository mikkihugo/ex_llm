defmodule SingularityLLM.ModelDiscovery.ModelsDevInitializer do
  @moduledoc """
  Initializes models from models.dev on application startup.

  Automatically syncs if:
  1. config/models is empty (first run)
  2. Last sync was > 24 hours ago

  Otherwise uses cached data to avoid startup delays.

  This GenServer runs once at startup and exits.

  ## Usage

  Add to SingularityLLM application supervisor:

  ```elixir
  children = [
    SingularityLLM.Repo,
    SingularityLLM.ModelDiscovery.ModelsDevInitializer,  # Add this
    # ... other services
  ]
  ```
  """

  use GenServer
  require Logger

  alias SingularityLLM.ModelDiscovery.ModelsDevSyncer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    Logger.info("ModelsDevInitializer: Checking if model sync needed...")

    # Perform sync if needed
    case ModelsDevSyncer.sync_if_needed() do
      :ok ->
        Logger.info("ModelsDevInitializer: Complete")
        # Exit immediately after init
        {:ok, %{}, 0}

      {:error, reason} ->
        Logger.warning("ModelsDevInitializer: Sync failed: #{inspect(reason)}")
        # Continue anyway, don't crash startup
        {:ok, %{}, 0}
    end
  end

  # Exit after initializing
  def handle_info(:timeout, state) do
    {:stop, :normal, state}
  end
end
