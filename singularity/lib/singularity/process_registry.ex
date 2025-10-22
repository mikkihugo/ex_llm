defmodule Singularity.ProcessRegistry do
  @moduledoc false

  def child_spec(_opts) do
    %{
      id: __MODULE__,
      start: {Registry, :start_link, [[keys: :unique, name: __MODULE__]]}
    }
  end
end
