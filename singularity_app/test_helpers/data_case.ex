defmodule Singularity.DataCase do
  @moduledoc """
  Test helpers for PostgreSQL access.
  Sets up the SQL sandbox and offers helpers for inspecting changeset errors.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias Singularity.Repo

      import Ecto
      import Ecto.Query
      import Singularity.DataCase
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Singularity.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Singularity.Repo, {:shared, self()})
    end

    :ok
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.
  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
