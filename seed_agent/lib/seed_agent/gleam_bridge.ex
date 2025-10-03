defmodule SeedAgent.GleamBridge do
  @moduledoc """
  Wrapper around Gleam modules to keep hot reload logic decoupled from Elixir runtime.
  """
  require Logger

  @validator :seed_improver

  @spec validate(binary()) :: :ok | {:error, term()}
  def validate(code) when is_binary(code) do
    ensure_loaded()

    case apply(@validator, :validate, [code]) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
      other -> {:error, {:unexpected_response, other}}
    end
  rescue
    error ->
      {:error, error}
  end

  def validate(_), do: {:error, :missing_code}

  @spec hot_reload(String.t()) :: {:ok, non_neg_integer()} | {:error, term()}
  def hot_reload(active_path) do
    ensure_loaded()

    case apply(@validator, :hot_reload, [active_path]) do
      {:ok, version} -> {:ok, version}
      {:error, reason} -> {:error, reason}
      other -> {:error, {:unexpected_response, other}}
    end
  rescue
    error ->
      Logger.error("Gleam hot reload failed", error: inspect(error))
      {:error, error}
  end

  defp ensure_loaded do
    case :code.ensure_loaded(@validator) do
      {:module, _} -> :ok
      {:error, :nofile} ->
        Logger.warning("Gleam module :seed_improver not yet compiled")
        :ok
      other -> other
    end
  end
end
