defmodule CentralCloud.Evolution.Consensus.Engine do
  @moduledoc """
  Consensus Engine - Multi-instance voting and autonomous change approval.

  The Consensus Engine coordinates distributed voting across Singularity instances
  to approve or reject evolution proposals based on collective intelligence.

  ## Purpose

  This service provides:
  1. **Change Proposal** - Instances propose changes for cross-instance voting
  2. **Distributed Voting** - Instances vote on proposals with confidence scores
  3. **Consensus Computation** - 2/3 majority + 85%+ confidence required
  4. **Auto-Execution** - Approved changes broadcast to all instances
  5. **Audit Trail** - Full vote history for governance analysis

  ## Architecture

  ```mermaid
  graph TD
    A[Instance Proposes Change] --> B[propose_change/4]
    B --> C[Consensus State]
    D[Other Instances] --> E[vote_on_change/4]
    E --> C
    C --> F{Consensus Met?}
    F -->|Yes, 2/3+ votes, 85%+ confidence| G[execute_if_consensus/1]
    G --> H[Broadcast via ex_quantum_flow]
    H --> I[All Instances Apply Change]
    F -->|No| J[Wait for More Votes]
  ```

  ## Consensus Rules

  1. **Minimum Votes**: At least 3 instances must vote
  2. **Majority**: 2/3 (67%) of votes must be "approve"
  3. **Confidence**: Average confidence must be >= 0.85
  4. **No Strong Rejections**: No vote with confidence > 0.90 and vote = "reject"

  If all rules met → Auto-execute change

  ## Module Identity (JSON)
  ```json
  {
    "module_name": "CentralCloud.Evolution.Consensus.Engine",
    "purpose": "distributed_voting_and_autonomous_change_approval",
    "domain": "evolution",
    "layer": "centralcloud",
    "capabilities": [
      "change_proposal",
      "distributed_voting",
      "consensus_computation",
      "auto_execution",
      "ex_quantum_flow_broadcast"
    ],
    "dependencies": [
      "CentralCloud.Repo",
      "QuantumFlow (ex_quantum_flow)",
      "Guardian (safety validation)",
      "Pattern Aggregator (pattern lookup)"
    ]
  }
  ```

  ## Call Graph (YAML)
  ```yaml
  CentralCloud.Evolution.Consensus.Engine:
    propose_change/4:
      - validates change proposal
      - stores in consensus_votes table
      - broadcasts to instances for voting
      - returns proposal_id
    vote_on_change/4:
      - records vote with confidence
      - checks consensus rules
      - triggers execute_if_consensus if met
    execute_if_consensus/1:
      - validates consensus met
      - broadcasts change via ex_quantum_flow
      - marks proposal as executed
      - returns execution_id
  ```

  ## Anti-Patterns

  - **DO NOT** execute changes without 2/3 majority - governance requirement
  - **DO NOT** allow votes after consensus reached - immutable decisions
  - **DO NOT** skip confidence checks - prevent low-quality approvals
  - **DO NOT** broadcast without ex_quantum_flow - durable delivery required
  - **DO NOT** approve with strong rejections - safety override

  ## Search Keywords

  consensus, distributed_voting, multi_instance_coordination, autonomous_approval,
  governance, ex_quantum_flow_broadcast, change_execution, collective_intelligence,
  vote_aggregation, quorum
  """

  use GenServer
  require Logger

  alias CentralCloud.Repo
  alias CentralCloud.Evolution.Consensus.Schemas.ConsensusVote
  alias CentralCloud.Evolution.Guardian.RollbackService
  import Ecto.Query

  # Client API

  @doc """
  Start the Consensus Engine.

  ## Examples

      {:ok, pid} = ConsensusEngine.start_link([])
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Propose a change for cross-instance consensus voting.

  The proposing instance submits a change, which is then broadcast to all other
  instances for voting. Consensus is reached when 2/3 of instances approve with
  85%+ average confidence.

  ## Parameters

  - `instance_id` - Singularity instance proposing the change
  - `change_id` - Unique identifier for this change (must be registered with Guardian first)
  - `code_change` - Map containing:
    - `:change_type` - :pattern_enhancement | :model_optimization | :cache_improvement | :code_refactoring
    - `:description` - What this change does
    - `:affected_agents` - List of agent IDs affected
    - `:before_code` - Code before change
    - `:after_code` - Code after change
  - `metadata` - Map containing:
    - `:expected_improvement` - Expected metric improvement (e.g., "+5% success_rate")
    - `:blast_radius` - :single_agent | :agent_group | :all_agents
    - `:rollback_time_sec` - How long rollback takes
    - `:trial_results` - Results from A/B testing (if available)

  ## Returns

  - `{:ok, proposal_id}` - Proposal created, voting begins
  - `{:error, reason}` - Proposal failed

  ## Examples

      iex> ConsensusEngine.propose_change(
      ...>   "dev-1",
      ...>   "change-uuid-123",
      ...>   %{
      ...>     change_type: :pattern_enhancement,
      ...>     description: "Add error recovery pattern to all GenServers",
      ...>     affected_agents: ["elixir-specialist", "otp-expert"],
      ...>     before_code: "def handle_call...",
      ...>     after_code: "def handle_call with recovery..."
      ...>   },
      ...>   %{
      ...>     expected_improvement: "+8% success_rate",
      ...>     blast_radius: :agent_group,
      ...>     rollback_time_sec: 15,
      ...>     trial_results: %{success_rate: 0.96}
      ...>   }
      ...> )
      {:ok, "proposal-uuid-789"}
  """
  @spec propose_change(String.t(), String.t(), map(), map()) ::
          {:ok, String.t()} | {:error, term()}
  def propose_change(instance_id, change_id, code_change, metadata) do
    GenServer.call(__MODULE__, {:propose_change, instance_id, change_id, code_change, metadata})
  end

  @doc """
  Vote on a proposed change.

  Instances vote "approve" or "reject" with a confidence score. When consensus
  rules are met, the change is automatically executed.

  ## Parameters

  - `instance_id` - Instance casting the vote
  - `change_id` - Change being voted on
  - `vote` - :approve | :reject
  - `reason` - Human-readable explanation for the vote

  ## Returns

  - `{:ok, :voted}` - Vote recorded, waiting for more votes
  - `{:ok, :consensus_reached}` - Vote recorded, consensus met, change executing
  - `{:error, reason}` - Vote failed

  ## Examples

      iex> ConsensusEngine.vote_on_change(
      ...>   "dev-2",
      ...>   "change-uuid-123",
      ...>   :approve,
      ...>   "Pattern improves error handling, trial success rate 96%"
      ...> )
      {:ok, :voted}

      # After 3rd vote with 2/3 approval:
      iex> ConsensusEngine.vote_on_change(
      ...>   "dev-3",
      ...>   "change-uuid-123",
      ...>   :approve,
      ...>   "Consistent with best practices"
      ...> )
      {:ok, :consensus_reached}
  """
  @spec vote_on_change(String.t(), String.t(), atom(), String.t()) ::
          {:ok, :voted | :consensus_reached} | {:error, term()}
  def vote_on_change(instance_id, change_id, vote, reason) do
    GenServer.call(__MODULE__, {:vote_on_change, instance_id, change_id, vote, reason})
  end

  @doc """
  Execute a change if consensus has been reached.

  Checks that consensus rules are met, then broadcasts the change to all instances
  via ex_quantum_flow for synchronized execution.

  ## Parameters

  - `change_id` - Change to execute

  ## Returns

  - `{:ok, execution_id}` - Change executed, broadcast sent
  - `{:error, :consensus_not_reached}` - Not enough votes or confidence
  - `{:error, reason}` - Execution failed

  ## Examples

      iex> ConsensusEngine.execute_if_consensus("change-uuid-123")
      {:ok, "execution-uuid-456"}

      iex> ConsensusEngine.execute_if_consensus("change-uuid-789")
      {:error, :consensus_not_reached}
  """
  @spec execute_if_consensus(String.t()) :: {:ok, String.t()} | {:error, term()}
  def execute_if_consensus(change_id) do
    GenServer.call(__MODULE__, {:execute_if_consensus, change_id})
  end

  # GenServer Callbacks

  @impl true
  def init(_opts) do
    Logger.info("[ConsensusEngine] Starting Consensus Engine")

    state = %{
      proposals: %{},
      votes: %{},
      executed: MapSet.new()
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:propose_change, instance_id, change_id, code_change, metadata}, _from, state) do
    Logger.info("[ConsensusEngine] Proposing change",
      instance_id: instance_id,
      change_id: change_id,
      change_type: code_change[:change_type]
    )

    # Validate change is registered with Guardian
    case RollbackService.approve_change?(change_id) do
      {:ok, :auto_approved, similarity} ->
        Logger.info("[ConsensusEngine] Change auto-approved by Guardian",
          change_id: change_id,
          similarity: similarity
        )

        # Skip consensus voting, execute immediately
        case broadcast_change(change_id, code_change, metadata) do
          {:ok, execution_id} ->
            {:reply, {:ok, execution_id}, state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end

      {:ok, :requires_consensus, _similarity} ->
        # Create proposal and start voting
        proposal_id = Ecto.UUID.generate()

        proposal = %{
          proposal_id: proposal_id,
          instance_id: instance_id,
          change_id: change_id,
          code_change: code_change,
          metadata: metadata,
          proposed_at: DateTime.utc_now(),
          status: :voting
        }

        new_state = put_in(state, [:proposals, change_id], proposal)

        # Persist to database
        persist_proposal(proposal)

        # Broadcast to instances for voting
        broadcast_for_voting(change_id, code_change, metadata)

        {:reply, {:ok, proposal_id}, new_state}

      {:error, reason} ->
        Logger.error("[ConsensusEngine] Guardian rejected change",
          change_id: change_id,
          reason: inspect(reason)
        )

        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:vote_on_change, instance_id, change_id, vote, reason}, _from, state) do
    Logger.info("[ConsensusEngine] Recording vote",
      instance_id: instance_id,
      change_id: change_id,
      vote: vote
    )

    # Compute confidence score based on reason length and keywords
    confidence = compute_vote_confidence(reason)

    # Record vote in state
    vote_record = %{
      instance_id: instance_id,
      vote: vote,
      confidence: confidence,
      reason: reason,
      voted_at: DateTime.utc_now()
    }

    current_votes = Map.get(state.votes, change_id, [])
    new_votes = [vote_record | current_votes]
    new_state = put_in(state, [:votes, change_id], new_votes)

    # Persist vote to database
    persist_vote(change_id, instance_id, vote, confidence, reason)

    # Check if consensus reached
    case check_consensus(new_votes) do
      {:consensus, :approved} ->
        Logger.info("[ConsensusEngine] Consensus reached, executing change",
          change_id: change_id,
          votes: length(new_votes)
        )

        # Execute the change
        proposal = Map.get(state.proposals, change_id)

        case broadcast_change(change_id, proposal.code_change, proposal.metadata) do
          {:ok, _execution_id} ->
            # Mark as executed
            executed_state = update_in(new_state, [:executed], &MapSet.put(&1, change_id))
            {:reply, {:ok, :consensus_reached}, executed_state}

          {:error, reason} ->
            {:reply, {:error, reason}, new_state}
        end

      {:consensus, :rejected} ->
        Logger.warning("[ConsensusEngine] Consensus to reject change",
          change_id: change_id,
          votes: length(new_votes)
        )

        {:reply, {:ok, :consensus_reached}, new_state}

      :no_consensus ->
        {:reply, {:ok, :voted}, new_state}
    end
  end

  @impl true
  def handle_call({:execute_if_consensus, change_id}, _from, state) do
    # Check if already executed
    if MapSet.member?(state.executed, change_id) do
      {:reply, {:error, :already_executed}, state}
    else
      votes = Map.get(state.votes, change_id, [])

      case check_consensus(votes) do
        {:consensus, :approved} ->
          proposal = Map.get(state.proposals, change_id)

          case broadcast_change(change_id, proposal.code_change, proposal.metadata) do
            {:ok, execution_id} ->
              new_state = update_in(state, [:executed], &MapSet.put(&1, change_id))
              {:reply, {:ok, execution_id}, new_state}

            {:error, reason} ->
              {:reply, {:error, reason}, state}
          end

        _ ->
          {:reply, {:error, :consensus_not_reached}, state}
      end
    end
  end

  # Private Functions

  defp compute_vote_confidence(reason) do
    # Mock confidence computation based on reason quality
    # In production: Use NLP to assess reasoning quality
    cond do
      String.length(reason) > 100 -> 0.95
      String.length(reason) > 50 -> 0.85
      true -> 0.75
    end
  end

  defp check_consensus(votes) when length(votes) < 3 do
    :no_consensus
  end

  defp check_consensus(votes) do
    # Consensus rules:
    # 1. At least 3 votes
    # 2. 2/3 (67%) approval
    # 3. Average confidence >= 0.85
    # 4. No strong rejections (confidence > 0.90 and vote = reject)

    total_votes = length(votes)
    approve_votes = Enum.count(votes, &(&1.vote == :approve))
    reject_votes = Enum.count(votes, &(&1.vote == :reject))

    approval_rate = approve_votes / total_votes
    avg_confidence = Enum.map(votes, & &1.confidence) |> Enum.sum() |> Kernel./(total_votes)

    strong_rejections =
      Enum.any?(votes, fn v ->
        v.vote == :reject and v.confidence > 0.90
      end)

    cond do
      strong_rejections ->
        {:consensus, :rejected}

      approval_rate >= 0.67 and avg_confidence >= 0.85 ->
        {:consensus, :approved}

      reject_votes > approve_votes and avg_confidence >= 0.85 ->
        {:consensus, :rejected}

      true ->
        :no_consensus
    end
  end

  defp persist_proposal(proposal) do
    # In production: Store in consensus_votes table
    Logger.info("[ConsensusEngine] Persisting proposal",
      proposal_id: proposal.proposal_id,
      change_id: proposal.change_id
    )

    :ok
  end

  defp persist_vote(change_id, instance_id, vote, confidence, reason) do
    changeset = ConsensusVote.changeset(%ConsensusVote{}, %{
      change_id: change_id,
      instance_id: instance_id,
      vote: Atom.to_string(vote),
      confidence: confidence,
      reason: reason,
      voted_at: DateTime.utc_now()
    })

    case Repo.insert(changeset) do
      {:ok, _} -> :ok
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp broadcast_for_voting(change_id, code_change, metadata) do
    # In production: Publish to ex_quantum_flow queue "evolution_voting_requests"
    Logger.info("[ConsensusEngine] Broadcasting for voting",
      change_id: change_id,
      change_type: code_change[:change_type]
    )

    # TODO: Implement ex_quantum_flow broadcast
    :ok
  end

  defp broadcast_change(change_id, code_change, metadata) do
    execution_id = Ecto.UUID.generate()

    # In production: Publish to ex_quantum_flow queue "evolution_approved_changes"
    Logger.info("[ConsensusEngine] Broadcasting approved change",
      execution_id: execution_id,
      change_id: change_id,
      change_type: code_change[:change_type]
    )

    # TODO: Implement ex_quantum_flow broadcast
    {:ok, execution_id}
  end
end
