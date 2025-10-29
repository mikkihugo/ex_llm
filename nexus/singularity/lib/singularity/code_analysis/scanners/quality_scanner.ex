defmodule Singularity.CodeAnalysis.Scanners.QualityScanner do
  @moduledoc """
  Thin wrapper that exposes `Singularity.CodeAnalysis.QualityAnalyzer` as a
  scanner module.  This allows the existing scan orchestrator and configuration
  (`config :singularity, :scanner_types`) to treat the quality analyzer like the
  other scanners (security, performance, etc).
  """

  alias Singularity.CodeAnalysis.QualityAnalyzer

  @type scan_result :: %{
          issues: [map()],
          summary: map(),
          refactoring_suggestions: list()
        }

  @doc "Human readable name used by the scan orchestrator."
  @spec name() :: atom()
  def name, do: :quality

  @doc "Return scanner metadata (name + description) used in UIs."
  @spec info() :: map()
  def info do
    config = Application.get_env(:singularity, :scanner_types, %{})
    scanner_cfg = Map.get(config, name(), %{})

    %{
      name: name(),
      description:
        Map.get(scanner_cfg, :description, "Detect code quality issues and violations"),
      enabled: Map.get(scanner_cfg, :enabled, true)
    }
  end

  @doc """
  Check if the scanner is enabled in configuration.
  """
  @spec enabled?() :: boolean()
  def enabled? do
    info()[:enabled]
  end

  @doc """
  Run the quality scanner against a path (file or directory).
  """
  @spec scan(Path.t(), keyword()) :: {:ok, scan_result()} | {:error, term()}
  def scan(path, opts \\ []) do
    case QualityAnalyzer.analyze(path, opts) do
      {:ok, %{issues: issues, summary: summary, refactoring_suggestions: suggestions}} ->
        {:ok,
         %{
           issues: issues,
           summary: summary,
           refactoring_suggestions: suggestions
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
