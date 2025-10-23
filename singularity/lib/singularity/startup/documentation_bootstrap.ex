defmodule Singularity.Startup.DocumentationBootstrap do
  @moduledoc """
  Documentation Bootstrap - Automatically starts documentation system on startup.

  This module ensures the documentation system is properly initialized and
  can run automatically when Singularity starts up.

  ## Overview

  - Starts documentation agents if not already running
  - Enables quality gates for new files
  - Schedules automatic documentation upgrades
  - Provides health check for documentation system

  ## Public API

  - `bootstrap_documentation_system/0` - Initialize documentation system
  - `check_documentation_health/0` - Check if documentation system is healthy
  - `enable_automatic_upgrades/0` - Enable automatic documentation upgrades
  """

  require Logger
  alias Singularity.Agents.DocumentationPipeline
  alias Singularity.Agents.QualityEnforcer
  alias Singularity.Agents.DocumentationUpgrader

  @doc """
  Bootstrap the documentation system on startup.
  """
  def bootstrap_documentation_system do
    Logger.info("Bootstrapping documentation system...")

    with :ok <- ensure_agents_started(),
         :ok <- enable_quality_gates(),
         :ok <- schedule_automatic_upgrades() do
      Logger.info("✅ Documentation system bootstrapped successfully")
      :ok
    else
      {:error, reason} ->
        Logger.error("Failed to bootstrap documentation system: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Check if documentation system is healthy.
  """
  def check_documentation_health do
    try do
      with {:ok, _status} <- DocumentationPipeline.get_pipeline_status(),
           {:ok, _report} <- QualityEnforcer.get_quality_report() do
        :healthy
      else
        {:error, reason} ->
          {:unhealthy, reason}
      end
    rescue
      error ->
        {:unhealthy, error}
    end
  end

  @doc """
  Enable automatic documentation upgrades.
  """
  def enable_automatic_upgrades do
    case DocumentationPipeline.schedule_automatic_upgrades(60) do
      :ok ->
        Logger.info("Automatic documentation upgrades enabled (every 60 minutes)")
        :ok
      {:error, reason} ->
        Logger.error("Failed to enable automatic upgrades: #{inspect(reason)}")
        {:error, reason}
    end
  end

  ## Private Functions

  defp ensure_agents_started do
    agents = [
      {DocumentationUpgrader, "DocumentationUpgrader"},
      {QualityEnforcer, "QualityEnforcer"},
      {DocumentationPipeline, "DocumentationPipeline"}
    ]

    agents
    |> Enum.reduce(:ok, fn {agent, name}, acc ->
      case agent.start_link() do
        {:ok, _pid} ->
          Logger.debug("Started #{name}")
          acc
        {:error, {:already_started, _pid}} ->
          Logger.debug("#{name} already started")
          acc
        {:error, reason} ->
          Logger.error("Failed to start #{name}: #{inspect(reason)}")
          {:error, reason}
      end
    end)
  end

  defp enable_quality_gates do
    case QualityEnforcer.enable_quality_gates() do
      :ok ->
        Logger.info("Quality gates enabled")
        :ok
      {:error, reason} ->
        Logger.error("Failed to enable quality gates: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp schedule_automatic_upgrades do
    case DocumentationPipeline.schedule_automatic_upgrades(60) do
      :ok ->
        Logger.info("Automatic documentation upgrades scheduled (every 60 minutes)")
        :ok
      {:error, reason} ->
        Logger.error("Failed to schedule automatic upgrades: #{inspect(reason)}")
        {:error, reason}
    end
  end
end