defmodule Pgflow.Workflow do
  @moduledoc """
  Compatibility wrapper for callers expecting `Pgflow.Workflow`.
  Delegates `use Pgflow.Workflow` to `ExPgflow.Workflow` so existing
  code continues to work without changing dependencies.
  """

  # Forward the `use` call to ExPgflow.Workflow so `use Pgflow.Workflow`
  # behaves exactly like `use ExPgflow.Workflow`.
  defmacro __using__(opts \\ []) do
    quote do
      use ExPgflow.Workflow, unquote(opts)
    end
  end
end