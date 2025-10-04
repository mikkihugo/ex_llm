defmodule SeedAgent.Autonomy.Planner do
  @moduledoc """
  Produces new strategy payloads for self-improving agents.

  The planner emits Gleam source code that can be validated and staged by the
  hot-reload pipeline. Today the generated strategies simply wrap contextual
  metadata, but the scaffolding allows richer program synthesis (e.g. feeding in
  prompts, historical traces, or external LLM outputs) without touching the
  agent loop again.
  """

  @default_reason "stagnation"

  @spec generate(map(), map()) :: map()
  def generate(state, context) do
    agent_id = Map.fetch!(state, :id)
    reason = context |> Map.get(:reason, @default_reason) |> to_string()
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    module_base = module_basename(agent_id)
    module_name = "SeedAgent.Dynamic.Strategy#{module_base}#{unique_suffix()}"
    score = Map.get(context, :score, state[:last_score] || 1.0)
    samples = Map.get(context, :samples, 0)
    stagnation = Map.get(context, :stagnation, 0)

    code = build_module(module_name, agent_id, reason, timestamp, score, samples, stagnation)

    %{
      "code" => code,
      "module" => module_name,
      "metadata" => %{
        "agent_id" => agent_id,
        "reason" => reason,
        "generated_at" => timestamp,
        "samples" => samples,
        "score" => score,
        "stagnation_cycles" => stagnation,
        "module" => module_name
      }
    }
  end

  defp module_basename(agent_id) do
    agent_id
    |> to_string()
    |> String.replace(~r/[^A-Za-z0-9]/, "_")
    |> String.trim("_")
  end

  defp unique_suffix do
    System.system_time(:millisecond)
  end

  defp build_module(module_name, agent_id, reason, timestamp, score, samples, stagnation) do
    summary =
      "Agent #{agent_id} improved because #{reason} (score=#{Float.round(score, 4)}, " <>
        "samples=#{samples}, stagnation=#{stagnation})"

    """
    defmodule #{module_name} do
      @moduledoc \"\"\"
      Auto-generated strategy for #{agent_id} at #{timestamp}.
      Triggered because: #{reason}.
      \"\"\"

      @summary #{inspect(summary)}

      @doc "Respond to the given input with the current strategy summary."
      @spec respond(term()) :: {:ok, term()} | {:error, term()}
      def respond(input) do
        {:ok, %{summary: @summary, input: input}}
      end
    end
    """
  end
end
