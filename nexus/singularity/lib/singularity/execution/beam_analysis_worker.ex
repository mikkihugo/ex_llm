defmodule Singularity.Execution.BeamAnalysisWorker do
  @moduledoc """
  Worker that wraps `Singularity.BeamAnalysisEngine` so it can participate in
  HTDAG/Workflow execution.

  Contract: `function(args_map, opts) -> {:ok, info} | {:error, reason}`

  Supported entry points:
    * `analyze_file/2` - analyse a single BEAM source file.
    * `summarize_results/2` - fold per-file analyses into a summary payload.
  """

  require Logger

  alias Singularity.BeamAnalysisEngine

  @doc """
  Analyse a BEAM file. Expects args with:

    * `:language`  - "elixir" | "erlang" | "gleam" (default "elixir")
    * `:path`      - absolute or workspace-relative file path
    * `:codebase_id` (optional) - informational
  """
  def analyze_file(%{path: path} = args, opts) do
    dry_run = Keyword.get(opts, :dry_run, true)
    language = Map.get(args, :language, "elixir")
    codebase_id = Map.get(args, :codebase_id)

    Logger.info("BeamAnalysisWorker.analyze_file: #{path} (#{language}, dry_run=#{dry_run})",
      codebase_id: codebase_id
    )

    cond do
      dry_run ->
        {:ok,
         %{
           action: :beam_analysis,
           status: :dry_run,
           path: path,
           language: language,
           codebase_id: codebase_id,
           description: "Would analyse BEAM file and record OTP/fault-tolerance metrics"
         }}

      not File.exists?(path) ->
        {:error, {:file_not_found, path}}

      true ->
        with {:ok, code} <- File.read(path),
             {:ok, analysis} <- BeamAnalysisEngine.analyze_beam_code(language, code, path) do
          {:ok,
           %{
             action: :beam_analysis,
             status: :analysed,
             path: path,
             language: language,
             codebase_id: codebase_id,
             metrics: analysis.beam_metrics,
             otp_patterns: analysis.otp_patterns,
             actor_analysis: analysis.actor_analysis,
             fault_tolerance: analysis.fault_tolerance
           }}
        else
          {:error, reason} ->
            Logger.error("BeamAnalysisWorker.analyze_file failed",
              path: path,
              reason: inspect(reason)
            )

            {:error, reason}
        end
    end
  end

  @doc """
  Summarise multiple per-file analysis results. Accepts args with:

    * `:results` - list of maps returned from `analyze_file/2`
    * `:codebase_id` (optional)
  """
  def summarize_results(%{results: results} = args, _opts) when is_list(results) do
    codebase_id = Map.get(args, :codebase_id)

    totals =
      Enum.reduce(results, %{files: 0, processes: 0, fault_score: 0.0}, fn
        %{metrics: metrics}, acc ->
          %{
            files: acc.files + 1,
            processes: acc.processes + (metrics[:estimated_process_count] || 0),
            fault_score: acc.fault_score + (metrics[:fault_tolerance_score] || 0.0)
          }

        _result, acc ->
          acc
      end)

    aggregate =
      if totals.files > 0 do
        %{average_fault_tolerance: Float.round(totals.fault_score / totals.files, 2)}
      else
        %{average_fault_tolerance: 0.0}
      end

    {:ok,
     %{
       action: :beam_analysis_summary,
       status: :summarised,
       codebase_id: codebase_id,
       totals: totals,
       aggregate: aggregate
     }}
  end

  def summarize_results(_args, _opts), do: {:error, :invalid_summary_args}
end
