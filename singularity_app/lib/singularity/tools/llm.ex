defmodule Singularity.Tools.Llm do
  @moduledoc """
  Registers tool wrappers around the emergency Claude CLI profiles so agents can
  invoke safe or write-enabled fallbacks via the tool runner.
  """

  alias Singularity.Integration.Claude
  alias Singularity.Tools.{Registry, Tool}

  @doc "Register LLM emergency tools for a provider."
  @spec register(term()) :: :ok
  def register(provider) do
    tools =
      Claude.available_profiles()
      |> Enum.map(fn {profile, cfg} -> build_tool(profile, cfg) end)

    Registry.register_tools(provider, tools)
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
