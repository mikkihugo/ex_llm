defmodule Singularity.Workflows.CodeMetricsWorkflow do
  @moduledoc """
  PGFlow workflow for running the code-metrics pipeline end-to-end.

  Accepts either a list of file paths (`:file_paths`) or a `:codebase_id`
  registered with `Singularity.CodeStore`. For each target file it invokes
  `Singularity.Metrics.Orchestrator` to compute metrics, enrichment and insights,
  then stores the results via `Singularity.Metrics.CodeMetrics`.
  """

  use Pgflow.Workflow
  require Logger

  import Ecto.Query

  alias Singularity.Metrics.Orchestrator
  alias Singularity.Repo
  alias Singularity.Schemas.CodeFile

  @default_limit 200

  @impl true
  def workflow_definition do
    %{
      name: "code_metrics_pipeline",
      version: Singularity.BuildInfo.version(),
      description: "Compute AI-powered code metrics with enrichment.",
      config: %{
        timeout_ms: 120_000,
        retries: 2,
        retry_delay_ms: 1_000,
        concurrency: 2
      },
      steps: [
        %{
          id: :fetch_targets,
          name: "Fetch Targets",
          description: "Load file targets for metrics analysis",
          type: :task,
          module: __MODULE__,
          function: :fetch_targets,
          config: %{
            timeout_ms: 15_000,
            concurrency: 2
          },
          next: [:analyze_targets]
        },
        %{
          id: :analyze_targets,
          name: "Analyze Targets",
          description: "Run metrics orchestrator for each file",
          type: :task,
          module: __MODULE__,
          function: :analyze_targets,
          config: %{
            concurrency: 4,
            timeout_ms: 90_000
          },
          depends_on: [:fetch_targets],
          next: [:aggregate_results]
        },
        %{
          id: :aggregate_results,
          name: "Aggregate Results",
          description: "Summarise metrics for reporting",
          type: :task,
          module: __MODULE__,
          function: :aggregate_results,
          config: %{
            timeout_ms: 15_000
          },
          depends_on: [:analyze_targets]
        }
      ],
      metrics: [
        :execution_time,
        :success_rate,
        :error_rate,
        :throughput
      ]
    }
  end

  @doc false
  def fetch_targets(context) do
    input = context.input

    with {:ok, targets} <- resolve_targets(input) do
      {:ok,
       %{
         targets: targets,
         project_id: Map.get(input, :project_id),
         enrich?: Map.get(input, :enrich, true),
         store?: Map.get(input, :store, true)
       }}
    else
      {:error, reason} ->
        Logger.error("Failed to resolve metrics targets: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc false
  def analyze_targets(%{fetch_targets: %{result: state}} = _context) do
    opts = [
      enrich: state.enrich?,
      store: state.store?,
      project_id: state.project_id
    ]

    results =
      state.targets
      |> Enum.map(fn target ->
        analyze_target(target, opts)
      end)

    {:ok, %{results: results}}
  end

  @doc false
  def aggregate_results(
        %{
          fetch_targets: %{result: %{targets: targets}},
          analyze_targets: %{result: %{results: results}}
        } = _context
      ) do
    successful =
      results
      |> Enum.filter(&match?({:ok, _}, &1))
      |> Enum.map(fn {:ok, result} -> result end)

    failed =
      results
      |> Enum.filter(&match?({:error, _}, &1))

    summary = %{
      total_files: length(targets),
      successful: length(successful),
      failed: length(failed),
      average_quality_score:
        successful
        |> Enum.map(fn result -> get_in(result, [:metrics, :overall_quality_score]) end)
        |> avg_safe(),
      type_safety_avg:
        successful
        |> Enum.map(fn result -> get_in(result, [:metrics, :type_safety_score]) end)
        |> avg_safe(),
      coupling_avg:
        successful
        |> Enum.map(fn result -> get_in(result, [:metrics, :coupling_score]) end)
        |> avg_safe(),
      error_handling_avg:
        successful
        |> Enum.map(fn result -> get_in(result, [:metrics, :error_handling_score]) end)
        |> avg_safe(),
      insights:
        successful
        |> Enum.flat_map(&Map.get(&1, :insights, []))
    }

    {:ok,
     %{
       summary: summary,
       results: successful,
       failed: failed
     }}
  end

  defp analyze_target(%{path: path, code: code, language: language} = target, opts) do
    orchestrator_opts =
      [code: code, language: language, project_id: target[:project_id] || opts[:project_id]]
      |> Keyword.merge(opts)

    case Orchestrator.analyze_file(path, orchestrator_opts) do
      {:ok, result} ->
        {:ok, result}

      {:error, reason} ->
        Logger.error("Metric analysis failed for #{path}: #{inspect(reason)}")
        {:error, %{path: path, reason: reason}}
    end
  end

  defp resolve_targets(%{file_paths: paths} = input) when is_list(paths) do
    project_id = Map.get(input, :project_id)

    targets =
      paths
      |> Enum.uniq()
      |> Enum.map(&Path.expand/1)
      |> Enum.filter(&File.exists?/1)
      |> Enum.map(fn path ->
        %{
          path: path,
          project_id: project_id,
          code: File.read!(path),
          language: detect_language_from_extension(path)
        }
      end)

    {:ok, targets}
  end

  defp resolve_targets(%{codebase_id: codebase_id} = input) do
    limit = Map.get(input, :limit, @default_limit)

    query =
      from cf in CodeFile,
        where: cf.project_name == ^codebase_id,
        select: %{path: cf.file_path, code: cf.content, language: cf.language},
        limit: ^limit

    try do
      case Repo.all(query) do
        [] ->
          {:error, :no_files_found}

        rows ->
          targets =
            Enum.map(rows, fn %{path: path, code: code, language: language} ->
              %{
                path: path,
                code: code,
                language: language || detect_language_from_extension(path),
                project_id: codebase_id
              }
            end)

          {:ok, targets}
      end
    rescue
      e ->
        {:error, {:db_error, e}}
    end
  end

  defp resolve_targets(_), do: {:error, :invalid_input}

  defp detect_language_from_extension(path) do
    case Path.extname(path) do
      ".ex" -> :elixir
      ".exs" -> :elixir
      ".erl" -> :erlang
      ".gleam" -> :gleam
      ".rs" -> :rust
      ".py" -> :python
      ".js" -> :javascript
      ".ts" -> :typescript
      ".java" -> :java
      ".go" -> :go
      ".rb" -> :ruby
      ".cs" -> :csharp
      ".cpp" -> :cpp
      ".c" -> :c
      ext when byte_size(ext) > 1 -> String.trim_leading(ext, ".") |> String.to_atom()
      _ -> :unknown
    end
  end

  defp avg_safe([]), do: 0.0

  defp avg_safe(list) do
    values =
      list
      |> Enum.filter(&is_number/1)

    case values do
      [] -> 0.0
      _ -> Enum.sum(values) / length(values)
    end
  end
end
