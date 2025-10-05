defmodule Singularity.HotReload.CodeValidator do
  @moduledoc """
  Code validation for hot reload system.

  Validates code before hot reloading to ensure:
  - Code is not empty
  - Code size is within limits (max 1MB)
  - Code contains at least one function definition

  Migrated from Gleam seed/improver.gleam
  """

  defmodule ValidationError do
    @moduledoc "Validation error details"
    defexception [:message]
  end

  @max_code_size 1_000_000

  @doc """
  Validate code before hot reload.

  Returns `{:ok, code}` if valid, `{:error, reason}` otherwise.

  ## Examples

      iex> CodeValidator.validate("")
      {:error, %ValidationError{message: "code payload is empty"}}

      iex> CodeValidator.validate("def foo, do: :ok")
      {:ok, "def foo, do: :ok"}
  """
  @spec validate(String.t()) :: {:ok, String.t()} | {:error, ValidationError.t()}
  def validate(code) when is_binary(code) do
    cond do
      String.length(code) == 0 ->
        {:error, %ValidationError{message: "code payload is empty"}}

      String.length(code) > @max_code_size ->
        {:error, %ValidationError{message: "code payload too large (max 1MB)"}}

      not has_function?(code) ->
        {:error, %ValidationError{message: "code must contain at least one function"}}

      true ->
        {:ok, code}
    end
  end

  defp has_function?(code) do
    String.contains?(code, "def ") or
      String.contains?(code, "defp ") or
      String.contains?(code, "defmacro ")
  end

  @doc """
  Hot reload code module.

  Currently returns a timestamp as version ID.
  In production, this would:
  1. Write code to temp file
  2. Compile the module
  3. Use `:code.load_file/1` to load the .beam file
  4. Call `:code.soft_purge/1` on old version

  ## Examples

      iex> {:ok, version_id} = CodeValidator.hot_reload("/path/to/module.ex")
      iex> is_integer(version_id)
      true
  """
  @spec hot_reload(Path.t()) :: {:ok, integer()} | {:error, String.t()}
  def hot_reload(_path) do
    # Return timestamp as version ID
    # In production, this would load compiled BEAM modules
    {:ok, System.system_time(:millisecond)}
  end
end
