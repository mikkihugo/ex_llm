defmodule Singularity.AgentImprovementBroadcaster do
  @moduledoc """
  Agent Improvement Broadcaster - Publishes agent improvements across cluster nodes.

  Cluster-native broadcasting without external transports (pgmq-free).
  """

  alias Singularity.Agents.Agent

  @group :singularity_control

  @doc """
  Publish an improvement payload to the cluster.

  The request is fanned out to all control listeners (one per node). Each
  listener attempts to route the payload to the target agent locally; exactly
  one should succeed, and the rest will ignore the `:not_found` result.
  """
  @spec publish_improvement(String.t(), map()) :: :ok
  def publish_improvement(agent_id, payload) when is_map(payload) do
    ensure_pg()
    message = {:improve, to_string(agent_id), payload}

    members = :pg.get_members(@group)

    if members == [] do
      _ = Agent.improve(agent_id, payload)
    else
      Enum.each(members, &send(&1, message))
    end

    :ok
  end

  @doc """
  Attempt to apply an improvement locally; if the agent isn't on this node,
  forward the request to peers via synchronous RPC.
  """
  @spec request_improvement(String.t(), map()) :: :ok | {:error, :not_found}
  def request_improvement(agent_id, payload) when is_map(payload) do
    agent_id = to_string(agent_id)

    case Agent.improve(agent_id, payload) do
      :ok -> :ok
      {:error, :not_found} -> forward_to_cluster(agent_id, payload)
    end
  end

  defp forward_to_cluster(agent_id, payload) do
    Node.list()
    |> Enum.shuffle()
    |> Enum.reduce_while({:error, :not_found}, fn node, _acc ->
      case :rpc.call(node, Singularity.Agents.Agent, :improve, [agent_id, payload]) do
        :ok -> {:halt, :ok}
        {:error, :not_found} -> {:cont, {:error, :not_found}}
        {:badrpc, _} -> {:cont, {:error, :not_found}}
      end
    end)
  end

  defp ensure_pg do
    case :pg.start_link() do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      {:error, {:already_registered_name, _name}} -> :ok
      {:error, reason} -> raise "failed to start :pg: #{inspect(reason)}"
    end
  end
end
