defmodule Singularity.QuantumFlow.Worker do
  @moduledoc false
  defmacro __using__(opts \\ []) do
    escaped = Macro.escape(opts)

    quote do
      use QuantumFlow.Worker, unquote(escaped)
    end
  end
end
