defmodule Singularity.Evolution.ProposalQueue do
  @moduledoc """
  Change Proposal Queue - Per-instance proposal management with priority scoring.

  Manages the lifecycle of code change proposals from agents:
  1. Collects proposals locally
  2. Prioritizes by impact/cost/risk/success_rate
  3. Sends to CentralCloud for consensus voting
  4. Executes approved proposals
  5. Reports metrics to CentralCloud Guardian

  ## AI Navigation Metadata

  ### Module Identity
  ```json
  {
    "module": "Singularity.Evolution.ProposalQueue",
    "purpose": "Manages per-instance change proposal queue with priority scoring",
    "role": "service",
    "layer": "domain_services",
    "features": ["proposal_queueing", "priority_scoring", "consensus_coordination"]
  }
  ```

  ### Architecture
  ```
  Agents
    ↓ (submit_proposal)
  ProposalQueue (GenServer)
    ├─ ETS cache (proposals_ets)
    ├─ DB fallback (proposals table)
    └─ Priority queue (sorted by score)
    ↓ (next_proposal)
  ProposalSelector (returns highest priority)
    ↓ (send_for_consensus)
  CentralCloud.Consensus.Engine (voting)
    ↓ (apply_if_consensus_reached)
  ExecutionFlow (execute code change)
    ↓ (report_metrics)
  CentralCloud.Guardian (metrics tracking)
  ```

  ### Call Graph (YAML)
  ```yaml
  ProposalQueue:
    calls_from:
      - AgentCoordinator.propose_change
    calls_to:
      - Repo (ECS.Repo)
      - ExecutionFlow.execute_proposal
      - CentralCloud.Consensus.Engine
      - Telemetry
    depends_on:
      - Schemas.Evolution.Proposal
      - ExecutionFlow
    provides_to:
      - Agents (via AgentCoordinator)
  ```

  ### Anti-Patterns
  - ❌ DO NOT submit proposals without agent_id
  - ❌ DO NOT bypass priority scoring
  - ❌ DO NOT assume CentralCloud is always available (graceful degradation)
  - ✅ DO use AgentCoordinator.propose_change for submission
  - ✅ DO check proposal status before assuming approval
  - ✅ DO handle consensus timeout gracefully

  ### Search Keywords
  change proposal queue, proposal lifecycle, priority scoring, consensus voting,
  proposal prioritization, evolution orchestration, code change management

  ## Usage

  ```elixir
  # Submit a proposal from an agent
  {:ok, proposal} = ProposalQueue.submit_proposal(
    "QualityCodeGenerator",
    %{file: "lib/foo.ex", change: "refactored function"},
    agent_id: "qcg_001",
    impact_score: 8.0,
    risk_score: 2.0,
    safety_profile: %{success_rate: 0.95}
  )

  # Get next highest-priority proposal
  {:ok, proposal} = ProposalQueue.next_proposal()

  # Send for consensus voting
  {:ok, proposal} = ProposalQueue.send_for_consensus(proposal.id)

  # Check status
  status = ProposalQueue.get_status(proposal.id)

  # Apply approved proposal
  {:ok, result} = ProposalQueue.apply_proposal(proposal.id)
  ```

  ## Proposal States

  ```
  pending
    ↓ (send_for_consensus)
  sent_for_consensus
    ├→ consensus_reached (2/3+ votes, 85%+ confidence)
    │  ↓ (execute_proposal)
    │  executing → applied OR failed
    │           → rolled_back (if Guardian detects issues)
    │
    └→ consensus_failed (not enough votes)
  ```
  """

  use GenServer
  require Logger
  import Ecto.Query

  alias Singularity.Repo
  alias Singularity.Schemas.Evolution.Proposal
  alias Singularity.Evolution.{ExecutionFlow, ProposalScorer}
  alias CentralCloud.Consensus.Engine, as: ConsensusEngine
  alias CentralCloud.Guardian.RollbackService

  # ETS table for fast lookups
  @ets_table :evolution_proposals_cache

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Create ETS table for fast proposal lookups
    :ets.new(@ets_table, [
      :set,
      :named_table,
      :public,
      read_concurrency: true,
      write_concurrency: true
    ])

    # Start background jobs
    schedule_consensus_check()
    schedule_metrics_batch()

    {:ok, %{
      pending_consensus: [],
      executing: [],
      last_metrics_batch: DateTime.utc_now()
    }}
  end

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Submit a new proposal from an agent.

  Returns `{:ok, proposal}` or `{:error, reason}`.

  ## Options
  - `:agent_id` - Agent identifier
  - `:metadata` - Additional metadata (map)
  - `:safety_profile` - Safety thresholds (map)
  - `:impact_score` - 1-10 impact score (default: 5.0)
  - `:risk_score` - 1-10 risk score (default: 5.0)
  - `:consensus_required` - Whether consensus is required (default: true)

  ## Example
  ```elixir
  {:ok, proposal} = ProposalQueue.submit_proposal(
    "RefactoringAgent",
    %{file: "lib/foo.ex", change: "extract method"},
    agent_id: "refactor_001",
    impact_score: 6.0,
    risk_score: 2.0
  )
  ```
  """
  def submit_proposal(agent_type, code_change, opts \\ []) do
    GenServer.call(__MODULE__, {:submit_proposal, agent_type, code_change, opts})
  end

  @doc """
  Get the next highest-priority proposal ready for consensus.

  Returns `{:ok, proposal}` or `{:error, :no_proposals}`.
  """
  def next_proposal do
    GenServer.call(__MODULE__, :next_proposal)
  end

  @doc "Send a proposal for consensus voting in CentralCloud."
  def send_for_consensus(proposal_id) do
    GenServer.call(__MODULE__, {:send_for_consensus, proposal_id})
  end

  @doc "Check if consensus was reached and apply proposal if approved."
  def check_consensus_result(proposal_id) do
    GenServer.call(__MODULE__, {:check_consensus_result, proposal_id})
  end

  @doc """
  Apply an approved proposal (execute the code change).

  Returns `{:ok, result}` with execution metrics, or `{:error, reason}`.
  """
  def apply_proposal(proposal_id) do
    GenServer.call(__MODULE__, {:apply_proposal, proposal_id})
  end

  @doc "Get current status of a proposal."
  def get_status(proposal_id) do
    case :ets.lookup(@ets_table, proposal_id) do
      [{^proposal_id, proposal}] ->
        {:ok, proposal.status}

      [] ->
        case Repo.get(Proposal, proposal_id) do
          %Proposal{status: status} -> {:ok, status}
          nil -> {:error, :not_found}
        end
    end
  end

  @doc "Get a proposal by ID."
  def get_proposal(proposal_id) do
    case :ets.lookup(@ets_table, proposal_id) do
      [{^proposal_id, proposal}] ->
        {:ok, proposal}

      [] ->
        Repo.get(Proposal, proposal_id)
    end
  end

  @doc "List all pending proposals (not yet sent for consensus)."
  def list_pending do
    Repo.all(
      from p in Proposal,
      where: p.status == "pending",
      order_by: [desc: p.priority_score, asc: p.created_at]
    )
  end

  @doc "List proposals awaiting consensus result."
  def list_awaiting_consensus do
    Repo.all(
      from p in Proposal,
      where: p.status == "sent_for_consensus",
      order_by: [asc: p.consensus_sent_at]
    )
  end

  @doc "List executing proposals."
  def list_executing do
    Repo.all(
      from p in Proposal,
      where: p.status == "executing",
      order_by: [asc: p.execution_started_at]
    )
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl true
  def handle_call({:submit_proposal, agent_type, code_change, opts}, _from, state) do
    Logger.info("Submitting proposal from #{agent_type}")

    changeset = Proposal.new_proposal(agent_type, code_change, opts)

    case Repo.insert(changeset) do
      {:ok, proposal} ->
        # Recalculate and cache priority
        proposal = ProposalScorer.score_proposal(proposal)

        case Repo.update(Proposal.changeset(proposal, %{priority_score: proposal.priority_score})) do
          {:ok, updated_proposal} ->
            :ets.insert(@ets_table, {updated_proposal.id, updated_proposal})

            :telemetry.execute(
              [:evolution, :proposal, :submitted],
              %{priority_score: updated_proposal.priority_score},
              %{agent_type: agent_type}
            )

            {:reply, {:ok, updated_proposal}, state}

          {:error, reason} ->
            Logger.error("Failed to update proposal priority: #{inspect(reason)}")
            {:reply, {:ok, proposal}, state}
        end

      {:error, reason} ->
        Logger.error("Failed to insert proposal: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:next_proposal, _from, state) do
    # Get highest priority pending proposal
    pending = list_pending()

    case pending do
      [proposal | _] ->
        Logger.info("Selected proposal #{proposal.id} (priority: #{proposal.priority_score})")
        {:reply, {:ok, proposal}, state}

      [] ->
        {:reply, {:error, :no_proposals}, state}
    end
  end

  @impl true
  def handle_call({:send_for_consensus, proposal_id}, _from, state) do
    Logger.info("Sending proposal #{proposal_id} for consensus")

    case get_proposal(proposal_id) do
      {:ok, proposal} when is_struct(proposal) ->
        # Mark as sent
        proposal = Proposal.mark_sent_for_consensus(proposal)

        case Repo.update(proposal) do
          {:ok, updated} ->
            :ets.insert(@ets_table, {updated.id, updated})

            # Send to CentralCloud (fire and forget with timeout handling)
            Task.Supervisor.start_child(
              Singularity.TaskSupervisor,
              fn -> broadcast_to_consensus(updated) end
            )

            :telemetry.execute(
              [:evolution, :proposal, :sent_for_consensus],
              %{},
              %{proposal_id: proposal_id}
            )

            {:reply, {:ok, updated}, state}

          {:error, reason} ->
            Logger.error("Failed to mark proposal as sent: #{inspect(reason)}")
            {:reply, {:error, reason}, state}
        end

      nil ->
        {:reply, {:error, :not_found}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:check_consensus_result, proposal_id}, _from, state) do
    Logger.debug("Checking consensus result for #{proposal_id}")

    case get_proposal(proposal_id) do
      {:ok, proposal} when is_struct(proposal) ->
        case proposal.status do
          "consensus_reached" ->
            # Execute approved proposal
            Logger.info("Consensus reached for #{proposal_id}, executing")
            execute_proposal(proposal, state)

          "consensus_failed" ->
            Logger.warning("Consensus failed for #{proposal_id}")
            {:reply, {:error, :consensus_rejected}, state}

          "sent_for_consensus" ->
            {:reply, {:error, :consensus_pending}, state}

          _ ->
            {:reply, {:ok, proposal.status}, state}
        end

      nil ->
        {:reply, {:error, :not_found}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:apply_proposal, proposal_id}, _from, state) do
    Logger.info("Applying proposal #{proposal_id}")

    case get_proposal(proposal_id) do
      {:ok, proposal} when is_struct(proposal) ->
        execute_proposal(proposal, state)

      nil ->
        {:reply, {:error, :not_found}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_info(:check_consensus, state) do
    # Periodically check proposals awaiting consensus
    awaiting = list_awaiting_consensus()

    Enum.each(awaiting, fn proposal ->
      Task.Supervisor.start_child(
        Singularity.TaskSupervisor,
        fn -> check_consensus_from_centralcloud(proposal) end
      )
    end)

    schedule_consensus_check()
    {:noreply, state}
  end

  @impl true
  def handle_info(:batch_metrics, state) do
    # Periodically batch report metrics to CentralCloud
    executing = list_executing()

    Enum.each(executing, fn proposal ->
      Task.Supervisor.start_child(
        Singularity.TaskSupervisor,
        fn -> report_metrics(proposal) end
      )
    end)

    schedule_metrics_batch()
    {:noreply, state}
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp execute_proposal(proposal, state) do
    Logger.info("Executing proposal #{proposal.id}")

    # Mark as executing
    proposal = Proposal.mark_executing(proposal)

    case Repo.update(proposal) do
      {:ok, executing_proposal} ->
        :ets.insert(@ets_table, {executing_proposal.id, executing_proposal})

        :telemetry.execute(
          [:evolution, :proposal, :execution_started],
          %{},
          %{proposal_id: executing_proposal.id, agent_type: executing_proposal.agent_type}
        )

        # Execute in background task
        Task.Supervisor.start_child(
          Singularity.TaskSupervisor,
          fn ->
            case ExecutionFlow.execute_proposal(executing_proposal) do
              {:ok, result} ->
                mark_applied(executing_proposal, result)

              {:error, reason} ->
                Logger.error("Proposal execution failed: #{inspect(reason)}")
                mark_failed(executing_proposal, inspect(reason))
            end
          end
        )

        {:reply, {:ok, executing_proposal}, state}

      {:error, reason} ->
        Logger.error("Failed to mark proposal as executing: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  defp broadcast_to_consensus(proposal) do
    Logger.debug("Broadcasting proposal #{proposal.id} to CentralCloud.Consensus")

    try do
      case ConsensusEngine.propose_change(
        "singularity_#{System.get_env("INSTANCE_ID", "default")}",
        proposal.id,
        proposal.code_change,
        %{
          agent_type: proposal.agent_type,
          impact_score: proposal.impact_score,
          risk_score: proposal.risk_score,
          safety_profile: proposal.safety_profile
        }
      ) do
        {:ok, _} ->
          Logger.info("Proposal sent to consensus successfully")

        {:error, reason} ->
          Logger.error("Failed to send to consensus: #{inspect(reason)}")
      end
    rescue
      e ->
        Logger.error("Exception broadcasting to consensus: #{inspect(e)}")
    end
  end

  defp check_consensus_from_centralcloud(proposal) do
    Logger.debug("Checking consensus result from CentralCloud for #{proposal.id}")

    try do
      # Query CentralCloud for consensus result
      case ConsensusEngine.get_consensus_result(proposal.id) do
        {:ok, %{status: "approved", votes: votes}} ->
          Logger.info("Consensus approved for #{proposal.id}")

          updated = Proposal.mark_consensus_reached(proposal, votes)

          case Repo.update(updated) do
            {:ok, p} ->
              :ets.insert(@ets_table, {p.id, p})

              # Execute approved proposal
              Task.Supervisor.start_child(
                Singularity.TaskSupervisor,
                fn -> ExecutionFlow.execute_proposal(p) end
              )

            {:error, reason} ->
              Logger.error("Failed to update consensus result: #{inspect(reason)}")
          end

        {:ok, %{status: "rejected", votes: votes}} ->
          Logger.warning("Consensus rejected for #{proposal.id}")

          updated = Proposal.mark_consensus_failed(proposal, votes)
          Repo.update(updated)

        {:ok, %{status: "pending"}} ->
          Logger.debug("Consensus still pending for #{proposal.id}")

        {:error, reason} ->
          Logger.error("Error checking consensus: #{inspect(reason)}")
      end
    rescue
      e ->
        Logger.error("Exception checking consensus: #{inspect(e)}")
    end
  end

  defp report_metrics(proposal) do
    Logger.debug("Reporting metrics for executing proposal #{proposal.id}")

    try do
      metrics = collect_proposal_metrics(proposal)

      case RollbackService.report_metrics(
        "singularity_#{System.get_env("INSTANCE_ID", "default")}",
        proposal.id,
        metrics
      ) do
        {:ok, _} ->
          Logger.debug("Metrics reported successfully")

        {:error, reason} ->
          Logger.warning("Failed to report metrics: #{inspect(reason)}")
      end
    rescue
      e ->
        Logger.error("Exception reporting metrics: #{inspect(e)}")
    end
  end

  defp mark_applied(proposal, result) do
    Logger.info("Proposal #{proposal.id} applied successfully")

    updated = Proposal.mark_applied(proposal, result.metrics)

    case Repo.update(updated) do
      {:ok, p} ->
        :ets.insert(@ets_table, {p.id, p})

        :telemetry.execute(
          [:evolution, :proposal, :applied],
          %{},
          %{proposal_id: p.id}
        )

      {:error, reason} ->
        Logger.error("Failed to mark as applied: #{inspect(reason)}")
    end
  end

  defp mark_failed(proposal, error) do
    Logger.error("Proposal #{proposal.id} execution failed: #{error}")

    updated = Proposal.mark_failed(proposal, error)

    case Repo.update(updated) do
      {:ok, p} ->
        :ets.insert(@ets_table, {p.id, p})

        :telemetry.execute(
          [:evolution, :proposal, :failed],
          %{},
          %{proposal_id: p.id, error: error}
        )

      {:error, reason} ->
        Logger.error("Failed to mark as failed: #{inspect(reason)}")
    end
  end

  defp collect_proposal_metrics(proposal) do
    %{
      proposal_id: proposal.id,
      status: proposal.status,
      execution_time_ms: execution_time_ms(proposal),
      agent_type: proposal.agent_type,
      risk_score: proposal.risk_score,
      impact_score: proposal.impact_score
    }
  end

  defp execution_time_ms(proposal) do
    case {proposal.execution_started_at, proposal.execution_completed_at} do
      {started, completed} when not is_nil(started) and not is_nil(completed) ->
        DateTime.diff(completed, started, :millisecond)

      {started, nil} when not is_nil(started) ->
        DateTime.diff(DateTime.utc_now(), started, :millisecond)

      _ ->
        0
    end
  end

  defp schedule_consensus_check do
    Process.send_after(self(), :check_consensus, 5_000)  # Every 5 seconds
  end

  defp schedule_metrics_batch do
    Process.send_after(self(), :batch_metrics, 60_000)  # Every 60 seconds
  end
end
