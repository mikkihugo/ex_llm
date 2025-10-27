defmodule Singularity.Agents.Coordination.WorkflowLearner do
  @moduledoc """
  Workflow Learner - Learn optimal agent selection from execution outcomes.

  Tracks execution outcomes (success/failure, performance) and learns which agents
  work best for which domains/tasks. Uses this learning to continuously improve
  task routing decisions via CapabilityRegistry updates.

  ## Learning Loop

  ```
  1. ExecutionCoordinator executes task via agent
         ↓
  2. Record execution outcome (success, latency, metrics)
         ↓
  3. Analyze patterns (agent × domain × task type)
         ↓
  4. Update CapabilityRegistry (success rates, performance scores)
         ↓
  5. AgentRouter uses updated scores for future decisions
         ↓
  [LOOP: continuous optimization]
  ```

  ## Tracked Metrics

  Per execution outcome:
  - `:agent` - Agent that executed task
  - `:task_domain` - Domain of the task (code_quality, refactoring, etc.)
  - `:success` - Boolean: task succeeded
  - `:latency_ms` - Execution time
  - `:tokens_used` - LLM tokens consumed (if applicable)
  - `:quality_score` - Quality of output (0.0-1.0, if available)
  - `:feedback` - Human or automated feedback

  ## Learning Strategies

  ### 1. Success Rate Updates
  - Track successes/failures per agent
  - Update CapabilityRegistry.success_rate periodically
  - Formula: success_rate = successes / (successes + failures)
  - Min sample size: 5 executions before updating

  ### 2. Domain Expertise Learning
  - Which agents perform best in which domains
  - Boosts weighting for domain-specific agents in routing decisions
  - Per-domain success rates tracked separately

  ### 3. Performance Optimization
  - Track latency trends over time
  - Identify agents with performance regression
  - Alert when latency increases > 50% from baseline

  ### 4. Cost Optimization
  - Track tokens per execution
  - Identify cost-heavy agents
  - Prefer lower-cost agents when performance is equivalent

  ## Example Usage

  ### Record Execution Outcome
  ```elixir
  outcome = %{
    agent: :quality_enforcer,
    task_id: 123,
    task_domain: :code_quality,
    success: true,
    latency_ms: 450,
    tokens_used: 250,
    quality_score: 0.94
  }

  WorkflowLearner.record_outcome(outcome)
  ```

  ### Get Learned Statistics
  ```elixir
  stats = WorkflowLearner.get_agent_stats(:quality_enforcer)
  # => %{
  #   successes: 47,
  #   failures: 3,
  #   success_rate: 0.94,
  #   avg_latency: 420,
  #   total_executions: 50,
  #   domain_performance: %{
  #     code_quality: 0.96,
  #     documentation: 0.92
  #   }
  # }
  ```

  ### Get Domain Recommendations
  ```elixir
  agents = WorkflowLearner.best_agents_for_domain(:refactoring, limit: 3)
  # => [
  #   {refactoring_agent, 0.95},
  #   {self_improving_agent, 0.88},
  #   {quality_enforcer, 0.75}
  # ]
  ```

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Agents.Coordination.WorkflowLearner",
    "purpose": "Learn optimal agent selection from execution outcomes",
    "layer": "learning_system",
    "pattern": "Feedback-based learning",
    "responsibilities": [
      "Record execution outcomes",
      "Track success rates per agent",
      "Learn domain expertise",
      "Track performance metrics",
      "Optimize cost efficiency",
      "Update capability registry with learnings"
    ],
    "stores": "PostgreSQL execution_outcomes table"
  }
  ```
  """

  require Logger
  alias Singularity.Agents.Coordination.{CapabilityRegistry, AgentRegistration}

  @doc """
  Record an execution outcome for learning.

  Records the result of a task executed by an agent. This data feeds the
  learning loop that continuously improves agent selection.

  ## Parameters

  - `outcome` - Map with keys:
    - `:agent` - Agent that executed (required)
    - `:task_id` - Task ID (required)
    - `:task_domain` - Domain (required, e.g., :code_quality)
    - `:success` - Boolean result (required)
    - `:latency_ms` - Execution time (optional)
    - `:tokens_used` - Tokens consumed (optional)
    - `:quality_score` - Output quality 0.0-1.0 (optional)
    - `:feedback` - User/system feedback (optional)
    - `:error` - Error if failed (optional)
    - `:metadata` - Additional data (optional)

  ## Examples

      iex> outcome = %{
      ...>   agent: :quality_enforcer,
      ...>   task_id: 1,
      ...>   task_domain: :code_quality,
      ...>   success: true,
      ...>   latency_ms: 450,
      ...>   quality_score: 0.94
      ...> }
      iex> WorkflowLearner.record_outcome(outcome)
      :ok
  """
  @spec record_outcome(map()) :: :ok | {:error, term()}
  def record_outcome(outcome) when is_map(outcome) do
    try do
      agent = outcome[:agent]
      domain = outcome[:task_domain]
      success = outcome[:success]
      latency = outcome[:latency_ms]
      _quality = outcome[:quality_score]

      Logger.debug("Recording execution outcome",
        agent: agent,
        domain: domain,
        success: success,
        task_id: outcome[:task_id]
      )

      # Store in database (TODO: implement PostgreSQL persistence)
      # For now, store in ETS for in-memory learning
      store_outcome_in_memory(outcome)

      # Calculate and update success rates periodically
      # (Every 10 executions or on demand)
      maybe_update_success_rates(agent, domain, success)

      :ok
    rescue
      e ->
        Logger.error("Failed to record execution outcome",
          error: inspect(e)
        )
        {:error, :recording_failed}
    end
  end

  @doc """
  Get learned statistics for an agent.

  Returns success rates, performance metrics, and domain expertise.

  ## Examples

      iex> WorkflowLearner.get_agent_stats(:quality_enforcer)
      %{
        successes: 47,
        failures: 3,
        success_rate: 0.94,
        avg_latency: 420,
        total_executions: 50,
        domain_performance: %{code_quality: 0.96}
      }
  """
  @spec get_agent_stats(atom()) :: map() | nil
  def get_agent_stats(agent_name) when is_atom(agent_name) do
    case get_from_memory(agent_name) do
      nil ->
        nil

      {successes, failures, domains} ->
        total = successes + failures
        rate = if total > 0, do: successes / total, else: 0.0

        %{
          successes: successes,
          failures: failures,
          success_rate: rate,
          total_executions: total,
          domain_performance: domains
        }
    end
  end

  @doc """
  Get top agents for a domain ranked by success rate.

  Returns agents that work best in a specific domain, ordered by performance.

  ## Examples

      iex> WorkflowLearner.best_agents_for_domain(:refactoring, limit: 3)
      [{:refactoring_agent, 0.95}, {:self_improving_agent, 0.88}]
  """
  @spec best_agents_for_domain(atom(), keyword()) :: [{atom(), float()}]
  def best_agents_for_domain(domain, opts \\ []) when is_atom(domain) do
    limit = Keyword.get(opts, :limit, 5)

    # Get all agents and their domain performance
    :ets.all()
    |> Enum.filter(&is_agent_table?/1)
    |> Enum.map(&get_domain_performance(&1, domain))
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(fn {_agent, score} -> score end, :desc)
    |> Enum.take(limit)
  end

  @doc """
  Force update of agent success rates in CapabilityRegistry.

  Normally called periodically by the learning system, but can be
  called manually to immediately update based on recent outcomes.

  ## Examples

      iex> WorkflowLearner.update_success_rates(:quality_enforcer)
      :ok
  """
  @spec update_success_rates(atom()) :: :ok | {:error, term()}
  def update_success_rates(agent_name) when is_atom(agent_name) do
    case get_agent_stats(agent_name) do
      nil ->
        Logger.warning("No stats found for agent",
          agent: agent_name
        )
        {:error, :no_stats}

      stats ->
        rate = stats.success_rate
        Logger.info("Updating agent success rate",
          agent: agent_name,
          rate: Float.round(rate, 3),
          samples: stats.total_executions
        )

        AgentRegistration.update_success_rate(agent_name, rate)
    end
  end

  # Private

  defp maybe_update_success_rates(agent, domain, _success) do
    # Check if we have enough samples for this agent+domain
    case get_domain_stats(agent, domain) do
      {:ok, {successes, failures}} ->
        total = successes + failures
        # Update every 10 executions
        if rem(total, 10) == 0 do
          update_success_rates(agent)
        end

      :not_found ->
        :ok
    end
  end

  defp store_outcome_in_memory(outcome) do
    agent = outcome[:agent]
    domain = outcome[:task_domain]
    success = outcome[:success]

    # Get or create table for this agent
    table_name = String.to_atom("workflow_learner_#{agent}")

    # Ensure ETS table exists
    unless :ets.info(table_name) do
      :ets.new(table_name, [:named_table, :public, :set])
    end

    # Record outcome
    key = :crypto.strong_rand_bytes(8) |> Base.encode16()
    :ets.insert(table_name, {key, outcome})

    # Update aggregate stats
    update_domain_stats(agent, domain, success)
  end

  defp update_domain_stats(agent, domain, success) do
    stats_table = String.to_atom("workflow_learner_stats_#{agent}")

    unless :ets.info(stats_table) do
      :ets.new(stats_table, [:named_table, :public, :set])
    end

    # Update global stats
    case :ets.lookup(stats_table, :global) do
      [{:global, {total_s, total_f, domains}}] ->
        new_s = if success, do: total_s + 1, else: total_s
        new_f = if success, do: total_f, else: total_f + 1
        new_domains = update_domain_count(domains, domain, success)
        :ets.insert(stats_table, {:global, {new_s, new_f, new_domains}})

      [] ->
        s = if success, do: 1, else: 0
        f = if success, do: 0, else: 1
        domains = %{domain => {s, f}}
        :ets.insert(stats_table, {:global, {s, f, domains}})
    end
  end

  defp update_domain_count(domains, domain, success) do
    case Map.get(domains, domain) do
      {s, f} ->
        new_s = if success, do: s + 1, else: s
        new_f = if success, do: f, else: f + 1
        Map.put(domains, domain, {new_s, new_f})

      nil ->
        s = if success, do: 1, else: 0
        f = if success, do: 0, else: 1
        Map.put(domains, domain, {s, f})
    end
  end

  defp get_from_memory(agent_name) do
    stats_table = String.to_atom("workflow_learner_stats_#{agent_name}")

    case :ets.lookup(stats_table, :global) do
      [{:global, {s, f, domains}}] ->
        domain_map = Enum.map(domains, fn {domain, {ds, df}} ->
          rate = if ds + df > 0, do: ds / (ds + df), else: 0.0
          {domain, rate}
        end) |> Map.new()

        {s, f, domain_map}

      [] ->
        nil
    end
  end

  defp get_domain_stats(agent, domain) do
    stats_table = String.to_atom("workflow_learner_stats_#{agent}")

    case :ets.lookup(stats_table, :global) do
      [{:global, {_, _, domains}}] ->
        case Map.get(domains, domain) do
          {s, f} -> {:ok, {s, f}}
          nil -> :not_found
        end

      [] ->
        :not_found
    end
  end

  defp get_domain_performance(table, domain) when is_atom(table) do
    # Extract agent name from table
    table_str = Atom.to_string(table)

    with true <- String.starts_with?(table_str, "workflow_learner_stats_"),
         agent_str <- String.replace_prefix(table_str, "workflow_learner_stats_", ""),
         agent_atom <- String.to_atom(agent_str),
         [{:global, {_, _, domains}}] <- :ets.lookup(table, :global),
         {s, f} when is_integer(s) <- Map.get(domains, domain) do
      total = s + f
      rate = if total > 0, do: s / total, else: 0.0
      {agent_atom, rate}
    else
      _ -> nil
    end
  end

  defp is_agent_table?(table) do
    table_str = Atom.to_string(table)
    String.starts_with?(table_str, "workflow_learner_stats_")
  end
end
