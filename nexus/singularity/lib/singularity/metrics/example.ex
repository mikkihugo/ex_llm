defmodule Singularity.Metrics.Example do
  @moduledoc """
  Example Usage - Complete Metrics Workflow

  This module demonstrates the complete metrics pipeline in action,
  showing how Elixir orchestrates Rust calculations with PostgreSQL enrichment.

  Run with:
      iex> Singularity.Metrics.Example.demo()
  """

  require Logger

  @doc """
  Complete metrics workflow demonstration
  """
  def demo do
    Logger.info("=== Singularity Metrics System Demo ===")

    # 1. Analyze a file
    Logger.info("\n1. Analyzing file...")

    case analyze_example_file() do
      {:ok, analysis} ->
        Logger.info("✓ Analysis complete")
        print_metrics(analysis)

        # 2. Get enrichment data
        Logger.info("\n2. Fetching enrichment data...")
        print_enrichment(analysis.enrichment)

        # 3. Generate insights
        Logger.info("\n3. Generated insights...")
        print_insights(analysis.insights)

        # 4. Get language report
        Logger.info("\n4. Getting language report...")
        get_and_print_language_report(:elixir)

        # 5. Find refactoring opportunities
        Logger.info("\n5. Finding refactoring opportunities...")
        find_and_print_opportunities(:elixir)

        Logger.info("\n=== Demo Complete ===")
        {:ok, analysis}

      {:error, reason} ->
        Logger.error("Analysis failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Example showing the data flow
  """
  def show_dataflow do
    Logger.info("""
    === Metrics Pipeline Data Flow ===

    1. ELIXIR (Orchestrator.analyze_file)
       ↓
    2. READ FILE & DETECT LANGUAGE
       ↓
    3. CALL RUST NIF (Metrics.NIF.analyze_all)
       ├─ Type Safety calculation (Rust)
       ├─ Coupling calculation (Rust)
       └─ Error Handling calculation (Rust)
       ↓
    4. POSTGRESQL ENRICHMENT (Metrics.Enrichment)
       ├─ Query similar patterns (pgvector)
       ├─ Fetch historical trends
       ├─ Get language benchmarks
       └─ Query refactoring patterns
       ↓
    5. STORE RESULTS (CodeMetrics table)
       ├─ Insert new record
       ├─ Store enrichment data
       └─ Index for querying
       ↓
    6. GENERATE INSIGHTS
       ├─ Anomaly detection
       ├─ Recommendations
       └─ Trend analysis
       ↓
    7. RETURN TO CALLER
       └─ Full analysis result with all data

    Performance:
    - Rust calculation: 50-200ms
    - DB enrichment: 100-500ms
    - Storage: 10-50ms
    - Total: 160-750ms per file
    """)
  end

  # Private helpers

  defp analyze_example_file do
    # Example Elixir code
    example_code = """
    defmodule MyModule do
      @doc \"\"\"
      Process user input with error handling
      \"\"\"
      def process(input) when is_binary(input) do
        case parse_input(input) do
          {:ok, data} ->
            Logger.info("Processing: \#{inspect(data)}")
            {:ok, transform(data)}

          {:error, reason} ->
            Logger.error("Parse failed: \#{inspect(reason)}")
            {:error, reason}
        end
      end

      defp parse_input(input) do
        case Integer.parse(input) do
          {num, ""} -> {:ok, num}
          _ -> {:error, "invalid input"}
        end
      end

      defp transform(value) do
        value * 2
      end
    end
    """

    Singularity.Metrics.Orchestrator.analyze_file(
      "lib/my_module.ex",
      code: example_code,
      language: :elixir,
      enrich: true,
      store: true
    )
  end

  defp print_metrics(analysis) do
    Logger.info("""
    Metrics Results:
    ├─ File: #{analysis.file_path}
    ├─ Language: #{analysis.language}
    └─ Scores:
       ├─ Type Safety: #{analysis.metrics.type_safety}
       ├─ Coupling: #{analysis.metrics.coupling}
       ├─ Error Handling: #{analysis.metrics.error_handling}
       └─ Overall Quality: #{analysis.metrics.overall_quality}
    """)
  end

  defp print_enrichment(enrichment) do
    patterns_count = enrichment[:similar_patterns] |> Enum.count()
    history_count = enrichment[:history] |> Enum.count()
    refactor_count = enrichment[:refactoring_patterns] |> Enum.count()

    Logger.info("""
    Enrichment Context:
    ├─ Similar Patterns: #{patterns_count}
    ├─ Historical Records: #{history_count}
    ├─ Refactoring Patterns: #{refactor_count}
    └─ Language Benchmarks:
       ├─ Avg Type Safety: #{enrichment[:benchmarks][:avg_type_safety] || "N/A"}
       ├─ Avg Coupling: #{enrichment[:benchmarks][:avg_coupling] || "N/A"}
       └─ Avg Error Handling: #{enrichment[:benchmarks][:avg_error_handling] || "N/A"}
    """)
  end

  defp print_insights(insights) do
    Enum.each(insights, fn insight ->
      Logger.info("  • [#{insight.type}] #{insight.message}")
      Logger.info("    → #{insight.recommendation}")
    end)

    if Enum.empty?(insights) do
      Logger.info("  No insights generated (code quality is good!)")
    end
  end

  defp get_and_print_language_report(language) do
    case Singularity.Metrics.Orchestrator.language_report(language) do
      {:ok, report} ->
        Logger.info("""
        Language Report (#{language}):
        ├─ Files Analyzed: #{report.file_count}
        ├─ Average Quality: #{report.avg_quality_score}
        ├─ Average Type Safety: #{report.type_safety_avg}
        ├─ Average Coupling: #{report.coupling_avg}
        ├─ Average Error Handling: #{report.error_handling_avg}
        └─ Top Performers:
           #{format_files(report.best_files)}
        """)

      {:error, reason} ->
        Logger.error("Failed to get report: #{inspect(reason)}")
    end
  end

  defp find_and_print_opportunities(language) do
    opportunities = Singularity.Metrics.Orchestrator.find_refactoring_opportunities(language)

    if Enum.empty?(opportunities) do
      Logger.info("No refactoring opportunities found (or database is empty)")
    else
      Logger.info("Files needing refactoring:")

      Enum.each(opportunities, fn file ->
        Logger.info("""
          • #{file.file_path} (Quality: #{file.overall_quality})
            Issues:
            #{format_opportunities(file.opportunities)}
        """)
      end)
    end
  end

  defp format_files(files) do
    Enum.map(files, fn file ->
      "  • #{file.path} (#{file.score})"
    end)
    |> Enum.join("\n")
  end

  defp format_opportunities(opportunities) do
    Enum.map(opportunities, fn opp ->
      "    - #{opp.type}: #{opp.score}"
    end)
    |> Enum.join("\n")
  end

  @doc """
  Performance benchmark
  """
  def benchmark(file_count \\ 10) do
    Logger.info("Running performance benchmark...")

    # Create test files
    test_files =
      Enum.map(1..file_count, fn i ->
        "lib/test_module_#{i}.ex"
      end)

    # Benchmark batch analysis
    start_time = System.monotonic_time(:millisecond)

    {ok_count, err_count, _results} =
      Singularity.Metrics.Orchestrator.analyze_batch(
        test_files,
        enrich: true,
        store: true
      )

    elapsed = System.monotonic_time(:millisecond) - start_time
    avg_per_file = if ok_count > 0, do: elapsed / ok_count, else: 0

    Logger.info("""
    Benchmark Results:
    ├─ Files Processed: #{ok_count} successful, #{err_count} failed
    ├─ Total Time: #{elapsed}ms
    ├─ Average per File: #{avg_per_file}ms
    └─ Throughput: #{(1000 / (avg_per_file + 1)) |> round()} files/second
    """)
  end

  @doc """
  Show architecture diagram
  """
  def show_architecture do
    Logger.info("""
    === Singularity Metrics Architecture ===

    ELIXIR LAYER
    ┌────────────────────────────────────────┐
    │ Metrics.Orchestrator (Coordinator)     │
    │ - High-level API                       │
    │ - Pipeline orchestration               │
    │ - Error handling                       │
    └────────────────────────────────────────┘
              ↓            ↓            ↓
         ┌────────┐  ┌──────────┐  ┌────────────┐
         │  NIF   │  │Enrichment│  │CodeMetrics │
         │        │  │ Queries  │  │   Schema   │
         └────────┘  └──────────┘  └────────────┘
            ↓             ↓              ↓
    RUST LAYER (NIF)  POSTGRESQL     POSTGRESQL
    ┌────────────────┐  (Patterns,    (Stored
    │ Code Analysis  │  History,      Metrics,
    │ - Type Safety  │  Benchmarks)   Indexes)
    │ - Coupling     │
    │ - Error        │
    │   Handling     │
    └────────────────┘

    DATA FLOW
    Code File
        ↓
    Orchestrator.analyze_file()
        ↓
    [1] NIF.analyze_all()      → Type Safety, Coupling, Error Handling
        ↓
    [2] Enrichment.build_context() → Patterns, History, Benchmarks
        ↓
    [3] CodeMetrics.create()   → Store in PostgreSQL
        ↓
    [4] Generate Insights      → Anomalies, Recommendations
        ↓
    Return Complete Analysis

    KEY POINTS
    • Rust NIF handles language-aware metric calculation (fast!)
    • Elixir coordinates with PostgreSQL for enrichment context
    • All results stored for historical analysis and trends
    • Insights generated from combined raw + enriched data
    """)
  end
end
