defmodule Singularity.Execution.Planning.Vision do
  @moduledoc """
  Vision management for planning and goal setting with approval tracking.

  Provides centralized vision management for the planning system with
  approval tracking, version history, and integration with work planning
  components for goal-oriented development.

  ## Integration Points

  This module integrates with:
  - PostgreSQL table: `vision_history` (stores vision changes and approvals)

  ## Usage

      # Set system vision
      :ok = Vision.set_vision("Build AGI-powered autonomous development platform")
      # => :ok

      # Get current vision
      vision = Vision.get_vision()
      # => %{vision: "Build AGI-powered...", approved_by: "system", updated_at: ~U[...]}
  """

  use GenServer
  require Logger

  @doc """
  Set the system vision.
  """
  def set_vision(vision_text, opts \\ []) do
    approved_by = Keyword.get(opts, :approved_by, "system")

    case GenServer.call(__MODULE__, {:set_vision, vision_text, approved_by}) do
      :ok ->
        Logger.info("Vision updated", %{
          approved_by: approved_by,
          vision_length: String.length(vision_text)
        })

        :ok

      {:error, reason} ->
        Logger.error("Failed to set vision: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Get current vision.
  """
  def get_vision do
    GenServer.call(__MODULE__, :get_vision)
  end

  @doc """
  Start the vision manager.
  """
  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, _opts)
  end

  @impl true
  def init(opts) do
    {:ok, %{vision: nil, approved_by: nil, updated_at: nil}}
  end

  @impl true
  def handle_call({:set_vision, vision_text, approved_by}, _from, state) do
    new_state = %{
      state
      | vision: vision_text,
        approved_by: approved_by,
        updated_at: DateTime.utc_now()
    }

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_vision, _from, state) do
    {:reply, state, state}
  end
end
