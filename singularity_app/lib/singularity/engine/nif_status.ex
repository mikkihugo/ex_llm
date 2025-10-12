defmodule Singularity.Engine.NifStatus do
  @moduledoc """
  Startup task that logs NIF status after application boots.

  This GenServer starts, logs the status of all NIFs, then exits.
  """

  use GenServer
  require Logger

  alias Singularity.Engine.NifLoader

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Schedule immediate status check
    send(self(), :check_status)
    {:ok, %{}}
  end

  @impl true
  def handle_info(:check_status, state) do
    # Small delay to let NIFs finish loading
    Process.sleep(100)

    NifLoader.log_startup_status()

    # Exit normally - we're done
    {:stop, :normal, state}
  end
end
