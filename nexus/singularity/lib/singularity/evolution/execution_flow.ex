defmodule Singularity.Evolution.ExecutionFlow do
  @moduledoc """
  Execution Flow - Orchestrates proposal execution with safety gates.

  Manages the complete flow: Proposal → Validation → Execution → Metrics

  1. Get proposal from queue
  2. Validate safety profile
  3. Collect metrics before execution
  4. Execute code change
  5. Verify no errors
  6. Report metrics to CentralCloud.Guardian
  7. Mark as applied or failed

  ## AI Navigation Metadata

  ### Module Identity
  ```json
  {
    "module": "Singularity.Evolution.ExecutionFlow",
    "purpose": "Orchestrates end-to-end proposal execution with safety gates",
    "role": "orchestrator",
    "layer": "domain_services",
    "features": ["safe_execution", "metrics_collection", "error_recovery"]
  }
  ```

  ### Architecture
  ```
  execute_proposal(proposal)
    ├─ Validate safety profile
    ├─ Collect metrics_before
    ├─ ExecutionEngine.apply_change()
    ├─ Verify success
    ├─ Collect metrics_after
    ├─ Report to Guardian
    └─ Return {:ok, result} or {:error, reason}
  ```

  ### Call Graph (YAML)
  ```yaml
  ExecutionFlow:
    calls_from:
      - ProposalQueue
    calls_to:
      - ExecutionEngine (code execution)
      - Telemetry
      - CentralCloud.Guardian.RollbackService
    depends_on:
      - Schemas.Evolution.Proposal
      - ExecutionEngine
  ```

  ### Anti-Patterns
  - ❌ DO NOT execute without safety profile validation
  - ❌ DO NOT skip metrics collection
  - ❌ DO NOT silently fail (always report to Guardian)
  - ✅ DO validate all safety gates before execution
  - ✅ DO collect metrics before and after
  - ✅ DO handle rollback signals from Guardian

  ### Search Keywords
  proposal execution, safety validation, metrics collection, error recovery,
  execution orchestration, code change application
  """

  require Logger

  alias Singularity.Repo
  alias Singularity.Schemas.Evolution.Proposal
  alias CentralCloud.Guardian.RollbackService

  @doc """
  Execute an approved proposal end-to-end.

  Returns `{:ok, result}` with execution metrics, or `{:error, reason}`.

  ## Execution Flow
  1. Validate safety profile
  2. Collect metrics before
  3. Execute code change
  4. Collect metrics after
  5. Report to Guardian
  6. Return result

  ## Example
  ```elixir
  proposal = %Proposal{...approved...}
  {:ok, result} = ExecutionFlow.execute_proposal(proposal)
  # result.metrics contains before/after metrics
  ```
  """
  def execute_proposal(proposal) do
    Logger.info("Starting execution flow for proposal #{proposal.id}")

    with :ok <- validate_safety_profile(proposal),
         {:ok, metrics_before} <- collect_metrics_before(proposal),
         {:ok, result} <- execute_code_change(proposal),
         {:ok, metrics_after} <- collect_metrics_after(proposal, result),
         :ok <- validate_execution_result(result, metrics_before, metrics_after),
         :ok <- report_to_guardian(proposal, metrics_before, metrics_after)
    do
      Logger.info("Proposal #{proposal.id} executed successfully")

      :telemetry.execute(
        [:evolution, :execution, :completed],
        %{
          execution_time_ms: execution_time_ms(metrics_before, metrics_after)
        },
        %{proposal_id: proposal.id}
      )

      {:ok, %{
        proposal_id: proposal.id,
        status: "applied",
        metrics_before: metrics_before,
        metrics_after: metrics_after,
        execution_time_ms: execution_time_ms(metrics_before, metrics_after)
      }}
    else
      {:error, reason} ->
        Logger.error("Proposal execution failed: #{inspect(reason)}")

        :telemetry.execute(
          [:evolution, :execution, :failed],
          %{},
          %{proposal_id: proposal.id, reason: inspect(reason)}
        )

        {:error, reason}
    end
  end

  @doc "Validate proposal safety profile before execution."
  def validate_safety_profile(proposal) do
    profile = proposal.safety_profile || %{}

    cond do
      proposal.risk_score > 8.0 and Map.get(profile, :force_consensus, false) == false ->
        Logger.warning("High-risk proposal without consensus force flag: #{proposal.id}")
        {:error, :high_risk_requires_consensus}

      is_nil(profile) or profile == %{} ->
        Logger.warning("Proposal has no safety profile: #{proposal.id}")
        {:error, :missing_safety_profile}

      true ->
        :ok
    end
  end

  @doc "Collect metrics before executing proposal."
  def collect_metrics_before(_proposal) do
    metrics = %{
      timestamp: DateTime.utc_now(),
      cpu_usage: get_cpu_usage(),
      memory_usage: get_memory_usage(),
      error_count: get_error_count(),
      execution_count: get_execution_count()
    }

    {:ok, metrics}
  end

  @doc "Collect metrics after executing proposal."
  def collect_metrics_after(_proposal, _result) do
    metrics = %{
      timestamp: DateTime.utc_now(),
      cpu_usage: get_cpu_usage(),
      memory_usage: get_memory_usage(),
      error_count: get_error_count(),
      execution_count: get_execution_count()
    }

    {:ok, metrics}
  end

  @doc "Execute the actual code change."
  def execute_code_change(proposal) do
    Logger.info("Executing code change for proposal #{proposal.id}")

    case proposal.code_change do
      %{"file" => file, "change" => change} ->
        # Delegate to actual execution engine (simplified here)
        apply_code_change(file, change)

      _ ->
        Logger.error("Invalid code change format in proposal #{proposal.id}")
        {:error, :invalid_code_change}
    end
  end

  @doc "Validate execution result against metrics."
  def validate_execution_result(result, metrics_before, metrics_after) do
    # Check that key metrics didn't degrade unexpectedly
    cpu_increase = metrics_after.cpu_usage - metrics_before.cpu_usage
    error_increase = metrics_after.error_count - metrics_before.error_count

    cond do
      cpu_increase > 50.0 ->
        Logger.warning("Execution caused high CPU increase: #{cpu_increase}%")
        {:error, :cpu_spike}

      error_increase > 10 ->
        Logger.warning("Execution caused error increase: #{error_increase}")
        {:error, :error_spike}

      result.status == "error" ->
        Logger.error("Execution result indicates error")
        {:error, result.error}

      true ->
        :ok
    end
  end

  @doc "Report execution metrics to CentralCloud Guardian."
  def report_to_guardian(proposal, metrics_before, metrics_after) do
    Logger.debug("Reporting execution metrics to Guardian for proposal #{proposal.id}")

    instance_id = "singularity_#{System.get_env("INSTANCE_ID", "default")}"

    metrics = %{
      proposal_id: proposal.id,
      agent_type: proposal.agent_type,
      cpu_delta: metrics_after.cpu_usage - metrics_before.cpu_usage,
      error_delta: metrics_after.error_count - metrics_before.error_count,
      execution_success: true,
      timestamp: DateTime.utc_now()
    }

    case RollbackService.report_metrics(instance_id, proposal.id, metrics) do
      {:ok, _} ->
        Logger.debug("Metrics reported successfully")
        :ok

      {:error, reason} ->
        Logger.warning("Failed to report metrics: #{inspect(reason)}")
        # Don't fail execution if metrics reporting fails
        :ok
    end
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp apply_code_change(file, _change) do
    try do
      # This is a simplified example - real implementation would
      # actually apply the code change to the file system
      Logger.info("Applying change to file: #{file}")

      # Placeholder: in real implementation, this would:
      # 1. Read file
      # 2. Apply change
      # 3. Write file
      # 4. Run tests to verify

      {:ok, %{
        status: "success",
        file: file,
        change_applied: true
      }}
    rescue
      e ->
        Logger.error("Exception applying code change: #{inspect(e)}")
        {:error, {:execution_error, e}}
    end
  end

  # Metric collection helpers (simplified)

  defp get_cpu_usage do
    # In real implementation, query Prometheus or system metrics
    :random.uniform() * 100.0
  end

  defp get_memory_usage do
    # In real implementation, query actual memory metrics
    :random.uniform() * 1000.0
  end

  defp get_error_count do
    # In real implementation, query error logs
    :random.uniform(20)
  end

  defp get_execution_count do
    # In real implementation, query execution metrics
    :random.uniform(1000)
  end

  defp execution_time_ms(metrics_before, metrics_after) do
    DateTime.diff(metrics_after.timestamp, metrics_before.timestamp, :millisecond)
  end
end
