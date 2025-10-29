defmodule Singularity.Engine.NifLoader do
  @moduledoc """
  Unified NIF loader for all Rust engines.

  Centralizes NIF loading, health checks, and error handling for:
  - parser_engine (polyglot parser)
  - code_quality_engine (code analysis)
  - linting_engine (linting & quality gates)
  - embedding_engine (vector embeddings)
  - prompt_engine (prompt optimization)

  ## Architecture

  Each engine module still uses `use Rustler` to define its NIF interface,
  but this module provides centralized:
  - Health monitoring
  - Load status tracking
  - Error aggregation
  - Diagnostics

  ## Usage

      iex> NifLoader.health_check_all()
      %{
        parser_engine: :ok,
        code_quality_engine: :ok,
        ...
      }

      iex> NifLoader.loaded?(:parser_engine)
      true
  """

  require Logger

  @type nif_name ::
          :parser_engine
          | :code_quality_engine
          | :linting_engine
          | :embedding_engine
          | :prompt_engine
  @type health_status :: :ok | {:error, term()}

  # Map of NIF name to its Elixir module
  @nif_modules %{
    parser_engine: Singularity.ParserEngine,
    code_quality_engine: Singularity.CodeAnalyzer.Native,
    linting_engine: Singularity.LintingEngine,
    embedding_engine: Singularity.EmbeddingEngine,
    prompt_engine: Singularity.PromptEngine.Native
  }

  # Health check functions per NIF (optional, module must export these)
  @health_check_functions %{
        parser_engine: :supported_languages,
        code_quality_engine: :supported_languages,
        embedding_engine: :health_check
  }

  @doc """
  List all registered NIF engines.
  """
  @spec all_nifs() :: [nif_name()]
  def all_nifs, do: Map.keys(@nif_modules)

  @doc """
  Get the Elixir module for a NIF.
  """
  @spec module_for(nif_name()) :: module() | nil
  def module_for(nif_name), do: Map.get(@nif_modules, nif_name)

  @doc """
  Check if a NIF is loaded by attempting to call a known function.

  Returns true if the NIF responds without :nif_not_loaded error.
  """
  @spec loaded?(nif_name()) :: boolean()
  def loaded?(nif_name) do
    case health_check(nif_name) do
      :ok -> true
      {:ok, _} -> true
      {:error, :nif_not_loaded} -> false
      # Assume loaded if no health check defined
      {:error, :no_health_check} -> true
      # Loaded but has other errors
      {:error, _} -> true
    end
  end

  @doc """
  Perform health check on a specific NIF.

  Returns:
  - `:ok` if NIF is loaded and responding
  - `{:ok, result}` if NIF returns data
  - `{:error, :nif_not_loaded}` if NIF not loaded
  - `{:error, :no_health_check}` if no health check function defined
  - `{:error, reason}` for other errors
  """
  @spec health_check(nif_name()) :: health_status()
  def health_check(nif_name) do
    module = module_for(nif_name)

    if module == nil do
      {:error, :unknown_nif}
    else
      health_fn = Map.get(@health_check_functions, nif_name)

      if health_fn do
        try do
          result = apply(module, health_fn, [])
          {:ok, result}
        rescue
          ErlangError ->
            {:error, :nif_not_loaded}

          error ->
            {:error, error}
        end
      else
        {:error, :no_health_check}
      end
    end
  end

  @doc """
  Check health of all NIFs.

  Returns a map of nif_name => health_status.
  """
  @spec health_check_all() :: %{nif_name() => health_status()}
  def health_check_all do
    all_nifs()
    |> Enum.map(fn nif -> {nif, health_check(nif)} end)
    |> Enum.into(%{})
  end

  @doc """
  Get summary of all NIFs with load status.

  Returns list of maps with:
  - name: NIF identifier
  - module: Elixir module
  - loaded: boolean
  - health: health status
  """
  @spec summary() :: [map()]
  def summary do
    all_nifs()
    |> Enum.map(fn nif ->
      health = health_check(nif)

      %{
        name: nif,
        module: module_for(nif),
        loaded: loaded?(nif),
        health: health,
        # Rust crate name matches NIF name
        crate: nif
      }
    end)
  end

  @doc """
  Pretty-print NIF status for debugging.
  """
  @spec print_status() :: :ok
  def print_status do
    IO.puts("\n=== Singularity Rust NIF Status ===\n")

    summary()
    |> Enum.each(fn info ->
      status = if info.loaded, do: "✅ LOADED", else: "❌ NOT LOADED"
      IO.puts("#{status} - #{info.name}")
      IO.puts("  Module: #{inspect(info.module)}")
      IO.puts("  Crate: #{info.crate}")
      IO.puts("  Health: #{inspect(info.health)}")
      IO.puts("")
    end)

    :ok
  end

  @doc """
  Log NIF status on startup.
  """
  def log_startup_status do
    summary = summary()
    loaded_count = Enum.count(summary, & &1.loaded)
    total_count = length(summary)

    Logger.info("NIF Loader: #{loaded_count}/#{total_count} NIFs loaded successfully")

    summary
    |> Enum.filter(&(not &1.loaded))
    |> Enum.each(fn info ->
      Logger.warning("NIF not loaded: #{info.name} (#{inspect(info.health)})")
    end)

    :ok
  end
end
