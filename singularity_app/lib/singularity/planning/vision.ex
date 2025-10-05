defmodule Singularity.Planning.Vision do
  @moduledoc """
  Vision management for planning and goal setting.
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
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  @impl true
  def init(_opts) do
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
