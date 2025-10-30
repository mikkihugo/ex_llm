defmodule Mix.Tasks.Analyze.Codebase do
  @shortdoc "Analyze entire codebase using Singularity.CodeAnalyzer with 20-language support"

  @moduledoc """
  Analyzes an entire codebase with multi-language support.

  Uses Singularity.CodeAnalyzer to analyze all files in a codebase from the database.

  ## Usage

      # Analyze specific codebase
      mix analyze.codebase --codebase-id my-project

      # Analyze with RCA metrics (for supported languages)
      mix analyze.codebase --codebase-id my-project --rca

      # Analyze and store results
      mix analyze.codebase --codebase-id my-project --store

      # Analyze specific language only
      mix analyze.codebase --codebase-id my-project --language elixir

  ## Options

    * `--codebase-id` - Codebase identifier (required)
    * `--rca` - Include RCA metrics for supported languages (Rust, C, C++, etc.)
    * `--store` - Store analysis results back to database
    * `--language` - Only analyze files of specific language
    * `--verbose` - Show detailed output

  ## Examples

      # Full analysis
      mix analyze.codebase --codebase-id singularity --rca --store

      # Quick check (no storage)
      mix analyze.codebase --codebase-id my-app

      # Language-specific
      mix analyze.codebase --codebase-id backend --language rust --rca
  """

  use Mix.Task
  require Logger

  alias Singularity.Repo
  alias Singularity.Schemas.CodeFile
  alias Singularity.CodeAnalyzer
  import Ecto.Query

  @requirements ["app.start"]

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          codebase_id: :string,
          rca: :boolean,
          store: :boolean,
          language: :string,
          verbose: :boolean
        ]
      )

    codebase_id = opts[:codebase_id] || Mix.raise("--codebase-id is required")
    include_rca = opts[:rca] || false
    store_results = opts[:store] || false
    language_filter = opts[:language]
    verbose = opts[:verbose] || false

    Mix.shell().info("Analyzing codebase: #{codebase_id}")

    Mix.shell().info(
      "Options: RCA=#{include_rca}, Store=#{store_results}, Language=#{language_filter || "all"}"
    )

    Mix.shell().info("")

    # Load files from database
    files = load_files(codebase_id, language_filter)

    if Enum.empty?(files) do
      Mix.shell().error("No files found for codebase: #{codebase_id}")
      Mix.shell().info("Hint: Run `mix parser.ingest` first to populate the database")
      System.halt(1)
    end

    Mix.shell().info("Found #{length(files)} files to analyze")
    Mix.shell().info("")

    # Analyze files
    results = analyze_files(files, include_rca, verbose)

    # Print summary
    print_summary(results, include_rca)

    # Store results if requested
    if store_results do
      Mix.shell().info("")
      Mix.shell().info("Storing results to database...")
      store_analysis_results(results)
      Mix.shell().info("✓ Results stored successfully")
    end

    Mix.shell().info("")
    Mix.shell().info("✓ Analysis complete!")
  end

  defp load_files(codebase_id, language_filter) do
    query =
      if language_filter do
        from c in CodeFile,
          where: c.codebase_id == ^codebase_id and c.language == ^language_filter,
          select: %{id: c.id, file_path: c.file_path, language: c.language, content: c.content}
      else
        from c in CodeFile,
          where: c.codebase_id == ^codebase_id,
          select: %{id: c.id, file_path: c.file_path, language: c.language, content: c.content}
      end

    Repo.all(query)
  end

  defp analyze_files(files, include_rca, verbose) do
    total = length(files)

    # Use parallel processing with controlled concurrency
    # Default: 4 parallel tasks (conservative, won't overwhelm host)
    max_concurrency = System.schedulers_online() |> min(4)

    Mix.shell().info("Analyzing #{total} files with #{max_concurrency} parallel workers...")

    files
    |> Enum.with_index(1)
    |> Task.async_stream(
      fn {file, index} ->
        if verbose do
          Mix.shell().info("[#{index}/#{total}] Analyzing #{file.file_path} (#{file.language})")
        else
          if rem(index, 10) == 0 do
            Mix.shell().info("Progress: #{index}/#{total} files analyzed")
          end
        end

        analysis_result = CodeAnalyzer.analyze_language(file.content, file.language)

        rca_result =
          if include_rca && CodeAnalyzer.has_rca_support?(file.language) do
            CodeAnalyzer.get_rca_metrics(file.content, file.language)
          else
            nil
          end

        %{
          file_id: file.id,
          file_path: file.file_path,
          language: file.language,
          analysis: analysis_result,
          rca_metrics: rca_result,
          analyzed_at: DateTime.utc_now()
        }
      end,
      max_concurrency: max_concurrency,
      # 30 seconds per file
      timeout: 30_000,
      on_timeout: :kill_task
    )
    |> Enum.map(fn
      {:ok, result} ->
        result

      {:exit, reason} ->
        Mix.shell().error("Task timed out: #{inspect(reason)}")
        nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp print_summary(results, include_rca) do
    Mix.shell().info("")
    Mix.shell().info("=" <> String.duplicate("=", 70))
    Mix.shell().info("ANALYSIS SUMMARY")
    Mix.shell().info("=" <> String.duplicate("=", 70))

    # Count by language
    by_language =
      results
      |> Enum.group_by(& &1.language)
      |> Enum.map(fn {lang, files} -> {lang, length(files)} end)
      |> Enum.sort_by(fn {_, count} -> -count end)

    Mix.shell().info("")
    Mix.shell().info("Files by Language:")

    Enum.each(by_language, fn {lang, count} ->
      Mix.shell().info("  #{String.pad_trailing(lang, 15)} #{count} files")
    end)

    # Success rate
    successful =
      Enum.count(results, fn r ->
        match?({:ok, _}, r.analysis)
      end)

    Mix.shell().info("")

    Mix.shell().info(
      "Success Rate: #{successful}/#{length(results)} (#{Float.round(successful / length(results) * 100, 1)}%)"
    )

    # Average complexity (for successful analyses)
    complexities =
      results
      |> Enum.filter(fn r -> match?({:ok, _}, r.analysis) end)
      |> Enum.map(fn r ->
        case r.analysis do
          {:ok, analysis} -> analysis.complexity_score
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    if !Enum.empty?(complexities) do
      avg_complexity = Enum.sum(complexities) / length(complexities)
      Mix.shell().info("Average Complexity: #{Float.round(avg_complexity, 2)}")
    end

    # RCA summary
    if include_rca do
      rca_analyzed =
        Enum.count(results, fn r ->
          match?({:ok, _}, r.rca_metrics)
        end)

      Mix.shell().info("")
      Mix.shell().info("RCA Metrics: #{rca_analyzed} files analyzed")
    end

    Mix.shell().info("=" <> String.duplicate("=", 70))
  end

  defp store_analysis_results(results) do
    start_time = System.monotonic_time(:millisecond)

    # Store each result
    stored_count =
      results
      |> Enum.map(fn result ->
        case result.analysis do
          {:ok, analysis} ->
            duration_ms = if result[:duration_ms], do: result.duration_ms, else: nil

            case CodeAnalyzer.store_result(result.file_id, analysis, duration_ms: duration_ms) do
              {:ok, _stored} ->
                :ok

              {:error, changeset} ->
                Logger.error(
                  "Failed to store result for #{result.file_path}: #{inspect(changeset.errors)}"
                )

                :error
            end

          {:error, reason} ->
            # Store error result
            case CodeAnalyzer.store_error(result.file_id, result.language, reason) do
              {:ok, _stored} ->
                :ok

              {:error, changeset} ->
                Logger.error(
                  "Failed to store error for #{result.file_path}: #{inspect(changeset.errors)}"
                )

                :error
            end
        end
      end)
      |> Enum.count(&(&1 == :ok))

    elapsed = System.monotonic_time(:millisecond) - start_time

    Mix.shell().info("Stored #{stored_count}/#{length(results)} results in #{elapsed}ms")
  end
end
