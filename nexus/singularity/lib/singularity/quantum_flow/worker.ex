defmodule Singularity.QuantumFlow.Worker do
  @moduledoc false
  defmacro __using__(opts \\ []) do
    quote bind_quoted: [opts: opts] do
      use Pgflow.Worker, opts
    end
  end
end
