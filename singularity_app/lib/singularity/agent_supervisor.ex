defmodule Singularity.AgentSupervisor do
  @moduledoc """
  Supervises dynamically generated agent workers.
  """
  use DynamicSupervisor

  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def children do
    DynamicSupervisor.which_children(__MODULE__)
    |> Enum.map(fn {_, pid, _, _} -> pid end)
  end
end
