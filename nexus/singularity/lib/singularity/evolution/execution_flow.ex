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
  alias Singularity.HotReload.ModuleReloader

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

    # Extract execution details from proposal metadata
    metadata = proposal.metadata || %{}
    change_type = metadata["change_type"] || proposal.code_change["type"]
    target_module = metadata["target_module"]
    details = metadata["details"] || %{}

    # Route to appropriate executor based on change type
    case change_type do
      :documentation ->
        execute_documentation_change(proposal, target_module, details)

      :refactoring ->
        execute_refactoring_change(proposal, target_module, details)

      :bug_fix ->
        execute_bug_fix_change(proposal, target_module, details)

      :quality ->
        execute_quality_change(proposal, target_module, details)

      :pattern_adoption ->
        execute_pattern_adoption(proposal, target_module, details)

      _ ->
        # Fallback to generic change application
        apply_generic_code_change(proposal)
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
  # Private Helpers - Specialized Change Executors
  # ============================================================================

  defp execute_documentation_change(proposal, target_module, details) do
    Logger.info("Executing documentation change for proposal #{proposal.id} on module #{target_module}")

    with {:ok, updated_content} <- apply_documentation_change(target_module, details),
         {:ok, validation} <- validate_change_result(updated_content),
         :ok <- dispatch_change(proposal, target_module, updated_content, "documentation") do
      {:ok, %{
        status: "success",
        change_type: "documentation",
        proposal_id: proposal.id,
        target_module: target_module,
        change_applied: true,
        validation: validation
      }}
    else
      error ->
        Logger.error("Documentation change failed: #{inspect(error)}")
        error
    end
  end

  defp execute_refactoring_change(proposal, target_module, details) do
    Logger.info("Executing refactoring change for proposal #{proposal.id} on module #{target_module}")

    with {:ok, updated_content} <- apply_refactoring_change(target_module, details),
         {:ok, validation} <- validate_change_result(updated_content),
         :ok <- dispatch_change(proposal, target_module, updated_content, "refactoring") do
      {:ok, %{
        status: "success",
        change_type: "refactoring",
        proposal_id: proposal.id,
        target_module: target_module,
        change_applied: true,
        validation: validation
      }}
    else
      error ->
        Logger.error("Refactoring change failed: #{inspect(error)}")
        error
    end
  end

  defp execute_bug_fix_change(proposal, target_module, details) do
    Logger.info("Executing bug fix change for proposal #{proposal.id} on module #{target_module}")

    with {:ok, updated_content} <- apply_bug_fix_change(target_module, details),
         {:ok, validation} <- validate_change_result(updated_content),
         :ok <- dispatch_change(proposal, target_module, updated_content, "bug_fix") do
      {:ok, %{
        status: "success",
        change_type: "bug_fix",
        proposal_id: proposal.id,
        target_module: target_module,
        change_applied: true,
        validation: validation
      }}
    else
      error ->
        Logger.error("Bug fix change failed: #{inspect(error)}")
        error
    end
  end

  defp execute_quality_change(proposal, target_module, details) do
    Logger.info("Executing quality improvement change for proposal #{proposal.id} on module #{target_module}")

    with {:ok, updated_content} <- apply_quality_change(target_module, details),
         {:ok, validation} <- validate_change_result(updated_content),
         :ok <- dispatch_change(proposal, target_module, updated_content, "quality") do
      {:ok, %{
        status: "success",
        change_type: "quality",
        proposal_id: proposal.id,
        target_module: target_module,
        change_applied: true,
        validation: validation
      }}
    else
      error ->
        Logger.error("Quality change failed: #{inspect(error)}")
        error
    end
  end

  defp execute_pattern_adoption(proposal, target_module, details) do
    Logger.info("Executing pattern adoption change for proposal #{proposal.id} on module #{target_module}")

    with {:ok, updated_content} <- apply_pattern_adoption_change(target_module, details),
         {:ok, validation} <- validate_change_result(updated_content),
         :ok <- dispatch_change(proposal, target_module, updated_content, "pattern_adoption") do
      {:ok, %{
        status: "success",
        change_type: "pattern_adoption",
        proposal_id: proposal.id,
        target_module: target_module,
        change_applied: true,
        validation: validation
      }}
    else
      error ->
        Logger.error("Pattern adoption change failed: #{inspect(error)}")
        error
    end
  end

  defp apply_generic_code_change(proposal) do
    Logger.info("Applying generic code change for proposal #{proposal.id}")

    code_change = proposal.code_change || %{}
    target_module = code_change["target_module"] || code_change["module"]

    if target_module do
      with {:ok, updated_content} <- apply_code_change_from_map(target_module, code_change),
           {:ok, validation} <- validate_change_result(updated_content),
           :ok <- dispatch_change(proposal, target_module, updated_content, "generic") do
        {:ok, %{
          status: "success",
          change_type: "generic",
          proposal_id: proposal.id,
          target_module: target_module,
          change_applied: true,
          validation: validation
        }}
      else
        error ->
          Logger.error("Generic code change failed: #{inspect(error)}")
          error
      end
    else
      Logger.error("No target module specified for generic code change")
      {:error, :missing_target_module}
    end
  end

  # ============================================================================
  # Change Application Helpers
  # ============================================================================

  defp apply_documentation_change(target_module, details) do
    content = details["content"] || ""
    Logger.debug("Applying documentation content to #{target_module}")
    {:ok, content}
  end

  defp apply_refactoring_change(target_module, details) do
    # For refactoring, apply the structured changes from details
    new_code = details["new_code"] || details["code"] || ""

    Logger.debug("Applying refactoring to #{target_module}")
    {:ok, new_code}
  end

  defp apply_bug_fix_change(target_module, details) do
    # Bug fixes contain the fixed code
    new_code = details["fixed_code"] || details["code"] || ""

    Logger.debug("Applying bug fix to #{target_module}")
    {:ok, new_code}
  end

  defp apply_quality_change(target_module, details) do
    # Quality improvements include formatting, type hints, documentation
    new_code = details["improved_code"] || details["code"] || ""

    Logger.debug("Applying quality improvements to #{target_module}")
    {:ok, new_code}
  end

  defp apply_pattern_adoption_change(target_module, details) do
    # Pattern adoption applies design patterns to code
    new_code = details["refactored_code"] || details["code"] || ""

    Logger.debug("Applying pattern adoption to #{target_module}")
    {:ok, new_code}
  end

  defp apply_code_change_from_map(target_module, code_change) do
    new_code =
      code_change["content"] ||
        code_change["new_code"] ||
        code_change["code"] ||
        ""

    Logger.debug("Applying code change to #{target_module}")
    {:ok, new_code}
  end

  # ============================================================================
  # Change Validation & Dispatch
  # ============================================================================

  defp validate_change_result(content) do
    # Validate the updated code is syntactically valid
    # For now, just check it's not empty
    if is_binary(content) and byte_size(content) > 0 do
      {:ok, %{valid: true, checks: []}}
    else
      {:error, :empty_content}
    end
  end

  defp dispatch_change(proposal, target_module, content, change_type) do
    # Enqueue code change through ModuleReloader for hot reload
    agent_id = "evolution-executor-#{proposal.agent_type}"

    metadata = %{
      proposal_id: proposal.id,
      change_type: change_type,
      target_module: target_module,
      agent_type: proposal.agent_type,
      agent_id: proposal.agent_id,
      source: "evolution_execution_flow"
    }

    payload = %{
      code: content,
      target_module: target_module,
      change_type: change_type,
      proposal_id: proposal.id,
      metadata: metadata
    }

    case ModuleReloader.enqueue(agent_id, payload) do
      :ok ->
        Logger.info("Code change enqueued in ModuleReloader for proposal #{proposal.id}")
        :ok

      {:error, reason} ->
        Logger.error("Failed to enqueue code change: #{inspect(reason)}")
        {:error, {:enqueue_failed, reason}}
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
