defmodule CentralCloud.LLMTeamOrchestrator do
  @moduledoc """
  High-level façade for running the CentralCloud multi-agent LLM workflow.

  Instead of manually chaining model calls, we enqueue a PGFlow workflow
  (`CentralCloud.Workflows.LLMTeamWorkflow`) that models the entire discussion.
  The workflow automatically picks the right crew (fast/default/thorough), runs
  the required specialists, and returns a consensus payload with trace data.
  """

  require Logger
  alias CentralCloud.Workflows.LLMTeamWorkflow
  alias PGFlow.Workflow

  @doc """
  Validate a codebase pattern by delegating to the PGFlow crew workflow.

  Options:
  * `:mode` – force a crew (`:fast | :default | :thorough`)
  * `:initial_confidence` – heuristic from local analysis (0.0-1.0)
  * `:metadata` – additional information (map)
  * `:request_id` – correlation id for upstream tracking
  * `:skip_cache` – skip cache lookups (future)
  """
  @spec validate_pattern(String.t(), list(String.t()), keyword()) ::
          {:ok, map()} | {:error, term()}
  def validate_pattern(codebase_id, code_samples, opts \\ []) when is_list(code_samples) do
    pattern_type = Keyword.get(opts, :pattern_type, "architecture")
    initial_confidence = clamp(Keyword.get(opts, :initial_confidence, 0.5))
    mode = Keyword.get(opts, :mode)
    metadata = Keyword.get(opts, :metadata, %{})
    request_id = Keyword.get(opts, :request_id, generate_request_id())

    payload = %{
      codebase_id: codebase_id,
      code_samples: code_samples,
      pattern_type: pattern_type,
      mode: mode,
      initial_confidence: initial_confidence,
      metadata: metadata,
      request_id: request_id
    }

    Logger.info("[LLMTeam] Enqueuing PGFlow workflow", codebase: codebase_id, mode: mode || :auto)

    timeout = Keyword.get(opts, :timeout, 180_000)

    with {:ok, run_id} <- PGFlow.Workflow.execute(LLMTeamWorkflow, payload),
         {:ok, result} <- PGFlow.Workflow.await(run_id, timeout: timeout) do
      store_validation_results(codebase_id, result)
      {:ok, result}
    else
      {:error, :timeout} ->
        Logger.error("[LLMTeam] Workflow execution timed out", codebase: codebase_id)
        {:error, :timeout}

      {:error, reason} ->
        Logger.error("[LLMTeam] Workflow execution failed",
          codebase: codebase_id,
          reason: inspect(reason)
        )

        {:error, reason}
    end
  end

  # ────────────────────────────────────────────────────────────────
  # Helpers
  # ────────────────────────────────────────────────────────────────

  defp store_validation_results(codebase_id, %{specialists: specialists} = result) do
    Logger.info("[LLMTeam] Storing validation results",
      codebase: codebase_id,
      final_confidence: result.final_confidence
    )

    summary =
      specialists
      |> Enum.map(fn specialist ->
        "#{specialist.role}: #{format_confidence(specialist.confidence)}"
      end)
      |> Enum.join(" | ")

    Logger.debug("[LLMTeam] Specialist summary", summary: summary)

    # TODO: persist into analytics tables once schema is defined
    :ok
  end

  defp store_validation_results(codebase_id, result) do
    Logger.info("[LLMTeam] Storing validation results (no specialists payload)",
      codebase: codebase_id
    )

    Logger.debug("[LLMTeam] Result", result: result)
    :ok
  end

  defp generate_request_id, do: :crypto.strong_rand_bytes(12) |> Base.url_encode64(padding: false)

  defp clamp(value) when is_number(value), do: value |> max(0.0) |> min(1.0)
  defp clamp(value), do: value

  defp format_confidence(nil), do: "n/a"
  defp format_confidence(value), do: :io_lib.format("~.2f", [value]) |> IO.iodata_to_binary()
end
