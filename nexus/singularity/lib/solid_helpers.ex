defmodule Solid.Helpers do
  @moduledoc """
  Custom helpers for Solid templating engine.

  This module provides functionality to register custom helpers
  that can be used in Solid templates.
  """

  # Store for registered helpers
  @helpers :solid_helpers

  @doc """
  Register a custom helper function.

  ## Parameters
  - `name` - Atom name of the helper
  - `fun` - Function to register (should be a 2-arity function)

  ## Examples

      iex> Solid.Helpers.register(:my_helper, fn value, options -> "processed: " <> to_string(value) end)
      :ok
  """
  @spec register(atom(), function()) :: :ok
  def register(name, fun) when is_atom(name) and is_function(fun) do
    # Initialize ETS table if it doesn't exist
    case :ets.info(@helpers) do
      :undefined ->
        :ets.new(@helpers, [:named_table, :public, :set])
      _ ->
        :ok
    end

    :ets.insert(@helpers, {name, fun})
    :ok
  end

  @doc """
  Get a registered helper function.

  ## Parameters
  - `name` - Atom name of the helper

  ## Returns
  - `{:ok, function}` if found
  - `{:error, :not_found}` if not found
  """
  @spec get(atom()) :: {:ok, function()} | {:error, :not_found}
  def get(name) when is_atom(name) do
    case :ets.lookup(@helpers, name) do
      [{^name, fun}] -> {:ok, fun}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  List all registered helper names.
  """
  @spec list() :: [atom()]
  def list do
    case :ets.info(@helpers) do
      :undefined -> []
      _ ->
        :ets.tab2list(@helpers)
        |> Enum.map(fn {name, _} -> name end)
    end
  end

  @doc """
  Call a registered helper.

  ## Parameters
  - `name` - Atom name of the helper
  - `arg1` - First argument
  - `arg2` - Second argument

  ## Returns
  - Result of calling the helper function
  - Raises if helper not found
  """
  @spec call(atom(), any(), any()) :: any()
  def call(name, arg1, arg2) do
    case get(name) do
      {:ok, fun} -> fun.(arg1, arg2)
      {:error, :not_found} -> raise "Helper #{name} not found"
    end
  end
end