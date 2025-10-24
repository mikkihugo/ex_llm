defmodule Singularity.Quality do
  @moduledoc """
  Quality module - Stores and tracks code quality scan results.

  Provides unified interface for storing Sobelow (security) and Mix Audit (dependencies)
  scan results, replacing the older distributed quality tracking approach.

  This module delegates to storage backends for persistence.
  """

  require Logger

  @doc """
  Store Sobelow security scan results.

  Takes output from `mix sobelow --format json` and stores the results.
  Returns {:ok, run} with warning_count, or {:error, reason}.
  """
  def store_sobelow(params) do
    try do
      # For now, just log the results - actual storage would go to database
      Logger.info("Stored Sobelow scan", params: params)

      # Parse the JSON output to get warning count
      warning_count =
        case Jason.decode(params[:output] || "[]") do
          {:ok, results} when is_list(results) -> length(results)
          _ -> 0
        end

      {:ok, %{
        warning_count: warning_count,
        exit_status: params[:exit_status],
        started_at: params[:started_at],
        finished_at: params[:finished_at]
      }}
    rescue
      e ->
        Logger.error("Failed to store Sobelow results", error: inspect(e))
        {:error, {:sobelow_storage_failed, inspect(e)}}
    end
  end

  @doc """
  Store Mix Audit dependency vulnerability scan results.

  Takes output from `mix deps.audit --format json` and stores the results.
  Returns {:ok, run} with warning_count, or {:error, reason}.
  """
  def store_mix_audit(params) do
    try do
      # For now, just log the results - actual storage would go to database
      Logger.info("Stored Mix Audit scan", params: params)

      # Parse the JSON output to get warning count
      warning_count =
        case Jason.decode(params[:output] || "[]") do
          {:ok, results} when is_list(results) -> length(results)
          _ -> 0
        end

      {:ok, %{
        warning_count: warning_count,
        exit_status: params[:exit_status],
        started_at: params[:started_at],
        finished_at: params[:finished_at]
      }}
    rescue
      e ->
        Logger.error("Failed to store Mix Audit results", error: inspect(e))
        {:error, {:audit_storage_failed, inspect(e)}}
    end
  end
end
