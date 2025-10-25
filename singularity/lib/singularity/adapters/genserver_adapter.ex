defmodule Singularity.Adapters.GenServerAdapter do
  @moduledoc """
  GenServer Adapter - Synchronous task execution via GenServer agents.

  Implements @behaviour TaskAdapter for executing tasks synchronously via
  GenServer agent processes for immediate execution and feedback.

  ## Features

  - Synchronous task execution
  - In-process execution
  - Immediate results
  - Lower latency

  ## Capabilities

  - `["sync", "in_process", "immediate", "low_latency"]`
  """

  @behaviour Singularity.Execution.TaskAdapter

  require Logger

  @impl Singularity.Execution.TaskAdapter
  def adapter_type, do: :genserver_adapter

  @impl Singularity.Execution.TaskAdapter
  def description do
    "Synchronous task execution via GenServer agents"
  end

  @impl Singularity.Execution.TaskAdapter
  def capabilities do
    ["sync", "in_process", "immediate", "low_latency", "agent_based"]
  end

  @impl Singularity.Execution.TaskAdapter
  def execute(task, opts \\ []) do
    Logger.debug("GenServer adapter: Executing task", task_type: task[:type])

    # Extract task details
    task_type = task[:type]
    args = task[:args] || %{}
    timeout = Keyword.get(opts, :timeout, 5000)
    task_id = generate_task_id()

    # Find or create agent for this task type
    case get_or_create_agent(task_type) do
      {:ok, agent_pid} ->
        # Execute task in agent
        try do
          Agent.get_and_update(agent_pid, fn state ->
            result = execute_task(task_type, args)
            {result, state}
          end)

          Logger.debug("GenServer adapter: Task executed",
            task_type: task_type,
            task_id: task_id
          )

          {:ok, "genserver:#{task_id}"}
        catch
          :exit, reason ->
            Logger.error("GenServer adapter: Task execution failed",
              reason: inspect(reason)
            )

            {:error, reason}
        end

      {:error, reason} ->
        Logger.error("GenServer adapter: Failed to get/create agent",
          reason: inspect(reason)
        )

        {:error, reason}
    end
  end

  defp get_or_create_agent(task_type) do
    agent_name = :"task_agent_#{task_type}"

    case Agent.start_link(fn -> %{} end, name: agent_name) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      {:error, reason} -> {:error, reason}
    end
  end

  defp execute_task(task_type, args) do
    # In a real implementation, this would dispatch to the appropriate handler
    # For now, just return success
    {:ok, task_type, args}
  end

  defp generate_task_id do
    :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
  end
end
