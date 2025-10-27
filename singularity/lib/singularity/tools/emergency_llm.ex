defmodule Singularity.Tools.EmergencyLLM do
  @moduledoc """
  Emergency LLM Fallback Tools - Direct Claude CLI Access

  ⚠️  DO NOT USE FOR REGULAR LLM CALLS ⚠️

  This module provides EMERGENCY fallback tools that call Claude CLI directly.
  These are only used when:
  - pgmq AI server is down
  - Emergency recovery scenarios
  - Agent tools that explicitly request CLI fallback

  ## Regular LLM Usage

  For normal LLM calls from Elixir code, use:

      Singularity.LLM.Service.call("claude-sonnet-4.5", messages)

  This goes through pgmq → AI Server → AI SDK providers.

  ## Emergency Tools

  This module registers tools like:
  - `llm_claude_safe` - Read-only Claude CLI
  - `llm_claude_write` - Can edit files
  - `llm_claude_dangerous` - Unrestricted (recovery only)

  ## Architecture

  Normal:  Elixir → pgmq → AI Server → AI SDK → Providers
  Emergency: Agent Tool → This Module → Claude CLI (direct)
  """

  alias Singularity.Integration.Claude
  alias Singularity.Schemas.Tools.Tool

  @doc "Register LLM emergency tools for a provider."
  @spec register(term()) :: :ok
  def register(provider) do
    tools =
      Claude.available_profiles()
      |> Enum.map(fn {profile, cfg} -> build_tool(profile, cfg) end)

    Singularity.Tools.Catalog.add_tools(provider, tools)
  end

  defp build_tool(profile, cfg) do
    Tool.new!(%{
      name: "llm_claude_#{profile}",
      description:
        cfg[:description] ||
          "Call the Claude recovery CLI using the #{profile} profile (fallback path).",
      display_text: "Claude CLI (#{profile})",
      parameters: [
        %{name: "prompt", type: :string, required: true, description: "Text prompt"}
      ],
      function: &__MODULE__.run/2,
      options: %{profile: profile}
    })
  end

  @doc false
  def run(%{"prompt" => prompt}, %{tool: tool}) do
    profile = tool.options[:profile]

    case Claude.chat(prompt, profile: profile) do
      {:ok, %{response: response}} ->
        {:ok, response}

      {:ok, %{raw: raw}} ->
        {:ok, raw}

      {:error, reason} ->
        {:error, "Claude CLI (#{profile}) failed: #{inspect(reason)}"}
    end
  end

  def run(_args, %{tool: tool}) do
    {:error, "Prompt is required for #{tool.name}"}
  end
end
