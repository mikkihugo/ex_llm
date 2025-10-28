defmodule Singularity.ApplicationMemoryEfficient do
  @moduledoc """
  Memory-efficient version of Singularity.Application for resource-constrained environments.

  Starts processes in stages to reduce memory pressure during startup.
  """

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    # Create ETS table for runner executions
    :ets.new(:runner_executions, [:named_table, :public, :set])

    # Stage 1: Essential foundation only
    stage1_children = [
      # Layer 1: Foundation - Database and metrics MUST start first
      Singularity.Repo,
      Singularity.Infrastructure.Telemetry,
      Singularity.ProcessRegistry
    ]

    Logger.info("Starting Singularity Stage 1 (Foundation)",
      child_count: length(stage1_children),
      environment: Mix.env()
    )

    # Start Stage 1
    case Supervisor.start_link(stage1_children, strategy: :one_for_one) do
      {:ok, supervisor} ->
        Logger.info("Stage 1 started successfully, starting Stage 2 in 2 seconds...")

        # Start Stage 2 after a delay
        Process.send_after(self(), :start_stage2, 2000)

        {:ok, supervisor}

      error ->
        Logger.error("Failed to start Stage 1", error: error)
        error
    end
  end

  def handle_info(:start_stage2, state) do
    # Stage 2: Infrastructure services
    stage2_children = [
      Singularity.Infrastructure.Supervisor,
      Singularity.Tools.ProviderToolkitBootstrapper
    ]

    Logger.info("Starting Singularity Stage 2 (Infrastructure)",
      child_count: length(stage2_children)
    )

    # Start Stage 2 children
    for child <- stage2_children do
      case Supervisor.start_child(state, child) do
        {:ok, _} ->
          Logger.debug("Started child: #{inspect(child)}")

        error ->
          Logger.warning("Failed to start child: #{inspect(child)}, error: #{inspect(error)}")
      end
    end

    # Schedule Stage 3
    Process.send_after(self(), :start_stage3, 3000)
    {:noreply, state}
  end

  def handle_info(:start_stage3, state) do
    # Stage 3: Core domain services
    stage3_children = [
      Singularity.LLM.Supervisor,
      Singularity.Architecture.InfrastructureRegistryCache,
      Singularity.Agents.DocumentationPipeline
    ]

    Logger.info("Starting Singularity Stage 3 (Domain Services)",
      child_count: length(stage3_children)
    )

    # Start Stage 3 children
    for child <- stage3_children do
      case Supervisor.start_child(state, child) do
        {:ok, _} ->
          Logger.debug("Started child: #{inspect(child)}")

        error ->
          Logger.warning("Failed to start child: #{inspect(child)}, error: #{inspect(error)}")
      end
    end

    # Schedule Stage 4
    Process.send_after(self(), :start_stage4, 3000)
    {:noreply, state}
  end

  def handle_info(:start_stage4, state) do
    # Stage 4: Agents and execution (most memory-intensive)
    stage4_children = [
      Singularity.Agents.Supervisor,
      Singularity.ApplicationSupervisor
    ]

    Logger.info("Starting Singularity Stage 4 (Agents & Execution)",
      child_count: length(stage4_children)
    )

    # Start Stage 4 children
    for child <- stage4_children do
      case Supervisor.start_child(state, child) do
        {:ok, _} ->
          Logger.debug("Started child: #{inspect(child)}")

        error ->
          Logger.warning("Failed to start child: #{inspect(child)}, error: #{inspect(error)}")
      end
    end

    # Schedule Stage 5
    Process.send_after(self(), :start_stage5, 2000)
    {:noreply, state}
  end

  def handle_info(:start_stage5, state) do
    # Stage 5: Optional services
    stage5_children = [
      Singularity.Autonomy.RuleEngine,
      Singularity.ArchitectureEngine.MetaRegistry.Supervisor,
      Singularity.Git.Supervisor
    ]

    Logger.info("Starting Singularity Stage 5 (Optional Services)",
      child_count: length(stage5_children)
    )

    # Start Stage 5 children
    for child <- stage5_children do
      case Supervisor.start_child(state, child) do
        {:ok, _} ->
          Logger.debug("Started child: #{inspect(child)}")

        error ->
          Logger.warning("Failed to start child: #{inspect(child)}, error: #{inspect(error)}")
      end
    end

    Logger.info("🎉 Singularity startup complete! All stages started successfully.")
    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.debug("Received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end
end
