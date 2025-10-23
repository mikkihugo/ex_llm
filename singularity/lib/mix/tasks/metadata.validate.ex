defmodule Mix.Tasks.Metadata.Validate do
  @moduledoc """
  Validate v2.2.0 AI metadata completeness for ingested code.

  ## Usage

      # Validate all files in 'singularity' codebase
      mix metadata.validate

      # Validate specific codebase
      mix metadata.validate my-project

      # Show detailed report (includes all files)
      mix metadata.validate --detailed

      # Auto-fix incomplete files
      mix metadata.validate --fix

  ## What It Checks

  For each file, validates presence of:

  1. Human content (Quick Start, Examples, API list)
  2. Separator (`---` + "AI Navigation Metadata" heading)
  3. Module Identity JSON
  4. Architecture Diagram (Mermaid)
  5. Call Graph (YAML)
  6. Anti-Patterns section
  7. Search Keywords

  ## Validation Levels

  - **complete** - All v2.2.0 requirements met (score = 1.0)
  - **partial** - Some AI metadata present (score 0.5-0.99)
  - **legacy** - Has docs but not v2.2.0 structure (score < 0.5)
  - **missing** - No @moduledoc at all (score = 0.0)

  ## Integration with HTDAGAutoBootstrap

  This task reads from the same `code_files` table that HTDAGAutoBootstrap
  populates during ingestion. The validation results are stored in the
  `metadata.v2_2_validation` JSONB field.

  ## Auto-Fix

  When `--fix` is used, the task will:

  1. Identify files with incomplete metadata
  2. Use appropriate HBS template for language
  3. Call LLM to generate missing sections
  4. Update files with generated documentation
  5. Re-ingest to update database

  See `Singularity.Analysis.MetadataValidator` for implementation.
  """

  use Mix.Task
  require Logger

  alias Singularity.Analysis.MetadataValidator

  @shortdoc "Validate v2.2.0 AI metadata completeness"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, args, _invalid} =
      OptionParser.parse(args,
        strict: [detailed: :boolean, fix: :boolean],
        aliases: [d: :detailed, f: :fix]
      )

    codebase_id = List.first(args) || "singularity"
    detailed = Keyword.get(opts, :detailed, false)
    fix_mode = Keyword.get(opts, :fix, false)

    Mix.shell().info("")
    Mix.shell().info("Validating v2.2.0 AI metadata completeness for: #{codebase_id}")
    Mix.shell().info("")

    # Run validation
    report = MetadataValidator.validate_codebase(codebase_id)

    # Print summary
    print_summary(report)

    # Print detailed results if requested
    if detailed do
      print_detailed_results(report)
    else
      print_incomplete_files(report)
    end

    # Auto-fix if requested
    if fix_mode do
      fix_incomplete_files(report)
    end

    Mix.shell().info("")
  end

  defp print_summary(report) do
    Mix.shell().info("=" <> String.duplicate("=", 60))
    Mix.shell().info("v2.2.0 AI Metadata Validation Report")
    Mix.shell().info("=" <> String.duplicate("=", 60))
    Mix.shell().info("")
    Mix.shell().info("  Total Files:    #{report.total_files}")
    Mix.shell().info("  ✓ Complete:     #{report.complete} (#{report.complete_pct}%)")
    Mix.shell().info("  ⚠ Partial:      #{report.partial} (#{report.partial_pct}%)")
    Mix.shell().info("  ✗ Missing:      #{report.missing} (#{report.missing_pct}%)")
    Mix.shell().info("")
  end

  defp print_incomplete_files(report) do
    incomplete =
      report.by_file
      |> Enum.filter(fn {_path, v} -> v.level != :complete end)
      |> Enum.sort_by(fn {_path, v} -> v.score end, :asc)

    if length(incomplete) > 0 do
      Mix.shell().info(
        "Files needing attention (showing #{min(10, length(incomplete))} of #{length(incomplete)}):"
      )

      Mix.shell().info("")

      incomplete
      |> Enum.take(10)
      |> Enum.each(fn {path, validation} ->
        Mix.shell().info("  #{path}")
        Mix.shell().info("    Level: #{validation.level} | Score: #{validation.score}")

        if length(validation.missing) > 0 do
          Mix.shell().info("    Missing: #{Enum.join(validation.missing, ", ")}")
        end

        Mix.shell().info("")
      end)

      Mix.shell().info("Run with --detailed to see all files")
      Mix.shell().info("Run with --fix to auto-generate missing metadata")
    else
      Mix.shell().info("✓ All files have complete v2.2.0 metadata!")
    end

    Mix.shell().info("")
  end

  defp print_detailed_results(report) do
    Mix.shell().info("Detailed Results:")
    Mix.shell().info("")

    report.by_file
    |> Enum.sort_by(fn {_path, v} -> v.score end, :asc)
    |> Enum.each(fn {path, validation} ->
      Mix.shell().info("  #{path}")
      Mix.shell().info("    Level: #{validation.level}")
      Mix.shell().info("    Score: #{validation.score}")
      Mix.shell().info("    Has: #{inspect(validation.has)}")

      if length(validation.missing) > 0 do
        Mix.shell().info("    Missing: #{Enum.join(validation.missing, ", ")}")
      end

      if length(validation.recommendations) > 0 do
        Mix.shell().info("    Recommendations:")

        validation.recommendations
        |> Enum.each(fn rec ->
          Mix.shell().info("      - #{rec}")
        end)
      end

      Mix.shell().info("")
    end)
  end

  defp fix_incomplete_files(report) do
    incomplete =
      report.by_file
      |> Enum.filter(fn {_path, v} -> v.level != :complete end)
      |> Enum.map(fn {path, _v} -> path end)

    if length(incomplete) == 0 do
      Mix.shell().info("✓ No files need fixing!")
    else
      Mix.shell().info("")
      Mix.shell().info("Auto-fixing #{length(incomplete)} files...")
      Mix.shell().info("")

      incomplete
      |> Enum.each(fn file_path ->
        Mix.shell().info("Fixing: #{file_path}")

        case MetadataValidator.fix_incomplete_metadata(file_path) do
          {:ok, :queued} ->
            Mix.shell().info("  ✓ Queued for auto-fix")

          {:error, reason} ->
            Mix.shell().info("  ✗ Error: #{inspect(reason)}")
        end
      end)

      Mix.shell().info("")
      Mix.shell().info("Auto-fix complete! Re-run validation to see results.")
      Mix.shell().info("")
    end
  end
end
