defmodule Mix.Tasks.Documentation.Upgrade do
  @moduledoc """
  Upgrade documentation across all source files to quality 2.2.0+ standards.

  This task coordinates the 6 autonomous agents to automatically scan,
  analyze, and upgrade documentation for Elixir, Rust, and TypeScript files.

  ## Usage

      # Run full documentation upgrade pipeline
      mix documentation.upgrade

      # Run incremental upgrade for specific files
      mix documentation.upgrade --files lib/my_module.ex,rust/src/lib.rs

      # Run with specific language focus
      mix documentation.upgrade --language elixir

      # Enable quality gates (enforce standards)
      mix documentation.upgrade --enforce-quality

      # Get status report only
      mix documentation.upgrade --status

      # Schedule automatic upgrades
      mix documentation.upgrade --schedule 60

  ## Options

  - `--files` - Comma-separated list of files to upgrade
  - `--language` - Focus on specific language (elixir, rust, typescript)
  - `--enforce-quality` - Enable quality gates to enforce standards
  - `--status` - Show current documentation status only
  - `--schedule` - Schedule automatic upgrades every N minutes
  - `--dry-run` - Show what would be upgraded without making changes

  ## Examples

      # Full upgrade with quality enforcement
      mix documentation.upgrade --enforce-quality

      # Upgrade only Elixir files
      mix documentation.upgrade --language elixir

      # Check status
      mix documentation.upgrade --status

      # Schedule automatic upgrades every 2 hours
      mix documentation.upgrade --schedule 120
  """

  use Mix.Task
  require Logger
  alias Singularity.Agents.DocumentationPipeline
  alias Singularity.Agents.QualityEnforcer
  alias Singularity.Agents.DocumentationUpgrader

  @shortdoc "Upgrade documentation to quality 2.2.0+ standards"

  @impl true
  def run(args) do
    {opts, _parsed, _invalid} = OptionParser.parse(args,
      strict: [
        files: :string,
        language: :string,
        enforce_quality: :boolean,
        status: :boolean,
        schedule: :integer,
        dry_run: :boolean
      ],
      aliases: [
        f: :files,
        l: :language,
        e: :enforce_quality,
        s: :status,
        d: :dry_run
      ]
    )

    Mix.shell().info("""
    ╔══════════════════════════════════════════════════════════════════════════════╗
    ║                    Documentation Upgrade Pipeline 2.3.0                     ║
    ║                    Multi-Language Quality Standards                          ║
    ╚══════════════════════════════════════════════════════════════════════════════╝
    """)

    # Start required agents
    start_agents()

    cond do
      opts[:status] ->
        show_status()

      opts[:schedule] ->
        schedule_automatic_upgrades(opts[:schedule])

      opts[:dry_run] ->
        run_dry_run(opts)

      true ->
        run_upgrade_pipeline(opts)
    end
  end

  defp start_agents do
    Mix.shell().info("Starting documentation agents...")

    # Start DocumentationPipeline
    case DocumentationPipeline.start_link() do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      {:error, reason} -> 
        Mix.shell().error("Failed to start DocumentationPipeline: #{inspect(reason)}")
        System.halt(1)
    end

    # Start QualityEnforcer
    case QualityEnforcer.start_link() do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      {:error, reason} -> 
        Mix.shell().error("Failed to start QualityEnforcer: #{inspect(reason)}")
        System.halt(1)
    end

    # Start DocumentationUpgrader
    case DocumentationUpgrader.start_link() do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      {:error, reason} -> 
        Mix.shell().error("Failed to start DocumentationUpgrader: #{inspect(reason)}")
        System.halt(1)
    end

    Mix.shell().info("✅ All agents started successfully")
  end

  defp show_status do
    Mix.shell().info("Getting documentation status...")

    with {:ok, pipeline_status} <- DocumentationPipeline.get_pipeline_status(),
         {:ok, quality_report} <- QualityEnforcer.get_quality_report() do
      
      Mix.shell().info("""
      📊 Documentation Status Report
      ═══════════════════════════════════════════════════════════════════════════════

      Pipeline Status:
        Status: #{pipeline_status.status}
        Running: #{pipeline_status.pipeline_running}
        Last Run: #{pipeline_status.last_run || "Never"}
        Auto-Upgrades: #{pipeline_status.automatic_upgrades_enabled}

      Quality Report:
        Total Files: #{quality_report.total_files}
        Compliant: #{quality_report.compliant}
        Non-Compliant: #{quality_report.non_compliant}
        Compliance Rate: #{quality_report.compliance_rate}%

      Languages:
      """)

      quality_report.languages
      |> Enum.each(fn {lang, stats} ->
        Mix.shell().info("""
          #{String.capitalize(to_string(lang))}:
            Total: #{stats.total}
            Compliant: #{stats.compliant}
            Avg Quality: #{stats.avg_quality}
        """)
      end)

      Mix.shell().info("""
      Quality Gates: #{if quality_report.quality_gates_enabled, do: "Enabled", else: "Disabled"}
      """)

    else
      {:error, reason} ->
        Mix.shell().error("Failed to get status: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp schedule_automatic_upgrades(interval_minutes) do
    Mix.shell().info("Scheduling automatic documentation upgrades every #{interval_minutes} minutes...")

    case DocumentationPipeline.schedule_automatic_upgrades(interval_minutes) do
      :ok ->
        Mix.shell().info("✅ Automatic upgrades scheduled successfully")
        Mix.shell().info("The system will now automatically upgrade documentation every #{interval_minutes} minutes")
      {:error, reason} ->
        Mix.shell().error("Failed to schedule automatic upgrades: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp run_dry_run(opts) do
    Mix.shell().info("Running dry run - showing what would be upgraded...")

    files = get_files_to_process(opts)
    Mix.shell().info("Files to process: #{length(files)}")

    # Analyze files without upgrading
    case DocumentationUpgrader.scan_codebase_documentation() do
      {:ok, results} ->
        Mix.shell().info("""
        📋 Dry Run Results
        ═══════════════════════════════════════════════════════════════════════════════

        Total Files: #{results.total_files}
        Documented: #{results.documented}
        Quality Modules: #{results.quality_modules}
        Missing Documentation: #{results.total_files - results.documented}

        Files that would be upgraded:
        """)

        files
        |> Enum.take(10)
        |> Enum.each(fn file ->
          Mix.shell().info("  - #{file}")
        end)

        if length(files) > 10 do
          Mix.shell().info("  ... and #{length(files) - 10} more files")
        end

      {:error, reason} ->
        Mix.shell().error("Dry run failed: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp run_upgrade_pipeline(opts) do
    # Enable quality gates if requested
    if opts[:enforce_quality] do
      Mix.shell().info("Enabling quality gates...")
      QualityEnforcer.enable_quality_gates()
    end

    files = get_files_to_process(opts)
    
    Mix.shell().info("""
    🚀 Starting Documentation Upgrade Pipeline
    ═══════════════════════════════════════════════════════════════════════════════

    Files to process: #{length(files)}
    Quality enforcement: #{if opts[:enforce_quality], do: "Enabled", else: "Disabled"}
    """)

    # Run the pipeline
    case DocumentationPipeline.run_full_pipeline() do
      {:ok, :pipeline_started} ->
        Mix.shell().info("✅ Pipeline started successfully")
        Mix.shell().info("The pipeline is running in the background. Check status with: mix documentation.upgrade --status")
        
      {:error, :pipeline_already_running} ->
        Mix.shell().warning("Pipeline is already running. Check status with: mix documentation.upgrade --status")
        
      {:error, reason} ->
        Mix.shell().error("Failed to start pipeline: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp get_files_to_process(opts) do
    cond do
      opts[:files] ->
        opts[:files]
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.filter(&File.exists?/1)
        
      opts[:language] ->
        get_files_by_language(opts[:language])
        
      true ->
        # Get all files
        ["./singularity/lib/**/*.ex", "./rust/**/*.rs", "./llm-server/**/*.ts", "./llm-server/**/*.tsx"]
        |> Enum.flat_map(fn pattern ->
          Path.wildcard(pattern)
        end)
        |> Enum.filter(&File.regular?/1)
    end
  end

  defp get_files_by_language(language) do
    case language do
      "elixir" ->
        Path.wildcard("./singularity/lib/**/*.ex")
        |> Enum.filter(&File.regular?/1)
        
      "rust" ->
        Path.wildcard("./rust/**/*.rs")
        |> Enum.filter(&File.regular?/1)
        
      "typescript" ->
        Path.wildcard("./llm-server/**/*.ts") ++ Path.wildcard("./llm-server/**/*.tsx")
        |> Enum.filter(&File.regular?/1)
        
      _ ->
        Mix.shell().error("Unsupported language: #{language}. Supported: elixir, rust, typescript")
        System.halt(1)
    end
  end
end