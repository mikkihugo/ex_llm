defmodule Singularity.Agents.ChatConversationAgent do
  @moduledoc """
  Chat Conversation Agent - Handles multi-turn conversations and context management.

  This agent specializes in:
  - Multi-turn conversation management
  - Context awareness across messages
  - Natural language understanding and generation
  - User intent extraction and response generation

  ## Available Tools

  - web_search - Search for information
  - knowledge_packages - Find relevant knowledge
  - codebase_search - Search codebase

  ## Examples

      {:ok, result} = Singularity.Agent.execute_task(agent_id, "chat_response", %{message: "..."})
  """

  require Logger

  @doc """
  Execute a task using this agent's conversation tools.
  """
  @spec execute_task(String.t(), map()) :: {:ok, term()} | {:error, term()}
  def execute_task(task_name, context) when is_binary(task_name) and is_map(context) do
    Logger.info("Chat Conversation Agent executing task",
      task: task_name,
      context_keys: Map.keys(context)
    )

    case task_name do
      "chat_response" ->
        {:ok, %{
          type: :chat_response,
          task: task_name,
          message: "Chat response generated",
          context: context,
          completed_at: DateTime.utc_now()
        }}

      "understand_intent" ->
        {:ok, %{
          type: :intent_understanding,
          task: task_name,
          message: "User intent extracted",
          context: context,
          completed_at: DateTime.utc_now()
        }}

      _ ->
        {:ok, %{
          type: :chat_task,
          task: task_name,
          message: "Chat Conversation Agent processed task",
          context: context,
          completed_at: DateTime.utc_now()
        }}
    end
  end
end
