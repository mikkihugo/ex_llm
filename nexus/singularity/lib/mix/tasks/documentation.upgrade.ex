defmodule Mix.Tasks.Documentation.Upgrade do
  @moduledoc """
  Upgrade documentation across all source files to quality 2.6.0 standards from templates_data.

  This task coordinates the 6 autonomous agents to automatically scan,
  analyze, and upgrade documentation for all supported languages using templates_data.

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

      # Run incremental updates for changed files
      mix documentation.upgrade --incremental

  ## Options

  - `--files` - Comma-separated list of files to upgrade
  - `--language` - Focus on specific language (elixir, rust, go, java, javascript, tsx, gleam, python)
  - `--enforce-quality` - Enable quality gates to enforce standards
  - `--status` - Show current documentation status only
  - `--incremental` - Run incremental updates for changed files only
  - `--dry-run` - Show what would be upgraded without making changes

  ## Examples

      # Full upgrade with quality enforcement
      mix documentation.upgrade --enforce-quality

      # Upgrade only Elixir files
      mix documentation.upgrade --language elixir

      # Check status
      mix documentation.upgrade --status

      # Run incremental updates for changed files
      mix documentation.upgrade --incremental
  """

  use Mix.Task
  require Logger
  alias Singularity.Agents.DocumentationPipeline
  alias Singularity.Agents.QualityEnforcer

  @shortdoc "Upgrade documentation to quality 2.6.0 standards from templates_data"

  @impl true
  def run(args) do
    {opts, _parsed, _invalid} =
      OptionParser.parse(args,
        strict: [
          files: :string,
          language: :string,
          enforce_quality: :boolean,
          status: :boolean,
          incremental: :boolean,
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
    ║                    Documentation Upgrade Pipeline 2.6.0                     ║
    ║                    Multi-Language Quality Standards                          ║
    ╚══════════════════════════════════════════════════════════════════════════════╝
    """)

    # Start required agents
    start_agents()

    cond do
      opts[:status] ->
        show_status()

      opts[:incremental] ->
        run_incremental_updates()

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
      {:ok, _pid} ->
        :ok

      {:error, {:already_started, _pid}} ->
        :ok

      {:error, reason} ->
        Mix.shell().error("Failed to start DocumentationPipeline: #{inspect(reason)}")
        System.halt(1)
    end

    # Start QualityEnforcer
    case QualityEnforcer.start_link() do
      {:ok, _pid} ->
        :ok

      {:error, {:already_started, _pid}} ->
        :ok

      {:error, reason} ->
        Mix.shell().error("Failed to start QualityEnforcer: #{inspect(reason)}")
        System.halt(1)
    end

    # DocumentationPipeline is already started in supervision tree
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

  defp run_incremental_updates do
    Mix.shell().info("Running incremental documentation updates for changed files...")

    # Get changed files from ChangeTracker
    case Singularity.Agents.ChangeTracker.get_changes() do
      {:ok, changes} ->
        if length(changes) > 0 do
          file_paths = Enum.map(changes, & &1.file_path)

          Mix.shell().info(
            "Found #{length(changes)} changed files: #{Enum.join(file_paths, ", ")}"
          )

          # Run incremental pipeline for changed files
          case DocumentationPipeline.run_incremental_pipeline(file_paths) do
            {:ok, :pipeline_started} ->
              Mix.shell().info("✅ Incremental updates started successfully")

            {:error, reason} ->
              Mix.shell().error("Failed to start incremental updates: #{inspect(reason)}")
              System.halt(1)
          end
        else
          Mix.shell().info("No files have changed - nothing to update")
        end

      {:error, reason} ->
        Mix.shell().error("Failed to get changed files: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp run_dry_run(opts) do
    Mix.shell().info("Running dry run - showing what would be upgraded...")

    files = get_files_to_process(opts)
    Mix.shell().info("Files to process: #{length(files)}")

    # Analyze changed files without upgrading
    case Singularity.Agents.ChangeTracker.get_changes() do
      {:ok, changes} ->
        if length(changes) > 0 do
          file_paths = Enum.map(changes, & &1.file_path)

          Mix.shell().info("""
          📋 Dry Run Results
          ═══════════════════════════════════════════════════════════════════════════════

          Changed Files Found: #{length(changes)}
          Files that would be upgraded:
          #{Enum.join(file_paths, "\n")}
          """)
        else
          Mix.shell().info("No files have changed - nothing to upgrade")
        end

      {:error, reason} ->
        Mix.shell().error("Failed to get changed files: #{inspect(reason)}")
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

    # Run incremental pipeline for changed files
    case Singularity.Agents.ChangeTracker.get_changes() do
      {:ok, changes} ->
        if length(changes) > 0 do
          file_paths = Enum.map(changes, & &1.file_path)

          case DocumentationPipeline.run_incremental_pipeline(file_paths) do
            {:ok, :pipeline_started} ->
              Mix.shell().info("✅ Incremental pipeline started successfully")

            {:error, reason} ->
              Mix.shell().error("Failed to start incremental pipeline: #{inspect(reason)}")
              System.halt(1)
          end
        else
          Mix.shell().info("No files have changed - nothing to update")
        end

      {:error, reason} ->
        Mix.shell().error("Failed to get changed files: #{inspect(reason)}")
        System.halt(1)
    end

    Mix.shell().info(
      "The pipeline is running in the background. Check status with: mix documentation.upgrade --status"
    )
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
        [
          "./singularity/lib/**/*.ex",
          "./rust/**/*.rs",
          "./observer/lib/**/*.ex",
          "./observer/lib/**/*.heex",
          "./packages/**/*.rs",
          "./packages/**/*.ex"
        ]
        |> Enum.flat_map(fn pattern ->
          Path.wildcard(pattern)
        end)
        |> Enum.filter(&File.regular?/1)
    end
  end

  defp get_files_by_language(language) do
    case language do
      "elixir" ->
        (Path.wildcard("./singularity/lib/**/*.ex") ++
           Path.wildcard("./observer/lib/**/*.ex") ++
           Path.wildcard("./packages/**/*.ex"))
        |> Enum.filter(&File.regular?/1)

      "rust" ->
        (Path.wildcard("./rust/**/*.rs") ++
           Path.wildcard("./packages/**/*.rs"))
        |> Enum.filter(&File.regular?/1)

      "javascript" ->
        Path.wildcard("./**/*.js")
        |> Enum.filter(&File.regular?/1)

      "typescript" ->
        Path.wildcard("./**/*.ts")
        |> Enum.filter(&File.regular?/1)

      "tsx" ->
        Path.wildcard("./**/*.tsx")
        |> Enum.filter(&File.regular?/1)

      "go" ->
        Path.wildcard("./**/*.go")
        |> Enum.filter(&File.regular?/1)

      "java" ->
        Path.wildcard("./**/*.java")
        |> Enum.filter(&File.regular?/1)

      "gleam" ->
        Path.wildcard("./**/*.gleam")
        |> Enum.filter(&File.regular?/1)

      "python" ->
        Path.wildcard("./**/*.py")
        |> Enum.filter(&File.regular?/1)

      _ ->
        Mix.shell().error(
          "Unsupported language: #{language}. Supported: elixir, rust, go, java, javascript, typescript, tsx, gleam, python"
        )

        System.halt(1)
    end
  end
end
