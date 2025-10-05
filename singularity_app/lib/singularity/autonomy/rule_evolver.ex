defmodule Singularity.Autonomy.RuleEvolver do
  @moduledoc """
  Manages consensus-based rule evolution.

  Agents propose changes → Other agents vote → Consensus reached → Apply evolution.

  **OTP-native** - uses GenServer message passing, NOT event-driven.
  """

  use GenServer
  require Logger

  import Ecto.Query

  alias Singularity.{Repo, Autonomy}
  alias Autonomy.{Rule, RuleEvolutionProposal, RuleLoader}

  @consensus_timeout :timer.minutes(5)

  ## Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Agent proposes a rule evolution.

  Returns {:ok, proposal_id} and waits for consensus votes.
  """
  def propose_evolution(agent_id, rule_id, proposed_patterns, reasoning) do
    GenServer.call(__MODULE__, {
      :propose,
      agent_id,
      rule_id,
      proposed_patterns,
      reasoning
    })
  end

  @doc """
  Agent votes on a proposal.

  vote: :approve | :reject
  confidence: 0.0 - 1.0
  """
  def vote(agent_id, proposal_id, vote, confidence) do
    GenServer.call(__MODULE__, {:vote, agent_id, proposal_id, vote, confidence})
  end

  @doc "Get pending proposals for agent review"
  def get_pending_proposals do
    GenServer.call(__MODULE__, :get_pending)
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    {:ok, %{active_proposals: %{}}}
  end

  @impl true
  def handle_call({:propose, agent_id, rule_id, proposed_patterns, reasoning}, _from, state) do
    # Create proposal
    {:ok, proposal} =
      %RuleEvolutionProposal{}
      |> RuleEvolutionProposal.changeset(%{
        rule_id: rule_id,
        proposer_agent_id: agent_id,
        proposed_patterns: proposed_patterns,
        evolution_reasoning: reasoning,
        status: "proposed"
      })
      |> Repo.insert()

    Logger.info("Rule evolution proposed",
      proposal_id: proposal.id,
      rule_id: rule_id,
      agent: agent_id
    )

    # Track proposal + schedule timeout
    state = put_in(state.active_proposals[proposal.id], proposal)
    schedule_timeout(proposal.id)

    # Notify other agents (via direct message passing, not events)
    notify_agents_for_review(proposal)

    {:reply, {:ok, proposal.id}, state}
  end

  @impl true
  def handle_call({:vote, agent_id, proposal_id, vote, confidence}, _from, state) do
    case Repo.get(RuleEvolutionProposal, proposal_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      proposal ->
        # Record vote
        {:ok, updated_proposal} =
          proposal
          |> RuleEvolutionProposal.vote_changeset(agent_id, vote, confidence)
          |> Repo.update()

        Logger.info("Vote recorded",
          proposal_id: proposal_id,
          agent: agent_id,
          vote: vote,
          confidence: confidence
        )

        # Check if consensus reached
        if updated_proposal.consensus_reached do
          apply_evolution(updated_proposal)
          state = Map.delete(state.active_proposals, proposal_id)
          {:reply, {:consensus_reached, :approved}, state}
        else
          state = put_in(state.active_proposals[proposal_id], updated_proposal)
          {:reply, {:ok, :vote_recorded}, state}
        end
    end
  end

  @impl true
  def handle_call(:get_pending, _from, state) do
    pending =
      RuleEvolutionProposal
      |> where([proposal], proposal.status == "proposed")
      |> preload(:rule)
      |> Repo.all()

    {:reply, pending, state}
  end

  @impl true
  def handle_info({:proposal_timeout, proposal_id}, state) do
    case Map.get(state.active_proposals, proposal_id) do
      nil ->
        # Already handled
        {:noreply, state}

      proposal ->
        Logger.warning("Proposal timed out without consensus",
          proposal_id: proposal_id
        )

        # Mark as expired
        Repo.update!(Ecto.Changeset.change(proposal, status: "expired"))
        state = Map.delete(state.active_proposals, proposal_id)
        {:noreply, state}
    end
  end

  ## Private Functions

  defp apply_evolution(proposal) do
    Logger.info("Applying rule evolution", proposal_id: proposal.id)

    # Load original rule
    rule = Repo.get!(Rule, proposal.rule_id)

    # Create new version (immutable evolution history)
    {:ok, evolved_rule} =
      %Rule{}
      |> Rule.evolution_changeset(%{
        name: rule.name <> " v#{rule.version + 1}",
        description: rule.description,
        category: rule.category,
        patterns: proposal.proposed_patterns,
        confidence_threshold: proposal.proposed_threshold || rule.confidence_threshold,
        version: rule.version + 1,
        parent_rule_id: rule.id,
        created_by_agent_id: proposal.proposer_agent_id,
        status: "active"
      })
      |> Repo.insert()

    # Deprecate old rule
    Repo.update!(Ecto.Changeset.change(rule, status: "deprecated"))

    # Reload rules cache
    RuleLoader.reload_rules()

    Logger.info("Rule evolution applied",
      old_rule_id: rule.id,
      new_rule_id: evolved_rule.id,
      version: evolved_rule.version
    )

    {:ok, evolved_rule}
  end

  defp notify_agents_for_review(proposal) do
    # Send direct messages to agent processes (OTP message passing)
    # NOT event-driven - find agent PIDs via Registry and send messages

    # Get all active agent PIDs from Registry
    agents = Registry.lookup(Singularity.AgentRegistry, :all_agents)

    Enum.each(agents, fn {agent_pid, _value} ->
      send(agent_pid, {:review_evolution_proposal, proposal.id, proposal.rule_id})
    end)
  end

  defp schedule_timeout(proposal_id) do
    Process.send_after(self(), {:proposal_timeout, proposal_id}, @consensus_timeout)
  end
end
