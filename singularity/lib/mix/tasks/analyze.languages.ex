defmodule Mix.Tasks.Analyze.Languages do
  @shortdoc "Show supported languages and their capabilities"

  @moduledoc """
  Displays all supported languages and their analysis capabilities.

  ## Usage

      # Show all languages
      mix analyze.languages

      # Show only RCA-supported languages
      mix analyze.languages --rca-only

      # Show detailed capability information
      mix analyze.languages --detailed

  ## Options

    * `--rca-only` - Show only languages with RCA metrics support
    * `--detailed` - Show detailed capability information for each language
  """

  use Mix.Task
  alias Singularity.CodeAnalyzer

  @requirements ["app.start"]

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args,
      strict: [
        rca_only: :boolean,
        detailed: :boolean
      ]
    )

    rca_only = opts[:rca_only] || false
    detailed = opts[:detailed] || false

    all_languages = CodeAnalyzer.supported_languages()
    rca_languages = CodeAnalyzer.rca_supported_languages()
    ast_grep_languages = CodeAnalyzer.ast_grep_supported_languages()

    languages_to_show =
      if rca_only do
        rca_languages
      else
        all_languages
      end

    Mix.shell().info("")
    Mix.shell().info("=" <> String.duplicate("=", 70))
    Mix.shell().info("SINGULARITY CODE ANALYZER - SUPPORTED LANGUAGES")
    Mix.shell().info("=" <> String.duplicate("=", 70))
    Mix.shell().info("")
    Mix.shell().info("Total Languages: #{length(all_languages)}")
    Mix.shell().info("RCA Metrics: #{length(rca_languages)} languages")
    Mix.shell().info("AST-Grep: #{length(ast_grep_languages)} languages")
    Mix.shell().info("")

    if detailed do
      show_detailed_capabilities(languages_to_show, rca_languages, ast_grep_languages)
    else
      show_language_list(languages_to_show, rca_languages)
    end

    Mix.shell().info("")
    Mix.shell().info("=" <> String.duplicate("=", 70))
    Mix.shell().info("")
    Mix.shell().info("Use --detailed flag for capability details")
    Mix.shell().info("Use --rca-only to see only languages with RCA metrics")
  end

  defp show_language_list(languages, rca_languages) do
    Mix.shell().info("Supported Languages:")
    Mix.shell().info("")

    # Group by capability
    languages_with_rca =
      languages
      |> Enum.filter(&(&1 in rca_languages))
      |> Enum.sort()

    languages_without_rca =
      languages
      |> Enum.reject(&(&1 in rca_languages))
      |> Enum.sort()

    if !Enum.empty?(languages_with_rca) do
      Mix.shell().info("With RCA Metrics (#{length(languages_with_rca)}):")
      Enum.each(languages_with_rca, fn lang ->
        Mix.shell().info("  ✓ #{lang}")
      end)
      Mix.shell().info("")
    end

    if !Enum.empty?(languages_without_rca) do
      Mix.shell().info("AST-Only (#{length(languages_without_rca)}):")
      Enum.each(languages_without_rca, fn lang ->
        Mix.shell().info("  • #{lang}")
      end)
    end
  end

  defp show_detailed_capabilities(languages, rca_languages, ast_grep_languages) do
    Mix.shell().info("Language Capabilities:")
    Mix.shell().info("")
    Mix.shell().info(String.pad_trailing("Language", 15) <> " | RCA | AST-Grep | Capabilities")
    Mix.shell().info(String.duplicate("-", 70))

    languages
    |> Enum.sort()
    |> Enum.each(fn lang ->
      has_rca = lang in rca_languages
      has_ast = lang in ast_grep_languages

      rca_mark = if has_rca, do: " ✓ ", else: " - "
      ast_mark = if has_ast, do: "    ✓   ", else: "    -   "

      capabilities = get_capabilities(lang, has_rca, has_ast)

      Mix.shell().info(
        String.pad_trailing(lang, 15) <>
        " |" <> rca_mark <> "|" <> ast_mark <> "| " <> capabilities
      )
    end)

    Mix.shell().info("")
    Mix.shell().info("Legend:")
    Mix.shell().info("  RCA      - Cyclomatic Complexity, Halstead metrics, Maintainability Index")
    Mix.shell().info("  AST-Grep - Function/class extraction, imports/exports, pattern matching")
  end

  defp get_capabilities(_lang, true, true), do: "Full analysis + metrics"
  defp get_capabilities(_lang, false, true), do: "AST analysis only"
  defp get_capabilities(_lang, true, false), do: "Metrics only (rare)"
  defp get_capabilities(_lang, false, false), do: "Limited support"
end
