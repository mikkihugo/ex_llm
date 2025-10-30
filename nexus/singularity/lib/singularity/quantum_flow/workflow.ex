defmodule Singularity.QuantumFlow.Workflow do
  @moduledoc false
  defmacro __using__(opts \\ []) do
    quote bind_quoted: [opts: opts] do
      use Pgflow.Workflow, opts
    end
  end
end
